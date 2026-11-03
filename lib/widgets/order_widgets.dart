import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import 'common.dart';

/// Kartu ringkas pesanan (dipakai di riwayat customer, driver, dan admin).
/// [perspective]: 'customer' | 'driver' | 'admin'
class OrderTile extends StatelessWidget {
  final Order order;
  final String perspective;
  final VoidCallback? onTap;
  const OrderTile({super.key, required this.order, required this.perspective, this.onTap});

  @override
  Widget build(BuildContext context) {
    final who = switch (perspective) {
      'customer' => order.driver?.name == null ? 'Belum ada driver' : 'Driver: ${order.driver!.name}',
      'driver' => 'Customer: ${order.customerName}',
      _ => '${order.customerName} → ${order.driver?.name ?? 'tanpa driver'}',
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? () => showOrderDetail(context, order.id, perspective: perspective),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(order.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3))),
              StatusChip(order.statusLabel, order.statusColor),
            ]),
            const SizedBox(height: 2),
            Text('${Fmt.dateTime(order.createdAt)} • $who', style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
            const SizedBox(height: 10),
            RouteSummary(pickup: order.pickupAddress, dest: order.destAddress),
            const Divider(height: 20),
            Row(children: [
              const Icon(Icons.route_rounded, size: 16, color: AppColors.grey),
              const SizedBox(width: 6),
              Text(Fmt.km(order.distanceKm), style: const TextStyle(color: AppColors.grey, fontSize: 13)),
              const SizedBox(width: 12),
              Icon(order.isPaid ? Icons.check_circle : Icons.payments_outlined, size: 16, color: order.isPaid ? AppColors.success : AppColors.grey),
              const SizedBox(width: 6),
              Text(order.isPaid ? 'Lunas (tunai)' : 'Tunai', style: TextStyle(color: order.isPaid ? AppColors.success : AppColors.grey, fontSize: 13)),
              const Spacer(),
              Text(Fmt.rupiah(order.totalFare), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> showOrderDetail(BuildContext context, int orderId, {required String perspective, VoidCallback? onChanged}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _OrderDetail(orderId: orderId, perspective: perspective, scroll: scroll, onChanged: onChanged),
    ),
  );
}

class _OrderDetail extends StatefulWidget {
  final int orderId;
  final String perspective;
  final ScrollController scroll;
  final VoidCallback? onChanged;
  const _OrderDetail({required this.orderId, required this.perspective, required this.scroll, this.onChanged});
  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  late Future<Map<String, dynamic>> _f = Api.get('orders/${widget.orderId}');
  int _stars = 5;
  final _comment = TextEditingController();
  bool _rating = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _rate(Order o) async {
    setState(() => _rating = true);
    try {
      await Api.post('orders/${o.id}/rate', body: {'rating': _stars, 'comment': _comment.text.trim()});
      if (!mounted) return;
      showMsg(context, 'Terima kasih atas penilaian Anda!');
      widget.onChanged?.call();
      setState(() => _f = Api.get('orders/${widget.orderId}'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', subtitle: snap.error.toString());
        final o = Order.fromJson(snap.data!['order']);
        final canRate = widget.perspective == 'customer' && o.isCompleted && !o.rated;
        return ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
          const SheetHandle(),
          Row(children: [
            Expanded(child: Text('Detail Pesanan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            StatusChip(o.statusLabel, o.statusColor),
          ]),
          const SizedBox(height: 4),
          Text(o.code, style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          RouteSummary(pickup: o.pickupAddress, dest: o.destAddress),
          const Divider(height: 28),
          InfoRow(Icons.event_rounded, 'Tanggal pesan', Fmt.dateTime(o.createdAt)),
          if (widget.perspective != 'customer') InfoRow(Icons.person_rounded, 'Customer', o.customerName),
          if (widget.perspective != 'driver') InfoRow(Icons.two_wheeler_rounded, 'Driver', o.driver?.name ?? '-'),
          if (o.driver?.plate != null && widget.perspective != 'driver') InfoRow(Icons.pin_rounded, 'Kendaraan', '${o.driver?.vehicle ?? ''} • ${o.driver!.plate}'),
          InfoRow(Icons.route_rounded, 'Jarak', Fmt.km(o.distanceKm)),
          InfoRow(Icons.payments_rounded, 'Metode pembayaran', 'Tunai (Cash)'),
          InfoRow(o.isPaid ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded, 'Status pembayaran', o.isPaid ? 'Berhasil' : 'Belum dibayar',
              valueColor: o.isPaid ? AppColors.success : AppColors.warning),
          if (o.cancelReason != null) InfoRow(Icons.info_outline, 'Alasan pembatalan', o.cancelReason!, valueColor: AppColors.danger),
          const Divider(height: 24),
          InfoRow(Icons.attach_money_rounded, 'Tarif dasar', Fmt.rupiah(_base(snap.data!))),
          InfoRow(Icons.speed_rounded, 'Tarif per km', Fmt.rupiah(_perKm(snap.data!))),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Expanded(child: Text('Total tarif', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(Fmt.rupiah(o.totalFare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
            ]),
          ),
          if (o.history.isNotEmpty) ...[
            const SectionTitle('Riwayat status'),
            for (var i = 0; i < o.history.length; i++) _timelineRow(o.history[i], i == o.history.length - 1),
          ],
          if (canRate) ...[
            const SectionTitle('Beri rating driver'),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 36, color: AppColors.warning),
                ),
            ]),
            TextField(controller: _comment, maxLines: 2, decoration: const InputDecoration(hintText: 'Tulis ulasan (opsional)')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _rating ? null : () => _rate(o), child: const Text('Kirim Rating')),
          ],
          if (o.isCompleted && o.rated)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star_rounded, color: AppColors.warning),
                SizedBox(width: 6),
                Text('Pesanan ini sudah dinilai', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]);
      },
    );
  }

  int _base(Map<String, dynamic> d) => (d['order']['base_fare'] as num).toInt();
  int _perKm(Map<String, dynamic> d) => (d['order']['per_km_rate'] as num).toInt();

  Widget _timelineRow(Map<String, dynamic> h, bool last) {
    final label = const {
          'waiting': 'Menunggu driver',
          'accepted': 'Diterima driver',
          'heading_pickup': 'Menuju penjemputan',
          'picked_up': 'Customer dijemput',
          'in_trip': 'Dalam perjalanan',
          'completed': 'Selesai',
          'cancelled_customer': 'Dibatalkan customer',
          'cancelled_driver': 'Dibatalkan driver',
          'no_driver': 'Tidak mendapat driver',
        }[h['status']] ??
        '${h['status']}';
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            if (!last) Expanded(child: Container(width: 2, color: AppColors.greyLight)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (h['note'] != null) Text('${h['note']}', style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
              Text(Fmt.dateTime(h['created_at']), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}

