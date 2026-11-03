import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/auth_provider.dart';
import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../core/marker_factory.dart';
import '../../core/models.dart';
import '../../core/route_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import 'customer_controller.dart';
import 'place_picker.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _map;
  late final CustomerController _ctrl;

  PlaceChoice? _pickup;
  PlaceChoice? _dest;
  RouteResult? _route;
  final _noteCtrl = TextEditingController();
  bool _routing = false;
  bool _ordering = false;
  LatLng? _me;
  Timer? _meTimer;
  double _panelHeight = 300;

  // tracking
  RouteResult? _trackRoute;
  DateTime? _trackRouteAt;
  String? _trackStatus;
  int? _trackOrderId;

  BitmapDescriptor? _icPickup, _icDest, _icDriver, _icMe, _icCampus, _icNearby;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ctrl = context.read<CustomerController>();
    _ctrl.addListener(_onCtrl);
    _loadIcons();
    _initLocation();
    _meTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshMe());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    _meTimer?.cancel();
    _map?.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    final r = await Future.wait([
      MarkerFactory.icon(Icons.trip_origin_rounded, AppColors.primary),
      MarkerFactory.icon(Icons.flag_rounded, AppColors.danger),
      MarkerFactory.icon(Icons.two_wheeler_rounded, AppColors.primaryDark, width: 54),
      MarkerFactory.icon(Icons.person_rounded, AppColors.info, width: 40),
      MarkerFactory.icon(Icons.school_rounded, const Color(0xFF5B4BDB), width: 40),
      MarkerFactory.icon(Icons.two_wheeler_rounded, AppColors.grey, width: 40),
    ]);
    if (!mounted) return;
    setState(() {
      _icPickup = r[0];
      _icDest = r[1];
      _icDriver = r[2];
      _icMe = r[3];
      _icCampus = r[4];
      _icNearby = r[5];
    });
  }

  Future<void> _initLocation() async {
    await LocationService.ensurePermission();
    final p = await LocationService.current();
    if (!mounted) return;
    _me = p;
    if (_pickup == null) {
      final addr = LocationService.simulated ? 'Kampus Polinela (lokasi simulasi)' : await RouteService.addressOf(p);
      if (!mounted) return;
      setState(() => _pickup = PlaceChoice('Lokasi saya', addr, p));
    }
    if (LocationService.simulated && mounted) {
      showMsg(context, 'GPS di luar area layanan — memakai lokasi simulasi di kampus.');
    }
    _animate(p, zoom: 16);
  }

  Future<void> _refreshMe() async {
    final p = await LocationService.current();
    if (mounted) setState(() => _me = p);
  }

  void _animate(LatLng p, {double zoom = 16}) {
    _map?.animateCamera(CameraUpdate.newLatLngZoom(p, zoom));
  }

  Future<void> _fit(List<LatLng> pts) async {
    if (_map == null || pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        await _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 16));
      } else {
        await _map!.animateCamera(CameraUpdate.newLatLngBounds(Geo.bounds(pts), 70));
      }
    } catch (_) {
      // peta belum selesai layout; abaikan
    }
  }

  // ---------- reaksi terhadap perubahan pesanan ----------
  void _onCtrl() {
    final o = _ctrl.active;
    if (o == null) {
      _trackRoute = null;
      _trackStatus = null;
      _trackOrderId = null;
    } else {
      final changed = _trackOrderId != o.id || _trackStatus != o.status;
      final stale = _trackRouteAt == null || DateTime.now().difference(_trackRouteAt!) > const Duration(seconds: 20);
      if (changed || (o.driver?.location != null && stale && !o.isWaiting)) {
        _trackOrderId = o.id;
        _trackStatus = o.status;
        _updateTrackRoute(o, refit: changed);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateTrackRoute(Order o, {required bool refit}) async {
    _trackRouteAt = DateTime.now();
    LatLng from;
    LatLng to;
    if (o.isWaiting) {
      if (refit) _fit([o.pickup, o.dest]);
      return;
    }
    if (o.toPickup) {
      from = o.driver?.location ?? o.pickup;
      to = o.pickup;
    } else {
      from = o.pickup;
      to = o.dest;
    }
    final r = await RouteService.route(from, to);
    if (!mounted || _trackOrderId != o.id) return;
    setState(() => _trackRoute = r);
    if (refit) {
      _fit([if (o.driver?.location != null) o.driver!.location!, o.pickup, o.dest]);
    }
  }

  // ---------- pemilihan lokasi ----------
  Future<void> _pickDest() async {
    final r = await Navigator.push<PlaceChoice>(
      context,
      MaterialPageRoute(builder: (_) => PlacePickerScreen(title: 'Pilih tujuan', places: _ctrl.places)),
    );
    if (r == null) return;
    setState(() => _dest = r);
    _calcRoute();
  }

  Future<void> _pickPickup() async {
    final r = await Navigator.push<PlaceChoice>(
      context,
      MaterialPageRoute(builder: (_) => PlacePickerScreen(title: 'Titik penjemputan', places: _ctrl.places, allowCurrent: true)),
    );
    if (r == null) return;
    setState(() => _pickup = r);
    if (_dest != null) _calcRoute();
  }

  Future<void> _quickDest(CampusPlace p) async {
    setState(() => _dest = PlaceChoice(p.name, p.address ?? p.name, p.pos));
    _calcRoute();
  }

  Future<void> _calcRoute() async {
    if (_pickup == null || _dest == null) return;
    setState(() {
      _routing = true;
      _route = null;
    });
    final r = await RouteService.route(_pickup!.pos, _dest!.pos);
    if (!mounted) return;
    if (r.distanceKm > 60) {
      setState(() {
        _routing = false;
        _dest = null;
      });
      showMsg(context, 'Jarak terlalu jauh. Layanan hanya untuk area sekitar kampus (maks. 60 km).', error: true);
      return;
    }
    if (Geo.km(_pickup!.pos, _dest!.pos) < 0.05) {
      setState(() {
        _routing = false;
        _dest = null;
      });
      showMsg(context, 'Lokasi jemput dan tujuan terlalu dekat.', error: true);
      return;
    }
    setState(() {
      _route = r;
      _routing = false;
    });
    _fit(r.points.length > 2 ? r.points : [_pickup!.pos, _dest!.pos]);
  }

  void _clearPlan() {
    setState(() {
      _dest = null;
      _route = null;
      _routing = false;
    });
    if (_me != null) _animate(_me!);
  }

  Future<void> _order() async {
    if (_pickup == null || _dest == null || _route == null || _ordering) return;
    setState(() => _ordering = true);
    try {
      final note = _noteCtrl.text.trim();
      final basePickup = _pickup!.name == 'Lokasi saya' ? 'Lokasi saya — ${_pickup!.address}' : _pickup!.name;
      final fullPickup = note.isNotEmpty ? '$basePickup (Catatan: $note)' : basePickup;

      await _ctrl.createOrder(
        pickupAddress: fullPickup,
        pickup: _pickup!.pos,
        destAddress: _dest!.name,
        dest: _dest!.pos,
        distanceKm: _route!.distanceKm,
        durationMin: _route!.durationMin,
      );
      HapticFeedback.mediumImpact();
      _noteCtrl.clear();
      setState(() {
        _dest = null;
        _route = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showError(context, e);
      if (e.status == 409) _ctrl.poll();
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  // ---------- peta ----------
  Set<Marker> _markers(Order? active) {
    final m = <Marker>{};
    Marker mk(String id, LatLng p, BitmapDescriptor? icon, {String? title, double hue = 0, Offset anchor = const Offset(0.5, 0.5), double z = 1}) =>
        Marker(
          markerId: MarkerId(id),
          position: p,
          icon: icon ?? BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: title == null ? InfoWindow.noText : InfoWindow(title: title),
          anchor: anchor,
          zIndexInt: z.toInt(),
        );
    if (active != null) {
      m.add(mk('pickup', active.pickup, _icPickup, title: 'Penjemputan'));
      m.add(mk('dest', active.dest, _icDest, title: 'Tujuan'));
      final d = active.driver?.location;
      if (d != null) m.add(mk('driver', d, _icDriver, title: active.driver?.name, z: 5));
      return m;
    }
    m.add(mk('campus', AppConfig.campusCenter, _icCampus, title: 'Politeknik Negeri Lampung'));
    if (_me != null) m.add(mk('me', _me!, _icMe, title: 'Lokasi saya', z: 3));
    if (_dest != null) {
      if (_pickup != null) m.add(mk('pickup', _pickup!.pos, _icPickup, title: 'Penjemputan'));
      m.add(mk('dest', _dest!.pos, _icDest, title: _dest!.name));
    } else {
      for (final d in _ctrl.nearbyDrivers) {
        m.add(mk('nd${d['id']}', LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()), _icNearby, title: d['name']));
      }
    }
    return m;
  }

  Set<Polyline> _polylines(Order? active) {
    List<LatLng>? pts;
    if (active != null) {
      pts = _trackRoute?.points;
    } else if (_dest != null) {
      pts = _route?.points;
    }
    if (pts == null || pts.length < 2) return {};
    return {
      Polyline(polylineId: const PolylineId('route_bg'), points: pts, color: Colors.white, width: 9, jointType: JointType.round, startCap: Cap.roundCap, endCap: Cap.roundCap),
      Polyline(polylineId: const PolylineId('route'), points: pts, color: AppColors.primary, width: 5, jointType: JointType.round, startCap: Cap.roundCap, endCap: Cap.roundCap),
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ctrl = context.watch<CustomerController>();
    final active = ctrl.active;
    final finished = ctrl.finished;
    final planning = active == null && finished == null && _dest != null;

    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: AppConfig.campusCenter, zoom: 15.5),
        onMapCreated: (c) {
          _map = c;
          if (_me != null) _animate(_me!);
        },
        padding: EdgeInsets.only(bottom: _panelHeight + 85, top: 90),
        markers: _markers(active),
        polylines: _polylines(active),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        rotateGesturesEnabled: false,
      ),
      // header
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _header(ctrl, planning, active),
        ),
      ),
      // recenter
      Positioned(
        right: 16,
        bottom: _panelHeight + 96,
        child: FloatingActionButton.small(
          heroTag: 'recenter',
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 3,
          onPressed: () {
            if (active != null) {
              _fit([if (active.driver?.location != null) active.driver!.location!, active.pickup, active.dest]);
            } else if (_route != null && _dest != null) {
              _fit([_pickup!.pos, _dest!.pos]);
            } else if (_me != null) {
              _animate(_me!);
            }
          },
          child: const Icon(Icons.my_location_rounded),
        ),
      ),
      // panel
      Align(
        alignment: Alignment.bottomCenter,
        child: _MeasureSize(
          onChange: (s) {
            if ((s.height - _panelHeight).abs() > 2) setState(() => _panelHeight = s.height);
          },
          child: _panel(ctrl, active, finished),
        ),
      ),
    ]);
  }

  Widget _header(CustomerController ctrl, bool planning, Order? active) {
    final user = context.watch<AuthProvider>().user!;
    if (planning && active == null) {
      return Card(
        elevation: 4,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(children: [
            IconButton(onPressed: _clearPlan, icon: const Icon(Icons.arrow_back_rounded)),
            Expanded(
              child: RouteSummary(
                pickup: _pickup?.name ?? '...',
                dest: _dest?.name ?? '...',
                onTapPickup: _pickPickup,
                onTapDest: _pickDest,
              ),
            ),
          ]),
        ),
      );
    }
    return Row(children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Avatar(user.initials, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('JEKPOL', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13, letterSpacing: 0.8)),
                    const SizedBox(width: 6),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(Fmt.greeting(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.grey))),
                  ]),
                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showNotifications(ctrl),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Badge(
              isLabelVisible: ctrl.unread > 0,
              label: Text('${ctrl.unread}'),
              child: const Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.text),
            ),
          ),
        ),
      ),
    ]);
  }

  void _showNotifications(CustomerController ctrl) {
    ctrl.loadNotifications();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer<CustomerController>(
        builder: (ctx, c, _) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) => Column(children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Expanded(child: Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                if (c.unread > 0) TextButton(onPressed: c.markNotificationsRead, child: const Text('Tandai dibaca')),
              ]),
            ),
            Expanded(
              child: c.notifications.isEmpty
                  ? const EmptyState(icon: Icons.notifications_off_outlined, title: 'Belum ada notifikasi')
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: c.notifications.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final n = c.notifications[i];
                        final unread = n['is_read'] != true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: unread ? AppColors.primaryLight : AppColors.background,
                            child: Icon(Icons.notifications_rounded, color: unread ? AppColors.primary : AppColors.grey, size: 20),
                          ),
                          title: Text(n['title'], style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                          subtitle: Text('${n['body']}\n${Fmt.dateTime(n['created_at'])}'),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------- panel bawah ----------
  Widget _panel(CustomerController ctrl, Order? active, Order? finished) {
    Widget child;
    String key;
    if (finished != null) {
      key = 'fin${finished.id}';
      child = _FinishedPanel(order: finished, ctrl: ctrl, onNewOrder: () {
        ctrl.dismissFinished();
      });
    } else if (active != null) {
      key = 'act${active.isWaiting}';
      child = active.isWaiting ? _SearchingPanel(order: active, ctrl: ctrl) : _TrackingPanel(order: active);
    } else if (_dest != null) {
      key = 'plan';
      child = _planPanel(ctrl);
    } else {
      key = 'browse';
      child = _browsePanel(ctrl);
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 96),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: KeyedSubtree(key: ValueKey(key), child: child),
              ),
            ),
          ]),
        ),
      );
    }

  Widget _browsePanel(CustomerController ctrl) {
    final campus = ctrl.places.take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const Text('Mau ke mana hari ini?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      InkWell(
        onTap: _pickDest,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
          child: const Row(children: [
            Icon(Icons.search_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(child: Text('Cari lokasi tujuan', style: TextStyle(color: AppColors.grey, fontSize: 15.5))),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      InkWell(
        onTap: _pickPickup,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            const Icon(Icons.trip_origin_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Dijemput di: ${_pickup?.name ?? 'mencari lokasi...'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.grey))),
            const Text('Ubah', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
      if (campus.isNotEmpty) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: campus.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ActionChip(
              avatar: Icon(campus[i].icon, size: 16, color: AppColors.primary),
              label: Text(campus[i].name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.primaryLight,
              side: BorderSide.none,
              onPressed: () => _quickDest(campus[i]),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: ctrl.nearbyDrivers.isEmpty ? AppColors.grey : AppColors.success, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          ctrl.nearbyDrivers.isEmpty ? 'Belum ada driver online saat ini' : '${ctrl.nearbyDrivers.length} driver tersedia di sekitar kampus',
          style: const TextStyle(fontSize: 13, color: AppColors.grey, fontWeight: FontWeight.w600),
        ),
      ]),
      if (ctrl.configError != null && !ctrl.configLoaded)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(ctrl.configError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
    ]);
  }

  Widget _planPanel(CustomerController ctrl) {
    final r = _route;
    final fare = r == null ? null : ctrl.tariff.fare(r.distanceKm);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (_routing || r == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(children: [CircularProgressIndicator(), SizedBox(height: 14), Text('Menghitung rute & tarif...', style: TextStyle(color: AppColors.grey))]),
        )
      else ...[
        Row(children: [
          _metric(Icons.route_rounded, 'Jarak', Fmt.km(r.distanceKm)),
          _metric(Icons.schedule_rounded, 'Estimasi', '${r.durationMin} menit'),
          _metric(Icons.payments_rounded, 'Tarif', Fmt.rupiah(fare!), highlight: true),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.calculate_outlined, size: 18, color: AppColors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${Fmt.rupiah(ctrl.tariff.baseFare)} + ${Fmt.km(r.distanceKm)} × ${Fmt.rupiah(ctrl.tariff.perKmRate)}/km',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.grey)),
              ),
            ]),
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.payments_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Pembayaran tunai (Cash) langsung ke driver', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
            ]),
            if (r.estimated) ...[
              const SizedBox(height: 8),
              const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(child: Text('Jarak diperkirakan (Directions API belum aktif). Isi Google API key untuk jarak rute jalan akurat.', style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.3))),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            hintText: 'Catatan penjemputan (opsional, misal: "Depan pos TI")',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _ordering ? null : _order,
          icon: _ordering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.two_wheeler_rounded),
          label: Text(_ordering ? 'Memesan...' : 'Pesan Ojek • ${Fmt.rupiah(fare)}'),
        ),
      ],
    ]);
  }

  Widget _metric(IconData icon, String label, String value, {bool highlight = false}) => Expanded(
        child: Column(children: [
          Icon(icon, color: highlight ? AppColors.primary : AppColors.grey, size: 22),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: highlight ? 17 : 15, color: highlight ? AppColors.primary : AppColors.text))),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.grey)),
        ]),
      );
}

