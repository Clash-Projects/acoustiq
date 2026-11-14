import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave Liquid Sliding Glass Dock (Volumetric Optical Glass v4)
///
/// Features:
/// 1. Physical Glass Slab Volumetric Gradient:
///    - Instead of a flat empty color, the dock substrate uses a physical light-bounce gradient
///      (14% white top catch, clear body core, 6% ground reflection) so it reads as a solid
///      3D optical glass cylinder even over dark/black backgrounds.
/// 2. Focal-Light Liquid Lens (Radial Optical Focus):
///    - Active pill features a directional radial focal gradient centered at the upper-left,
///      simulating light gathering inside a convex water droplet.
///    - High-elevation outer shadow (35% alpha, 10px blur) casts a physical drop shadow onto
///      the glass track bed, separating the liquid droplet from the rail.
/// 3. Meniscus 3-Tier Layered Shading & Specular Catch:
///    - Silhouette-clipped 3-band nested shading (6.0dp, 3.5dp, 1.5dp) creates physical
///      meniscus thickness without wireframe strokes.
///    - 92% bright specular white light catch arc along the upper-left chamfer.
/// 4. Compact Floating Island Geometry:
///    - 316dp dock width (leaves ~37dp breathing room on screen sides).
///    - 94dp active tab + 72dp inactives: "Duplicates" fits comfortably with 23dp extra padding,
///      zero text clipping.
///    - Inactive icons boosted to 78% crisp white.
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
  // Compact floating island geometry:
  // 316dp dock width leaves ~37dp breathing room on screen sides.
  static const double _kDockWidth = 316.0;
  static const double _kDockHeight = 50.0;
  static const double _kPaddingH = 3.0;
  static const double _kPaddingV = 2.0;
  static const int _kTabCount = 4;

  // Geometry: 316 - 6 = 310dp inner track width
  // Active slot gets 94dp (comfortably fits 10-letter words like "Duplicates")
  // 3 Inactive slots share remaining 216dp equally = 72dp each
  static const double _kActiveSlotWidth = 94.0;
  static const double _kInactiveSlotWidth = 72.0;
  static const double _kPillHeight = _kDockHeight - (2 * _kPaddingV); // 46.0

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

        // Linear continuous pill position:
        // Active 0: 3.0, Active 1: 75.0, Active 2: 147.0, Active 3: 219.0
        final pillLeft = _kPaddingH + (widget.currentIndex * _kInactiveSlotWidth);

        return Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTouch(details.localPosition),
              onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  // 14dp Gaussian optical blur (crisp, optical, never muddy)
                  filter: useGlass
                      ? ImageFilter.blur(sigmaX: 14, sigmaY: 14)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: CustomPaint(
                    // WWDC25 & LastWave Specular Light Catch Rim along top edge
                    painter: _DockSpecularRimPainter(
                      isDark: isDark,
                      radius: 25,
                    ),
                    child: Container(
                      width: _kDockWidth,
                      height: _kDockHeight,
                      decoration: BoxDecoration(
                        // Physical Glass Volume Gradient:
                        // Gives the glass cylinder real physical presence and depth
                        // even over pitch-black backgrounds.
                        gradient: useGlass
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        Colors.white.withOpacity(0.14), // top ambient light catch
                                        Colors.white.withOpacity(0.04), // upper body
                                        Colors.white.withOpacity(0.02), // clear core
                                        Colors.white.withOpacity(0.06), // bottom reflection
                                      ]
                                    : [
                                        Colors.white.withOpacity(0.85),
                                        Colors.white.withOpacity(0.70),
                                        Colors.white.withOpacity(0.65),
                                        Colors.white.withOpacity(0.78),
                                      ],
                                stops: const [0.0, 0.30, 0.70, 1.0],
                              )
                            : null,
                        color: useGlass
                            ? null
                            : (isDark ? const Color(0xF012151A) : Colors.white),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.10),
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
                          // 1. Physical Sliding Glass Lens (Focal-Light Liquid Droplet)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: pillLeft,
                            top: _kPaddingV,
                            width: _kActiveSlotWidth,
                            height: _kPillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                // Convex Focal-Light Radial Gradient:
                                // Simulates light gathering inside an elevated water bubble
                                gradient: RadialGradient(
                                  center: const Alignment(-0.25, -0.45),
                                  radius: 0.95,
                                  colors: isDark
                                      ? [
                                          Colors.white.withOpacity(0.12), // focal light gathering
                                          Colors.white.withOpacity(0.03),
                                          Colors.transparent,
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.40),
                                          Colors.white.withOpacity(0.12),
                                          Colors.transparent,
                                        ],
                                  stops: const [0.0, 0.50, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(23),
                                boxShadow: [
                                  // Physical drop shadow from water droplet onto glass slab
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(isDark ? 0.08 : 0.0),
                                    blurRadius: 2,
                                    offset: const Offset(0, -1),
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
                                    ? Colors.white.withOpacity(0.78)
                                    : AppColors.lightTextMuted;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: isSelected ? _kActiveSlotWidth : _kInactiveSlotWidth,
                                  height: _kPillHeight,
                                  child: InkWell(
                                    onTap: () => _selectTab(index),
                                    borderRadius: BorderRadius.circular(23),
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            tab.icon,
                                            size: isSelected ? 18.0 : 19.5,
                                            color: isSelected ? activeColor : inactiveColor,
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                tab.label,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 11.0,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.3,
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

    // Crisp specular hairline with ambient light focus
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(isDark ? 0.65 : 0.85),
          Colors.white.withOpacity(isDark ? 0.25 : 0.40),
          Colors.white.withOpacity(isDark ? 0.04 : 0.08),
        ],
        stops: const [0.0, 0.42, 1.0],
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

    // 1. Layered inset lower shade bands (LastWave 3-Tier Layered Curvature)
    // Clipping strokes centred on the outline leaves soft inset depth without hard bevels.
    final lowerShadeShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.transparent,
        Colors.black.withOpacity(0.03),
        Colors.black.withOpacity(isDark ? 0.18 : 0.10),
      ],
      stops: const [0.0, 0.45, 0.70, 1.0],
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

    // 2. Upper-left specular light catch rim (Direct LastWave formula)
    final upperRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: const Alignment(-0.5, -0.6),
        end: const Alignment(0.60, 1.0),
        colors: [
          Colors.white.withOpacity(isDark ? 0.92 : 0.98),
          Colors.white.withOpacity(isDark ? 0.45 : 0.60),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, upperRimPaint);

    // 3. Lower-right ambient reflection rim (Direct LastWave formula)
    final lowerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(isDark ? 0.40 : 0.48),
        ],
        stops: const [0.0, 0.60, 0.84, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, lowerRimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidBubbleHighlightPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
