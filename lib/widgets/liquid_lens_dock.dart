import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic LastWave & BitChord Liquid Sliding Glass Dock
/// Phase 2: Fluid Jelly Physics, Acceleration Squash & Stretch,
///          Release Jitter Fix & 7-Ray Chromatic Dispersion Meniscus.
///
/// Integrated Architecture:
/// 1. Dual Under-damped Springs (X & Y lift):
///    - Damping ratios 0.60 across and 0.70 down: on tap/drag down,
///      the pill physically overshoots its raised size and rebounds (jelly pop!).
/// 2. PillSquashModel (from liquid_glass_easy 4.3.4 & BitChord GlassSelectionPill):
///    - Instantaneous acceleration is sampled over a 300ms window.
///    - Conservation of volume: Width scales by (1 + dev), Height by (1 - dev).
/// 3. Harmonic Jelly Wobble while Held:
///    - Micro-oscillation (14 rad/s) gives the pill an organic liquid mercury
///      fluid jiggle while held and dragged.
/// 4. Release Jitter Fix:
///    - Guarded target indexing and single-source Tween eliminate race conditions
///      and mid-flight animation collisions when triggering tab callbacks.
/// 5. 7-Ray Chromatic Dispersion Meniscus:
///    - BitChord spectral wavelengths (Red -> Orange -> Yellow -> Green -> Cyan -> Blue -> Purple)
///      bloom on the outer meniscus during travel and lift.
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
  // Active slot gets 94dp (fits 10-letter words like "Duplicates" without clipping)
  // 3 Inactive slots share remaining 216dp equally = 72dp each
  static const double _kActiveSlotWidth = 94.0;
  static const double _kInactiveSlotWidth = 72.0;
  static const double _kPillHeight = _kDockHeight - (2 * _kPaddingV); // 46.0

  // Continuous floating position coordinates
  double _currentPosition = 0.0;
  double _dragTarget = 0.0;
  double _dragStartX = 0.0;
  double _dragStartPosition = 0.0;
  double _velocity = 0.0;
  bool _isDragging = false;

  // Target index guard to eliminate release jitter
  int _targetIndex = 0;
  int _lastHapticIndex = -1;

  // Under-damped Dual Springs for Lift (ported from liquid_glass_easy)
  // Damping ratio 0.6 across, 0.7 down -> overshoots raised size and bounces back!
  double _liftX = 0.0;
  double _liftXVel = 0.0;
  double _liftY = 0.0;
  double _liftYVel = 0.0;
  double _liftTarget = 0.0;

  // Harmonic Jelly Wobble while held
  double _wobbleTime = 0.0;
  double _wobble = 0.0;

  // Acceleration squash model
  final _PillSquashModel _squashModel = _PillSquashModel();

  // Animation controller for snap transitions
  late final AnimationController _positionController;
  Animation<double>? _positionAnim;

  // Dedicated high-frequency ticker for fluid physics
  Ticker? _ticker;
  double _lastTickSeconds = -1.0;

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
    _dragTarget = _currentPosition;
    _targetIndex = widget.currentIndex;
    _lastHapticIndex = widget.currentIndex;

    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (!_isDragging && _positionAnim != null) {
          setState(() {
            _currentPosition = _positionAnim!.value;
          });
        }
      });

    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant LiquidLensNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Guard against collision: if parent echoes the destination tab we already targeted,
    // do NOT re-trigger _animateToTab! This permanently fixes the release jitter!
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      if (_targetIndex != widget.currentIndex) {
        _targetIndex = widget.currentIndex;
        _animateToTab(widget.currentIndex);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _positionController.dispose();
    super.dispose();
  }

  void _ensureTicker() {
    if (_ticker != null && !_ticker!.isActive) {
      _lastTickSeconds = -1.0;
      _ticker!.start();
    }
  }

  /// One frame of fluid physics (runs at native 90Hz / 120Hz display refresh rate)
  void _onTick(Duration elapsed) {
    final double now = elapsed.inMicroseconds / 1e6;
    if (_lastTickSeconds < 0) {
      _lastTickSeconds = now;
      return;
    }
    final double dt = (now - _lastTickSeconds).clamp(0.001, 0.033);
    _lastTickSeconds = now;

    final double prevPos = _currentPosition;

    // 1. Step Under-damped Dual Springs for Lift (Semi-implicit Euler)
    _stepLiftSprings(dt);

    // 2. Under finger: Chase target with exponential liquid lag (FOLLOW_TAU = 0.045s)
    if (_isDragging) {
      const double tau = 0.045;
      _currentPosition += (_dragTarget - _currentPosition) * (1.0 - math.exp(-dt / tau));
      _velocity = (_currentPosition - prevPos) / dt;

      // Sample acceleration squash
      _squashModel.track(_currentPosition * _kInactiveSlotWidth, now, dt);

      // Continuous harmonic jelly wobble while held
      _wobbleTime += dt;
      _wobble = math.sin(_wobbleTime * 14.0) * 0.024 * _liftY.clamp(0.0, 1.0);
    } else {
      // Free travel or settling
      if (_positionController.isAnimating) {
        _velocity = (_currentPosition - prevPos) / dt;
        _squashModel.track(_currentPosition * _kInactiveSlotWidth, now, dt);
      } else {
        _velocity *= math.exp(-dt / 0.06);
        _squashModel.easeOut(dt);
        _wobble *= math.exp(-dt / 0.06);
      }
    }

    // Check if physics engine can sleep
    final bool liftSettled = (_liftX - _liftTarget).abs() < 0.001 &&
        (_liftY - _liftTarget).abs() < 0.001 &&
        _liftXVel.abs() < 0.005 &&
        _liftYVel.abs() < 0.005;

    final bool squashSettled = _squashModel.value.abs() < 0.001 && _wobble.abs() < 0.001;
    final bool isSettled = !_isDragging &&
        !_positionController.isAnimating &&
        liftSettled &&
        squashSettled;

    if (isSettled) {
      _liftX = _liftTarget;
      _liftY = _liftTarget;
      _liftXVel = 0.0;
      _liftYVel = 0.0;
      _velocity = 0.0;
      _wobble = 0.0;
      _squashModel.stop();
      _ticker?.stop();
    }

    setState(() {});
  }

  /// Semi-implicit Euler integration for independent X & Y under-damped lift springs
  void _stepLiftSprings(double dt) {
    double t = dt;
    while (t > 0) {
      final double step = t > (1.0 / 240.0) ? (1.0 / 240.0) : t;

      // X-axis: stiffness 250, damping 19.0 (damping ratio 0.60 -> bouncy overshoot)
      final double accelX = -250.0 * (_liftX - _liftTarget) - 19.0 * _liftXVel;
      _liftXVel += accelX * step;
      _liftX += _liftXVel * step;

      // Y-axis: stiffness 250, damping 22.1 (damping ratio 0.70 -> slightly tighter bounce)
      final double accelY = -250.0 * (_liftY - _liftTarget) - 22.1 * _liftYVel;
      _liftYVel += accelY * step;
      _liftY += _liftYVel * step;

      t -= step;
    }
  }

  void _animateToTab(int targetIndex) {
    _positionController.stop();
    _targetIndex = targetIndex;
    final double targetPos = targetIndex.toDouble();

    if ((_currentPosition - targetPos).abs() < 0.001) {
      setState(() {
        _currentPosition = targetPos;
      });
      return;
    }

    _positionAnim = Tween<double>(
      begin: _currentPosition,
      end: targetPos,
    ).animate(CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeOutCubic,
    ));

    _squashModel.start();
    _ensureTicker();
    _positionController.forward(from: 0.0).whenComplete(() {
      setState(() {
        _currentPosition = targetPos;
      });
    });
  }

  void _handleTapDown(TapDownDetails details) {
    _liftTarget = 1.0;
    _ensureTicker();
  }

  void _handleTapUp(TapUpDetails details) {
    _liftTarget = 0.0;
    _ensureTicker();
    final double innerX = details.localPosition.dx - _kPaddingH;
    final int target = _positionToSlot(innerX);
    _selectTab(target);
  }

  void _handleTapCancel() {
    _liftTarget = 0.0;
    _ensureTicker();
  }

  void _handleDragStart(DragStartDetails details) {
    _positionController.stop();
    _isDragging = true;
    _liftTarget = 1.0;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _currentPosition;
    _dragTarget = _currentPosition;
    _squashModel.start();
    _ensureTicker();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final double dx = details.localPosition.dx - _dragStartX;
    final double deltaPos = dx / _kInactiveSlotWidth;
    final double rawTarget = _dragStartPosition + deltaPos;

    // Smooth over-scroll resistance at edges
    _dragTarget = rawTarget.clamp(-0.15, 3.15);

    final int crossedIndex = _dragTarget.round().clamp(0, _kTabCount - 1);
    if (crossedIndex != _lastHapticIndex) {
      _lastHapticIndex = crossedIndex;
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }
    _ensureTicker();
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    _liftTarget = 0.0;

    final int destination = _currentPosition.round().clamp(0, _kTabCount - 1);
    _targetIndex = destination;
    _animateToTab(destination);

    if (destination != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(destination);
    }
    _ensureTicker();
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
    _targetIndex = clamped;
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

        // Dynamic conservation of volume deformation (liquid_glass_easy formula)
        // Width scales by 1 + dev, Height scales by 1 - dev
        final double totalDeviation = (_squashModel.value + _wobble).clamp(-0.14, 0.14);
        final double liftedW = _kActiveSlotWidth + (_liftX * 4.0);
        final double liftedH = _kPillHeight + (_liftY * 3.0);

        final double dynamicPillWidth = liftedW * (1.0 + totalDeviation);
        final double dynamicPillHeight = liftedH * (1.0 - totalDeviation);

        // Center calculation: the distance between slot centers is identically 72.0dp!
        final double centerX = _kPaddingH + (_kActiveSlotWidth / 2.0) + (_currentPosition * _kInactiveSlotWidth);
        final double pillLeft = centerX - (dynamicPillWidth / 2.0);
        final double pillTop = (_kDockHeight / 2.0) - (dynamicPillHeight / 2.0);

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
                    // WWDC25 Specular Light Catch Rim along top edge
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
                          // 1. Physical Sliding Glass Lens with Jelly Physics & Optics
                          Positioned(
                            left: pillLeft,
                            top: pillTop,
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
                                          Colors.white.withOpacity(0.12 + (_liftY * 0.05)),
                                          Colors.white.withOpacity(0.03),
                                          Colors.transparent,
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.40 + (_liftY * 0.10)),
                                          Colors.white.withOpacity(0.12),
                                          Colors.transparent,
                                        ],
                                  stops: const [0.0, 0.50, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(dynamicPillHeight / 2),
                                boxShadow: [
                                  // Dynamic shadow deepening during under-damped lift
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? (0.35 + _liftY * 0.15) : 0.12),
                                    blurRadius: 10 + (_liftY * 6.0),
                                    offset: Offset(0, 3 + (_liftY * 2.0)),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(isDark ? (0.08 + _liftY * 0.06) : 0.0),
                                    blurRadius: 2 + (_liftY * 2.0),
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // LastWave 3-Tier Layered Curvature & Specular Highlight
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _LiquidBubbleHighlightPainter(
                                        isDark: isDark,
                                        lift: _liftY,
                                      ),
                                    ),
                                  ),
                                  // BitChord 7-Ray Chromatic Dispersion Meniscus Flare
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _LiquidChromaticDispersionPainter(
                                        isDark: isDark,
                                        lift: _liftY,
                                        velocity: _velocity,
                                      ),
                                    ),
                                  ),
                                ],
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

