import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Studio-Grade Audio Inspector Architecture
///
/// Features:
/// - Restores embedded album cover artwork (72dp continuous squircle).
/// - Studio Spectral Nyquist Analyzer (multi-band dynamic audio frequency stage).
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - Zero text truncation with natural soft-wrapping.
/// - 140dp bottom clearance.
class InspectScreen extends StatefulWidget {
  final FlacInfo? initialTrack;

  const InspectScreen({super.key, this.initialTrack});

  @override
  State<InspectScreen> createState() => _InspectScreenState();
}

class _InspectScreenState extends State<InspectScreen>
    with SingleTickerProviderStateMixin {
  FlacInfo? _info;
  bool _isLoading = false;
  late AnimationController _spectrumAnimController;

  @override
  void initState() {
    super.initState();
    _info = widget.initialTrack;
    _spectrumAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spectrumAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['flac'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final analyzed = await FlacParser.analyzeFile(path);
        setState(() {
          _info = analyzed;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error choosing file: $e'),
            backgroundColor: AppColors.fakeCoral,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'genuine':
        return AppColors.genuineEmerald;
      case 'suspicious':
        return AppColors.suspiciousAmber;
      default:
        return AppColors.fakeCoral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        return Scaffold(
          backgroundColor: appState.getBgColor(context),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Title
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
                    child: Text(
                      'Inspect',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: textColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 1. Studio Audio Hero Stage (Artwork + Spectrogram + Wavy Verified Seal)
                  _buildStudioHeroStage(isDark, textColor, subTextColor),

                  const SizedBox(height: 18),

                  // 2. Technical Stream Specifications (Connected Group)
                  if (_info != null) ...[
                    buildSectionHeader('Stream Telemetry & Integrity', subTextColor),
                    _buildStreamTelemetryGroup(isDark, textColor, subTextColor),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudioHeroStage(bool isDark, Color textColor, Color subTextColor) {
    final statusColor = _info != null ? _getStatusColor(_info!.status) : AppColors.accentPrimary;
    final cardBg = appState.getCardBgColor(context);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(28),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: _isLoading ? null : _pickAndAnalyzeFile,
        borderRadius: BorderRadius.circular(28),
        splashColor: AppColors.accentPrimary.withOpacity(0.10),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Row (Embedded Artwork + File Title & Action)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 72dp Continuous Squircle Album Cover Artwork
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          )
                        : (_info != null && _info!.hasCover && _info!.coverBytes != null
                            ? Image.memory(
                                _info!.coverBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _fallbackArtwork(statusColor),
                              )
                            : _fallbackArtwork(statusColor)),
                  ),
                  const SizedBox(width: 14),
                  // Title & Subtitle with Soft Multiline Wrapping (No truncation)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _info != null
                              ? (_info!.title.isNotEmpty ? _info!.title : _info!.fileName)
                              : 'Select FLAC Track',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          maxLines: 2,
                          softWrap: true,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _info != null
                              ? (_info!.artist.isNotEmpty
                                  ? '${_info!.artist} • ${_info!.album}'
                                  : _info!.filePath.split('/').last)
                              : 'Tap to inspect lossless audio authenticity, embedded artwork & Nyquist cutoff',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.3,
                            color: subTextColor,
                          ),
                          maxLines: 2,
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222222) : const Color(0xFFECECEF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _info != null ? 'Change' : 'Browse',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),

              if (_info != null) ...[
                const SizedBox(height: 22),

                // 2. Score Row with Wavy Circle Verified Seal
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Score with baseline %
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_info!.score}',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -1.2,
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 14),

                    // Iconic Wavy Circle Verified Seal & Status Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? statusColor.withOpacity(0.14)
                              : (statusColor == AppColors.genuineEmerald
                                  ? AppColors.lightEmeraldPillBg
                                  : (statusColor == AppColors.suspiciousAmber
                                      ? AppColors.lightAmberPillBg
                                      : AppColors.lightCoralPillBg)),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _info!.status == 'genuine'
                                  ? Icons.verified_rounded
                                  : (_info!.status == 'suspicious'
                                      ? Icons.warning_amber_rounded
                                      : Icons.cancel_rounded),
                              size: 18,
                              color: isDark
                                  ? statusColor
                                  : (statusColor == AppColors.genuineEmerald
                                      ? AppColors.lightEmeraldText
                                      : (statusColor == AppColors.suspiciousAmber
                                          ? AppColors.lightAmberText
                                          : AppColors.lightCoralText)),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _info!.status == 'genuine'
                                    ? 'GENUINE LOSSLESS'
                                    : (_info!.status == 'suspicious'
                                        ? 'SUSPECT CUTOFF'
                                        : 'LOSSY TRANSCODE'),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isDark
                                      ? statusColor
                                      : (statusColor == AppColors.genuineEmerald
                                          ? AppColors.lightEmeraldText
                                          : (statusColor == AppColors.suspiciousAmber
                                              ? AppColors.lightAmberText
                                              : AppColors.lightCoralText)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Pro Studio Spectral Nyquist Analyzer Stage (Multi-band Frequency Canvas)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F1F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.graphic_eq_rounded, size: 14, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                'Cutoff: ${_info!.cutoffKhz.toStringAsFixed(1)} kHz',
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
                            'Nyquist: ${_info!.maxKhz.toStringAsFixed(1)} kHz',
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
                      // Animated Spectrogram Canvas
                      SizedBox(
                        height: 38,
                        child: AnimatedBuilder(
                          animation: _spectrumAnimController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _AudioSpectrumPainter(
                                cutoffRatio: (_info!.cutoffKhz / (_info!.maxKhz > 0 ? _info!.maxKhz : 22.05))
                                    .clamp(0.0, 1.0),
                                statusColor: statusColor,
                                animProgress: _spectrumAnimController.value,
                                isDark: isDark,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. Clean High-Contrast Spec Pills
                Row(
                  children: [
                    _buildSpecTile('${_info!.bitDepth}-bit', 'Depth', isDark),
                    const SizedBox(width: 6),
                    _buildSpecTile('${(_info!.sampleRate / 1000).toStringAsFixed(1)} kHz', 'Sampling', isDark),
                    const SizedBox(width: 6),
                    _buildSpecTile('${_info!.bitrateKbps} kbps', 'Bitrate', isDark),
                    const SizedBox(width: 6),
                    _buildSpecTile('${_info!.fileSizeMb.toStringAsFixed(1)} MB', 'Size', isDark),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackArtwork(Color statusColor) {
    return Container(
      color: statusColor.withOpacity(0.12),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 34,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildSpecTile(String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF0F0F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamTelemetryGroup(bool isDark, Color textColor, Color subTextColor) {
    if (_info == null) return const SizedBox.shrink();

    final rows = [
      (
        icon: Icons.verified_user_rounded,
        iconColor: AppColors.genuineEmerald,
        iconBg: isDark ? const Color(0xFF142B1F) : const Color(0xFFDCFCE7),
        title: 'Encoding & Analysis Verdict',
        subtitle: _info!.verdict,
        trailing: Text(
          _info!.status == 'genuine' ? 'Lossless' : 'Transcode',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _info!.status == 'genuine'
                ? AppColors.genuineEmerald
                : AppColors.fakeCoral,
          ),
        ),
      ),
      (
        icon: Icons.graphic_eq_rounded,
        iconColor: AppColors.accentPrimary,
        iconBg: isDark ? const Color(0xFF162B38) : const Color(0xFFE0F7FE),
        title: 'Channels & Audio Subframes',
        subtitle: '${_info!.channels == 2 ? 'Stereo (2.0)' : 'Mono'} • FLAC Lossless Stream',
        trailing: Text(
          '${_info!.channels} ch',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: subTextColor,
          ),
        ),
      ),
      (
        icon: Icons.timer_outlined,
        iconColor: const Color(0xFFA78BFA),
        iconBg: isDark ? const Color(0xFF261D3B) : const Color(0xFFEDE9FE),
        title: 'Track Duration & Bitrate',
        subtitle: '${_info!.bitrateKbps} kbps average streaming rate',
        trailing: Text(
          _info!.durationStr,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
      (
        icon: Icons.folder_open_rounded,
        iconColor: AppColors.suspiciousAmber,
        iconBg: isDark ? const Color(0xFF332714) : const Color(0xFFFEF3C7),
        title: 'Storage Path',
        subtitle: _info!.filePath,
        trailing: null,
      ),
    ];

    return ExpressiveGroup(
      rowCount: rows.length,
      itemBuilder: (context, index, position) {
        final r = rows[index];
        return ExpressiveGroupRow(
          icon: r.icon,
          iconColor: r.iconColor,
          iconBgColor: r.iconBg,
          title: r.title,
          subtitle: r.subtitle,
          position: position,
          trailing: r.trailing,
        );
      },
    );
  }
}

/// Custom Spectrogram Visualizer Canvas with Nyquist Cutoff Line
class _AudioSpectrumPainter extends CustomPainter {
  final double cutoffRatio;
  final Color statusColor;
  final double animProgress;
  final bool isDark;

  _AudioSpectrumPainter({
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
      ..color = isDark ? const Color(0xFF242424) : const Color(0xFFDCDCE0);

    for (int i = 0; i < barCount; i++) {
      // Harmonic wave shape
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
            statusColor.withOpacity(0.55),
            statusColor,
          ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));
        canvas.drawRRect(barRect, activePaint);
      } else {
        canvas.drawRRect(barRect, inactivePaint);
      }
    }

    // Cutoff Laser Line Marker
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
  bool shouldRepaint(covariant _AudioSpectrumPainter oldDelegate) {
    return oldDelegate.cutoffRatio != cutoffRatio ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.isDark != isDark;
  }
}
