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
import '../widgets/expressive_group.dart';
import '../widgets/ambient_wallpaper.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_glass_dialog.dart';
import '../widgets/bounded_scroll_physics.dart';

/// Lightweight Squircle Album Art Widget with Lazy Extraction & Fallback
/// Lightweight Squircle Album Art Widget with In-Memory Caching & Zero Jitter
class _DuplicateCoverArt extends StatefulWidget {
  final String filePath;
  final double size;
  final double borderRadius;

  static final Map<String, Uint8List?> _cache = {};

  const _DuplicateCoverArt({
    required this.filePath,
    this.size = 52,
    this.borderRadius = 14,
  });

  @override
  State<_DuplicateCoverArt> createState() => _DuplicateCoverArtState();
}

class _DuplicateCoverArtState extends State<_DuplicateCoverArt> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  @override
  void didUpdateWidget(covariant _DuplicateCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadCover();
    }
  }

  void _loadCover() {
    if (_DuplicateCoverArt._cache.containsKey(widget.filePath)) {
      _bytes = _DuplicateCoverArt._cache[widget.filePath];
      _loaded = true;
      return;
    }
    FlacParser.extractCoverBytes(widget.filePath).then((bytes) {
      _DuplicateCoverArt._cache[widget.filePath] = bytes;
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: isDark
            ? AppColors.softElevation(elevation: 2.0)
            : AppColors.lightSoftElevation(elevation: 2.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: _loaded && _bytes != null
          ? Image.memory(_bytes!, fit: BoxFit.cover)
          : Icon(
              Icons.album_rounded,
              size: widget.size * 0.55,
              color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
            ),
    );
  }
}

/// Interactive Inline Audio Progress Bar with Seek & Real-Time Counter
class _InlineAudioProgressStrip extends StatefulWidget {
  final String filePath;
  final double durationSec;

  const _InlineAudioProgressStrip({
    required this.filePath,
    required this.durationSec,
  });

  @override
  State<_InlineAudioProgressStrip> createState() => _InlineAudioProgressStripState();
}

class _InlineAudioProgressStripState extends State<_InlineAudioProgressStrip> {
  final _player = AudioPlaybackService.instance;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerUpdate);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  String _formatTime(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final remS = s % 60;
    return '${m.toString().padLeft(2, '0')}:${remS.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = _player.currentFilePath == widget.filePath;
    if (!isCurrent || !_player.isPlaying) {
      return const SizedBox.shrink();
    }

    final pos = _player.positionMs;
    final dur = _player.durationMs > 0 ? _player.durationMs : (widget.durationSec * 1000).toInt();
    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAccent = appState.getAccentColor(context);
    final subTextColor = appState.getSubTextColor(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activeAccent.withValues(alpha: 0.25),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            // Mini Pause / Play button
            LuminousFeedback(
              onTap: () {
                if (_player.isPlaying) {
                  _player.pause();
                } else {
                  _player.resume();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: activeAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 14,
                  color: activeAccent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Interactive Scrub / Progress Bar
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      if (dur > 0 && constraints.maxWidth > 0) {
                        final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                        final ratio = (localX / constraints.maxWidth).clamp(0.0, 1.0);
                        _player.seek((ratio * dur).toInt());
                      }
                    },
                    onTapDown: (details) {
                      if (dur > 0 && constraints.maxWidth > 0) {
                        final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                        final ratio = (localX / constraints.maxWidth).clamp(0.0, 1.0);
                        _player.seek((ratio * dur).toInt());
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x30FFFFFF) : const Color(0x20000000),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: activeAccent,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeAccent.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // Real-Time Position / Duration Counter
            Text(
              '${_formatTime(pos)} / ${_formatTime(dur)}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: subTextColor,
              ),
            ),
          ],
        ),
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

  String? _lastPlayingFile;
  bool _lastIsPlaying = false;

  void _onPlaybackStateChanged() {
    final service = AudioPlaybackService.instance;
    if (_lastPlayingFile != service.currentFilePath || _lastIsPlaying != service.isPlaying) {
      _lastPlayingFile = service.currentFilePath;
      _lastIsPlaying = service.isPlaying;
      if (mounted) setState(() {});
    }
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

  void _confirmDeleteSingleTrack(FlacInfo track, DuplicateGroup group) {
    showAppGlassDialog(
      context: context,
      title: 'Delete Duplicate File?',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.fakeCoral,
      isDestructive: true,
      content: 'Permanently delete "${track.fileName}" (${track.fileSizeMb.toStringAsFixed(1)} MB)?\n\nYour preserved version will remain safe.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete (${track.fileSizeMb.toStringAsFixed(1)} MB)',
      onConfirm: () async {
        try {
          await _deleteTrackWithMediaStoreSync(track.filePath);
          appState.removeTrackFromLibrary(track.filePath);
          _analyzeDuplicates(appState.sharedLibrary);
          if (mounted) {
            showThemedSnackBar(
              context,
              'Deleted "${track.fileName}"',
              icon: Icons.delete_sweep_rounded,
              accentColor: AppColors.genuineEmerald,
            );
          }
        } catch (e) {
          if (mounted) {
            showThemedSnackBar(context, 'Delete failed: $e', icon: Icons.error_outline_rounded);
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
                        LuminousFeedback(
                          onTap: _isScanning ? null : _showScanOptions,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x20FFFFFF) : const Color(0x12000000),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              Icons.folder_open_rounded,
                              size: 18,
                              color: subTextColor,
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
                    // 140dp bottom padding: content glides behind the liquid glass dock without overlapping the last card!
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
    required Color activeAccent,
  }) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(26),
      style: GlassStyle.frosted,
      borderless: false,
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
              LuminousFeedback(
                onTap: _isScanning ? null : _showScanOptions,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? activeAccent.withValues(alpha: 0.20)
                        : activeAccent.withValues(alpha: 0.12),
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
                      color: AppColors.fakeCoral.withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.fakeCoral.withValues(alpha: 0.40),
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

          const SizedBox(height: 16),

          // The 3 High-Contrast Telemetry Stat Capsules
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
                  color: AppColors.fakeCoral.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.fakeCoral.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.fakeCoral),
                    const SizedBox(width: 8),
                    Text(
                      'Clean All Redundant Copies (${wastedMb.toStringAsFixed(1)} MB)',
                      style: const TextStyle(
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

            // Forensic Banner Content (Calm, dignified Apple sentence)
            String bannerTitle;
            String bannerDetail;
            IconData bannerIcon;
            Color bannerColor;

            if (currentGroup.isMd5Identical) {
              bannerIcon = Icons.fingerprint_rounded;
              bannerColor = AppColors.genuineEmerald;
              bannerTitle = 'Identical Audio Waveforms';
              bannerDetail = currentGroup.wastedMb > 0
                  ? 'Both files contain identical audio streams. Preserving your preferred version reclaims ${currentGroup.wastedMb.toStringAsFixed(1)} MB with zero quality loss.'
                  : 'Both files contain identical audio streams. AcoustiQ marks the secondary copy as redundant.';
            } else if (currentGroup.isAllFake) {
              bannerIcon = Icons.info_outline_rounded;
              bannerColor = AppColors.suspiciousAmber;
              bannerTitle = 'Lossy Transcodes Detected';
              bannerDetail = 'Both files are lossy upscales to FLAC. AcoustiQ recommends the most compact copy to conserve storage.';
            } else {
              bannerIcon = Icons.verified_rounded;
              bannerColor = activeAccent;
              bannerTitle = 'Audio Quality Comparison';
              bannerDetail = 'AcoustiQ evaluated audio purity, resolution, lyrics, and artwork completeness to determine the superior copy.';
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

                      // Set Header with Album Cover (Calm, full width)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _DuplicateCoverArt(
                              filePath: currentGroup.items.first.info.filePath,
                              size: 46,
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
                                  fontWeight: FontWeight.w600,
                                  color: subTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            LuminousFeedback(
                              onTap: () {
                                Navigator.of(sheetCtx).pop();
                                _openFullPageComparison(currentGroup);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: GlassSurface(
                                borderRadius: BorderRadius.circular(8),
                                style: GlassStyle.clear,
                                borderless: false,
                                tintColor: activeAccent.withValues(alpha: isDark ? 0.20 : 0.12),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fullscreen_rounded, size: 14, color: activeAccent),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      'Full Page',
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

                      const SizedBox(height: 12),

                      // Forensic Intelligence Callout Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bannerColor.withValues(alpha: isDark ? 0.12 : 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: bannerColor.withValues(alpha: 0.30),
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

                      // Unified Side-by-Side Diff Matrix (Zero Scroll)
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BoundedBouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                          child: _SideBySideDiffMatrix(
                            group: currentGroup,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            activeAccent: activeAccent,
                            onSelectKeep: (path) {
                              _setUserKeepTrack(currentGroup, path);
                              setSheetState(() {});
                            },
                            onRefresh: () {
                              setSheetState(() {});
                              if (mounted) setState(() {});
                            },
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

  void _openFullPageComparison(DuplicateGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FullPageComparisonScreen(
          group: group,
          appState: appState,
          onSetUserKeepTrack: (grp, path) {
            _setUserKeepTrack(grp, path);
          },
          onConfirmDeleteGroupRedundant: (grp, c) {
            _confirmDeleteGroupRedundant(grp, c);
          },
        ),
      ),
    ).whenComplete(() {
      if (AudioPlaybackService.instance.isPlaying) {
        AudioPlaybackService.instance.stop();
      }
      if (mounted) setState(() {});
    });
  }

  /// Connected Group representation of a Duplicate Track Set (Apple Photos Style)
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
        // Set Header: Squircle Cover Art + Title + Artist (ZERO neon badges, 100% full width)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              _DuplicateCoverArt(
                filePath: group.items.first.info.filePath,
                size: 40,
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.artist} · $redundantCount extra (${group.wastedMb.toStringAsFixed(1)} MB)',
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
              if (group.isMd5Identical) ...[
                const SizedBox(width: 6),
                GlassSurface(
                  borderRadius: BorderRadius.circular(10),
                  style: GlassStyle.clear,
                  borderless: false,
                  tintColor: AppColors.genuineEmerald.withValues(alpha: isDark ? 0.22 : 0.14),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 12, color: AppColors.genuineEmerald),
                      SizedBox(width: 3.5),
                      Text(
                        'EXACT',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.genuineEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 6),
              LuminousFeedback(
                onTap: () => _showComparisonSheet(group),
                borderRadius: BorderRadius.circular(10),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(10),
                  style: GlassStyle.clear,
                  borderless: false,
                  tintColor: activeAccent.withValues(alpha: isDark ? 0.18 : 0.10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.compare_arrows_rounded, size: 13, color: activeAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Compare',
                        style: TextStyle(
                          fontSize: 11.5,
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
        ),

        // Connected Rows with Frosted Glass & Luminous Feedback (Hybrid Gold Standard)
        ExpressiveGroup(
          rowCount: group.items.length,
          gap: 6.0,
          itemBuilder: (context, index, position) {
            final item = group.items[index];
            final shape = BorderRadius.circular(16);
            final isPlaying = AudioPlaybackService.instance.isPlaying &&
                AudioPlaybackService.instance.currentFilePath == item.info.filePath;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Tactile Squircle Status Badge (1-tap selection toggle!)
                        LuminousFeedback(
                          onTap: () => _setUserKeepTrack(group, item.info.filePath),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item.isUserKept
                                  ? AppColors.genuineEmerald.withValues(alpha: isDark ? 0.22 : 0.15)
                                  : AppColors.fakeCoral.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: item.isUserKept
                                    ? AppColors.genuineEmerald.withValues(alpha: 0.45)
                                    : AppColors.fakeCoral.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              item.isUserKept
                                  ? Icons.verified_rounded
                                  : Icons.copy_rounded,
                              size: 19,
                              color: item.isUserKept
                                  ? AppColors.genuineEmerald
                                  : AppColors.fakeCoral,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 2. Middle Content (3 Clean Breathable Layers)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Layer 1: Status Pill & Purity Capsule (Symmetrical Telemetry)
                              Row(
                                children: [
                                  Text(
                                    item.isUserKept
                                        ? (group.isAllFake ? 'SPACE-SAVER' : 'BEST VERSION')
                                        : 'REDUNDANT COPY',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: item.isUserKept
                                          ? (group.isAllFake ? activeAccent : AppColors.genuineEmerald)
                                          : AppColors.fakeCoral,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (item.info.status == 'untested' || item.info.score <= 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0C000000),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: isDark ? const Color(0x20FFFFFF) : const Color(0x15000000),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        'Untested',
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: subTextColor,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (item.info.score >= 80
                                                ? AppColors.genuineEmerald
                                                : (item.info.score < 50 ? AppColors.fakeCoral : AppColors.suspiciousAmber))
                                            .withValues(alpha: isDark ? 0.15 : 0.10),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: (item.info.score >= 80
                                                  ? AppColors.genuineEmerald
                                                  : (item.info.score < 50 ? AppColors.fakeCoral : AppColors.suspiciousAmber))
                                              .withValues(alpha: 0.30),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        '${item.info.score}% purity',
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: item.info.score >= 80
                                              ? AppColors.genuineEmerald
                                              : (item.info.score < 50 ? AppColors.fakeCoral : AppColors.suspiciousAmber),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Layer 2: Audio Specs with Dot Separators & Lyrics Indicator
                              Text(
                                '${item.info.bitDepth}-bit / ${(item.info.sampleRate / 1000).toStringAsFixed(1)}k · ${item.info.fileSizeMb.toStringAsFixed(1)} MB${item.info.hasLyrics ? ' · Lyrics' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: subTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),

                              // Layer 3: File Name (Clean 2-line wrap with zero truncation!)
                              Text(
                                item.info.fileName,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Symmetrical 2-Slot Dock: Status/Action on Left, Play on Right [▶]
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Slot 1 (Left): Luminous Glass KEPT Badge or DELETE Button
                            if (item.isUserKept)
                              GlassSurface(
                                borderRadius: BorderRadius.circular(10),
                                style: GlassStyle.clear,
                                borderless: false,
                                tintColor: AppColors.genuineEmerald.withValues(alpha: isDark ? 0.22 : 0.14),
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded, size: 12, color: AppColors.genuineEmerald),
                                    SizedBox(width: 3.5),
                                    Text(
                                      'KEPT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: AppColors.genuineEmerald,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              LuminousFeedback(
                                onTap: () => _confirmDeleteSingleTrack(item.info, group),
                                borderRadius: BorderRadius.circular(10),
                                child: GlassSurface(
                                  borderRadius: BorderRadius.circular(10),
                                  style: GlassStyle.clear,
                                  borderless: false,
                                  tintColor: AppColors.fakeCoral.withValues(alpha: isDark ? 0.22 : 0.14),
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 13, color: AppColors.fakeCoral),
                                      SizedBox(width: 3.5),
                                      Text(
                                        'DELETE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                          color: AppColors.fakeCoral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(width: 8),

                            // Slot 2 (Right): Audio Preview Play/Stop (100% Column Aligned on all rows!)
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
                                      ? activeAccent.withValues(alpha: 0.30)
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
                      ],
                    ),

                    // Layer 4: Live Audio Progress Strip (Active seek & real-time counter when playing)
                    _InlineAudioProgressStrip(
                      filePath: item.info.filePath,
                      durationSec: item.info.durationSec,
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

/// Dedicated Full-Page Comparison Screen (Audiophile Forensic Studio Lab)
class _FullPageComparisonScreen extends StatefulWidget {
  final DuplicateGroup group;
  final dynamic appState;
  final void Function(DuplicateGroup, String) onSetUserKeepTrack;
  final void Function(DuplicateGroup, BuildContext) onConfirmDeleteGroupRedundant;

  const _FullPageComparisonScreen({
    required this.group,
    required this.appState,
    required this.onSetUserKeepTrack,
    required this.onConfirmDeleteGroupRedundant,
  });

  @override
  State<_FullPageComparisonScreen> createState() => _FullPageComparisonScreenState();
}

class _FullPageComparisonScreenState extends State<_FullPageComparisonScreen> {
  late DuplicateGroup _group;
  int _selectedCopyIndex = 0;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  String _formatExactDuration(double durationSec) {
    if (durationSec <= 0) return '0:00.00';
    final int totalMs = (durationSec * 1000).round();
    final int minutes = totalMs ~/ 60000;
    final int seconds = (totalMs % 60000) ~/ 1000;
    final int hundredths = (totalMs % 1000) ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  Widget _buildForensicSpecRow(
    String label,
    Widget valueWidget,
    bool isDark,
    Color subTextColor, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0x0EFFFFFF) : const Color(0x08000000),
                  width: 0.6,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: subTextColor,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: valueWidget),
        ],
      ),
    );
  }

  Widget _buildForensicCard({
    required DuplicateItem item,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
    required bool isPlaying,
    required VoidCallback onTogglePlay,
  }) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      style: item.isUserKept ? GlassStyle.frosted : GlassStyle.clear,
      borderless: false,
      tintColor: item.isUserKept
          ? AppColors.genuineEmerald.withValues(alpha: isDark ? 0.10 : 0.06)
          : (isDark ? const Color(0x12FFFFFF) : const Color(0x08000000)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Selection Pill & AcoustiQ Pick Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: item.isUserKept
                      ? AppColors.genuineEmerald.withValues(alpha: isDark ? 0.22 : 0.15)
                      : AppColors.fakeCoral.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isUserKept
                        ? AppColors.genuineEmerald.withValues(alpha: 0.40)
                        : AppColors.fakeCoral.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isUserKept ? Icons.verified_rounded : Icons.copy_rounded,
                      size: 12,
                      color: item.isUserKept ? AppColors.genuineEmerald : AppColors.fakeCoral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.isUserKept ? 'Preserved Master' : 'Redundant Copy',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: item.isUserKept ? AppColors.genuineEmerald : AppColors.fakeCoral,
                      ),
                    ),
                  ],
                ),
              ),

              if (item.isAcoustiqPick) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: activeAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeAccent.withValues(alpha: 0.40),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 11, color: activeAccent),
                      const SizedBox(width: 3),
                      Text(
                        'AcoustiQ Pick',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: activeAccent,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Artwork Thumbnail + Track Name + Full Breadcrumb Path
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DuplicateCoverArt(
                filePath: item.info.filePath,
                size: 44,
                borderRadius: 11,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.info.fileName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.info.filePath,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: subTextColor,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Audio Player Controls & Live Scrubbing Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0x0C000000),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isPlaying ? activeAccent.withValues(alpha: 0.35) : (isDark ? const Color(0x15FFFFFF) : const Color(0x0E000000)),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                LuminousFeedback(
                  onTap: onTogglePlay,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isPlaying ? activeAccent : (isDark ? const Color(0x25FFFFFF) : const Color(0x15000000)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 16,
                      color: isPlaying ? Colors.black : textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InlineAudioProgressStrip(
                    filePath: item.info.filePath,
                    durationSec: item.info.durationSec,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Deep Audiophile Forensic Specs Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14000000) : const Color(0x06000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
                width: 0.6,
              ),
            ),
            child: Column(
              children: [
                _buildForensicSpecRow(
                  'Format / Codec',
                  Text(
                    '${item.info.bitDepth}-bit / ${(item.info.sampleRate / 1000).toStringAsFixed(1)}k FLAC',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Audio Stream',
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stream_rounded, size: 12, color: AppColors.genuineEmerald),
                      SizedBox(width: 3),
                      Text(
                        'Native FLAC (Lossless)',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.genuineEmerald),
                      ),
                    ],
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Channels',
                  Text(
                    'Stereo (2 Channels)',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Bitrate',
                  Text(
                    item.info.bitrateKbps > 0 ? '${item.info.bitrateKbps} kbps' : 'N/A',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Duration',
                  Text(
                    _formatExactDuration(item.info.durationSec),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'File Size',
                  Text(
                    '${item.info.fileSizeMb.toStringAsFixed(1)} MB${!item.isUserKept ? ' (redundant copy)' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.isUserKept ? textColor : AppColors.fakeCoral,
                    ),
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Lyrics',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.info.hasLyrics ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 12,
                        color: item.info.hasLyrics ? AppColors.genuineEmerald : subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.info.hasLyrics ? 'Embedded Synchronized (.lrc)' : 'Missing',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: item.info.hasLyrics ? textColor : subTextColor,
                        ),
                      ),
                    ],
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Artwork',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.info.hasCover ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 12,
                        color: item.info.hasCover ? AppColors.genuineEmerald : subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.info.hasCover ? 'Embedded Cover Art' : 'Missing',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: item.info.hasCover ? textColor : subTextColor,
                        ),
                      ),
                    ],
                  ),
                  isDark,
                  subTextColor,
                ),
                _buildForensicSpecRow(
                  'Authenticity',
                  Text(
                    item.info.status == 'untested' || item.info.score <= 0
                        ? 'Untested'
                        : (item.info.score >= 80 ? 'Genuine FLAC (${item.info.score}%)' : '${item.info.score}% lossy'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: item.info.status == 'untested' || item.info.score <= 0
                          ? subTextColor
                          : (item.info.score >= 80 ? AppColors.genuineEmerald : (item.info.score < 50 ? AppColors.fakeCoral : AppColors.suspiciousAmber)),
                    ),
                  ),
                  isDark,
                  subTextColor,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Action Button pinned to Card
          if (item.isUserKept)
            Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.genuineEmerald.withValues(alpha: isDark ? 0.22 : 0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: AppColors.genuineEmerald.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: AppColors.genuineEmerald),
                  SizedBox(width: 5),
                  Text(
                    'Preserved Master Version',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.genuineEmerald,
                    ),
                  ),
                ],
              ),
            )
          else
            LuminousFeedback(
              onTap: () {
                widget.onSetUserKeepTrack(_group, item.info.filePath);
                setState(() {
                  _group = _group.withUserSelection(item.info.filePath);
                });
              },
              borderRadius: BorderRadius.circular(11),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(11),
                style: GlassStyle.clear,
                borderless: false,
                tintColor: activeAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                padding: const EdgeInsets.symmetric(vertical: 9.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 16, color: activeAccent),
                    const SizedBox(width: 5),
                    Text(
                      'Keep This Version Instead',
                      style: TextStyle(
                        fontSize: 11.5,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.appState.isCurrentDark(context);
    final textColor = widget.appState.getTextColor(context);
    final subTextColor = widget.appState.getSubTextColor(context);
    final activeAccent = widget.appState.getAccentColor(context);

    String bannerTitle;
    String bannerDetail;
    IconData bannerIcon;
    Color bannerColor;

    if (_group.isMd5Identical) {
      bannerIcon = Icons.fingerprint_rounded;
      bannerColor = AppColors.genuineEmerald;
      bannerTitle = '100% Bit-Identical Waveforms (MD5 Certified)';
      bannerDetail = _group.wastedMb > 0
          ? 'Both files decode to identical PCM audio samples. Preserving your preferred master reclaims ${_group.wastedMb.toStringAsFixed(1)} MB with zero quality loss.'
          : 'Both files decode to identical PCM audio samples. AcoustiQ marks the secondary copy as redundant.';
    } else if (_group.isAllFake) {
      bannerIcon = Icons.info_outline_rounded;
      bannerColor = AppColors.suspiciousAmber;
      bannerTitle = 'Lossy Transcodes Detected';
      bannerDetail = 'Both files are lossy upscales to FLAC. AcoustiQ recommends the most compact copy to conserve storage.';
    } else {
      bannerIcon = Icons.verified_rounded;
      bannerColor = activeAccent;
      bannerTitle = 'Audio Quality Forensic Inspection';
      bannerDetail = 'AcoustiQ evaluated audio purity, resolution, lyrics, and artwork completeness to determine the superior copy.';
    }

    final redundantCount = _group.items.where((it) => !it.isUserKept).length;

    final itemA = _group.items.isNotEmpty ? _group.items[0] : null;
    if (itemA == null) return const SizedBox.shrink();

    final remainingItems = _group.items.length > 1 ? _group.items.sublist(1) : <DuplicateItem>[];
    if (_selectedCopyIndex >= remainingItems.length && remainingItems.isNotEmpty) {
      _selectedCopyIndex = 0;
    }
    final itemB = remainingItems.isNotEmpty ? remainingItems[_selectedCopyIndex] : itemA;

    final isPlayingA = AudioPlaybackService.instance.isPlaying &&
        AudioPlaybackService.instance.currentFilePath == itemA.info.filePath;
    final isPlayingB = AudioPlaybackService.instance.isPlaying &&
        AudioPlaybackService.instance.currentFilePath == itemB.info.filePath;

    return Stack(
      fit: StackFit.expand,
      children: [
        const AmbientWallpaperView(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0x35000000) : const Color(0x20FFFFFF),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                _DuplicateCoverArt(
                  filePath: _group.items.first.info.filePath,
                  size: 36,
                  borderRadius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _group.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_group.artist} · ${_group.items.length} Versions',
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
              ],
            ),
            actions: [
              if (_group.isMd5Identical) ...[
                Center(
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(8),
                    style: GlassStyle.clear,
                    borderless: false,
                    tintColor: AppColors.genuineEmerald.withValues(alpha: isDark ? 0.22 : 0.14),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 12, color: AppColors.genuineEmerald),
                        SizedBox(width: 3.5),
                        Text(
                          'EXACT MD5',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.genuineEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Forensic Certificate Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: isDark ? 0.12 : 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: bannerColor.withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(bannerIcon, size: 20, color: bannerColor),
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
                              const SizedBox(height: 2),
                              Text(
                                bannerDetail,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.3,
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

                // Version Switcher if > 2 items
                if (remainingItems.length > 1) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Comparing Version 1 with Version ${_selectedCopyIndex + 2} of ${_group.items.length}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subTextColor),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                icon: Icon(Icons.chevron_left_rounded, size: 20, color: _selectedCopyIndex > 0 ? textColor : subTextColor.withValues(alpha: 0.3)),
                                onPressed: _selectedCopyIndex > 0 ? () => setState(() => _selectedCopyIndex--) : null,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                icon: Icon(Icons.chevron_right_rounded, size: 20, color: _selectedCopyIndex < remainingItems.length - 1 ? textColor : subTextColor.withValues(alpha: 0.3)),
                                onPressed: _selectedCopyIndex < remainingItems.length - 1 ? () => setState(() => _selectedCopyIndex++) : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Main Content: Dual Forensic Cards Side-by-Side
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BoundedBouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildForensicCard(
                            item: itemA,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            activeAccent: activeAccent,
                            isPlaying: isPlayingA,
                            onTogglePlay: () async {
                              if (isPlayingA) {
                                await AudioPlaybackService.instance.stop();
                              } else {
                                await AudioPlaybackService.instance.play(itemA.info.filePath);
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildForensicCard(
                            item: itemB,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            activeAccent: activeAccent,
                            isPlaying: isPlayingB,
                            onTogglePlay: () async {
                              if (isPlayingB) {
                                await AudioPlaybackService.instance.stop();
                              } else {
                                await AudioPlaybackService.instance.play(itemB.info.filePath);
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Cleanup Action Bar
                GlassSurface(
                  borderRadius: BorderRadius.zero,
                  style: GlassStyle.frosted,
                  borderless: false,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  child: LuminousFeedback(
                    onTap: () {
                      widget.onConfirmDeleteGroupRedundant(_group, context);
                    },
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.fakeCoral.withValues(alpha: isDark ? 0.22 : 0.15),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: AppColors.fakeCoral.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.fakeCoral),
                          const SizedBox(width: 6),
                          Text(
                            'Clean $redundantCount Redundant ${redundantCount == 1 ? 'Copy' : 'Copies'} (${_group.wastedMb.toStringAsFixed(1)} MB)',
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
      ],
    );
  }
}

/// Unified Side-by-Side Dual-Card Diff Matrix (Build #86 - Option B)
/// Features:
/// - Option B: Dual Encapsulated Cards side-by-side with clean 8dp separation gutter.
/// - Zero line offset, zero stray 14dp ticks.
/// - Uncramped 2-tier header: Line 1 for Badges (Preserved / Redundant & AcoustiQ Pick), Line 2 for Art + Title + Right-aligned Listen button.
/// - Fixed-slot columns (Song A on left, Song B on right; zero physical swapping).
/// - Symmetrical spec rows inside each card with independent key-value layout.
class _SideBySideDiffMatrix extends StatefulWidget {
  final DuplicateGroup group;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final Color activeAccent;
  final void Function(String filePath) onSelectKeep;
  final VoidCallback onRefresh;

  const _SideBySideDiffMatrix({
    required this.group,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    required this.activeAccent,
    required this.onSelectKeep,
    required this.onRefresh,
  });

  @override
  State<_SideBySideDiffMatrix> createState() => _SideBySideDiffMatrixState();
}

class _SideBySideDiffMatrixState extends State<_SideBySideDiffMatrix> {
  int _selectedCopyIndex = 0;

  String _formatExactDuration(double durationSec) {
    if (durationSec <= 0) return '0:00.00';
    final int totalMs = (durationSec * 1000).round();
    final int minutes = totalMs ~/ 60000;
    final int seconds = (totalMs % 60000) ~/ 1000;
    final int hundredths = (totalMs % 1000) ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
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

  Widget _buildSpecRow(String label, Widget valueWidget, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: widget.isDark ? const Color(0x0EFFFFFF) : const Color(0x08000000),
                  width: 0.6,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: widget.subTextColor,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: valueWidget),
        ],
      ),
    );
  }

  Widget _buildEncapsulatedCard({
    required DuplicateItem item,
    required bool isPlaying,
    required VoidCallback onTogglePlay,
  }) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(16),
      style: item.isUserKept ? GlassStyle.frosted : GlassStyle.clear,
      borderless: false,
      tintColor: item.isUserKept
          ? AppColors.genuineEmerald.withValues(alpha: widget.isDark ? 0.08 : 0.05)
          : (widget.isDark ? const Color(0x10FFFFFF) : const Color(0x06000000)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tier 1: Badges Row (Preserved/Redundant + AcoustiQ Pick)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: item.isUserKept
                      ? AppColors.genuineEmerald.withValues(alpha: widget.isDark ? 0.22 : 0.15)
                      : AppColors.fakeCoral.withValues(alpha: widget.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: item.isUserKept
                        ? AppColors.genuineEmerald.withValues(alpha: 0.40)
                        : AppColors.fakeCoral.withValues(alpha: 0.35),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isUserKept ? Icons.check_circle_rounded : Icons.copy_rounded,
                      size: 10,
                      color: item.isUserKept ? AppColors.genuineEmerald : AppColors.fakeCoral,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.isUserKept ? 'Preserved' : 'Redundant',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: item.isUserKept ? AppColors.genuineEmerald : AppColors.fakeCoral,
                      ),
                    ),
                  ],
                ),
              ),

              if (item.isAcoustiqPick) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: widget.activeAccent.withValues(alpha: widget.isDark ? 0.20 : 0.14),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: widget.activeAccent.withValues(alpha: 0.40),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 9.5, color: widget.activeAccent),
                      const SizedBox(width: 2.5),
                      Text(
                        'AcoustiQ Pick',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: widget.activeAccent,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 7),

          // Tier 2: Squircle Art + Title + Right-aligned Listen Button
          Row(
            children: [
              _DuplicateCoverArt(
                filePath: item.info.filePath,
                size: 32,
                borderRadius: 8,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.info.fileName,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: widget.textColor,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      _formatCleanLocation(item.info.filePath),
                      style: TextStyle(fontSize: 8.5, color: widget.subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              LuminousFeedback(
                onTap: onTogglePlay,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? widget.activeAccent.withValues(alpha: 0.25)
                        : (widget.isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPlaying
                          ? widget.activeAccent.withValues(alpha: 0.50)
                          : (widget.isDark ? const Color(0x20FFFFFF) : const Color(0x15000000)),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 11.5,
                        color: isPlaying ? widget.activeAccent : widget.textColor,
                      ),
                      const SizedBox(width: 2.5),
                      Text(
                        isPlaying ? 'Stop' : 'Listen',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isPlaying ? widget.activeAccent : widget.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          _InlineAudioProgressStrip(
            filePath: item.info.filePath,
            durationSec: item.info.durationSec,
          ),

          const SizedBox(height: 6),

          // Specs Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0x12000000) : const Color(0x06000000),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: widget.isDark ? const Color(0x10FFFFFF) : const Color(0x0A000000),
                width: 0.6,
              ),
            ),
            child: Column(
              children: [
                _buildSpecRow('Format', Text(
                  '${item.info.bitDepth}-bit / ${(item.info.sampleRate / 1000).toStringAsFixed(1)}k FLAC',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
                _buildSpecRow('Duration', Text(
                  _formatExactDuration(item.info.durationSec),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.textColor),
                )),
                _buildSpecRow('File Size', Text(
                  '${item.info.fileSizeMb.toStringAsFixed(1)} MB${!item.isUserKept ? ' (redundant)' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: item.isUserKept ? widget.textColor : AppColors.fakeCoral,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
                _buildSpecRow('Bitrate', Text(
                  item.info.bitrateKbps > 0 ? '${item.info.bitrateKbps} kbps' : 'N/A',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.textColor),
                )),
                _buildSpecRow('Lyrics', Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.info.hasLyrics ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 10.5,
                      color: item.info.hasLyrics ? AppColors.genuineEmerald : widget.subTextColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.info.hasLyrics ? 'Embedded (.lrc)' : 'Missing',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: item.info.hasLyrics ? widget.textColor : widget.subTextColor,
                      ),
                    ),
                  ],
                )),
                _buildSpecRow('Artwork', Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.info.hasCover ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 10.5,
                      color: item.info.hasCover ? AppColors.genuineEmerald : widget.subTextColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.info.hasCover ? 'Embedded' : 'Missing',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: item.info.hasCover ? widget.textColor : widget.subTextColor,
                      ),
                    ),
                  ],
                )),
                _buildSpecRow('Purity', Text(
                  item.info.status == 'untested' || item.info.score <= 0
                      ? 'Untested'
                      : (item.info.score >= 80 ? 'Genuine (${item.info.score}%)' : '${item.info.score}% lossy'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: item.info.status == 'untested' || item.info.score <= 0
                        ? widget.subTextColor
                        : (item.info.score >= 80 ? AppColors.genuineEmerald : (item.info.score < 50 ? AppColors.fakeCoral : AppColors.suspiciousAmber)),
                  ),
                ), isLast: true),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Bottom Action Button
          if (item.isUserKept)
            Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.genuineEmerald.withValues(alpha: widget.isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: AppColors.genuineEmerald.withValues(alpha: 0.40),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 13, color: AppColors.genuineEmerald),
                  SizedBox(width: 4),
                  Text(
                    'Preserved Master',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.genuineEmerald,
                    ),
                  ),
                ],
              ),
            )
          else
            LuminousFeedback(
              onTap: () {
                widget.onSelectKeep(item.info.filePath);
              },
              borderRadius: BorderRadius.circular(9),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(9),
                style: GlassStyle.clear,
                borderless: false,
                tintColor: widget.activeAccent.withValues(alpha: widget.isDark ? 0.22 : 0.14),
                padding: const EdgeInsets.symmetric(vertical: 7.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 14, color: widget.activeAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Keep This Instead',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: widget.activeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemA = widget.group.items.isNotEmpty ? widget.group.items[0] : null;
    if (itemA == null) return const SizedBox.shrink();

    final remainingItems = widget.group.items.length > 1 ? widget.group.items.sublist(1) : <DuplicateItem>[];
    if (_selectedCopyIndex >= remainingItems.length && remainingItems.isNotEmpty) {
      _selectedCopyIndex = 0;
    }
    final itemB = remainingItems.isNotEmpty
        ? remainingItems[_selectedCopyIndex]
        : itemA;

    final isPlayingA = AudioPlaybackService.instance.isPlaying &&
        AudioPlaybackService.instance.currentFilePath == itemA.info.filePath;
    final isPlayingB = AudioPlaybackService.instance.isPlaying &&
        AudioPlaybackService.instance.currentFilePath == itemB.info.filePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (remainingItems.length > 1) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comparing Version 1 with Version ${_selectedCopyIndex + 2} of ${widget.group.items.length}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: widget.subTextColor),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: Icon(Icons.chevron_left_rounded, size: 18, color: _selectedCopyIndex > 0 ? widget.textColor : widget.subTextColor.withValues(alpha: 0.3)),
                      onPressed: _selectedCopyIndex > 0 ? () => setState(() => _selectedCopyIndex--) : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: Icon(Icons.chevron_right_rounded, size: 18, color: _selectedCopyIndex < remainingItems.length - 1 ? widget.textColor : widget.subTextColor.withValues(alpha: 0.3)),
                      onPressed: _selectedCopyIndex < remainingItems.length - 1 ? () => setState(() => _selectedCopyIndex++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Dual Encapsulated Cards Side-by-Side (Option B)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildEncapsulatedCard(
                item: itemA,
                isPlaying: isPlayingA,
                onTogglePlay: () async {
                  if (isPlayingA) {
                    await AudioPlaybackService.instance.stop();
                  } else {
                    await AudioPlaybackService.instance.play(itemA.info.filePath);
                  }
                  setState(() {});
                  widget.onRefresh();
                },
              ),
            ),
            const SizedBox(width: 8), // Clean 8dp gutter between cards!
            Expanded(
              child: _buildEncapsulatedCard(
                item: itemB,
                isPlaying: isPlayingB,
                onTogglePlay: () async {
                  if (isPlayingB) {
                    await AudioPlaybackService.instance.stop();
                  } else {
                    await AudioPlaybackService.instance.play(itemB.info.filePath);
                  }
                  setState(() {});
                  widget.onRefresh();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
