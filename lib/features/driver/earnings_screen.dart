import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/order_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _key = GlobalKey<AsyncPageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendapatan & Penalti')),
      body: AsyncPage(
        key: _key,
        load: () => Api.get('driver/summary'),
        builder: (context, data) {
          final total = data['total_earnings'] as num? ?? 0;
          final today = data['today_earnings'] as num? ?? 0;
          final completed = data['completed_orders'] as num? ?? 0;
          final todayCompleted = data['today_orders'] as num? ?? 0;
          final penalties = (data['penalties'] as List? ?? []).cast<Map>();
          final txs = (data['transactions'] as List? ?? []).map((e) => Order.fromJson(e)).toList();
          final driver = data['driver'] as Map?;
          final points = driver?['penalty_points'] as num? ?? 0;
          final threshold = driver?['penalty_threshold'] as num? ?? 3;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Pendapatan Tunai',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Fmt.rupiah(total),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(Fmt.rupiah(today),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Trip Selesai Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('$todayCompleted trip',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // Grid Stat
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.check_circle_rounded,
                    label: 'Total Trip Selesai',
                    value: '$completed',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Poin Pelanggaran',
                    value: '$points / $threshold',
                    color: points > 0 ? AppColors.danger : AppColors.grey,
                  ),
                ),
              ]),
              if (points > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Peringatan: Akun Anda akan diblokir otomatis jika mencapai $threshold poin pelanggaran akibat pembatalan.',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ]),
                ),
              ],
              if (penalties.isNotEmpty) ...[
                const SectionTitle('Riwayat penalti & pelanggaran'),
                Card(
                  child: Column(children: [
                    for (final p in penalties)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                          child: const Icon(Icons.warning_rounded, color: AppColors.danger, size: 20),
                        ),
                        title: Text('${p['reason_text']}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text('${Fmt.dateTime(p['created_at'])}\nStatus: ${p['status'] == 'pending_review' ? 'Menunggu Review Admin' : (p['status'] == 'dismissed' ? 'Dibatalkan (Bebas)' : 'Pelanggaran')}'),
                        isThreeLine: true,
                        trailing: Text(
                          '+${p['points']} poin',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ]),
                ),
              ],
              SectionTitle('Riwayat transaksi lunas',
                  trailing: Text('${txs.length} transaksi',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
              if (txs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Belum ada transaksi perjalanan selesai',
                          style: TextStyle(color: AppColors.grey)),
                    ),
                  ),
                )
              else
                for (final o in txs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OrderTile(order: o, perspective: 'driver'),
                  ),
            ],
          );
        },
      ),
    );
  }
}

