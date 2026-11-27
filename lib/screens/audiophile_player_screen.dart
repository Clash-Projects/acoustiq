import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../services/native_audio_service.dart';
import '../services/thumbnail_cache.dart';
import '../ui/theme/colors.dart';
import '../utils/lyrics_parser.dart';
import '../widgets/glass_surface.dart';
import '../widgets/player_lyrics_options_dialog.dart';
import '../widgets/player_lyrics_stage.dart';
import '../widgets/playing_queue_sheet.dart';
import '../widgets/signal_path_sheet.dart';

/// Opens the dedicated full-screen Audiophile Player with a fluid slide-up transition
void openAudiophilePlayerScreen(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AudiophilePlayerScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ),
  );
}

class AudiophilePlayerScreen extends StatefulWidget {
  const AudiophilePlayerScreen({super.key});

  @override
  State<AudiophilePlayerScreen> createState() => _AudiophilePlayerScreenState();
}

class _AudiophilePlayerScreenState extends State<AudiophilePlayerScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlaybackService.instance;
  late final AnimationController _rotationController;

  bool _isDraggingScrubber = false;
  double _dragValue = 0.0;
  bool _hasUsbDac = false;
  String _usbDacName = '';

  // Dedicated LastWave + ClashPlayer Lyrics Modes
  bool _lyricsMode = false;
  bool _lyricsFullscreen = false;
  bool _fsControlsVisible = true;
  Timer? _fsHideTimer;

  // Cached synchronous offline lyrics result
  String? _cachedLyricsKey;
  ParsedLyricsResult _parsedLyrics = const ParsedLyricsResult(kind: LyricsSyncKind.none);

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _player.addListener(_onPlaybackChanged);
    appState.addListener(_onPlaybackChanged);

    if (_player.isPlaying) {
      _rotationController.repeat();
    }

    _loadOutputHardware();
    _ensureLyricsResolved(appState.activeTrack);
    _ensureCoverResolved(appState.activeTrack);
  }

  void _ensureCoverResolved(FlacInfo? track) {
    if (track != null && track.hasCover && track.coverBytes == null) {
      ThumbnailCacheService.instance.getOrLoadCover(track.filePath).then((bytes) {
        if (mounted && bytes != null && appState.activeTrack?.filePath == track.filePath) {
          appState.setActiveTrack(appState.activeTrack!.copyWith(coverBytes: bytes));
          setState(() {});
        }
      });
    }
  }

  void _ensureLyricsResolved(FlacInfo? track) {
    final key = '${track?.filePath ?? ''}|${track?.lyricsText?.hashCode ?? 0}';
    if (_cachedLyricsKey != key) {
      _cachedLyricsKey = key;
      _parsedLyrics = OfflineLyricsParser.resolveForTrack(track);
    }
  }

  Future<void> _loadOutputHardware() async {
    final status = await NativeAudioService.instance.queryEngineStatus();
    if (mounted) {
      final usb = status['hasUsbDac'] == true;
      final dacName = status['usbDacName']?.toString() ?? '';
      setState(() {
        _hasUsbDac = usb;
        _usbDacName = dacName;
      });
    }
  }

  @override
  void dispose() {
    _fsHideTimer?.cancel();
    _player.removeListener(_onPlaybackChanged);
    appState.removeListener(_onPlaybackChanged);
    _rotationController.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    _ensureLyricsResolved(appState.activeTrack);
    if (_player.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!_player.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
    setState(() {});
  }

  void _enterFullscreenLyrics() {
    setState(() {
      _lyricsMode = true;
      _lyricsFullscreen = true;
      _fsControlsVisible = true;
    });
    _scheduleFsHide();
  }

  void _scheduleFsHide() {
    _fsHideTimer?.cancel();
    if (!_lyricsFullscreen) return;
    _fsHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _lyricsFullscreen) {
        setState(() => _fsControlsVisible = false);
      }
    });
  }

  void _revealFsControls() {
    if (!_lyricsFullscreen) return;
    setState(() => _fsControlsVisible = true);
    _scheduleFsHide();
  }

  String _formatTime(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final track = appState.activeTrack;
    _ensureLyricsResolved(track);

    final isPlaying = _player.isPlaying;
    final pos = _player.positionMs;
    final dur = _player.durationMs > 0
        ? _player.durationMs
        : ((track?.durationSec ?? 0) * 1000).toInt();

    final currentPos = _isDraggingScrubber ? (_dragValue * dur).toInt() : pos;
    final progress = (dur > 0) ? (currentPos / dur).clamp(0.0, 1.0) : 0.0;

    final title = track?.title.isNotEmpty == true
        ? track!.title
        : (_player.currentFilePath?.split('/').last ?? 'Lossless Audio Stream');
    final artist = track?.artist.isNotEmpty == true
        ? track!.artist
        : 'Bit-Perfect Playback';
    final album = track?.album.isNotEmpty == true ? track!.album : 'Studio FLAC Master';

    final sampleRateStr = track != null
        ? '${(track.sampleRate / 1000).toStringAsFixed(1)} kHz'
        : '48.0 kHz';
    final bitDepthStr = track != null ? '${track.bitDepth}-bit' : '24-bit';

    final coverBytes = track?.coverBytes ??
        (track != null ? ThumbnailCacheService.instance.getCached(track.filePath) : null);
    final hasCover = track?.hasCover == true && coverBytes != null;
    final activeAccent = appState.getAccentColor(context);
    final hasQueue = appState.sharedLibrary.length > 1;

    return PopScope(
      canPop: !_lyricsFullscreen && !_lyricsMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_lyricsFullscreen) {
          _fsHideTimer?.cancel();
          setState(() => _lyricsFullscreen = false);
        } else if (_lyricsMode) {
          setState(() => _lyricsMode = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0E12),
        body: Stack(
          children: [
            // 0. Ambient Dynamic Artwork Backdrop
            if (coverBytes != null)
              Positioned.fill(
                child: Image.memory(coverBytes, fit: BoxFit.cover),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _lyricsMode ? 65 : 55,
                  sigmaY: _lyricsMode ? 65 : 55,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  color: const Color(0xFF0A0C10).withOpacity(
                    !hasCover
                        ? 1.0
                        : (_lyricsFullscreen
                            ? 0.86
                            : (_lyricsMode ? 0.84 : 0.78)),
                  ),
                ),
              ),
            ),

            // 1. Main Player / Fullscreen Lyrics Body
            SafeArea(
              child: _lyricsFullscreen
                  ? _buildFullscreenLyricsLayout(
                      track: track,
                      title: title,
                      artist: artist,
                      isPlaying: isPlaying,
                      pos: pos,
                      dur: dur,
                      currentPos: currentPos,
                      progress: progress,
                      activeAccent: activeAccent,
                      hasQueue: hasQueue,
                    )
                  : Column(
                      children: [
                        _buildTopAppBar(hasQueue: hasQueue, activeAccent: activeAccent),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 700;
                              if (isWide) {
                                return _buildWideLayout(
                                  constraints: constraints,
                                  track: track,
                                  title: title,
                                  artist: artist,
                                  album: album,
                                  bitDepthStr: bitDepthStr,
                                  sampleRateStr: sampleRateStr,
                                  isPlaying: isPlaying,
                                  pos: pos,
                                  dur: dur,
                                  currentPos: currentPos,
                                  progress: progress,
                                  activeAccent: activeAccent,
                                  hasQueue: hasQueue,
                                );
                              }
                              return _buildPortraitLayout(
                                constraints: constraints,
                                track: track,
                                title: title,
                                artist: artist,
                                album: album,
                                bitDepthStr: bitDepthStr,
                                sampleRateStr: sampleRateStr,
                                isPlaying: isPlaying,
                                pos: pos,
                                dur: dur,
                                currentPos: currentPos,
                                progress: progress,
                                activeAccent: activeAccent,
                                hasQueue: hasQueue,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar({required bool hasQueue, required Color activeAccent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_lyricsFullscreen) {
                _fsHideTimer?.cancel();
                setState(() => _lyricsFullscreen = false);
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(
              _lyricsFullscreen
                  ? Icons.arrow_back_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: _lyricsFullscreen ? 26 : 32,
            ),
            tooltip: _lyricsFullscreen ? 'Back' : 'Minimize Player',
            splashRadius: 24,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _lyricsFullscreen ? 'LYRICS' : 'NOW PLAYING',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'FLAC Lossless',
                  style: TextStyle(
                    color: AppColors.genuineEmerald.withOpacity(0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Option 1: Playing Queue ("Up Next")
          IconButton(
            onPressed: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              showPlayingQueueSheet(context);
            },
            icon: Icon(
              Icons.queue_music_rounded,
              color: hasQueue ? Colors.white.withOpacity(0.90) : Colors.white54,
              size: 24,
            ),
            tooltip: 'Playing Queue',
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout({
    required BoxConstraints constraints,
    required FlacInfo? track,
    required String title,
    required String artist,
    required String album,
    required String bitDepthStr,
    required String sampleRateStr,
    required bool isPlaying,
    required int pos,
    required int dur,
    required int currentPos,
    required double progress,
    required Color activeAccent,
    required bool hasQueue,
  }) {
    final isCompactH = constraints.maxHeight < 620;
    final artSize = isCompactH
        ? 185.0
        : (constraints.maxHeight > 820 ? 265.0 : 230.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        children: [
          // Stage Area: Morphs between Hero Artwork and Dedicated Inline Lyrics
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _lyricsMode
                  ? PlayerLyricsStage(
                      key: ValueKey('inline_${track?.filePath ?? ''}'),
                      track: track,
                      parsed: _parsedLyrics,
                      accentColor: activeAccent,
                      onBackToArtwork: () => setState(() => _lyricsMode = false),
                    )
                  : Center(
                      key: ValueKey('art_${track?.filePath ?? ''}'),
                      child: _buildHeroArtwork(track, isPlaying, size: artSize),
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // Title Row + LastWave-style Quote Button / Morphed Lyrics Actions
          _buildIdentityAndLyricsActionRow(
            track: track,
            title: title,
            artist: artist,
            album: album,
            activeAccent: activeAccent,
          ),

          const SizedBox(height: 12),

          // Single Unified Signal Path Badge (Hidden while reading inline lyrics? No, sleek & compact!)
          if (!_lyricsMode || constraints.maxHeight > 660) ...[
            _buildSignalPathBadge(
              title: title,
              track: track,
              bitDepthStr: bitDepthStr,
              sampleRateStr: sampleRateStr,
            ),
            SizedBox(height: isCompactH ? 10 : 16),
          ],

          // Scrubber + Time Stamps
          _buildScrubber(
            progress: progress,
            currentPos: currentPos,
            dur: dur,
            activeAccent: activeAccent,
          ),

          SizedBox(height: isCompactH ? 8 : 14),

          // 5-Button Transport Bar (Shuffle | Prev | Play/Pause | Next | Repeat)
          _buildTransportRow(
            track: track,
            isPlaying: isPlaying,
            pos: pos,
            dur: dur,
            activeAccent: activeAccent,
            hasQueue: hasQueue,
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout({
    required BoxConstraints constraints,
    required FlacInfo? track,
    required String title,
    required String artist,
    required String album,
    required String bitDepthStr,
    required String sampleRateStr,
    required bool isPlaying,
    required int pos,
    required int dur,
    required int currentPos,
    required double progress,
    required Color activeAccent,
    required bool hasQueue,
  }) {
    final artSize = (constraints.maxHeight * 0.42).clamp(180.0, 290.0);

    if (_lyricsMode) {
      // LastWave Landscape Split: Left = Artwork + Controls, Right = Live Lyrics Panel
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
        child: Row(
          children: [
            Expanded(
              flex: 45,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeroArtwork(track, isPlaying, size: artSize),
                      const SizedBox(height: 18),
                      _buildIdentityAndLyricsActionRow(
                        track: track,
                        title: title,
                        artist: artist,
                        album: album,
                        activeAccent: activeAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildSignalPathBadge(
                        title: title,
                        track: track,
                        bitDepthStr: bitDepthStr,
                        sampleRateStr: sampleRateStr,
                      ),
                      const SizedBox(height: 16),
                      _buildScrubber(
                        progress: progress,
                        currentPos: currentPos,
                        dur: dur,
                        activeAccent: activeAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildTransportRow(
                        track: track,
                        isPlaying: isPlaying,
                        pos: pos,
                        dur: dur,
                        activeAccent: activeAccent,
                        hasQueue: hasQueue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 55,
              child: PlayerLyricsStage(
                track: track,
                parsed: _parsedLyrics,
                accentColor: activeAccent,
                onBackToArtwork: () => setState(() => _lyricsMode = false),
              ),
            ),
          ],
        ),
      );
    }

    // Standard Wide Artwork Mode (centered max-width column)
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _buildPortraitLayout(
          constraints: constraints,
          track: track,
          title: title,
          artist: artist,
          album: album,
          bitDepthStr: bitDepthStr,
          sampleRateStr: sampleRateStr,
          isPlaying: isPlaying,
          pos: pos,
          dur: dur,
          currentPos: currentPos,
          progress: progress,
          activeAccent: activeAccent,
          hasQueue: hasQueue,
        ),
      ),
    );
  }

  Widget _buildFullscreenLyricsLayout({
    required FlacInfo? track,
    required String title,
    required String artist,
    required bool isPlaying,
    required int pos,
    required int dur,
    required int currentPos,
    required double progress,
    required Color activeAccent,
    required bool hasQueue,
  }) {
    return Column(
      children: [
        AnimatedOpacity(
          opacity: _fsControlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !_fsControlsVisible,
            child: _buildTopAppBar(hasQueue: hasQueue, activeAccent: activeAccent),
          ),
        ),
        // Compact Track Identity Header in Fullscreen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: PlayerLyricsStage(
              track: track,
              parsed: _parsedLyrics,
              accentColor: activeAccent,
              isFullscreen: true,
              onBackToArtwork: () => setState(() {
                _lyricsFullscreen = false;
                _lyricsMode = false;
              }),
              onTapStage: _revealFsControls,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _fsControlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !_fsControlsVisible,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScrubber(
                    progress: progress,
                    currentPos: currentPos,
                    dur: dur,
                    activeAccent: activeAccent,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircularGlassIconButton(
                        icon: Icons.fullscreen_exit_rounded,
                        tooltip: 'Exit Fullscreen',
                        size: 42,
                        onTap: () {
                          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                          _fsHideTimer?.cancel();
                          setState(() => _lyricsFullscreen = false);
                        },
                      ),
                      Row(
                        children: [
                          _CircularGlassIconButton(
                            icon: hasQueue ? Icons.skip_previous_rounded : Icons.replay_10_rounded,
                            tooltip: hasQueue ? 'Previous' : 'Rewind 10s',
                            size: 44,
                            onTap: () {
                              if (appState.hapticsEnabled) HapticFeedback.lightImpact();
                              _revealFsControls();
                              if (hasQueue) {
                                _player.playPrevious();
                              } else {
                                _player.seek((pos - 10000).clamp(0, dur));
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                              _revealFsControls();
                              final path = track?.filePath ?? _player.currentFilePath;
                              if (path != null) _player.play(path);
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF1F5F9),
                              ),
                              child: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _CircularGlassIconButton(
                            icon: hasQueue ? Icons.skip_next_rounded : Icons.forward_10_rounded,
                            tooltip: hasQueue ? 'Next' : 'Forward 10s',
                            size: 44,
                            onTap: () {
                              if (appState.hapticsEnabled) HapticFeedback.lightImpact();
                              _revealFsControls();
                              if (hasQueue) {
                                _player.playNext();
                              } else {
                                _player.seek((pos + 10000).clamp(0, dur));
                              }
                            },
                          ),
                        ],
                      ),
                      _CircularGlassIconButton(
                        icon: Icons.more_vert_rounded,
                        tooltip: 'Lyrics Options',
                        size: 42,
                        onTap: () {
                          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                          _fsHideTimer?.cancel();
                          showPlayerLyricsOptionsDialog(
                            context,
                            track: track,
                            parsed: _parsedLyrics,
                          ).then((_) {
                            if (mounted) _scheduleFsHide();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityAndLyricsActionRow({
    required FlacInfo? track,
    required String title,
    required String artist,
    required String album,
    required Color activeAccent,
  }) {
    final hasAnyLyrics = _parsedLyrics.hasLyrics;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$artist • $album',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // LastWave-style Title-Side Quote Toggle -> Morphs into Artwork/Fullscreen/Options
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(anim), child: child),
          ),
          child: _lyricsMode
              ? Row(
                  key: const ValueKey('lyricsActionsPair'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircularGlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Show Artwork',
                      size: 38,
                      onTap: () {
                        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                        setState(() => _lyricsMode = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    _CircularGlassIconButton(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Fullscreen Lyrics',
                      size: 38,
                      onTap: () {
                        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                        _enterFullscreenLyrics();
                      },
                    ),
                    const SizedBox(width: 8),
                    _CircularGlassIconButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: 'Lyrics Options',
                      size: 38,
                      onTap: () {
                        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                        showPlayerLyricsOptionsDialog(
                          context,
                          track: track,
                          parsed: _parsedLyrics,
                        );
                      },
                    ),
                  ],
                )
              : _CircularGlassIconButton(
                  key: const ValueKey('quoteTrigger'),
                  icon: Icons.format_quote_rounded,
                  tooltip: 'Show Lyrics',
                  size: 44,
                  iconSize: 23,
                  tintColor: hasAnyLyrics ? activeAccent.withOpacity(0.18) : null,
                  iconColor: hasAnyLyrics ? Colors.white : Colors.white60,
                  onTap: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    setState(() => _lyricsMode = true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSignalPathBadge({
    required String title,
    required FlacInfo? track,
    required String bitDepthStr,
    required String sampleRateStr,
  }) {
    final badgeText = _hasUsbDac && _usbDacName.isNotEmpty
        ? '$_usbDacName • $bitDepthStr / $sampleRateStr'
        : 'Bit-Perfect • $bitDepthStr / $sampleRateStr';

    return GestureDetector(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.lightImpact();
        showSignalPathSheet(
          context,
          trackTitle: title,
          sampleRate: track?.sampleRate ?? 48000,
          bitDepth: track?.bitDepth ?? 16,
        );
      },
      child: GlassSurface(
        style: GlassStyle.frosted,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _hasUsbDac ? Icons.usb_rounded : Icons.bolt_rounded,
                color: _hasUsbDac ? const Color(0xFFFFD700) : AppColors.genuineEmerald,
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  badgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _hasUsbDac ? const Color(0xFFFFD700) : AppColors.genuineEmerald,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrainsMono',
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: (_hasUsbDac ? const Color(0xFFFFD700) : AppColors.genuineEmerald)
                    .withOpacity(0.60),
                size: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrubber({
    required double progress,
    required int currentPos,
    required int dur,
    required Color activeAccent,
  }) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            activeTrackColor: activeAccent,
            inactiveTrackColor: Colors.white.withOpacity(0.14),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: progress,
            onChangeStart: (_) => setState(() => _isDraggingScrubber = true),
            onChanged: (val) => setState(() => _dragValue = val),
            onChangeEnd: (val) {
              setState(() => _isDraggingScrubber = false);
              if (dur > 0) {
                _player.seek((val * dur).toInt());
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(currentPos),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11.5,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              Text(
                _formatTime(dur),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11.5,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransportRow({
    required FlacInfo? track,
    required bool isPlaying,
    required int pos,
    required int dur,
    required Color activeAccent,
    required bool hasQueue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Shuffle Toggle
        IconButton(
          onPressed: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            _player.toggleShuffle();
          },
          icon: Icon(
            Icons.shuffle_rounded,
            size: 21,
            color: _player.isShuffle ? activeAccent : Colors.white.withOpacity(0.50),
          ),
          tooltip: 'Shuffle',
        ),

        // 2. Previous Track / -10s
        _CircularGlassIconButton(
          icon: hasQueue ? Icons.skip_previous_rounded : Icons.replay_10_rounded,
          tooltip: hasQueue ? 'Previous Track' : 'Rewind 10s',
          size: 48,
          iconSize: 26,
          onTap: () {
            if (appState.hapticsEnabled) HapticFeedback.lightImpact();
            if (hasQueue) {
              _player.playPrevious();
            } else {
              _player.seek((pos - 10000).clamp(0, dur));
            }
          },
        ),

        // 3. Main Play / Pause Button
        GestureDetector(
          onTap: () {
            if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
            final path = track?.filePath ?? _player.currentFilePath;
            if (path != null) {
              _player.play(path);
            }
          },
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1F5F9),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.20),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 36,
              ),
            ),
          ),
        ),

        // 4. Next Track / +10s
        _CircularGlassIconButton(
          icon: hasQueue ? Icons.skip_next_rounded : Icons.forward_10_rounded,
          tooltip: hasQueue ? 'Next Track' : 'Forward 10s',
          size: 48,
          iconSize: 26,
          onTap: () {
            if (appState.hapticsEnabled) HapticFeedback.lightImpact();
            if (hasQueue) {
              _player.playNext();
            } else {
              _player.seek((pos + 10000).clamp(0, dur));
            }
          },
        ),

        // 5. Repeat Toggle (Off -> All -> One)
        IconButton(
          onPressed: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            _player.toggleRepeat();
          },
          icon: Icon(
            _player.repeatMode == PlaybackRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 21,
            color: _player.repeatMode != PlaybackRepeatMode.off
                ? activeAccent
                : Colors.white.withOpacity(0.50),
          ),
          tooltip: 'Repeat',
        ),
      ],
    );
  }

  Widget _buildHeroArtwork(FlacInfo? track, bool isPlaying, {double size = 225}) {
    final coverBytes = track?.coverBytes ??
        (track != null ? ThumbnailCacheService.instance.getCached(track.filePath) : null);

    if (coverBytes != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
          image: DecorationImage(
            image: MemoryImage(coverBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // High-End Studio Vinyl Platter with Concentric Grooves
    return RotationTransition(
      turns: _rotationController,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A0C10),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.70),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.84,
              height: size * 0.84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
              ),
            ),
            Container(
              width: size * 0.66,
              height: size * 0.66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
              ),
            ),
            Container(
              width: size * 0.48,
              height: size * 0.48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.10), width: 0.8),
              ),
            ),
            Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPrimary.withOpacity(0.90),
                border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.0),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularGlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color? tintColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircularGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.iconSize = 21,
    this.tintColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          style: GlassStyle.frosted,
          borderRadius: BorderRadius.circular(size / 2),
          tintColor: tintColor,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                icon,
                color: iconColor ?? Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
