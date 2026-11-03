import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'config.dart';

class Fmt {
  Fmt._();
  static final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static String rupiah(num v) => _rp.format(v);
  static String km(double v) => '${v.toStringAsFixed(v >= 10 ? 1 : 2)} km';

  static DateTime? parse(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  static String dateTime(String? s) {
    final d = parse(s);
    return d == null ? '-' : DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(d);
  }

  static String date(String? s) {
    final d = parse(s);
    return d == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(d);
  }

  static String shortDay(String? s) {
    final d = parse(s);
    return d == null ? '-' : DateFormat('EEE d', 'id_ID').format(d);
  }

  static String time(String? s) {
    final d = parse(s);
    return d == null ? '-' : DateFormat('HH:mm').format(d);
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  static String ago(String? s) {
    final d = parse(s);
    if (d == null) return 'Belum pernah';
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }
}

class Geo {
  Geo._();

  static double km(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _rad(double d) => d * math.pi / 180;

  static double bearing(LatLng a, LatLng b) {
    final y = math.sin(_rad(b.longitude - a.longitude)) * math.cos(_rad(b.latitude));
    final x = math.cos(_rad(a.latitude)) * math.sin(_rad(b.latitude)) -
        math.sin(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.cos(_rad(b.longitude - a.longitude));
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Estimasi menit tempuh bila rute Directions tidak tersedia.
  static int etaMinutes(double km) => math.max(1, (km / AppConfig.avgSpeedKmh * 60).ceil());

  static bool inServiceArea(LatLng p) => Geo.km(p, AppConfig.campusCenter) <= AppConfig.serviceRadiusKm;

  /// Titik pada jarak [meters] dari [from] menuju [to] (maks. sampai [to]).
  static LatLng step(LatLng from, LatLng to, double meters) {
    final d = km(from, to) * 1000;
    if (d <= meters || d == 0) return to;
    final f = meters / d;
    return LatLng(from.latitude + (to.latitude - from.latitude) * f, from.longitude + (to.longitude - from.longitude) * f);
  }

  static LatLngBounds bounds(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = minLat, minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // hindari bounds dengan luas nol
    if ((maxLat - minLat).abs() < 0.0005) {
      minLat -= 0.0008;
      maxLat += 0.0008;
    }
    if ((maxLng - minLng).abs() < 0.0005) {
      minLng -= 0.0008;
      maxLng += 0.0008;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  /// Decode encoded polyline Google.
  static List<LatLng> decodePolyline(String encoded) {
    final pts = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }
}

