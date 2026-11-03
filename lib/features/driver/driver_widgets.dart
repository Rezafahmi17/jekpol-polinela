import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import 'driver_controller.dart';

/// Membuka navigasi Google Maps (aplikasi eksternal) menuju [to].
/// Menyertakan titik asal (origin) di sekitar kampus agar di Emulator tidak dianggap dari California.
Future<void> openExternalNavigation(BuildContext context, LatLng to, {LatLng? from}) async {
  final origin = from ?? LocationService.simulatedPosition;
  final dirWeb = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${to.latitude},${to.longitude}&travelmode=driving',
  );
  try {
    if (await launchUrl(dirWeb, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  final nav = Uri.parse('google.navigation:q=${to.latitude},${to.longitude}&mode=d');
  try {
    if (await launchUrl(nav, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted) showMsg(context, 'Aplikasi Google Maps tidak tersedia. Ikuti rute pada peta di dalam aplikasi.', error: true);
}

// ======================= PESANAN MASUK =======================
Future<void> showIncomingOrderSheet(BuildContext context, DriverController ctrl, IncomingOrder order, {VoidCallback? onAccepted}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    builder: (ctx) => ChangeNotifierProvider.value(value: ctrl, child: _IncomingSheet(order: order, onAccepted: onAccepted)),
  );
  // ditutup tanpa memilih → jangan munculkan otomatis lagi (tetap dapat dibuka dari beranda)
  ctrl.dismissed.add(order.id);
}

class _IncomingSheet extends StatefulWidget {
  final IncomingOrder order;
  final VoidCallback? onAccepted;
  const _IncomingSheet({required this.order, this.onAccepted});
  @override
  State<_IncomingSheet> createState() => _IncomingSheetState();
}

class _IncomingSheetState extends State<_IncomingSheet> {
  late int _left = widget.order.secondsLeft;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = (_left - 1).clamp(0, 9999));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept(DriverController ctrl) async {
    setState(() => _busy = true);
    try {
      await ctrl.accept(widget.order);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAccepted?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(e.code == 'ORDER_TAKEN' ? 'Pesanan sudah diambil driver lain' : e.message),
        backgroundColor: AppColors.danger,
      ));
      if (e.status == 409) nav.pop();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverController>();
    final o = widget.order;
    final stillThere = ctrl.incoming.any((e) => e.id == o.id);
    if (!stillThere && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
          showMsg(context, 'Pesanan sudah diambil driver lain atau kedaluwarsa', error: true);
        }
      });
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Pesanan baru!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: o.secondsLeft == 0 ? 0 : _left / o.secondsLeft.clamp(1, 9999), strokeWidth: 4, color: _left < 20 ? AppColors.danger : AppColors.primary, backgroundColor: AppColors.greyLight),
                Text('$_left', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.person_rounded, size: 18, color: AppColors.grey),
                const SizedBox(width: 8),
                Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (o.pickupDistanceKm != null) StatusChip('${Fmt.km(o.pickupDistanceKm!)} dari Anda', AppColors.info, icon: Icons.near_me_rounded),
              ]),
              const Divider(height: 22),
              RouteSummary(pickup: o.pickupAddress, dest: o.destAddress),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _stat('Jarak', Fmt.km(o.distanceKm))),
            Expanded(child: _stat('Estimasi', '${o.durationMin == 0 ? Geo.etaMinutes(o.distanceKm) : o.durationMin} mnt')),
            Expanded(child: _stat('Pendapatan', Fmt.rupiah(o.totalFare), highlight: true)),
          ]),
          const SizedBox(height: 4),
          const Center(child: Text('Pembayaran tunai', style: TextStyle(color: AppColors.grey, fontSize: 12))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                onPressed: _busy
                    ? null
                    : () async {
                        await ctrl.reject(o);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Tolak'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _busy || _left == 0 ? null : () => _accept(ctrl),
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Terima Pesanan'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, {bool highlight = false}) => Column(children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: highlight ? 20 : 16, color: highlight ? AppColors.primary : AppColors.text))),
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
      ]);
}

// ======================= KARTU PESANAN AKTIF =======================
class DriverOrderCard extends StatelessWidget {
  final Order order;
  final bool compact;
  const DriverOrderCard({super.key, required this.order, this.compact = false});

  String get _title => switch (order.status) {
        'accepted' => 'Pesanan diterima',
        'heading_pickup' => 'Menuju lokasi penjemputan',
        'picked_up' || 'in_trip' => 'Mengantar ke tujuan',
        'completed' => 'Perjalanan selesai',
        _ => order.statusLabel,
      };

