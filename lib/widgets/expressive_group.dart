import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';

/// 1:1 Port of LastWave Native's ExpressiveGroup Architecture
///
/// A group of rows reads as ONE continuous premium sculpted surface rather
/// than a stack of separate cards — first row rounded on top (28dp), last row
/// rounded on the bottom (28dp), middle rows nearly square (6dp), all separated by a
/// hairline 3dp gap instead of normal item spacing.
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

/// A tappable row inside an [ExpressiveGroup] that navigates or toggles an action.
///
/// Features:
/// - Exact 28dp/6dp continuous corner curvature based on position.
/// - Pure LastWave obsidian container (#141414 in dark, #FFFFFF in light) with ZERO borders.
/// - Fluid spring scale feedback on touch press (scales to 0.98).
/// - 44dp squircle icon badge with continuous 14dp curvature.
class ExpressiveGroupRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final GroupPosition position;
  final VoidCallback? onTap;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBgColor;
  final Widget? trailing;
  final bool danger;

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
  });

  @override
  State<ExpressiveGroupRow> createState() => _ExpressiveGroupRowState();
}

class _ExpressiveGroupRowState extends State<ExpressiveGroupRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = widget.danger
            ? AppColors.fakeCoral
            : appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        final rowBg = isDark ? AppColors.surfaceContainer : AppColors.lightSurface;
        final shape = groupShape(widget.position);

        final iconBg = widget.iconBgColor ??
            (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F2));
        final iconClr = widget.iconColor ??
            (widget.danger ? AppColors.fakeCoral : AppColors.accentPrimary);

        return AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.fastOutSlowIn,
          child: Material(
            color: rowBg,
            borderRadius: shape,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (highlighted) {
                if (mounted && widget.onTap != null) {
                  setState(() => _isPressed = highlighted);
                }
              },
              borderRadius: shape,
              splashColor: AppColors.accentPrimary.withOpacity(0.10),
              highlightColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: shape,
                ),
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
                        widget.icon,
                        size: 22,
                        color: iconClr,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title & Optional Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: subTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ] else if (widget.onTap != null) ...[
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: isDark ? const Color(0x66FFFFFF) : const Color(0x66000000),
                      ),
                    ],
                  ],
                ),
              ),
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
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color.withOpacity(0.55),
      ),
    ),
  );
}
