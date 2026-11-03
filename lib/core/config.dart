import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Konfigurasi utama aplikasi GOJEK POLINELA.
class AppConfig {
  AppConfig._();

  /// Alamat API backend (XAMPP).
  /// - Emulator Android Studio : http://10.0.2.2/gojek_polinela/api/index.php
  /// - HP asli (satu Wi-Fi)    : http://IP-LAPTOP/gojek_polinela/api/index.php
  /// Dapat diubah dari dalam aplikasi (ikon pengaturan server di halaman login).
  static const String defaultBaseUrl = 'http://10.0.2.2/gojek_polinela/api/index.php';
  static String baseUrl = defaultBaseUrl;

  /// Google Maps API key (untuk Directions API / rute & jarak).
  /// Key yang SAMA juga harus diisi di android/gradle.properties (MAPS_API_KEY)
  /// agar peta Google tampil. Bisa juga dikirim lewat:
  ///   flutter run --dart-define=MAPS_API_KEY=xxxxx
  static const String googleApiKey =
      String.fromEnvironment('MAPS_API_KEY', defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY');
  static bool get hasGoogleKey => googleApiKey.isNotEmpty && !googleApiKey.startsWith('YOUR_');

  /// Titik pusat kampus Politeknik Negeri Lampung.
  static const LatLng campusCenter = LatLng(-5.358214, 105.233129);

  /// Radius layanan; jika GPS di luar radius ini (mis. emulator di California),
  /// aplikasi memakai lokasi simulasi di sekitar kampus.
  static const double serviceRadiusKm = 40;

  /// Kecepatan rata-rata untuk estimasi waktu bila Directions API tidak tersedia.
  static const double avgSpeedKmh = 25;

  static const String appName = 'JEKPOL';
  static const String appTagline = 'Ojek Online Mahasiswa Politeknik Negeri Lampung';
}

