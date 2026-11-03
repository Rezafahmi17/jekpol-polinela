import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'theme.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class DriverInfo {
  final String verificationStatus; // pending | approved | rejected
  final String? rejectionReason;
  final bool isOnline;
  final bool isBusy;
  final int penaltyPoints;
  final int penaltyThreshold;
  final double ratingAvg;
  final int ratingCount;
  final String? vehicle;
  final String? plate;
  final String? vehicleColor;

  DriverInfo({
    required this.verificationStatus,
    this.rejectionReason,
    required this.isOnline,
    required this.isBusy,
    required this.penaltyPoints,
    required this.penaltyThreshold,
    required this.ratingAvg,
    required this.ratingCount,
    this.vehicle,
    this.plate,
    this.vehicleColor,
  });

  bool get approved => verificationStatus == 'approved';

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
        verificationStatus: j['verification_status'] ?? 'pending',
        rejectionReason: j['rejection_reason'],
        isOnline: j['is_online'] == true,
        isBusy: j['is_busy'] == true,
        penaltyPoints: _i(j['penalty_points']),
        penaltyThreshold: _i(j['penalty_threshold']) == 0 ? 3 : _i(j['penalty_threshold']),
        ratingAvg: _d(j['rating_avg']),
        ratingCount: _i(j['rating_count']),
        vehicle: j['brand_model'],
        plate: j['plate_number'],
        vehicleColor: j['color'],
      );
}

class AppUser {
  final int id;
  final String role; // customer | driver | admin | super_admin
  final String name;
  final String? npm;
  final String email;
  final String phone;
  final String status; // active | blocked
  final String? blockedReason;
  final DriverInfo? driver;

  AppUser({
    required this.id,
    required this.role,
    required this.name,
    this.npm,
    required this.email,
    required this.phone,
    required this.status,
    this.blockedReason,
    this.driver,
  });

  bool get isBlocked => status == 'blocked';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  String get roleLabel => const {
        'customer': 'Customer',
        'driver': 'Driver',
        'admin': 'Admin',
        'super_admin': 'Super Admin',
      }[role]!;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _i(j['id']),
        role: j['role'],
        name: j['name'] ?? '',
        npm: j['npm'],
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        status: j['status'] ?? 'active',
        blockedReason: j['blocked_reason'],
        driver: j['driver'] is Map<String, dynamic> ? DriverInfo.fromJson(j['driver']) : null,
      );
}

class CampusPlace {
  final int id;
  final String name;
  final String category;
  final String? address;
  final LatLng pos;
  CampusPlace({required this.id, required this.name, required this.category, this.address, required this.pos});

  factory CampusPlace.fromJson(Map<String, dynamic> j) => CampusPlace(
        id: _i(j['id']),
        name: j['name'],
        category: j['category'] ?? 'kampus',
        address: j['address'],
        pos: LatLng(_d(j['lat']), _d(j['lng'])),
      );

  IconData get icon => switch (category) {
        'hunian' => Icons.home_work_rounded,
        'transportasi' => Icons.directions_bus_rounded,
        _ => Icons.school_rounded,
      };
}

class Tariff {
  final int baseFare;
  final int perKmRate;
  const Tariff(this.baseFare, this.perKmRate);

  /// Total Tarif = Tarif Dasar + (Jarak × Tarif per Km), dibulatkan ke Rp100 (sama dengan server).
  int fare(double km) => (((baseFare + km * perKmRate) / 100).round() * 100);

  factory Tariff.fromJson(Map<String, dynamic> j) => Tariff(_i(j['base_fare']), _i(j['per_km_rate']));
}

class DriverBrief {
  final int id;
  final String name;
  final String? phone;
  final String? vehicle;
  final String? plate;
  final double ratingAvg;
  final int ratingCount;
  final LatLng? location;
  DriverBrief({
    required this.id,
    required this.name,
    this.phone,
    this.vehicle,
    this.plate,
    required this.ratingAvg,
    required this.ratingCount,
    this.location,
  });

  factory DriverBrief.fromJson(Map<String, dynamic> j) {
    final loc = j['location'];
    return DriverBrief(
      id: _i(j['id']),
      name: j['name'] ?? '',
      phone: j['phone'],
      vehicle: j['vehicle'],
      plate: j['plate_number'],
      ratingAvg: _d(j['rating_avg']),
      ratingCount: _i(j['rating_count']),
      location: loc is Map<String, dynamic> ? LatLng(_d(loc['lat']), _d(loc['lng'])) : null,
    );
  }
}

