import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/app_settings.dart';

/// AcoustiQ Studio Splash Screen
///
/// Features:
/// - 100% pitch-black OLED canvas (#000000).
/// - High-fidelity animated AcoustiQ logo: the 5 equalizer bars pulse with dynamic
///   audio-reactive heights for ~600ms, then seamlessly settle into the iconic resting logo mark.
/// - Clean "A C O U S T I Q" tracking wordmark (Option D: Zero Subtitles).
/// - Pure minimalist backdrop (Choice 2: Zero footer badges).
/// - Non-blocking: Tap-to-skip instantly transitions into MainShell.
class AcoustiQSplashScreen extends StatefulWidget {
  const AcoustiQSplashScreen({super.key});

  @override
  State<AcoustiQSplashScreen> createState() => _AcoustiQSplashScreenState();
}

class _AcoustiQSplashScreenState extends State<AcoustiQSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _controller.addListener(() {
      if (_controller.value >= 1.0 && !_navigated) {
        _proceedToMainShell();
      }
    });

    _controller.forward();
  }

  void _proceedToMainShell() {
    if (_navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep system bars pure black & hidden/clean during splash
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _proceedToMainShell,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;

              // Smooth fade-in for overall logo mark during first 200ms
              final logoOpacity = (t / 0.25).clamp(0.0, 1.0);

              // Subtitle/wordmark tracking fade in
              final textOpacity = ((t - 0.15) / 0.30).clamp(0.0, 1.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Container with Q-Ring and Animated Equalizer Bars
                  Opacity(
                    opacity: logoOpacity,
                    child: SizedBox(
                      width: 96,
                      height: 105,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Static Master Q Ring with custom-cut audio notch
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/logo_acoustiq_ring.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),

                          // 2. Dynamic Equalizer Bars with audio-reactive pulse
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AnimatedEqualizerBarsPainter(progress: t),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Monochromatic Wordmark: ACOUSTIQ
                  Opacity(
                    opacity: textOpacity,
                    child: const Text(
                      'ACOUSTIQ',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Vector Painter for the 5 AcoustiQ Equalizer Bars
///
/// Coordinates precisely mapped from Minimalist Q Equalizer master mark:
/// - Bars width: 6.61% of canvas width
/// - Normalized X centers: [0.6068, 0.6966, 0.7864, 0.8763, 0.9661]
/// - Base resting heights: [0.1594, 0.2771, 0.3947, 0.2508, 0.1393]
class _AnimatedEqualizerBarsPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0

  _AnimatedEqualizerBarsPainter({required this.progress});

  static const List<double> _normX = [0.6068, 0.6966, 0.7864, 0.8763, 0.9661];
  static const List<double> _normY = [0.8158, 0.8142, 0.8019, 0.8088, 0.8135];
  static const List<double> _baseH = [0.1594, 0.2771, 0.3947, 0.2508, 0.1393];
  static const List<double> _phases = [0.0, 1.4, 2.8, 4.2, 5.5];

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width * 0.0661;
    final radius = Radius.circular(barW / 2);
    final paint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Settle curve: waves oscillate during t in [0.0, 0.60], then damp to 0.0 at t=0.70
    final damp = (1.0 - (progress / 0.65)).clamp(0.0, 1.0);

    for (int i = 0; i < 5; i++) {
      final cx = size.width * _normX[i];
      final cy = size.height * _normY[i];
      final baseH = size.height * _baseH[i];

      // Sinusoidal wave bounce
      final wave = math.sin(progress * 22.0 + _phases[i]);
      // Multiplier oscillates around 1.0 when active, snaps cleanly to 1.0 at rest
      final scaleFactor = (1.0 + (wave * 0.40 * damp)).clamp(0.2, 1.6);
      final dynamicH = baseH * scaleFactor;

      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: barW,
        height: dynamicH,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedEqualizerBarsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
