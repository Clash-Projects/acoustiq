import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Native's Mix & Track List Stage for FLAC Audio Auditing
///
/// Features:
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - Luminous emerald touch feedback ripple across track items.
/// - High-contrast Light Mode typography and stat pills.
/// - Pure pitch black AMOLED vs Graphite background with ZERO border outlines.
/// - 140dp bottom padding clearance.
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

                // 2. Hero Stage (Single Sculpted Obsidian Surface, Zero Borders)
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

                // 3. Filter Chips Row
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = filteredTracks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
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
    final cardBg = appState.getCardBgColor(context);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(28),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.04),
      child: InkWell(
        onTap: _isScanning ? null : _scanFolder,
        borderRadius: BorderRadius.circular(28),
        splashColor: AppColors.accentPrimary.withOpacity(0.10),
        child: Padding(
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
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE0F7FE),
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

              // High-Contrast Telemetry Pills Row
              Row(
                children: [
                  _buildStatPill('Genuine', '$genuineCount', AppColors.genuineEmerald, isDark),
                  const SizedBox(width: 6),
                  _buildStatPill('Suspect', '$suspiciousCount', AppColors.suspiciousAmber, isDark),
                  const SizedBox(width: 6),
                  _buildStatPill('Fake', '$fakeCount', AppColors.fakeCoral, isDark),
                  const SizedBox(width: 6),
                  _buildStatPill('Avg Score', '$averageScore%', AppColors.accentPrimary, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color, bool isDark) {
    Color pillBg = isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF0F0F4);
    Color fgColor = color;

    if (!isDark) {
      if (color == AppColors.genuineEmerald) {
        pillBg = AppColors.lightEmeraldPillBg;
        fgColor = AppColors.lightEmeraldText;
      } else if (color == AppColors.suspiciousAmber) {
        pillBg = AppColors.lightAmberPillBg;
        fgColor = AppColors.lightAmberText;
      } else if (color == AppColors.fakeCoral) {
        pillBg = AppColors.lightCoralPillBg;
        fgColor = AppColors.lightCoralText;
      } else {
        pillBg = AppColors.lightCyanPillBg;
        fgColor = AppColors.lightCyanText;
      }
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(14),
        ),
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String filterKey, bool isDark) {
    final isSelected = _filter == filterKey;
    final bg = isSelected
        ? (isDark ? const Color(0xFF242E3D) : const Color(0xFFE0F2FE))
        : (isDark ? const Color(0xFF141414) : const Color(0xFFEAEAEE));
    final fg = isSelected
        ? AppColors.accentPrimary
        : (isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary);

    return GestureDetector(
      onTap: () => setState(() => _filter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
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

  /// Seamless Transparent Track Row with Luminous Emerald Touch Feedback
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.transparent : Colors.white.withOpacity(0.50),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 52dp Continuous Squircle Artwork Thumbnail
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5EA),
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
            // Title, Artist & Technical Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title.isNotEmpty ? track.title : track.fileName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
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
                      fontSize: 12,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildTinyBadge('${track.bitDepth}-bit', isDark),
                      const SizedBox(width: 4),
                      _buildTinyBadge('${(track.sampleRate / 1000).toStringAsFixed(1)}k', isDark),
                      const SizedBox(width: 4),
                      _buildTinyBadge('${track.bitrateKbps}k', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Wavy Circle Verified Seal & Purity Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      track.status == 'genuine'
                          ? Icons.verified_rounded
                          : (track.status == 'suspicious'
                              ? Icons.warning_amber_rounded
                              : Icons.cancel_rounded),
                      size: 16,
                      color: isDark
                          ? statusColor
                          : (track.status == 'genuine'
                              ? AppColors.lightEmeraldText
                              : (track.status == 'suspicious'
                                  ? AppColors.lightAmberText
                                  : AppColors.lightCoralText)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${track.score}%',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? statusColor
                            : (track.status == 'genuine'
                                ? AppColors.lightEmeraldText
                                : (track.status == 'suspicious'
                                    ? AppColors.lightAmberText
                                    : AppColors.lightCoralText)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  track.durationStr,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

  Widget _buildTinyBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8EE),
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

/// Track Detail Modal Bottom Sheet (Frosted Glass with 28dp Blur)
class _TrackDetailModal extends StatelessWidget {
  final FlacInfo track;

  const _TrackDetailModal({required this.track});

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE6121212) : Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
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
              const SizedBox(height: 20),
              // Track Title, Artwork & Verified Seal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E5EA),
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
                        : const Icon(Icons.album_rounded, size: 30),
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
                          track.artist.isNotEmpty ? track.artist : 'Unknown Artist',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Technical Metadata Rows
              _buildModalRow('Authenticity Score', '${track.score}%', isDark, textColor),
              _buildModalRow('Cutoff Frequency', '${track.cutoffKhz.toStringAsFixed(1)} kHz', isDark, textColor),
              _buildModalRow('Sample Rate & Depth', '${track.bitDepth}-bit / ${(track.sampleRate / 1000).toStringAsFixed(1)} kHz', isDark, textColor),
              _buildModalRow('Bitrate', '${track.bitrateKbps} kbps', isDark, textColor),
              _buildModalRow('File Size', '${track.fileSizeMb.toStringAsFixed(2)} MB', isDark, textColor),
              _buildModalRow('Duration', track.durationStr, isDark, textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
