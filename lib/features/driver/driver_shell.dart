import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_nav_bar.dart';
import '../../widgets/profile_view.dart';
import 'driver_controller.dart';
import 'earnings_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  late final DriverController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = DriverController(context.read<AuthProvider>());
    _ctrl.start();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final driver = user?.driver;

    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<DriverController>(
        builder: (context, c, _) => Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              DriverHomeScreen(onOpenOrders: () => setState(() => _index = 1)),
              const DriverOrdersScreen(),
              const EarningsScreen(),
              Scaffold(
                appBar: AppBar(title: const Text('Profil Driver')),
                body: ProfileView(
                  showVehicleEdit: true,
                  sections: [
                    const SectionTitle('Status driver'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(children: [
                          InfoRow(
                            Icons.verified_user_rounded,
                            'Verifikasi',
                            switch (driver?.verificationStatus) {
                              'approved' => 'Terverifikasi (Disetujui)',
                              'rejected' => 'Ditolak: ${driver?.rejectionReason ?? ""}',
                              _ => 'Menunggu verifikasi admin',
                            },
                            valueColor: switch (driver?.verificationStatus) {
                              'approved' => AppColors.success,
                              'rejected' => AppColors.danger,
                              _ => AppColors.warning,
                            },
                          ),
                          InfoRow(
                            Icons.star_rounded,
                            'Rating driver',
                            '${driver?.ratingAvg.toStringAsFixed(1) ?? "0.0"} (${driver?.ratingCount ?? 0} ulasan)',
                            valueColor: AppColors.warning,
                          ),
                          InfoRow(
                            Icons.warning_amber_rounded,
                            'Poin pelanggaran',
                            '${driver?.penaltyPoints ?? 0} poin (Batas: ${driver?.penaltyThreshold ?? 3})',
                            valueColor: (driver?.penaltyPoints ?? 0) > 0 ? AppColors.danger : AppColors.grey,
                          ),
                        ]),
                      ),
                    ),
                    const SectionTitle('Data kendaraan'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(children: [
                          InfoRow(Icons.two_wheeler_rounded, 'Kendaraan', driver?.vehicle ?? '-'),
                          InfoRow(Icons.tag_rounded, 'Plat Nomor', driver?.plate ?? '-'),
                          InfoRow(Icons.palette_outlined, 'Warna', driver?.vehicleColor ?? '-'),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: CustomFloatingNavBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: [
              const NavItem(
                icon: Icons.navigation_outlined,
                activeIcon: Icons.navigation_rounded,
                label: 'Beranda',
              ),
              NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Pesanan',
                showBadge: c.active != null,
              ),
              const NavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: 'Pendapatan',
              ),
              const NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

