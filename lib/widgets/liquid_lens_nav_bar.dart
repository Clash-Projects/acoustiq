import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_settings.dart';

/// KowSU-Inspired 3D Optical Liquid Lens Navigation Bar
///
/// Features:
/// 1. Floating frosted capsule track with uniform silky perimeter
/// 2. Water-clear 3D refractive liquid lens droplet
/// 3. Dynamic overhang on hold/drag: 64px lens overhanging 56px track (4px top & bottom)
/// 4. Molten horizontal fluid elongation proportional to drag velocity
/// 5. Boundary collision squash & volume conservation bulge
/// 6. Prismatic caustic highlights: Solar amber top crest, sky-cyan bottom bounce rim
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

class _LiquidLensNavBarState extends State<LiquidLensNavBar> with TickerProviderStateMixin {
  late AnimationController _springController;
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;

  double _currentX = 0.0;
  double _targetX = 0.0;
  double _dragVelocityX = 0.0;
  bool _isDragging = false;

  final List<({IconData icon, String label})> _tabs = const [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  void _snapToTab(int tabIndex, double tabWidth) {
    _targetX = tabIndex * tabWidth;
    final startX = _currentX;

    _springController.stop();
    final anim = Tween<double>(begin: startX, end: _targetX).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );

    anim.addListener(() {
      setState(() {
        _currentX = anim.value;
      });
    });

    _springController.forward(from: 0.0);
    _expansionController.reverse();
    _isDragging = false;
    _dragVelocityX = 0.0;

    if (tabIndex != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(tabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appState, _springController, _expansionAnimation]),
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            const barHeight = 56.0;
            final tabWidth = totalWidth / _tabs.length;

            if (!_isDragging && !_springController.isAnimating) {
              _currentX = widget.currentIndex * tabWidth;
              _dragVelocityX = 0.0;
            }

            final minX = 0.0;
            final maxX = (_tabs.length - 1) * tabWidth;

            // Fluid dynamics: Boundary collision squash vs molten velocity stretch
            double stretchX = 1.0;
            double bulgeY = 1.0;

            if (_isDragging) {
              if (_currentX < minX) {
                // Left wall collision: horizontal squash, vertical volume bulge (KowSU Frame 030)
                final overshoot = (minX - _currentX).clamp(0.0, 36.0);
                stretchX = 1.0 - (overshoot / 36.0) * 0.30;
                bulgeY = 1.0 + (overshoot / 36.0) * 0.18;
              } else if (_currentX > maxX) {
                // Right wall collision: horizontal squash, vertical volume bulge
                final overshoot = (_currentX - maxX).clamp(0.0, 36.0);
                stretchX = 1.0 - (overshoot / 36.0) * 0.30;
                bulgeY = 1.0 + (overshoot / 36.0) * 0.18;
              } else if (_dragVelocityX.abs() > 0.8) {
                // Molten velocity stretch along drag trajectory (KowSU Frame 015)
                final vFactor = (_dragVelocityX.abs() / 14.0).clamp(0.0, 0.28);
                stretchX = 1.0 + vFactor;
                bulgeY = 1.0 - (vFactor * 0.14);
              }
            }

            final expansion = _expansionAnimation.value;

            // Resting: 46px height (comfortably within 56px track, 5px margin top & bottom)
            // Hold/Drag: expands to 64px height -> OVERHANGS the 56px track by 4px top & 4px bottom!
            // (1:1 recreation of KowSU Frames 005 & 040)
            final baseWidth = (tabWidth - 8.0) * stretchX;
            final baseHeight = (46.0 + (18.0 * expansion)) * bulgeY;

            final lensWidth = baseWidth.clamp(38.0, tabWidth * 1.6);
            final lensHeight = baseHeight.clamp(36.0, 66.0);

            // Compute lens placement with vertical overhang centering
            final lensLeft = _currentX + (tabWidth - lensWidth) / 2;
            final lensTop = (barHeight - lensHeight) / 2;

            return Listener(
              onPointerDown: (event) {
                _isDragging = true;
                _springController.stop();
                _expansionController.forward();
                if (appState.hapticsEnabled) {
                  HapticFeedback.lightImpact();
                }
                setState(() {
                  _dragVelocityX = 0.0;
                  final localX = (event.localPosition.dx - (tabWidth / 2)).clamp(-28.0, maxX + 28.0);
                  _currentX = localX;
                });
              },
              onPointerMove: (event) {
                setState(() {
                  _dragVelocityX = event.delta.dx;
                  double newX = _currentX + event.delta.dx;
                  if (newX < minX) {
                    newX = minX - (minX - newX) * 0.40;
                  } else if (newX > maxX) {
                    newX = maxX + (newX - maxX) * 0.40;
                  }
                  _currentX = newX;
                });
              },
              onPointerUp: (event) {
                final nearestTab = (_currentX / tabWidth).round().clamp(0, _tabs.length - 1);
                _snapToTab(nearestTab, tabWidth);
              },
              onPointerCancel: (event) {
                final nearestTab = (_currentX / tabWidth).round().clamp(0, _tabs.length - 1);
                _snapToTab(nearestTab, tabWidth);
              },
              child: SizedBox(
                height: barHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 1. Frosted Translucent Track Capsule with Soft Uniform Border
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F1523).withOpacity(0.76)
                                : Colors.white.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(28),
                            // UNIFORM SILKY TRACK BORDER (No harsh top wire)
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.14)
                                  : Colors.black.withOpacity(0.08),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.45 : 0.09),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. 3D LIQUID LENS DROPLET (Overhangs track by 4-6px on hold/drag)
                    Positioned(
                      left: lensLeft,
                      top: lensTop,
                      width: lensWidth,
                      height: lensHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(lensHeight / 2),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 20 + (10 * expansion),
                            sigmaY: 20 + (10 * expansion),
                          ),
                          child: CustomPaint(
                            painter: _KowSULiquidLensPainter(
                              isDark: isDark,
                              expansion: expansion,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(lensHeight / 2),
                                boxShadow: [
                                  // Contact elevation shadow directly under the lens droplet
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35 + (0.18 * expansion)),
                                    blurRadius: 10 + (10 * expansion),
                                    offset: Offset(0, 3 + (3 * expansion)),
                                  ),
                                  // Specular ambient glow
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.08 + (0.06 * expansion)),
                                    blurRadius: 12 + (6 * expansion),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Crisp Tab Items (Icons + Inter Typography)
                    Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = index == widget.currentIndex;
                        final tab = _tabs[index];

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _snapToTab(index, tabWidth);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tab.icon,
                                    size: 20,
                                    color: isSelected
                                        ? (isDark ? Colors.white : const Color(0xFF0A0E17))
                                        : (isDark ? Colors.white.withOpacity(0.40) : Colors.black.withOpacity(0.42)),
                                  ),
                                  const SizedBox(height: 2.5),
                                  Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark ? Colors.white : const Color(0xFF0A0E17))
                                          : (isDark ? Colors.white.withOpacity(0.40) : Colors.black.withOpacity(0.42)),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// KowSU-Accurate Optical Caustic Lens Painter
