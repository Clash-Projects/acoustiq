import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

/// Flagship KowSU & visionOS 3D Liquid Lens Navigation Bar
///
/// Features:
/// 1. Stable Dock Geometry: Zero fake zoom, zero adjacent icon ballooning, zero jitter.
/// 2. Water-Clear 3D Liquid Lens Droplet: Floats smoothly over the track with genuine optical diffusion.
/// 3. Always-on Caustic Radiance: Amber-gold solar crest & sky-cyan bottom ground reflection.
/// 4. Fluid Dynamics: Molten velocity stretch, boundary collision cushioning, and snappy spring snap.
/// 5. Strictly Neutral Palette: Absolute obsidian/charcoal tones (zero navy blue).
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
  void disposeValidate() {
    _springController.dispose();
    _expansionController.dispose();
  }

  @override
  void dispose() {
    disposeValidate();
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
            const barHeight = 54.0;
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
                final vFactor = (_dragVelocityX.abs() / 16.0).clamp(0.0, 0.20);
                stretchX = 1.0 + vFactor;
                bulgeY = 1.0 - (vFactor * 0.10);
              }
            }

            final expansion = _expansionAnimation.value;

            // Resting: 44px height (clean 5px margin inside 54px track)
            // Dragging: expands to 50px height
            final baseWidth = (tabWidth - 8.0) * stretchX;
            final baseHeight = (44.0 + (6.0 * expansion)) * bulgeY;

            final lensWidth = baseWidth.clamp(36.0, tabWidth * 1.5);
            final lensHeight = baseHeight.clamp(34.0, 52.0);

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
                    // LAYER 1: Frosted Smooth Track Capsule (Pure neutral, zero navy blue)
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.48 : 0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF121212).withOpacity(0.82)
                                  : Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(27),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.08),
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // LAYER 2: 3D LIQUID LENS DROPLET FLOATING OVER THE TRACK
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
                              // Soft contact shadow under the lens droplet
                              BoxShadow(
                                color: Colors.black.withOpacity(0.32 + (0.12 * expansion)),
                                blurRadius: 10 + (6 * expansion),
                                offset: Offset(0, 2 + (2 * expansion)),
                              ),
                              // Specular ambient glow
                              BoxShadow(
                                color: Colors.white.withOpacity(0.08 + (0.05 * expansion)),
                                blurRadius: 12 + (4 * expansion),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(lensHeight / 2),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: CustomPaint(
                                painter: _KowSULiquidLensPainter(
                                  isDark: isDark,
                                  expansion: expansion,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // LAYER 3: Tab Items (Rock-solid, crisp, stable layout - NO FAKE ZOOM!)
                    Row(
                      children: List.generate(_tabs.length, (index) {
                        final tab = _tabs[index];
                        final isSelected = index == widget.currentIndex;

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
                                        ? Colors.white.withOpacity(isSelected ? 1.0 : 0.45)
                                        : const Color(0xFF111111).withOpacity(isSelected ? 1.0 : 0.45),
                                  ),
                                  const SizedBox(height: 2.5),
                                  Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isDark
                                          ? Colors.white.withOpacity(isSelected ? 1.0 : 0.45)
                                          : const Color(0xFF111111).withOpacity(isSelected ? 1.0 : 0.45),
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
/// - Water-clear crystal body with resting 0.22 opacity
/// - Solar amber-gold top caustic crest
/// - Sky-cyan ground bounce reflection
/// - Silky 0.8px sub-pixel perimeter
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

    // 1. Crystal Water-Clear Optical Body
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 1.15,
        colors: [
          Colors.white.withOpacity(isDark ? (0.24 + 0.08 * expansion) : (0.42 + 0.10 * expansion)),
          Colors.white.withOpacity(isDark ? 0.09 : 0.18),
          Colors.white.withOpacity(isDark ? 0.03 : 0.06),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 2. Silky Sub-Pixel Perimeter Rim
    final rimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.82 + (0.14 * expansion)),
        Colors.white.withOpacity(isDark ? 0.24 : 0.38),
        Colors.white.withOpacity(isDark ? 0.12 : 0.22),
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 + (0.2 * expansion);
    canvas.drawRRect(rrect, rimPaint);

    // 3. Solar Amber-Gold Top Caustic Crest (Always active, gleaming on upper curve)
    final topHighlightPath = Path();
    final arcWidth = size.width * 0.62;
    final arcLeft = (size.width - arcWidth) / 2;
    topHighlightPath.moveTo(arcLeft, 1.2);
    topHighlightPath.quadraticBezierTo(
      size.width / 2,
      -0.6,
      arcLeft + arcWidth,
      1.2,
    );

    final topHighlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFFD580).withOpacity(0.0),
          const Color(0xFFFFF0D0).withOpacity(0.85 + (0.12 * expansion)),
          const Color(0xFFFFD580).withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(arcLeft, 0, arcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + (0.3 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // 4. Sky-Cyan Bottom Ground Bounce Reflection (Always active on lower curve)
    final bottomBouncePath = Path();
    final bArcWidth = size.width * 0.46;
    final bArcLeft = (size.width - bArcWidth) / 2;
    bottomBouncePath.moveTo(bArcLeft, size.height - 1.2);
    bottomBouncePath.quadraticBezierTo(
      size.width / 2,
      size.height + 0.6,
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
