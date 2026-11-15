import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bounded Bouncing Scroll Physics for AcoustiQ
///
/// Resolves Flutter's "Infinite Overscroll / Multi-Touch Ratchet" bug while
/// preserving butter-smooth spring bounce-back without any freezing/locking:
///
/// 1. User Offset Drag Lock ([applyPhysicsToUserOffset]):
///    Correctly checks Flutter's drag offset sign (`offset < 0.0` when easing back
///    from start, `offset > 0.0` when easing back from end). When dragging deeper into
///    overscroll, drag deltas are progressively dampened by friction and strictly
///    capped to zero once [maxOverscroll] (140dp) is reached. Even with multi-touch
///    ratchet swiping, user drags cannot push the content past 140dp.
///
/// 2. Zero-Freeze Ballistic Compatibility:
///    [applyBoundaryConditions] intentionally returns `0.0`. In Flutter, returning
///    a non-zero overscroll from [applyBoundaryConditions] signals [BallisticScrollActivity]
///    that a rigid wall was hit, immediately calling `goIdle()` and freezing/locking
///    the scroll view at the overscroll limit! By returning `0.0`, the spring simulation
///    is guaranteed to complete its natural deceleration and bounce all the way back to bounds.
///
/// 3. Velocity Clamp in [createBallisticSimulation]:
///    Clamps incoming fling velocities to avoid excessive kinetic impulses that could
///    momentarily throw the spring past comfortable visual bounds.
///
/// 4. Quadratic Inversion Shield ([frictionFactor]):
///    Clamps [frictionFactor] input to `[0.0, 1.0]`, preventing Flutter's quadratic (1 - x)^2
///    formula from inverting and exponentially accelerating into outer space when overscroll
///    exceeds the viewport height.
class BoundedBouncingScrollPhysics extends BouncingScrollPhysics {
  final double maxOverscroll;

  const BoundedBouncingScrollPhysics({
    super.parent,
    super.decelerationRate,
    this.maxOverscroll = 140.0,
  });

  @override
  BoundedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BoundedBouncingScrollPhysics(
      parent: buildParent(ancestor),
      decelerationRate: decelerationRate,
      maxOverscroll: maxOverscroll,
    );
  }

  @override
  double frictionFactor(double overscrollFraction) {
    // Clamp to [0.0, 1.0] to prevent Flutter's quadratic (1 - x)^2 formula
    // from inverting into reverse acceleration when overscroll exceeds viewport height.
    final double clamped = overscrollFraction.clamp(0.0, 1.0);
    return super.frictionFactor(clamped);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    assert(offset != 0.0);
    assert(position.minScrollExtent <= position.maxScrollExtent);

    if (!position.outOfRange) {
      return offset;
    }

    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast = math.max(overscrollPastStart, overscrollPastEnd);

    // In Flutter, ScrollPosition.applyUserOffset(delta) does:
    // setPixels(pixels - applyPhysicsToUserOffset(delta))
    // - Dragging down past start: delta > 0, pixels decreases.
    // - Moving back towards content: delta < 0, pixels increases (easing == true).
    // - Dragging up past end: delta < 0, pixels increases.
    // - Moving back towards content: delta > 0, pixels decreases (easing == true).
    final bool easing = (overscrollPastStart > 0.0 && offset < 0.0)
        || (overscrollPastEnd > 0.0 && offset > 0.0);

    // Hard ceiling gate: prevent multi-touch ratcheting past maximum overscroll limit
    if (!easing && overscrollPast >= maxOverscroll) {
      return 0.0;
    }

    final double delta = super.applyPhysicsToUserOffset(position, offset);

    // Prevent single-frame delta from overshooting past the ceiling
    if (!easing) {
      final double remaining = maxOverscroll - overscrollPast;
      if (delta.abs() > remaining) {
        return delta.sign * remaining;
      }
    }

    return delta;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Calibrate maximum velocity so high-speed flicks stay comfortably within bounds
    final double clampedVelocity = velocity.clamp(-3000.0, 3000.0);
    return super.createBallisticSimulation(position, clampedVelocity);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // MUST return 0.0 for bouncing physics!
    // Returning non-zero here triggers BallisticScrollActivity.applyMoveTo() == false,
    // which immediately calls delegate.goIdle() and kills the spring simulation mid-flight,
    // permanently freezing/locking the scroll position in the overscroll state.
    return 0.0;
  }
}
