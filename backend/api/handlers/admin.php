<?php
// Handler: Admin & Super Admin

function admin_only(): array { return require_role('admin', 'super_admin'); }
function super_only(): array { return require_role('super_admin'); }

function h_admin_dashboard(): void {
    admin_only();
    $byStatus = [];
    foreach (rows('SELECT status, COUNT(*) AS c FROM orders GROUP BY status') as $r) $byStatus[$r['status']] = (int) $r['c'];
    ok([
        'customers' => (int) scalar("SELECT COUNT(*) FROM users WHERE role = 'customer' AND status <> 'deleted'"),
        'drivers' => (int) scalar("SELECT COUNT(*) FROM users WHERE role = 'driver' AND status <> 'deleted'"),
        'drivers_online' => (int) scalar("SELECT COUNT(*) FROM driver_profiles WHERE is_online = 1"),
        'drivers_busy' => (int) scalar("SELECT COUNT(*) FROM driver_profiles WHERE is_busy = 1"),
        'pending_verifications' => (int) scalar("SELECT COUNT(*) FROM driver_profiles dp JOIN users u ON u.id = dp.user_id WHERE dp.verification_status = 'pending' AND u.status <> 'deleted'"),
        'blocked_users' => (int) scalar("SELECT COUNT(*) FROM users WHERE status = 'blocked'"),
        'orders_total' => (int) scalar('SELECT COUNT(*) FROM orders'),
        'orders_today' => (int) scalar('SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURDATE()'),
        'orders_active' => (int) scalar("SELECT COUNT(*) FROM orders WHERE status IN (" . ACTIVE_STATUSES . ")"),
        'revenue_today' => (int) scalar("SELECT COALESCE(SUM(amount),0) FROM payments WHERE status = 'paid' AND DATE(paid_at) = CURDATE()"),
        'revenue_total' => (int) scalar("SELECT COALESCE(SUM(amount),0) FROM payments WHERE status = 'paid'"),
        'cancellations' => (int) scalar("SELECT COUNT(*) FROM orders WHERE status IN ('cancelled_customer','cancelled_driver')"),
        'open_complaints' => (int) scalar("SELECT COUNT(*) FROM complaints WHERE status = 'open'"),
        'pending_penalties' => (int) scalar("SELECT COUNT(*) FROM penalties WHERE status = 'pending_review'"),
        'orders_by_status' => (object) $byStatus,
    ]);
}

function user_row_public(array $r): array {
    $o = [
        'id' => (int) $r['id'], 'role' => $r['role'], 'name' => $r['name'], 'npm' => $r['npm'], 'email' => $r['email'],
        'phone' => $r['phone'], 'status' => $r['status'], 'blocked_reason' => $r['blocked_reason'],
        'last_login_at' => $r['last_login_at'], 'created_at' => $r['created_at'],
    ];
    if ($r['role'] === 'driver') $o['driver'] = driver_info((int) $r['id']);
    return $o;
}

function h_admin_users(): void {
    admin_only();
    $role = in('role');
    $qstr = in('q');
    $status = in('status');
    $sql = "SELECT * FROM users WHERE status <> 'deleted'";
    $params = [];
    if ($role) { $sql .= ' AND role = ?'; $params[] = $role; }
    if ($status) { $sql .= ' AND status = ?'; $params[] = $status; }
    if ($qstr) { $sql .= ' AND (name LIKE ? OR email LIKE ? OR npm LIKE ?)'; $like = '%' . $qstr . '%'; array_push($params, $like, $like, $like); }
    $sql .= ' ORDER BY id DESC LIMIT 200';
    ok(['users' => array_map('user_row_public', rows($sql, $params))]);
}

