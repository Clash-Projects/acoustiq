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

/// 1:1 Port of LastWave Native's Borderless AMOLED Track List Stage for FLAC Audio Auditing
///
/// Features:
/// - Borderless AMOLED Track Rows (Tracks sit natively on #000000 canvas with zero cartoon borders).
/// - 48dp Squircle Album Art with smooth 12dp continuous curvature.
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - Zero Truncation Architecture: 2-line title wrapping + isolated fixed-width audio specs capsule.
/// - Rich Studio Spectral Nyquist Analyzer Stage inside song details modal bottom sheet.
/// - Calibrated 96dp bottom padding (album art smoothly flows behind the liquid glass dock).
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
        final activeAccent = appState.getAccentColor(context);

        int averageScore = 0;
        if (tracks.isNotEmpty) {
          final total = tracks.fold<int>(0, (sum, item) => sum + item.score);
          averageScore = (total / tracks.length).round();
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
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

                // 2. Library Hero Action & Statistics Card (WWDC25 Frosted Glass Substrate)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _buildHeroAuditCard(
                      totalTracks: tracks.length,
                      genuineCount: genuineCount,
                      suspiciousCount: suspiciousCount,
                      fakeCount: fakeCount,
                      averageScore: averageScore,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      activeAccent: activeAccent,
                    ),
                  ),
                ),

                // 3. Filter Segment Pills Row (Clear Glass)
                if (tracks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterPill('All (${tracks.length})', 'all', isDark, activeAccent),
                            const SizedBox(width: 8),
                            _buildFilterPill('Genuine ($genuineCount)', 'genuine', isDark, activeAccent),
                            const SizedBox(width: 8),
                            _buildFilterPill('Suspicious ($suspiciousCount)', 'suspicious', isDark, activeAccent),
                            const SizedBox(width: 8),
                            _buildFilterPill('Fake ($fakeCount)', 'fake', isDark, activeAccent),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. LastWave Borderless AMOLED Track List
                if (tracks.isEmpty && !_isScanning)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 56,
                            color: activeAccent.withOpacity(0.45),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Audited Tracks Yet',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the card above to scan a music directory',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    // 96dp bottom padding: Content smoothly glides behind the 56dp liquid glass dock!
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = filteredTracks[index];
                          return _buildBorderlessTrackRow(
                            track: track,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onTap: () => _openTrackDetail(track),
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

  Widget _buildHeroAuditCard({
    required int totalTracks,
    required int genuineCount,
    required int suspiciousCount,
    required int fakeCount,
    required int averageScore,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
  }) {
    return LuminousFeedback(
      onTap: _isScanning ? null : _scanFolder,
      variant: LuminousVariant.emerald,
      borderRadius: BorderRadius.circular(28),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        style: GlassStyle.frosted,
        borderless: false, // Refined WWDC25 specular light rim active
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
                            '$totalTracks',
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
                            'Audited Tracks',
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
                            ? 'Scanning folder... analyzed $_scannedCount tracks'
                            : (appState.lastScannedFolder != null
                                ? 'Source: ${appState.lastScannedFolder!.split('/').last}'
                                : 'Tap to scan folder and audit entire library'),
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
                    color: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isScanning
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.genuineEmerald,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.folder_open_rounded,
                          color: AppColors.genuineEmerald,
                          size: 22,
                        ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Telemetry Pills Row (Clear Glass Substrates)
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
                  activeAccent,
                  activeAccent.withOpacity(isDark ? 0.22 : 0.14),
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
        borderless: false,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String filterKey, bool isDark, Color activeAccent) {
    final isSelected = _filter == filterKey;
    final fg = isSelected
        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
        : (isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _filter = filterKey),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(20),
          style: GlassStyle.clear,
          borderless: false,
          tintColor: isSelected
              ? activeAccent.withOpacity(isDark ? 0.30 : 0.16)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? (isDark ? Colors.white : activeAccent) : fg,
            ),
          ),
        ),
      ),
    );
  }

  /// LastWave Borderless Track Row Architecture (Zero Truncation)
  ///
  /// Matches LastWave screenshot_1.png and screenshot_6.png:
  /// - 0 box containers or outlines. Tracks sit directly on AMOLED black.
  /// - 48dp continuous squircle artwork.
  /// - 2-line title wrapping (prevents truncation on long song names).
  /// - Dedicated audio specs capsule (sample rate, bit depth, bitrate are never pushed off).
  /// - Wavy circle verified seal (Icons.verified_rounded) for genuine FLACs.
  /// - Luminous subtle touch feedback on tap.
  Widget _buildBorderlessTrackRow({
    required FlacInfo track,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    final statusColor = _getStatusColor(track.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: statusColor.withOpacity(0.12),
          highlightColor: statusColor.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 48dp Squircle Artwork Thumbnail (12dp radius)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x28FFFFFF) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDark
                        ? AppColors.softElevation(elevation: 2.0)
                        : AppColors.lightSoftElevation(elevation: 2.0),
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

                // Title & Subtitle with Clean 1-Line Non-wrapping Layout (LastWave Native Architecture)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title.isNotEmpty ? track.title : track.fileName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artist.isNotEmpty
                            ? '${track.artist} • ${(track.sampleRate / 1000).toStringAsFixed(0)}k/${track.bitDepth}b'
                            : '${(track.sampleRate / 1000).toStringAsFixed(0)}k/${track.bitDepth}b • ${track.bitrateKbps}k',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Wavy Verified Seal & Score Badge
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
                    const SizedBox(width: 5),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover(Color statusColor) {
    return Center(
      child: Icon(
        Icons.album_rounded,
        size: 24,
        color: statusColor.withOpacity(0.7),
      ),
    );
  }
}

/// Rich Studio Audio Inspector Modal Bottom Sheet with Spectral Analyzer Stage
///
/// Features Apple WWDC25 Frosted Glass Substrate with real Gaussian blur & specular rim.
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
      borderless: false, // Refined WWDC25 top specular rim
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

          // 1. Header: Artwork + Title + Artist + Verified Seal (No Truncation)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? AppColors.softElevation(elevation: 3.0)
                      : AppColors.lightSoftElevation(elevation: 3.0),
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
                              height: 1.25,
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

          // 2. Hybrid Forensic Audio Engine (Speedometer Dial + Scientific Nyquist Shelf Graph)
          AudioSpectrumStage(
            score: track.score,
            cutoffKhz: track.cutoffKhz,
            maxKhz: track.maxKhz,
            status: track.status,
            shortBadge: track.shortBadge,
            statusColor: statusColor,
            height: 136,
          ),

          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              track.verdict,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                height: 1.3,
                color: subTextColor,
              ),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          // 4. Quick Specs in Clear Glass (WWDC25 Clear Glass)
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
            borderless: false,
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
        borderless: false,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
