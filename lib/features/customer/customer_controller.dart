import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api.dart';
import '../../core/models.dart';

/// State & polling pesanan aktif customer (Beranda dan Aktivitas memakai sumber yang sama).
class CustomerController extends ChangeNotifier {
  Order? active;

  /// Pesanan yang baru berakhir (selesai/dibatalkan/tidak dapat driver) dan belum ditutup customer.
  Order? finished;

  List<Map<String, dynamic>> nearbyDrivers = [];
  List<CampusPlace> places = [];
  Tariff tariff = const Tariff(3000, 2500);
  List<Map<String, dynamic>> notifications = [];
  int unread = 0;
  bool configLoaded = false;
  String? configError;

  Timer? _timer;
  int _tick = 0;
  int? _trackedId;
  bool _busy = false;
  bool _disposed = false;

  void start() {
    loadConfig();
    poll();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
  }

  Future<void> loadConfig() async {
    try {
      final r = await Api.get('config');
      tariff = Tariff.fromJson(r['tariff']);
      places = (r['campus_locations'] as List).map((e) => CampusPlace.fromJson(e)).toList();
      configLoaded = true;
      configError = null;
    } catch (e) {
      configError = e.toString();
    }
    _notify();
  }

  Future<void> poll() async {
    if (_busy) return;
    _busy = true;
    _tick++;
    try {
      final r = await Api.get('orders/active');
      final o = r['order'] == null ? null : Order.fromJson(r['order']);
      if (o != null) {
        _trackedId = o.id;
        finished = null;
        active = o;
      } else {
        if (_trackedId != null) {
          final id = _trackedId!;
          _trackedId = null;
          try {
            final d = await Api.get('orders/$id');
            final fo = Order.fromJson(d['order']);
            if (!fo.isActive) finished = fo;
          } catch (_) {}
        }
        active = null;
        if (_tick % 3 == 1) {
          try {
            final d = await Api.get('drivers/nearby');
            nearbyDrivers = (d['drivers'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          } catch (_) {}
        }
      }
      if (_tick % 4 == 1) await loadNotifications(silent: true);
      if (!configLoaded) await loadConfig();
    } catch (_) {
      // koneksi sementara terputus; coba lagi pada tick berikutnya
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> loadNotifications({bool silent = false}) async {
    try {
      final r = await Api.get('notifications');
      notifications = (r['notifications'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      unread = r['unread'] ?? 0;
      if (!silent) _notify();
    } catch (_) {}
  }

  Future<void> markNotificationsRead() async {
    try {
      await Api.post('notifications/read');
      unread = 0;
      notifications = notifications.map((n) => {...n, 'is_read': true}).toList();
      _notify();
    } catch (_) {}
  }

  Future<Order> createOrder({
    required String pickupAddress,
    required LatLng pickup,
    required String destAddress,
    required LatLng dest,
    required double distanceKm,
    required int durationMin,
  }) async {
    final r = await Api.post('orders', body: {
      'pickup_address': pickupAddress,
      'pickup_lat': pickup.latitude,
      'pickup_lng': pickup.longitude,
      'dest_address': destAddress,
      'dest_lat': dest.latitude,
      'dest_lng': dest.longitude,
      'distance_km': distanceKm,
      'duration_min': durationMin,
    });
    final o = Order.fromJson(r['order']);
    _trackedId = o.id;
    active = o;
    finished = null;
    _notify();
    return o;
  }

  Future<void> cancelActive({String? reason}) async {
    final o = active;
    if (o == null) return;
    await Api.post('orders/${o.id}/cancel', body: {'reason': reason ?? 'Dibatalkan oleh customer'});
    await poll();
  }

  Future<void> rate(int orderId, int stars, String comment) async {
    await Api.post('orders/$orderId/rate', body: {'rating': stars, 'comment': comment});
  }

  void dismissFinished() {
    finished = null;
    _notify();
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

