import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/order_widgets.dart';
import 'customer_controller.dart';

class ActivityScreen extends StatefulWidget {
  final VoidCallback onOpenTracking;
  const ActivityScreen({super.key, required this.onOpenTracking});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _key = GlobalKey<AsyncPageState>();
  late final CustomerController _ctrl;
  String _sig = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _ctrl = context.read<CustomerController>();
    _ctrl.addListener(_onCtrl);
  }

  void _onCtrl() {
    final s = '${_ctrl.active?.id}:${_ctrl.active?.status}:${_ctrl.finished?.id}';
    if (s != _sig) {
      _sig = s;
      _key.currentState?.reload();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas')),
      body: AsyncPage(
        key: _key,
        load: () => Api.get('orders/history'),
        builder: (context, data) {
          final all = (data['orders'] as List).map((e) => Order.fromJson(e)).toList();
          final active = all.where((o) => o.isActive).toList();
          var history = all.where((o) => !o.isActive).toList();
          if (_filter == 'done') history = history.where((o) => o.isCompleted).toList();
          if (_filter == 'cancel') history = history.where((o) => o.isCancelled).toList();
          if (all.isEmpty) {
            return const EmptyScroll(icon: Icons.receipt_long_rounded, title: 'Belum ada aktivitas', subtitle: 'Pesanan ojek Anda akan muncul di sini.');
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              if (active.isNotEmpty) ...[
                const SectionTitle('Sedang berlangsung'),
                for (final o in active) _activeCard(o),
              ],
              SectionTitle('Riwayat perjalanan', trailing: Text('${history.length} pesanan', style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
              Wrap(spacing: 8, children: [
                for (final f in const [('all', 'Semua'), ('done', 'Selesai'), ('cancel', 'Dibatalkan')])
                  ChoiceChip(
                    label: Text(f.$2),
                    selected: _filter == f.$1,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _filter == f.$1 ? AppColors.primaryDark : AppColors.grey),
                    onSelected: (_) => setState(() => _filter = f.$1),
                  ),
              ]),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('Tidak ada pesanan', style: TextStyle(color: AppColors.grey))))
              else
                for (final o in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderTile(order: o, perspective: 'customer'),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _activeCard(Order o) => Card(
        color: AppColors.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.primary)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(o.code, style: const TextStyle(fontWeight: FontWeight.w800))),
              StatusChip(o.statusLabel, o.statusColor),
            ]),
            const SizedBox(height: 10),
            RouteSummary(pickup: o.pickupAddress, dest: o.destAddress),
            const SizedBox(height: 10),
            Row(children: [
              Text(Fmt.rupiah(o.totalFare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryDark)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(130, 42)),
                onPressed: widget.onOpenTracking,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Lacak'),
              ),
            ]),
          ]),
        ),
      );
}

