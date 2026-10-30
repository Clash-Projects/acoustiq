import 'dart:math' as math;
import 'package:flutter/material.dart';

/// G2 Continuous-Curvature Superellipse (Squircle) Engine
///
/// Ported 1:1 from LastWave-Native's `createSquirclePath` (Cubic Bezier k = 1.528665).
/// Generates authentic Apple visionOS / iOS 18 curvature continuity without rigid cuts.
class SquirclePath {
  static Path create(
    Size size, {
    double radius = 24.0,
    double? topLeftRadius,
    double? topRightRadius,
    double? bottomRightRadius,
    double? bottomLeftRadius,
  }) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    if (w <= 0.0 || h <= 0.0) return path;

    final maxRadius = math.min(w, h) / 2.0;
    final tl = (topLeftRadius ?? radius).clamp(0.0, maxRadius);
    final tr = (topRightRadius ?? radius).clamp(0.0, maxRadius);
    final br = (bottomRightRadius ?? radius).clamp(0.0, maxRadius);
    final bl = (bottomLeftRadius ?? radius).clamp(0.0, maxRadius);

    const k = 1.528665;
    var lTl = tl * k;
    var lTr = tr * k;
    var lBr = br * k;
    var lBl = bl * k;

    final maxWTop = lTl + lTr;
    if (maxWTop > w && maxWTop > 0.0) {
      final scale = w / maxWTop;
      lTl *= scale;
      lTr *= scale;
    }
    final maxWBottom = lBl + lBr;
    if (maxWBottom > w && maxWBottom > 0.0) {
      final scale = w / maxWBottom;
      lBl *= scale;
      lBr *= scale;
    }
    final maxHLeft = lTl + lBl;
    if (maxHLeft > h && maxHLeft > 0.0) {
      final scale = h / maxHLeft;
      lTl *= scale;
      lBl *= scale;
    }
    final maxHRight = lTr + lBr;
    if (maxHRight > h && maxHRight > 0.0) {
      final scale = h / maxHRight;
      lTr *= scale;
      lBr *= scale;
    }

    path.moveTo(lTl, 0.0);
    path.lineTo(w - lTr, 0.0);

    // Top-Right Corner (Cubic Bezier G2 continuity)
    if (lTr > 0.001) {
      path.cubicTo(
        w - lTr * (1.0 - 0.712053), 0.0,
        w - lTr * (1.0 - 0.566789), lTr * 0.030183,
        w - lTr * (1.0 - 0.455953), lTr * 0.087377,
      );
      path.cubicTo(
        w - lTr * (1.0 - 0.345118), lTr * 0.144571,
        w - lTr * (1.0 - 0.242846), lTr * 0.242846,
        w - lTr * (1.0 - 0.144571), lTr * 0.345118,
      );
      path.cubicTo(
        w - lTr * (1.0 - 0.087377), lTr * 0.455953,
        w - lTr * 0.030183, lTr * (1.0 - 0.566789),
        w, lTr * (1.0 - 0.712053),
      );
      path.lineTo(w, lTr);
    } else {
      path.lineTo(w, 0.0);
      path.lineTo(w, lTr);
    }

    path.lineTo(w, h - lBr);

    // Bottom-Right Corner
    if (lBr > 0.001) {
      path.cubicTo(
        w, h - lBr * (1.0 - 0.712053),
        w - lBr * 0.030183, h - lBr * (1.0 - 0.566789),
        w - lBr * 0.087377, h - lBr * (1.0 - 0.455953),
      );
      path.cubicTo(
        w - lBr * 0.144571, h - lBr * (1.0 - 0.345118),
        w - lBr * 0.242846, h - lBr * (1.0 - 0.242846),
        w - lBr * 0.345118, h - lBr * (1.0 - 0.144571),
      );
      path.cubicTo(
        w - lBr * 0.455953, h - lBr * (1.0 - 0.087377),
        w - lBr * (1.0 - 0.566789), h - lBr * 0.030183,
        w - lBr * (1.0 - 0.712053), h,
      );
      path.lineTo(w - lBr, h);
    } else {
      path.lineTo(w, h);
      path.lineTo(w - lBr, h);
    }

