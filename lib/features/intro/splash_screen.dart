import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AnimatedIntroScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const AnimatedIntroScreen({super.key, required this.onComplete});

  @override
  State<AnimatedIntroScreen> createState() => _AnimatedIntroScreenState();
}

class _AnimatedIntroScreenState extends State<AnimatedIntroScreen> with TickerProviderStateMixin {
  late final AnimationController _logoCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _textCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _logoCtrl,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _textCtrl,
    curve: Curves.easeIn,
  );
  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _textCtrl.forward();

    // Auto navigate after 2.8s
    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF063B1F), AppColors.primary, Color(0xFF0F7A44)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Subtle background decorative circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    ScaleTransition(
                      scale: _logoScale,
                      child: const AppLogo(size: 110, light: true),
                    ),
                    const SizedBox(height: 28),
                    // Animated Title & Tagline
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.two_wheeler_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'POLITEKNIK NEGERI LAMPUNG',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              AppConfig.appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppConfig.appTagline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Bottom loading indicator & skip
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: widget.onComplete,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Lewati intro'),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
