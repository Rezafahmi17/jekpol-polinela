import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_view.dart';

class AdminDashboardScreen extends StatelessWidget {
  final void Function(int tabIndex)? onNavigate;
  const AdminDashboardScreen({super.key, this.onNavigate});

  void _openProfile(BuildContext context) {
    if (onNavigate != null) {
      onNavigate?.call(4);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Text('Profil Super Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Expanded(child: ProfileView()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Super Admin'),
        actions: [
          IconButton(
            tooltip: 'Profil Super Admin',
            icon: const Icon(Icons.account_circle_rounded, size: 28),
            onPressed: () => _openProfile(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AsyncPage(
        load: () => Api.get('admin/dashboard'),
        builder: (context, data) {
          final cust = data['customers'] ?? 0;
          final drv = data['drivers'] ?? 0;
          final drvOnline = data['drivers_online'] ?? 0;
          final drvBusy = data['drivers_busy'] ?? 0;
          final pendingVerif = data['pending_verifications'] ?? 0;
          final blocked = data['blocked_users'] ?? 0;
          final ordersToday = data['orders_today'] ?? 0;
          final ordersActive = data['orders_active'] ?? 0;
          final revToday = data['revenue_today'] ?? 0;
          final revTotal = data['revenue_total'] ?? 0;
          final cancellations = data['cancellations'] ?? 0;
          final complaints = data['open_complaints'] ?? 0;
          final pendingPenalties = data['pending_penalties'] ?? 0;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              // Banner Omset
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
                  const Text('Pendapatan Tunai Transaksi Hari Ini',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(Fmt.rupiah(revToday),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text('Total Seluruh Transaksi: ${Fmt.rupiah(revTotal)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),

              if (pendingVerif > 0)
                Card(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions_rounded, color: AppColors.warning),
                    title: Text('$pendingVerif Driver Menunggu Verifikasi',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Periksa dokumen KTM dan surat pernyataan.'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.warning),
                    onTap: () => onNavigate?.call(1), // Tab Verifikasi
                  ),
                ),

              if (complaints > 0)
                Card(
                  color: AppColors.info.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: const Icon(Icons.mark_chat_unread_rounded, color: AppColors.info),
                    title: Text('$complaints Pengaduan Pengguna Belum Ditanggapi',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Ketuk untuk membuka pengaduan.'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.info),
                    onTap: () => onNavigate?.call(3), // Tab Pesanan & Pengaduan
                  ),
                ),

              const SectionTitle('Aktivitas Hari Ini'),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Pesanan Hari Ini',
                    value: '$ordersToday',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.route_rounded,
                    label: 'Pesanan Aktif',
                    value: '$ordersActive',
                    color: AppColors.info,
                    onTap: () => onNavigate?.call(3),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.cancel_outlined,
                    label: 'Pembatalan',
                    value: '$cancellations',
                    color: AppColors.danger,
                    onTap: () => onNavigate?.call(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.shield_outlined,
                    label: 'Review Penalti',
                    value: '$pendingPenalties',
                    color: AppColors.warning,
                    onTap: () => onNavigate?.call(3),
                  ),
                ),
              ]),

              const SectionTitle('Status Pengguna & Driver'),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.two_wheeler_rounded,
                    label: 'Driver Online',
                    value: '$drvOnline / $drv',
                    color: AppColors.success,
                    onTap: () => onNavigate?.call(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.two_wheeler_rounded,
                    label: 'Driver Sedang Antar',
                    value: '$drvBusy',
                    color: AppColors.info,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.people_alt_rounded,
                    label: 'Total Mahasiswa',
                    value: '$cust',
                    color: AppColors.primary,
                    onTap: () => onNavigate?.call(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.block_rounded,
                    label: 'Akun Diblokir',
                    value: '$blocked',
                    color: AppColors.danger,
                    onTap: () => onNavigate?.call(2),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

