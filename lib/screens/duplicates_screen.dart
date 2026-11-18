import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../services/duplicate_detector.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_glass_dialog.dart';
import '../widgets/bounded_scroll_physics.dart';

/// Lightweight Squircle Album Art Widget with Lazy Extraction & Fallback
class _DuplicateCoverArt extends StatelessWidget {
  final String filePath;
  final double size;
  final double borderRadius;

  const _DuplicateCoverArt({
    required this.filePath,
    this.size = 52,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isDark
            ? AppColors.softElevation(elevation: 2.0)
            : AppColors.lightSoftElevation(elevation: 2.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List?>(
        future: FlacParser.extractCoverBytes(filePath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return Icon(
            Icons.album_rounded,
            size: size * 0.55,
            color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
          );
        },
      ),
    );
  }
}

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

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  bool _isScanning = false;
  bool _cancelRequested = false;
  int _scannedCount = 0;
  int _totalFiles = 0;
  List<DuplicateGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
    AudioPlaybackService.instance.addListener(_onPlaybackStateChanged);
    if (appState.sharedLibrary.isNotEmpty) {
      _analyzeDuplicates(appState.sharedLibrary);
    }
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    AudioPlaybackService.instance.removeListener(_onPlaybackStateChanged);
    if (AudioPlaybackService.instance.isPlaying) {
      AudioPlaybackService.instance.stop();
    }
    super.dispose();
  }

  void _onPlaybackStateChanged() {
    if (mounted) setState(() {});
  }

  void _onAppStateChanged() {
    if (!_isScanning && mounted) {
      _analyzeDuplicates(appState.sharedLibrary);
    }
  }

  Future<void> _startScan(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      if (mounted) {
        showThemedSnackBar(
          context,
          'Folder not found: $dirPath',
          icon: Icons.folder_off_rounded,
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _cancelRequested = false;
      _scannedCount = 0;
      _totalFiles = 0;
      _groups = [];
    });

    final List<FlacInfo> tracks = [];

    try {
      final List<File> flacFiles = [];

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (_cancelRequested) break;
        if (entity is File && entity.path.toLowerCase().endsWith('.flac')) {
          flacFiles.add(entity);
        }
      }

      if (_cancelRequested) {
        if (mounted) {
          setState(() => _isScanning = false);
          showThemedSnackBar(
            context,
            'Scan cancelled',
            icon: Icons.cancel_outlined,
          );
        }
        return;
      }

      if (flacFiles.isEmpty && mounted) {
        showThemedSnackBar(
          context,
          'No .flac files found in $dirPath',
          icon: Icons.info_outline_rounded,
        );
      }

      if (mounted) {
        setState(() {
          _totalFiles = flacFiles.length;
        });
      }

      final Map<String, FlacInfo> existingCacheMap = {
        for (final t in appState.sharedLibrary) t.filePath: t
      };

      for (final file in flacFiles) {
        if (_cancelRequested) break;
        final cached = existingCacheMap[file.path];
        if (cached != null) {
          tracks.add(cached);
        } else {
          final info = await FlacParser.analyzeFile(
            file.path,
            deepDsp: false,
            readCoverBytes: false,
          );
          tracks.add(info);
        }
        if (mounted) {
          setState(() {
            _scannedCount++;
          });
        }
      }

      if (tracks.isNotEmpty) {
        appState.setSharedLibrary(tracks, dirPath);
        _analyzeDuplicates(tracks);
      }

      if (mounted) {
        showThemedSnackBar(
          context,
          _cancelRequested
              ? 'Scan cancelled • Analyzed ${tracks.length} of $_totalFiles tracks'
              : 'Audited ${tracks.length} tracks for duplicates',
          icon: _cancelRequested ? Icons.info_outline_rounded : Icons.verified_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        showThemedSnackBar(
          context,
          'Error scanning folder: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _pickFolderAndScan() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath != null) {
      _startScan(dirPath);
    }
  }

  void _showScanOptions() {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);
    final lastFolder = appState.lastScannedFolder;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          style: GlassStyle.frosted,
          borderless: false,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x40FFFFFF) : const Color(0x35000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Scan Audio Duplicates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a music source to find redundant and lossy duplicates',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (lastFolder != null && lastFolder.isNotEmpty) ...[
                  LuminousFeedback(
                    onTap: () {
                      Navigator.pop(ctx);
                      _startScan(lastFolder);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassSurface(
                      borderRadius: BorderRadius.circular(16),
                      style: GlassStyle.clear,
                      borderless: false,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.replay_rounded, color: activeAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Re-scan Recent Folder',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastFolder,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                LuminousFeedback(
                  onTap: () {
                    Navigator.pop(ctx);
                    _startScan('/storage/emulated/0/Music');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    style: GlassStyle.clear,
                    borderless: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.library_music_rounded, color: AppColors.genuineEmerald, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Music Folder',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/storage/emulated/0/Music • Standard music library',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LuminousFeedback(
                  onTap: () {
                    Navigator.pop(ctx);
                    _startScan('/storage/emulated/0/Download');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    style: GlassStyle.clear,
                    borderless: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.download_rounded, color: Color(0xFF38BDF8), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Downloads Folder',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/storage/emulated/0/Download • FLAC downloads folder',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LuminousFeedback(
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFolderAndScan();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    style: GlassStyle.clear,
                    borderless: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.suspiciousAmber.withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder_open_rounded, color: AppColors.suspiciousAmber, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browse Custom Folder...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select any directory using system file picker',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                      ],
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

  void _analyzeDuplicates(List<FlacInfo> tracks) {
    final groups = DuplicateDetector.findDuplicates(tracks);
    if (mounted) {
      setState(() => _groups = groups);
    }
  }

  Future<void> _deleteTrackWithMediaStoreSync(String filePath) async {
    try {
      const channel = MethodChannel('flac_toolkit/audio_decoder');
      await channel.invokeMethod('deleteMediaFile', {'filePath': filePath});
    } catch (_) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  void _setUserKeepTrack(DuplicateGroup group, String targetFilePath) {
    final groupIndex = _groups.indexWhere((g) => g.key == group.key);
    if (groupIndex != -1) {
      setState(() {
        _groups[groupIndex] = _groups[groupIndex].withUserSelection(targetFilePath);
      });
      if (appState.hapticsEnabled) {
        HapticFeedback.lightImpact();
      }
      final chosen = _groups[groupIndex].items.firstWhere((it) => it.info.filePath == targetFilePath);
      showThemedSnackBar(
        context,
        'Keeping "${chosen.info.fileName}" · Other copies marked redundant',
        icon: Icons.check_circle_rounded,
        accentColor: AppColors.genuineEmerald,
      );
    }
  }

  void _confirmDeleteGroupRedundant(DuplicateGroup group, [BuildContext? modalCtx]) {
    final redundantTracks = group.items.where((it) => !it.isUserKept).map((it) => it.info).toList();
    if (redundantTracks.isEmpty) return;

    double groupWasted = 0.0;
    for (final t in redundantTracks) {
      groupWasted += t.fileSizeMb;
    }

    showAppGlassDialog(
      context: context,
      title: 'Clean Duplicate Copies?',
      icon: Icons.delete_sweep_rounded,
      iconColor: AppColors.fakeCoral,
      isDestructive: true,
      content: 'Permanently remove ${redundantTracks.length} redundant ${redundantTracks.length == 1 ? 'copy' : 'copies'} of "${group.title}" (${groupWasted.toStringAsFixed(1)} MB)?\n\nYour preferred version will be preserved.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Clean (${groupWasted.toStringAsFixed(1)} MB)',
      onConfirm: () async {
        if (modalCtx != null && Navigator.canPop(modalCtx)) {
          Navigator.pop(modalCtx);
        }
        try {
          for (final track in redundantTracks) {
            await _deleteTrackWithMediaStoreSync(track.filePath);
            appState.removeTrackFromLibrary(track.filePath);
          }
          _analyzeDuplicates(appState.sharedLibrary);
          if (mounted) {
            showThemedSnackBar(
              context,
              'Cleaned redundant copies of "${group.title}"',
              icon: Icons.delete_sweep_rounded,
              accentColor: AppColors.genuineEmerald,
            );
          }
        } catch (e) {
          if (mounted) {
            showThemedSnackBar(context, 'Cleanup failed: $e', icon: Icons.error_outline_rounded);
          }
        }
      },
    );
  }

  void _confirmCleanAllRedundant(List<DuplicateGroup> groups) {
    final redundantTracks = <FlacInfo>[];
    double totalWasted = 0.0;
    for (final g in groups) {
      for (final it in g.items) {
        if (!it.isUserKept) {
          redundantTracks.add(it.info);
          totalWasted += it.info.fileSizeMb;
        }
      }
    }

    if (redundantTracks.isEmpty) return;

    showAppGlassDialog(
      context: context,
      title: 'Clean All Redundant Copies?',
      icon: Icons.auto_delete_rounded,
      iconColor: AppColors.fakeCoral,
      content: 'Permanently delete ${redundantTracks.length} redundant ${redundantTracks.length == 1 ? 'copy' : 'copies'} to reclaim ${totalWasted.toStringAsFixed(1)} MB?\n\nYour preferred version of each track will be preserved, and Android MediaStore will be updated.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete All (${totalWasted.toStringAsFixed(1)} MB)',
      isDestructive: true,
      onConfirm: () async {
        int deletedCount = 0;
        for (final track in redundantTracks) {
          await _deleteTrackWithMediaStoreSync(track.filePath);
          appState.removeTrackFromLibrary(track.filePath);
          deletedCount++;
        }
        _analyzeDuplicates(appState.sharedLibrary);
        if (mounted) {
          showThemedSnackBar(
            context,
            'Cleaned $deletedCount redundant copies (${totalWasted.toStringAsFixed(1)} MB reclaimed)',
            icon: Icons.delete_sweep_rounded,
            accentColor: AppColors.genuineEmerald,
          );
        }
      },
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
        final activeAccent = appState.getAccentColor(context);

        final duplicatesCount = _groups.fold<int>(
            0, (sum, g) => sum + (g.items.length > 1 ? g.items.where((it) => !it.isUserKept).length : 0));
        final wastedMb = _groups.fold<double>(0.0, (sum, g) => sum + g.wastedMb);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BoundedBouncingScrollPhysics(),
              slivers: [
                // Top Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Duplicates',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: textColor,
                          ),
                        ),
                        if (duplicatesCount > 0)
                          LuminousFeedback(
                            onTap: () => _confirmCleanAllRedundant(_groups),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.fakeCoral.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.fakeCoral.withOpacity(0.40),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_delete_rounded, size: 15, color: AppColors.fakeCoral),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Clean All',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.fakeCoral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
                      activeAccent: activeAccent,
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
                              color: activeAccent.withOpacity(0.40),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appState.sharedLibrary.isEmpty
                                  ? 'No library scanned yet\nChoose a music source below to audit duplicates'
                                  : 'No duplicate FLAC sets found in library!\nYour collection has zero redundant audio files',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: subTextColor,
                              ),
                            ),
                            if (appState.sharedLibrary.isEmpty) ...[
                              const SizedBox(height: 18),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LuminousFeedback(
                                    onTap: () => _startScan('/storage/emulated/0/Music'),
                                    borderRadius: BorderRadius.circular(14),
                                    child: GlassSurface(
                                      borderRadius: BorderRadius.circular(14),
                                      style: GlassStyle.clear,
                                      borderless: false,
                                      tintColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.library_music_rounded, size: 16, color: activeAccent),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Scan Music Library',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: activeAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  LuminousFeedback(
                                    onTap: _showScanOptions,
                                    borderRadius: BorderRadius.circular(14),
                                    child: GlassSurface(
                                      borderRadius: BorderRadius.circular(14),
                                      style: GlassStyle.clear,
                                      borderless: false,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.folder_open_rounded, size: 16, color: subTextColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Browse',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
    required Color activeAccent,
  }) {
    return LuminousFeedback(
      onTap: _isScanning ? null : _showScanOptions,
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
                            ? 'Scanning... $_scannedCount of $_totalFiles tracks'
                            : (groupsCount > 0
                                ? '$groupsCount duplicate sets ($duplicatesCount redundant files)'
                                : 'Tap to scan music folders and keep the purest FLAC'),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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
                    color: isDark
                        ? activeAccent.withOpacity(0.20)
                        : activeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isScanning
                      ? Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: activeAccent,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.search_rounded,
                          color: activeAccent,
                          size: 22,
                        ),
                ),
              ],
            ),

            if (_isScanning) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _totalFiles > 0 ? _scannedCount / _totalFiles : null,
                  backgroundColor: isDark ? const Color(0x30FFFFFF) : const Color(0x20000000),
                  valueColor: AlwaysStoppedAnimation<Color>(activeAccent),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _totalFiles > 0
                        ? '${((_scannedCount / _totalFiles) * 100).toInt()}% complete'
                        : 'Discovering tracks...',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: subTextColor,
                    ),
                  ),
                  LuminousFeedback(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                      setState(() => _cancelRequested = true);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.fakeCoral.withOpacity(isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.fakeCoral.withOpacity(0.40),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 13, color: AppColors.fakeCoral),
                          SizedBox(width: 4),
                          Text(
                            'Cancel Scan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.fakeCoral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // High-Contrast Clear Glass Telemetry Pills Row
            Row(
              children: [
                _buildStatPill('Sets', '$groupsCount', activeAccent, isDark),
                const SizedBox(width: 6),
                _buildStatPill('Redundant', '$duplicatesCount', AppColors.suspiciousAmber, isDark),
                const SizedBox(width: 6),
                _buildStatPill('Storage to Free', '${wastedMb.toStringAsFixed(0)} MB', AppColors.genuineEmerald, isDark),
              ],
            ),

            if (duplicatesCount > 0) ...[
              const SizedBox(height: 14),
              LuminousFeedback(
                onTap: () => _confirmCleanAllRedundant(_groups),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.fakeCoral.withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.fakeCoral.withOpacity(0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.fakeCoral),
                      const SizedBox(width: 8),
                      Text(
                        'Clean All Redundant Copies (${wastedMb.toStringAsFixed(1)} MB)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.fakeCoral,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

  String _formatCleanLocation(String path) {
    final parts = path.split('/');
    if (parts.length >= 2) {
      final folder = parts[parts.length - 2];
      final file = parts.last;
      return '$folder / $file';
    }
    return path;
  }

  String _formatExactDuration(double durationSec) {
    if (durationSec <= 0) return '0:00.00';
    final int totalMs = (durationSec * 1000).round();
    final int minutes = totalMs ~/ 60000;
    final int seconds = (totalMs % 60000) ~/ 1000;
    final int hundredths = (totalMs % 1000) ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  Widget _buildSpecSheetTable({
    required BuildContext context,
    required DuplicateGroup currentGroup,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
    required void Function(void Function()) setSheetState,
  }) {
    final items = currentGroup.items;

    Widget buildTableRow({
      required String label,
      required List<Widget> cells,
      bool isHeader = false,
      bool isAction = false,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: isHeader
              ? (isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
              width: 0.6,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isHeader ? 8 : (isAction ? 8 : 7)),
        child: Row(
          children: [
            SizedBox(
              width: 115,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isHeader ? 10 : 11,
                  fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: isHeader ? 0.6 : 0,
                  color: isHeader ? subTextColor : subTextColor.withOpacity(0.9),
                ),
              ),
            ),
            ...List.generate(cells.length, (idx) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: cells[idx],
                ),
              );
            }),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1A000000) : const Color(0x08000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x18FFFFFF) : const Color(0x12000000),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BoundedBouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 36,
          ),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Row
                buildTableRow(
                  label: 'ATTRIBUTE',
                  isHeader: true,
                  cells: items.map((item) {
                    final isKept = item.isUserKept;
                    final badgeColor = isKept
                        ? (item.isAcoustiqPick
                            ? (currentGroup.isAllFake ? const Color(0xFF38BDF8) : AppColors.genuineEmerald)
                            : AppColors.suspiciousAmber)
                        : AppColors.fakeCoral;
                    final badgeText = isKept
                        ? (item.isAcoustiqPick
                            ? (currentGroup.isAllFake ? 'SPACE-SAVER' : 'PRESERVED MASTER')
                            : 'USER KEPT')
                        : 'DUPLICATE COPY';

                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: badgeColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),

                // 2. Recommendation / Verdict Row
                buildTableRow(
                  label: 'Recommendation',
                  cells: items.map((item) {
                    return Text(
                      item.reason,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: item.isUserKept ? FontWeight.w600 : FontWeight.w500,
                        color: item.isUserKept
                            ? (item.isAcoustiqPick
                                ? (currentGroup.isAllFake ? const Color(0xFF38BDF8) : AppColors.genuineEmerald)
                                : AppColors.suspiciousAmber)
                            : subTextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  }).toList(),
                ),

                // 3. Synced Lyrics Row
                buildTableRow(
                  label: 'Synced Lyrics',
                  cells: items.map((item) {
                    if (item.info.hasLyrics) {
                      return const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lyrics_rounded, size: 12, color: Color(0xFFD8B4FE)),
                          SizedBox(width: 4),
                          Text(
                            'Synced (.lrc)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD8B4FE),
                            ),
                          ),
                        ],
                      );
                    }
                    return Text(
                      'None (Missing)',
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor.withOpacity(0.65),
                      ),
                    );
                  }).toList(),
                ),

                // 4. Album Artwork Row
                buildTableRow(
                  label: 'Cover Artwork',
                  cells: items.map((item) {
                    if (item.info.hasCover) {
                      return const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_rounded, size: 12, color: Color(0xFFF472B6)),
                          SizedBox(width: 4),
                          Text(
                            'Embedded Cover',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF472B6),
                            ),
                          ),
                        ],
                      );
                    }
                    return Text(
                      'None (Missing)',
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor.withOpacity(0.65),
                      ),
                    );
                  }).toList(),
                ),

                // 5. Audio Waveform (MD5 Signature)
                buildTableRow(
                  label: 'Waveform MD5',
                  cells: items.map((item) {
                    if (currentGroup.isMd5Identical) {
                      return const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint_rounded, size: 12, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            '100% Bit-Identical',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      );
                    }
                    return Text(
                      'Unique Waveform',
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor,
                      ),
                    );
                  }).toList(),
                ),

                // 6. Lossless Purity Diagnosis
                buildTableRow(
                  label: 'Lossless Purity',
                  cells: items.map((item) {
                    if (item.info.status == 'untested') {
                      return Text('Untested', style: TextStyle(fontSize: 11, color: subTextColor));
                    }
                    final scoreColor = item.info.score >= 80
                        ? AppColors.genuineEmerald
                        : (item.info.score < 50 ? AppColors.fakeCoral : AppColors.suspiciousAmber);
                    return Text(
                      '${item.info.score}% (${item.info.shortBadge})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scoreColor,
                      ),
                    );
                  }).toList(),
                ),

                // 7. Frequency Cutoff
                buildTableRow(
                  label: 'Frequency Reach',
                  cells: items.map((item) {
                    final reach = item.info.cutoffKhz > 0
                        ? '${item.info.cutoffKhz.toStringAsFixed(1)} kHz'
                        : '${item.info.maxKhz.toStringAsFixed(1)} kHz';
                    final tag = item.info.score < 50 ? ' (Lossy)' : '';
                    return Text(
                      '$reach$tag',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    );
                  }).toList(),
                ),

                // 8. Format & Depth
                buildTableRow(
                  label: 'Format & Depth',
                  cells: items.map((item) {
                    return Text(
                      '${item.info.bitDepth}-bit / ${(item.info.sampleRate / 1000).toStringAsFixed(1)} kHz',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    );
                  }).toList(),
                ),

                // 9. Average Bitrate
                buildTableRow(
                  label: 'Average Bitrate',
                  cells: items.map((item) {
                    return Text(
                      item.info.bitrateKbps > 0 ? '${item.info.bitrateKbps} kbps' : 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor,
                      ),
                    );
                  }).toList(),
                ),

                // 10. Exact Duration
                buildTableRow(
                  label: 'Exact Duration',
                  cells: items.map((item) {
                    return Text(
                      _formatExactDuration(item.info.durationSec),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    );
                  }).toList(),
                ),

                // 11. File Size & Storage
                buildTableRow(
                  label: 'File Size',
                  cells: items.map((item) {
                    return Text(
                      '${item.info.fileSizeMb.toStringAsFixed(1)} MB',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.isUserKept ? textColor : AppColors.fakeCoral,
                      ),
                    );
                  }).toList(),
                ),

                // 12. Storage Location
                buildTableRow(
                  label: 'Location',
                  cells: items.map((item) {
                    return Text(
                      _formatCleanLocation(item.info.filePath),
                      style: TextStyle(
                        fontSize: 10,
                        color: subTextColor.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }).toList(),
                ),

                // 13. In-Table Audio Preview
                buildTableRow(
                  label: 'Audio Preview',
                  cells: items.map((item) {
                    final isPlaying = AudioPlaybackService.instance.isPlaying &&
                        AudioPlaybackService.instance.currentFilePath == item.info.filePath;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: LuminousFeedback(
                        onTap: () async {
                          if (isPlaying) {
                            await AudioPlaybackService.instance.stop();
                          } else {
                            await AudioPlaybackService.instance.play(item.info.filePath);
                          }
                          setSheetState(() {});
                          if (mounted) setState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? activeAccent.withOpacity(0.25)
                                : (isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPlaying
                                  ? activeAccent.withOpacity(0.4)
                                  : (isDark ? const Color(0x20FFFFFF) : const Color(0x14000000)),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                size: 13,
                                color: isPlaying ? activeAccent : textColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isPlaying ? 'Stop' : 'Listen',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isPlaying ? activeAccent : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // 14. Action / Override Button
                buildTableRow(
                  label: 'Action',
                  isAction: true,
                  cells: items.map((item) {
                    if (item.isUserKept) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.genuineEmerald.withOpacity(0.35),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: AppColors.genuineEmerald),
                            SizedBox(width: 3),
                            Text(
                              'Preserved',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.genuineEmerald,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return LuminousFeedback(
                      onTap: () {
                        _setUserKeepTrack(currentGroup, item.info.filePath);
                        setSheetState(() {});
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: activeAccent.withOpacity(0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 12, color: activeAccent),
                            const SizedBox(width: 3),
                            Text(
                              'Keep This Instead',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: activeAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComparisonSheet(DuplicateGroup group) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final currentGroup = _groups.firstWhere(
              (g) => g.key == group.key,
              orElse: () => group,
            );

            // Forensic Banner Content
            String bannerTitle;
            String bannerDetail;
            IconData bannerIcon;
            Color bannerColor;

            if (currentGroup.isMd5Identical) {
              bannerIcon = Icons.fingerprint_rounded;
              bannerColor = AppColors.genuineEmerald;
              bannerTitle = '100% Bit-Identical Waveforms (MD5 Certified)';
              bannerDetail = currentGroup.wastedMb > 0
                  ? 'Both files contain identical audio streams. AcoustiQ recommends the most efficiently compressed file to reclaim ${currentGroup.wastedMb.toStringAsFixed(1)} MB with zero quality loss.'
                  : 'Both files contain identical audio streams and matching file size. AcoustiQ designates the primary collection master and marks the clone as redundant.';
            } else if (currentGroup.isAllFake) {
              bannerIcon = Icons.warning_amber_rounded;
              bannerColor = AppColors.suspiciousAmber;
              bannerTitle = 'Lossy Audio Transcodes Detected';
              bannerDetail = 'All files in this set are lossy upscales to FLAC. AcoustiQ designates the space-saving version to conserve storage without compromising audio fidelity.';
            } else {
              bannerIcon = Icons.verified_rounded;
              bannerColor = activeAccent;
              bannerTitle = 'Forensic Multi-Vector Quality Diagnosis';
              bannerDetail = 'AcoustiQ evaluated audio purity, bit depth, sampling rates, and metadata completeness to determine the superior studio copy.';
            }

            final redundantCount = currentGroup.items.where((it) => !it.isUserKept).length;

            return GlassSurface(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              style: GlassStyle.frosted,
              borderless: false,
              padding: EdgeInsets.zero,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x40FFFFFF) : const Color(0x40000000),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Set Header with Album Cover
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _DuplicateCoverArt(
                              filePath: currentGroup.items.first.info.filePath,
                              size: 48,
                              borderRadius: 13,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentGroup.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentGroup.artist,
                                    style: TextStyle(
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${currentGroup.items.length} Versions',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: subTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Forensic Intelligence Callout Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bannerColor.withOpacity(isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: bannerColor.withOpacity(0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                bannerIcon,
                                size: 18,
                                color: bannerColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bannerTitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: bannerColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      bannerDetail,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.35,
                                        color: isDark ? const Color(0xCCFFFFFF) : const Color(0xCC000000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Forensic Comparative Spec Sheet Table
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BoundedBouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                          child: _buildSpecSheetTable(
                            context: sheetCtx,
                            currentGroup: currentGroup,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            activeAccent: activeAccent,
                            setSheetState: setSheetState,
                          ),
                        ),
                      ),

                      // Sticky Bottom Action Bar
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x28000000) : const Color(0x10FFFFFF),
                          border: Border(
                            top: BorderSide(
                              color: isDark ? const Color(0x15FFFFFF) : const Color(0x0E000000),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: LuminousFeedback(
                          onTap: () {
                            _confirmDeleteGroupRedundant(currentGroup, ctx);
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.fakeCoral.withOpacity(isDark ? 0.22 : 0.15),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: AppColors.fakeCoral.withOpacity(0.45),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.fakeCoral),
                                const SizedBox(width: 6),
                                Text(
                                  'Clean $redundantCount Redundant ${redundantCount == 1 ? 'Copy' : 'Copies'} (${currentGroup.wastedMb.toStringAsFixed(1)} MB)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.fakeCoral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (AudioPlaybackService.instance.isPlaying) {
        AudioPlaybackService.instance.stop();
      }
    });
  }

  /// Connected Group representation of a Duplicate Track Set (Style B: 2-Line Minimal)
  Widget _buildDuplicateGroup(
    DuplicateGroup group,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final activeAccent = appState.getAccentColor(context);
    final redundantCount = group.items.where((it) => !it.isUserKept).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Set Header with Cover Art, Title & Compare Pill Button
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              _DuplicateCoverArt(
                filePath: group.items.first.info.filePath,
                size: 44,
                borderRadius: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.artist} · $redundantCount redundant ${redundantCount == 1 ? 'copy' : 'copies'} (${group.wastedMb.toStringAsFixed(1)} MB)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (group.isMd5Identical) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.genuineEmerald.withOpacity(0.35), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 11, color: AppColors.genuineEmerald),
                      SizedBox(width: 3),
                      Text(
                        'MD5 MATCH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.genuineEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (group.isAllFake) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.suspiciousAmber.withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.suspiciousAmber.withOpacity(0.35), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.suspiciousAmber),
                      SizedBox(width: 3),
                      Text(
                        'LOSSY SET',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.suspiciousAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              LuminousFeedback(
                onTap: () => _showComparisonSheet(group),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeAccent.withOpacity(0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.compare_arrows_rounded, size: 12, color: activeAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Compare',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: activeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Connected Rows with Frosted Glass & Luminous Feedback (Style B: 2-Line Minimal)
        ExpressiveGroup(
          rowCount: group.items.length,
          itemBuilder: (context, index, position) {
            final item = group.items[index];
            final shape = groupShape(position);
            final isPlaying = AudioPlaybackService.instance.isPlaying &&
                AudioPlaybackService.instance.currentFilePath == item.info.filePath;

            // Status label & color
            String statusLabel;
            Color statusColor;
            if (item.isUserKept) {
              if (item.isAcoustiqPick) {
                if (group.isAllFake) {
                  statusLabel = 'SPACE-SAVER';
                  statusColor = const Color(0xFF38BDF8);
                } else {
                  statusLabel = 'PRESERVED';
                  statusColor = isDark ? AppColors.genuineEmerald : AppColors.lightEmeraldText;
                }
              } else {
                statusLabel = 'USER KEPT';
                statusColor = isDark ? AppColors.suspiciousAmber : AppColors.lightAmberText;
              }
            } else {
              statusLabel = 'REDUNDANT';
              statusColor = isDark ? AppColors.fakeCoral : AppColors.lightCoralText;
            }

            return LuminousFeedback(
              onTap: () {
                if (!item.isUserKept) {
                  _setUserKeepTrack(group, item.info.filePath);
                } else {
                  _showComparisonSheet(group);
                }
              },
              borderRadius: shape,
              child: GlassSurface(
                borderRadius: shape,
                style: item.isUserKept ? GlassStyle.frosted : GlassStyle.clear,
                borderless: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Radio / Check Selection Indicator (1-tap toggle)
                    LuminousFeedback(
                      onTap: () => _setUserKeepTrack(group, item.info.filePath),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: item.isUserKept
                              ? statusColor.withOpacity(isDark ? 0.25 : 0.15)
                              : (isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isUserKept
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: item.isUserKept
                              ? statusColor
                              : (isDark ? const Color(0x50FFFFFF) : const Color(0x40000000)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Line 1: File Name + Status Capsule + Badges
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.info.fileName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(isDark ? 0.20 : 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.35),
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              if (item.info.hasLyrics) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA855F7).withOpacity(isDark ? 0.20 : 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: const Color(0xFFA855F7).withOpacity(0.35),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lyrics_rounded, size: 9.5, color: Color(0xFFD8B4FE)),
                                      SizedBox(width: 2.5),
                                      Text(
                                        'Lyrics',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD8B4FE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (item.info.hasCover) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEC4899).withOpacity(isDark ? 0.20 : 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: const Color(0xFFEC4899).withOpacity(0.35),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: const Text(
                                    'Art',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF472B6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Line 2: Specs & Why Keep (Upright Roman font, dot separator, zero italics, zero bullets)
                          Text(
                            '${item.info.bitDepth}-bit / ${(item.info.sampleRate / 1000).toStringAsFixed(1)}k · ${item.info.fileSizeMb.toStringAsFixed(1)} MB${item.info.bitrateKbps > 0 ? ' · ${item.info.bitrateKbps} kbps' : ''} · ${item.reason}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: subTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Audio Preview Icon Button (Symmetric on all rows)
                    LuminousFeedback(
                      onTap: () async {
                        if (isPlaying) {
                          await AudioPlaybackService.instance.stop();
                        } else {
                          await AudioPlaybackService.instance.play(item.info.filePath);
                        }
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? activeAccent.withOpacity(0.30)
                              : (isDark ? const Color(0x18FFFFFF) : const Color(0x0E000000)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          size: 16,
                          color: isPlaying ? activeAccent : textColor,
                        ),
                      ),
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
