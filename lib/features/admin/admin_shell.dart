import 'package:flutter/material.dart';

import '../../widgets/custom_nav_bar.dart';
import 'admin_dashboard_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';
import 'admin_verifications_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboardScreen(onNavigate: (i) => setState(() => _index = i)),
      const AdminVerificationsScreen(),
      const AdminUsersScreen(),
      const AdminOrdersScreen(),
      const AdminSettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      extendBody: true,
      bottomNavigationBar: CustomFloatingNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          NavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),
          NavItem(
            icon: Icons.verified_user_outlined,
            activeIcon: Icons.verified_user_rounded,
            label: 'Verifikasi',
          ),
          NavItem(
            icon: Icons.people_alt_outlined,
            activeIcon: Icons.people_alt_rounded,
            label: 'Pengguna',
          ),
          NavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Pesanan',
          ),
          NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

