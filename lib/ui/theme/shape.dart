import 'package:flutter/material.dart';

/// Material 3 Expressive Shape Tokens (1:1 with LastWave Native)
///
/// Hoisted immutable shape constants matching LastWave's Shape.kt
/// to avoid per-frame re-allocations in list rows and hero containers.
class ExpressiveShapes {
  ExpressiveShapes._();

  /// 32dp continuous corner curvature for top Hero containers and stats cards
  static const BorderRadius hero = BorderRadius.all(Radius.circular(32));

  /// 24dp inner rounded container nested inside the Hero Stage
  static const BorderRadius heroInner = BorderRadius.all(Radius.circular(24));

  /// 28dp top-corner continuous surface for unified list and content stages
  static const BorderRadius listContainer = BorderRadius.only(
    topLeft: Radius.circular(28),
    topRight: Radius.circular(28),
  );

  /// 28dp continuous pill dock shape for FloatingNavBar
  static const BorderRadius dock = BorderRadius.all(Radius.circular(28));

  /// 18dp rounded container for interactive file and track rows
  static const BorderRadius trackRow = BorderRadius.all(Radius.circular(18));

  /// 16dp rounded quick telemetry pill
  static const BorderRadius statPill = BorderRadius.all(Radius.circular(16));

  /// 14dp rounded thumbnail container for album artwork or waveform badge
  static const BorderRadius artwork = BorderRadius.all(Radius.circular(14));

  /// 100dp stadium/capsule shape for technical badges and interactive chips
  static const BorderRadius badgePill = BorderRadius.all(Radius.circular(100));

  /// 6dp inner corner radius for connected group rows
  static const BorderRadius innerGroup = BorderRadius.all(Radius.circular(6));
}

/// Where a row sits within a visually connected group of settings or duplicate rows.
/// Drives per-row corner radii so a multi-row group reads as one premium surface.
enum GroupPosition {
  single,
  top,
  middle,
  bottom,
}

BorderRadius groupShape(GroupPosition position) {
  const outer = Radius.circular(28);
  const inner = Radius.circular(6);

  switch (position) {
    case GroupPosition.single:
      return const BorderRadius.all(outer);
    case GroupPosition.top:
      return const BorderRadius.only(
        topLeft: outer,
        topRight: outer,
        bottomLeft: inner,
        bottomRight: inner,
      );
    case GroupPosition.middle:
      return const BorderRadius.all(inner);
    case GroupPosition.bottom:
      return const BorderRadius.only(
        topLeft: inner,
        topRight: inner,
        bottomLeft: outer,
        bottomRight: outer,
      );
  }
}

