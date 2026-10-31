import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';

/// Hybrid Forensic Audio Analyzer Stage
///
/// Features:
/// 1. Radial Purity Speedometer Dial:
///    - Dynamic spring sweep animation (0 -> score) with animated numeric count-up.
///    - Ambient breathing glow pulse on the active arc tip.
///    - Status chip (GENUINE / SUSPICIOUS / FAKE).
/// 2. Scientific Frequency Roll-Off Shelf Canvas:
///    - Genuine FLAC: Natural smooth acoustic roll-off extending past 20 kHz to 22.05 kHz Nyquist limit.
///    - Fake FLAC: Vertical brickwall cliff drop at 16.0 kHz (MP3 encoder signature) leaving an absolute void.
///    - Continuous live acoustic micro-shimmer along active spectrum.
///    - Vertical glowing laser cutoff guide at the exact cutoff frequency.
class AudioSpectrumStage extends StatefulWidget {
  final int score;
  final double cutoffKhz;
  final double maxKhz;
  final String status;
  final String shortBadge;
  final Color statusColor;
  final double height;

  const AudioSpectrumStage({
    super.key,
    this.score = 98,
    required this.cutoffKhz,
    required this.maxKhz,
    this.status = 'genuine',
    this.shortBadge = 'GENUINE LOSSLESS',
    required this.statusColor,
    this.height = 136.0,
  });

  @override
  State<AudioSpectrumStage> createState() => _AudioSpectrumStageState();
}

