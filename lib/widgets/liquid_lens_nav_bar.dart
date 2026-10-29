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
            const barHeight = 58.0;
            final tabWidth = totalWidth / _tabs.length;

            if (!_isDragging && !_springController.isAnimating) {
              _currentX = widget.currentIndex * tabWidth;
            }

            // Boundary Squeeze / Elastic Stretch calculation
            final minX = 0.0;
            final maxX = (_tabs.length - 1) * tabWidth;

            double squeezeX = 1.0;
            double bulgeY = 1.0;

            if (_currentX < minX) {
              // Left wall collision squeeze: compresses horizontally, bulges vertically
              final overshoot = (minX - _currentX).clamp(0.0, 40.0);
              squeezeX = 1.0 - (overshoot / 40.0) * 0.32;
              bulgeY = 1.0 + (overshoot / 40.0) * 0.20;
            } else if (_currentX > maxX) {
              // Right wall collision squeeze: compresses horizontally, bulges vertically
              final overshoot = (_currentX - maxX).clamp(0.0, 40.0);
              squeezeX = 1.0 - (overshoot / 40.0) * 0.32;
              bulgeY = 1.0 + (overshoot / 40.0) * 0.20;
            } else if (_dragVelocityX.abs() > 0.5) {
              // Fluid velocity elongation along direction of drag
              final vFactor = (_dragVelocityX.abs() / 14.0).clamp(0.0, 0.25);
              squeezeX = 1.0 + vFactor;
              bulgeY = 1.0 - (vFactor * 0.35);
            }

            // Dynamic morph: Resting pill (height 42) -> 3D Liquid Lens bubble (height 54) on hold/drag
            final expansion = _expansionAnimation.value;
            final baseHeight = 42.0 + (12.0 * expansion);
            final baseWidth = (tabWidth - (12.0 * (1.0 - expansion))) * squeezeX;
            final lensHeight = baseHeight * bulgeY;
            final lensWidth = baseWidth;
            final lensLeft = _currentX + (tabWidth - lensWidth) / 2;

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
                  final localX = (event.localPosition.dx - (tabWidth / 2)).clamp(-32.0, maxX + 32.0);
                  _currentX = localX;
                });
              },
              onPointerMove: (event) {
                setState(() {
                  _dragVelocityX = event.delta.dx;
                  double newX = _currentX + event.delta.dx;
                  if (newX < minX) {
                    newX = minX - (minX - newX) * 0.38;
                  } else if (newX > maxX) {
                    newX = maxX + (newX - maxX) * 0.38;
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
                height: barHeight + 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 1. Sleek Frosted Translucent Track Capsule
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isDark
                                ? (appState.isAmoled
                                    ? Colors.black.withOpacity(0.55)
                                    : const Color(0xFF101420).withOpacity(0.82))
                                : Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(30),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(isDark ? 0.22 : 0.45),
                                width: 1.2,
                              ),
                              left: BorderSide(color: Colors.white.withOpacity(isDark ? 0.08 : 0.20), width: 1.0),
                              right: BorderSide(color: Colors.white.withOpacity(isDark ? 0.08 : 0.20), width: 1.0),
                              bottom: BorderSide(color: Colors.white.withOpacity(isDark ? 0.05 : 0.10), width: 1.0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.50 : 0.12),
                                blurRadius: 22,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. THE 100% GENUINE 3D OPTICAL LIQUID LENS
                    Positioned(
                      left: lensLeft,
                      width: lensWidth,
                      height: lensHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(lensHeight / 2),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18 + (6 * expansion), sigmaY: 18 + (6 * expansion)),
                          child: CustomPaint(
                            painter: _GenuineOpticalLiquidLensPainter(
                              isDark: isDark,
                              expansion: expansion,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(lensHeight / 2),
                                boxShadow: [
                                  // Prismatic Caustic Ambient Glow
                                  BoxShadow(
                                    color: const Color(0xFF00D2FF).withOpacity(0.12 + (0.16 * expansion)),
                                    blurRadius: 14 + (10 * expansion),
                                    spreadRadius: -2,
                                  ),
                                  // Deep Floating Contact Shadow for authentic 3D optical elevation
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35 + (0.25 * expansion)),
                                    blurRadius: 10 + (12 * expansion),
                                    offset: Offset(0, 2 + (4 * expansion)),
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
                                    size: 21,
                                    color: isSelected
                                        ? const Color(0xFF00D2FF)
                                        : (isDark ? Colors.white54 : Colors.black45),
                                  ),
                                  const SizedBox(height: 2.5),
                                  Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? Colors.white54 : Colors.black45),
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

// ── Genuine 3D Optical Liquid Lens Painter ──────────────────────────────────
class _GenuineOpticalLiquidLensPainter extends CustomPainter {
  final bool isDark;
  final double expansion;

  _GenuineOpticalLiquidLensPainter({
    required this.isDark,
    required this.expansion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 1. Water-Clear Optical Fresnel Fill
    // In real water/glass, center has almost 0 opacity (<0.04) and glances have soft Fresnel sheen
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 1.15,
        colors: [
          Colors.white.withOpacity(isDark ? (0.12 + 0.08 * expansion) : (0.35 + 0.10 * expansion)),
          Colors.white.withOpacity(isDark ? 0.03 : 0.10),
          Colors.white.withOpacity(isDark ? (0.015 + 0.03 * expansion) : 0.05),
        ],
        stops: const [0.0, 0.60, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // 2. Prismatic / Chromatic Dispersion Outer Caustic Rim
    // KowSU Reference: Amber/Gold reflection at top-right, Sky-Cyan reflection at bottom-left
    final chromaticGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0xFFFFA726).withOpacity((0.35 + 0.35 * expansion).clamp(0.0, 1.0)), // Warm amber flare
        Colors.white.withOpacity(0.92), // Hot specular crest
        Color(0xFF00D2FF).withOpacity((0.30 + 0.40 * expansion).clamp(0.0, 1.0)), // Cool sky cyan
        Colors.white.withOpacity(isDark ? 0.12 : 0.25),
      ],
      stops: const [0.0, 0.28, 0.72, 1.0],
    );

    final chromaticPaint = Paint()
      ..shader = chromaticGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 + (0.5 * expansion);
    canvas.drawRRect(rrect, chromaticPaint);

    // 3. Top Specular Convex Highlight Arc (Simulates overhead keylight on curved dome)
    final topHighlightPath = Path();
    final arcWidth = size.width * 0.68;
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
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(arcLeft, 0, arcWidth, 4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 + (0.6 * expansion)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // 4. Bottom Ground Bounce Reflection Arc
    final bottomBouncePath = Path();
    final bArcWidth = size.width * 0.52;
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
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.38 + (0.22 * expansion)),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(bArcLeft, size.height - 4, bArcWidth, 4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bottomBouncePath, bottomBouncePaint);
  }

  @override
  bool shouldRepaint(covariant _GenuineOpticalLiquidLensPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.expansion != expansion;
  }
}
