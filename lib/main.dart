import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/auth_provider.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/customer/customer_shell.dart';
import 'features/driver/driver_shell.dart';
import 'features/intro/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const GojekPolinelaApp(),
    ),
  );
}

class GojekPolinelaApp extends StatelessWidget {
  const GojekPolinelaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppEntryCoordinator(),
    );
  }
}

class AppEntryCoordinator extends StatefulWidget {
  const AppEntryCoordinator({super.key});

  @override
  State<AppEntryCoordinator> createState() => _AppEntryCoordinatorState();
}

class _AppEntryCoordinatorState extends State<AppEntryCoordinator> {
  bool _showIntro = true;

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return AnimatedIntroScreen(
        onComplete: () {
          if (mounted) setState(() => _showIntro = false);
        },
      );
    }
    return const RootGate();
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        final user = auth.user;
        if (user == null) return const LoginScreen();
        return switch (user.role) {
          'driver' => const DriverShell(),
          'admin' || 'super_admin' => const AdminShell(),
          _ => const CustomerShell(),
        };
    }
  }
}
