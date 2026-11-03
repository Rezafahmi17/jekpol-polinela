import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/order_widgets.dart';
import 'driver_controller.dart';
import 'driver_widgets.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  final _key = GlobalKey<AsyncPageState>();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverController>();
    final active = ctrl.active;

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      body: AsyncPage(
        key: _key,
        load: () => Api.get('orders/history'),
        builder: (context, data) {
          final history = (data['orders'] as List).map((e) => Order.fromJson(e)).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              if (active != null) ...[
                const SectionTitle('Pesanan aktif saat ini'),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DriverOrderCard(order: active),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SectionTitle('Riwayat pesanan driver',
                  trailing: Text('${history.length} pesanan',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey))),
              if (history.isEmpty)
                const EmptyScroll(
                  icon: Icons.receipt_long_rounded,
                  title: 'Belum ada pesanan',
                  subtitle: 'Pesanan yang Anda selesaikan atau batalkan akan tercatat di sini.',
                )
              else
                for (final o in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderTile(order: o, perspective: 'driver'),
                  ),
            ],
          );
        },
      ),
    );
  }
}

