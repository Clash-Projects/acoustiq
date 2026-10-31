import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

enum GlassStyle {
  frosted, // WWDC25 Regular Glass Substrate: 20dp blur + subtle translucent fill
  clear,   // WWDC25 Clear Glass: High clarity + 12dp blur
  liquid,  // WWDC25 Liquid Glass: Optical backdrop refraction + specular catch
}

/// A physical Glass Surface adhering to Apple WWDC25 "Meet Liquid Glass"
/// and LastWave Native glass specifications.
///
/// LastWave Rule: Cards & lists have zero borders (borderless: true by default).
/// Glass is used selectively for floating navigation chrome, headers, and floating pills.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final GlassStyle style;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color? tintColor;
  final double? elevation;
  final bool borderless;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.style = GlassStyle.frosted,
    this.padding,
    this.constraints,
    this.tintColor,
    this.elevation,
    this.borderless = true, // Default to true matching LastWave zero-border rule!
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final useGlass = appState.isLiquidGlass;

        // If user disabled Liquid Glass in Settings, render high-performance opaque Expressive container
        if (!useGlass) {
          final solidBg = isDark
              ? (appState.amoledMode ? const Color(0xFF101214) : const Color(0xFF1E2228))
              : AppColors.lightSurface;

          return Container(
            constraints: constraints,
            padding: padding,
            decoration: BoxDecoration(
              color: tintColor ?? solidBg,
              borderRadius: borderRadius,
              boxShadow: isDark
                  ? AppColors.softElevation(elevation: elevation ?? 3.0)
                  : AppColors.lightSoftElevation(elevation: elevation ?? 3.0),
            ),
            child: child,
          );
        }

        // --- WWDC25 & LastWave True Glass Architecture ---
        double blurSigma;
        Color surfaceFill;

        switch (style) {
          case GlassStyle.clear:
            blurSigma = 12.0;
            surfaceFill = isDark
                ? (tintColor?.withOpacity(0.18) ?? const Color(0x16FFFFFF))
                : (tintColor?.withOpacity(0.20) ?? Colors.white.withOpacity(0.65));
            break;

          case GlassStyle.liquid:
            blurSigma = 20.0;
            surfaceFill = isDark
                ? (tintColor?.withOpacity(0.24) ?? const Color(0x22FFFFFF))
                : (tintColor?.withOpacity(0.30) ?? Colors.white.withOpacity(0.80));
            break;

          case GlassStyle.frosted:
          default:
            blurSigma = 16.0;
            surfaceFill = isDark
                ? (tintColor?.withOpacity(0.18) ?? (appState.amoledMode ? const Color(0x18FFFFFF) : const Color(0x22FFFFFF)))
                : (tintColor?.withOpacity(0.20) ?? Colors.white.withOpacity(0.72));
            break;
        }

        // Pure white specular catch on top, zero blue/cyan dye
        final borderStroke = borderless
            ? null
            : Border.all(
                color: isDark ? const Color(0x20FFFFFF) : const Color(0x30FFFFFF),
                width: 0.6,
              );

        return ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              constraints: constraints,
              padding: padding,
              decoration: BoxDecoration(
                color: surfaceFill,
                borderRadius: borderRadius,
                border: borderStroke,
                boxShadow: isDark
                    ? AppColors.softElevation(elevation: elevation ?? 3.5)
                    : AppColors.lightSoftElevation(elevation: elevation ?? 3.5),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
