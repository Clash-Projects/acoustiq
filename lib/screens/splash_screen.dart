import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

/// AcoustiQ Studio Splash Screen
///
/// Refined Animation Choreography:
/// - 100% pitch-black OLED canvas (#000000).
/// - Android 12+ system icon disabled via values-v31 windowSplashScreenAnimatedIcon = transparent,
///   achieving the seamless Google Pay / Apple aesthetic (zero cold-start icon flash).
/// - Rich 1500ms audio-reactive equalizer animation:
///   * 0ms – 150ms: Smooth emergence from black.
///   * 150ms – 1050ms: The 5 equalizer bars pulse with organic acoustic harmonics.
///   * 1050ms – 1300ms: Smooth deceleration & settle into the iconic resting logo mark.
///   * 1300ms – 1500ms: Steady resting hold.
///   * 1500ms: Fluid 250ms fade dissolve directly into MainShell.
/// - Non-blocking: Tap anywhere at any time to skip instantly into the app.
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
      duration: const Duration(milliseconds: 1500),
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

              // Smooth fade-in for overall logo mark during initial 150ms
              final logoOpacity = (t / 0.12).clamp(0.0, 1.0);

              // Wordmark fade in with tracking ease
              final textOpacity = ((t - 0.10) / 0.20).clamp(0.0, 1.0);

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
  static const List<double> _harmonics = [1.0, 1.25, 0.85, 1.15, 0.95];

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width * 0.0661;
    final radius = Radius.circular(barW / 2);
    final paint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Settle curve:
    // Wave bounces actively during progress in [0.0, 0.70] (~1050ms)
    // Settle dampens to 0 between [0.70, 0.86] (~1050ms - 1300ms)
    // Resting hold between [0.86, 1.0] (1300ms - 1500ms)
    final damp = (1.0 - ((progress - 0.15) / 0.65)).clamp(0.0, 1.0);

    for (int i = 0; i < 5; i++) {
      final cx = size.width * _normX[i];
      final cy = size.height * _normY[i];
      final baseH = size.height * _baseH[i];

      // Studio acoustic harmonic bounce
      final freq = 18.0 * _harmonics[i];
      final wave = math.sin(progress * freq + _phases[i]);
      // Multiplier oscillates around 1.0 when active, smoothly settles to 1.0 at rest
      final scaleFactor = (1.0 + (wave * 0.42 * damp)).clamp(0.25, 1.65);
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
