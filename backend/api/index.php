<?php
declare(strict_types=1);
require_once __DIR__ . '/lib/core.php';
require_once __DIR__ . '/handlers/auth.php';
require_once __DIR__ . '/handlers/orders.php';
require_once __DIR__ . '/handlers/admin.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }

// Tabel rute: [METHOD, pola, handler]
$routes = [
    ['GET',  'ping', 'h_ping'],
    ['GET',  'config', 'h_public_config'],
    // auth & profil
    ['POST', 'auth/register', 'h_register'],
    ['POST', 'auth/login', 'h_login'],
    ['POST', 'auth/logout', 'h_logout'],
    ['GET',  'auth/me', 'h_me'],
    ['POST', 'profile/update', 'h_update_profile'],
    ['POST', 'profile/password', 'h_change_password'],
    ['GET',  'notifications', 'h_notifications'],
    ['POST', 'notifications/read', 'h_notifications_read'],
    ['POST', 'complaints', 'h_complaint_create'],
    ['GET',  'complaints', 'h_complaints_mine'],
    // customer
    ['POST', 'orders/quote', 'h_quote'],
    ['GET',  'drivers/nearby', 'h_nearby_drivers'],
    ['POST', 'orders', 'h_order_create'],
    ['GET',  'orders/active', 'h_order_active'],
    ['GET',  'orders/history', 'h_orders_history'],
    ['GET',  'orders/{id}', 'h_order_get'],
    ['POST', 'orders/{id}/cancel', 'h_order_cancel_customer'],
    ['POST', 'orders/{id}/rate', 'h_order_rate'],
    // driver
    ['POST', 'driver/status', 'h_driver_status'],
    ['POST', 'driver/location', 'h_driver_location'],
    ['GET',  'driver/incoming', 'h_driver_incoming'],
    ['GET',  'driver/summary', 'h_driver_summary'],
    ['POST', 'orders/{id}/accept', 'h_order_accept'],
    ['POST', 'orders/{id}/reject', 'h_order_reject'],
    ['POST', 'orders/{id}/advance', 'h_order_advance'],
    ['POST', 'orders/{id}/payment', 'h_order_confirm_payment'],
    ['POST', 'orders/{id}/driver-cancel', 'h_order_driver_cancel'],
    // admin
    ['GET',  'admin/dashboard', 'h_admin_dashboard'],
    ['GET',  'admin/users', 'h_admin_users'],
    ['POST', 'admin/users', 'h_admin_user_create'],
    ['GET',  'admin/users/{id}', 'h_admin_user_detail'],
    ['POST', 'admin/users/{id}/block', 'h_admin_user_block'],
    ['POST', 'admin/users/{id}/password', 'h_admin_user_reset_password'],
    ['POST', 'admin/users/{id}/delete', 'h_admin_user_delete'],
    ['GET',  'admin/verifications', 'h_admin_verifications'],
    ['POST', 'admin/drivers/{id}/verify', 'h_admin_verify_driver'],
    ['GET',  'admin/documents/{id}', 'h_admin_document'],
    ['GET',  'admin/orders', 'h_admin_orders'],
    ['GET',  'admin/cancellations', 'h_admin_cancellations'],
    ['GET',  'admin/penalties', 'h_admin_penalties'],
    ['POST', 'admin/penalties/{id}/review', 'h_admin_penalty_review'],
    ['GET',  'admin/reports', 'h_admin_reports'],
    ['GET',  'admin/complaints', 'h_admin_complaints'],
    ['POST', 'admin/complaints/{id}/resolve', 'h_admin_complaint_resolve'],
    ['GET',  'admin/inactive-drivers', 'h_admin_inactive_drivers'],
    ['GET',  'admin/settings', 'h_admin_settings_get'],
    ['POST', 'admin/tariff', 'h_admin_tariff_update'],
    ['POST', 'admin/settings', 'h_admin_setting_update'],
    ['GET',  'admin/logs', 'h_admin_logs'],
];

try {
    $path = $_SERVER['PATH_INFO'] ?? '';
    if ($path === '') {
        $uri = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH) ?: '';
        $pos = strpos($uri, 'index.php');
        $path = $pos !== false ? substr($uri, $pos + 9) : '';
    }
    $path = trim($path, '/');
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $methodMatched = false;

    foreach ($routes as [$m, $pattern, $handler]) {
        $regex = '#^' . preg_replace('#\{(\w+)\}#', '(?P<$1>[0-9]+)', $pattern) . '$#';
        if (preg_match($regex, $path, $matches)) {
            if ($m !== $method) { $methodMatched = true; continue; }
            $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
            (new ReflectionFunction($handler))->getNumberOfParameters() > 0 ? $handler($params) : $handler();
            exit;
        }
    }
    throw new ApiException($methodMatched ? 'Method tidak diizinkan' : 'Endpoint tidak ditemukan', $methodMatched ? 405 : 404);
} catch (ApiException $e) {
    json_out(array_merge(['success' => false, 'message' => $e->getMessage()], $e->extra), $e->getCode() ?: 400);
} catch (PDOException $e) {
    error_log('DB error: ' . $e->getMessage());
    $hint = str_contains($e->getMessage(), 'Unknown database') || str_contains($e->getMessage(), 'refused')
        ? 'Database tidak dapat diakses. Pastikan MySQL XAMPP berjalan dan database sudah diimport.'
        : 'Terjadi kesalahan database';
    json_out(['success' => false, 'message' => $hint], 500);
} catch (Throwable $e) {
    error_log('Server error: ' . $e->getMessage());
    json_out(['success' => false, 'message' => 'Terjadi kesalahan server'], 500);
}

