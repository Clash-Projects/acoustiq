import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import 'squircle.dart';

/// 1:1 KowSU & LastWave Optical Liquid Lens Navigation Bar
///
/// Features:
/// 1. Layer Inversion: Icons sit UNDER the lens, droplet floats OVER the icons.
/// 2. Real Optical Magnification: Active icon swells to 1.28× inside the liquid droplet.
/// 3. Fluid Drag Lensing: Icons swell & shrink dynamically as the droplet glides over them.
/// 4. 4px Top & Bottom Overhang on hold/drag (64px lens over 56px track).
/// 5. Always-on Caustic Rim: Solar amber top crest & sky-cyan bottom bounce reflection.
/// 6. Boundary collision squash & volume conservation bulge.
/// 7. Responsive dock width: scales gracefully on phones and tablets.
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

            // Fluid dynamics: collision squash vs molten velocity stretch
            double stretchX = 1.0;
            double bulgeY = 1.0;

            if (_isDragging) {
              if (_currentX < minX) {
                // Left wall collision squash & vertical volume bulge (KowSU Frame 030)
                final overshoot = (minX - _currentX).clamp(0.0, 36.0);
                stretchX = 1.0 - (overshoot / 36.0) * 0.30;
                bulgeY = 1.0 + (overshoot / 36.0) * 0.18;
              } else if (_currentX > maxX) {
                // Right wall collision squash & vertical volume bulge
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

            // Resting: 46px height (within 56px track, 5px margin top & bottom)
            // Hold/Drag: expands to 64px height -> OVERHANGS the 56px track by 4px top & bottom!
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
                    // LAYER 1: Frosted Squircle Track Capsule
                    ClipPath(
                      clipper: const SquircleClipper(radius: 28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF111216).withOpacity(0.78)
                                : Colors.white.withOpacity(0.84),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Hairline border on the Squircle Track Capsule
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SquircleBorderPainter(
                          radius: 28,
                          borderColor: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.black.withOpacity(0.06),
                          borderWidth: 0.5,
                        ),
                      ),
                    ),

                    // LAYER 2: Tab Items UNDER the Lens (With Dynamic Optical Magnification!)
                    Row(
                      children: List.generate(_tabs.length, (index) {
                        final tab = _tabs[index];
                        final tabCenterX = (index + 0.5) * tabWidth;

                        // Dynamic Refractive Magnification Math:
                        // As the droplet approaches this tab, the icon physically swells up to 1.28x
                        final dropletCenterX = _currentX + tabWidth / 2;
                        final distance = (dropletCenterX - tabCenterX).abs();
                        final proximity = (1.0 - (distance / (tabWidth * 1.15))).clamp(0.0, 1.0);
                        final smoothT = Curves.easeOutCubic.transform(proximity);
                        final magnification = 1.0 + (0.28 * smoothT);
                        final iconOpacity = lerpDouble(isDark ? 0.55 : 0.45, 1.0, smoothT)!;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _snapToTab(index, tabWidth);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Transform.scale(
                                scale: magnification,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tab.icon,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white.withOpacity(iconOpacity)
                                          : const Color(0xFF0A0B0E).withOpacity(iconOpacity),
                                    ),
                                    const SizedBox(height: 2.5),
                                    Text(
                                      tab.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.5,
                                        fontWeight: proximity > 0.6 ? FontWeight.w700 : FontWeight.w500,
                                        color: isDark
                                            ? Colors.white.withOpacity(iconOpacity)
                                            : const Color(0xFF0A0B0E).withOpacity(iconOpacity),
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    // LAYER 3: 3D LIQUID LENS DROPLET FLOATING OVER THE TABS!
                    Positioned(
                      left: lensLeft,
                      top: lensTop,
                      width: lensWidth,
                      height: lensHeight,
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(lensHeight / 2),
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
/// - Water-clear crystal body with resting 0.22 opacity
/// - Amber-gold solar caustic top crest
/// - Sky-cyan cerulean bottom bounce reflection
/// - Silky 0.5px sub-pixel perimeter
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

    // 1. Crystal Water-Clear Optical Body (Resting opacity boosted to 0.22, zero muddy dye)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 1.15,
        colors: [
          Colors.white.withOpacity(isDark ? (0.22 + 0.08 * expansion) : (0.42 + 0.10 * expansion)),
          Colors.white.withOpacity(isDark ? 0.08 : 0.16),
          Colors.white.withOpacity(isDark ? 0.02 : 0.05),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 2. Silky Sub-Pixel Perimeter Rim
    final rimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.85 + (0.12 * expansion)),
        Colors.white.withOpacity(isDark ? 0.25 : 0.40),
        Colors.white.withOpacity(isDark ? 0.14 : 0.25),
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 + (0.3 * expansion);
    canvas.drawRRect(rrect, rimPaint);

    // 3. Solar Amber-Gold Top Caustic Crest (Always active, gleaming on upper curve)
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
          const Color(0xFFFFF0D0).withOpacity(0.88 + (0.12 * expansion)),
          const Color(0xFFFFD580).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(arcLeft, 0, arcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 + (0.4 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // 4. Sky-Cyan Bottom Ground Bounce Reflection (Always active on lower curve)
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
          const Color(0xFF38BDF8).withOpacity(0.35 + (0.15 * expansion)),
          const Color(0xFF38BDF8).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(bArcLeft, size.height - 3, bArcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (0.2 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bottomBouncePath, bottomBouncePaint);
  }

  @override
  bool shouldRepaint(covariant _KowSULiquidLensPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.expansion != expansion;
  }
}
