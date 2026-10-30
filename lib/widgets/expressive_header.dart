import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';

/// 1:1 Port of LastWave's ExpressiveHeader & HeaderActionIcon
class ExpressiveHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;

  const ExpressiveHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? const Color(0xB3FFFFFF) : const Color(0x99000000);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        );
      },
    );
  }
}

/// 1:1 Port of LastWave's HeaderActionIcon / Pill Button
class HeaderActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const HeaderActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);

    return Material(
      color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceHigh,
      borderRadius: ExpressiveShapes.badgePill,
      child: InkWell(
        onTap: onTap,
        borderRadius: ExpressiveShapes.badgePill,
        child: Container(
          padding: const EdgeInsets.all(8.5),
          decoration: BoxDecoration(
            borderRadius: ExpressiveShapes.badgePill,
            border: Border.all(
              color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

