import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

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
    this.borderRadius = 22,
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
        final isAmoled = appState.isAmoled;

        final defaultBg = backgroundColor ?? (isAmoled
            ? const Color(0xFF0F1218).withOpacity(useGlass ? 0.75 : 0.98)
            : const Color(0xFF161B26).withOpacity(useGlass ? 0.75 : 0.98));

        final defaultBorder = borderColor ?? Colors.white.withOpacity(0.08);

        Widget content = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: defaultBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: defaultBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
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
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