class _AudioSpectrumStageState extends State<AudioSpectrumStage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AudioSpectrumStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score || oldWidget.cutoffKhz != widget.cutoffKhz) {
      _entryController.reset();
      _entryController.forward();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);
        final safeMax = widget.maxKhz > 0 ? widget.maxKhz : 24.0;

        return GlassSurface(
          borderRadius: BorderRadius.circular(20),
          style: GlassStyle.frosted,
          borderless: false,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: AnimatedBuilder(
            animation: Listenable.merge([_entryAnimation, _shimmerController]),
            builder: (context, _) {
              final entryVal = _entryAnimation.value;
              final shimmerVal = _shimmerController.value;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Left: Radial Purity Speedometer Dial (~104dp width)
                  SizedBox(
                    width: 104,
                    height: widget.height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(88, 88),
                                painter: _SpeedometerDialPainter(
                                  score: widget.score,
                                  entryProgress: entryVal,
                                  shimmerProgress: shimmerVal,
                                  statusColor: widget.statusColor,
                                  isDark: isDark,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(widget.score * entryVal).round()}%',
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: textColor,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'PURITY',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Status Badge Tag below dial
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: widget.statusColor.withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.status == 'genuine'
                                    ? Icons.verified_rounded
                                    : (widget.status == 'suspicious'
                                        ? Icons.warning_amber_rounded
                                        : Icons.cancel_rounded),
                                size: 11,
                                color: widget.statusColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.status.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: widget.statusColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1,
                    height: widget.height - 16,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: isDark ? const Color(0x18FFFFFF) : const Color(0x12000000),
                  ),

                  // 2. Right: Scientific Frequency Cutoff Shelf Canvas
                  Expanded(
                    child: SizedBox(
                      height: widget.height,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Telemetry Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.graphic_eq_rounded, size: 13, color: widget.statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cutoff: ${widget.cutoffKhz.toStringAsFixed(1)} kHz',
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Limit: ${safeMax.toStringAsFixed(1)}k',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Frequency Shelf Area Graph
                          Expanded(
                            child: CustomPaint(
                              painter: _FrequencyShelfPainter(
                                cutoffKhz: widget.cutoffKhz,
                                maxKhz: safeMax,
                                entryProgress: entryVal,
                                shimmerProgress: shimmerVal,
                                statusColor: widget.statusColor,
                                isDark: isDark,
                                subTextColor: subTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Speedometer Gauge Painter: Radial Track with Animated Arc & Glowing Bead
class _SpeedometerDialPainter extends CustomPainter {
  final int score;
  final double entryProgress;
  final double shimmerProgress;
  final Color statusColor;
  final bool isDark;

  _SpeedometerDialPainter({
    required this.score,
    required this.entryProgress,
    required this.shimmerProgress,
    required this.statusColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 6.4;
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = 135 * (math.pi / 180); // 135 deg
    const totalSweep = 270 * (math.pi / 180); // 270 deg tachometer arc

    // 1. Background Track Arc
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0x22FFFFFF) : const Color(0x15000000);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    // 2. Active Animated Progress Arc
    final activeRatio = (score / 100.0).clamp(0.0, 1.0);
    final activeSweep = totalSweep * activeRatio * entryProgress;

    if (activeSweep > 0.01) {
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + totalSweep,
          colors: [
            statusColor.withOpacity(0.40),
            statusColor,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );

      // 3. Glowing End Bead on Arc Tip
      final endAngle = startAngle + activeSweep;
      final tipPos = Offset(
        center.dx + math.cos(endAngle) * radius,
        center.dy + math.sin(endAngle) * radius,
      );

      final pulse = 0.65 + 0.35 * math.sin(shimmerProgress * 2 * math.pi);

      // Diffuse halo glow
      canvas.drawCircle(
        tipPos,
        6.5 * pulse,
        Paint()..color = statusColor.withOpacity(0.38 * pulse),
      );

      // Bright solid core bead
      canvas.drawCircle(
        tipPos,
        3.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerDialPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.entryProgress != entryProgress ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Scientific Frequency Cutoff Shelf Painter
/// Renders authentic Nyquist frequency slope & sharp brickwall drops
class _FrequencyShelfPainter extends CustomPainter {
  final double cutoffKhz;
  final double maxKhz;
  final double entryProgress;
  final double shimmerProgress;
  final Color statusColor;
  final bool isDark;
  final Color subTextColor;

  _FrequencyShelfPainter({
    required this.cutoffKhz,
    required this.maxKhz,
    required this.entryProgress,
    required this.shimmerProgress,
    required this.statusColor,
    required this.isDark,
    required this.subTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = size.height - 15.0; // Leaves 15dp for bottom axis labels
    const peakY = 4.0;
    final availableHeight = baselineY - peakY;

    final cutoffRatio = (cutoffKhz / maxKhz).clamp(0.05, 1.0);
    final cutoffX = size.width * cutoffRatio;
    final revealX = size.width * entryProgress;

    // 1. Draw Subtle Axis Baseline
    final axisPaint = Paint()
      ..color = isDark ? const Color(0x18FFFFFF) : const Color(0x15000000)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), axisPaint);

    // 2. Generate Forensic Frequency Curve
    final curvePath = Path();
    curvePath.moveTo(0, baselineY);

    const int pointCount = 50;
    final List<Offset> points = [];

    final isBrickwall = cutoffKhz <= 18.5; // MP3 upscales exhibit brickwall cliff drops

    for (int i = 0; i <= pointCount; i++) {
      final double x = (i / pointCount) * size.width;
      final double f = (x / size.width) * maxKhz;

      double y;
      if (f <= cutoffKhz) {
        // High frequency active audio spectrum
        final progressInActive = f / cutoffKhz;
        // Natural acoustic slope: strong dynamic energy with gentle taper
        final baseAmplitude = 0.88 - (progressInActive * 0.22);
        // Live harmonic micro-shimmer ripple
        final shimmer = math.sin(progressInActive * 5 * math.pi + shimmerProgress * 2 * math.pi) * 2.8;

        if (isBrickwall && progressInActive > 0.94) {
          // Sharp vertical cliff drop for fake MP3
          y = baselineY;
        } else {
          y = baselineY - (availableHeight * baseAmplitude) + shimmer;
        }
      } else {
        // Past cutoff point: Absolute energy void (lossy compression artifact)
        y = baselineY;
      }

      points.add(Offset(x, y.clamp(peakY, baselineY)));
    }

    // Build area fill path
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (pt.dx <= revealX) {
        if (i == 0) {
          curvePath.lineTo(pt.dx, pt.dy);
        } else {
          curvePath.lineTo(pt.dx, pt.dy);
        }
      } else {
        curvePath.lineTo(revealX, baselineY);
        break;
      }
    }
    curvePath.lineTo(math.min(size.width, revealX), baselineY);
    curvePath.close();

    // Fill with soft translucent gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          statusColor.withOpacity(0.35),
          statusColor.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, baselineY));

    canvas.drawPath(curvePath, fillPaint);

    // 3. Draw Top Neon Stroke Line
    final strokePath = Path();
    bool strokeStarted = false;
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (pt.dx <= revealX) {
        if (!strokeStarted) {
          strokePath.moveTo(pt.dx, pt.dy);
          strokeStarted = true;
        } else {
          strokePath.lineTo(pt.dx, pt.dy);
        }
      }
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = statusColor;

    canvas.drawPath(strokePath, strokePaint);

    // 4. Vertical Glowing Laser Cutoff Line & Tag
    if (cutoffX <= revealX) {
      final laserPulse = 0.70 + 0.30 * math.sin(shimmerProgress * 2 * math.pi);
      final laserPaint = Paint()
        ..color = statusColor.withOpacity(0.70 * laserPulse)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;

      // Draw vertical dashed guide
      double startY = peakY;
      while (startY < baselineY) {
        canvas.drawLine(
          Offset(cutoffX, startY),
          Offset(cutoffX, math.min(startY + 4, baselineY)),
          laserPaint,
        );
        startY += 7;
      }

      // Small glowing bead at cutoff apex
      canvas.drawCircle(
        Offset(cutoffX, peakY + 2),
        3.0,
        Paint()..color = statusColor,
      );
    }

    // 5. Frequency Axis Ticks & Labels
    _drawAxisLabel(canvas, '0k', 0, baselineY + 2, Alignment.centerLeft);
    if (maxKhz >= 20.0) {
      final x16 = (16.0 / maxKhz) * size.width;
      _drawAxisLabel(
        canvas,
        isBrickwall ? '16k [MP3]' : '16k',
        x16,
        baselineY + 2,
        Alignment.center,
        color: isBrickwall ? AppColors.fakeCoral : subTextColor.withOpacity(0.7),
      );
    }
    final xLimit = size.width;
    _drawAxisLabel(
      canvas,
      '${cutoffKhz.toStringAsFixed(0)}k',
      cutoffX,
      baselineY + 2,
      Alignment.center,
      color: statusColor,
      isBold: true,
    );
    _drawAxisLabel(canvas, '${maxKhz.toStringAsFixed(0)}k', xLimit, baselineY + 2, Alignment.centerRight);
  }

  void _drawAxisLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    Alignment alignment, {
    Color? color,
    bool isBold = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 9.0,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? subTextColor.withOpacity(0.6),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    double dx = x;
    if (alignment == Alignment.center) {
      dx -= textPainter.width / 2;
    } else if (alignment == Alignment.centerRight) {
      dx -= textPainter.width;
    }

    textPainter.paint(canvas, Offset(dx.clamp(0.0, 400.0), y));
  }

  @override
  bool shouldRepaint(covariant _FrequencyShelfPainter oldDelegate) {
    return oldDelegate.cutoffKhz != cutoffKhz ||
        oldDelegate.maxKhz != maxKhz ||
        oldDelegate.entryProgress != entryProgress ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.isDark != isDark;
  }
}
