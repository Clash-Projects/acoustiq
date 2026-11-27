import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../utils/lyrics_parser.dart';
import 'glass_surface.dart';

/// Dedicated Player Lyrics Stage combining LastWave's style/sync-badge architecture
/// with ClashPlayer's 60fps interpolated sweep, breathing interlude dots, and soft edge fades.
/// Strictly 100% offline: immediately displays Synced, Plain, Instrumental, or No Lyrics.
class PlayerLyricsStage extends StatefulWidget {
  final FlacInfo? track;
  final ParsedLyricsResult parsed;
  final Color accentColor;
  final VoidCallback onBackToArtwork;
  final bool isFullscreen;
  final VoidCallback? onTapStage;

  const PlayerLyricsStage({
    super.key,
    required this.track,
    required this.parsed,
    required this.accentColor,
    required this.onBackToArtwork,
    this.isFullscreen = false,
    this.onTapStage,
  });

  @override
  State<PlayerLyricsStage> createState() => _PlayerLyricsStageState();
}

class _PlayerLyricsStageState extends State<PlayerLyricsStage>
    with SingleTickerProviderStateMixin {
  final AudioPlaybackService _player = AudioPlaybackService.instance;
  late final Ticker _ticker;

  int _lastRawPosMs = 0;
  DateTime _anchorWall = DateTime.now();
  final ValueNotifier<int> _smoothPosNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _lastRawPosMs = _player.positionMs;
    _anchorWall = DateTime.now();
    _smoothPosNotifier.value = _effectivePos(_lastRawPosMs);

    _ticker = createTicker(_onTick);
    _player.addListener(_onPlayerUpdate);
    appState.addListener(_onSettingsUpdate);
    _syncTickerState();
  }

  @override
  void didUpdateWidget(covariant PlayerLyricsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parsed.kind != widget.parsed.kind ||
        oldWidget.track?.filePath != widget.track?.filePath) {
      _lastRawPosMs = _player.positionMs;
      _anchorWall = DateTime.now();
      _smoothPosNotifier.value = _effectivePos(_lastRawPosMs);
      _syncTickerState();
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerUpdate);
    appState.removeListener(_onSettingsUpdate);
    _ticker.dispose();
    _smoothPosNotifier.dispose();
    super.dispose();
  }

  int _effectivePos(int rawMs) {
    return rawMs + appState.lyricsOffsetMs - widget.parsed.parsedOffsetMs;
  }

  void _onSettingsUpdate() {
    if (!mounted) return;
    _smoothPosNotifier.value = _effectivePos(_lastRawPosMs);
    setState(() {});
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final pos = _player.positionMs;
    if (pos != _lastRawPosMs) {
      _lastRawPosMs = pos;
      _anchorWall = DateTime.now();
      _smoothPosNotifier.value = _effectivePos(pos);
    }
    _syncTickerState();
  }

  void _syncTickerState() {
    final shouldTick = _player.isPlaying && widget.parsed.isSynced;
    if (shouldTick && !_ticker.isActive) {
      _anchorWall = DateTime.now();
      _ticker.start();
    } else if (!shouldTick && _ticker.isActive) {
      _ticker.stop();
      _smoothPosNotifier.value = _effectivePos(_player.positionMs);
    }
  }

  void _onTick(Duration _) {
    if (!_player.isPlaying) return;
    final elapsedMs = DateTime.now().difference(_anchorWall).inMilliseconds.clamp(0, 380);
    _smoothPosNotifier.value = _effectivePos(_lastRawPosMs + elapsedMs);
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.parsed.kind;
    final fontScale = appState.lyricsFontScale;
    final centered = appState.lyricsCentered;
    final lyricsStyle = appState.lyricsStyle;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTapStage,
      child: Column(
        children: [
          // Top Unique Sync / State Indicator Badge (LastWave parity)
          if (kind == LyricsSyncKind.wordSynced || kind == LyricsSyncKind.lineSynced)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: _SyncModeBadge(
                isWordSynced: kind == LyricsSyncKind.wordSynced,
              ),
            ),

          Expanded(
            child: switch (kind) {
              LyricsSyncKind.none => _OfflineEmptyLyricsCard(
                  track: widget.track,
                  showBackButton: !widget.isFullscreen,
                  onBackToArtwork: widget.onBackToArtwork,
                ),
              LyricsSyncKind.instrumental => _InstrumentalLyricsCard(
                  track: widget.track,
                  showBackButton: !widget.isFullscreen,
                  onBackToArtwork: widget.onBackToArtwork,
                ),
              LyricsSyncKind.plain => _PlainLyricsView(
                  text: widget.parsed.plainText ?? '',
                  fontScale: fontScale,
                  centered: centered,
                  isRtl: widget.parsed.isRtl,
                ),
              LyricsSyncKind.lineSynced || LyricsSyncKind.wordSynced => _SyncedLyricsList(
                  parsed: widget.parsed,
                  smoothPosNotifier: _smoothPosNotifier,
                  isPlaying: _player.isPlaying,
                  fontScale: fontScale,
                  centered: centered,
                  lyricsStyle: lyricsStyle,
                  isFullscreen: widget.isFullscreen,
                  onSeek: (targetMs) {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    final seekAudioMs = (targetMs - appState.lyricsOffsetMs + widget.parsed.parsedOffsetMs)
                        .clamp(0, _player.durationMs > 0 ? _player.durationMs : 1 << 30);
                    _player.seek(seekAudioMs);
                    if (!_player.isPlaying && widget.track != null) {
                      _player.play(widget.track!.filePath);
                    }
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _SyncModeBadge extends StatelessWidget {
  final bool isWordSynced;

  const _SyncModeBadge({
    required this.isWordSynced,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      style: GlassStyle.frosted,
      borderRadius: BorderRadius.circular(20),
      tintColor: Colors.white.withOpacity(0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWordSynced ? Icons.graphic_eq_rounded : Icons.lyrics_rounded,
              size: 12,
              color: Colors.white.withOpacity(0.90),
            ),
            const SizedBox(width: 6),
            Text(
              isWordSynced ? 'WORD SYNC' : 'LINE SYNC',
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlainLyricsView extends StatelessWidget {
  final String text;
  final double fontScale;
  final bool centered;
  final bool isRtl;

  const _PlainLyricsView({
    required this.text,
    required this.fontScale,
    required this.centered,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.06, 0.88, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 72),
          child: Column(
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              // LastWave-style explicit unsynced indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisAlignment:
                      centered ? MainAxisAlignment.center : MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync_disabled_rounded,
                      size: 15,
                      color: Colors.white.withOpacity(0.86),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Lyrics not time-synced',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Text(
                  text,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    fontSize: 23.5 * fontScale,
                    height: 1.44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white.withOpacity(0.94),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineEmptyLyricsCard extends StatelessWidget {
  final FlacInfo? track;
  final bool showBackButton;
  final VoidCallback onBackToArtwork;

  const _OfflineEmptyLyricsCard({
    required this.track,
    required this.showBackButton,
    required this.onBackToArtwork,
  });

  @override
  Widget build(BuildContext context) {
    final title = track?.title.isNotEmpty == true
        ? track!.title
        : (track?.fileName ?? 'No Track');
    final artist = track?.artist ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Icon(
                Icons.lyrics_outlined,
                size: 28,
                color: Colors.white.withOpacity(0.86),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Embedded Lyrics',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              artist.isNotEmpty ? '$title • $artist' : title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No Vorbis lyrics tags or matching local .lrc file found.\nAcoustiQ runs 100% offline with zero web lookups.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.52),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            if (showBackButton) ...[
              const SizedBox(height: 18),
              GlassSurface(
                style: GlassStyle.frosted,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onBackToArtwork,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.album_rounded, size: 16, color: Colors.white.withOpacity(0.90)),
                        const SizedBox(width: 7),
                        const Text(
                          'Show Artwork',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstrumentalLyricsCard extends StatelessWidget {
  final FlacInfo? track;
  final bool showBackButton;
  final VoidCallback onBackToArtwork;

  const _InstrumentalLyricsCard({
    required this.track,
    required this.showBackButton,
    required this.onBackToArtwork,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded, size: 42, color: Colors.white.withOpacity(0.90)),
            const SizedBox(height: 14),
            const Text(
              'Instrumental',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This track has no vocal lyrics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 14,
              ),
            ),
            if (showBackButton) ...[
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: onBackToArtwork,
                icon: Icon(Icons.album_rounded, size: 17, color: Colors.white.withOpacity(0.90)),
                label: const Text(
                  'Show Artwork',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncedLyricsList extends StatefulWidget {
  final ParsedLyricsResult parsed;
  final ValueNotifier<int> smoothPosNotifier;
  final bool isPlaying;
  final double fontScale;
  final bool centered;
  final String lyricsStyle;
  final bool isFullscreen;
  final ValueChanged<int> onSeek;

  const _SyncedLyricsList({
    required this.parsed,
    required this.smoothPosNotifier,
    required this.isPlaying,
    required this.fontScale,
    required this.centered,
    required this.lyricsStyle,
    required this.isFullscreen,
    required this.onSeek,
  });

  @override
  State<_SyncedLyricsList> createState() => _SyncedLyricsListState();
}

class _SyncedLyricsListState extends State<_SyncedLyricsList> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _rowKeys;
  int _activeIndex = -1;
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isBrowsing = false;

  @override
  void initState() {
    super.initState();
    _rowKeys = List.generate(widget.parsed.lines.length, (_) => GlobalKey());
    _activeIndex = widget.parsed.activeIndexAt(widget.smoothPosNotifier.value);
    widget.smoothPosNotifier.addListener(_onSmoothPos);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive(animate: false));
  }

  @override
  void didUpdateWidget(covariant _SyncedLyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parsed.lines.length != widget.parsed.lines.length ||
        oldWidget.parsed.rawExportText != widget.parsed.rawExportText) {
      _rowKeys = List.generate(widget.parsed.lines.length, (_) => GlobalKey());
      _activeIndex = widget.parsed.activeIndexAt(widget.smoothPosNotifier.value);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive(animate: false));
    }
  }

  @override
  void dispose() {
    widget.smoothPosNotifier.removeListener(_onSmoothPos);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSmoothPos() {
    if (!mounted) return;
    final nextIdx = widget.parsed.activeIndexAt(widget.smoothPosNotifier.value);
    if (nextIdx != _activeIndex) {
      setState(() => _activeIndex = nextIdx);
      _scrollToActive(animate: true);
    }
    if (_isBrowsing) {
      final elapsed = DateTime.now().difference(_lastUserScroll).inMilliseconds;
      final grace = widget.isPlaying ? 3000 : 5000;
      if (elapsed >= grace) {
        setState(() => _isBrowsing = false);
      }
    }
  }

  void _scrollToActive({required bool animate}) {
    if (!mounted || _activeIndex < 0 || _activeIndex >= _rowKeys.length) return;
    final elapsedSinceScroll = DateTime.now().difference(_lastUserScroll).inMilliseconds;
    final graceMs = widget.isPlaying ? 3000 : 5000;
    if (animate && elapsedSinceScroll < graceMs) return;

    final ctx = _rowKeys[_activeIndex].currentContext;
    if (ctx == null) return;

    final alignment = widget.lyricsStyle == 'flow' ? 0.38 : 0.33;
    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: animate ? const Duration(milliseconds: 520) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.parsed.lines;
    final isDirectionRtl = widget.parsed.isRtl;

    return Directionality(
      textDirection: isDirectionRtl ? TextDirection.rtl : TextDirection.ltr,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction != ScrollDirection.idle) {
            _lastUserScroll = DateTime.now();
            if (!_isBrowsing) {
              setState(() => _isBrowsing = true);
            }
          }
          return false;
        },
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.08, 0.87, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              14,
              widget.isFullscreen ? 44 : 26,
              14,
              widget.isFullscreen ? 140 : 96,
            ),
            child: Column(
              crossAxisAlignment:
                  widget.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: List.generate(lines.length, (index) {
                final line = lines[index];
                final isActive = index == _activeIndex;
                final distance = _activeIndex < 0 ? 2 : (index - _activeIndex).abs();
                final isPrev = _activeIndex >= 0 && index < _activeIndex;

                return Container(
                  key: _rowKeys[index],
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: line.isInterlude ? 14 : 18),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSeek(line.timeMs),
                    child: line.isInterlude
                        ? _InterludeDotsRow(
                            line: line,
                            isActive: isActive,
                            centered: widget.centered,
                            smoothPosNotifier: widget.smoothPosNotifier,
                          )
                        : _SyncedLyricLineItem(
                            line: line,
                            isActive: isActive,
                            isPrev: isPrev,
                            distance: distance,
                            isBrowsing: _isBrowsing,
                            lyricsStyle: widget.lyricsStyle,
                            fontScale: widget.fontScale,
                            centered: widget.centered,
                            smoothPosNotifier: widget.smoothPosNotifier,
                          ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncedLyricLineItem extends StatelessWidget {
  final ParsedLyricLine line;
  final bool isActive;
  final bool isPrev;
  final int distance;
  final bool isBrowsing;
  final String lyricsStyle;
  final double fontScale;
  final bool centered;
  final ValueNotifier<int> smoothPosNotifier;

  const _SyncedLyricLineItem({
    required this.line,
    required this.isActive,
    required this.isPrev,
    required this.distance,
    required this.isBrowsing,
    required this.lyricsStyle,
    required this.fontScale,
    required this.centered,
    required this.smoothPosNotifier,
  });

  double _targetAlpha() {
    if (isActive) return 1.0;
    if (isBrowsing) return 0.76;
    if (lyricsStyle == 'halo') {
      if (isPrev) return 0.22;
      const haloFalloff = [0.42, 0.28, 0.18];
      return distance - 1 < haloFalloff.length ? haloFalloff[distance - 1] : 0.14;
    }
    if (lyricsStyle == 'flow') {
      if (isPrev) return 0.34;
      const flowFalloff = [0.54, 0.38, 0.26];
      return distance - 1 < flowFalloff.length ? flowFalloff[distance - 1] : 0.20;
    }
    // Default style
    const defFalloff = [0.52, 0.38, 0.26];
    return distance - 1 < defFalloff.length ? defFalloff[distance - 1] : 0.18;
  }

  double _targetScale() {
    if (isActive) return 1.0;
    if (lyricsStyle == 'flow') return (0.94 - (distance * 0.015)).clamp(0.86, 0.95);
    if (lyricsStyle == 'halo') return 0.94;
    return 0.96;
  }

  double _targetBlurSigma() {
    if (isActive || isBrowsing) return 0.0;
    if (lyricsStyle == 'flow' && isPrev) return 1.6;
    if (lyricsStyle == 'halo') {
      if (isPrev) return 2.2;
      return (distance * 0.85).clamp(0.8, 3.0);
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final baseFont = 25.0 * fontScale;
    final align = centered ? TextAlign.center : TextAlign.start;
    final pivot = centered
        ? Alignment.center
        : (line.isRtl ? Alignment.centerRight : Alignment.centerLeft);

    final targetAlpha = _targetAlpha();
    final targetScale = _targetScale();
    final blurSigma = _targetBlurSigma();

    final textWidget = _buildTextContent(baseFont, align);

    final Widget blurred = blurSigma > 0.1
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: textWidget,
          )
        : textWidget;

    return AnimatedScale(
      scale: targetScale,
      alignment: pivot,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: targetAlpha,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: blurred,
        ),
      ),
    );
  }

  Widget _buildTextContent(double baseFont, TextAlign align) {
    final textStyle = TextStyle(
      fontSize: baseFont,
      height: 1.24,
      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
      letterSpacing: -0.5,
      color: Colors.white,
      shadows: isActive
          ? [
              Shadow(
                color: Colors.white.withOpacity(lyricsStyle == 'flow' ? 0.38 : 0.22),
                blurRadius: lyricsStyle == 'flow' ? 18 : 12,
              ),
            ]
          : null,
    );

    if (!isActive) {
      return SizedBox(
        width: double.infinity,
        child: Text(
          line.text,
          textAlign: align,
          style: textStyle,
        ),
      );
    }

    // Active Line: Pure luminous white karaoke / horizontal sweep
    return ValueListenableBuilder<int>(
      valueListenable: smoothPosNotifier,
      builder: (context, posMs, _) {
        if (line.hasSyllables) {
          return SizedBox(
            width: double.infinity,
            child: Text.rich(
              TextSpan(
                children: line.syllables.map((syl) {
                  final p = ((posMs - syl.timeMs) / syl.durationMs.clamp(1, 100000))
                      .clamp(0.0, 1.0);
                  final sylColor = Color.lerp(
                    Colors.white.withOpacity(0.38),
                    Colors.white,
                    p,
                  )!;
                  return TextSpan(
                    text: syl.text,
                    style: textStyle.copyWith(
                      color: sylColor,
                      shadows: p > 0.05 && p < 0.98
                          ? [
                              Shadow(
                                color: Colors.white.withOpacity(0.45 * p),
                                blurRadius: 14,
                              ),
                            ]
                          : textStyle.shadows,
                    ),
                  );
                }).toList(),
              ),
              textAlign: align,
            ),
          );
        }

        // Line-Synced pure white horizontal luminous sweep across the active lyric
        final lineProg = ((posMs - line.timeMs) / line.durationMs.clamp(400, 100000))
            .clamp(0.0, 1.0);
        final softStop = (lineProg + 0.16).clamp(0.0, 1.0);

        return SizedBox(
          width: double.infinity,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: line.isRtl ? Alignment.centerRight : Alignment.centerLeft,
              end: line.isRtl ? Alignment.centerLeft : Alignment.centerRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.56),
              ],
              stops: [
                (lineProg - 0.04).clamp(0.0, 1.0),
                lineProg,
                softStop,
              ],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              line.text,
              textAlign: align,
              style: textStyle,
            ),
          ),
        );
      },
    );
  }
}

class _InterludeDotsRow extends StatelessWidget {
  final ParsedLyricLine line;
  final bool isActive;
  final bool centered;
  final ValueNotifier<int> smoothPosNotifier;

  const _InterludeDotsRow({
    required this.line,
    required this.isActive,
    required this.centered,
    required this.smoothPosNotifier,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return const SizedBox(height: 8);
    }

    return SizedBox(
      height: 38,
      width: double.infinity,
      child: Align(
        alignment: centered ? Alignment.center : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ValueListenableBuilder<int>(
            valueListenable: smoothPosNotifier,
            builder: (context, posMs, _) {
              final totalMs = line.durationMs.clamp(1000, 120000);
              final elapsedMs = (posMs - line.timeMs).clamp(0, totalMs);
              final timeScale = (elapsedMs / totalMs).clamp(0.0, 1.0);
              final elapsedSec = elapsedMs / 1000.0;
              return CustomPaint(
                size: const Size(64, 28),
                painter: _InterludeDotsPainter(
                  timeScale: timeScale,
                  elapsedSec: elapsedSec,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Beautiful-Lyrics / Spicy-Lyrics 0->1 Pause-Duration Dot Timeline:
/// Divides the entire pause interval across 3 dots (0.925 / 3 each) so every dot
/// lifts smoothly up once, settles glowing at 1.0, and holds with gentle breath
/// until the next vocal line begins. Zero rapid looping.
class _InterludeDotsPainter extends CustomPainter {
  final double timeScale;
  final double elapsedSec;

  _InterludeDotsPainter({
    required this.timeScale,
    required this.elapsedSec,
  });

  double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const int dotCount = 3;
    const double dotStep = 0.925 / dotCount;
    const double baseR = 4.6;
    const double dotSize = 10.0;

    // Gentle container scale breath matching Beautiful-Lyrics (PulseInterval = 2.25s)
    double groupScale = 1.0 + 0.045 * math.sin(elapsedSec * math.pi / 1.125);
    double groupAlpha = 1.0;

    // Subtle pre-vocal anticipation swell & fade-out right at pause end (last 7.5%)
    if (timeScale > 0.925) {
      final tail = ((timeScale - 0.925) / 0.075).clamp(0.0, 1.0);
      groupScale += 0.10 * math.sin(tail * math.pi * 0.65);
      if (tail > 0.78) {
        groupAlpha = 1.0 - _smoothstep(0.78, 1.0, tail) * 0.65;
      }
    }

    final centerY = size.height * 0.56;

    for (int i = 0; i < dotCount; i++) {
      final double dotStart = i * dotStep;
      final double t = ((timeScale - dotStart) / dotStep).clamp(0.0, 1.0);

      // Single lift + settle curve across each dot's 1/3rd pause slot:
      // YOffset: rests slightly low (+0.125) -> lifts smoothly to peak (-0.42) -> settles (0.0)
      final double yFactor = t <= 0.0
          ? 0.125
          : t < 0.52
              ? (0.125 + (-0.42 - 0.125) * _smoothstep(0.0, 0.52, t))
              : (-0.42 + (0.0 - (-0.42)) * _smoothstep(0.52, 1.0, t));

      // Scale: 0.76 -> swells smoothly to 1.08 -> rests at 1.0
      final double dotScale = t < 0.65
          ? (0.76 + (1.08 - 0.76) * _smoothstep(0.0, 0.65, t))
          : (1.08 + (1.0 - 1.08) * _smoothstep(0.65, 1.0, t));

      // Opacity: dims at 0.32 -> lights cleanly to 1.0 by 60% of its turn and stays lit
      final double dotAlpha = (0.32 + 0.68 * _smoothstep(0.0, 0.60, t)) * groupAlpha;

      final double dy = dotSize * yFactor;
      final double r = baseR * dotScale * groupScale;
      final Offset center = Offset(baseR * 1.8 + i * baseR * 4.0, centerY + dy);

      // Soft diffused Gaussian glow ONLY (zero sharp circular outline border!)
      if (t > 0.15) {
        final glow = _smoothstep(0.15, 0.65, t) * groupAlpha;
        canvas.drawCircle(
          center,
          r * 1.25,
          Paint()
            ..color = Colors.white.withOpacity((0.28 * glow).clamp(0.0, 1.0))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
        );
      }

      canvas.drawCircle(
        center,
        r,
        Paint()..color = Colors.white.withOpacity(dotAlpha.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InterludeDotsPainter oldDelegate) {
    return oldDelegate.timeScale != timeScale ||
        oldDelegate.elapsedSec != elapsedSec;
  }
}
