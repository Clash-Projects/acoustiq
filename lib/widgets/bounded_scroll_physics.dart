import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bounded Bouncing Scroll Physics for AcoustiQ
///
/// Resolves Flutter's "Infinite Overscroll / Multi-Touch Ratchet" bug via a
/// bulletproof double-lock mechanism:
///
/// 1. Low-level Pipeline Lock ([applyBoundaryConditions]):
///    Guarantees that [ScrollPosition.pixels] can NEVER under any circumstances
///    exceed [maxOverscroll] (default 140dp) outside [minScrollExtent] and [maxScrollExtent].
///    Any delta attempting to move past this threshold is immediately intercepted
///    and clamped to zero by Flutter's scroll engine.
///
/// 2. User Offset Drag Lock ([applyPhysicsToUserOffset]):
///    Correctly checks Flutter's inverted drag offset sign (`offset < 0.0` when easing
///    back from start, `offset > 0.0` when easing back from end). When the user is
///    dragging deeper into overscroll, user motion is progressively dampened by friction
///    and strictly capped at [maxOverscroll].
///
/// 3. Quadratic Inversion Shield ([frictionFactor]):
///    Clamps [frictionFactor] input to `[0.0, 1.0]`, preventing Flutter's quadratic (1 - x)^2
///    formula from inverting and exponentially accelerating into outer space when overscroll
///    exceeds the viewport height.
///
/// 4. 100% Responsiveness:
///    Easing back towards the content boundary is never restricted or delayed.
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
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double hardMin = position.minScrollExtent - maxOverscroll;
    final double hardMax = position.maxScrollExtent + maxOverscroll;

    // Moving further past hardMin (underscroll)
    if (value < position.pixels && position.pixels <= hardMin) {
      return value - position.pixels;
    }
    // Moving further past hardMax (overscroll)
    if (hardMax <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    // Crossing hardMin boundary from inside towards outside
    if (value < hardMin && hardMin < position.pixels) {
      return value - hardMin;
    }
    // Crossing hardMax boundary from inside towards outside
    if (position.pixels < hardMax && hardMax < value) {
      return value - hardMax;
    }
    return 0.0;
  }
}
