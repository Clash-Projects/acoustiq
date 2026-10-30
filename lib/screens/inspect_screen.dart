import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';

/// 1:1 Port of LastWave Studio-Grade Audio Inspector Architecture
///
/// Features:
/// - Replaces arcade speedometer arc with bold studio typography and Nyquist spectrum bar.
/// - Pure pitch black AMOLED canvas with ZERO border outlines.
/// - Connected Group Architecture for detailed technical stream metadata.
/// - 140dp bottom padding clearance ensuring seamless dock scrolling.
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
          backgroundColor: isDark ? AppColors.amoledCanvas : AppColors.lightCanvas,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header
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

                  // 1. Studio Audio Hero Stage (Single Sculpted Obsidian Surface, Zero Borders)
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
    final cardBg = isDark ? AppColors.surfaceContainer : AppColors.lightSurface;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: _isLoading ? null : _pickAndAnalyzeFile,
        borderRadius: BorderRadius.circular(28),
        splashColor: AppColors.accentPrimary.withOpacity(0.10),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Row (Pick File)
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE0F7FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            _info != null ? Icons.audio_file_rounded : Icons.file_upload_outlined,
                            size: 24,
                            color: AppColors.accentPrimary,
                          ),
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _info != null
                              ? (_info!.artist.isNotEmpty
                                  ? '${_info!.artist} • ${_info!.album}'
                                  : _info!.filePath.split('/').last)
                              : 'Tap to inspect lossless audio authenticity & Nyquist cutoff',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: subTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222222) : const Color(0xFFECECEF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _info != null ? 'Change' : 'Browse',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),

              if (_info != null) ...[
                const SizedBox(height: 24),

                // Typographic Purity Score Stage
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_info!.score}',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -1.2,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Status Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
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
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Studio Frequency Spectrum Nyquist Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cutoff: ${_info!.cutoffKhz.toStringAsFixed(1)} kHz',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                        ),
                        Text(
                          'Nyquist Limit: ${_info!.maxKhz.toStringAsFixed(1)} kHz',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFE2E2E6),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_info!.cutoffKhz / (_info!.maxKhz > 0 ? _info!.maxKhz : 22.05))
                              .clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4 Clean Spec Pills
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

  Widget _buildSpecTile(String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF1F1F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : const Color(0x80000000),
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
                color: isDark ? Colors.white : Colors.black87,
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
