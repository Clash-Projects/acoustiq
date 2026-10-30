import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import 'squircle.dart';

/// Flagship visionOS / LastWave-Inspired G2 Squircle Frosted Glass Card
///
/// Features:
/// 1. Continuous-Curvature G2 Superellipse clipping (k = 1.528665)
/// 2. Crisp 14dp Optical Diffusion Kernel (LastWave recipe)
/// 3. Luminous Frosted Silica Gradient
/// 4. Sub-pixel 0.5px hairline rim (zero cartoon wires)
/// 5. Soft ambient contact shadow for true floating depth
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
    this.borderRadius = 24,
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
        final baseBorder = borderColor ?? appState.getBorderColor(context);

        final Gradient? fillGradient = useGlass
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.065),
                        Colors.white.withOpacity(0.018),
                      ]
                    : [
                        Colors.white.withOpacity(0.80),
                        Colors.white.withOpacity(0.62),
                      ],
              )
            : null;

        Widget cardContent = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: useGlass ? (backgroundColor ?? Colors.transparent) : bg,
            gradient: backgroundColor == null ? fillGradient : null,
          ),
          child: child,
        );

        Widget glassBody;
        if (useGlass) {
          glassBody = ClipPath(
            clipper: SquircleClipper(radius: borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: cardContent,
            ),
          );
        } else {
          glassBody = ClipPath(
            clipper: SquircleClipper(radius: borderRadius),
            child: cardContent,
          );
        }

        // Sub-pixel hairline border + Ambient contact drop shadow
        Widget framed = CustomPaint(
          foregroundPainter: SquircleBorderPainter(
            radius: borderRadius,
            borderColor: baseBorder,
            borderWidth: 0.5,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.42)
                      : const Color(0xFF1E2D4A).withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
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
