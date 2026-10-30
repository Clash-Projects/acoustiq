import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/score_gauge.dart';

/// 1:1 Port of LastWave's Hero Stage & Unified Analysis Architecture
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

        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. LastWave Expressive Hero Stage (32dp Continuous Curvature)
              _buildHeroStage(isDark, textColor, subTextColor),

              const SizedBox(height: 14),

              // 2. LastWave Unified Content Container (28dp Top Continuous Radius)
              _buildContentContainer(isDark, textColor, subTextColor),
            ],
          ),
        );
      },
    );
  }

  /// 1:1 Port of LastWave's StatsCard Hero Stage
  Widget _buildHeroStage(bool isDark, Color textColor, Color subTextColor) {
    final statusColor = _info != null ? _getStatusColor(_info!.status) : AppColors.accentPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
        borderRadius: ExpressiveShapes.hero,
        border: Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 0.5,
        ),
        boxShadow: AppColors.softElevation(elevation: 5.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Inner Hero Surface (24dp HeroInnerShape)
          Material(
            color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceLow,
            borderRadius: ExpressiveShapes.heroInner,
            child: InkWell(
              onTap: _isLoading ? null : _pickAndAnalyzeFile,
              borderRadius: ExpressiveShapes.heroInner,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: ExpressiveShapes.heroInner,
                  border: Border.all(
                    color: _info != null
                        ? statusColor.withOpacity(0.35)
                        : (isDark ? AppColors.darkHairline : AppColors.lightHairline),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_info != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${_info!.score}',
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.0,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '%',
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.16),
                                    borderRadius: ExpressiveShapes.badgePill,
                                  ),
                                  child: Text(
                                    _info!.status.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _info!.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _info!.verdict,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: subTextColor,
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Icon(Icons.waves_rounded, color: AppColors.accentPrimary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Select FLAC File',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap here to browse lossless audio and analyze spectral authenticity',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action Pill Button (46dp circle)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(isDark ? 0.22 : 0.16),
                        border: Border.all(color: statusColor.withOpacity(0.40), width: 0.8),
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: statusColor,
                                ),
                              )
                            : Icon(
                                _info == null
                                    ? Icons.folder_open_rounded
                                    : Icons.sync_rounded,
                                color: statusColor,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Quick Telemetry Pills (16dp StatPillShape)
          Row(
            children: [
              Expanded(
                child: _buildStatPill(
                  label: 'Bit Depth',
                  value: _info != null ? '${_info!.bitDepth}-bit' : '--',
                  highlight: _info != null && _info!.isFake24 ? AppColors.fakeCoral : null,
                  isDark: isDark,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatPill(
                  label: 'Sample Rate',
                  value: _info != null ? '${(_info!.sampleRate / 1000).toStringAsFixed(1)} kHz' : '--',
                  isDark: isDark,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatPill(
                  label: 'Bitrate',
                  value: _info != null ? '${_info!.bitrateKbps} kbps' : '--',
                  isDark: isDark,
                  textColor: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    Color? highlight,
    required bool isDark,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceLow,
        borderRadius: ExpressiveShapes.statPill,
        border: Border.all(
          color: highlight != null
              ? highlight.withOpacity(0.4)
              : (isDark ? AppColors.darkHairline : AppColors.lightHairline),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlight ?? textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 1:1 Port of LastWave's Continuous ListContainerShape Stage
  Widget _buildContentContainer(bool isDark, Color textColor, Color subTextColor) {
    if (_info == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceLow : AppColors.lightSurface,
          borderRadius: ExpressiveShapes.listContainer,
          border: Border.all(
            color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 46,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 14),
              Text(
                'No FLAC file selected',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the card above to inspect audio spectrogram & Nyquist cutoff',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: subTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statusColor = _getStatusColor(_info!.status);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLow : AppColors.lightSurface,
        borderRadius: ExpressiveShapes.listContainer,
        border: Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spectrogram & Analysis',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: ExpressiveShapes.badgePill,
                  border: Border.all(color: statusColor.withOpacity(0.35), width: 0.5),
                ),
                child: Text(
                  '${_info!.cutoffKhz.toStringAsFixed(1)} kHz CUTOFF',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Embedded Nyquist Arc / Spectrum Meter
          Center(
            child: ScoreGauge(
              score: _info!.score,
              status: _info!.status,
              cutoffKhz: _info!.cutoffKhz,
              maxKhz: _info!.maxKhz,
            ),
          ),

          const SizedBox(height: 14),

          // File & Metadata Track Row (18dp TrackRowShape)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainer : AppColors.lightSurfaceLow,
              borderRadius: ExpressiveShapes.trackRow,
              border: Border.all(
                color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Artwork thumbnail (14dp ArtworkShape)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh,
                    borderRadius: ExpressiveShapes.artwork,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _info!.hasCover && _info!.coverBytes != null
                      ? Image.memory(
                          _info!.coverBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackCover(statusColor),
                        )
                      : _fallbackCover(statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _info!.title.isNotEmpty ? _info!.title : _info!.fileName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _info!.artist.isNotEmpty ? _info!.artist : 'Unknown Artist',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildFormatBadge('${_info!.fileSizeMb.toStringAsFixed(1)} MB', isDark),
                          const SizedBox(width: 6),
                          _buildFormatBadge(_info!.durationStr, isDark),
                          const SizedBox(width: 6),
                          _buildFormatBadge('${_info!.channels}ch', isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Detailed Audio Specs Row (18dp TrackRowShape)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainer : AppColors.lightSurfaceLow,
              borderRadius: ExpressiveShapes.trackRow,
              border: Border.all(
                color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                _buildSpecTile('Nyquist Max Frequency', '${_info!.maxKhz.toStringAsFixed(1)} kHz', textColor, subTextColor),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 14),
                _buildSpecTile('High-Frequency Cutoff', '${_info!.cutoffKhz.toStringAsFixed(1)} kHz', textColor, subTextColor),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 14),
                _buildSpecTile(
                  '24-Bit Authenticity',
                  _info!.isFake24 ? 'Suspect (Padded 16-bit noise floor)' : 'Genuine dynamic range',
                  _info!.isFake24 ? AppColors.fakeCoral : AppColors.genuineEmerald,
                  subTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecTile(String label, String value, Color valColor, Color labelColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh,
        borderRadius: ExpressiveShapes.badgePill,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Color(0xB3FFFFFF),
        ),
      ),
    );
  }

  Widget _fallbackCover(Color accent) {
    return Center(
      child: Icon(Icons.music_note_rounded, size: 26, color: accent.withOpacity(0.8)),
    );
  }
}
