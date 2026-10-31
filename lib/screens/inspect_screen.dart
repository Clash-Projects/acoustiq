import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/audio_spectrum_stage.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Studio-Grade Audio Inspector Architecture
///
/// Features:
/// - Borderless AMOLED / Light mode container (zero cartoon box strokes).
/// - Embedded album cover artwork (72dp continuous squircle).
/// - Studio Spectral Nyquist Analyzer Stage (32-band real-time audio frequency visualizer).
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - Concise studio-grade badges that never truncate.
/// - 160dp bottom clearance (guarantees floating dock never obstructs content).
class InspectScreen extends StatefulWidget {
  final FlacInfo? initialTrack;

  const InspectScreen({super.key, this.initialTrack});

  @override
  State<InspectScreen> createState() => _InspectScreenState();
}

class _InspectScreenState extends State<InspectScreen> {
  FlacInfo? _info;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _info = widget.initialTrack;
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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

                  // 1. Studio Audio Hero Stage (Zero-Border Architecture)
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

    return LuminousFeedback(
      onTap: _isLoading ? null : _pickAndAnalyzeFile,
      variant: _info?.status == 'genuine' ? LuminousVariant.emerald : LuminousVariant.cyan,
      borderRadius: BorderRadius.circular(28),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        style: GlassStyle.frosted,
        borderless: true, // ZERO BORDERS matching LastWave!
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
                    color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isDark
                        ? AppColors.softElevation(elevation: 3.0)
                        : AppColors.lightSoftElevation(elevation: 3.0),
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
                // Title & Subtitle with Clean Wrapping
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _info != null
                            ? (_info!.artist.isNotEmpty
                                ? '${_info!.artist} • ${_info!.album}'
                                : _info!.filePath.split('/').last)
                            : 'Tap to inspect lossless audio authenticity, embedded artwork & Nyquist cutoff',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.35,
                          color: subTextColor,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GlassSurface(
                  borderRadius: BorderRadius.circular(12),
                  style: GlassStyle.clear,
                  borderless: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    _info != null ? 'Change' : 'Browse',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),

            if (_info != null) ...[
              const SizedBox(height: 20),

              // 2. Score Row with Wavy Circle Verified Seal & Concise Badge (No Truncation)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Concise Studio Badge (Fits cleanly in 1 line with no truncation)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _info!.status == 'genuine'
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _info!.shortBadge,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: statusColor,
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

              const SizedBox(height: 14),

              // 3. Pro Studio Spectral Nyquist Analyzer Stage
              AudioSpectrumStage(
                cutoffKhz: _info!.cutoffKhz,
                maxKhz: _info!.maxKhz,
                statusColor: statusColor,
                height: 42,
              ),

              // Detailed explanation text under spectrum
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  _info!.verdict,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    height: 1.3,
                    color: subTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 12),

              // 4. Clean High-Contrast Spec Pills in Clear Glass (Zero Borders)
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
    );
  }

  Widget _fallbackArtwork(Color statusColor) {
    return Center(
      child: Icon(
        Icons.album_rounded,
        size: 34,
        color: statusColor,
      ),
    );
  }

  Widget _buildSpecTile(String value, String label, bool isDark) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(14),
        style: GlassStyle.clear,
        borderless: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
        iconBg: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
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
        iconBg: isDark ? const Color(0x3000D2FF) : const Color(0xFFE0F7FE),
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
        iconBg: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
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
        iconBg: isDark ? const Color(0x30FFB300) : const Color(0xFFFEF3C7),
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
