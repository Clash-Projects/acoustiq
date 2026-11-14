import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave & BitChord Liquid Sliding Glass Dock (Phase 1: Motion Physics Engine)
///
/// Features:
/// 1. Continuous Floating Puck Coordinates:
///    - Pill position is a continuous double `_currentPosition` (0.00 to 3.00).
///    - Follows finger 1:1 in real-time across the dock with fluid responsiveness.
/// 2. Dynamic Z-Axis Lift (Inflation on Press):
///    - Pill physically inflates on touch down / drag: expands height by +3dp, width by +3dp,
///      deepens drop shadow to 16px blur with +2dp elevation.
///    - Deflates back smoothly into the dock bed on release.
/// 3. Velocity Inertia & Squash/Stretch:
///    - Dynamic deformation scales horizontally based on finger velocity.
/// 4. Magnetic Spring Release:
///    - Snaps to destination tab with under-damped spring curve (Curves.easeOutCubic)
///      and haptic confirmation.
/// 5. Compact 316dp Floating Island with 94dp Active / 72dp Inactive symmetry.
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

class _LiquidLensNavBarState extends State<LiquidLensNavBar>
    with TickerProviderStateMixin {
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

  late AnimationController _positionController;
  late AnimationController _liftController;

  double _currentPosition = 0.0;
  double _dragStartX = 0.0;
  double _dragStartPosition = 0.0;
  double _dragVelocity = 0.0;
  bool _isDragging = false;

  int _lastHapticIndex = -1;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentIndex.toDouble();
    _lastHapticIndex = widget.currentIndex;

    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant LiquidLensNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      _animateToTab(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _liftController.dispose();
    super.dispose();
  }

  void _animateToTab(int targetIndex) {
    _positionController.stop();
    final double targetPos = targetIndex.toDouble();
    final Animation<double> curve = CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeOutCubic,
    );

    _positionController.reset();
    final double startPos = _currentPosition;
    _positionController.duration = const Duration(milliseconds: 320);

    void listener() {
      if (!_isDragging) {
        setState(() {
          _currentPosition = startPos + (targetPos - startPos) * curve.value;
        });
      }
    }

    curve.addListener(listener);
    _positionController.forward().whenComplete(() {
      curve.removeListener(listener);
      setState(() {
        _currentPosition = targetPos;
      });
    });
  }

  void _handleTapDown(TapDownDetails details) {
    _liftController.forward();
    _dragVelocity = 0.0;
  }

  void _handleTapUp(TapUpDetails details) {
    _liftController.reverse();
    final double innerX = details.localPosition.dx - _kPaddingH;
    final int target = _positionToSlot(innerX);
    _selectTab(target);
  }

  void _handleTapCancel() {
    _liftController.reverse();
  }

  void _handleDragStart(DragStartDetails details) {
    _positionController.stop();
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _currentPosition;
    _dragVelocity = 0.0;
    _liftController.forward();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final double dx = details.localPosition.dx - _dragStartX;
    final double deltaPos = dx / _kInactiveSlotWidth;
    final double rawTarget = _dragStartPosition + deltaPos;

    final double clamped = rawTarget.clamp(-0.15, 3.15);
    final double vel = details.primaryDelta ?? 0.0;
    _dragVelocity = (_dragVelocity * 0.6) + (vel * 0.4);

    final int crossedIndex = clamped.round().clamp(0, _kTabCount - 1);
    if (crossedIndex != _lastHapticIndex) {
      _lastHapticIndex = crossedIndex;
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    setState(() {
      _currentPosition = clamped;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    _liftController.reverse();

    final int destination = _currentPosition.round().clamp(0, _kTabCount - 1);
    _animateToTab(destination);

    if (destination != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(destination);
    }
  }

  int _positionToSlot(double innerX) {
    if (innerX < 0) return 0;
    double accumulated = 0.0;
    for (int i = 0; i < _kTabCount; i++) {
      final double width = (i == widget.currentIndex) ? _kActiveSlotWidth : _kInactiveSlotWidth;
      if (innerX >= accumulated && innerX < accumulated + width) {
        return i;
      }
      accumulated += width;
    }
    return _kTabCount - 1;
  }

  void _selectTab(int targetIndex) {
    final int clamped = targetIndex.clamp(0, _kTabCount - 1);
    if (clamped != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(clamped);
      _animateToTab(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final useGlass = appState.isLiquidGlass;

        final double lift = _liftController.value;
        final double pillLeft = _kPaddingH + (_currentPosition * _kInactiveSlotWidth);

        // Dynamic inflation & Z-axis expansion
        final double dynamicPillHeight = _kPillHeight + (lift * 3.0);
        final double dynamicPillTop = _kPaddingV - (lift * 1.5);
        final double dynamicPillWidth = _kActiveSlotWidth + (lift * 3.0) + (_dragVelocity.abs() * 0.3).clamp(0.0, 6.0);

        return Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  // 14dp Gaussian optical blur
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
                        // Physical Glass Volume Gradient
                        gradient: useGlass
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        Colors.white.withOpacity(0.14),
                                        Colors.white.withOpacity(0.04),
                                        Colors.white.withOpacity(0.02),
                                        Colors.white.withOpacity(0.06),
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
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Physical Sliding Glass Lens (Continuous Puck with Z-Axis Lift)
                          Positioned(
                            left: pillLeft - ((dynamicPillWidth - _kActiveSlotWidth) / 2),
                            top: dynamicPillTop,
                            width: dynamicPillWidth,
                            height: dynamicPillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                // Convex Focal-Light Radial Gradient
                                gradient: RadialGradient(
                                  center: const Alignment(-0.25, -0.45),
                                  radius: 0.95,
                                  colors: isDark
                                      ? [
                                          Colors.white.withOpacity(0.12 + (lift * 0.05)),
                                          Colors.white.withOpacity(0.03),
                                          Colors.transparent,
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.40 + (lift * 0.10)),
                                          Colors.white.withOpacity(0.12),
                                          Colors.transparent,
                                        ],
                                  stops: const [0.0, 0.50, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(dynamicPillHeight / 2),
                                boxShadow: [
                                  // Dynamic shadow deepening during lift
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? (0.35 + lift * 0.15) : 0.12),
                                    blurRadius: 10 + (lift * 6.0),
                                    offset: Offset(0, 3 + (lift * 2.0)),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(isDark ? (0.08 + lift * 0.06) : 0.0),
                                    blurRadius: 2 + (lift * 2.0),
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _LiquidBubbleHighlightPainter(
                                  isDark: isDark,
                                  lift: lift,
                                ),
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
  final double lift;

  _LiquidBubbleHighlightPainter({required this.isDark, this.lift = 0.0});

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

    // 2. Upper-left specular light catch rim (Direct LastWave formula with dynamic lift boost)
    final upperRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 + (lift * 0.3)
      ..shader = LinearGradient(
        begin: const Alignment(-0.5, -0.6),
        end: const Alignment(0.60, 1.0),
        colors: [
          Colors.white.withOpacity(isDark ? (0.92 + lift * 0.06).clamp(0.0, 1.0) : 0.98),
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
      oldDelegate.isDark != isDark || oldDelegate.lift != lift;
}
