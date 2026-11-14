import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave Liquid Sliding Glass Dock (Option 1: Optical Hybrid v2)
///
/// Features:
/// 1. True 1:1 LastWave Optical Glass Substrate:
///    - Frosted white photon sheen (WWDC25 & LastWave spec) scatters ambient light over
///      16dp blur so the dock reads as luminous physical frosted glass rather than a dark hole.
///    - Background content and colors bleed through with optical luminance without dark smudging.
///    - Soft ambient elevation shadows (alpha 0.18 / 0.08) match LastWave's exact subtle elevation.
/// 2. Direct 1:1 Port of LastWave LiquidBubbleHighlight:
///    - 3-tier nested stroke layering (6.0dp, 3.5dp, 1.5dp) clipped to the silhouette
///      produces authentic 3D convex curvature and water-droplet meniscus thickness.
///    - High-contrast directional specular highlight (85% white) along the top-left rim.
///    - Lower-right ambient reflection rim with transparent side edges.
/// 3. Physical Sliding Glass Lens (Continuous Motion):
///    - Glides smoothly across the track with synchronized 300ms cubic ease.
///    - Dynamic breathing room: 102dp for active tab, 76dp for inactives (Zero text clipping).
/// 4. High-Contrast Optics:
///    - Inactive icons boosted to 82% crisp white, matching LastWave's resting contrast.
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

        // Frosted white photon sheen (WWDC25 & LastWave spec):
        // White photons scatter ambient light over the 16dp blur so the dock reads as
        // luminous physical frosted glass rather than a dark hole.
        final railBg = isDark
            ? (useGlass ? const Color(0x1EFFFFFF) : const Color(0xF012151A))
            : (useGlass ? Colors.white.withOpacity(0.72) : Colors.white);

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
                  // 16dp Gaussian optical blur (crisp, optical, never muddy)
                  filter: useGlass
                      ? ImageFilter.blur(sigmaX: 16, sigmaY: 16)
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
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(0x14000000),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Stack(
                        children: [
                          // 1. Physical Sliding Glass Lens (3D Water Droplet)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: pillLeft,
                            top: _kPaddingV,
                            width: _kActiveSlotWidth,
                            height: _kPillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.20 : 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2.5),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(isDark ? 0.08 : 0.0),
                                    blurRadius: 1,
                                    offset: const Offset(0, -0.5),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                // 1:1 Port of LastWave LiquidBubbleHighlight with 3-Tier Layering
                                painter: _LiquidBubbleHighlightPainter(isDark: isDark),
                              ),
                            ),
                          ),

                          // 2. Tab Items Row (High Contrast Optics)
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
                                    ? Colors.white.withOpacity(0.82)
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

/// CustomPainter that renders a dual-pass specular light catch rim along the dock top
class _DockSpecularRimPainter extends CustomPainter {
  final bool isDark;
  final double radius;

  _DockSpecularRimPainter({required this.isDark, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(0.5);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(isDark ? 0.55 : 0.80),
          Colors.white.withOpacity(isDark ? 0.20 : 0.35),
          Colors.white.withOpacity(isDark ? 0.05 : 0.10),
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _DockSpecularRimPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.radius != radius;
}

/// 1:1 Port of LastWave LiquidBubbleHighlight:
/// Uses 3-tier nested stroke layering (6.0dp, 3.5dp, 1.5dp) clipped to the silhouette
/// to produce true 3D convex curvature and water-droplet meniscus thickness.
class _LiquidBubbleHighlightPainter extends CustomPainter {
  final bool isDark;

  _LiquidBubbleHighlightPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final radius = Radius.circular(size.height / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final rimRRect = rrect.deflate(0.5);

    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Surface reflection (soft vertical sheen)
    final surfacePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(isDark ? 0.08 : 0.12),
          Colors.white.withOpacity(isDark ? 0.01 : 0.02),
          Colors.transparent,
          Colors.white.withOpacity(isDark ? 0.02 : 0.03),
        ],
        stops: const [0.0, 0.38, 0.64, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, surfacePaint);

    // 2. Layered inset lower shade bands (LastWave 3-Tier Layered Curvature)
    // Clipping strokes centred on the outline leaves soft inset depth without hard bevels.
    final lowerShadeShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.transparent,
        Colors.black.withOpacity(0.03),
        Colors.black.withOpacity(isDark ? 0.16 : 0.10),
      ],
      stops: const [0.0, 0.50, 0.74, 1.0],
    ).createShader(rect);

    final broadShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..shader = lowerShadeShader;
    canvas.drawRRect(rrect, broadShade);

    final middleShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = lowerShadeShader;
    canvas.drawRRect(rrect, middleShade);

    final narrowShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = lowerShadeShader;
    canvas.drawRRect(rrect, narrowShade);

    // 3. Upper-left specular light catch rim (Direct LastWave formula)
    final upperRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: const Alignment(0.60, 1.0),
        colors: [
          Colors.white.withOpacity(isDark ? 0.85 : 0.95),
          Colors.white.withOpacity(isDark ? 0.40 : 0.52),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.52, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, upperRimPaint);

    // 4. Lower-right ambient reflection rim (Direct LastWave formula)
    final lowerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(isDark ? 0.35 : 0.42),
        ],
        stops: const [0.0, 0.62, 0.84, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, lowerRimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidBubbleHighlightPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