///
/// Implements:
/// - Water-clear crystal Fresnel body
/// - Amber-gold iridescent solar caustic crest on top rim
/// - Sky-cyan cerulean bounce reflection on bottom rim
/// - Silky specular perimeter
class _KowSULiquidLensPainter extends CustomPainter {
  final bool isDark;
  final double expansion;

  _KowSULiquidLensPainter({
    required this.isDark,
    required this.expansion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 1. Crystal Water-Clear Optical Body (Pure transparency, zero muddy dye)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 1.15,
        colors: [
          Colors.white.withOpacity(isDark ? (0.09 + 0.04 * expansion) : (0.34 + 0.08 * expansion)),
          Colors.white.withOpacity(isDark ? 0.025 : 0.08),
          Colors.white.withOpacity(isDark ? 0.008 : 0.03),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 2. Silky Specular Perimeter Rim
    final rimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.85 + (0.12 * expansion)),
        Colors.white.withOpacity(isDark ? 0.20 : 0.35),
        Colors.white.withOpacity(isDark ? 0.12 : 0.20),
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 + (0.3 * expansion);
    canvas.drawRRect(rrect, rimPaint);

    // 3. Solar Amber-Gold Top Caustic Crest (Overhead keylight reflection)
    final topHighlightPath = Path();
    final arcWidth = size.width * 0.64;
    final arcLeft = (size.width - arcWidth) / 2;
    topHighlightPath.moveTo(arcLeft, 1.2);
    topHighlightPath.quadraticBezierTo(
      size.width / 2,
      -0.8,
      arcLeft + arcWidth,
      1.2,
    );

    final topHighlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFFD580).withOpacity(0.0),
          const Color(0xFFFFF0D0).withOpacity(0.92 + (0.08 * expansion)),
          const Color(0xFFFFD580).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(arcLeft, 0, arcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 + (0.4 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // 4. Sky-Cyan Bottom Ground Bounce Reflection
    final bottomBouncePath = Path();
    final bArcWidth = size.width * 0.48;
    final bArcLeft = (size.width - bArcWidth) / 2;
    bottomBouncePath.moveTo(bArcLeft, size.height - 1.2);
    bottomBouncePath.quadraticBezierTo(
      size.width / 2,
      size.height + 0.8,
      bArcLeft + bArcWidth,
      size.height - 1.2,
    );

    final bottomBouncePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF38BDF8).withOpacity(0.0),
          const Color(0xFF38BDF8).withOpacity(0.32 + (0.16 * expansion)),
          const Color(0xFF38BDF8).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(bArcLeft, size.height - 3, bArcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 + (0.2 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bottomBouncePath, bottomBouncePaint);
  }

  @override
  bool shouldRepaint(covariant _KowSULiquidLensPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.expansion != expansion;
  }
}