/// PillSquashModel: Differentiates position twice over a 300ms window to extract
/// acceleration and map it to volume-conserving squash & stretch.
/// Ported from liquid_glass_easy (pub.dev/packages/liquid_glass_easy, Ahmed Gamil)
class _PillSquashModel {
  static const double _kSampleWindow = 0.30; // 300ms window
  static const double _kSensitivity = 0.00007; // Acceleration to deformation scaler
  static const double _kMaxDeformation = 0.12; // ±12% deformation ceiling
  static const double _kResponseTime = 0.18;

  final List<({double x, double time})> _history = [];
  bool isTracking = false;
  double value = 0.0;

  void start() {
    _history.clear();
    value = 0.0;
    isTracking = true;
  }

  void stop() {
    isTracking = false;
    _history.clear();
    value = 0.0;
  }

  void easeOut(double dt) {
    value += (0.0 - value) * (dt / _kResponseTime).clamp(0.0, 1.0);
  }

  double track(double x, double now, double dt) {
    if (!isTracking) return value;
    _history.add((x: x, time: now));
    final cutoff = now - _kSampleWindow;
    _history.removeWhere((item) => item.time < cutoff);

    final double raw = (_averageAcceleration() * _kSensitivity).clamp(-_kMaxDeformation, _kMaxDeformation);
    final double ease = (dt / _kResponseTime).clamp(0.0, 1.0);
    value += (raw - value) * ease;
    return value;
  }

