import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave Liquid Sliding Glass Dock
///
/// Features:
/// 1. True 1:1 LastWave Optical Glass Substrate:
///    - Light 12dp Gaussian blur (never heavy mud) lets album art, colors, and text
///      underneath bleed through vividly with true glass refraction.
///    - Ultra-translucent 22% smoky tint (matching LastWave's exact 0.22 alpha spec).
/// 2. Physical Sliding Glass Lens (Continuous Motion):
///    - A dedicated glass capsule that physically GLIDES across the dock from tab to tab.
///    - True sliding spring animation (Curves.easeOutCubic) when switching tabs.
///    - Real-time drag tracking: slide finger across to guide the glass pill.
/// 3. Pure Optical Translucent Pill (Zero Fake Plastic Gradients):
///    - Translucent white glass substrate (12% alpha) with hairline 0.8px glass rim.
///    - Soft ambient elevation shadow.
/// 4. Zero-Collision Layout:
///    - Balanced 320dp width with 77.5dp per tab slot.
///    - Icon + Label comfortably fit inside the sliding glass pill without clipping.
class LiquidLensNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const LiquidLensNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<LiquidLensNavBar> createState() => _LiquidLensNavBarState();
}

class _LiquidLensNavBarState extends State<LiquidLensNavBar> {
  static const double _kDockWidth = 320.0;
  static const double _kDockHeight = 52.0;
  static const double _kPaddingH = 5.0;
  static const double _kPaddingV = 4.0;
  static const int _kTabCount = 4;

  // Track geometry
  static const double _kTrackWidth = _kDockWidth - (2 * _kPaddingH); // 310.0
  static const double _kSlotWidth = _kTrackWidth / _kTabCount; // 77.5
  static const double _kPillHeight = _kDockHeight - (2 * _kPaddingV); // 44.0

  int _lastHapticIndex = -1;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  void _handleTouch(Offset localPos) {
    final double innerX = localPos.dx - _kPaddingH;
    final int targetIndex = (innerX / _kSlotWidth).floor().clamp(0, _kTabCount - 1);

    if (targetIndex != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(targetIndex);
    } else if (targetIndex != _lastHapticIndex) {
      _lastHapticIndex = targetIndex;
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
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

        // 1:1 LastWave Optical Glass Substrate:
        // Ultra-translucent 22% dark tint so colors and album art underneath bleed through clearly
        final railBg = isDark
            ? (useGlass ? const Color(0x38000000) : const Color(0xF012151A))
            : (useGlass ? Colors.white.withOpacity(0.60) : Colors.white);

        final railBorder = isDark
            ? Colors.white.withOpacity(0.14)
            : Colors.black.withOpacity(0.08);

        return Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTouch(details.localPosition),
              onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  // 12dp Gaussian blur (LastWave exact spec: crisp optical glass, never muddy)
                  filter: useGlass
                      ? ImageFilter.blur(sigmaX: 12, sigmaY: 12)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    width: _kDockWidth,
                    height: _kDockHeight,
                    decoration: BoxDecoration(
                      color: railBg,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: railBorder, width: 0.8),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: const Color(0x12000000),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: Stack(
                      children: [
                        // 1. Physical Sliding Glass Lens (Continuous Slide Animation)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          left: _kPaddingH + (widget.currentIndex * _kSlotWidth),
                          top: _kPaddingV,
                          width: _kSlotWidth,
                          height: _kPillHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              // Pure translucent water-clear glass capsule
                              color: isDark
                                  ? Colors.white.withOpacity(0.14)
                                  : Colors.black.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.28)
                                    : Colors.black.withOpacity(0.12),
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2. Tab Items Row (Stationary grid above the sliding lens)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _kPaddingH,
                            vertical: _kPaddingV,
                          ),
                          child: Row(
                            children: List.generate(_tabs.length, (index) {
                              final tab = _tabs[index];
                              final isSelected = widget.currentIndex == index;

                              final activeColor = isDark ? Colors.white : AppColors.lightTextPrimary;
                              final inactiveColor = isDark
                                  ? Colors.white.withOpacity(0.50)
                                  : AppColors.lightTextMuted;

                              return SizedBox(
                                width: _kSlotWidth,
                                height: _kPillHeight,
                                child: InkWell(
                                  onTap: () {
                                    if (widget.currentIndex != index) {
                                      if (appState.hapticsEnabled) {
                                        HapticFeedback.selectionClick();
                                      }
                                      widget.onTabSelected(index);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          tab.icon,
                                          size: 20,
                                          color: isSelected ? activeColor : inactiveColor,
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              tab.label,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                                color: activeColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.clip,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
