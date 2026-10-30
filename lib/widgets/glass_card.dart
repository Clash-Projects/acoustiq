import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';

/// 1:1 Port of LastWave's LiquidGlassCard & Material 3 Expressive Container
///
/// Features:
/// 1. Material 3 Expressive corner curvature (ExpressiveHeroShape, TrackRowShape, etc.)
/// 2. Neutral milky frosted glass veil (sigma 16-18) without fake caustic strokes.
/// 3. Soft ambient drop shadow punching depth under the element.
/// 4. Sub-pixel hairline rim (0.5dp, 15% opacity) only where appropriate.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double elevation;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.radius,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.elevation = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final useGlass = appState.isLiquidGlass;
        final isDark = appState.isCurrentDark(context);

        final resolvedRadius = borderRadius ??
            (radius != null ? BorderRadius.circular(radius!) : ExpressiveShapes.hero);

        // Resolved Surface Container Colors (R = G = B, strictly neutral)
        final defaultBg = isDark
            ? (useGlass
                ? AppColors.surfaceContainer.withOpacity(0.72)
                : AppColors.surfaceContainer)
            : (useGlass
                ? Colors.white.withOpacity(0.85)
                : AppColors.lightSurface);

        final bg = backgroundColor ?? defaultBg;
        final border = borderColor ?? (isDark ? AppColors.darkHairline : AppColors.lightHairline);

        Widget box = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: resolvedRadius,
            border: Border.all(color: border, width: 0.5),
            boxShadow: elevation > 0 ? AppColors.softElevation(elevation: elevation) : null,
          ),
          child: child,
        );

        if (useGlass) {
          box = ClipRRect(
            borderRadius: resolvedRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: box,
            ),
          );
        }

        if (margin != null) {
          box = Padding(padding: margin!, child: box);
        }

        if (onTap != null) {
          box = Material(
            color: Colors.transparent,
            borderRadius: resolvedRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: resolvedRadius,
              splashColor: AppColors.accentPrimary.withOpacity(0.12),
              child: box,
            ),
          );
        }

        return box;
      },
    );
  }
}
