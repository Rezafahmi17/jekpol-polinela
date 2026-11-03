import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api.dart';
import '../../core/auth_provider.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/route_service.dart';

/// State driver: status online, pesanan masuk, pesanan aktif, lokasi GPS, ringkasan pendapatan.
class DriverController extends ChangeNotifier {
  final AuthProvider auth;
  DriverController(this.auth);

  Order? active;
  List<IncomingOrder> incoming = [];
  final Set<int> dismissed = {};
  LatLng? position;
  RouteResult? route; // rute aktif untuk peta (menuju jemput / menuju tujuan)
  Map<String, dynamic>? summary;
  int unread = 0;

  /// Dipanggil saat ada pesanan masuk baru (id) yang belum pernah ditampilkan.
  void Function(IncomingOrder order)? onNewIncoming;
  final Set<int> _seen = {};

  Timer? _timer;
  int _tick = 0;
  bool _busy = false;
  bool _disposed = false;

  SimWalker? _walker;
  String? _walkerKey;
  String? _routeKey;

  DriverInfo? get info => auth.user?.driver;
  bool get online => info?.isOnline ?? false;
  bool get canWork => auth.user != null && !auth.user!.isBlocked && (info?.approved ?? false);

  void start() {
    _timer?.cancel();
    _tick = 0;
    _loop();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loop());
    loadSummary();
  }

  Future<void> _loop() async {
    if (_busy) return;
    _busy = true;
    _tick++;
    try {
      // 1. pesanan aktif
      final r = await Api.get('orders/active');
      active = r['order'] == null ? null : Order.fromJson(r['order']);

      // 2. lokasi GPS (atau simulasi)
      if (online || active != null) {
        await _updateLocation();
      } else {
        position ??= await LocationService.current();
      }

      // 3. pesanan masuk
      if (online && active == null && canWork) {
        final d = await Api.get('driver/incoming');
        incoming = (d['orders'] as List).map((e) => IncomingOrder.fromJson(e)).toList();
        final ids = incoming.map((e) => e.id).toSet();
        dismissed.removeWhere((id) => !ids.contains(id));
        for (final o in incoming) {
          if (_seen.add(o.id) && !dismissed.contains(o.id)) {
            HapticFeedback.heavyImpact();
            SystemSound.play(SystemSoundType.alert);
            onNewIncoming?.call(o);
          }
        }
      } else {
        incoming = [];
      }

      // 4. sinkronisasi akun (blokir / verifikasi) tiap ±15 detik
      if (_tick % 5 == 0) {
        await auth.refreshUser();
        await _loadUnread();
      }
      _syncRoute();
    } catch (_) {
      // koneksi sementara terputus
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _updateLocation() async {
    final a = active;
    LatLng? target;
    String? key;
    if (a != null && a.isActive) {
      target = a.toPickup ? a.pickup : a.dest;
      key = '${a.id}:${a.toPickup}';
    }
    var p = await LocationService.current();
    if (LocationService.simulated) {
      if (target != null) {
        if (_walkerKey != key) {
          // saat mulai perjalanan ke tujuan, driver sudah berada di titik jemput
          if (!a!.toPickup) LocationService.simulatedPosition = a.pickup;
          final rr = await RouteService.route(LocationService.simulatedPosition, target);
          _walker = SimWalker(rr.points, LocationService.simulatedPosition);
          _walkerKey = key;
        }
        // hanya bergerak bila navigasi sudah dimulai
        if (a != null && (a.status == 'heading_pickup' || a.status == 'in_trip' || a.status == 'picked_up')) {
          p = _walker!.advance(48);
          LocationService.simulatedPosition = p;
        }
      } else {
        _walker = null;
        _walkerKey = null;
      }
    }
    final prev = position;
    position = p;
    if (online || active != null) {
      try {
        await Api.post('driver/location', body: {
          'lat': p.latitude,
          'lng': p.longitude,
          if (prev != null && prev != p) 'heading': LocationService.heading(prev, p),
        });
      } catch (_) {}
    }
  }

  void _syncRoute() {
    final a = active;
    if (a == null || !a.isActive) {
      route = null;
      _routeKey = null;
      return;
    }
    final key = '${a.id}:${a.toPickup}';
    if (_routeKey == key) return;
    _routeKey = key;
    final from = a.toPickup ? (position ?? a.pickup) : a.pickup;
    final to = a.toPickup ? a.pickup : a.dest;
    RouteService.route(from, to).then((r) {
      if (_routeKey == key) {
        route = r;
        _notify();
      }
    });
  }

  Future<void> _loadUnread() async {
    try {
      final r = await Api.get('notifications');
      unread = r['unread'] ?? 0;
    } catch (_) {}
  }

  Future<void> loadSummary() async {
    try {
      summary = await Api.get('driver/summary');
      _notify();
    } catch (_) {}
  }

  // ---------- aksi ----------
  Future<String> setOnline(bool value) async {
    final p = await LocationService.current();
    final r = await Api.post('driver/status', body: {'online': value, 'lat': p.latitude, 'lng': p.longitude});
    auth.setUser(AppUser.fromJson(r['user']));
    position = p;
    if (!value) incoming = [];
    _notify();
    return r['_message'] ?? '';
  }

  Future<void> accept(IncomingOrder o) async {
    await Api.post('orders/${o.id}/accept');
    incoming.removeWhere((e) => e.id == o.id);
    await _loop();
    await auth.refreshUser();
  }

  Future<void> reject(IncomingOrder o) async {
    dismissed.add(o.id);
    try {
      await Api.post('orders/${o.id}/reject');
    } catch (_) {}
    incoming.removeWhere((e) => e.id == o.id);
    _notify();
  }

  Future<void> advance(String action) async {
    final a = active;
    if (a == null) return;
    if (action == 'picked_up' && LocationService.simulated) LocationService.simulatedPosition = a.pickup;
    await Api.post('orders/${a.id}/advance', body: {'action': action});
    _routeKey = null;
    await _loop();
  }

  Future<void> confirmPayment() async {
    final a = active;
    if (a == null) return;
    await Api.post('orders/${a.id}/payment');
    await _loop();
    await auth.refreshUser();
    await loadSummary();
  }

  Future<Map<String, dynamic>> cancel(String category, String reason) async {
    final a = active;
    if (a == null) return {};
    final r = await Api.post('orders/${a.id}/driver-cancel', body: {'category': category, 'reason': reason});
    await _loop();
    await auth.refreshUser();
    await loadSummary();
    return r;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

