import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';

/// 1:1 Port of LastWave's Connected Card Group Architecture for Duplicate Track Management
class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class DuplicateItem {
  final FlacInfo info;
  final bool isBest;
  final String reason;

  DuplicateItem({required this.info, required this.isBest, required this.reason});
}

class DuplicateGroup {
  final String key;
  final String title;
  final String artist;
  final List<DuplicateItem> items;

  DuplicateGroup({
    required this.key,
    required this.title,
    required this.artist,
    required this.items,
  });

  double get wastedMb {
    if (items.length <= 1) return 0.0;
    final best = items.firstWhere((i) => i.isBest, orElse: () => items.first);
    double total = 0.0;
    for (final it in items) {
      if (it != best) total += it.info.fileSizeMb;
    }
    return total;
  }
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  bool _isScanning = false;
  int _scannedCount = 0;
  List<DuplicateGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    if (appState.sharedLibrary.isNotEmpty) {
      _analyzeDuplicates(appState.sharedLibrary);
    }
  }

  Future<void> _scanForDuplicates() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    setState(() {
      _isScanning = true;
      _scannedCount = 0;
      _groups = [];
    });

    try {
      final dir = Directory(dirPath);
      final List<File> flacFiles = [];

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.flac')) {
          flacFiles.add(entity);
        }
      }

      final List<FlacInfo> tracks = [];
      for (final file in flacFiles) {
        final info = await FlacParser.analyzeFile(file.path);
        tracks.add(info);
        if (mounted) {
          setState(() {
            _scannedCount++;
          });
        }
      }

      appState.setSharedLibrary(tracks, dirPath);
      _analyzeDuplicates(tracks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: AppColors.fakeCoral),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  double get _totalWastedMb {
    return _groups.fold<double>(0.0, (sum, g) => sum + g.wastedMb);
  }

  Future<void> _confirmDelete(DuplicateItem item, DuplicateGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.heroInner,
          side: BorderSide(color: AppColors.darkHairline, width: 0.6),
        ),
        title: const Text(
          'Delete Duplicate?',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "${item.info.fileName}" (${item.info.fileSizeMb.toStringAsFixed(1)} MB)?\n\nThis cannot be undone.',
          style: const TextStyle(fontFamily: 'Inter', color: Color(0xB3FFFFFF), fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fakeCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final file = File(item.info.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        appState.removeTrackFromLibrary(item.info.filePath);
        setState(() {
          group.items.remove(item);
          if (group.items.length <= 1) {
            _groups.remove(group);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Duplicate deleted successfully!'), backgroundColor: AppColors.genuineEmerald),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.fakeCoral),
          );
        }
      }
    }
  }

  void _analyzeDuplicates(List<FlacInfo> tracks) {
    final Map<String, List<FlacInfo>> map = {};

    for (final t in tracks) {
      final normTitle = t.title.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final normArtist = t.artist.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final key = normTitle.isNotEmpty && normArtist.isNotEmpty
          ? '$normTitle##$normArtist'
          : t.fileName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      map.putIfAbsent(key, () => []).add(t);
    }

    final List<DuplicateGroup> result = [];

    for (final entry in map.entries) {
      if (entry.value.length > 1) {
        final groupTracks = entry.value;

        // Rank by quality score, then sample rate, then bit depth
        groupTracks.sort((a, b) {
          if (b.score != a.score) return b.score.compareTo(a.score);
          if (b.sampleRate != a.sampleRate) return b.sampleRate.compareTo(a.sampleRate);
          return b.bitDepth.compareTo(a.bitDepth);
        });

        final bestTrack = groupTracks.first;

        final List<DuplicateItem> items = [];
        for (int i = 0; i < groupTracks.length; i++) {
          final t = groupTracks[i];
          final isBest = i == 0;
          String reason;
          if (isBest) {
            reason = 'Highest audio purity (${t.score}%)';
          } else {
            reason = t.score < bestTrack.score
                ? 'Lower quality (${t.score}% vs ${bestTrack.score}%)'
                : 'Identical audio purity, duplicate copy';
          }
          items.add(DuplicateItem(info: t, isBest: isBest, reason: reason));
        }

        result.add(DuplicateGroup(
          key: entry.key,
          title: bestTrack.title.isNotEmpty ? bestTrack.title : bestTrack.fileName,
          artist: bestTrack.artist.isNotEmpty ? bestTrack.artist : 'Unknown Artist',
          items: items,
        ));
      }
    }

    setState(() {
      _groups = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        final totalDuplicatesCount = _groups.fold<int>(0, (sum, g) => sum + g.items.length - 1);

        return Column(
          children: [
            // 1. LastWave Expressive Hero Stage (32dp Continuous Curvature)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _buildHeroStage(
                groupsCount: _groups.length,
                duplicatesCount: totalDuplicatesCount,
                wastedMb: _totalWastedMb,
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
            ),

            const SizedBox(height: 8),

            // 2. LastWave Connected Group Content Stage (28dp Top Corners)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildListContainer(
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

  Widget _buildHeroStage({
    required int groupsCount,
    required int duplicatesCount,
    required double wastedMb,
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
              onTap: _isScanning ? null : _scanForDuplicates,
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
                                '${wastedMb.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  color: wastedMb > 0 ? AppColors.suspiciousAmber : textColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'MB Recoverable',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isScanning
                                ? 'Scanning library for duplicates...'
                                : groupsCount > 0
                                    ? '$groupsCount duplicate sets found ($duplicatesCount redundant files)'
                                    : 'Scan music folders to find duplicate copies and keep the purest FLAC',
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
                                Icons.search_rounded,
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

          // Telemetry Pills Row (16dp StatPillShape)
          Row(
            children: [
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Duplicate Sets',
                  value: '$groupsCount',
                  color: AppColors.accentPrimary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Redundant Files',
                  value: '$duplicatesCount',
                  color: AppColors.suspiciousAmber,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryPill(
                  label: 'Storage to Free',
                  value: '${wastedMb.toStringAsFixed(0)} MB',
                  color: AppColors.genuineEmerald,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  /// 1:1 Port of LastWave's ListContainer with Connected Groups
  Widget _buildListContainer({
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
      child: _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    size: 42,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No duplicate audio detected',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audit a music library to detect redundant files',
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              physics: const BouncingScrollPhysics(),
              itemCount: _groups.length,
              itemBuilder: (context, gIndex) {
                final group = _groups[gIndex];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Header Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${group.title} • ${group.artist}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${group.items.length} copies',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.suspiciousAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Connected Rows Group (1:1 with LastWave SettingsGroup)
                      Column(
                        children: List.generate(group.items.length, (i) {
                          final item = group.items[i];
                          final position = group.items.length == 1
                              ? GroupPosition.single
                              : (i == 0
                                  ? GroupPosition.top
                                  : (i == group.items.length - 1
                                      ? GroupPosition.bottom
                                      : GroupPosition.middle));

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3), // GROUP_GAP = 3dp
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceContainer : AppColors.lightSurfaceLow,
                                borderRadius: groupShape(position),
                                border: Border.all(
                                  color: item.isBest
                                      ? AppColors.genuineEmerald.withOpacity(0.35)
                                      : (isDark ? AppColors.darkHairline : AppColors.lightHairline),
                                  width: 0.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: item.isBest
                                          ? AppColors.genuineEmerald.withOpacity(0.18)
                                          : (isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh),
                                    ),
                                    child: Icon(
                                      item.isBest ? Icons.verified_rounded : Icons.file_copy_rounded,
                                      color: item.isBest ? AppColors.genuineEmerald : subTextColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.info.fileName,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12.5,
                                                  fontWeight: item.isBest ? FontWeight.w700 : FontWeight.w500,
                                                  color: textColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (item.isBest)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.genuineEmerald.withOpacity(0.16),
                                                  borderRadius: ExpressiveShapes.badgePill,
                                                ),
                                                child: const Text(
                                                  'BEST QUALITY',
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                    color: AppColors.genuineEmerald,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.reason,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10.5,
                                            color: subTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            _buildBadge('${item.info.bitDepth}-bit', isDark),
                                            const SizedBox(width: 5),
                                            _buildBadge('${(item.info.sampleRate / 1000).toStringAsFixed(1)}k', isDark),
                                            const SizedBox(width: 5),
                                            _buildBadge('${item.info.fileSizeMb.toStringAsFixed(1)} MB', isDark),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!item.isBest) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.fakeCoral, size: 20),
                                      onPressed: () => _confirmDelete(item, group),
                                      tooltip: 'Delete duplicate',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
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
}
