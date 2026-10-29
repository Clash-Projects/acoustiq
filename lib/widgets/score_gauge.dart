import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScoreGauge extends StatelessWidget {
  final int score;
  final String status;
  final double cutoffKhz;
  final double maxKhz;

  const ScoreGauge({
    super.key,
    required this.score,
    required this.status,
    required this.cutoffKhz,
    required this.maxKhz,
  });

  Color get statusColor {
    if (score >= 80) return const Color(0xFF00E676); // Emerald Green
    if (score >= 55) return const Color(0xFFFFB300); // Amber
    return const Color(0xFFFF3D3D); // Crimson Red
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 180,
          child: CustomPaint(
            painter: _ArcPainter(
              score: score,
              color: statusColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.5,
                          shadows: [
                            Shadow(
                              color: statusColor.withOpacity(0.5),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Cutoff Frequency Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 16, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              'Cutoff: ${cutoffKhz.toStringAsFixed(1)} kHz',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.3,
              ),
            ),
            Text(
              '  /  Max: ${maxKhz.toStringAsFixed(1)} kHz',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final int score;
  final Color color;

  _ArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = size.width / 2 - 16;
    const startAngle = 135 * (math.pi / 180);
    const sweepTotal = 270 * (math.pi / 180);
    final currentSweep = sweepTotal * (score.clamp(0, 100) / 100);

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Progress Arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.4),
          color,
        ],
        startAngle: startAngle,
        endAngle: startAngle + sweepTotal,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      progressPaint,
    );

    // Tip dot on progress arc
    if (score > 2) {
      final tipAngle = startAngle + currentSweep;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);

      final glowPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), 9, glowPaint);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(tipX, tipY), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}

