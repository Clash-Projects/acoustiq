import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave & WWDC25 Frosted Glass Navigation Dock
///
/// Features:
/// 1. Perfect 1:1 LastWave Proportions:
///    - 54dp dock height (42dp active stadium pill) with balanced 296dp width.
///    - 48dp inactive touch slots with 21dp centered glyphs.
///    - 136dp active pill with 20dp icon + 8dp spacing + 13sp SemiBold typography.
/// 2. Deep Smoky Translucent Glass Substrate (Zero Opaque Mud):
///    - 40% neutral dark tint with real GPU 20dp Gaussian blur.
///    - Content, album art, and text glide through clearly underneath.
/// 3. True Water-Meniscus Specular Optics:
///    - Top specular highlight line simulating ambient ceiling reflection.
///    - Directional glass rim contour (brighter top-left, soft bottom-right).
///    - Dual-layer soft ambient drop shadow.
/// 4. Zero-Collision Horizontal Flow:
///    - Pure horizontal layout (Icon + Spacing + Label) prevents any text/icon overlap.
///    - Smooth spring expansion (Curves.easeOutCubic) with tactile haptic clicks.
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
  static const double _kPaddingH = 8.0;
  static const double _kDockHeight = 54.0;
  static const double _kInactiveWidth = 48.0;
  static const double _kActiveWidth = 136.0;
  static const double _kTotalWidth = (2 * _kPaddingH) + (3 * _kInactiveWidth) + _kActiveWidth; // 296.0

  int _lastHapticIndex = -1;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  void _handleTouchPosition(Offset localPos) {
    final double innerX = localPos.dx - _kPaddingH;
    if (innerX < 0) {
      _selectTab(0);
      return;
    }

    double cumulative = 0.0;
    for (int i = 0; i < _tabs.length; i++) {
      final width = (i == widget.currentIndex) ? _kActiveWidth : _kInactiveWidth;
      if (innerX >= cumulative && innerX < cumulative + width) {
        _selectTab(i);
        return;
      }
      cumulative += width;
    }
    if (innerX >= cumulative) {
      _selectTab(_tabs.length - 1);
    }
  }

  void _selectTab(int index) {
    final clamped = index.clamp(0, _tabs.length - 1);
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
        final activeAccent = appState.getAccentColor(context);

        // LastWave Smoky Translucent Glass (Zero opaque grey/blue tint)
        // Lets album art, text, and vibrant colors bleed through softly with GPU blur
        final dockBg = isDark
            ? (useGlass ? const Color(0x66000000) : const Color(0xF012151A))
            : (useGlass ? Colors.white.withOpacity(0.70) : Colors.white);

        final dockBorder = isDark
            ? Colors.white.withOpacity(0.14)
            : Colors.black.withOpacity(0.08);

        return Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTouchPosition(details.localPosition),
              onHorizontalDragUpdate: (details) => _handleTouchPosition(details.localPosition),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: useGlass
                      ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    width: _kTotalWidth,
                    height: _kDockHeight,
                    padding: const EdgeInsets.symmetric(horizontal: _kPaddingH, vertical: 6),
                    decoration: BoxDecoration(
                      color: dockBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: dockBorder, width: 0.8),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.20),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: const Color(0x18000000),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_tabs.length, (index) {
                        final tab = _tabs[index];
                        final isSelected = widget.currentIndex == index;

                        return _LastWaveDockTab(
                          icon: tab.icon,
                          label: tab.label,
                          isSelected: isSelected,
                          isDark: isDark,
                          useGlass: useGlass,
                          activeAccent: activeAccent,
                          onTap: () => _selectTab(index),
                        );
                      }),
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

/// Individual Tab Item with Spring Expansion & Horizontal Content Alignment
class _LastWaveDockTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final bool useGlass;
  final Color activeAccent;
  final VoidCallback onTap;

  const _LastWaveDockTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.useGlass,
    required this.activeAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeWidth = 136.0;
    const inactiveWidth = 48.0;

    final activeColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final inactiveColor = isDark ? Colors.white.withOpacity(0.55) : AppColors.lightTextMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: isSelected ? activeWidth : inactiveWidth,
      height: 42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(21),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: isSelected
              ? _GlassActivePill(
                  isDark: isDark,
                  useGlass: useGlass,
                  activeAccent: activeAccent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: activeColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: activeColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Icon(
                    icon,
                    size: 21,
                    color: inactiveColor,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Authentic Translucent Glass Pill Substrate with Specular Light Arc
class _GlassActivePill extends StatelessWidget {
  final bool isDark;
  final bool useGlass;
  final Color activeAccent;
  final Widget child;

  const _GlassActivePill({
    required this.isDark,
    required this.useGlass,
    required this.activeAccent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0x14000000),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: CustomPaint(
          painter: _GlassPillPainter(
            isDark: isDark,
            activeAccent: activeAccent,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for the Active Glass Pill:
/// 1. Subtle translucent white glass body (12-18% alpha)
/// 2. Top specular reflection line (ambient overhead light on water meniscus)
/// 3. Hairline directional refraction border (brighter top-left, soft bottom-right)
class _GlassPillPainter extends CustomPainter {
  final bool isDark;
  final Color activeAccent;

  _GlassPillPainter({
    required this.isDark,
    required this.activeAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(21),
    );

    // 1. Crystal Translucent Glass Body (Never opaque grey)
    // Subtle gradient giving convex optical depth
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.11),
                Colors.white.withOpacity(0.06),
              ]
            : [
                Colors.white.withOpacity(0.85),
                Colors.white.withOpacity(0.70),
                Colors.white.withOpacity(0.55),
              ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, bodyPaint);

    // 2. Top Specular Highlight Arc (Simulates overhead light reflection)
    final topArcPath = Path()
      ..moveTo(size.width * 0.16, 1.0)
      ..lineTo(size.width * 0.84, 1.0);

    final topArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          isDark ? const Color(0xE6FFFFFF) : Colors.white,
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(topArcPath, topArcPaint);

    // 3. Hairline Refraction Rim (Crisp, Directional 0.7px contour)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withOpacity(0.38),
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ]
            : [
                Colors.white,
                Colors.white.withOpacity(0.50),
                Colors.white.withOpacity(0.20),
              ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassPillPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.activeAccent != activeAccent;
  }
}
