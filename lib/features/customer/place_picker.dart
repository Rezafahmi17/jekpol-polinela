import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/route_service.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class PlaceChoice {
  final String name;
  final String address;
  final LatLng pos;
  const PlaceChoice(this.name, this.address, this.pos);
}

/// Memilih lokasi: titik kampus, lokasi saya, pencarian alamat, atau titik di peta.
class PlacePickerScreen extends StatefulWidget {
  final String title;
  final List<CampusPlace> places;
  final bool allowCurrent;
  const PlacePickerScreen({super.key, required this.title, required this.places, this.allowCurrent = false});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _q = TextEditingController();
  PlaceChoice? _searchResult;
  bool _searching = false;
  String? _searchMsg;

  List<CampusPlace> get _filtered {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return widget.places;
    return widget.places.where((p) => p.name.toLowerCase().contains(q) || (p.address ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _useCurrent() async {
    final pos = await LocationService.current();
    final addr = LocationService.simulated ? 'Lokasi simulasi di kampus Polinela' : await RouteService.addressOf(pos);
    if (!mounted) return;
    Navigator.pop(context, PlaceChoice('Lokasi saya', addr, pos));
  }

  Future<void> _searchAddress() async {
    final q = _q.text.trim();
    if (q.length < 3) return;
    setState(() {
      _searching = true;
      _searchResult = null;
      _searchMsg = null;
    });
    try {
      final list = await _geocode(q);
      if (list != null) {
        final addr = await RouteService.addressOf(list);
        setState(() => _searchResult = PlaceChoice(q, addr, list));
      } else {
        setState(() => _searchMsg = 'Alamat tidak ditemukan. Coba pilih lewat peta.');
      }
    } catch (_) {
      setState(() => _searchMsg = 'Pencarian alamat tidak tersedia. Pilih titik lewat peta.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<LatLng?> _geocode(String q) => RouteService.geocode('$q, Bandar Lampung');

  Future<void> _pickOnMap() async {
    final r = await Navigator.push<PlaceChoice>(
      context,
      MaterialPageRoute(builder: (_) => MapPickScreen(title: widget.title)),
    );
    if (r != null && mounted) Navigator.pop(context, r);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {
              _searchResult = null;
              _searchMsg = null;
            }),
            onSubmitted: (_) => _searchAddress(),
            decoration: InputDecoration(
              hintText: 'Cari lokasi atau alamat',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _q.clear())),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            if (widget.allowCurrent) _tile(Icons.my_location_rounded, AppColors.info, 'Gunakan lokasi saya', 'Berdasarkan GPS perangkat', _useCurrent),
            _tile(Icons.pin_drop_rounded, AppColors.danger, 'Pilih lewat peta', 'Geser peta untuk menentukan titik', _pickOnMap),
            if (_q.text.trim().length >= 3)
              _tile(Icons.travel_explore_rounded, AppColors.primary, 'Cari alamat "${_q.text.trim()}"', _searching ? 'Mencari...' : 'Ketuk untuk mencari di peta', _searching ? null : _searchAddress),
            if (_searchResult != null)
              _tile(Icons.place_rounded, AppColors.success, _searchResult!.name, _searchResult!.address, () => Navigator.pop(context, _searchResult)),
            if (_searchMsg != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(_searchMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
            const SectionTitle('Lokasi kampus & sekitar'),
            if (items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Tidak ada lokasi yang cocok', style: TextStyle(color: AppColors.grey))),
            for (final p in items)
              _tile(p.icon, AppColors.primary, p.name, p.address ?? 'Politeknik Negeri Lampung', () => Navigator.pop(context, PlaceChoice(p.name, p.address ?? p.name, p.pos))),
          ]),
        ),
      ]),
    );
  }

  Widget _tile(IconData icon, Color color, String title, String sub, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            onTap: onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 22)),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
          ),
        ),
      );
}

/// Pilih titik dengan menggeser peta (pin tengah).
class MapPickScreen extends StatefulWidget {
  final String title;
  const MapPickScreen({super.key, required this.title});
  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  LatLng _center = AppConfig.campusCenter;
  String _address = 'Geser peta untuk memilih titik';
  bool _loading = false;
  int _seq = 0;

  Future<void> _resolve() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final a = await RouteService.addressOf(_center);
    if (!mounted || seq != _seq) return;
    setState(() {
      _address = a;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: 16),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onCameraMove: (p) => _center = p.target,
          onCameraIdle: _resolve,
        ),
        const Center(child: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.location_on_rounded, size: 46, color: AppColors.danger))),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.place_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading ? null : () => Navigator.pop(context, PlaceChoice(_address.split(',').first, _address, _center)),
                    child: const Text('Pilih titik ini'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
