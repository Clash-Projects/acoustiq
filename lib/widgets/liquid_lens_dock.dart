import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Authentic BitChord & LastWave Liquid Floating Glass Dock
/// Master Synthesis Rework:
/// 1. Flawless Concentric End-Cap Geometry (319dp width x 62dp height):
///    - Semicircular outer caps (31dp radius) share identical arc centers with pill (27.5dp radius + 3.5dp padding).
///    - Left and right caps have an exact, uniform 3.5dp concentric margin (zero gaps, zero asymmetry).
/// 2. BitChord Precision Flight Landing Hand-off (HANDOVER_START = 0.88):
///    - Hand-off no longer waits for the pill to come to a dead stop!
///    - Deflation and glass-to-flat dissolve trigger at 88% of travel (during landing decrescendo).
///    - Pill lands and becomes flat in one continuous, butter-smooth 120 FPS deceleration!
/// 3. Optical Icon Magnification (1.09x Dynamic Scale):
///    - Active icon organically magnifies by up to +9% as the lens passes over it,
///      simulating the physical convex magnification of thick crown glass.
/// 4. Luminous Translucent Water Core:
///    - Replaced murky dark tints with BitChord's 0.16 white optical luminance.
///    - Feather-soft 0.8px specular hairline (0.28 opacity) and 16px soft ambient drop shadow.
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
  // Apple HIG & BitChord standard dimensions:
  // 62dp dock height provides lush vertical presence (eliminates squeezed look).
  // 319dp dock width with 3.5dp padding creates 100% mathematically concentric end-caps.
  static const double _kDockWidth = 319.0;
  static const double _kDockHeight = 62.0;
  static const double _kPaddingH = 3.5;
  static const double _kPaddingV = 3.5;
  static const int _kTabCount = 4;

  // Track allocation: 319 - 7 = 312dp inner track
  // Active slot: 96dp (ample room for text + icon)
  // 3 Inactive slots: 72dp each (96 + 3*72 = 312dp)
  static const double _kActiveSlotWidth = 96.0;
  static const double _kInactiveSlotWidth = 72.0;
  static const double _kPillHeight = _kDockHeight - (2 * _kPaddingV); // 55.0dp

  // Dynamic growth constants on lift (BitChord proportional expansion)
  static const double _kPillLiftGrowth = 11.0; // 55dp -> 66dp
  static const double _kPillWidthGrowth = 19.2; // 96dp -> 115.2dp

  // Continuous floating position coordinates
  double _currentPosition = 0.0;
  double _dragTarget = 0.0;
  double _dragStartX = 0.0;
  double _dragStartPosition = 0.0;
  double _velocity = 0.0;
  bool _isDragging = false;

  // Travel start coordinate for accurate travelProgress calculation
  double _travelFrom = 0.0;

  // Target index guard to eliminate release jitter
  int _targetIndex = 0;
  int _lastHapticIndex = -1;

  // Continuous Material Hand-off springs (BitChord GlassSelectionPill architecture)
  // material: 0.0 (flat indicator) -> 1.0 (glass lens active)
  // handover: 0.0 (fully lifted lens) -> 1.0 (landing hand-off back to flat)
  double _material = 0.0;
  double _handover = 1.0;

  // Under-damped Dual Springs for Lift (from liquid_glass_easy & BitChord)
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
    _travelFrom = _currentPosition;
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

  /// Calculates flight completion progress (0.0 at launch -> 1.0 at destination)
  double _travelProgress() {
    final double span = (_targetIndex.toDouble() - _travelFrom).abs();
    if (span < 1e-4) return 1.0;
    return (1.0 - (_targetIndex.toDouble() - _currentPosition).abs() / span).clamp(0.0, 1.0);
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

    // 1. BitChord Landing Decrescendo Hand-off (HANDOVER_START = 0.88):
    // As the pill enters the final 12% of flight, release lift during braking!
    if (!_isDragging && _liftTarget > 0.0) {
      if (_travelProgress() >= 0.88 || !_positionController.isAnimating) {
        _liftTarget = 0.0;
      }
    }

    // 2. Step Under-damped Dual Springs for Lift (Semi-implicit Euler)
    _stepLiftSprings(dt);

    // 3. Material Hand-off Transition (Continuous 50ms exponential morph)
    final double materialTarget = _liftTarget > 0.0 ? 1.0 : 0.0;
    _material += (materialTarget - _material) * (1.0 - math.exp(-dt / 0.05));
    if ((materialTarget - _material).abs() < 0.004) _material = materialTarget;

    final double handoverTarget = _liftTarget > 0.0 ? 0.0 : 1.0;
    final double handoverTau = handoverTarget > _handover ? 0.08 : 0.04;
    _handover += (handoverTarget - _handover) * (1.0 - math.exp(-dt / handoverTau));
    if ((handoverTarget - _handover).abs() < 0.004) _handover = handoverTarget;

    // 4. Under finger: Chase target with exponential liquid lag (FOLLOW_TAU = 0.045s)
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

    // Check if physics engine can settle
    final bool liftSettled = (_liftX - _liftTarget).abs() < 0.001 &&
        (_liftY - _liftTarget).abs() < 0.001 &&
        _liftXVel.abs() < 0.005 &&
        _liftYVel.abs() < 0.005;

    final bool squashSettled = _squashModel.value.abs() < 0.001;
    final bool materialSettled = (_material - materialTarget).abs() < 0.004 &&
        (_handover - handoverTarget).abs() < 0.004;

    final bool isSettled = !_isDragging &&
        !_positionController.isAnimating &&
        liftSettled &&
        squashSettled &&
        materialSettled;

    if (isSettled) {
      _liftX = _liftTarget;
      _liftY = _liftTarget;
      _liftXVel = 0.0;
      _liftYVel = 0.0;
      _velocity = 0.0;
      _material = materialTarget;
      _handover = handoverTarget;
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
    _travelFrom = _currentPosition;
    final double targetPos = targetIndex.toDouble();

    if ((_currentPosition - targetPos).abs() < 0.001) {
      setState(() {
        _currentPosition = targetPos;
      });
      return;
    }

    // Material turns on smoothly as spring starts travel
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
      _liftTarget = 0.0;
      _ensureTicker();
    });
  }

  void _handleTapDown(TapDownDetails details) {
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
    _liftTarget = 1.0;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _currentPosition;
    _travelFrom = _currentPosition;
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
    _travelFrom = _currentPosition;
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
    _travelFrom = _currentPosition;
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

        // Proportional growth on lift: 55dp -> 66dp height, 96dp -> 115.2dp width
        final double liftedW = _kActiveSlotWidth + (_liftX * _kPillWidthGrowth);
        final double liftedH = _kPillHeight + (_liftY * _kPillLiftGrowth);

        final double dynamicPillWidth = liftedW * (1.0 + deviation);
        final double dynamicPillHeight = liftedH * (1.0 - deviation);

        // Center calculation: the distance between slot centers is identically 72.0dp!
        final double centerX = _kPaddingH + (_kActiveSlotWidth / 2.0) + (_currentPosition * _kInactiveSlotWidth);
        final double pillLeft = centerX - (dynamicPillWidth / 2.0);
        // Centers vertically around dock height (62dp): stands 2dp above & 2dp below dock edges when lifted!
        final double pillTop = (_kDockHeight / 2.0) - (dynamicPillHeight / 2.0);

        // Resting flat pill coordinates (active tab slot)
        final double restingCenter = _kPaddingH + (_kActiveSlotWidth / 2.0) + (widget.currentIndex * _kInactiveSlotWidth);
        final double restingLeft = restingCenter - (_kActiveSlotWidth / 2.0);
        final double restingTop = (_kDockHeight - _kPillHeight) / 2.0;

        // Continuous hand-off blend factors (BitChord standard: 0.16 white indicator in dark mode)
        final double glassPresence = (_material * (1.0 - _handover)).clamp(0.0, 1.0);
        final double flatAlpha = ((1.0 - _material) * (isDark ? 0.16 : 0.08)).clamp(0.0, 1.0);

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
                    // Radius: 31dp (semicircular cap concentric with pill's 27.5dp radius)
                    // ==============================================================
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(31),
                        child: BackdropFilter(
                          filter: useGlass
                              ? ImageFilter.blur(sigmaX: 16, sigmaY: 16)
                              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                          child: CustomPaint(
                            painter: _DockSpecularRimPainter(
                              isDark: isDark,
                              radius: 31,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: useGlass
                                    ? LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: isDark
                                            ? [
                                                Colors.white.withOpacity(0.16),
                                                Colors.white.withOpacity(0.05),
                                                Colors.white.withOpacity(0.03),
                                                Colors.white.withOpacity(0.08),
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
                                borderRadius: BorderRadius.circular(31),
                                boxShadow: isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.28),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
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
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
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
                    // Fades out continuously as glass material blooms in on touch!
                    // ==============================================================
                    if (flatAlpha > 0.005)
                      Positioned(
                        left: restingLeft,
                        top: restingTop,
                        width: _kActiveSlotWidth,
                        height: _kPillHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(flatAlpha),
                            borderRadius: BorderRadius.circular(_kPillHeight / 2),
                          ),
                        ),
                      ),

                    // ==============================================================
                    // LAYER 3: TAB ICONS & LABELS ROW (With 1.09x Optical Magnification)
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

                            // Optical Magnification: Icon magnifies to 1.09x under the lens!
                            final double distance = (_currentPosition - index).abs();
                            final double proximity = (1.0 - distance).clamp(0.0, 1.0);
                            final double iconScale = 1.0 + (0.09 * proximity);

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: isSelected ? _kActiveSlotWidth : _kInactiveSlotWidth,
                              height: _kPillHeight,
                              child: InkWell(
                                onTap: () => _selectTab(index),
                                borderRadius: BorderRadius.circular(27),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.scale(
                                        scale: iconScale,
                                        child: Icon(
                                          tab.icon,
                                          size: isSelected ? 20.0 : 21.0,
                                          color: isSelected ? activeColor : inactiveColor,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            tab.label,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11.5,
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
                    // Fades in continuously with glassPresence, stands above and outside dock!
                    // Pure optical water glass with 0.16 white core and feather-soft specular rim.
                    // ==============================================================
                    if (glassPresence > 0.005)
                      Positioned(
                        left: pillLeft,
                        top: pillTop,
                        width: dynamicPillWidth,
                        height: dynamicPillHeight,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: glassPresence,
                            child: Container(
                              decoration: BoxDecoration(
                                // Soft, luminous water droplet gradient with pure water-clear core
                                gradient: RadialGradient(
                                  center: const Alignment(-0.20, -0.40),
                                  radius: 0.95,
                                  colors: isDark
                                      ? [
                                          Colors.white.withOpacity(0.12 + (_liftY * 0.06)),
                                          Colors.white.withOpacity(0.03),
                                          Colors.transparent,
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.40 + (_liftY * 0.10)),
                                          Colors.white.withOpacity(0.10),
                                          Colors.transparent,
                                        ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(dynamicPillHeight / 2),
                                boxShadow: [
                                  // Deep, soft ambient drop shadow cast onto dock and screen (BitChord Image 4)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? (0.35 + _liftY * 0.15) : 0.12),
                                    blurRadius: 16 + (_liftY * 6.0),
                                    offset: Offset(0, 4 + (_liftY * 2.0)),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(isDark ? 0.06 : 0.0),
                                    blurRadius: 2,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _LiquidBubbleHighlightPainter(
                                  isDark: isDark,
                                  lift: _liftY,
                                ),
                              ),
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

/// Pure Optical Water Droplet Lens Shading (LastWave & BitChord Standard)
/// Devoid of fake colored strokes or harsh opaque white gleams.
/// Uses soft, feather-thin specular arcs (0.8px, 0.28 opacity) and gentle inset depth.
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

    // 1. Subtle, gentle inset lower shade (soft depth without harsh black bevels)
    final lowerShadeShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.transparent,
        Colors.black.withOpacity(0.02),
        Colors.black.withOpacity(isDark ? 0.08 : 0.05),
      ],
      stops: const [0.0, 0.50, 0.75, 1.0],
    ).createShader(rect);

    final softShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = lowerShadeShader;
    canvas.drawRRect(rrect, softShade);

    // 2. Upper-left soft specular light catch rim (Soft 0.8px hairline, gentle 0.28 opacity)
    final upperRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 + (lift * 0.3)
      ..shader = LinearGradient(
        begin: const Alignment(-0.6, -0.6),
        end: const Alignment(0.60, 1.0),
        colors: [
          Colors.white.withOpacity(isDark ? (0.28 + lift * 0.08).clamp(0.0, 0.40) : 0.45),
          Colors.white.withOpacity(isDark ? 0.10 : 0.18),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, upperRimPaint);

    // 3. Lower-right subtle ambient reflection rim
    final lowerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.04),
          Colors.white.withOpacity(isDark ? 0.15 : 0.22),
        ],
        stops: const [0.0, 0.65, 0.85, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rimRRect, lowerRimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidBubbleHighlightPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.lift != lift;
}
