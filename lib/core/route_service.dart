import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'utils.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  /// true bila Directions API tidak tersedia, sehingga jarak diperkirakan dari garis lurus.
  final bool estimated;
  const RouteResult(this.points, this.distanceKm, this.durationMin, this.estimated);
}

/// Perhitungan rute/jarak memakai Google Directions API.
/// Jika API key belum diisi atau API gagal, dipakai estimasi garis lurus × 1,3.
class RouteService {
  RouteService._();
  static final Map<String, RouteResult> _cache = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}>${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  static Future<RouteResult> route(LatLng from, LatLng to, {bool useCache = true}) async {
    final k = _key(from, to);
    if (useCache && _cache.containsKey(k)) return _cache[k]!;

    RouteResult? result;
    if (AppConfig.hasGoogleKey) {
      try {
        final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
          'origin': '${from.latitude},${from.longitude}',
          'destination': '${to.latitude},${to.longitude}',
          'mode': 'driving',
          'language': 'id',
          'key': AppConfig.googleApiKey,
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['status'] == 'OK') {
          final r = (j['routes'] as List).first as Map<String, dynamic>;
          final leg = (r['legs'] as List).first as Map<String, dynamic>;
          final meters = (leg['distance']['value'] as num).toDouble();
          final secs = (leg['duration']['value'] as num).toDouble();
          result = RouteResult(
            Geo.decodePolyline(r['overview_polyline']['points'] as String),
            meters / 1000,
            (secs / 60).ceil().clamp(1, 9999),
            false,
          );
        }
      } catch (_) {/* fallback di bawah */}
    }
    result ??= _fallback(from, to);
    if (!result.estimated) _cache[k] = result;
    return result;
  }

  static RouteResult _fallback(LatLng a, LatLng b) {
    final km = Geo.km(a, b) * 1.3;
    return RouteResult([a, b], double.parse(km.toStringAsFixed(2)), Geo.etaMinutes(km), true);
  }

  /// Koordinat dari teks alamat (Android Geocoder).
  static Future<LatLng?> geocode(String query) async {
    try {
      final l = await Geocoding().locationFromAddress(query).timeout(const Duration(seconds: 8));
      if (l.isNotEmpty) return LatLng(l.first.latitude, l.first.longitude);
    } catch (_) {}
    return null;
  }

  /// Alamat dari koordinat (Android Geocoder, tanpa API key).
  static Future<String> addressOf(LatLng p) async {
    try {
      final list = await Geocoding().placemarkFromCoordinates(p.latitude, p.longitude).timeout(const Duration(seconds: 6));
      if (list.isNotEmpty) {
        final m = list.first;
        final parts = <String>[
          if ((m.street ?? '').isNotEmpty && !(m.street!.contains('+'))) m.street!,
          if ((m.subLocality ?? '').isNotEmpty) m.subLocality!,
          if ((m.locality ?? '').isNotEmpty) m.locality!,
        ];
        if (parts.isNotEmpty) return parts.take(3).join(', ');
      }
    } catch (_) {}
    return 'Titik di peta (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})';
  }
}