class Order {
  final int id;
  final String code;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final int? driverId;
  final String pickupAddress;
  final LatLng pickup;
  final String destAddress;
  final LatLng dest;
  final double distanceKm;
  final int durationMin;
  final int totalFare;
  final String paymentMethod;
  final String paymentStatus; // pending | paid
  final String status;
  final String statusLabel;
  final String? cancelReason;
  final String createdAt;
  final String? completedAt;
  final bool rated;
  final DriverBrief? driver;
  final List<Map<String, dynamic>> history;

  Order({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.driverId,
    required this.pickupAddress,
    required this.pickup,
    required this.destAddress,
    required this.dest,
    required this.distanceKm,
    required this.durationMin,
    required this.totalFare,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.statusLabel,
    this.cancelReason,
    required this.createdAt,
    this.completedAt,
    required this.rated,
    this.driver,
    this.history = const [],
  });

  static const activeStatuses = {'waiting', 'accepted', 'heading_pickup', 'picked_up', 'in_trip'};
  bool get isActive => activeStatuses.contains(status);
  bool get isWaiting => status == 'waiting';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled_customer' || status == 'cancelled_driver' || status == 'no_driver';
  bool get isPaid => paymentStatus == 'paid';
  bool get toPickup => status == 'accepted' || status == 'heading_pickup';
  bool get inTrip => status == 'in_trip' || status == 'picked_up';

  Color get statusColor => switch (status) {
        'waiting' => AppColors.warning,
        'accepted' || 'heading_pickup' => AppColors.info,
        'picked_up' || 'in_trip' => AppColors.primary,
        'completed' => AppColors.success,
        _ => AppColors.danger,
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _i(j['id']),
        code: j['order_code'] ?? '',
        customerId: _i(j['customer_id']),
        customerName: j['customer_name'] ?? '',
        customerPhone: j['customer_phone'],
        driverId: j['driver_id'] == null ? null : _i(j['driver_id']),
        pickupAddress: j['pickup_address'] ?? '',
        pickup: LatLng(_d(j['pickup_lat']), _d(j['pickup_lng'])),
        destAddress: j['dest_address'] ?? '',
        dest: LatLng(_d(j['dest_lat']), _d(j['dest_lng'])),
        distanceKm: _d(j['distance_km']),
        durationMin: _i(j['duration_min']),
        totalFare: _i(j['total_fare']),
        paymentMethod: j['payment_method'] ?? 'cash',
        paymentStatus: j['payment_status'] ?? 'pending',
        status: j['status'] ?? 'waiting',
        statusLabel: j['status_label'] ?? '',
        cancelReason: j['cancel_reason'],
        createdAt: j['created_at'] ?? '',
        completedAt: j['completed_at'],
        rated: j['rated'] == true,
        driver: j['driver'] is Map<String, dynamic> ? DriverBrief.fromJson(j['driver']) : null,
        history: (j['history'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const [],
      );
}

class IncomingOrder {
  final int id;
  final String code;
  final String customerName;
  final String pickupAddress;
  final LatLng pickup;
  final String destAddress;
  final LatLng dest;
  final double distanceKm;
  final int durationMin;
  final int totalFare;
  final double? pickupDistanceKm;
  final int secondsLeft;
  IncomingOrder({
    required this.id,
    required this.code,
    required this.customerName,
    required this.pickupAddress,
    required this.pickup,
    required this.destAddress,
    required this.dest,
    required this.distanceKm,
    required this.durationMin,
    required this.totalFare,
    this.pickupDistanceKm,
    required this.secondsLeft,
  });

  factory IncomingOrder.fromJson(Map<String, dynamic> j) => IncomingOrder(
        id: _i(j['id']),
        code: j['order_code'] ?? '',
        customerName: j['customer_name'] ?? '',
        pickupAddress: j['pickup_address'] ?? '',
        pickup: LatLng(_d(j['pickup_lat']), _d(j['pickup_lng'])),
        destAddress: j['dest_address'] ?? '',
        dest: LatLng(_d(j['dest_lat']), _d(j['dest_lng'])),
        distanceKm: _d(j['distance_km']),
        durationMin: _i(j['duration_min']),
        totalFare: _i(j['total_fare']),
        pickupDistanceKm: j['pickup_distance_km'] == null ? null : _d(j['pickup_distance_km']),
        secondsLeft: _i(j['seconds_left']),
      );
}

