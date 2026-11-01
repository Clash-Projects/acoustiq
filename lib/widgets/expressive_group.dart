import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

/// 1:1 Port of LastWave Native's ExpressiveGroup Architecture with WWDC25 Glass Substrate
///
/// A group of rows reads as ONE continuous premium sculpted glass surface rather
/// than a stack of separate cards — first row rounded on top (28dp), last row
/// rounded on the bottom (28dp), middle rows nearly square (6dp), all separated by a
/// hairline 3dp gap with a delicate top-down specular light catch.
class ExpressiveGroup extends StatelessWidget {
  final int rowCount;
  final Widget Function(BuildContext context, int index, GroupPosition position) itemBuilder;
  final double gap;

  const ExpressiveGroup({
    super.key,
    required this.rowCount,
    required this.itemBuilder,
    this.gap = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(rowCount, (index) {
        final position = _getPosition(index, rowCount);
        return Padding(
          padding: EdgeInsets.only(bottom: index == rowCount - 1 ? 0 : gap),
          child: itemBuilder(context, index, position),
        );
      }),
    );
  }

  static GroupPosition _getPosition(int index, int count) {
    if (count <= 1) return GroupPosition.single;
    if (index == 0) return GroupPosition.top;
    if (index == count - 1) return GroupPosition.bottom;
    return GroupPosition.middle;
  }
}

/// A tappable row inside an [ExpressiveGroup] matching LastWave's ExpressiveGroupRow.
///
/// Features:
/// - Exact 28dp/6dp continuous corner curvature based on position.
/// - WWDC25 Regular Glass Substrate with delicate specular rim reflection.
/// - 44dp squircle icon badge (14dp radius).
/// - 2-line responsive soft-wrapping (prevents hard pixel truncation).
/// - High-contrast readable typography in both dark AMOLED and light modes.
/// - Luminous subtle touch feedback ripple.
class ExpressiveGroupRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final GroupPosition position;
  final VoidCallback? onTap;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBgColor;
  final Widget? trailing;
  final bool danger;
  final LuminousVariant luminousVariant;

  const ExpressiveGroupRow({
    super.key,
    required this.icon,
    required this.title,
    required this.position,
    this.onTap,
    this.subtitle,
    this.iconColor,
    this.iconBgColor,
    this.trailing,
    this.danger = false,
    this.luminousVariant = LuminousVariant.violet,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = danger
            ? AppColors.fakeCoral
            : appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        final shape = groupShape(position);

        final iconBg = iconBgColor ??
            (isDark ? const Color(0x28FFFFFF) : const Color(0xFFF0F2F5));
        final iconClr = iconColor ??
            (danger ? AppColors.fakeCoral : AppColors.accentPrimary);

        return LuminousFeedback(
          onTap: onTap,
          variant: luminousVariant,
          borderRadius: shape,
          child: GlassSurface(
            borderRadius: shape,
            style: GlassStyle.frosted,
            borderless: false, // WWDC25 specular light rim active
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // 44dp Squircle Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: iconClr,
                  ),
                ),
                const SizedBox(width: 14),
                // Title & Subtitle with Clean 2-Line Wrapping (No Truncation)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.0,
                            height: 1.35,
                            color: subTextColor,
                          ),
                          maxLines: 3,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ] else if (onTap != null) ...[
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: isDark ? const Color(0x66FFFFFF) : AppColors.lightTextMuted,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section header label (muted uppercase, matching LastWave's Settings headers)
Widget buildSectionHeader(String label, Color color) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 18),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      ),
    ),
  );
}
