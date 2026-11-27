import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../services/thumbnail_cache.dart';
import 'glass_surface.dart';

/// Playing Queue Sheet ("Up Next") for AudiophilePlayerScreen (Option 1).
/// Shows the offline library queue, active playing indicator, shuffle status, and tap-to-jump.
void showPlayingQueueSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PlayingQueueSheet(),
  );
}

class _PlayingQueueSheet extends StatefulWidget {
  const _PlayingQueueSheet();

  @override
  State<_PlayingQueueSheet> createState() => _PlayingQueueSheetState();
}

class _PlayingQueueSheetState extends State<_PlayingQueueSheet> {
  final AudioPlaybackService _player = AudioPlaybackService.instance;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onChanged);
    appState.addListener(_onChanged);
  }

  @override
  void dispose() {
    _player.removeListener(_onChanged);
    appState.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    final activeTrack = appState.activeTrack;
    final activePath = _player.currentFilePath ?? activeTrack?.filePath;
    final library = appState.sharedLibrary;
    final List<FlacInfo> queueTracks = library.isNotEmpty
        ? library
        : (activeTrack != null ? [activeTrack] : const []);

    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.queue_music_rounded, color: activeAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Playing Queue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '${queueTracks.length} ${queueTracks.length == 1 ? 'track' : 'tracks'} • Local Lossless',
                          style: TextStyle(
                            fontSize: 12,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                      _player.toggleShuffle();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: _player.isShuffle
                            ? activeAccent.withOpacity(0.18)
                            : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _player.isShuffle
                              ? activeAccent.withOpacity(0.45)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shuffle_rounded,
                            size: 14,
                            color: _player.isShuffle ? activeAccent : subTextColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _player.isShuffle ? 'Shuffle On' : 'Shuffle',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _player.isShuffle ? activeAccent : subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
            ),

            // Track Queue List
            Flexible(
              child: queueTracks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.library_music_outlined, size: 34, color: subTextColor),
                          const SizedBox(height: 10),
                          Text(
                            'Queue is empty',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan a FLAC folder in Audit to populate your playback queue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: subTextColor),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                      itemCount: queueTracks.length,
                      itemBuilder: (context, index) {
                        final item = queueTracks[index];
                        final isCurrent = activePath != null && item.filePath == activePath;
                        final fallbackActiveCover = isCurrent ? activeTrack?.coverBytes : null;
                        final title = item.title.isNotEmpty ? item.title : item.fileName;
                        final rateStr = '${(item.sampleRate / 1000).toStringAsFixed(1)}k';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: isCurrent
                                ? activeAccent.withOpacity(isDark ? 0.16 : 0.10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                appState.setActiveTrack(item);
                                _player.play(item.filePath, forceRestart: true);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    _QueueTrackArt(
                                      track: item,
                                      fallbackBytes: fallbackActiveCover,
                                      isCurrent: isCurrent,
                                      isDark: isDark,
                                      activeAccent: activeAccent,
                                      subTextColor: subTextColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  isCurrent ? FontWeight.w700 : FontWeight.w600,
                                              color: isCurrent ? activeAccent : textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.artist} • ${item.bitDepth}b/$rateStr',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: subTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isCurrent)
                                      Icon(
                                        _player.isPlaying
                                            ? Icons.graphic_eq_rounded
                                            : Icons.pause_circle_outline_rounded,
                                        size: 20,
                                        color: activeAccent,
                                      )
                                    else if (item.hasLyrics)
                                      Icon(
                                        Icons.lyrics_outlined,
                                        size: 16,
                                        color: subTextColor.withOpacity(0.75),
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
      ),
    );
  }
}

/// Lazy visible-row artwork loader for Playing Queue.
/// Reads cached RAM bytes immediately, and loads FLAC picture header on-demand when scrolled into view.
class _QueueTrackArt extends StatefulWidget {
  final FlacInfo track;
  final Uint8List? fallbackBytes;
  final bool isCurrent;
  final bool isDark;
  final Color activeAccent;
  final Color subTextColor;

  const _QueueTrackArt({
    required this.track,
    required this.fallbackBytes,
    required this.isCurrent,
    required this.isDark,
    required this.activeAccent,
    required this.subTextColor,
  });

  @override
  State<_QueueTrackArt> createState() => _QueueTrackArtState();
}

class _QueueTrackArtState extends State<_QueueTrackArt> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  @override
  void didUpdateWidget(covariant _QueueTrackArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.filePath != widget.track.filePath ||
        oldWidget.fallbackBytes != widget.fallbackBytes) {
      _resolveCover();
    }
  }

  void _resolveCover() {
    final immediate = widget.track.coverBytes ??
        widget.fallbackBytes ??
        ThumbnailCacheService.instance.getCached(widget.track.filePath);
    if (immediate != null) {
      _bytes = immediate;
      ThumbnailCacheService.instance.put(widget.track.filePath, immediate);
      return;
    }

    _bytes = null;
    if (!widget.track.hasCover || widget.track.filePath.isEmpty) return;

    final path = widget.track.filePath;
    ThumbnailCacheService.instance.getOrLoadCover(path).then((loaded) {
      if (mounted && widget.track.filePath == path && loaded != null) {
        setState(() => _bytes = loaded);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: widget.isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06),
      ),
      clipBehavior: Clip.antiAlias,
      child: _bytes != null
          ? Image.memory(
              _bytes!,
              fit: BoxFit.cover,
              cacheWidth: 120,
              gaplessPlayback: true,
            )
          : Icon(
              Icons.album_rounded,
              size: 22,
              color: widget.isCurrent ? widget.activeAccent : widget.subTextColor,
            ),
    );
  }
}
