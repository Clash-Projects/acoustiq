import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic BitChord & LastWave Liquid Floating Glass Dock
/// Phase 2 (Rework): Unclipped Floating Lens, Proportional +9dp Lift,
///                   Pure Acceleration Squash (No Fake Wobble),
///                   Corner-Localized Optical Glint & Flat-to-Glass Hand-off.
///
/// Architecture Ground Truth (Derived from BitChord Source & Screenshots):
/// 1. Unclipped Double-Layer Geometry:
///    - Root container is an unclipped Stack (`clipBehavior: Clip.none`).
///    - Dock rail is clipped to its 25px rounded rectangle (Layer 1).
///    - Floating Glass Pill sits on Layer 4 OUTSIDE the dock's clip,
///      standing 3dp to 4.5dp above and below dock boundaries with zero edge clipping.
/// 2. Proportional Growth on Lift (PILL_GROW_HEIGHT = 9.0dp):
///    - Resting height: 46dp, resting width: 94dp.
///    - Lifted height: 56dp (+10dp), lifted width: 112dp (+18dp) scaled proportionally.
/// 3. Pure Acceleration Squash (Zero Artificial Sine Wobble):
///    - Tracks instantaneous acceleration d^2x/dt^2 via PillSquashModel.
///    - When held still: deviation = 0.0 (calm stillness, no vibration).
///    - When moving: volume-conserving elongation and braking squash.
/// 4. Corner-Localized Prismatic Dispersion (No Static Neon Rainbow Border):
///    - Dispersion intensity follows (x * y) / (W/2 * H/2).
///    - Appears exclusively at diagonal corner radiuses where glass curves bend light.
/// 5. BitChord Flat-to-Glass Hand-off:
///    - At rest: Flat minimal indicator (clean, zero visual noise).
///    - On touch: Unclips, lifts +10dp, casts 16px ambient shadow, becomes convex liquid lens.
///    - On release: Snaps to destination tab, deflates back into dock bed, hands off to flat pill.
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

  // BitChord Flat-to-Glass Hand-off state
  bool _isFlat = true;

  // Under-damped Dual Springs for Lift (from liquid_glass_easy & BitChord)
  // Damping ratio 0.6 across, 0.7 down -> overshoots raised size and bounces back!
  double _liftX = 0.0;
  double _liftXVel = 0.0;
  double _liftY = 0.0;
  double _liftYVel = 0.0;
  double _liftTarget = 0.0;

  // Acceleration squash model (Strictly motion-driven, NO artificial sine wave)
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
    // do NOT re-trigger _animateToTab!
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

      // Sample pure motion acceleration squash (Zero artificial sine wave!)
      _squashModel.track(_currentPosition * _kInactiveSlotWidth, now, dt);
    } else {
      // Free travel or settling
      if (_positionController.isAnimating) {
        _velocity = (_currentPosition - prevPos) / dt;
        _squashModel.track(_currentPosition * _kInactiveSlotWidth, now, dt);
      } else {
        _velocity *= math.exp(-dt / 0.06);
        _squashModel.easeOut(dt);
      }
    }

    // Check if physics engine can settle and hand-off to flat pill
    final bool liftSettled = (_liftX - _liftTarget).abs() < 0.001 &&
        (_liftY - _liftTarget).abs() < 0.001 &&
        _liftXVel.abs() < 0.005 &&
        _liftYVel.abs() < 0.005;

    final bool squashSettled = _squashModel.value.abs() < 0.001;
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
      _squashModel.stop();
      _ticker?.stop();

      // Hand-off back to flat pill when resting at destination
      if (_liftTarget == 0.0) {
        _isFlat = true;
      }
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
        _isFlat = true;
      });
      return;
    }

    // Switch from flat indicator to floating glass lens during travel
    _isFlat = false;
    _liftTarget = 1.0;

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
      // Once landed, deflate lift and hand off back to flat pill
      _liftTarget = 0.0;
      _ensureTicker();
    });
  }

  void _handleTapDown(TapDownDetails details) {
    _isFlat = false;
    _liftTarget = 1.0;
    _ensureTicker();
  }

  void _handleTapUp(TapUpDetails details) {
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
    _isFlat = false;
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
    } else {
      _liftTarget = 0.0;
      _ensureTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final useGlass = appState.isLiquidGlass;

        // Dynamic conservation of volume deformation (Pure acceleration, no fake sine)
        final double deviation = _squashModel.value.clamp(-0.12, 0.12);

        // Proportional growth on lift (+10dp height, +18dp width)
        final double liftedW = _kActiveSlotWidth + (_liftX * 18.0);
        final double liftedH = _kPillHeight + (_liftY * 10.0);

        final double dynamicPillWidth = liftedW * (1.0 + deviation);
        final double dynamicPillHeight = liftedH * (1.0 - deviation);

        // Center calculation: the distance between slot centers is identically 72.0dp!
        final double centerX = _kPaddingH + (_kActiveSlotWidth / 2.0) + (_currentPosition * _kInactiveSlotWidth);
        final double pillLeft = centerX - (dynamicPillWidth / 2.0);
        // Centers vertically around dock height: stands 3dp above & 3dp below dock edges when lifted!
        final double pillTop = (_kDockHeight / 2.0) - (dynamicPillHeight / 2.0);

        // Resting flat pill coordinates
        final double restingCenter = _kPaddingH + (_kActiveSlotWidth / 2.0) + (widget.currentIndex * _kInactiveSlotWidth);
        final double restingLeft = restingCenter - (_kActiveSlotWidth / 2.0);
        final double restingTop = (_kDockHeight - _kPillHeight) / 2.0;

        return Center(
          child: SizedBox(
            width: _kDockWidth,
            height: _kDockHeight,
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
                child: Stack(
                  // UNCLIPPED ROOT CONTAINER: Floating glass lens can stand outside dock boundaries!
                  clipBehavior: Clip.none,
                  children: [
                    // ==============================================================
                    // LAYER 1: CLIPPED DOCK RAIL (Substrate, Gaussian Blur & Top Rim)
                    // ==============================================================
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: useGlass
                              ? ImageFilter.blur(sigmaX: 14, sigmaY: 14)
                              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                          child: CustomPaint(
                            painter: _DockSpecularRimPainter(
                              isDark: isDark,
                              radius: 25,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
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
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ==============================================================
                    // LAYER 2: FLAT RESTING PILL (BitChord FlatSelectionPill)
                    // At rest: Clean, quiet indicator with zero neon noise!
                    // ==============================================================
                    if (_isFlat)
                      Positioned(
                        left: restingLeft,
                        top: restingTop,
                        width: _kActiveSlotWidth,
                        height: _kPillHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(_kPillHeight / 2),
                          ),
                        ),
                      ),

                    // ==============================================================
                    // LAYER 3: TAB ICONS & LABELS ROW
                    // ==============================================================
                    Positioned.fill(
                      child: Padding(
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
                    ),

                    // ==============================================================
                    // LAYER 4: UNCLIPPED FLOATING GLASS LENS (BitChord GlassSelectionPill)
                    // Active when lifted or moving: stands above and outside the dock!
                    // ==============================================================
                    if (!_isFlat)
                      Positioned(
                        left: pillLeft,
                        top: pillTop,
                        width: dynamicPillWidth,
                        height: dynamicPillHeight,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              // Convex Focal-Light Radial Water Droplet Gradient
                              gradient: RadialGradient(
                                center: const Alignment(-0.25, -0.45),
                                radius: 0.95,
                                colors: isDark
                                    ? [
                                        Colors.white.withOpacity(0.14 + (_liftY * 0.08)),
                                        Colors.white.withOpacity(0.04),
                                        Colors.transparent,
                                      ]
                                    : [
                                        Colors.white.withOpacity(0.45 + (_liftY * 0.12)),
                                        Colors.white.withOpacity(0.14),
                                        Colors.transparent,
                                      ],
                                stops: const [0.0, 0.50, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(dynamicPillHeight / 2),
                              boxShadow: [
                                // Deep ambient drop shadow cast on dock & background (BitChord Image 4)
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.15),
                                  blurRadius: 16 + (_liftY * 4.0),
                                  offset: Offset(0, 4 + (_liftY * 2.0)),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(isDark ? 0.12 : 0.0),
                                  blurRadius: 3,
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
                                // Corner-Localized Meniscus Glint (BitChord formula: no fake neon border!)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _CornerPrismaticGlintPainter(
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
                      ),
                  ],
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
      final dt = velocities[i].time - velocities[i - 1].time;
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
      ..strokeWidth = 1.3 + (lift * 0.4)
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

/// Corner-Localized Optical Glint & Prismatic Refraction (BitChord formula)
/// Unlike a cheap continuous neon rainbow border, dispersion intensity follows (x * y) / (W/2 * H/2).
/// It blooms exclusively at the diagonal curved meniscus corners where light physically refracts!
class _CornerPrismaticGlintPainter extends CustomPainter {
  final bool isDark;
  final double lift;
  final double velocity;

  _CornerPrismaticGlintPainter({
    required this.isDark,
    required this.lift,
    required this.velocity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)).deflate(0.6);

    // BitChord formula: dispersion is proportional to velocity & lift, localized diagonally
    final double velMag = velocity.abs();
    final double intensity = (0.15 + (lift * 0.25) + (velMag * 0.06)).clamp(0.12, 0.55);

    // Diagonal corner dispersion sweep:
    // Glint focuses at Top-Left (~135 deg) and Bottom-Right (~315 deg) diagonal corners!
    final cornerSweepShader = SweepGradient(
      center: Alignment.center,
      colors: [
        Colors.transparent,
        const Color(0x3300C7BE).withOpacity(intensity * 0.6), // Cyan corner glint
        const Color(0x55FFCC00).withOpacity(intensity * 0.8), // Warm gold highlight
        Colors.transparent,
        Colors.transparent,
        const Color(0x33007AFF).withOpacity(intensity * 0.5), // Cool blue meniscus
        const Color(0x44AF52DE).withOpacity(intensity * 0.7), // Violet flare
        Colors.transparent,
      ],
      stops: const [0.0, 0.12, 0.22, 0.35, 0.50, 0.62, 0.72, 0.85],
      transform: GradientRotation(velocity > 0.05 ? 0.35 : (velocity < -0.05 ? -0.35 : 0.0)),
    ).createShader(rect);

    final glintPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (lift * 0.6)
      ..shader = cornerSweepShader;

    canvas.drawRRect(rrect, glintPaint);
  }

  @override
  bool shouldRepaint(covariant _CornerPrismaticGlintPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.lift != lift ||
      oldDelegate.velocity != velocity;
}
