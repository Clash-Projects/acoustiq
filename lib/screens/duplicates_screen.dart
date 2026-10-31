import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Native's Connected Group Architecture for Duplicate Track Management
///
/// Features:
/// - Apple WWDC25 Frosted & Clear Glass surfaces.
/// - Connected Groups with 3dp gaps and 28dp/6dp continuous curvature.
/// - Luminous amber ripple feedback on interactions.
/// - Zero Truncation: 2-line title wrapping for duplicate tracks.
/// - Calibrated 96dp bottom padding (content glides behind the liquid glass dock).
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
          final isBest = identical(track, best);
          String reason;
          if (isBest) {
            reason = 'Highest authenticity (${track.score}%) • ${track.bitDepth}-bit/${(track.sampleRate / 1000).toStringAsFixed(1)}k';
          } else {
            reason = 'Redundant copy (${track.score}% purity) • ${(track.sampleRate / 1000).toStringAsFixed(1)}k';
          }
          return DuplicateItem(info: track, isBest: isBest, reason: reason);
        }).toList();

        final first = sorted.first;
        groups.add(DuplicateGroup(
          key: entry.key,
          title: first.title.isNotEmpty ? first.title : first.fileName,
          artist: first.artist.isNotEmpty ? first.artist : 'Unknown Artist',
          items: items,
        ));
      }
    }

    if (mounted) {
      setState(() => _groups = groups);
    }
  }

  String _sanitize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _confirmDeleteTrack(FlacInfo track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appState.getCardBgColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Redundant Copy?',
          style: TextStyle(
            color: appState.getTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete:\n${track.fileName}\n(${track.fileSizeMb.toStringAsFixed(1)} MB)\n\nYour highest quality version will be preserved.',
          style: TextStyle(
            color: appState.getSubTextColor(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: appState.getSubTextColor(context)),
            ),
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
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.fakeCoral,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          backgroundColor: Colors.transparent,
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

                // Hero Stage (WWDC25 Frosted Glass Substrate)
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

                // Duplicate Sets List
                if (_groups.isEmpty && !_isScanning)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_all_outlined,
                              size: 44,
                              color: isDark ? const Color(0x40FFFFFF) : AppColors.lightTextMuted,
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
                    // 96dp bottom padding: content glides behind the liquid glass dock!
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
    return LuminousFeedback(
      onTap: _isScanning ? null : _scanForDuplicates,
      variant: LuminousVariant.amber,
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
                          Icons.search_rounded,
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
    );
  }

  Widget _buildStatPill(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(14),
        style: GlassStyle.clear,
        borderless: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${group.items.length} copies',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.suspiciousAmber : AppColors.lightAmberText,
                ),
              ),
            ],
          ),
        ),

        // Connected Rows with Frosted Glass & Luminous Feedback
        ExpressiveGroup(
          rowCount: group.items.length,
          itemBuilder: (context, index, position) {
            final item = group.items[index];
            final shape = groupShape(position);

            return GlassSurface(
              borderRadius: shape,
              style: GlassStyle.frosted,
              borderless: false, // Refined WWDC25 specular light rim active
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Badge: Wavy verified seal for best vs copy icon for redundant
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.isBest
                          ? (isDark ? const Color(0x3000E676) : AppColors.lightEmeraldPillBg)
                          : (isDark ? const Color(0x30FF5252) : AppColors.lightCoralPillBg),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.isBest ? Icons.verified_rounded : Icons.copy_rounded,
                      size: 20,
                      color: item.isBest
                          ? (isDark ? AppColors.genuineEmerald : AppColors.lightEmeraldText)
                          : (isDark ? AppColors.fakeCoral : AppColors.lightCoralText),
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
                                color: item.isBest
                                    ? (isDark ? AppColors.genuineEmerald : AppColors.lightEmeraldText)
                                    : (isDark ? AppColors.fakeCoral : AppColors.lightCoralText),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            );
          },
        ),
      ],
    );
  }
}