// ======================= PANEL: MENCARI DRIVER =======================
class _SearchingPanel extends StatefulWidget {
  final Order order;
  final CustomerController ctrl;
  const _SearchingPanel({required this.order, required this.ctrl});
  @override
  State<_SearchingPanel> createState() => _SearchingPanelState();
}

class _SearchingPanelState extends State<_SearchingPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await confirm(context, 'Batalkan pesanan?', 'Pencarian driver akan dihentikan.', confirmText: 'Ya, batalkan', cancelText: 'Tidak', danger: true);
    if (!ok) return;
    try {
      await widget.ctrl.cancelActive();
      if (mounted) showMsg(context, 'Pesanan dibatalkan');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      const Center(
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 3.5, color: AppColors.primary),
              Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Mencari driver terdekat...', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Pesanan dikirim ke semua driver online. Driver tercepat yang konfirmasi akan mengambil pesanan Anda.',
          textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 13, height: 1.4)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          RouteSummary(pickup: o.pickupAddress, dest: o.destAddress),
          const Divider(height: 18),
          Row(children: [
            Text('${Fmt.km(o.distanceKm)} • ${o.code}', style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
            const Spacer(),
            Text(Fmt.rupiah(o.totalFare), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
        onPressed: _cancel,
        child: const Text('Batalkan Pesanan'),
      ),
    ]);
  }
}