function h_admin_user_detail(array $p): void {
    admin_only();
    $u = row('SELECT * FROM users WHERE id = ?', [(int) $p['id']]);
    if (!$u) throw new ApiException('Pengguna tidak ditemukan', 404);
    $out = user_row_public($u);
    $out['orders_count'] = (int) scalar('SELECT COUNT(*) FROM orders WHERE customer_id = ? OR driver_id = ?', [$u['id'], $u['id']]);
    if ($u['role'] === 'driver') {
        $out['documents'] = array_map(fn($d) => ['id' => (int) $d['id'], 'doc_type' => $d['doc_type'], 'original_name' => $d['original_name'],
            'is_image' => (bool) preg_match('/\.(jpe?g|png)$/i', $d['file_path'])],
            rows('SELECT id, doc_type, original_name, file_path FROM driver_documents WHERE driver_id = ?', [$u['id']]));
        $out['penalties'] = rows('SELECT id, reason_category, reason_text, points, status, created_at FROM penalties WHERE driver_id = ? ORDER BY id DESC LIMIT 30', [$u['id']]);
        $out['completed_orders'] = (int) scalar("SELECT COUNT(*) FROM orders WHERE driver_id = ? AND status = 'completed'", [$u['id']]);
        $out['earnings'] = (int) scalar("SELECT COALESCE(SUM(p.amount),0) FROM payments p JOIN orders o ON o.id = p.order_id WHERE o.driver_id = ? AND p.status = 'paid'", [$u['id']]);
    }
    ok(['user' => $out]);
}

