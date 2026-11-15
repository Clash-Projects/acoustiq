import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bounded Bouncing Scroll Physics for AcoustiQ
///
/// Resolves Flutter's "Infinite Overscroll / Multi-Touch Ratchet" bug:
/// 1. Enforces a strict physical ceiling ([maxOverscroll], default 140dp) on overscroll distance.
///    Even if a user holds with one hand and repeatedly swipes with the other, the content
///    never leaves the viewport and stops cleanly at the ceiling.
/// 2. Clamps [frictionFactor] input to [0.0, 1.0], preventing Flutter's quadratic (1 - x)^2
///    formula from inverting and exponentially accelerating into outer space when overscroll
///    exceeds the viewport height.
/// 3. Preserves 100% responsiveness when easing back towards the content boundary.
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

    final bool easing = (overscrollPastStart > 0.0 && offset > 0.0)
        || (overscrollPastEnd > 0.0 && offset < 0.0);

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
}