    path.lineTo(lBl, h);

    // Bottom-Left Corner
    if (lBl > 0.001) {
      path.cubicTo(
        lBl * (1.0 - 0.712053), h,
        lBl * (1.0 - 0.566789), h - lBl * 0.030183,
        lBl * (1.0 - 0.455953), h - lBl * 0.087377,
      );
      path.cubicTo(
        lBl * (1.0 - 0.345118), h - lBl * 0.144571,
        lBl * (1.0 - 0.242846), h - lBl * 0.242846,
        lBl * (1.0 - 0.144571), h - lBl * 0.345118,
      );
      path.cubicTo(
        lBl * (1.0 - 0.087377), h - lBl * 0.455953,
        0.0, h - lBl * (1.0 - 0.566789),
        0.0, h - lBl * (1.0 - 0.712053),
      );
      path.lineTo(0.0, h - lBl);
    } else {
      path.lineTo(0.0, h);
      path.lineTo(0.0, h - lBl);
    }

    path.lineTo(0.0, lTl);

    // Top-Left Corner
    if (lTl > 0.001) {
      path.cubicTo(
        0.0, lTl * (1.0 - 0.712053),
        lTl * 0.030183, lTl * (1.0 - 0.566789),
        lTl * 0.087377, lTl * (1.0 - 0.455953),
      );
      path.cubicTo(
        lTl * 0.144571, lTl * (1.0 - 0.345118),
        lTl * 0.242846, lTl * (1.0 - 0.242846),
        lTl * 0.345118, lTl * (1.0 - 0.144571),
      );
      path.cubicTo(
        lTl * 0.455953, lTl * (1.0 - 0.087377),
        lTl * (1.0 - 0.566789), 0.0,
        lTl * (1.0 - 0.712053), 0.0,
      );
      path.lineTo(lTl, 0.0);
    } else {
      path.lineTo(0.0, 0.0);
      path.lineTo(lTl, 0.0);
    }

    path.close();
    return path;
  }
}

/// Custom Clipper for G2 Squircles
class SquircleClipper extends CustomClipper<Path> {
  final double radius;
  final double? topLeftRadius;
  final double? topRightRadius;
  final double? bottomRightRadius;
  final double? bottomLeftRadius;

  const SquircleClipper({
    this.radius = 24.0,
    this.topLeftRadius,
    this.topRightRadius,
    this.bottomRightRadius,
    this.bottomLeftRadius,
  });

  @override
  Path getClip(Size size) {
    return SquirclePath.create(
      size,
      radius: radius,
      topLeftRadius: topLeftRadius,
      topRightRadius: topRightRadius,
      bottomRightRadius: bottomRightRadius,
      bottomLeftRadius: bottomLeftRadius,
    );
  }

  @override
  bool shouldReclip(covariant SquircleClipper oldClipper) {
    return oldClipper.radius != radius ||
        oldClipper.topLeftRadius != topLeftRadius ||
        oldClipper.topRightRadius != topRightRadius ||
        oldClipper.bottomRightRadius != bottomRightRadius ||
        oldClipper.bottomLeftRadius != bottomLeftRadius;
  }
}

/// Custom Painter for Sub-Pixel Hairline Rim on G2 Squircle
class SquircleBorderPainter extends CustomPainter {
  final double radius;
  final Color borderColor;
  final double borderWidth;

  SquircleBorderPainter({
    required this.radius,
    required this.borderColor,
    this.borderWidth = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (borderWidth <= 0 || borderColor.opacity <= 0) return;
    final path = SquirclePath.create(size, radius: radius);
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SquircleBorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
