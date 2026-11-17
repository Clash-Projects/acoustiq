import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

enum LuminousVariant {
  emerald, // Genuine FLACs & Audio tracks
  cyan,    // Dock tabs & Active navigation
  amber,   // Duplicates & Warning actions
  violet,  // Settings & Theme toggles
}

/// Interactive Luminous Feedback & Glitter Ripple
///
/// Emits contextual chromatic light ripples and subtle specular sparkles on tap.
class LuminousFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final LuminousVariant variant;
  final BorderRadius? borderRadius;
  final double scaleOnPress;

  const LuminousFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.variant = LuminousVariant.cyan,
    this.borderRadius,
    this.scaleOnPress = 0.98,
  });

  @override
  State<LuminousFeedback> createState() => _LuminousFeedbackState();
}

class _LuminousFeedbackState extends State<LuminousFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _tapPosition = Offset.zero;
  bool _isPressed = false;

  Color get _accentColor {
    switch (widget.variant) {
      case LuminousVariant.emerald:
        return AppColors.genuineEmerald;
      case LuminousVariant.cyan:
        return AppColors.accentPrimary;
      case LuminousVariant.amber:
        return AppColors.suspiciousAmber;
      case LuminousVariant.violet:
        return const Color(0xFFA78BFA);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() {
      _tapPosition = details.localPosition;
      _isPressed = true;
    });
    if (!appState.isMotionOff) {
      _controller.forward(from: 0.0);
    }
    if (appState.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: (_isPressed && !appState.isMotionOff) ? widget.scaleOnPress : 1.0,
          duration: Duration(milliseconds: appState.isMotionOff ? 0 : 140),
          curve: Curves.fastOutSlowIn,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                widget.child,
                // Luminous Glitter & Chromatic Ripple Overlay (Disabled when Motion is Off)
                if (!appState.isMotionOff)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          if (_controller.value == 0.0 || _controller.value == 1.0) {
                            return const SizedBox.shrink();
                          }
                          return CustomPaint(
                            painter: _GlitterRipplePainter(
                              progress: _controller.value,
                              origin: _tapPosition,
                              color: _accentColor,
                              variant: widget.variant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlitterRipplePainter extends CustomPainter {
  final double progress;
  final Offset origin;
  final Color color;
  final LuminousVariant variant;

  _GlitterRipplePainter({
    required this.progress,
    required this.origin,
    required this.color,
    required this.variant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.7;
    final currentRadius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // 1. Soft Chromatic Ambient Glow Wave
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (origin.dx / size.width) * 2 - 1,
          (origin.dy / size.height) * 2 - 1,
        ),
        radius: (currentRadius / size.width).clamp(0.1, 2.0),
        colors: [
          color.withOpacity(0.24 * opacity),
          color.withOpacity(0.08 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, glowPaint);

    // 2. Micro Specular Sparkles (Glitter particles around tap origin)
    final random = math.Random(variant.index * 100);
    final particlePaint = Paint()..style = PaintingStyle.fill;

    const particleCount = 6;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (2 * math.pi / particleCount)) + (progress * 0.5);
      final dist = currentRadius * (0.3 + 0.4 * random.nextDouble());
      final px = origin.dx + math.cos(angle) * dist;
      final py = origin.dy + math.sin(angle) * dist;

      final pOpacity = ((1.0 - progress) * (0.8 + 0.2 * random.nextDouble())).clamp(0.0, 1.0);
      particlePaint.color = Colors.white.withOpacity(pOpacity * 0.75);

      // Micro 4-point sparkle star
      final pSize = 2.0 + 1.5 * (1.0 - progress);
      canvas.drawCircle(Offset(px, py), pSize, particlePaint);

      particlePaint.color = color.withOpacity(pOpacity * 0.4);
      canvas.drawCircle(Offset(px, py), pSize * 2.2, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlitterRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
