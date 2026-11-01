import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'app_snack_bar.dart';

/// Studio Audio Authenticity Stage (Speedometer Gauge + Waveform Hybrid Switcher)
///
/// Features:
/// 1. 3-Way Segmented Visualizer Switcher:
///    - [ ⚡ Hybrid ]: Left 72dp Speedometer Dial + Right 16-Bar Frequency Waveform (Default).
///    - [ ⏱️ Gauge ]: Full 90dp Speedometer Dial with score count-up and status pill.
///    - [ 📊 Waveform ]: 32-Bar Studio Frequency Waveform edge-to-edge.
/// 2. Jargon De-escalation (Everyday vs Audiophile Pro Mode):
///    - Everyday Mode: Clean, human terms ("Audio Quality", "Full Range 22 kHz").
///    - Audiophile Mode: Exact DSP terms ("Cutoff 16.0 kHz", "Nyquist 24.0 kHz").
///    - Contextual Tooltip: Tap '(i)' to open a friendly 2-line explanation.
/// 3. Real STFT Spectrogram & Detection Center:
///    - Paints the ACTUAL song's computed 32x32 time-frequency STFT matrix in Inferno colormap!
///    - Witty, engaging detection guide (Zero "Paaro", Zero "Desktop scripts").
///    - Syntax-highlighted DIY terminal commands with 1-tap copy.
class AudioSpectrumStage extends StatefulWidget {
  final int score;
  final double cutoffKhz;
  final double maxKhz;
  final String status;
  final String shortBadge;
  final Color statusColor;
  final double height;
  final List<double> spectrumBands;
  final List<List<double>> spectrogramMatrix;
  final int? sampleRate;
  final int? bitDepth;
  final String? verdict;

