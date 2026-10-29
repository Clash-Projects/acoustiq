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
        final isDark = appState.isCurrentDark(context);

        final bg = backgroundColor ?? appState.getCardBgColor(context);
        final baseBorder = borderColor ?? appState.getBorderColor(context);

        Widget content = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: isDark && useGlass
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.09),
                      Colors.white.withOpacity(0.025),
                    ],
                  )
                : null,
            border: isDark && useGlass
                ? Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.26), width: 1.2),
                    left: BorderSide(color: Colors.white.withOpacity(0.09), width: 1.0),
                    right: BorderSide(color: Colors.white.withOpacity(0.09), width: 1.0),
                    bottom: BorderSide(color: Colors.white.withOpacity(0.04), width: 1.0),
                  )
                : Border.all(color: baseBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.40) : Colors.black.withOpacity(0.06),
                blurRadius: 18,
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
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
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
