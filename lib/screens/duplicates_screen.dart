import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';

/// 1:1 Port of LastWave Native's Connected Group Architecture for Duplicate Track Management
///
/// Features:
/// - Replaces nested boxed cards with LastWave Connected Groups (3dp gaps, 28dp/6dp continuous curvature).
/// - Pure pitch black AMOLED canvas with ZERO border outlines.
/// - 140dp bottom padding clearance ensuring the dock never covers duplicate sets.
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

    final List<FlacInfo> tracks = [];

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
          SnackBar(
            content: Text('Error scanning folder: $e'),
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

  void _analyzeDuplicates(List<FlacInfo> tracks) {
    final Map<String, List<FlacInfo>> map = {};

    for (final t in tracks) {
      String key;
      if (t.title.isNotEmpty && t.artist.isNotEmpty) {
        key = '${_sanitize(t.title)}:::${_sanitize(t.artist)}';
      } else {
        key = _sanitize(t.fileName.replaceAll(RegExp(r'\.flac$', caseSensitive: false), ''));
      }
      map.putIfAbsent(key, () => []).add(t);
    }

    final List<DuplicateGroup> groups = [];

    for (final entry in map.entries) {
      if (entry.value.length > 1) {
        final sorted = List<FlacInfo>.from(entry.value)
          ..sort((a, b) {
            if (b.score != a.score) return b.score.compareTo(a.score);
            if (b.bitDepth != a.bitDepth) return b.bitDepth.compareTo(a.bitDepth);
            if (b.sampleRate != a.sampleRate) return b.sampleRate.compareTo(a.sampleRate);
            return b.bitrateKbps.compareTo(a.bitrateKbps);
          });

        final best = sorted.first;
        final items = sorted.map((track) {
          final isBest = track == best;
          final reason = isBest
              ? 'Highest purity (${track.score}% • ${track.bitDepth}-bit/${(track.sampleRate / 1000).toStringAsFixed(1)}k)'
              : (track.score < best.score
                  ? 'Lower score (${track.score}% vs ${best.score}%)'
                  : 'Lower resolution (${track.bitDepth}-bit vs ${best.bitDepth}-bit)');

          return DuplicateItem(info: track, isBest: isBest, reason: reason);
        }).toList();

        groups.add(
          DuplicateGroup(
            key: entry.key,
            title: best.title.isNotEmpty ? best.title : best.fileName,
            artist: best.artist.isNotEmpty ? best.artist : 'Unknown Artist',
            items: items,
          ),
        );
      }
    }

    setState(() {
      _groups = groups;
    });
  }

  String _sanitize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

  void _confirmDeleteTrack(FlacInfo track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete this redundant copy?\n\n${track.filePath.split('/').last}',
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0x99FFFFFF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                final file = File(track.filePath);
                if (file.existsSync()) {
                  file.deleteSync();
                }
                appState.removeTrackFromLibrary(track.filePath);
                _analyzeDuplicates(appState.sharedLibrary);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Redundant file deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete file: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.fakeCoral, fontWeight: FontWeight.bold)),
          ),
        ],
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

        final duplicatesCount = _groups.fold<int>(
            0, (sum, g) => sum + (g.items.length > 1 ? g.items.length - 1 : 0));
        final wastedMb = _groups.fold<double>(0.0, (sum, g) => sum + g.wastedMb);

        return Scaffold(
          backgroundColor: isDark ? AppColors.amoledCanvas : AppColors.lightCanvas,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 4),
                    child: Text(
                      'Duplicates',
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

                // Hero Stage (Single Sculpted Obsidian Container, Zero Borders)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _buildHeroStage(
                      groupsCount: _groups.length,
                      duplicatesCount: duplicatesCount,
                      wastedMb: wastedMb,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ),
                ),

                // Duplicate Sets List (Connected Groups)
                if (_groups.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_all_outlined,
                              size: 44,
                              color: isDark ? const Color(0x40FFFFFF) : const Color(0x40000000),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appState.sharedLibrary.isEmpty
                                  ? 'No library scanned yet\nTap the hero card above to audit your music folder'
                                  : 'No duplicate FLAC sets found in library!\nYour collection has zero redundant audio files',
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
                          final group = _groups[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildDuplicateGroup(group, isDark, textColor, subTextColor),
                          );
                        },
                        childCount: _groups.length,
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
    required int groupsCount,
    required int duplicatesCount,
    required double wastedMb,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    final cardBg = isDark ? AppColors.surfaceContainer : AppColors.lightSurface;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: _isScanning ? null : _scanForDuplicates,
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
                              '$groupsCount',
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
                              'Duplicate Sets',
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
                              ? 'Scanning... inspected $_scannedCount tracks'
                              : (groupsCount > 0
                                  ? '$groupsCount duplicate sets ($duplicatesCount redundant files)'
                                  : 'Tap to scan music folders and keep the purest FLAC'),
                          maxLines: 1,
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
                            Icons.search_rounded,
                            color: AppColors.accentPrimary,
                            size: 22,
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3 Telemetry Pills
              Row(
                children: [
                  _buildStatPill('Sets', '$groupsCount', AppColors.accentPrimary, isDark),
                  const SizedBox(width: 6),
                  _buildStatPill('Redundant', '$duplicatesCount', AppColors.suspiciousAmber, isDark),
                  const SizedBox(width: 6),
                  _buildStatPill('Storage to Free', '${wastedMb.toStringAsFixed(0)} MB', AppColors.genuineEmerald, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
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
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : const Color(0x80000000),
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
      ),
    );
  }

  /// Connected Group representation of a Duplicate Track Set (3dp gaps, 28dp/6dp continuous curvature)
  Widget _buildDuplicateGroup(
    DuplicateGroup group,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Set Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
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

        // Connected Rows
        ExpressiveGroup(
          rowCount: group.items.length,
          itemBuilder: (context, index, position) {
            final item = group.items[index];
            final shape = groupShape(position);
            final rowBg = isDark ? AppColors.surfaceContainer : AppColors.lightSurface;

            return Material(
              color: rowBg,
              borderRadius: shape,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Badge: Best vs Redundant
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.isBest
                            ? (isDark ? const Color(0xFF142B1F) : const Color(0xFFDCFCE7))
                            : (isDark ? const Color(0xFF261D1D) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.isBest ? Icons.star_rounded : Icons.copy_rounded,
                        size: 18,
                        color: item.isBest ? AppColors.genuineEmerald : AppColors.fakeCoral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.isBest ? 'BEST VERSION' : 'REDUNDANT COPY',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: item.isBest ? AppColors.genuineEmerald : AppColors.fakeCoral,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.info.score}% purity',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.info.bitDepth}-bit / ${(item.info.sampleRate / 1000).toStringAsFixed(1)}k • ${item.info.fileSizeMb.toStringAsFixed(1)} MB',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: subTextColor,
                            ),
                          ),
                          Text(
                            item.info.filePath.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              color: subTextColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!item.isBest)
                      IconButton(
                        onPressed: () => _confirmDeleteTrack(item.info),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: AppColors.fakeCoral,
                        ),
                        splashRadius: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
