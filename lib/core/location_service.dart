import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'config.dart';
import 'utils.dart';

/// Menelusuri polyline secara bertahap (dipakai untuk simulasi pergerakan driver di emulator).
class SimWalker {
  final List<LatLng> path;
  int _idx;
  LatLng pos;

  SimWalker(this.path, this.pos) : _idx = 0 {
    double best = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final d = Geo.km(pos, path[i]);
      if (d < best) {
        best = d;
        _idx = i;
      }
    }
  }

  LatLng advance(double meters) {
    var remaining = meters;
    while (remaining > 0 && _idx < path.length) {
      final next = path[_idx];
      final d = Geo.km(pos, next) * 1000;
      if (d <= remaining) {
        pos = next;
        remaining -= d;
        _idx++;
      } else {
        pos = Geo.step(pos, next, remaining);
        remaining = 0;
      }
    }
    return pos;
  }
}

/// Akses GPS. Bila GPS tidak tersedia / di luar area layanan (mis. emulator default di California),
/// dipakai lokasi simulasi di sekitar kampus agar aplikasi tetap dapat diuji.
class LocationService {
  LocationService._();

  static bool simulated = false;
  static LatLng _sim = const LatLng(-5.3592, 105.2336);
  static bool _denied = false;

  static LatLng get simulatedPosition => _sim;
  static set simulatedPosition(LatLng p) => _sim = p;

  static Future<bool> ensurePermission({bool ask = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && ask) p = await Geolocator.requestPermission();
      _denied = p == LocationPermission.denied || p == LocationPermission.deniedForever;
      return !_denied;
    } catch (_) {
      return false;
    }
  }

  static Future<LatLng> current() async {
    if (!_denied || await ensurePermission(ask: false)) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
        );
        final ll = LatLng(pos.latitude, pos.longitude);
        if (Geo.inServiceArea(ll)) {
          simulated = false;
          return ll;
        }
      } catch (_) {}
    }
    simulated = true;
    return _sim;
  }

  /// Arah gerak (derajat), hanya tersedia dari GPS asli.
  static double heading(LatLng from, LatLng to) => Geo.bearing(from, to);

  static LatLng get campus => AppConfig.campusCenter;
}

