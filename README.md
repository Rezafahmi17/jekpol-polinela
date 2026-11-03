# JEKPOL 🛵
### Aplikasi Pemesanan Ojek Online Mahasiswa Politeknik Negeri Lampung
**Versi:** 1.0  
**Platform:** Android Mobile Application  
**Framework:** Flutter (Dart)  
**Backend:** PHP (REST API)  
**Database:** MySQL (XAMPP)  
**Peta & Navigasi:** Google Maps API (Directions & Geocoding)  
**Metode Pembayaran:** Cash (Tunai)

---

## 📌 Ringkasan Implementasi PRD

Aplikasi telah dibangun secara penuh mengikuti seluruh spesifikasi dalam **Product Requirements Document (PRD)**:

1. **Role-Based Access Control (RBAC):**
   - **Customer:** Registrasi, login, pencarian lokasi kampus/peta, estimasi tarif otomatis, pemesanan ojek, pelacakan driver real-time, pembatalan sebelum driver konfirmasi, riwayat pesanan, rating & ulasan (1–5 bintang), pengaduan layanan.
   - **Driver:** Registrasi dengan unggah foto KTM & surat pernyataan bermeterai, toggle status Online/Offline, sistem penerimaan pesanan tercepat (first-come first-served) dengan transaksi database atomik, navigasi bertahap (menuju jemput → menuju tujuan) via aplikasi atau Google Maps eksternal, konfirmasi pembayaran tunai, riwayat pendapatan, dan sistem penalti.
   - **Admin:** Dashboard statistik operasional, verifikasi dokumen driver (pratinjau KTM & surat bermeterai, setujui/tolak dengan alasan), monitoring seluruh pesanan, laporan pembatalan, tinjauan penalti, penanganan pengaduan.
   - **Super Admin:** Hak akses penuh, manajemen seluruh akun (Customer, Driver, Admin), tambah akun admin, blokir/buka blokir akun (termasuk reset penalti), penghapusan akun driver nonaktif (soft delete dengan retensi audit), pengaturan tarif dasar & per kilometer, pengaturan sistem penalti & batas pelanggaran, log audit administrator.

2. **Perhitungan Tarif Otomatis:**
   $$\text{Total Tarif} = \text{Tarif Dasar} + (\text{Jarak Perjalanan} \times \text{Tarif per Kilometer})$$
   - Default: Tarif Dasar **Rp 3.000**, Tarif per km **Rp 2.500** (dapat diubah oleh Super Admin).
   - Tarif tersimpan permanen per pesanan agar tidak terpengaruh perubahan tarif di masa mendatang.

3. **Integritas Konfirmasi Pesanan Tercepat (Atomic Locks):**
   - Backend PHP menggunakan transaksi database `FOR UPDATE` sehingga pesanan hanya dapat diambil oleh satu driver tercepat dan terkunci secara aman.

4. **Simulasi Lokasi & Navigasi:**
   - Dilengkapi fallback GPS otomatis: jika dijalankan pada emulator Android dengan GPS default (di luar radius layanan Polinela), aplikasi otomatis menggunakan koordinat simulasi di area kampus Politeknik Negeri Lampung sehingga seluruh alur dapat diuji dengan lancar tanpa perlu setting mock GPS manual.

---

## 🚀 Panduan Menjalankan Aplikasi

### 1. Persiapan Backend & Database (XAMPP)

1. Buka **XAMPP Control Panel**.
2. Klik tombol **Start** pada modul **Apache** dan **MySQL**.
3. Buka terminal di folder project ini (atau terminal VS Code), lalu jalankan:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\backend\setup_backend.ps1
   ```
   *Skrip di atas akan otomatis menyalin folder API ke `C:\xampp\htdocs\gojek_polinela` dan mengimport skema database serta data seed `gojek_polinela.sql` ke MySQL.*

   > **Alternatif Manual:**
   > - Salin folder `backend/api` ke `C:\xampp\htdocs\gojek_polinela\api`.
   > - Buka browser ke `http://localhost/phpmyadmin`.
   > - Buat database `gojek_polinela` lalu import file `backend/database/gojek_polinela.sql`.

