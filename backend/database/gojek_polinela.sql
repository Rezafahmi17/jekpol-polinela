-- ============================================================
--  GOJEK POLINELA - Skema Database MySQL (XAMPP / phpMyAdmin)
--  Import file ini lewat phpMyAdmin atau jalankan setup_backend.ps1
-- ============================================================
CREATE DATABASE IF NOT EXISTS gojek_polinela CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gojek_polinela;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS complaints, admin_logs, notifications, system_settings, tariff_settings,
  penalties, ratings, payments, order_rejections, order_status_history, orders,
  campus_locations, driver_locations, vehicles, driver_documents, driver_profiles, users;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. users -----------------------------------------------------
CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role ENUM('customer','driver','admin','super_admin') NOT NULL DEFAULT 'customer',
  name VARCHAR(120) NOT NULL,
  npm VARCHAR(30) NULL UNIQUE,
  email VARCHAR(150) NOT NULL UNIQUE,
  phone VARCHAR(25) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  api_token CHAR(64) NULL UNIQUE,
  token_expires_at DATETIME NULL,
  status ENUM('active','blocked','deleted') NOT NULL DEFAULT 'active',
  blocked_reason VARCHAR(255) NULL,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_role (role, status)
) ENGINE=InnoDB;

-- 2. driver_profiles -------------------------------------------
CREATE TABLE driver_profiles (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL UNIQUE,
  verification_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  rejection_reason VARCHAR(255) NULL,
  verified_by INT UNSIGNED NULL,
  verified_at DATETIME NULL,
  is_online TINYINT(1) NOT NULL DEFAULT 0,
  is_busy TINYINT(1) NOT NULL DEFAULT 0,
  penalty_points INT NOT NULL DEFAULT 0,
  last_online_at DATETIME NULL,
  rating_avg DECIMAL(3,2) NOT NULL DEFAULT 0,
  rating_count INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_dp_available (is_online, is_busy, verification_status)
) ENGINE=InnoDB;

