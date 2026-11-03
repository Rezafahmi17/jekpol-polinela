import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/custom_nav_bar.dart';
import '../../widgets/profile_view.dart';
import 'activity_screen.dart';
import 'customer_controller.dart';
import 'help_screen.dart';
import 'home_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _ctrl = CustomerController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.start();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<CustomerController>(
        builder: (context, c, _) => Scaffold(
          extendBody: true,
          body: IndexedStack(index: _index, children: [
            const CustomerHomeScreen(),
            ActivityScreen(onOpenTracking: () => setState(() => _index = 0)),
            const HelpScreen(),
            Scaffold(appBar: AppBar(title: const Text('Profil Saya')), body: const ProfileView()),
          ]),
          bottomNavigationBar: CustomFloatingNavBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: [
              const NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Beranda',
              ),
              NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Aktivitas',
                showBadge: c.active != null,
              ),
              const NavItem(
                icon: Icons.help_outline_rounded,
                activeIcon: Icons.help_rounded,
                label: 'Bantuan',
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
