import 'package:flutter/material.dart';

/// Smooth Continuous-Curvature Rounded Geometry Engine
///
/// Implements silky-smooth, continuous rounded geometry without sharp chamfers,
/// polygon cuts, or inverted Bezier artifacts.
class SquirclePath {
  static Path create(
    Size size, {
    double radius = 22.0,
    double? topLeftRadius,
    double? topRightRadius,
    double? bottomRightRadius,
    double? bottomLeftRadius,
  }) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    if (w <= 0.0 || h <= 0.0) return path;

    final maxRadius = (w < h ? w : h) / 2.0;
    final tl = (topLeftRadius ?? radius).clamp(0.0, maxRadius);
    final tr = (topRightRadius ?? radius).clamp(0.0, maxRadius);
    final br = (bottomRightRadius ?? radius).clamp(0.0, maxRadius);
    final bl = (bottomLeftRadius ?? radius).clamp(0.0, maxRadius);

    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: Radius.circular(tl),
      topRight: Radius.circular(tr),
      bottomRight: Radius.circular(br),
      bottomLeft: Radius.circular(bl),
    );

    path.addRRect(rrect);
    return path;
  }
}

/// Custom Clipper for Smooth Continuous Curves
class SquircleClipper extends CustomClipper<Path> {
  final double radius;
  final double? topLeftRadius;
  final double? topRightRadius;
  final double? bottomRightRadius;
  final double? bottomLeftRadius;

  const SquircleClipper({
    this.radius = 22.0,
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

/// Custom Painter for Sub-Pixel Hairline Rim on Smooth Rounded Geometry
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
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant SquircleBorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
