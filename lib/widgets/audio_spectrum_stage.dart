import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';

/// Studio Spectral Nyquist Analyzer Stage
///
/// Features:
/// 1. 32-band real-time animated audio spectrum visualizer.
/// 2. Glowing laser cutoff line at the exact track cutoff frequency.
/// 3. Nyquist theoretical frequency marker (22.05 kHz / 48 kHz / 96 kHz).
/// 4. Embedded in a WWDC25 Clear Glass container with glossy reflections.
class AudioSpectrumStage extends StatefulWidget {
  final double cutoffKhz;
  final double maxKhz;
  final Color statusColor;
  final double height;

  const AudioSpectrumStage({
    super.key,
    required this.cutoffKhz,
    required this.maxKhz,
    required this.statusColor,
    this.height = 42.0,
  });

  @override
  State<AudioSpectrumStage> createState() => _AudioSpectrumStageState();
}

class _AudioSpectrumStageState extends State<AudioSpectrumStage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final subTextColor = appState.getSubTextColor(context);
        final safeMax = widget.maxKhz > 0 ? widget.maxKhz : 22.05;
        final cutoffRatio = (widget.cutoffKhz / safeMax).clamp(0.0, 1.0);

        return GlassSurface(
          borderRadius: BorderRadius.circular(18),
          style: GlassStyle.clear,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Frequency Readouts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 14, color: widget.statusColor),
                      const SizedBox(width: 5),
                      Text(
                        'Cutoff: ${widget.cutoffKhz.toStringAsFixed(1)} kHz',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Nyquist: ${safeMax.toStringAsFixed(1)} kHz',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Animated Spectrum Canvas
              SizedBox(
                height: widget.height,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: AudioSpectrumPainter(
                        cutoffRatio: cutoffRatio,
                        statusColor: widget.statusColor,
                        animProgress: _controller.value,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom Spectrogram Visualizer Canvas with Laser Cutoff Guideline
class AudioSpectrumPainter extends CustomPainter {
  final double cutoffRatio;
  final Color statusColor;
  final double animProgress;
  final bool isDark;

  AudioSpectrumPainter({
    required this.cutoffRatio,
    required this.statusColor,
    required this.animProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 32;
    final barWidth = (size.width - (barCount - 1) * 3) / barCount;
    final activeCount = (barCount * cutoffRatio).round();

    final activePaint = Paint()..style = PaintingStyle.fill;
    final inactivePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0x30FFFFFF) : const Color(0xFFDCDCE0);

    for (int i = 0; i < barCount; i++) {
      // Harmonic wave shape with gentle animation ripple
      final wave = math.sin((i / barCount) * math.pi) * 0.85 + 0.15;
      final jitter = math.sin(i * 1.5 + animProgress * math.pi) * 0.12;
      final heightRatio = (wave + jitter).clamp(0.15, 1.0);
      final barHeight = size.height * heightRatio;

      final x = i * (barWidth + 3);
      final y = size.height - barHeight;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(3),
      );

      if (i < activeCount) {
        activePaint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            statusColor.withOpacity(0.50),
            statusColor,
          ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));
        canvas.drawRRect(barRect, activePaint);
      } else {
        canvas.drawRRect(barRect, inactivePaint);
      }
    }

    // Cutoff Laser Line Marker with soft ambient glow
    final cutoffX = activeCount * (barWidth + 3);
    final laserPaint = Paint()
      ..color = statusColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cutoffX, 0),
      Offset(cutoffX, size.height),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant AudioSpectrumPainter oldDelegate) {
    return oldDelegate.cutoffRatio != cutoffRatio ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.isDark != isDark;
  }
}