// ======================= PANEL: TRACKING =======================
class _TrackingPanel extends StatelessWidget {
  final Order order;
  const _TrackingPanel({required this.order});

  int get _step => switch (order.status) { 'accepted' => 0, 'heading_pickup' => 1, 'picked_up' || 'in_trip' => 2, _ => 0 };

  String get _headline => switch (order.status) {
        'accepted' => 'Driver menerima pesanan',
        'heading_pickup' => 'Driver menuju lokasi Anda',
        'picked_up' || 'in_trip' => 'Dalam perjalanan ke tujuan',
        _ => order.statusLabel,
      };

  int? get _eta {
    final d = order.driver?.location;
    if (d == null) return null;
    final target = order.toPickup ? order.pickup : order.dest;
    return Geo.etaMinutes(Geo.km(d, target) * 1.3);
  }

  Future<void> _call(BuildContext context) async {
    final phone = order.driver?.phone;
    if (phone == null) return;
    final ok = await launchUrl(Uri.parse('tel:$phone'));
    if (!ok && context.mounted) showMsg(context, 'Tidak dapat membuka aplikasi telepon', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final d = order.driver;
    final eta = _eta;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: order.statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(order.toPickup ? Icons.two_wheeler_rounded : Icons.flag_rounded, color: order.statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_headline, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(order.toPickup ? 'Menjemput Anda' : 'Menuju tujuan', style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
          ]),
        ),
        if (eta != null) StatusChip('±$eta mnt', AppColors.info, icon: Icons.schedule_rounded),
      ]),
      const SizedBox(height: 14),
      _Steps(current: _step),
      const SizedBox(height: 14),
      if (d != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Avatar(d.name.isEmpty ? '?' : d.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase(), size: 50, bg: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 2),
                  Text(d.ratingCount == 0 ? 'Baru' : d.ratingAvg.toStringAsFixed(1), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Flexible(child: Text('${d.vehicle ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.grey))),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.greyLight)),
                child: Text(d.plate ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 13)),
              ),
            ]),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => _call(context),
              icon: const Icon(Icons.call_rounded, size: 20),
            ),
          ]),
        ),
      const SizedBox(height: 12),
      RouteSummary(pickup: order.pickupAddress, dest: order.destAddress),
      const Divider(height: 22),
      Row(children: [
        const Icon(Icons.payments_outlined, size: 20, color: AppColors.grey),
        const SizedBox(width: 8),
        const Expanded(child: Text('Bayar tunai ke driver', style: TextStyle(color: AppColors.grey))),
        Text(Fmt.rupiah(order.totalFare), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primary)),
      ]),
    ]);
  }
}

