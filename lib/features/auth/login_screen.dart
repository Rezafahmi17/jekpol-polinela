import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    try {
      await context.read<AuthProvider>().login(_id.text.trim(), _pw.text);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startupError = context.watch<AuthProvider>().startupError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background emerald header with smooth curves
          Container(
            height: MediaQuery.of(context).size.height * 0.44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF063B1F), AppColors.primary, Color(0xFF0F7A44)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  // Rider Logo
                  const AppLogo(size: 88, light: true),
                  const SizedBox(height: 12),
                  // JEKPOL Brand Name
                  const Text(
                    'JEKPOL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Politeknik Negeri Lampung',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Main Login Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Selamat Datang',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Silakan masuk ke akun JEKPOL Anda',
                              style: TextStyle(color: AppColors.grey, fontSize: 13.5),
                            ),
                            if (startupError != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        startupError,
                                        style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _id,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email atau NPM',
                                hintText: 'nama@student.polinela.ac.id',
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email atau NPM wajib diisi' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _pw,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.grey,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _login,
                              icon: const Icon(Icons.login_rounded, size: 20),
                              label: const Text(
                                'Masuk Sekarang',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Belum punya akun? ', style: TextStyle(color: AppColors.grey)),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Daftar di sini',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
