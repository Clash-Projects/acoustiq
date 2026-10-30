import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// Flagship iOS 18 / visionOS 4-Layer Frosted Glass Container
///
/// Implements authentic optical diffusion:
/// 1. Atmospheric Substrate transmission
/// 2. Bilateral Diffusion Kernel (sigma 28)
/// 3. Frosted Silica Emulsion gradient
/// 4. Silky uniform squircle perimeter (NO harsh white top wires)
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

        // In glass mode, blend dual-stop frosted silica gradient
        // In opaque mode, use flat background
        final Gradient? fillGradient = useGlass
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.085),
                        Colors.white.withOpacity(0.025),
                      ]
                    : [
                        Colors.white.withOpacity(0.82),
                        Colors.white.withOpacity(0.64),
                      ],
              )
            : null;

        Widget content = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: useGlass ? (backgroundColor ?? Colors.transparent) : bg,
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: backgroundColor == null ? fillGradient : null,
            // UNIFORM SILKY PERIMETER:
            // Eliminates the harsh white top border that previously destroyed squircle corners
            border: Border.all(
              color: baseBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.38)
                    : const Color(0xFF1E2D4A).withOpacity(0.06),
                blurRadius: 22,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        );

        Widget card;
        if (useGlass) {
          card = ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: content,
            ),
          );
        } else {
          card = content;
        }

        if (margin != null) {
          card = Padding(padding: margin!, child: card);
        }

        if (onTap != null) {
          card = GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: card,
          );
        }

        return card;
      },
    );
  }
}