  const AudioSpectrumStage({
    super.key,
    this.score = 98,
    required this.cutoffKhz,
    required this.maxKhz,
    this.status = 'genuine',
    this.shortBadge = 'GENUINE LOSSLESS',
    required this.statusColor,
    this.height = 140.0,
    this.spectrumBands = const [],
    this.spectrogramMatrix = const [],
    this.sampleRate,
    this.bitDepth,
    this.verdict,
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
      duration: const Duration(milliseconds: 900),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _entryController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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

  void _openForensicModal(BuildContext context) {
    if (appState.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _ForensicSpectrogramModal(
        score: widget.score,
        cutoffKhz: widget.cutoffKhz,
        maxKhz: widget.maxKhz > 0 ? widget.maxKhz : 24.0,
        status: widget.status,
        shortBadge: widget.shortBadge,
        statusColor: widget.statusColor,
        spectrumBands: widget.spectrumBands,
        spectrogramMatrix: widget.spectrogramMatrix,
        sampleRate: widget.sampleRate,
        bitDepth: widget.bitDepth,
        verdict: widget.verdict,
      ),
    );
  }

  void _showExplanationTooltip(BuildContext context, bool isDark, Color textColor, Color subTextColor) {
    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
    final isLossless = widget.status == 'genuine';
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE8141820) : const Color(0xF5FFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.statusColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLossless ? Icons.verified_rounded : Icons.info_outline_rounded,
                        color: widget.statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isLossless ? 'Genuine Lossless Audio' : 'Compressed / Cutoff Audio',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isLossless
                      ? 'This audio file preserves the complete acoustic spectrum without lossy frequency compression. Frequencies extend smoothly past 20 kHz to the recording limit.'
                      : 'This audio file cuts off abruptly around ${widget.cutoffKhz.toStringAsFixed(1)} kHz. In typical MP3/AAC compression, audio above 16-18 kHz is discarded to save file size.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.45,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        color: appState.getAccentColor(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);
        final activeAccent = appState.getAccentColor(context);
        final isPro = appState.audiophileMode;
        final mode = appState.visualizerMode; // 'hybrid', 'gauge', 'waveform'
        final safeMax = widget.maxKhz > 0 ? widget.maxKhz : 24.0;

        return GlassSurface(
          borderRadius: BorderRadius.circular(22),
          style: GlassStyle.frosted,
          borderless: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: AnimatedBuilder(
            animation: Listenable.merge([_entryAnimation, _shimmerController]),
            builder: (context, _) {
              final entryVal = _entryAnimation.value;
              final shimmerVal = _shimmerController.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header Row: Title, Mode Switcher [ ⏱️ | ⚡ | 📊 ], and Deep-Dive Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title + Help Button
                      Row(
                        children: [
                          Icon(
                            mode == 'gauge'
                                ? Icons.speed_rounded
                                : (mode == 'waveform' ? Icons.graphic_eq_rounded : Icons.auto_graph_rounded),
                            size: 16,
                            color: widget.statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPro ? 'Acoustic Spectrum' : 'Audio Quality',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Tap-to-explain info button
                          GestureDetector(
                            onTap: () => _showExplanationTooltip(context, isDark, textColor, subTextColor),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.help_outline_rounded,
                                size: 14,
                                color: subTextColor.withOpacity(0.65),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // View Mode Switcher [ ⏱️ | ⚡ | 📊 ]
                      Container(
                        height: 28,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x20FFFFFF) : const Color(0x12000000),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _modeButton('gauge', Icons.speed_rounded, mode, isDark, activeAccent),
                            _modeButton('hybrid', Icons.electric_bolt_rounded, mode, isDark, activeAccent),
                            _modeButton('waveform', Icons.bar_chart_rounded, mode, isDark, activeAccent),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 2. Visualizer Body (Gauge, Waveform, or Hybrid)
                  _buildVisualizerBody(
                    mode: mode,
                    entryVal: entryVal,
                    shimmerVal: shimmerVal,
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    activeAccent: activeAccent,
                    safeMax: safeMax,
                  ),

                  const SizedBox(height: 10),

                  // 3. Footer Bar: Readout + Full Spectrogram Trigger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Human or Pro Frequency Readout
                      Row(
                        children: [
                          Text(
                            isPro
                                ? 'Cutoff: ${widget.cutoffKhz.toStringAsFixed(1)}k / ${safeMax.toStringAsFixed(0)}k'
                                : (widget.status == 'genuine'
                                    ? 'Full Spectrum (${widget.cutoffKhz.toStringAsFixed(1)} kHz)'
                                    : 'Cut off at ${widget.cutoffKhz.toStringAsFixed(1)} kHz'),
                            style: TextStyle(
                              fontFamily: isPro ? 'JetBrainsMono' : 'Inter',
                              fontSize: 11,
                              fontWeight: isPro ? FontWeight.w700 : FontWeight.w600,
                              color: widget.status == 'genuine' ? activeAccent : widget.statusColor,
                            ),
                          ),
                        ],
                      ),

                      // "Sound Spectrogram & Detection" Action Button
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _openForensicModal(context),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: activeAccent.withOpacity(isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: activeAccent.withOpacity(0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  size: 13,
                                  color: activeAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Sound Spectrogram',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: activeAccent,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 9,
                                  color: activeAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _modeButton(String targetMode, IconData icon, String currentMode, bool isDark, Color activeAccent) {
    final isSelected = currentMode == targetMode;
    return GestureDetector(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
        appState.setVisualizerMode(targetMode);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0x50FFFFFF) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 13,
          color: isSelected ? activeAccent : (isDark ? const Color(0x88FFFFFF) : const Color(0x88000000)),
        ),
      ),
    );
  }

  Widget _buildVisualizerBody({
    required String mode,
    required double entryVal,
    required double shimmerVal,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
    required double safeMax,
  }) {
    if (mode == 'gauge') {
      // Full Speedometer Gauge View
      return SizedBox(
        height: 76,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(76, 76),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: textColor,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        'PURITY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 7.5,
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
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.shortBadge,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: widget.statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.status == 'genuine'
                      ? 'Lossless Acoustic Fidelity'
                      : 'Compression Signature Detected',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (mode == 'waveform') {
      // Full 32-Bar Studio Waveform View
      return SizedBox(
        height: 60,
        child: CustomPaint(
          painter: _StudioWaveformPainter(
            cutoffKhz: widget.cutoffKhz,
            maxKhz: safeMax,
            spectrumBands: widget.spectrumBands,
            entryProgress: entryVal,
            shimmerProgress: shimmerVal,
            statusColor: widget.statusColor,
            isDark: isDark,
            barCount: 32,
          ),
        ),
      );
    } else {
      // Default: Hybrid View (72dp Dial on Left + 16-Bar Waveform on Right)
      return SizedBox(
        height: 68,
        child: Row(
          children: [
            // Left: Dial (~72dp)
            SizedBox(
              width: 70,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(66, 66),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: textColor,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        'PURITY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 7.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Separator
            Container(
              width: 1,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: isDark ? const Color(0x18FFFFFF) : const Color(0x12000000),
            ),

            // Right: 16-Bar Waveform
            Expanded(
              child: CustomPaint(
                painter: _StudioWaveformPainter(
                  cutoffKhz: widget.cutoffKhz,
                  maxKhz: safeMax,
                  spectrumBands: widget.spectrumBands,
                  entryProgress: entryVal,
                  shimmerProgress: shimmerVal,
                  statusColor: widget.statusColor,
                  isDark: isDark,
                  barCount: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Speedometer Gauge Painter: Radial Track with Animated Arc
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
    final strokeWidth = size.width * 0.08;
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = 0.75 * math.pi; // 135 deg
    const sweepTotal = 1.5 * math.pi; // 270 deg

    // 1. Inactive Track
    final trackPaint = Paint()
      ..color = isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // 2. Active Animated Purity Arc
    final sweepProgress = (score / 100.0) * entryProgress * sweepTotal;
    if (sweepProgress > 0) {
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepTotal,
          colors: [
            statusColor.withOpacity(0.5),
            statusColor,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepProgress,
        false,
        activePaint,
      );

      // 3. Glowing Bead at tip
      final tipAngle = startAngle + sweepProgress;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);

      final beadGlow = Paint()
        ..color = statusColor.withOpacity(0.5 + 0.3 * math.sin(shimmerProgress * 2 * math.pi))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 0.75, beadGlow);

      final beadCore = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 0.35, beadCore);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerDialPainter oldDelegate) {
    return oldDelegate.entryProgress != entryProgress ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.score != score;
  }
}

/// Studio Waveform Painter (Supports 16 or 32 bars)
class _StudioWaveformPainter extends CustomPainter {
  final double cutoffKhz;
  final double maxKhz;
  final List<double> spectrumBands;
  final double entryProgress;
  final double shimmerProgress;
  final Color statusColor;
  final bool isDark;
  final int barCount;

  _StudioWaveformPainter({
    required this.cutoffKhz,
    required this.maxKhz,
    required this.spectrumBands,
    required this.entryProgress,
    required this.shimmerProgress,
    required this.statusColor,
    required this.isDark,
    this.barCount = 32,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double barSpacing = barCount == 16 ? 4.5 : 3.0;
    final double totalSpacing = barSpacing * (barCount - 1);
    final double barWidth = ((size.width - totalSpacing) / barCount).clamp(2.0, 16.0);

    final double cutoffRatio = (cutoffKhz / maxKhz).clamp(0.0, 1.0);
    final int cutoffBarIndex = (cutoffRatio * barCount).round().clamp(0, barCount - 1);

    List<double> heights = List.filled(barCount, 0.15);
    if (spectrumBands.isNotEmpty) {
      final int step = math.max(1, spectrumBands.length ~/ barCount);
      for (int i = 0; i < barCount; i++) {
        double sum = 0.0;
        int count = 0;
        for (int k = 0; k < step && (i * step + k) < spectrumBands.length; k++) {
          sum += spectrumBands[i * step + k];
          count++;
        }
        heights[i] = count > 0 ? (sum / count) : 0.2;
      }
    } else {
      for (int i = 0; i < barCount; i++) {
        final r = i / barCount;
        if (r <= cutoffRatio) {
          final naturalCurve = math.cos(r * math.pi * 0.45);
          heights[i] = (naturalCurve * 0.85).clamp(0.15, 0.95);
        } else {
          heights[i] = 0.04;
        }
      }
    }

    final Paint activePaint = Paint()..isAntiAlias = true;
    final Paint cutoffPaint = Paint()..isAntiAlias = true;
    final Paint voidPaint = Paint()..isAntiAlias = true;

    for (int i = 0; i < barCount; i++) {
      final double x = i * (barWidth + barSpacing);
      final bool isPastCutoff = i > cutoffBarIndex;

      final double wave = math.sin((i * 0.4) + (shimmerProgress * 2 * math.pi)) * 0.08;
      double h = (heights[i] + (isPastCutoff ? 0.0 : wave)).clamp(0.06, 1.0);
      h *= entryProgress;

      final double barHeight = (size.height * h).clamp(3.0, size.height);
      final double y = size.height - barHeight;
      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      if (isPastCutoff) {
        voidPaint.color = isDark ? const Color(0x20FFFFFF) : const Color(0x18000000);
        canvas.drawRRect(rrect, voidPaint);
      } else if (i == cutoffBarIndex && cutoffRatio < 0.92) {
        cutoffPaint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [statusColor.withOpacity(0.5), statusColor],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));
        canvas.drawRRect(rrect, cutoffPaint);
      } else {
        final double gradientRatio = i / barCount;
        final Color startColor = isDark ? const Color(0xFF00D2FF) : const Color(0xFF0077CC);
        final Color midColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF00A389);
        final Color endColor = statusColor;

        Color barColor;
        if (gradientRatio < 0.5) {
          barColor = Color.lerp(startColor, midColor, gradientRatio * 2) ?? startColor;
        } else {
          barColor = Color.lerp(midColor, endColor, (gradientRatio - 0.5) * 2) ?? endColor;
        }

        activePaint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [barColor.withOpacity(0.40), barColor],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));
        canvas.drawRRect(rrect, activePaint);
      }
    }

    if (cutoffRatio < 0.92) {
      final double laserX = (cutoffBarIndex * (barWidth + barSpacing)) + (barWidth / 2);
      final Paint laserPaint = Paint()
        ..color = statusColor.withOpacity(0.85)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const double dashHeight = 3.0;
      const double dashSpace = 2.5;
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(laserX, startY),
          Offset(laserX, math.min(startY + dashHeight, size.height)),
          laserPaint,
        );
        startY += dashHeight + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StudioWaveformPainter oldDelegate) {
    return oldDelegate.entryProgress != entryProgress ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.cutoffKhz != cutoffKhz ||
        oldDelegate.barCount != barCount;
  }
}

/// Modal Sheet: Sound Spectrogram (Real PCM Heatmap) & How Detection Works
class _ForensicSpectrogramModal extends StatefulWidget {
  final int score;
  final double cutoffKhz;
  final double maxKhz;
  final String status;
  final String shortBadge;
  final Color statusColor;
  final List<double> spectrumBands;
  final List<List<double>> spectrogramMatrix;
  final int? sampleRate;
  final int? bitDepth;
  final String? verdict;

  const _ForensicSpectrogramModal({
    required this.score,
    required this.cutoffKhz,
    required this.maxKhz,
    required this.status,
    required this.shortBadge,
    required this.statusColor,
    required this.spectrumBands,
    required this.spectrogramMatrix,
    this.sampleRate,
    this.bitDepth,
    this.verdict,
  });

  @override
  State<_ForensicSpectrogramModal> createState() => _ForensicSpectrogramModalState();
}

class _ForensicSpectrogramModalState extends State<_ForensicSpectrogramModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Pill
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x40FFFFFF) : const Color(0x35000000),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.status == 'genuine'
                              ? Icons.verified_rounded
                              : (widget.status == 'suspicious'
                                  ? Icons.warning_amber_rounded
                                  : Icons.cancel_rounded),
                          size: 18,
                          color: widget.statusColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio Deep-Dive',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '${widget.score}% • ${widget.shortBadge}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: widget.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: subTextColor,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Segmented Tab Selector (Rounded Glass Pill)
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x18FFFFFF) : const Color(0x0E000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0x40FFFFFF) : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: textColor,
                  unselectedLabelColor: subTextColor,
                  labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Sound Spectrogram'),
                    Tab(text: 'How Detection Works'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Real STFT Spectrogram Heatmap
                    _buildSpectrogramTab(isDark, textColor, subTextColor, activeAccent),

                    // Tab 2: Engaging How Detection Works
                    _buildDetectionGuideTab(isDark, textColor, subTextColor, activeAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 1: Sound Spectrogram (Real PCM Heatmap)
  Widget _buildSpectrogramTab(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2D Spectrogram Canvas Box
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1117),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x22FFFFFF) : const Color(0x1A000000),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _Spectrogram2dPainter(
                cutoffKhz: widget.cutoffKhz,
                maxKhz: widget.maxKhz,
                spectrumBands: widget.spectrumBands,
                spectrogramMatrix: widget.spectrogramMatrix,
                statusColor: widget.statusColor,
                status: widget.status,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Inferno Colorbar Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '-90 dB (Noise Floor)',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9.5,
                  color: subTextColor,
                ),
              ),
              Container(
                width: 110,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF000004),
                      Color(0xFF420A68),
                      Color(0xFF932667),
                      Color(0xFFDD513A),
                      Color(0xFFFCA50A),
                      Color(0xFFFCFFA4),
                    ],
                  ),
                ),
              ),
              Text(
                '0 dB (Loudest)',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9.5,
                  color: subTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Key Metrics Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill(
                label: 'Acoustic Reach',
                value: '${widget.cutoffKhz.toStringAsFixed(1)} kHz',
                color: widget.statusColor,
                isDark: isDark,
              ),
              _metricPill(
                label: 'Frequency Limit',
                value: '${widget.maxKhz.toStringAsFixed(1)} kHz',
                color: activeAccent,
                isDark: isDark,
              ),
              if (widget.sampleRate != null && widget.sampleRate! > 0)
                _metricPill(
                  label: 'Sample Rate',
                  value: '${(widget.sampleRate! / 1000).toStringAsFixed(1)} kHz',
                  color: activeAccent,
                  isDark: isDark,
                ),
              if (widget.bitDepth != null && widget.bitDepth! > 0)
                _metricPill(
                  label: 'Bit Depth',
                  value: '${widget.bitDepth}-bit',
                  color: activeAccent,
                  isDark: isDark,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Plain-English Verdict Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.statusColor.withOpacity(isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.statusColor.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.status == 'genuine' ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                  size: 16,
                  color: widget.statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.verdict ??
                        (widget.status == 'genuine'
                            ? 'Full audio bandwidth is preserved. No compression cutoff detected.'
                            : 'Audio frequencies drop sharply at ${widget.cutoffKhz} kHz, characteristic of lossy MP3/AAC compression.'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.35,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Tab 2: How Detection Works (No jargon, conversational, DIY instructions)
  Widget _buildDetectionGuideTab(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(
            title: 'The Great "Hi-Res" Scam',
            icon: Icons.search_rounded,
            accent: const Color(0xFFFF9500),
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            content: 'Ever downloaded a 24-bit / 96 kHz FLAC song that secretly sounded like YouTube from 2008? Someone probably took an ordinary 128 kbps MP3, converted it into a FLAC container, and called it a "Studio Master". We expose what is really inside.',
          ),
          const SizedBox(height: 10),
          _infoCard(
            title: 'Why Legacy Audio Tools Fail',
            icon: Icons.shield_outlined,
            accent: const Color(0xFF00D2FF),
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            content: 'Old tools look only at the highest frequency spike. When a lossy MP3 is upsampled to 96 kHz, digital interpolation creates ultrasonic noise above 24 kHz. Old tools mistake this noise for lossless music! Our engine checks the middle frequencies (16-22 kHz) to ensure real musical overtones exist before trusting ultrasonic numbers.',
          ),
          const SizedBox(height: 10),
          _infoCard(
            title: 'Our 4-Point Audio Check',
            icon: Icons.verified_user_outlined,
            accent: const Color(0xFF34C759),
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            content: '1. Frequency Reach: Identifies sharp brickwall dropoffs.\n2. Quantization Holes: Finds empty frequency pockets left by MP3/AAC encoders.\n3. True Bit-Depth: Exposes 16-bit audio padded with zero bytes into a fake 24-bit container.\n4. Acoustic Continuity: Validates harmonic balance across all bands.',
          ),
          const SizedBox(height: 10),
          // DIY Test Box with Copy Terminal Commands
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x10000000),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Text(
                          'Test It Yourself (DIY Challenge)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        const cmd = 'ffmpeg -i song.flac -b:a 128k fake.mp3 && ffmpeg -i fake.mp3 -sample_fmt s32 -ar 96000 fake_hires.flac';
                        Clipboard.setData(const ClipboardData(text: cmd));
                        if (appState.hapticsEnabled) HapticFeedback.lightImpact();
                        showThemedSnackBar(
                          context,
                          'Terminal commands copied to clipboard!',
                          icon: Icons.copy_rounded,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: activeAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Copy',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: activeAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Convert any real song into a fake Hi-Res file and test both in other tools vs this app:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1117),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '# 1. Compress to MP3:\nffmpeg -i song.flac -b:a 128k fake.mp3\n\n# 2. Upscale to 24-bit/96kHz FLAC:\nffmpeg -i fake.mp3 -sample_fmt s32 -ar 96000 fake_hires.flac',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.5,
                      color: Color(0xFF7DD3FC),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _metricPill({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x10000000),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0x99FFFFFF) : const Color(0x88000000),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Color accent,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x10000000),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              height: 1.4,
              color: isDark ? const Color(0xCCFFFFFF) : const Color(0xCC000000),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2D STFT Heatmap Spectrogram CustomPainter (Uses REAL PCM computed matrix when available)
class _Spectrogram2dPainter extends CustomPainter {
  final double cutoffKhz;
  final double maxKhz;
  final List<double> spectrumBands;
  final List<List<double>> spectrogramMatrix;
  final Color statusColor;
  final String status;

  _Spectrogram2dPainter({
    required this.cutoffKhz,
    required this.maxKhz,
    required this.spectrumBands,
    required this.spectrogramMatrix,
    required this.statusColor,
    required this.status,
  });

  Color _infernoColor(double v) {
    final t = v.clamp(0.0, 1.0);
    if (t < 0.25) {
      final f = t / 0.25;
      return Color.lerp(const Color(0xFF000004), const Color(0xFF420A68), f)!;
    } else if (t < 0.50) {
      final f = (t - 0.25) / 0.25;
      return Color.lerp(const Color(0xFF420A68), const Color(0xFF932667), f)!;
    } else if (t < 0.75) {
      final f = (t - 0.50) / 0.25;
      return Color.lerp(const Color(0xFF932667), const Color(0xFFDD513A), f)!;
    } else if (t < 0.90) {
      final f = (t - 0.75) / 0.15;
      return Color.lerp(const Color(0xFFDD513A), const Color(0xFFFCA50A), f)!;
    } else {
      final f = (t - 0.90) / 0.10;
      return Color.lerp(const Color(0xFFFCA50A), const Color(0xFFFCFFA4), f)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double axisLeft = 32.0;
    final double axisBottom = 20.0;
    final double plotWidth = size.width - axisLeft - 8.0;
    final double plotHeight = size.height - axisBottom - 8.0;

    const int timeSlices = 32;
    const int freqBins = 32;

    final double cellW = plotWidth / timeSlices;
    final double cellH = plotHeight / freqBins;
    final double cutoffRatio = (cutoffKhz / maxKhz).clamp(0.0, 1.0);

    final Paint cellPaint = Paint();
    final bool hasRealMatrix = spectrogramMatrix.length >= timeSlices;

    for (int t = 0; t < timeSlices; t++) {
      for (int f = 0; f < freqBins; f++) {
        // f = 0 is highest frequency, f = freqBins-1 is 0 kHz
        final double freqRatio = 1.0 - (f / freqBins);
        double energy;

        if (hasRealMatrix) {
          // Authentic PCM FFT magnitude
          final int binIdx = (freqBins - 1 - f).clamp(0, spectrogramMatrix[t].length - 1);
          energy = spectrogramMatrix[t][binIdx];
        } else {
          // Synthetic fallback
          if (freqRatio > cutoffRatio) {
            energy = 0.02 + (math.Random((t * 31 + f)).nextDouble() * 0.03);
          } else {
            final double baseBand = (1.0 - (freqRatio * 0.65)).clamp(0.15, 0.95);
            final double timeWeight = 0.85 + (math.sin(t * 0.35) * 0.15);
            energy = (baseBand * timeWeight).clamp(0.05, 0.98);
          }
        }

        cellPaint.color = _infernoColor(energy);
        final rect = Rect.fromLTWH(
          axisLeft + (t * cellW),
          8.0 + (f * cellH),
          cellW + 0.5,
          cellH + 0.5,
        );
        canvas.drawRect(rect, cellPaint);
      }
    }

    final double cutoffY = 8.0 + (plotHeight * (1.0 - cutoffRatio));
    final double cdRatio = (20.0 / maxKhz).clamp(0.0, 1.0);
    final double cdY = 8.0 + (plotHeight * (1.0 - cdRatio));

    // Studio CD Reference Line (20 kHz Dotted Cyan)
    final Paint cdPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    double startX = axisLeft;
    while (startX < axisLeft + plotWidth) {
      canvas.drawLine(
        Offset(startX, cdY),
        Offset(math.min(startX + 4, axisLeft + plotWidth), cdY),
        cdPaint,
      );
      startX += 7;
    }

    // Dead Zone Hatched Overlay if cutoff is below Nyquist
    if (cutoffRatio < 0.92) {
      final deadZoneRect = Rect.fromLTWH(axisLeft, 8.0, plotWidth, cutoffY - 8.0);
      canvas.drawRect(deadZoneRect, Paint()..color = const Color(0x33FF3B30));

      final Paint hatchPaint = Paint()
        ..color = const Color(0x44FF3B30)
        ..strokeWidth = 1.0;
      for (double d = -deadZoneRect.height; d < deadZoneRect.width; d += 14) {
        canvas.drawLine(
          Offset(axisLeft + math.max(0.0, d), 8.0),
          Offset(axisLeft + math.min(plotWidth, d + deadZoneRect.height), cutoffY),
          hatchPaint,
        );
      }

      final Paint cutoffLinePaint = Paint()
        ..color = const Color(0xFFFF3B30)
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(axisLeft, cutoffY), Offset(axisLeft + plotWidth, cutoffY), cutoffLinePaint);

      final tp = TextPainter(
        text: const TextSpan(
          text: '[!] MISSING FREQUENCIES (DEAD ZONE)',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFF9999),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tagX = axisLeft + (plotWidth - tp.width) / 2;
      final tagY = math.max(12.0, (8.0 + cutoffY) / 2 - 7);
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagX - 5, tagY - 2, tp.width + 10, tp.height + 4),
        const Radius.circular(5),
      );
      canvas.drawRRect(bgRect, Paint()..color = const Color(0xE6260000));
      tp.paint(canvas, Offset(tagX, tagY));
    }

    final labelStyle = const TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 8.5,
      color: Color(0xAAFFFFFF),
    );

    _drawText(canvas, '${maxKhz.toStringAsFixed(0)}k', Offset(2, 6), labelStyle);
    if (maxKhz > 22) {
      _drawText(canvas, '20k', Offset(2, cdY - 5), labelStyle);
    }
    _drawText(canvas, '${cutoffKhz.toStringAsFixed(0)}k', Offset(2, cutoffY - 5), labelStyle.copyWith(color: statusColor, fontWeight: FontWeight.w700));
    _drawText(canvas, '0k', Offset(6, 8.0 + plotHeight - 10), labelStyle);

    final timeStyle = const TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 8.5,
      color: Color(0x88FFFFFF),
    );
    _drawText(canvas, '0s', Offset(axisLeft, size.height - 14), timeStyle);
    _drawText(canvas, '15s', Offset(axisLeft + (plotWidth / 2) - 8, size.height - 14), timeStyle);
    _drawText(canvas, '30s', Offset(axisLeft + plotWidth - 18, size.height - 14), timeStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _Spectrogram2dPainter oldDelegate) {
    return oldDelegate.cutoffKhz != cutoffKhz ||
        oldDelegate.maxKhz != maxKhz ||
        oldDelegate.status != status ||
        oldDelegate.spectrogramMatrix != spectrogramMatrix;
  }
}
