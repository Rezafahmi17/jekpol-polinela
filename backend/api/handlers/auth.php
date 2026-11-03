<?php
// Handler: autentikasi, profil, data publik, notifikasi, pengaduan

function h_ping(): void { ok(['time' => date('c')], 'GOJEK POLINELA API aktif'); }

function h_public_config(): void {
    $t = tariff();
    ok([
        'tariff' => ['base_fare' => (int) $t['base_fare'], 'per_km_rate' => (int) $t['per_km_rate']],
        'campus_locations' => array_map(fn($r) => [
            'id' => (int) $r['id'], 'name' => $r['name'], 'category' => $r['category'], 'address' => $r['address'],
            'lat' => (float) $r['lat'], 'lng' => (float) $r['lng'],
        ], rows('SELECT * FROM campus_locations WHERE is_active = 1 ORDER BY id')),
        'penalty' => [
            'block_threshold' => (int) setting('penalty_block_threshold', '3'),
            'points_per_violation' => (int) setting('penalty_points_per_violation', '1'),
        ],
        'search_timeout_sec' => (int) setting('order_search_timeout_sec', '120'),
    ]);
}

function h_register(): void {
    $d = need('role', 'name', 'npm', 'email', 'phone', 'password');
    if (!in_array($d['role'], ['customer', 'driver'], true)) throw new ApiException('Role tidak valid', 422);
    if (!filter_var($d['email'], FILTER_VALIDATE_EMAIL)) throw new ApiException('Format email tidak valid', 422);
    if (!preg_match('/^[0-9]{8,15}$/', $d['phone'] = preg_replace('/[\s\-+]/', '', $d['phone']))) throw new ApiException('Nomor HP tidak valid', 422);
    if (!preg_match('/^[0-9A-Za-z]{6,20}$/', $d['npm'])) throw new ApiException('NPM tidak valid', 422);
    if (strlen($d['password']) < 6) throw new ApiException('Password minimal 6 karakter', 422);
    if (scalar('SELECT 1 FROM users WHERE email = ?', [strtolower($d['email'])])) throw new ApiException('Email sudah terdaftar', 409);
    if (scalar('SELECT 1 FROM users WHERE npm = ?', [$d['npm']])) throw new ApiException('NPM sudah terdaftar', 409);

    $ktm = $surat = null;
    if ($d['role'] === 'driver') {
        need('plate_number', 'vehicle_model');
        $ktm = save_upload('ktm', 'docs');
        $surat = save_upload('surat', 'docs');
        if (!$ktm) throw new ApiException('Foto KTM wajib diunggah', 422);
        if (!$surat) throw new ApiException('Surat pernyataan bermeterai wajib diunggah', 422);
    }

    $pdo = db();
    $pdo->beginTransaction();
    try {
        q('INSERT INTO users (role, name, npm, email, phone, password_hash) VALUES (?,?,?,?,?,?)',
            [$d['role'], $d['name'], $d['npm'], strtolower($d['email']), $d['phone'], password_hash($d['password'], PASSWORD_BCRYPT)]);
        $uid = insert_id();
        if ($d['role'] === 'driver') {
            q('INSERT INTO driver_profiles (user_id) VALUES (?)', [$uid]);
            q('INSERT INTO vehicles (driver_id, brand_model, plate_number, color) VALUES (?,?,?,?)',
                [$uid, trim((string) in('vehicle_model')), strtoupper(trim((string) in('plate_number'))), in('vehicle_color')]);
            q('INSERT INTO driver_documents (driver_id, doc_type, file_path, original_name) VALUES (?,?,?,?)', [$uid, 'ktm', $ktm['path'], $ktm['original']]);
            q('INSERT INTO driver_documents (driver_id, doc_type, file_path, original_name) VALUES (?,?,?,?)', [$uid, 'surat_pernyataan', $surat['path'], $surat['original']]);
            foreach (rows("SELECT id FROM users WHERE role IN ('admin','super_admin') AND status = 'active'") as $a)
                notify((int) $a['id'], 'Pendaftaran driver baru', $d['name'] . ' menunggu verifikasi dokumen.', 'verification');
        }
        $pdo->commit();
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
    $token = issue_token($uid);
    ok(['token' => $token, 'user' => user_public(row('SELECT * FROM users WHERE id = ?', [$uid]))],
        $d['role'] === 'driver' ? 'Pendaftaran berhasil, menunggu verifikasi admin' : 'Registrasi berhasil');
}

function h_login(): void {
    $d = need('identifier', 'password');
    $u = row('SELECT * FROM users WHERE (email = ? OR npm = ?) AND status <> ?', [strtolower($d['identifier']), $d['identifier'], 'deleted']);
    if (!$u || !password_verify($d['password'], $u['password_hash'])) throw new ApiException('Email/NPM atau password salah', 401);
    if ($u['status'] === 'blocked' && $u['role'] !== 'driver')
        throw new ApiException('Akun diblokir' . ($u['blocked_reason'] ? ': ' . $u['blocked_reason'] : ''), 403);
    $token = issue_token((int) $u['id']);
    $u = row('SELECT * FROM users WHERE id = ?', [$u['id']]);
    ok(['token' => $token, 'user' => user_public($u)], 'Login berhasil');
}

function h_logout(): void {
    $u = current_user();
    q('UPDATE users SET api_token = NULL, token_expires_at = NULL WHERE id = ?', [$u['id']]);
    if ($u['role'] === 'driver') {
        $busy = scalar("SELECT 1 FROM orders WHERE driver_id = ? AND status IN ('accepted','heading_pickup','picked_up','in_trip')", [$u['id']]);
        if (!$busy) q('UPDATE driver_profiles SET is_online = 0, last_online_at = NOW() WHERE user_id = ?', [$u['id']]);
    }
    ok([], 'Logout berhasil');
}

function h_me(): void {
    $u = current_user();
    ok(['user' => user_public($u)]);
}

function h_update_profile(): void {
    $u = current_user();
    $name = trim((string) in('name', $u['name']));
    $phone = preg_replace('/[\s\-+]/', '', (string) in('phone', $u['phone']));
    if ($name === '') throw new ApiException('Nama wajib diisi', 422);
    if (!preg_match('/^[0-9]{8,15}$/', $phone)) throw new ApiException('Nomor HP tidak valid', 422);
    q('UPDATE users SET name = ?, phone = ? WHERE id = ?', [$name, $phone, $u['id']]);
    if ($u['role'] === 'driver' && (in('plate_number') || in('vehicle_model'))) {
        q('UPDATE vehicles SET brand_model = ?, plate_number = ?, color = ? WHERE driver_id = ?',
            [trim((string) in('vehicle_model', '')), strtoupper(trim((string) in('plate_number', ''))), in('vehicle_color'), $u['id']]);
    }
    ok(['user' => user_public(row('SELECT * FROM users WHERE id = ?', [$u['id']]))], 'Profil diperbarui');
}

function h_change_password(): void {
    $u = current_user();
    $d = need('old_password', 'new_password');
    if (!password_verify($d['old_password'], $u['password_hash'])) throw new ApiException('Password lama salah', 422);
    if (strlen($d['new_password']) < 6) throw new ApiException('Password baru minimal 6 karakter', 422);
    q('UPDATE users SET password_hash = ? WHERE id = ?', [password_hash($d['new_password'], PASSWORD_BCRYPT), $u['id']]);
    ok([], 'Password berhasil diubah');
}

function h_notifications(): void {
    $u = current_user();
    $list = rows('SELECT id, title, body, type, order_id, is_read, created_at FROM notifications WHERE user_id = ? ORDER BY id DESC LIMIT 50', [$u['id']]);
    $unread = (int) scalar('SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0', [$u['id']]);
    ok(['notifications' => array_map(function ($n) { $n['is_read'] = (bool) $n['is_read']; $n['id'] = (int) $n['id']; return $n; }, $list), 'unread' => $unread]);
}
function h_notifications_read(): void {
    $u = current_user();
    q('UPDATE notifications SET is_read = 1 WHERE user_id = ?', [$u['id']]);
    ok([]);
}

function h_complaint_create(): void {
    $u = current_user();
    $d = need('subject', 'message');
    $orderId = in('order_id') ? (int) in('order_id') : null;
    q('INSERT INTO complaints (user_id, order_id, subject, message) VALUES (?,?,?,?)', [$u['id'], $orderId, $d['subject'], $d['message']]);
    foreach (rows("SELECT id FROM users WHERE role IN ('admin','super_admin') AND status = 'active'") as $a)
        notify((int) $a['id'], 'Pengaduan baru', $u['name'] . ': ' . $d['subject'], 'complaint');
    ok([], 'Pengaduan terkirim. Admin akan menindaklanjuti.');
}
function h_complaints_mine(): void {
    $u = current_user();
    ok(['complaints' => rows('SELECT id, subject, message, status, response, created_at, resolved_at FROM complaints WHERE user_id = ? ORDER BY id DESC LIMIT 30', [$u['id']])]);
}

