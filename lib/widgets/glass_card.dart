import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// Flagship visionOS-Grade Smooth Frosted Glass Card
///
/// Features:
/// 1. Silky Smooth Rounded Geometry (Zero chamfers, zero diagonal cuts)
/// 2. 18dp Gaussian Optical Diffusion Kernel for authentic glass refraction
/// 3. Luminous Frosted Silica Gradient + Neutral Translucent Glass Substrate
/// 4. Sub-pixel 0.8px hairline perimeter with top specular light catch
/// 5. Ambient deep contact drop shadow for genuine 3D floating elevation
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
        final baseBorder = borderColor ??
            (isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08));

        final Gradient? fillGradient = useGlass
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.025),
                      ]
                    : [
                        Colors.white.withOpacity(0.90),
                        Colors.white.withOpacity(0.70),
                      ],
              )
            : null;

        Widget cardContent = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: useGlass
                ? (backgroundColor ??
                    (isDark
                        ? const Color(0xFF141414).withOpacity(0.72)
                        : Colors.white.withOpacity(0.82)))
                : bg,
            gradient: backgroundColor == null ? fillGradient : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: baseBorder,
              width: 0.8,
            ),
          ),
          child: child,
        );

        Widget glassBody;
        if (useGlass) {
          glassBody = ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: cardContent,
            ),
          );
        } else {
          glassBody = ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: cardContent,
          );
        }

        // Ambient contact drop shadow for true 3D floating depth (Strictly neutral monochrome)
        Widget framed = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.52 : 0.07),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: glassBody,
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
