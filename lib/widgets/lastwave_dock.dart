import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/shape.dart';
import '../ui/theme/colors.dart';

/// 1:1 Port of LastWave Native's FloatingNavBar & FloatingNavItem
///
/// Features:
/// 1. True Material 3 Expressive Capsule Dock with authentic frosted glass substrate.
/// 2. Animated expanding active pill: Inactive tabs show icon-only (12dp padding);
///    selected tab smoothly expands to 18dp padding, highlights with primaryContainer
///    (alpha 0.28), and slides/fades in its label.
/// 3. Seamless touch tracking: Tap or drag across dock smoothly transitions tabs
///    without fake droplet physics, clipping, or adjacent scale ballooning.
class LastWaveNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const LastWaveNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<LastWaveNavBar> createState() => _LastWaveNavBarState();
}

class _LastWaveNavBarState extends State<LastWaveNavBar> {
  final GlobalKey _dockKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  void _handleTouch(Offset globalPosition) {
    for (int i = 0; i < _itemKeys.length; i++) {
      final keyContext = _itemKeys[i].currentContext;
      if (keyContext != null) {
        final box = keyContext.findRenderObject() as RenderBox?;
        if (box != null) {
          final local = box.globalToLocal(globalPosition);
          // 8dp bridge inflation matching LastWave's touch bridge
          final rect = Rect.fromLTWH(
            -8,
            -8,
            box.size.width + 16,
            box.size.height + 16,
          );
          if (rect.contains(local)) {
            if (widget.currentIndex != i) {
              if (appState.hapticsEnabled) {
                HapticFeedback.selectionClick();
              }
              widget.onTabSelected(i);
            }
            break;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final useGlass = appState.isLiquidGlass;

        final dockColor = isDark
            ? (useGlass
                ? AppColors.surfaceHigh.withOpacity(0.72)
                : AppColors.surfaceHigh)
            : (useGlass
                ? Colors.white.withOpacity(0.85)
                : AppColors.lightSurface);

        final borderColor = isDark ? AppColors.darkHairline : AppColors.lightHairline;

        Widget content = Container(
          key: _dockKey,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: dockColor,
            borderRadius: ExpressiveShapes.dock,
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: AppColors.softElevation(elevation: 8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isSelected = widget.currentIndex == index;

              return Padding(
                key: _itemKeys[index],
                padding: EdgeInsets.only(right: index == _tabs.length - 1 ? 0 : 4),
                child: _FloatingNavItem(
                  label: tab.label,
                  icon: tab.icon,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () {
                    if (!isSelected) {
                      if (appState.hapticsEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      widget.onTabSelected(index);
                    }
                  },
                ),
              );
            }),
          ),
        );

        if (useGlass) {
          content = ClipRRect(
            borderRadius: ExpressiveShapes.dock,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: content,
            ),
          );
        }

        return GestureDetector(
          onHorizontalDragDown: (details) => _handleTouch(details.globalPosition),
          onHorizontalDragUpdate: (details) => _handleTouch(details.globalPosition),
          child: content,
        );
      },
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1:1 with LastWave FloatingNavItem:
    // Active background: primaryContainer with alpha 0.28
    // Active content: onPrimaryContainer / vibrant accent
    // Unselected: Transparent background, onSurfaceVariant color
    final activeBg = AppColors.accentPrimary.withOpacity(isDark ? 0.28 : 0.20);
    final inactiveBg = Colors.transparent;

    final activeColor = isDark ? Colors.white : const Color(0xFF007299);
    final inactiveColor = isDark ? const Color(0x99FFFFFF) : const Color(0x99000000);

    return Material(
      color: Colors.transparent,
      borderRadius: ExpressiveShapes.badgePill,
      child: InkWell(
        onTap: onTap,
        borderRadius: ExpressiveShapes.badgePill,
        splashColor: AppColors.accentPrimary.withOpacity(0.12),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.fastOutSlowIn,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: ExpressiveShapes.badgePill,
            border: isSelected
                ? Border.all(
                    color: AppColors.accentPrimary.withOpacity(0.35),
                    width: 0.6,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.fastOutSlowIn,
                  alignment: Alignment.centerLeft,
                  child: isSelected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: activeColor,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