function h_admin_verifications(): void {
    admin_only();
    $status = in('status', 'pending');
    $list = rows("SELECT u.* FROM users u JOIN driver_profiles dp ON dp.user_id = u.id
                  WHERE u.role = 'driver' AND u.status <> 'deleted' AND dp.verification_status = ? ORDER BY u.id DESC LIMIT 100", [$status]);
    ok(['drivers' => array_map('user_row_public', $list)]);
}

function h_admin_document(array $p): void {
    admin_only();
    $d = row('SELECT * FROM driver_documents WHERE id = ?', [(int) $p['id']]);
    if (!$d) throw new ApiException('Dokumen tidak ditemukan', 404);
    $path = realpath(__DIR__ . '/../uploads/' . $d['file_path']);
    $root = realpath(__DIR__ . '/../uploads');
    if (!$path || !$root || strpos($path, $root) !== 0 || !is_file($path)) throw new ApiException('File tidak tersedia', 404);
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    header('Content-Type: ' . ($ext === 'pdf' ? 'application/pdf' : ($ext === 'png' ? 'image/png' : 'image/jpeg')));
    header('Content-Length: ' . filesize($path));
    header('Cache-Control: private, max-age=300');
    readfile($path);
    exit;
}

function h_admin_verify_driver(array $p): void {
    $a = admin_only();
    $id = (int) $p['id'];
    $decision = (string) need('decision')['decision'];
    $dp = row('SELECT * FROM driver_profiles WHERE user_id = ?', [$id]);
    if (!$dp) throw new ApiException('Driver tidak ditemukan', 404);
    if ($decision === 'approve') {
        q("UPDATE driver_profiles SET verification_status = 'approved', rejection_reason = NULL, verified_by = ?, verified_at = NOW() WHERE user_id = ?", [$a['id'], $id]);
        notify($id, 'Akun driver disetujui', 'Selamat! Akun Anda terverifikasi. Anda dapat mulai online dan menerima pesanan.', 'verification');
        admin_log((int) $a['id'], 'approve_driver', 'user', $id);
    } elseif ($decision === 'reject') {
        $reason = (string) need('reason')['reason'];
        q("UPDATE driver_profiles SET verification_status = 'rejected', rejection_reason = ?, verified_by = ?, verified_at = NOW(), is_online = 0 WHERE user_id = ?", [$reason, $a['id'], $id]);
        notify($id, 'Pendaftaran driver ditolak', $reason, 'verification');
        admin_log((int) $a['id'], 'reject_driver', 'user', $id, $reason);
    } else {
        throw new ApiException('Keputusan tidak valid', 422);
    }
    ok([], $decision === 'approve' ? 'Driver disetujui' : 'Driver ditolak');
}

function h_admin_orders(): void {
    admin_only();
    $status = in('status');
    $sql = 'SELECT id FROM orders';
    $params = [];
    if ($status === 'active') $sql .= " WHERE status IN (" . ACTIVE_STATUSES . ")";
    elseif ($status) { $sql .= ' WHERE status = ?'; $params[] = $status; }
    $sql .= ' ORDER BY id DESC LIMIT 100';
    ok(['orders' => array_map(fn($r) => order_full((int) $r['id']), rows($sql, $params))]);
}

function h_admin_cancellations(): void {
    admin_only();
    $ids = rows("SELECT id FROM orders WHERE status IN ('cancelled_customer','cancelled_driver','no_driver')
                 OR id IN (SELECT order_id FROM penalties WHERE order_id IS NOT NULL) ORDER BY id DESC LIMIT 100");
    $list = [];
    foreach ($ids as $r) {
        $o = order_full((int) $r['id']);
        $o['penalties'] = rows('SELECT id, reason_category, reason_text, points, status FROM penalties WHERE order_id = ?', [$o['id']]);
        $o['history'] = rows("SELECT status, note, created_at FROM order_status_history WHERE order_id = ? AND status LIKE 'cancelled%' ORDER BY id DESC LIMIT 3", [$o['id']]);
        $list[] = $o;
    }
    ok(['orders' => $list]);
}

function h_admin_penalties(): void {
    admin_only();
    $status = in('status');
    $sql = "SELECT pn.*, u.name AS driver_name, o.order_code FROM penalties pn JOIN users u ON u.id = pn.driver_id LEFT JOIN orders o ON o.id = pn.order_id";
    $params = [];
    if ($status) { $sql .= ' WHERE pn.status = ?'; $params[] = $status; }
    $sql .= ' ORDER BY (pn.status = \'pending_review\') DESC, pn.id DESC LIMIT 100';
    ok(['penalties' => array_map(function ($r) { $r['id'] = (int) $r['id']; $r['driver_id'] = (int) $r['driver_id']; $r['points'] = (int) $r['points']; return $r; }, rows($sql, $params))]);
}

function h_admin_penalty_review(array $p): void {
    $a = admin_only();
    $id = (int) $p['id'];
    $decision = (string) need('decision')['decision']; // violation | dismissed
    $pn = row('SELECT * FROM penalties WHERE id = ?', [$id]);
    if (!$pn) throw new ApiException('Data penalti tidak ditemukan', 404);
    if (!in_array($decision, ['violation', 'dismissed'], true)) throw new ApiException('Keputusan tidak valid', 422);
    if ($pn['status'] !== 'pending_review') throw new ApiException('Penalti ini sudah ditinjau', 409);
    $points = $decision === 'violation' ? (int) setting('penalty_points_per_violation', '1') : 0;
    q('UPDATE penalties SET status = ?, points = ?, reviewed_by = ?, reviewed_at = NOW() WHERE id = ?', [$decision, $points, $a['id'], $id]);
    $blocked = false;
    if ($points > 0) {
        q('UPDATE driver_profiles SET penalty_points = penalty_points + ? WHERE user_id = ?', [$points, $pn['driver_id']]);
        $blocked = apply_auto_block((int) $pn['driver_id']);
    }
    notify((int) $pn['driver_id'], 'Tinjauan pembatalan', $decision === 'violation'
        ? "Pembatalan Anda dinyatakan pelanggaran (+$points poin)." : 'Pembatalan Anda diterima sebagai alasan yang valid, tanpa penalti.', 'penalty');
    admin_log((int) $a['id'], 'review_penalty_' . $decision, 'penalty', $id);
    ok(['blocked' => $blocked], 'Penalti ditinjau');
}

function h_admin_reports(): void {
    admin_only();
    $days = max(1, min(90, (int) in('days', 7)));
    $series = rows("SELECT DATE(created_at) AS day, COUNT(*) AS total,
                           SUM(status = 'completed') AS completed,
                           SUM(status IN ('cancelled_customer','cancelled_driver','no_driver')) AS cancelled
                    FROM orders WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY DATE(created_at) ORDER BY day", [$days - 1]);
    $rev = [];
    foreach (rows("SELECT DATE(paid_at) AS day, SUM(amount) AS revenue FROM payments WHERE status = 'paid' AND paid_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY DATE(paid_at)", [$days - 1]) as $r) $rev[$r['day']] = (int) $r['revenue'];
    $map = [];
    foreach ($series as $s) $map[$s['day']] = $s;
    $out = [];
    for ($i = $days - 1; $i >= 0; $i--) {
        $d = date('Y-m-d', strtotime("-$i day"));
        $s = $map[$d] ?? null;
        $out[] = ['day' => $d, 'total' => (int) ($s['total'] ?? 0), 'completed' => (int) ($s['completed'] ?? 0),
                  'cancelled' => (int) ($s['cancelled'] ?? 0), 'revenue' => $rev[$d] ?? 0];
    }
    $top = rows("SELECT u.name, COUNT(*) AS trips, COALESCE(SUM(o.total_fare),0) AS total
                 FROM orders o JOIN users u ON u.id = o.driver_id JOIN payments p ON p.order_id = o.id
                 WHERE o.status = 'completed' AND p.status = 'paid' GROUP BY u.id ORDER BY trips DESC LIMIT 5");
    ok(['days' => $out, 'top_drivers' => array_map(fn($t) => ['name' => $t['name'], 'trips' => (int) $t['trips'], 'total' => (int) $t['total']], $top),
        'totals' => [
            'orders' => array_sum(array_column($out, 'total')), 'completed' => array_sum(array_column($out, 'completed')),
            'cancelled' => array_sum(array_column($out, 'cancelled')), 'revenue' => array_sum(array_column($out, 'revenue')),
        ]]);
}

function h_admin_complaints(): void {
    admin_only();
    $status = in('status');
    $sql = "SELECT c.*, u.name AS user_name, u.role AS user_role, o.order_code FROM complaints c JOIN users u ON u.id = c.user_id LEFT JOIN orders o ON o.id = c.order_id";
    $params = [];
    if ($status) { $sql .= ' WHERE c.status = ?'; $params[] = $status; }
    $sql .= " ORDER BY (c.status = 'open') DESC, c.id DESC LIMIT 100";
    ok(['complaints' => array_map(function ($r) { $r['id'] = (int) $r['id']; return $r; }, rows($sql, $params))]);
}

function h_admin_complaint_resolve(array $p): void {
    $a = admin_only();
    $id = (int) $p['id'];
    $resp = (string) need('response')['response'];
    $c = row('SELECT * FROM complaints WHERE id = ?', [$id]);
    if (!$c) throw new ApiException('Pengaduan tidak ditemukan', 404);
    q("UPDATE complaints SET status = 'resolved', response = ?, handled_by = ?, resolved_at = NOW() WHERE id = ?", [$resp, $a['id'], $id]);
    notify((int) $c['user_id'], 'Pengaduan ditanggapi', $resp, 'complaint');
    admin_log((int) $a['id'], 'resolve_complaint', 'complaint', $id);
    ok([], 'Pengaduan ditanggapi');
}

/* ----------- Super Admin ----------- */

function h_admin_user_create(): void {
    $a = super_only();
    $d = need('role', 'name', 'email', 'phone', 'password');
    if (!in_array($d['role'], ['admin', 'customer'], true)) throw new ApiException('Super Admin hanya dapat membuat akun admin atau customer', 422);
    if (!filter_var($d['email'], FILTER_VALIDATE_EMAIL)) throw new ApiException('Format email tidak valid', 422);
    if (strlen($d['password']) < 6) throw new ApiException('Password minimal 6 karakter', 422);
    if (scalar('SELECT 1 FROM users WHERE email = ?', [strtolower($d['email'])])) throw new ApiException('Email sudah terdaftar', 409);
    $npm = in('npm');
    if ($npm && scalar('SELECT 1 FROM users WHERE npm = ?', [$npm])) throw new ApiException('NPM sudah terdaftar', 409);
    q('INSERT INTO users (role, name, npm, email, phone, password_hash) VALUES (?,?,?,?,?,?)',
        [$d['role'], $d['name'], $npm, strtolower($d['email']), $d['phone'], password_hash($d['password'], PASSWORD_BCRYPT)]);
    $id = insert_id();
    admin_log((int) $a['id'], 'create_user', 'user', $id, $d['role']);
    ok(['id' => $id], 'Akun dibuat');
}

function protect_target(array $a, array $t): void {
    if ($t['role'] === 'super_admin') throw new ApiException('Akun Super Admin tidak dapat diubah dari sini', 403);
    if ((int) $t['id'] === (int) $a['id']) throw new ApiException('Tidak dapat memodifikasi akun sendiri', 403);
}

function h_admin_user_block(array $p): void {
    $a = super_only();
    $id = (int) $p['id'];
    $t = row("SELECT * FROM users WHERE id = ? AND status <> 'deleted'", [$id]);
    if (!$t) throw new ApiException('Pengguna tidak ditemukan', 404);
    protect_target($a, $t);
    $block = filter_var(in('blocked', true), FILTER_VALIDATE_BOOLEAN);
    if ($block) {
        $reason = (string) in('reason', 'Diblokir oleh administrator');
        q("UPDATE users SET status = 'blocked', blocked_reason = ?, api_token = IF(role = 'driver', api_token, NULL) WHERE id = ?", [$reason, $id]);
        if ($t['role'] === 'driver') q('UPDATE driver_profiles SET is_online = 0 WHERE user_id = ?', [$id]);
        notify($id, 'Akun diblokir', $reason, 'penalty');
        admin_log((int) $a['id'], 'block_user', 'user', $id, $reason);
    } else {
        q("UPDATE users SET status = 'active', blocked_reason = NULL WHERE id = ?", [$id]);
        if ($t['role'] === 'driver' && filter_var(in('reset_points', true), FILTER_VALIDATE_BOOLEAN))
            q('UPDATE driver_profiles SET penalty_points = 0 WHERE user_id = ?', [$id]);
        notify($id, 'Akun diaktifkan kembali', 'Blokir akun Anda telah dibuka oleh administrator.', 'penalty');
        admin_log((int) $a['id'], 'unblock_user', 'user', $id, (string) in('reason', ''));
    }
    ok([], $block ? 'Akun diblokir' : 'Blokir dibuka');
}

function h_admin_user_reset_password(array $p): void {
    $a = super_only();
    $id = (int) $p['id'];
    $t = row("SELECT * FROM users WHERE id = ? AND status <> 'deleted'", [$id]);
    if (!$t) throw new ApiException('Pengguna tidak ditemukan', 404);
    protect_target($a, $t);
    $pw = (string) need('password')['password'];
    if (strlen($pw) < 6) throw new ApiException('Password minimal 6 karakter', 422);
    q('UPDATE users SET password_hash = ?, api_token = NULL WHERE id = ?', [password_hash($pw, PASSWORD_BCRYPT), $id]);
    admin_log((int) $a['id'], 'reset_password', 'user', $id);
    ok([], 'Password direset');
}

/** Hapus akun (soft delete): data transaksi & audit tetap tersimpan, data pribadi dianonimkan. */
function h_admin_user_delete(array $p): void {
    $a = super_only();
    $id = (int) $p['id'];
    $t = row("SELECT * FROM users WHERE id = ? AND status <> 'deleted'", [$id]);
    if (!$t) throw new ApiException('Pengguna tidak ditemukan', 404);
    protect_target($a, $t);
    if (scalar("SELECT 1 FROM orders WHERE (customer_id = ? OR driver_id = ?) AND status IN (" . ACTIVE_STATUSES . ")", [$id, $id]))
        throw new ApiException('Akun masih memiliki pesanan aktif', 409);
    if ($t['role'] === 'driver' && scalar('SELECT 1 FROM driver_profiles WHERE user_id = ? AND is_online = 1', [$id]))
        throw new ApiException('Driver sedang online. Nonaktifkan (blokir) terlebih dahulu.', 409);

    foreach (rows('SELECT file_path FROM driver_documents WHERE driver_id = ?', [$id]) as $doc) {
        $f = realpath(__DIR__ . '/../uploads/' . $doc['file_path']);
        if ($f && is_file($f)) @unlink($f);
    }
    q('DELETE FROM driver_documents WHERE driver_id = ?', [$id]);
    q('DELETE FROM driver_locations WHERE driver_id = ?', [$id]);
    q("UPDATE users SET status = 'deleted', email = CONCAT('deleted_', id, '@deleted.local'), npm = NULL, phone = '-', api_token = NULL, blocked_reason = 'Akun dihapus' WHERE id = ?", [$id]);
    admin_log((int) $a['id'], 'delete_user', 'user', $id, $t['name'] . ' (' . $t['role'] . ')');
    ok([], 'Akun dihapus. Riwayat transaksi tetap tersimpan.');
}

function h_admin_inactive_drivers(): void {
    super_only();
    $days = (int) setting('inactive_driver_days', '30');
    $list = rows("SELECT u.*, dp.last_online_at,
                         (SELECT COUNT(*) FROM orders o WHERE o.driver_id = u.id) AS orders_count
                  FROM users u JOIN driver_profiles dp ON dp.user_id = u.id
                  WHERE u.role = 'driver' AND u.status <> 'deleted' AND dp.is_online = 0
                    AND (dp.last_online_at IS NULL OR dp.last_online_at < DATE_SUB(NOW(), INTERVAL ? DAY))
                  ORDER BY dp.last_online_at IS NULL DESC, dp.last_online_at ASC LIMIT 100", [$days]);
    ok(['inactive_days' => $days, 'drivers' => array_map(function ($r) {
        $o = user_row_public($r);
        $o['last_online_at'] = $r['last_online_at'];
        $o['orders_count'] = (int) $r['orders_count'];
        return $o;
    }, $list)]);
}

function h_admin_settings_get(): void {
    admin_only();
    $t = tariff();
    ok([
        'tariff' => ['base_fare' => (int) $t['base_fare'], 'per_km_rate' => (int) $t['per_km_rate']],
        'settings' => array_map(fn($r) => ['key' => $r['setting_key'], 'value' => $r['setting_value'], 'description' => $r['description']],
            rows('SELECT setting_key, setting_value, description FROM system_settings ORDER BY setting_key')),
        'tariff_history' => rows('SELECT id, base_fare, per_km_rate, is_active, created_at FROM tariff_settings ORDER BY id DESC LIMIT 10'),
    ]);
}

function h_admin_tariff_update(): void {
    $a = super_only();
    $d = need('base_fare', 'per_km_rate');
    $base = (int) $d['base_fare'];
    $km = (int) $d['per_km_rate'];
    if ($base < 0 || $km < 0 || $base > 1000000 || $km > 1000000) throw new ApiException('Nilai tarif tidak valid', 422);
    q('UPDATE tariff_settings SET is_active = 0 WHERE is_active = 1');
    q('INSERT INTO tariff_settings (base_fare, per_km_rate, is_active, created_by) VALUES (?,?,1,?)', [$base, $km, $a['id']]);
    admin_log((int) $a['id'], 'update_tariff', 'tariff', insert_id(), "Dasar Rp$base, per km Rp$km");
    ok([], 'Tarif diperbarui. Pesanan lama tidak berubah.');
}

function h_admin_setting_update(): void {
    $a = super_only();
    $d = need('key', 'value');
    $allowed = ['penalty_points_per_violation', 'penalty_block_threshold', 'order_search_timeout_sec', 'inactive_driver_days'];
    if (!in_array($d['key'], $allowed, true)) throw new ApiException('Pengaturan tidak dikenal', 422);
    if (!ctype_digit((string) $d['value']) || (int) $d['value'] < 1) throw new ApiException('Nilai harus berupa angka positif', 422);
    q('UPDATE system_settings SET setting_value = ? WHERE setting_key = ?', [(string) $d['value'], $d['key']]);
    admin_log((int) $a['id'], 'update_setting', 'setting', null, $d['key'] . ' = ' . $d['value']);
    ok([], 'Pengaturan disimpan');
}

function h_admin_logs(): void {
    super_only();
    ok(['logs' => rows("SELECT l.id, l.action, l.target_type, l.target_id, l.details, l.created_at, COALESCE(u.name, 'Sistem') AS admin_name
                        FROM admin_logs l LEFT JOIN users u ON u.id = l.admin_id ORDER BY l.id DESC LIMIT 150")]);
}
