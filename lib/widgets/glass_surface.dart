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

        // Add top specular strip for frosted and liquid styles (simulates chamfered glass edge)
        final showSpecularEdge = (style == GlassStyle.frosted || style == GlassStyle.liquid) && isDark;

        return ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              children: [
                Container(
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
                // Top specular light strip — simulates ambient overhead light on chamfered glass rim
                if (showSpecularEdge)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GlassSpecularEdgePainter(
                          borderRadius: borderRadius,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Draws a top-only specular strip on the glass surface.
/// Simulates how chamfered glass edges catch ambient overhead illumination —
/// creating a subtle shimmer along the top rim without any visible box outline.
class _GlassSpecularEdgePainter extends CustomPainter {
  final BorderRadius borderRadius;

  _GlassSpecularEdgePainter({required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to the same rounded rect as the container
    final outerRadius = borderRadius.topLeft.x;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(outerRadius),
    );
    canvas.clipRRect(rrect);

    // Top specular strip: height 1.4dp, fades from center outward
    const double stripHeight = 1.4;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x00FFFFFF),
          Color(0x30FFFFFF),
          Color(0x42FFFFFF),
          Color(0x30FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, stripHeight));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, stripHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassSpecularEdgePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}