4. Uji koneksi API di browser:
   - [http://localhost/gojek_polinela/api/index.php/ping](http://localhost/gojek_polinela/api/index.php/ping)
   - Jika muncul `{"success":true,"message":"GOJEK POLINELA API aktif",...}` berarti backend telah siap!

---

### 2. Menjalankan di Android Studio (Emulator) lewat VS Code

1. Buka **Android Studio** -> buka **Virtual Device Manager** (Device Manager) -> **Jalankan emulator HP Android** Anda.
2. Buka folder project ini di **VS Code**.
3. Di sudut kanan bawah VS Code, pilih device target (misal: `Android SDK built for x86_64` atau nama emulator Anda).
4. Tekan **F5** (Run Without Debugging / Start Debugging) atau jalankan di terminal VS Code:
   ```bash
   flutter run
   ```
5. Aplikasi akan terkompilasi dan otomatis muncul di layar emulator Android Studio!

> **Catatan Koneksi Emulator ke XAMPP:**
> - Emulator Android mengakses `localhost` laptop melalui IP bawaan: `http://10.0.2.2/gojek_polinela/api/index.php` (sudah diatur sebagai default di aplikasi).
> - Jika menggunakan perangkat HP fisik via kabel/Wi-Fi: pastikan HP dan laptop terhubung ke Wi-Fi yang sama, lalu ganti URL API ke `http://IP-LAPTOP-ANDA/gojek_polinela/api/index.php` melalui ikon pengaturan server di pojok kanan atas halaman Login aplikasi.

---

## 🔑 Akun Demo Pengujian (Seed Database)

Semua akun demo di bawah ini menggunakan password: **`password123`**

| Peran (Role) | Email / Identifier | Password | Keterangan |
|---|---|---|---|
| **Customer** | `budi@student.polinela.ac.id` | `password123` | Mahasiswa pemesan ojek (NPM: 2215011001) |
| **Driver 1** | `andi@student.polinela.ac.id` | `password123` | Driver terverifikasi (Motor: Honda Beat, BE 1234 AB) |
| **Driver 2** | `rizky@student.polinela.ac.id` | `password123` | Driver terverifikasi (Motor: Yamaha Mio, BE 5678 CD) |
| **Admin** | `admin@polinela.ac.id` | `password123` | Admin operasional & verifikasi driver |
| **Super Admin** | `superadmin@polinela.ac.id` | `password123` | Super Admin (Kelola akun, tarif, penalti, audit) |

*(Di halaman Login dalam mode debug, tersedia tombol shortcut sekali klik untuk langsung mengisi kredensial akun demo di atas).*

---

## 🗺️ Pengaturan Google Maps API Key (Opsional / Rekomendasi)

Aplikasi sudah memiliki built-in fallback kalkulasi rute dan jarak. Untuk mengaktifkan tampilan visual Google Maps dan rute jalan raya resmi:

1. Dapatkan API Key dari [Google Cloud Console](https://console.cloud.google.com/) dengan mengaktifkan:
   - **Maps SDK for Android**
   - **Directions API**
   - **Geocoding API**
2. Buka file `android/gradle.properties`, lalu isi:
   ```properties
   MAPS_API_KEY=AIzaSy...KunciAnda
   ```
3. Atau jalankan aplikasi dengan flag parameter:
   ```bash
   flutter run --dart-define=MAPS_API_KEY=AIzaSy...KunciAnda
   ```

---

## 📂 Struktur Direktori Proyek

```
ojek/
├── backend/
│   ├── api/
│   │   ├── handlers/
│   │   │   ├── admin.php       # Handler dashboard, user, verifikasi, log, penalti
│   │   │   ├── auth.php        # Handler login, register, profil, notifikasi
│   │   │   └── orders.php      # Handler order, quote, alur driver, pembayaran
│   │   ├── lib/
│   │   │   └── core.php        # Koneksi database PDO, token JWT/session, helper
│   │   ├── config.php          # Konfigurasi DB MySQL XAMPP
│   │   ├── index.php           # REST API Router
│   │   └── .htaccess           # Header auth forwarding
│   ├── database/
│   │   └── gojek_polinela.sql  # Skema tabel MySQL & seed data lengkap
│   └── setup_backend.ps1       # Skrip automasi deploy ke C:\xampp\htdocs
│
├── lib/
│   ├── core/
│   │   ├── api.dart            # Klien HTTP REST API Flutter
│   │   ├── auth_provider.dart  # Provider autentikasi pengguna
│   │   ├── config.dart         # Konfigurasi app & endpoint
│   │   ├── location_service.dart # GPS Geolocator & simulasi kampus
│   │   ├── marker_factory.dart # Generator ikon kustom Google Maps
│   │   ├── models.dart         # Model User, Order, DriverInfo, dll.
│   │   ├── route_service.dart  # Google Directions API & geocoder
│   │   ├── theme.dart          # Desain UI Material 3 Hijau Polinela
│   │   └── utils.dart          # Formatter Rupiah, tanggal & perhitungan haversine
│   ├── features/
│   │   ├── admin/              # Dashboard, verifikasi driver, pengguna, order, tarif
│   │   ├── auth/               # Login & Registrasi (Customer & Driver)
│   │   ├── customer/           # Beranda, pemesanan, pelacakan real-time, aktivitas, bantuan
│   │   └── driver/             # Beranda driver online, notif pesanan masuk, alur antar, pendapatan
│   ├── widgets/                # Komponen UI bersama (Common, OrderTile, ProfileView)
│   └── main.dart               # Titik masuk aplikasi & routing RBAC
└── pubspec.yaml
```
