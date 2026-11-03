<?php
// ============================================================
//  GOJEK POLINELA - Konfigurasi Backend
//  Sesuaikan jika kredensial MySQL XAMPP Anda berbeda.
// ============================================================
const DB_HOST = '127.0.0.1';
const DB_PORT = '3307';
const DB_NAME = 'gojek_polinela';
const DB_USER = 'root';
const DB_PASS = '';          // default XAMPP: kosong

const APP_TIMEZONE = 'Asia/Jakarta';
const DB_TIMEZONE_OFFSET = '+07:00';
const TOKEN_TTL_DAYS = 30;
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
const MAX_TRIP_KM = 60;      // batas jarak pemesanan (validasi server)

