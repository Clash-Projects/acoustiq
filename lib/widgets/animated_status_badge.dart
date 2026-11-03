import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Hardware-accelerated animated vector status badge for AcoustiQ.
/// Supports smooth stroke-drawing on entry and organic sinusoidal breathing glow.
class AnimatedStatusBadge extends StatefulWidget {
  final String status; // 'genuine', 'suspicious', 'fake'
  final Color color;
  final double size;
  final bool animatePulse;

  const AnimatedStatusBadge({
    super.key,
    required this.status,
    required this.color,
    this.size = 32.0,
    this.animatePulse = true,
  });

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge>
    with TickerProviderStateMixin {
  late AnimationController _drawController;
  late Animation<double> _drawProgress;

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Vector Stroke Entry Animation (450ms cubic ease-out)
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _drawProgress = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutCubic,
    );
    _drawController.forward();

    // 2. Organic Sinusoidal Breathing Glow (1800ms loop)
    if (widget.animatePulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);
      _pulseAnimation = CurvedAnimation(
        parent: _pulseController!,
        curve: Curves.easeInOutSine,
      );
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _drawController.reset();
      _drawController.forward();
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Listenable> anims = [_drawProgress];
    if (_pulseAnimation != null) anims.add(_pulseAnimation!);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(anims),
        builder: (context, _) {
          final drawVal = _drawProgress.value;
          final pulseVal = _pulseAnimation?.value ?? 0.0;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _BadgeVectorPainter(
                status: widget.status,
                color: widget.color,
                drawProgress: drawVal,
                pulseProgress: pulseVal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BadgeVectorPainter extends CustomPainter {
  final String status;
  final Color color;
  final double drawProgress;
  final double pulseProgress;

  _BadgeVectorPainter({
    required this.status,
    required this.color,
    required this.drawProgress,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Organic Breathing Halo Glow (Behind circle)
    if (pulseProgress > 0.0) {
      final glowRadius = radius + (pulseProgress * 4.0);
      final glowOpacity = (0.12 + 0.16 * pulseProgress).clamp(0.0, 1.0);
      final glowPaint = Paint()
        ..color = color.withOpacity(glowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 + pulseProgress * 3.0);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // 2. Translucent Base Circle Fill
    final bgPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 1.0, bgPaint);

    // 3. Subtle Rim Ring
    final rimPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 1.0, rimPaint);

    // 4. Dynamic Vector Stroke Drawing inside
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.09).clamp(2.0, 3.4)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (status == 'genuine') {
      _paintCheckmark(canvas, size, strokePaint, drawProgress);
    } else if (status == 'suspicious') {
      _paintWarning(canvas, size, strokePaint, drawProgress);
    } else {
      _paintCross(canvas, size, strokePaint, drawProgress);
    }
  }

  void _paintCheckmark(Canvas canvas, Size size, Paint paint, double progress) {
    final p = Path();
    final w = size.width;
    final h = size.height;

    // Standard 3-point checkmark path
    final start = Offset(w * 0.28, h * 0.52);
    final mid = Offset(w * 0.44, h * 0.68);
    final end = Offset(w * 0.74, h * 0.36);

    p.moveTo(start.dx, start.dy);
    p.lineTo(mid.dx, mid.dy);
    p.lineTo(end.dx, end.dy);

    _drawTrimmedPath(canvas, p, paint, progress);
  }

  void _paintCross(Canvas canvas, Size size, Paint paint, double progress) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.30;

    // Stroke 1: Top-Left to Bottom-Right (progress 0.0 -> 0.5)
    final p1 = Path()
      ..moveTo(inset, inset)
      ..lineTo(w - inset, h - inset);
    final prog1 = (progress / 0.5).clamp(0.0, 1.0);
    _drawTrimmedPath(canvas, p1, paint, prog1);

    // Stroke 2: Top-Right to Bottom-Left (progress 0.5 -> 1.0)
    if (progress > 0.4) {
      final p2 = Path()
        ..moveTo(w - inset, inset)
        ..lineTo(inset, h - inset);
      final prog2 = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      _drawTrimmedPath(canvas, p2, paint, prog2);
    }
  }

  void _paintWarning(Canvas canvas, Size size, Paint paint, double progress) {
    final w = size.width;
    final h = size.height;

    // Rounded Warning Triangle
    final p = Path();
    p.moveTo(w * 0.50, h * 0.26);
    p.lineTo(w * 0.76, h * 0.74);
    p.lineTo(w * 0.24, h * 0.74);
    p.close();

    _drawTrimmedPath(canvas, p, paint, (progress / 0.75).clamp(0.0, 1.0));

    // Exclamation Mark inside triangle (fades in during last 25%)
    if (progress > 0.65) {
      final dotOpacity = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
      final innerPaint = Paint()
        ..color = color.withOpacity(dotOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = paint.strokeWidth * 0.9
        ..strokeCap = StrokeCap.round;

      // Stem
      canvas.drawLine(
        Offset(w * 0.50, h * 0.44),
        Offset(w * 0.50, h * 0.58),
        innerPaint,
      );
      // Dot
      final dotFill = Paint()
        ..color = color.withOpacity(dotOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w * 0.50, h * 0.66), paint.strokeWidth * 0.5, dotFill);
    }
  }

  void _drawTrimmedPath(Canvas canvas, Path originalPath, Paint paint, double progress) {
    if (progress <= 0.0) return;
    for (final metric in originalPath.computeMetrics()) {
      final extract = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extract, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeVectorPainter oldDelegate) {
    return oldDelegate.status != status ||
        oldDelegate.color != color ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
