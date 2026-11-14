import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave Liquid Sliding Glass Dock (Option 1: Optical Hybrid)
///
/// Features:
/// 1. True 1:1 LastWave Optical Glass Substrate:
///    - Crisp 14dp Gaussian optical blur allows wallpaper, album art, and content
///      underneath to bleed through with vibrant glass translucency (matching
///      the reference photo's red badge bleed-through).
///    - Top specular chamfered hairline rim catches ambient light on the glass plate.
/// 2. Physical Sliding Glass Lens (Continuous Motion):
///    - Dedicated glass capsule that physically GLIDES across the dock from tab to tab.
///    - True sliding spring animation (Curves.easeOutCubic, 300ms).
///    - Real-time drag/scrub tracking across tabs.
/// 3. Direct Port of LastWave LiquidBubbleHighlight:
///    - Clear water-lens capsule with top-left ambient specular reflection.
///    - Transparent side edges (never a cartoon wireframe outline).
///    - Soft vertical surface sheen and ambient elevation depth.
/// 4. Asymmetric Zero-Collision Geometry:
///    - 340dp dock width. Active tab gets 102dp, inactives get 76dp.
///    - Full 10-character words like "Duplicates" have ample breathing room, zero clipping.
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
  static const double _kDockWidth = 340.0;
  static const double _kDockHeight = 52.0;
  static const double _kPaddingH = 5.0;
  static const double _kPaddingV = 4.0;
  static const int _kTabCount = 4;

  // Geometry: 340 - 10 = 330dp inner track width
  // Active slot gets 102dp (fits 10-letter words like "Duplicates" comfortably)
  // 3 Inactive slots share remaining 228dp equally = 76dp each
  static const double _kActiveSlotWidth = 102.0;
  static const double _kInactiveSlotWidth = 76.0;
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
    if (innerX < 0) {
      _selectTab(0);
      return;
    }
    final int current = widget.currentIndex;
    int target = 0;
    double accumulated = 0.0;
    for (int i = 0; i < _kTabCount; i++) {
      final double width = (i == current) ? _kActiveSlotWidth : _kInactiveSlotWidth;
      if (innerX >= accumulated && innerX < accumulated + width) {
        target = i;
        break;
      }
      accumulated += width;
      if (i == _kTabCount - 1) {
        target = _kTabCount - 1;
      }
    }
    _selectTab(target);
  }

  void _selectTab(int targetIndex) {
    final int clamped = targetIndex.clamp(0, _kTabCount - 1);
    if (clamped != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(clamped);
    } else if (clamped != _lastHapticIndex) {
      _lastHapticIndex = clamped;
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

        // LastWave Translucent Optical Substrate:
        // Translucent frosted white/neutral wash over 14dp blur lets background
        // content and vibrant colors bleed through with optical luminance.
        final railBg = isDark
            ? (useGlass ? const Color(0x2812161E) : const Color(0xF012151A))
            : (useGlass ? Colors.white.withOpacity(0.68) : Colors.white);

        // Linear continuous pill position:
        // Active 0: 5.0, Active 1: 81.0, Active 2: 157.0, Active 3: 233.0
        final pillLeft = _kPaddingH + (widget.currentIndex * _kInactiveSlotWidth);

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
                  // 14dp Gaussian optical blur (crisp, optical, never muddy)
                  filter: useGlass
                      ? ImageFilter.blur(sigmaX: 14, sigmaY: 14)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: CustomPaint(
                    // WWDC25 & LastWave Specular Light Catch Rim along top edge
                    painter: _DockSpecularRimPainter(
                      isDark: isDark,
                      radius: 26,
                    ),
                    child: Container(
                      width: _kDockWidth,
                      height: _kDockHeight,
                      decoration: BoxDecoration(
                        color: railBg,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 18,
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
                                  color: const Color(0x18000000),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      child: Stack(
                        children: [
                          // 1. Physical Sliding Glass Lens (Continuous Motion)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: pillLeft,
                            top: _kPaddingV,
                            width: _kActiveSlotWidth,
                            height: _kPillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                // Ultra-clear water-lens wash
                                color: isDark
                                    ? Colors.white.withOpacity(0.09)
                                    : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                // 1:1 Port of LastWave LiquidBubbleHighlight
                                painter: _LiquidBubbleHighlightPainter(isDark: isDark),
                              ),
                            ),
                          ),

                          // 2. Tab Items Row (Synchronized fluid layout)
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
                                    ? Colors.white.withOpacity(0.55)
                                    : AppColors.lightTextMuted;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: isSelected ? _kActiveSlotWidth : _kInactiveSlotWidth,
                                  height: _kPillHeight,
                                  child: InkWell(
                                    onTap: () => _selectTab(index),
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
                                            size: isSelected ? 19.0 : 20.0,
                                            color: isSelected ? activeColor : inactiveColor,
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
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
                                                overflow: TextOverflow.visible,
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
          ),
        );
      },
    );
  }
}

/// CustomPainter that renders the top specular chamfered hairline rim on the dock
class _DockSpecularRimPainter extends CustomPainter {
  final bool isDark;
  final double radius;

  _DockSpecularRimPainter({required this.isDark, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(0.4);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(isDark ? 0.38 : 0.65),
          Colors.white.withOpacity(isDark ? 0.12 : 0.25),
          Colors.white.withOpacity(isDark ? 0.04 : 0.08),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _DockSpecularRimPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.radius != radius;
}

/// CustomPainter that directly ports LastWave's LiquidBubbleHighlight optics:
/// 1. Top-left directional ambient specular reflection (bright light catch).
/// 2. Lower-right ambient reflection rim.
/// 3. Soft vertical surface sheen.
/// 4. Side edges remain transparent so it reads as physical convex glass, not a painted border.
class _LiquidBubbleHighlightPainter extends CustomPainter {
  final bool isDark;

  _LiquidBubbleHighlightPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final radius = Radius.circular(size.height / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final rimRRect = rrect.deflate(0.4);

    // 1. Surface reflection (soft vertical translucent sheen)
    final surfacePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(isDark ? 0.10 : 0.14),
          Colors.white.withOpacity(isDark ? 0.015 : 0.03),
          Colors.transparent,
          Colors.white.withOpacity(isDark ? 0.025 : 0.04),
        ],
        stops: const [0.0, 0.38, 0.64, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, surfacePaint);

    // 2. Upper-left specular light catch rim (Direct LastWave formula)
    final upperRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: const Alignment(0.60, 1.0),
        colors: [
          Colors.white.withOpacity(isDark ? 0.72 : 0.85),
          Colors.white.withOpacity(isDark ? 0.32 : 0.45),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.52, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, upperRimPaint);

    // 3. Lower-right ambient reflection rim (Direct LastWave formula)
    final lowerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(isDark ? 0.26 : 0.32),
        ],
        stops: const [0.0, 0.62, 0.84, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, lowerRimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidBubbleHighlightPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