  double _averageAcceleration() {
    if (_history.length < 3) return 0.0;
    final velocities = <({double v, double time})>[];
    for (int i = 1; i < _history.length; i++) {
      final double dt = _history[i].time - _history[i - 1].time;
      if (dt <= 0) continue;
      velocities.add((
        v: (_history[i].x - _history[i - 1].x) / dt,
        time: (_history[i].time + _history[i - 1].time) / 2.0,
      ));
    }
    if (velocities.length < 2) return 0.0;
    double total = 0.0;
    int count = 0;
    for (int i = 1; i < velocities.length; i++) {
      final double dt = velocities[i].time - velocities[i - 1].time;
      if (dt <= 0) continue;
      total += (velocities[i].v - velocities[i - 1].v) / dt;
      count++;
    }
    return count == 0 ? 0.0 : total / count;
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

    // 2. Upper-left specular light catch rim
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

    // 3. Lower-right ambient reflection rim
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

/// BitChord 7-Wavelength Chromatic Dispersion Meniscus Flare
/// Samples the outer meniscus contour with a rainbow flare (Red -> Orange -> Yellow -> Green -> Cyan -> Blue -> Purple).
/// Dynamically blooms in stroke width and intensity based on velocity and under-damped lift!
class _LiquidChromaticDispersionPainter extends CustomPainter {
  final bool isDark;
  final double lift;
  final double velocity;

  _LiquidChromaticDispersionPainter({
    required this.isDark,
    required this.lift,
    required this.velocity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)).deflate(0.5);

    // Intensity blooms with velocity & lift
    final double velMagnitude = velocity.abs();
    final double intensity = (0.22 + (lift * 0.32) + (velMagnitude * 0.08)).clamp(0.18, 0.85);

    // Orient rainbow flare with direction of travel:
    // Leading edge catches warm spectrum (Red/Orange/Yellow)
    // Trailing edge catches cool spectrum (Cyan/Blue/Purple)
    final bool movingLeft = velocity < -0.05;
    final Alignment startAlign = movingLeft ? Alignment.centerRight : Alignment.centerLeft;
    final Alignment endAlign = movingLeft ? Alignment.centerLeft : Alignment.centerRight;

    final List<Color> spectralColors = [
      const Color(0x66AF52DE), // 7. Purple
      const Color(0x66007AFF), // 6. Blue
      const Color(0x5500C7BE), // 5. Cyan
      const Color(0x4434C759), // 4. Green
      const Color(0x55FFCC00), // 3. Yellow
      const Color(0x55FF9500), // 2. Orange
      const Color(0x66FF3B30), // 1. Red
    ];

    final chromaticShader = LinearGradient(
      begin: startAlign,
      end: endAlign,
      colors: spectralColors.map((c) => c.withOpacity((c.opacity * intensity).clamp(0.0, 1.0))).toList(),
      stops: const [0.0, 0.16, 0.33, 0.50, 0.66, 0.83, 1.0],
    ).createShader(rect);

    final chromaticPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + (lift * 0.6) + (velMagnitude * 0.1).clamp(0.0, 0.8)
      ..shader = chromaticShader;

    canvas.drawRRect(rrect, chromaticPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidChromaticDispersionPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.lift != lift ||
      oldDelegate.velocity != velocity;
}
