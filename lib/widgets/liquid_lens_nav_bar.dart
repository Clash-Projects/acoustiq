import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

/// Flagship KowSU & visionOS 3D Liquid Lens Navigation Bar
///
/// Features:
/// 1. Stable Dock Coordinates: Zero adjacent ballooning, zero layout jitter.
/// 2. High-Contrast Luminous 3D Water Droplet: Water-clear crystal body, specular glints, solar amber crest & cyan ground bounce.
/// 3. Physical Optical Lensing Viewport: Magnification (1.18×) and luminous white illumination occur strictly INSIDE the droplet boundary.
/// 4. Molten Fluid Dynamics: Velocity stretch on drag trajectory, boundary cushions, and snappy spring snap.
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
      duration: const Duration(milliseconds: 300),
    );

    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
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

            // Fluid dynamics: collision cushion vs molten velocity stretch
            double stretchX = 1.0;
            double bulgeY = 1.0;

            if (_isDragging) {
              if (_currentX < minX) {
                // Left boundary cushion
                final overshoot = (minX - _currentX).clamp(0.0, 32.0);
                stretchX = 1.0 - (overshoot / 32.0) * 0.25;
                bulgeY = 1.0 + (overshoot / 32.0) * 0.15;
              } else if (_currentX > maxX) {
                // Right boundary cushion
                final overshoot = (_currentX - maxX).clamp(0.0, 32.0);
                stretchX = 1.0 - (overshoot / 32.0) * 0.25;
                bulgeY = 1.0 + (overshoot / 32.0) * 0.15;
              } else if (_dragVelocityX.abs() > 0.8) {
                // Molten velocity stretch along drag trajectory
                final vFactor = (_dragVelocityX.abs() / 16.0).clamp(0.0, 0.22);
                stretchX = 1.0 + vFactor;
                bulgeY = 1.0 - (vFactor * 0.11);
              }
            }

            final expansion = _expansionAnimation.value;

            // Resting: 46px height (clean 5px margin inside 56px track)
            // Dragging: expands to 52px height
            final baseWidth = (tabWidth - 6.0) * stretchX;
            final baseHeight = (46.0 + (6.0 * expansion)) * bulgeY;

            final lensWidth = baseWidth.clamp(38.0, tabWidth * 1.55);
            final lensHeight = baseHeight.clamp(36.0, 54.0);

            // Compute lens placement centered on tab
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
                  final localX = (event.localPosition.dx - (tabWidth / 2)).clamp(-20.0, maxX + 20.0);
                  _currentX = localX;
                });
              },
              onPointerMove: (event) {
                setState(() {
                  _dragVelocityX = event.delta.dx;
                  double newX = _currentX + event.delta.dx;
                  if (newX < minX) {
                    newX = minX - (minX - newX) * 0.35;
                  } else if (newX > maxX) {
                    newX = maxX + (newX - maxX) * 0.35;
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
                    // LAYER 1: Frosted Track Capsule with Multi-Stage Drop Shadow
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          // 1. Sharp Contact Shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.60 : 0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                          // 2. Deep Diffuse Ambient Float Shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.45 : 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111111).withOpacity(0.85)
                                  : Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.16)
                                    : Colors.black.withOpacity(0.08),
                                width: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // LAYER 2: Base Stable Tab Items (Crisp, anchored, muted opacity)
                    Row(
                      children: List.generate(_tabs.length, (index) {
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
                                    color: isDark
                                        ? Colors.white.withOpacity(0.38)
                                        : const Color(0xFF111111).withOpacity(0.38),
                                  ),
                                  const SizedBox(height: 2.5),
                                  Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.38)
                                          : const Color(0xFF111111).withOpacity(0.38),
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

                    // LAYER 3: 3D HIGH-CONTRAST WATER DROPLET FLOATING OVER TRACK
                    Positioned(
                      left: lensLeft,
                      top: lensTop,
                      width: lensWidth,
                      height: lensHeight,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(lensHeight / 2),
                            boxShadow: [
                              // 1. Deep Contact Elevation Shadow directly beneath the droplet
                              BoxShadow(
                                color: Colors.black.withOpacity(0.80),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                              // 2. Ambient Specular Refraction Glow
                              BoxShadow(
                                color: Colors.white.withOpacity(0.25 + 0.15 * expansion),
                                blurRadius: 16,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(lensHeight / 2),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Stack(
                                children: [
                                  // Droplet Luminous Optical Body, Glint & Caustics
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _KowSULiquidLensPainter(
                                        isDark: isDark,
                                        expansion: expansion,
                                      ),
                                    ),
                                  ),

                                  // OPTICAL LENSING VIEWPORT:
                                  // Tab content is rendered strictly INSIDE the droplet at 1.18x magnification
                                  // and brilliant pure white opacity!
                                  Positioned(
                                    left: -lensLeft,
                                    top: (lensHeight - barHeight) / 2,
                                    width: totalWidth,
                                    height: barHeight,
                                    child: Transform.scale(
                                      scale: 1.18,
                                      origin: Offset(lensLeft + lensWidth / 2, barHeight / 2),
                                      child: Row(
                                        children: List.generate(_tabs.length, (index) {
                                          final tab = _tabs[index];
                                          return Expanded(
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    tab.icon,
                                                    size: 20,
                                                    color: isDark ? Colors.white : Colors.black,
                                                  ),
                                                  const SizedBox(height: 2.5),
                                                  Text(
                                                    tab.label,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: isDark ? Colors.white : Colors.black,
                                                      letterSpacing: 0.1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
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

/// KowSU High-Definition Optical Caustic Lens Painter
///
/// Implements:
/// - Water-clear crystal body with high luminance (0.42+ opacity)
/// - Brilliant water-drop specular glint on the top-left shoulder
/// - Solar amber-gold top caustic crest (always gleaming)
/// - Sky-cyan ground bounce reflection (always gleaming)
/// - Silky 1.0px sub-pixel perimeter rim
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

    // 1. Crystal Water-Clear Optical Body (High Luminance)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.45),
        radius: 1.15,
        colors: [
          Colors.white.withOpacity(isDark ? (0.40 + 0.12 * expansion) : (0.65 + 0.10 * expansion)),
          Colors.white.withOpacity(isDark ? 0.16 : 0.30),
          Colors.white.withOpacity(isDark ? 0.05 : 0.10),
        ],
        stops: const [0.0, 0.60, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 2. Water-Drop Specular Glint (Top-left curved highlight catch)
    final glintPath = Path();
    final glintWidth = size.width * 0.38;
    final glintLeft = (size.width - glintWidth) / 2 - (size.width * 0.10);
    glintPath.addOval(
      Rect.fromLTWH(glintLeft, 3.2, glintWidth, size.height * 0.32),
    );

    final glintPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.6),
        radius: 0.8,
        colors: [
          Colors.white.withOpacity(0.70 + 0.15 * expansion),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(glintLeft, 3.2, glintWidth, size.height * 0.32));
    canvas.drawPath(glintPath, glintPaint);

    // 3. Solar Amber-Gold Top Caustic Crest (Always active, glowing intensely on upper curve)
    final topHighlightPath = Path();
    final arcWidth = size.width * 0.65;
    final arcLeft = (size.width - arcWidth) / 2;
    topHighlightPath.moveTo(arcLeft, 1.4);
    topHighlightPath.quadraticBezierTo(
      size.width / 2,
      -0.8,
      arcLeft + arcWidth,
      1.4,
    );

    final topHighlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFFD580).withOpacity(0.0),
          const Color(0xFFFFF4D8).withOpacity(0.95),
          const Color(0xFFFFD580).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(arcLeft, 0, arcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 + (0.4 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // 4. Sky-Cyan Bottom Ground Bounce Reflection (Always active on lower curve)
    final bottomBouncePath = Path();
    final bArcWidth = size.width * 0.50;
    final bArcLeft = (size.width - bArcWidth) / 2;
    bottomBouncePath.moveTo(bArcLeft, size.height - 1.4);
    bottomBouncePath.quadraticBezierTo(
      size.width / 2,
      size.height + 0.8,
      bArcLeft + bArcWidth,
      size.height - 1.4,
    );

    final bottomBouncePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF38BDF8).withOpacity(0.0),
          const Color(0xFF38BDF8).withOpacity(0.65 + (0.15 * expansion)),
          const Color(0xFF38BDF8).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(bArcLeft, size.height - 3, bArcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 + (0.2 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bottomBouncePath, bottomBouncePaint);

    // 5. Silky Beveled Perimeter Rim
    final rimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.90 + (0.10 * expansion)),
        Colors.white.withOpacity(isDark ? 0.32 : 0.45),
        Colors.white.withOpacity(isDark ? 0.16 : 0.25),
      ],
      stops: const [0.0, 0.50, 1.0],
    );

    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (0.2 * expansion);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _KowSULiquidLensPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.expansion != expansion;
  }
}
