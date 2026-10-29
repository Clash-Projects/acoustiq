import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_settings.dart';

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

            // Boundary Squeeze / Elastic Stretch calculation
            final minX = 0.0;
            final maxX = (_tabs.length - 1) * tabWidth;

            double squeezeX = 1.0;
            double bulgeY = 1.0;

            if (_isDragging) {
              if (_currentX < minX) {
                // Left wall collision squeeze: compresses horizontally against wall
                final overshoot = (minX - _currentX).clamp(0.0, 30.0);
                squeezeX = 1.0 - (overshoot / 30.0) * 0.25;
                bulgeY = 1.0 + (overshoot / 30.0) * 0.12;
              } else if (_currentX > maxX) {
                // Right wall collision squeeze: compresses horizontally against wall
                final overshoot = (_currentX - maxX).clamp(0.0, 30.0);
                squeezeX = 1.0 - (overshoot / 30.0) * 0.25;
                bulgeY = 1.0 + (overshoot / 30.0) * 0.12;
              } else if (_dragVelocityX.abs() > 0.8) {
                // Gentle fluid velocity stretch along drag direction (strictly clamped)
                final vFactor = (_dragVelocityX.abs() / 16.0).clamp(0.0, 0.12);
                squeezeX = 1.0 + vFactor;
                bulgeY = 1.0 - (vFactor * 0.15);
              }
            }

            // Dimensions: Clean icon-centered capsule, strictly bounded inside the bar
            // Resting: 56px wide x 38px high (9px margin inside 56px bar)
            // Hold: 64px wide x 44px high (6px margin inside 56px bar - NEVER overflows!)
            final expansion = _expansionAnimation.value;
            final baseWidth = (56.0 + (8.0 * expansion)) * squeezeX;
            final baseHeight = (38.0 + (6.0 * expansion)) * bulgeY;

            final lensWidth = baseWidth.clamp(40.0, tabWidth - 6.0);
            final lensHeight = baseHeight.clamp(32.0, 46.0);

            // Center droplet on current tab position
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
                  final localX = (event.localPosition.dx - (tabWidth / 2)).clamp(-24.0, maxX + 24.0);
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
                    // 1. Frosted Translucent Track Capsule
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF101624).withOpacity(0.78)
                                : Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(28),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(isDark ? 0.35 : 0.60),
                                width: 1.2,
                              ),
                              left: BorderSide(color: Colors.white.withOpacity(isDark ? 0.14 : 0.25), width: 1.0),
                              right: BorderSide(color: Colors.white.withOpacity(isDark ? 0.14 : 0.25), width: 1.0),
                              bottom: BorderSide(color: Colors.white.withOpacity(isDark ? 0.08 : 0.15), width: 1.0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.55 : 0.14),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. THE 100% WATER-CLEAR 3D LIQUID LENS (No Cyan Tint!)
                    Positioned(
                      left: lensLeft,
                      top: lensTop,
                      width: lensWidth,
                      height: lensHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(lensHeight / 2),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20 + (8 * expansion), sigmaY: 20 + (8 * expansion)),
                          child: CustomPaint(
                            painter: _WaterClearOpticalLensPainter(
                              isDark: isDark,
                              expansion: expansion,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(lensHeight / 2),
                                boxShadow: [
                                  // Soft natural elevation contact shadow
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.30 + (0.20 * expansion)),
                                    blurRadius: 8 + (8 * expansion),
                                    offset: Offset(0, 2 + (2 * expansion)),
                                  ),
                                  // Subtle pure white specular ambient glow
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.08 + (0.08 * expansion)),
                                    blurRadius: 10 + (6 * expansion),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Tab Items (Icons + Inter Labels)
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
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : (isDark ? Colors.white38 : Colors.black45),
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
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? Colors.white38 : Colors.black45),
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

// ── 100% Water-Clear Optical Lens Painter (Apple "Clear iOS" Style) ──────────
class _WaterClearOpticalLensPainter extends CustomPainter {
  final bool isDark;
  final double expansion;

  _WaterClearOpticalLensPainter({
    required this.isDark,
    required this.expansion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 1. Water-Clear Optical Body (No colored dye/tint - pure crystal water transparency)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.3),
        radius: 1.1,
        colors: [
          Colors.white.withOpacity(isDark ? (0.06 + 0.04 * expansion) : (0.28 + 0.06 * expansion)),
          Colors.white.withOpacity(isDark ? 0.015 : 0.06),
          Colors.white.withOpacity(isDark ? 0.005 : 0.02),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 2. Optical Glass Rim (White specular reflection along curved glass perimeter)
    final rimGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.85 + (0.10 * expansion)),
        Colors.white.withOpacity(isDark ? 0.22 : 0.40),
        Colors.white.withOpacity(isDark ? 0.12 : 0.20),
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + (0.3 * expansion);
    canvas.drawRRect(rrect, rimPaint);

    // 3. Razor-Sharp Top Specular Crest (Overhead keylight reflection on convex lens)
    final topHighlightPath = Path();
    final arcWidth = size.width * 0.62;
    final arcLeft = (size.width - arcWidth) / 2;
    topHighlightPath.moveTo(arcLeft, 1.0);
    topHighlightPath.quadraticBezierTo(
      size.width / 2,
      -0.6,
      arcLeft + arcWidth,
      1.0,
    );

    final topHighlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(arcLeft, 0, arcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 + (0.4 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // 4. Subtle Bottom Ground Bounce Reflection
    final bottomBouncePath = Path();
    final bArcWidth = size.width * 0.46;
    final bArcLeft = (size.width - bArcWidth) / 2;
    bottomBouncePath.moveTo(bArcLeft, size.height - 1.0);
    bottomBouncePath.quadraticBezierTo(
      size.width / 2,
      size.height + 0.6,
      bArcLeft + bArcWidth,
      size.height - 1.0,
    );

    final bottomBouncePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.30 + (0.15 * expansion)),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(bArcLeft, size.height - 3, bArcWidth, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bottomBouncePath, bottomBouncePaint);
  }

  @override
  bool shouldRepaint(covariant _WaterClearOpticalLensPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.expansion != expansion;
  }
}
