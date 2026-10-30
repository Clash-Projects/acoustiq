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
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 190,
          height: 150,
          child: CustomPaint(
            painter: _ArcPainter(
              score: score,
              color: statusColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  // Number + % Baseline Aligned
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          shadows: [
                            Shadow(
                              color: statusColor.withOpacity(0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '%',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Cutoff Frequency Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 15, color: Colors.white.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(
              'Cutoff: ${cutoffKhz.toStringAsFixed(1)} kHz',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.90),
                letterSpacing: 0.2,
              ),
            ),
            Text(
              '  /  Max: ${maxKhz.toStringAsFixed(1)} kHz',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: Colors.white.withOpacity(0.40),
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
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final radius = size.width / 2 - 14;
    const startAngle = 135 * (math.pi / 180);
    const sweepTotal = 270 * (math.pi / 180);
    final currentSweep = sweepTotal * (score.clamp(0, 100) / 100);

    // Track Background Arc
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Active Score Arc
    if (score > 0) {
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round;

      // Score Arc Glow Shadow
      final glowPaint = Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        glowPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        activePaint,
      );

      // Arc Head Needle Pill Dot
      final headAngle = startAngle + currentSweep;
      final headOffset = Offset(
        center.dx + radius * math.cos(headAngle),
        center.dy + radius * math.sin(headAngle),
      );

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(headOffset, 6.0, dotPaint);

      final dotGlow = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(headOffset, 6.0, dotGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}