class _Steps extends StatelessWidget {
  final int current;
  const _Steps({required this.current});
  @override
  Widget build(BuildContext context) {
    const labels = ['Diterima', 'Menjemput', 'Perjalanan', 'Tiba'];
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (i <= current ? AppColors.primary : AppColors.greyLight))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.primary : Colors.white,
                  border: Border.all(color: i <= current ? AppColors.primary : AppColors.greyLight, width: 2),
                ),
                child: i < current ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
              ),
              Expanded(child: Container(height: 3, color: i == labels.length - 1 ? Colors.transparent : (i < current ? AppColors.primary : AppColors.greyLight))),
            ]),
            const SizedBox(height: 6),
            Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: i == current ? FontWeight.w800 : FontWeight.w500, color: i <= current ? AppColors.primaryDark : AppColors.grey)),
          ]),
        ),
      ],
    ]);
  }
}

// ======================= PANEL: SELESAI / DIBATALKAN =======================
class _FinishedPanel extends StatefulWidget {
  final Order order;
  final CustomerController ctrl;
  final VoidCallback onNewOrder;
  const _FinishedPanel({required this.order, required this.ctrl, required this.onNewOrder});
  @override
  State<_FinishedPanel> createState() => _FinishedPanelState();
}

class _FinishedPanelState extends State<_FinishedPanel> {
  int _stars = 5;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.ctrl.rate(widget.order.id, _stars, _comment.text.trim());
      if (!mounted) return;
      showMsg(context, 'Terima kasih atas penilaian Anda!');
      widget.onNewOrder();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (!o.isCompleted) {
      final msg = switch (o.status) {
        'no_driver' => 'Belum ada driver yang menerima pesanan. Silakan coba lagi sebentar lagi.',
        'cancelled_driver' => 'Driver membatalkan perjalanan${o.cancelReason == null ? '' : ': ${o.cancelReason}'}',
        _ => 'Pesanan telah dibatalkan.',
      };
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 4),
        Icon(o.status == 'no_driver' ? Icons.search_off_rounded : Icons.cancel_rounded, size: 56, color: AppColors.danger),
        const SizedBox(height: 8),
        Text(o.statusLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey, height: 1.4)),
        const SizedBox(height: 18),
        FilledButton(onPressed: widget.onNewOrder, child: const Text('Pesan Lagi')),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.check_circle_rounded, size: 52, color: AppColors.success),
      const SizedBox(height: 6),
      const Text('Perjalanan selesai!', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Text('Bayar tunai kepada driver', style: TextStyle(color: AppColors.primaryDark, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(Fmt.rupiah(o.totalFare), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
          Text('${Fmt.km(o.distanceKm)} • ${o.code}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 14),
      Text('Beri nilai untuk ${o.driver?.name ?? 'driver'}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => setState(() => _stars = i),
            icon: AnimatedScale(
              scale: i <= _stars ? 1.12 : 1,
              duration: const Duration(milliseconds: 150),
              child: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 38, color: AppColors.warning),
            ),
          ),
      ]),
      TextField(
        controller: _comment,
        maxLines: 2,
        maxLength: 200,
        decoration: const InputDecoration(hintText: 'Tulis ulasan (opsional)', counterText: ''),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _sending ? null : widget.onNewOrder, child: const Text('Lewati'))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: FilledButton(onPressed: _sending ? null : _submit, child: _sending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Kirim Rating'))),
      ]),
    ]);
  }
}

/// Mengukur tinggi child agar padding peta menyesuaikan panel bawah.
class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;
  const _MeasureSize({required this.child, required this.onChange});
  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();
  Size? _old;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      if (_old != box.size) {
        _old = box.size;
        widget.onChange(box.size);
      }
    });
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

