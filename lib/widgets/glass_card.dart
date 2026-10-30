import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// Flagship visionOS-Grade Authentic Frosted Glass Card
///
/// Features:
/// 1. Silky Smooth Continuous Rounded Geometry (Zero chamfers, zero diagonal cuts)
/// 2. 20dp Gaussian Optical Diffusion Kernel for authentic silica refraction
/// 3. Luminous Frosted Silica Gradient + Translucent Dark Crystal Substrate
/// 4. Dual-Stop Specular Hairline Rim (Top edge catches overhead light, bottom edge settles in shadow)
/// 5. Multi-Stage Floating Ambient Shadows for true 3D floating elevation
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final useGlass = appState.isLiquidGlass;
        final isDark = appState.isCurrentDark(context);

        final bg = backgroundColor ?? appState.getCardBgColor(context);

        final Gradient? fillGradient = useGlass
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.14),
                        Colors.white.withOpacity(0.03),
                      ]
                    : [
                        Colors.white.withOpacity(0.92),
                        Colors.white.withOpacity(0.72),
                      ],
              )
            : null;

        Widget cardContent = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: useGlass
                ? (backgroundColor ??
                    (isDark
                        ? const Color(0xFF141414).withOpacity(0.68)
                        : Colors.white.withOpacity(0.82)))
                : bg,
            gradient: backgroundColor == null ? fillGradient : null,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        );

        Widget glassBody;
        if (useGlass) {
          glassBody = ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: cardContent,
            ),
          );
        } else {
          glassBody = ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: cardContent,
          );
        }

        // Multi-Stage Floating Ambient Shadows + Dual-Stop Specular Rim
        Widget framed = CustomPaint(
          foregroundPainter: _GlassSpecularBorderPainter(
            borderRadius: borderRadius,
            isDark: isDark,
            customBorderColor: borderColor,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                // 1. Sharp Contact Elevation Shadow directly beneath the card
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.65 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: -1,
                ),
                // 2. Deep Diffuse Ambient Spread Shadow giving true floating space
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.40 : 0.05),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: glassBody,
          ),
        );

        if (margin != null) {
          framed = Padding(padding: margin!, child: framed);
        }

        if (onTap != null) {
          framed = GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: framed,
          );
        }

        return framed;
      },
    );
  }
}

/// Dual-Stop Specular Hairline Rim Painter
///
/// Accurately renders physical glass bevel reflection:
/// Top edge catches overhead daylight and gleams bright white,
/// while bottom edge settles into ambient shadow.
class _GlassSpecularBorderPainter extends CustomPainter {
  final double borderRadius;
  final bool isDark;
  final Color? customBorderColor;

  _GlassSpecularBorderPainter({
    required this.borderRadius,
    required this.isDark,
    this.customBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    if (customBorderColor != null) {
      borderPaint.color = customBorderColor!;
    } else {
      borderPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withOpacity(0.28),
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ]
            : [
                Colors.white.withOpacity(0.95),
                Colors.black.withOpacity(0.08),
                Colors.black.withOpacity(0.04),
              ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    }

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassSpecularBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.customBorderColor != customBorderColor;
  }
}
