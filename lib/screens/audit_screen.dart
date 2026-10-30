import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/score_gauge.dart';

/// 1:1 Port of LastWave's Mix & Track List Stage for FLAC Audio Auditing
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  bool _isScanning = false;
  int _scannedCount = 0;
  String _filter = 'all'; // 'all', 'genuine', 'suspicious', 'fake'

  @override
  void initState() {
    super.initState();
    _scannedCount = appState.sharedLibrary.length;
  }

  Future<void> _scanFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    setState(() {
      _isScanning = true;
      _scannedCount = 0;
    });

    final List<FlacInfo> newTracks = [];

    try {
      final dir = Directory(dirPath);
      final List<File> flacFiles = [];

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.flac')) {
          flacFiles.add(entity);
        }
      }

      for (final file in flacFiles) {
        final info = await FlacParser.analyzeFile(file.path);
        newTracks.add(info);
        if (mounted) {
          setState(() {
            _scannedCount++;
          });
        }
      }

      appState.setSharedLibrary(newTracks, dirPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: AppColors.fakeCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _openTrackDetail(FlacInfo track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TrackDetailModal(track: track),
    );
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

        final tracks = appState.sharedLibrary;
        final filteredTracks = _filter == 'all'
            ? tracks
            : tracks.where((t) => t.status == _filter).toList();

        final genuineCount = tracks.where((t) => t.status == 'genuine').length;
        final suspiciousCount = tracks.where((t) => t.status == 'suspicious').length;
        final fakeCount = tracks.where((t) => t.status == 'fake').length;

        int averageScore = 0;
        if (tracks.isNotEmpty) {
          final total = tracks.fold<int>(0, (sum, item) => sum + item.score);
          averageScore = (total / tracks.length).round();
        }

        return Column(
          children: [
            // 1. LastWave Expressive Hero Stage (32dp Continuous Curvature)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _buildHeroStage(
                tracksCount: tracks.length,
                genuineCount: genuineCount,
                suspiciousCount: suspiciousCount,
                fakeCount: fakeCount,
                averageScore: averageScore,
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
            ),

            const SizedBox(height: 8),

            // 2. LastWave Unified Content Stage (28dp Top Corners)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildListContainer(
                  tracks: filteredTracks,
                  totalTracks: tracks.length,
                  genuineCount: genuineCount,
                  suspiciousCount: suspiciousCount,
                  fakeCount: fakeCount,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 1:1 Port of LastWave's StatsCard Hero Stage
  Widget _buildHeroStage({
    required int tracksCount,
    required int genuineCount,
    required int suspiciousCount,
    required int fakeCount,
    required int averageScore,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
        borderRadius: ExpressiveShapes.hero,
        border: Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 0.5,
        ),
        boxShadow: AppColors.softElevation(elevation: 4.0),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Inner Hero Surface (24dp HeroInnerShape)
          Material(
            color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceLow,
            borderRadius: ExpressiveShapes.heroInner,
            child: InkWell(
              onTap: _isScanning ? null : _scanFolder,
              borderRadius: ExpressiveShapes.heroInner,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: ExpressiveShapes.heroInner,
                  border: Border.all(
                    color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$tracksCount',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'FLACs Audited',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isScanning
                                ? 'Scanning... inspected $_scannedCount tracks'
                                : appState.lastScannedFolder != null
                                    ? appState.lastScannedFolder!.split('/').last
                                    : 'Tap to select a music directory to batch audit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: subTextColor,
                            ),
                          ),
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
                        color: AppColors.accentPrimary.withOpacity(isDark ? 0.20 : 0.14),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.accentPrimary,
                                ),
                              )
                            : const Icon(
                                Icons.folder_special_rounded,
                                color: AppColors.accentPrimary,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 4 Telemetry Pills Row (16dp StatPillShape)
          Row(
            children: [
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Genuine',
                  value: '$genuineCount',
                  color: AppColors.genuineEmerald,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Suspect',
                  value: '$suspiciousCount',
                  color: AppColors.suspiciousAmber,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Fake',
                  value: '$fakeCount',
                  color: AppColors.fakeCoral,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Avg Score',
                  value: '$averageScore%',
                  color: AppColors.accentPrimary,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPill({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceLow,
        borderRadius: ExpressiveShapes.statPill,
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0x99FFFFFF),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 1:1 Port of LastWave's ListContainerShape Stage
  Widget _buildListContainer({
    required List<FlacInfo> tracks,
    required int totalTracks,
    required int genuineCount,
    required int suspiciousCount,
    required int fakeCount,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLow : AppColors.lightSurface,
        borderRadius: ExpressiveShapes.listContainer,
        border: Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterPill('All ($totalTracks)', 'all', isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('Genuine ($genuineCount)', 'genuine', isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('Suspect ($suspiciousCount)', 'suspicious', isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('Fake ($fakeCount)', 'fake', isDark),
                ],
              ),
            ),
          ),

          Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),

          // Tracks List
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_music_rounded,
                          size: 42,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          totalTracks == 0 ? 'No folder scanned yet' : 'No tracks match filter',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalTracks == 0
                              ? 'Tap the folder button above to audit audio files'
                              : 'Select another filter chip above',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final statusColor = _getStatusColor(track.status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isDark ? AppColors.surfaceContainer : AppColors.lightSurfaceLow,
                          borderRadius: ExpressiveShapes.trackRow,
                          child: InkWell(
                            onTap: () => _openTrackDetail(track),
                            borderRadius: ExpressiveShapes.trackRow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: ExpressiveShapes.trackRow,
                                border: Border.all(
                                  color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Artwork Thumbnail (14dp ArtworkShape)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh,
                                      borderRadius: ExpressiveShapes.artwork,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: track.hasCover && track.coverBytes != null
                                        ? Image.memory(
                                            track.coverBytes!,
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
                                          track.title.isNotEmpty ? track.title : track.fileName,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.artist.isNotEmpty
                                              ? '${track.artist} • ${track.album}'
                                              : track.fileName,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: subTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            _buildBadge('${track.bitDepth}-bit', isDark),
                                            const SizedBox(width: 5),
                                            _buildBadge('${(track.sampleRate / 1000).toStringAsFixed(1)}k', isDark),
                                            const SizedBox(width: 5),
                                            _buildBadge('${track.bitrateKbps} kbps', isDark),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Score & Purity Indicator Dot
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: statusColor,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${track.score}%',
                                            style: TextStyle(
                                              fontFamily: 'JetBrainsMono',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${track.cutoffKhz.toStringAsFixed(1)} kHz',
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 9.5,
                                          color: subTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _filter == value;
    final activeBg = AppColors.accentPrimary.withOpacity(isDark ? 0.25 : 0.18);

    return Material(
      color: isSelected ? activeBg : (isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceLow),
      borderRadius: ExpressiveShapes.badgePill,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: ExpressiveShapes.badgePill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: ExpressiveShapes.badgePill,
            border: Border.all(
              color: isSelected
                  ? AppColors.accentPrimary.withOpacity(0.45)
                  : (isDark ? AppColors.darkHairline : AppColors.lightHairline),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.accentPrimary)
                  : (isDark ? const Color(0xB3FFFFFF) : const Color(0x99000000)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh,
        borderRadius: ExpressiveShapes.badgePill,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Color(0xB3FFFFFF),
        ),
      ),
    );
  }

  Widget _fallbackCover(Color accent) {
    return Center(
      child: Icon(Icons.music_note_rounded, size: 22, color: accent.withOpacity(0.8)),
    );
  }
}

/// LastWave-Style Modal Bottom Sheet with Frosted Glass & Nyquist Analysis
class _TrackDetailModal extends StatelessWidget {
  final FlacInfo track;

  const _TrackDetailModal({required this.track});

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xB3FFFFFF) : const Color(0x99000000);

    final statusColor = track.status == 'genuine'
        ? AppColors.genuineEmerald
        : (track.status == 'suspicious' ? AppColors.suspiciousAmber : AppColors.fakeCoral);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 0.5,
        ),
        boxShadow: AppColors.softElevation(elevation: 12.0),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Artwork & Title
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh,
                  borderRadius: ExpressiveShapes.artwork,
                ),
                clipBehavior: Clip.antiAlias,
                child: track.hasCover && track.coverBytes != null
                    ? Image.memory(track.coverBytes!, fit: BoxFit.cover)
                    : Icon(Icons.music_note_rounded, size: 28, color: statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title.isNotEmpty ? track.title : track.fileName,
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
                      track.artist.isNotEmpty ? track.artist : 'Unknown Artist',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.filePath,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: subTextColor.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Embedded Score Gauge
          ScoreGauge(
            score: track.score,
            status: track.status,
            cutoffKhz: track.cutoffKhz,
            maxKhz: track.maxKhz,
          ),

          const SizedBox(height: 16),

          // Verdict Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: ExpressiveShapes.statPill,
              border: Border.all(color: statusColor.withOpacity(0.35), width: 0.5),
            ),
            child: Row(
              children: [
                Icon(
                  track.status == 'genuine' ? Icons.verified_rounded : Icons.warning_rounded,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    track.verdict,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