  Future<void> _run(BuildContext context, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<DriverController>();
    final o = order;

    if (o.isCompleted && !o.isPaid) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.payments_rounded, size: 46, color: AppColors.success),
        const SizedBox(height: 8),
        const Text('Terima pembayaran tunai', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(Fmt.rupiah(o.totalFare), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
            Text('dari ${o.customerName} • ${o.code}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 14),
        LoadingButton(
          label: 'Konfirmasi Pembayaran Diterima',
          icon: Icons.check_circle_rounded,
          onPressed: () => _run(context, () async {
            await ctrl.confirmPayment();
            if (context.mounted) showMsg(context, 'Pembayaran tunai dikonfirmasi. Terima kasih!');
          }),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: o.statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(o.toPickup ? Icons.person_pin_circle_rounded : Icons.flag_rounded, color: o.statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(o.code, style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
          ]),
        ),
        StatusChip(o.statusLabel, o.statusColor),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Row(children: [
            Avatar(o.customerName.isEmpty ? '?' : o.customerName[0].toUpperCase(), size: 40, bg: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${Fmt.km(o.distanceKm)} • ${Fmt.rupiah(o.totalFare)} tunai', style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
              ]),
            ),
            if (o.customerPhone != null)
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => launchUrl(Uri.parse('tel:${o.customerPhone}')),
                icon: const Icon(Icons.call_rounded, size: 20),
              ),
          ]),
          const Divider(height: 20),
          RouteSummary(pickup: o.pickupAddress, dest: o.destAddress),
        ]),
      ),
      const SizedBox(height: 14),
      ..._actions(context, ctrl),
    ]);
  }

  List<Widget> _actions(BuildContext context, DriverController ctrl) {
    final o = order;
    final cancel = TextButton(
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      onPressed: () => showCancelDialog(context, ctrl),
      child: const Text('Batalkan pesanan'),
    );
    switch (o.status) {
      case 'accepted':
        return [
          LoadingButton(
            label: 'Mulai Navigasi ke Penjemputan',
            icon: Icons.navigation_rounded,
            onPressed: () => _run(context, () async {
              await ctrl.advance('start_pickup');
              if (context.mounted) await openExternalNavigation(context, o.pickup, from: ctrl.position ?? o.pickup);
            }),
          ),
          cancel,
        ];
      case 'heading_pickup':
        return [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => openExternalNavigation(context, o.pickup, from: ctrl.position ?? o.pickup),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigasi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: LoadingButton(
                label: 'Customer Dijemput',
                icon: Icons.how_to_reg_rounded,
                onPressed: () => _run(context, () async {
                  if (!await confirm(context, 'Konfirmasi penjemputan', 'Pastikan ${o.customerName} sudah naik ke motor Anda.', confirmText: 'Sudah dijemput', cancelText: 'Belum')) return;
                  await ctrl.advance('picked_up');
                }),
              ),
            ),
          ]),
          cancel,
        ];
      case 'picked_up':
      case 'in_trip':
        return [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => openExternalNavigation(context, o.dest, from: ctrl.position ?? o.pickup),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigasi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: LoadingButton(
                label: 'Selesaikan Perjalanan',
                icon: Icons.flag_rounded,
                onPressed: () => _run(context, () async {
                  if (!await confirm(context, 'Selesaikan perjalanan?', 'Pastikan Anda sudah tiba di tujuan: ${o.destAddress}', confirmText: 'Selesaikan', cancelText: 'Belum')) return;
                  await ctrl.advance('complete');
                }),
              ),
            ),
          ]),
          cancel,
        ];
      default:
        return [];
    }
  }
}

// ======================= PEMBATALAN OLEH DRIVER =======================
Future<void> showCancelDialog(BuildContext context, DriverController ctrl) async {
  String category = 'emergency';
  final reason = TextEditingController();
  const cats = [
    ('emergency', 'Keadaan darurat', 'Ditinjau admin'),
    ('technical', 'Kendala teknis kendaraan', 'Ditinjau admin'),
    ('customer_unreachable', 'Customer tidak dapat dihubungi', 'Dapat dikenai penalti'),
    ('other', 'Alasan lainnya', 'Dapat dikenai penalti'),
  ];
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      bool busy = false;
      return StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Batalkan pesanan', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Pembatalan tanpa alasan yang dapat diterima menambah poin pelanggaran dan dapat memblokir akun Anda.', style: TextStyle(fontSize: 12.5, height: 1.35))),
                ]),
              ),
              const SizedBox(height: 10),
              Column(children: [
                for (final c in cats)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: c.$1,
                    groupValue: category,
                    onChanged: (v) => setS(() => category = v!),
                    title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(c.$3, style: const TextStyle(fontSize: 11.5)),
                  ),
              ]),
              TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Alasan pembatalan (wajib)', alignLabelWithHint: true)),
            ]),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Kembali', style: TextStyle(color: AppColors.grey))),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44), backgroundColor: AppColors.danger),
              onPressed: busy
                  ? null
                  : () async {
                      if (reason.text.trim().length < 5) {
                        showMsg(ctx, 'Alasan minimal 5 karakter', error: true);
                        return;
                      }
                      setS(() => busy = true);
                      try {
                        final r = await ctrl.cancel(category, reason.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx, r);
                      } catch (e) {
                        setS(() => busy = false);
                        if (ctx.mounted) showError(ctx, e);
                      }
                    },
              child: const Text('Batalkan'),
            ),
          ],
        );
      });
    },
  );
  if (result != null && context.mounted) {
    showMsg(context, result['_message'] ?? 'Pembatalan dicatat', error: result['blocked'] == true);
  }
}