-- 3. driver_documents ------------------------------------------
CREATE TABLE driver_documents (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  driver_id INT UNSIGNED NOT NULL,
  doc_type ENUM('ktm','surat_pernyataan') NOT NULL,
  file_path VARCHAR(255) NOT NULL,
  original_name VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 4. vehicles --------------------------------------------------
CREATE TABLE vehicles (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  driver_id INT UNSIGNED NOT NULL,
  brand_model VARCHAR(100) NOT NULL,
  plate_number VARCHAR(20) NOT NULL,
  color VARCHAR(40) NULL,
  FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5. driver_locations (posisi GPS terbaru) ----------------------
CREATE TABLE driver_locations (
  driver_id INT UNSIGNED PRIMARY KEY,
  lat DECIMAL(10,7) NOT NULL,
  lng DECIMAL(10,7) NOT NULL,
  heading FLOAT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6. campus_locations ------------------------------------------
CREATE TABLE campus_locations (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  category VARCHAR(40) NOT NULL DEFAULT 'kampus',
  address VARCHAR(255) NULL,
  lat DECIMAL(10,7) NOT NULL,
  lng DECIMAL(10,7) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

-- 7. orders ----------------------------------------------------
CREATE TABLE orders (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_code VARCHAR(20) NOT NULL UNIQUE,
  customer_id INT UNSIGNED NOT NULL,
  driver_id INT UNSIGNED NULL,
  pickup_address VARCHAR(255) NOT NULL,
  pickup_lat DECIMAL(10,7) NOT NULL,
  pickup_lng DECIMAL(10,7) NOT NULL,
  dest_address VARCHAR(255) NOT NULL,
  dest_lat DECIMAL(10,7) NOT NULL,
  dest_lng DECIMAL(10,7) NOT NULL,
  distance_km DECIMAL(8,2) NOT NULL,
  duration_min INT NOT NULL DEFAULT 0,
  base_fare INT NOT NULL,
  per_km_rate INT NOT NULL,
  total_fare INT NOT NULL,
  payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
  status ENUM('waiting','accepted','heading_pickup','picked_up','in_trip','completed',
              'cancelled_customer','cancelled_driver','no_driver') NOT NULL DEFAULT 'waiting',
  cancel_reason VARCHAR(255) NULL,
  search_expires_at DATETIME NULL,
  accepted_at DATETIME NULL,
  picked_up_at DATETIME NULL,
  completed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES users(id),
  FOREIGN KEY (driver_id) REFERENCES users(id),
  INDEX idx_orders_status (status),
  INDEX idx_orders_customer (customer_id),
  INDEX idx_orders_driver (driver_id)
) ENGINE=InnoDB;

-- 8. order_status_history --------------------------------------
CREATE TABLE order_status_history (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL,
  status VARCHAR(30) NOT NULL,
  note VARCHAR(255) NULL,
  actor_id INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- (pendukung) order_rejections: driver yang menolak / membatalkan pesanan ----
CREATE TABLE order_rejections (
  order_id INT UNSIGNED NOT NULL,
  driver_id INT UNSIGNED NOT NULL,
  reason ENUM('rejected','cancelled') NOT NULL DEFAULT 'rejected',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (order_id, driver_id),
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9. payments --------------------------------------------------
CREATE TABLE payments (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL UNIQUE,
  amount INT NOT NULL,
  method VARCHAR(20) NOT NULL DEFAULT 'cash',
  status ENUM('pending','paid') NOT NULL DEFAULT 'pending',
  confirmed_by INT UNSIGNED NULL,
  paid_at DATETIME NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 10. ratings --------------------------------------------------
CREATE TABLE ratings (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL UNIQUE,
  customer_id INT UNSIGNED NOT NULL,
  driver_id INT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  comment VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (customer_id) REFERENCES users(id),
  FOREIGN KEY (driver_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- 11. penalties ------------------------------------------------
CREATE TABLE penalties (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  driver_id INT UNSIGNED NOT NULL,
  order_id INT UNSIGNED NULL,
  reason_category VARCHAR(30) NOT NULL,
  reason_text VARCHAR(255) NOT NULL,
  points INT NOT NULL DEFAULT 0,
  status ENUM('pending_review','violation','dismissed') NOT NULL DEFAULT 'violation',
  reviewed_by INT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 12. tariff_settings ------------------------------------------
CREATE TABLE tariff_settings (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  base_fare INT NOT NULL,
  per_km_rate INT NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- (pendukung) system_settings: konfigurasi sistem ---------------
CREATE TABLE system_settings (
  setting_key VARCHAR(60) PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  description VARCHAR(255) NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 13. notifications --------------------------------------------
CREATE TABLE notifications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  title VARCHAR(120) NOT NULL,
  body VARCHAR(255) NOT NULL,
  type VARCHAR(30) NOT NULL DEFAULT 'info',
  order_id INT UNSIGNED NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notif_user (user_id, is_read)
) ENGINE=InnoDB;

-- 14. admin_logs -----------------------------------------------
CREATE TABLE admin_logs (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NULL,
  action VARCHAR(60) NOT NULL,
  target_type VARCHAR(30) NULL,
  target_id INT UNSIGNED NULL,
  details VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- (pendukung) complaints: pengaduan pengguna --------------------
CREATE TABLE complaints (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  order_id INT UNSIGNED NULL,
  subject VARCHAR(150) NOT NULL,
  message TEXT NOT NULL,
  status ENUM('open','resolved') NOT NULL DEFAULT 'open',
  response VARCHAR(500) NULL,
  handled_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
--  DATA AWAL (SEED)  — semua akun demo memakai password: password123
-- ============================================================
INSERT INTO tariff_settings (base_fare, per_km_rate, is_active) VALUES (3000, 2500, 1);

INSERT INTO system_settings (setting_key, setting_value, description) VALUES
 ('penalty_points_per_violation', '1', 'Poin pelanggaran untuk setiap pembatalan tanpa alasan yang diterima'),
 ('penalty_block_threshold', '3', 'Akun driver diblokir otomatis saat poin mencapai nilai ini'),
 ('order_search_timeout_sec', '120', 'Lama pencarian driver sebelum pesanan berstatus Tidak Mendapat Driver'),
 ('inactive_driver_days', '30', 'Driver dianggap tidak aktif jika tidak online selama N hari');

INSERT INTO users (id, role, name, npm, email, phone, password_hash) VALUES
 (1, 'super_admin', 'Super Admin Polinela', NULL, 'superadmin@polinela.ac.id', '081200000001', '$2y$10$ofbMm2KRYhPyfOmY6jvyKu2YOdbf45qYFYb2hVBbQKpBzH5Luu/SW'),
 (3, 'customer',    'Budi Santoso',        '2215011001', 'budi@student.polinela.ac.id',  '081200000003', '$2y$10$ofbMm2KRYhPyfOmY6jvyKu2YOdbf45qYFYb2hVBbQKpBzH5Luu/SW'),
 (4, 'driver',      'Andi Pratama',        '2115012002', 'andi@student.polinela.ac.id',  '081200000004', '$2y$10$ofbMm2KRYhPyfOmY6jvyKu2YOdbf45qYFYb2hVBbQKpBzH5Luu/SW'),
 (5, 'driver',      'Rizky Maulana',       '2115012003', 'rizky@student.polinela.ac.id', '081200000005', '$2y$10$ofbMm2KRYhPyfOmY6jvyKu2YOdbf45qYFYb2hVBbQKpBzH5Luu/SW');

INSERT INTO driver_profiles (user_id, verification_status, verified_by, verified_at) VALUES
 (4, 'approved', 1, NOW()),
 (5, 'approved', 1, NOW());

INSERT INTO vehicles (driver_id, brand_model, plate_number, color) VALUES
 (4, 'Honda Beat', 'BE 1234 AB', 'Hitam'),
 (5, 'Yamaha Mio', 'BE 5678 CD', 'Merah');

INSERT INTO campus_locations (name, category, address, lat, lng) VALUES
 ('Gerbang Utama Polinela', 'kampus', 'Jl. Soekarno Hatta No.10, Rajabasa', -5.3582140, 105.2331290),
 ('Gedung Rektorat', 'kampus', 'Kampus Polinela', -5.3590000, 105.2338000),
 ('Perpustakaan Polinela', 'kampus', 'Kampus Polinela', -5.3595000, 105.2325000),
 ('Kantin & Student Center', 'kampus', 'Kampus Polinela', -5.3601000, 105.2335000),
 ('Jurusan Teknologi Informasi', 'kampus', 'Kampus Polinela', -5.3575000, 105.2322000),
 ('Asrama / Kos Mahasiswa Rajabasa', 'hunian', 'Rajabasa, Bandar Lampung', -5.3560000, 105.2290000),
 ('Terminal Rajabasa', 'transportasi', 'Rajabasa, Bandar Lampung', -5.3636000, 105.2380000),
 ('Universitas Lampung (Unila)', 'kampus', 'Jl. Prof. Sumantri Brojonegoro', -5.3640000, 105.2440000);

INSERT INTO driver_locations (driver_id, lat, lng) VALUES
 (4, -5.3588000, 105.2340000),
 (5, -5.3570000, 105.2318000);

