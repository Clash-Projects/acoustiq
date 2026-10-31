import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../widgets/audio_spectrum_stage.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Native's Mix & Track List Stage for FLAC Audio Auditing
///
/// Features:
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - WWDC25 Frosted & Clear Glass surfaces across hero cards, stat pills, and filters.
/// - Rich Studio Spectral Nyquist Analyzer Stage inside song details modal bottom sheet.
/// - Multi-line title wrapping for long track names.
/// - Luminous emerald touch feedback ripple across track items.
/// - 160dp bottom padding clearance.
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

        return Scaffold(
          backgroundColor: appState.getBgColor(context),
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Top Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 4),
                    child: Text(
                      'Audit Library',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                // 2. Hero Stage (Frosted Glass Substrate)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                ),

                // 3. Filter Chips Row (Clear Glass Pills)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterPill('All (${tracks.length})', 'all', isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Genuine ($genuineCount)', 'genuine', isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Suspect ($suspiciousCount)', 'suspicious', isDark),
                          const SizedBox(width: 8),
                          _buildFilterPill('Fake ($fakeCount)', 'fake', isDark),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Seamless Transparent Track Rows with Luminous Feedback
                if (filteredTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.library_music_outlined,
                              size: 44,
                              color: isDark ? const Color(0x40FFFFFF) : AppColors.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              tracks.isEmpty
                                  ? 'No FLAC files audited yet\nTap the hero card above to scan a music directory'
                                  : 'No tracks match current filter',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = filteredTracks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTransparentTrackRow(
                              track: track,
                              isDark: isDark,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              onTap: () => _openTrackDetail(track),
                            ),
                          );
                        },
                        childCount: filteredTracks.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

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
    return LuminousFeedback(
      onTap: _isScanning ? null : _scanFolder,
      variant: LuminousVariant.emerald,
      borderRadius: BorderRadius.circular(28),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        style: GlassStyle.frosted,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                              fontSize: 36,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isScanning
                            ? 'Scanning... audited $_scannedCount tracks'
                            : (appState.lastScannedFolder != null
                                ? appState.lastScannedFolder!.split('/').last
                                : 'Tap to select music folder to batch audit'),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x3000D2FF) : const Color(0xFFE0F7FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isScanning
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.folder_open_rounded,
                          color: AppColors.accentPrimary,
                          size: 22,
                        ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // High-Contrast Clear Glass Telemetry Pills Row
            Row(
              children: [
                _buildStatPill(
                  'GENUINE',
                  '$genuineCount',
                  AppColors.genuineEmerald,
                  isDark ? const Color(0x2500E676) : const Color(0xFFDCFCE7),
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  'SUSPECT',
                  '$suspiciousCount',
                  AppColors.suspiciousAmber,
                  isDark ? const Color(0x25FFB300) : const Color(0xFFFEF3C7),
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  'FAKE',
                  '$fakeCount',
                  AppColors.fakeCoral,
                  isDark ? const Color(0x25FF5252) : const Color(0xFFFFEBEE),
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  'AVG SCORE',
                  '$averageScore%',
                  AppColors.accentPrimary,
                  isDark ? const Color(0x2500D2FF) : const Color(0xFFE0F7FE),
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    String value,
    Color accentColor,
    Color chipBg,
    bool isDark,
  ) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(16),
        style: GlassStyle.clear,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String filterKey, bool isDark) {
    final isSelected = _filter == filterKey;
    final fg = isSelected
        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
        : (isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary);

    return GestureDetector(
      onTap: () => setState(() => _filter = filterKey),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(20),
        style: GlassStyle.clear,
        tintColor: isSelected
            ? (isDark ? const Color(0x4000D2FF) : const Color(0xFFCCE8FE))
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  /// Track Row with Soft Wrapping & Luminous Emerald Feedback
  Widget _buildTransparentTrackRow({
    required FlacInfo track,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    final statusColor = _getStatusColor(track.status);

    return LuminousFeedback(
      onTap: onTap,
      variant: LuminousVariant.emerald,
      borderRadius: BorderRadius.circular(18),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(18),
        style: GlassStyle.frosted,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            // 52dp Squircle Artwork Thumbnail
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.30 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
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
            const SizedBox(width: 14),
            // Title (2-line soft wrap), Artist & Technical Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title.isNotEmpty ? track.title : track.fileName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist.isNotEmpty
                        ? '${track.artist} • ${track.album}'
                        : track.fileName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _buildSpecChip('${track.bitDepth}-bit', isDark),
                      const SizedBox(width: 4),
                      _buildSpecChip('${(track.sampleRate / 1000).toStringAsFixed(1)}k', isDark),
                      const SizedBox(width: 4),
                      _buildSpecChip('${track.bitrateKbps}k', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Status Icon & Authenticity Score Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (track.status == 'genuine')
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.genuineEmerald,
                      )
                    else
                      Icon(
                        track.status == 'suspicious'
                            ? Icons.warning_amber_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '${track.score}%',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  track.durationStr,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFF0F0F4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xCCFFFFFF) : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _fallbackCover(Color statusColor) {
    return Center(
      child: Icon(
        Icons.album_rounded,
        size: 26,
        color: statusColor.withOpacity(0.7),
      ),
    );
  }
}

/// Rich Studio Audio Inspector Modal Bottom Sheet with Spectral Analyzer Stage
class _TrackDetailModal extends StatelessWidget {
  final FlacInfo track;

  const _TrackDetailModal({required this.track});

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);

    Color statusColor;
    switch (track.status) {
      case 'genuine':
        statusColor = AppColors.genuineEmerald;
        break;
      case 'suspicious':
        statusColor = AppColors.suspiciousAmber;
        break;
      default:
        statusColor = AppColors.fakeCoral;
    }

    return GlassSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      style: GlassStyle.frosted,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x40FFFFFF) : const Color(0x40000000),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 1. Header: Artwork + Title + Artist + Verified Seal
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: track.hasCover && track.coverBytes != null
                    ? Image.memory(track.coverBytes!, fit: BoxFit.cover)
                    : Icon(Icons.album_rounded, size: 32, color: statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.title.isNotEmpty ? track.title : track.fileName,
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
                        ),
                        if (track.status == 'genuine') ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 20,
                            color: AppColors.genuineEmerald,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist.isNotEmpty ? '${track.artist} • ${track.album}' : 'Unknown Artist',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: subTextColor,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Score Badge
          Row(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${track.score}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        track.status == 'genuine'
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        size: 15,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          track.verdict.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
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

          // 3. Studio Spectral Nyquist Analyzer Stage (Requested by user!)
          AudioSpectrumStage(
            cutoffKhz: track.cutoffKhz,
            maxKhz: track.maxKhz,
            statusColor: statusColor,
            height: 38,
          ),

          const SizedBox(height: 14),

          // 4. Quick Specs in Clear Glass
          Row(
            children: [
              _buildModalSpecTile('${track.bitDepth}-bit', 'Depth', isDark),
              const SizedBox(width: 6),
              _buildModalSpecTile('${(track.sampleRate / 1000).toStringAsFixed(1)}k', 'Sampling', isDark),
              const SizedBox(width: 6),
              _buildModalSpecTile('${track.bitrateKbps}k', 'Bitrate', isDark),
              const SizedBox(width: 6),
              _buildModalSpecTile('${track.fileSizeMb.toStringAsFixed(1)}MB', 'Size', isDark),
            ],
          ),

          const SizedBox(height: 12),

          // 5. File Location Row
          GlassSurface(
            borderRadius: BorderRadius.circular(14),
            style: GlassStyle.clear,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 18, color: subTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.filePath,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: subTextColor,
                    ),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSpecTile(String value, String label, bool isDark) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(12),
        style: GlassStyle.clear,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
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
}
