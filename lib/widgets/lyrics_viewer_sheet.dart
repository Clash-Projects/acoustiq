import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';
import 'audio_preview_bar.dart';

/// Shows an Apple WWDC25 Frosted Glass modal bottom sheet displaying
/// embedded Vorbis FLAC lyrics with LastWave-grade dynamic audio auto-scrolling.
void showLyricsViewerSheet(BuildContext context, FlacInfo track) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => LyricsViewerSheet(track: track),
  );
}

class LyricsViewerSheet extends StatefulWidget {
  final FlacInfo track;

  const LyricsViewerSheet({super.key, required this.track});

  @override
  State<LyricsViewerSheet> createState() => _LyricsViewerSheetState();
}

class _LyricsViewerSheetState extends State<LyricsViewerSheet>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final AudioPlaybackService _player = AudioPlaybackService.instance;

  List<_LrcLine> _parsedLines = [];
  bool _isSynced = false;
  int _activeIndex = -1;
  bool _isUserScrolling = false;

  // In-Sheet Toast & Ambient Bottom Glow State
  String? _inSheetToast;
  IconData? _inSheetIcon;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _parseLyrics();
    _player.addListener(_onPositionChanged);
  }

  @override
  void didUpdateWidget(covariant LyricsViewerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) {
      _parseLyrics();
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPositionChanged);
    _scrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _parseLyrics() {
    final rawLyrics = widget.track.lyrics?.trim() ?? '';
    final hasLrcRegex = RegExp(r'\[\d{2}:\d{2}[\.:]\d{2,3}\]').hasMatch(rawLyrics);

    final List<_LrcLine> lines = [];
    bool trulySynced = false;

    if (hasLrcRegex) {
      final rawLines = rawLyrics.split(RegExp(r'\r?\n'));
      final lrcRegex = RegExp(r'\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)');
      for (final l in rawLines) {
        final match = lrcRegex.firstMatch(l.trim());
        if (match != null) {
          final mm = int.tryParse(match.group(1) ?? '0') ?? 0;
          final ss = int.tryParse(match.group(2) ?? '0') ?? 0;
          final msRaw = match.group(3) ?? '0';
          final ms = int.tryParse(msRaw.padRight(3, '0').substring(0, 3)) ?? 0;
          final totalMs = (mm * 60 + ss) * 1000 + ms;

          final timeStr = '${match.group(1)}:${match.group(2)}';
          final text = match.group(4)?.trim() ?? '';
          if (text.isNotEmpty || timeStr.isNotEmpty) {
            lines.add(_LrcLine(timestamp: timeStr, timestampMs: totalMs, text: text));
            if (totalMs > 0) trulySynced = true;
          }
        } else if (l.trim().isNotEmpty) {
          lines.add(_LrcLine(timestamp: null, timestampMs: -1, text: l.trim()));
        }
      }
    }

    _parsedLines = lines;
    _isSynced = hasLrcRegex && trulySynced;
  }

  void _onPositionChanged() {
    if (!_isSynced || _parsedLines.isEmpty || !mounted) return;

    final currentMs = _player.positionMs;
    int active = -1;
    for (int i = 0; i < _parsedLines.length; i++) {
      if (_parsedLines[i].timestampMs <= currentMs) {
        active = i;
      } else {
        break;
      }
    }

    if (active != _activeIndex) {
      setState(() => _activeIndex = active);
      if (!_isUserScrolling && active >= 0 && _scrollController.hasClients) {
        // LastWave & Apple Music centering follow with smooth cubic-bezier easing
        const double itemEstHeight = 52.0;
        final viewportHeight = _scrollController.position.viewportDimension;
        final maxScroll = _scrollController.position.maxScrollExtent;
        // Center the active line vertically within the viewport, clamped to list bounds
        final targetOffset = ((active * itemEstHeight) - (viewportHeight - itemEstHeight) / 2.0)
            .clamp(0.0, maxScroll);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _showInSheetToast(String message, IconData icon) {
    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
    setState(() {
      _inSheetToast = message;
      _inSheetIcon = icon;
    });
    _glowController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() => _inSheetToast = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);
    final rawLyrics = widget.track.lyrics?.trim() ?? '';
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    // Multi-Lingual Font Fallback (Devanagari Hindi + Inter English)
    const fontFallbacks = ['Noto Sans Devanagari', 'Kohinoor Devanagari', 'sans-serif'];

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        child: Stack(
          children: [
            // 1. Bottom Ambient Wavy Acoustic Lightfield Pulse (Index 0: BEHIND content, flush with sheet bottom)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    if (_glowController.value == 0.0 || _glowController.value == 1.0) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      size: const Size(double.infinity, 100),
                      painter: _AcousticAmbientGlowPainter(
                        accentColor: activeAccent,
                        progress: _glowController.value,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Primary Foreground Content
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Top Drag Handle
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
                  const SizedBox(height: 12),

                  // Header Bar
                  Row(
                    children: [
                      // 50dp Squircle Album Art
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isDark
                              ? AppColors.softElevation(elevation: 2.5)
                              : AppColors.lightSoftElevation(elevation: 2.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.track.hasCover && widget.track.coverBytes != null
                            ? Image.memory(widget.track.coverBytes!, fit: BoxFit.cover)
                            : Center(
                                child: Icon(
                                  Icons.lyrics_rounded,
                                  size: 26,
                                  color: activeAccent,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.track.title.isNotEmpty ? widget.track.title : widget.track.fileName,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: fontFallbacks,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.track.artist.isNotEmpty ? widget.track.artist : 'Embedded FLAC Lyrics',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: fontFallbacks,
                                fontSize: 12.5,
                                color: subTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Actions: Export .LRC & Copy
                      if (rawLyrics.isNotEmpty) ...[
                        // Export .LRC Button
                        LuminousFeedback(
                          onTap: () async {
                            try {
                              const channel = MethodChannel('flac_toolkit/audio_decoder');
                              final res = await channel.invokeMethod<Map>('exportLyrics', {
                                'lyrics': rawLyrics,
                                'fileName': widget.track.title.isNotEmpty ? widget.track.title : widget.track.fileName,
                              });
                              final path = res?['path'] as String? ?? '';
                              _showInSheetToast(
                                'Saved to Downloads: ${path.split('/').last}',
                                Icons.download_done_rounded,
                              );
                            } catch (e) {
                              _showInSheetToast('Export failed: $e', Icons.error_outline_rounded);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x20FFFFFF) : const Color(0x18000000),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(Icons.download_rounded, size: 18, color: textColor),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Copy All Lyrics Button
                        LuminousFeedback(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: rawLyrics));
                            _showInSheetToast('Lyrics copied to clipboard', Icons.copy_rounded);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x20FFFFFF) : const Color(0x18000000),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(Icons.copy_rounded, size: 18, color: textColor),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Lyrics Format Pill & Live Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_isSynced ? AppColors.genuineEmerald : activeAccent).withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSynced ? Icons.sync_rounded : Icons.article_outlined,
                              size: 13,
                              color: _isSynced ? AppColors.genuineEmerald : activeAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isSynced ? 'SYNCED LRC • AUTO-FOLLOW' : 'PLAIN VORBIS LYRICS',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isSynced ? AppColors.genuineEmerald : activeAccent,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _isSynced ? '${_parsedLines.length} timestamped lines' : 'Full Song',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Lossless Audio Preview Player Bar
                  AudioPreviewBar(
                    filePath: widget.track.filePath,
                    title: widget.track.title.isNotEmpty ? widget.track.title : widget.track.fileName,
                  ),

                  const SizedBox(height: 12),

                  // Hairline separator
                  Container(
                    height: 1,
                    color: isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000),
                  ),

                  const SizedBox(height: 8),

                  // Scrollable Lyrics Body
                  Expanded(
                    child: rawLyrics.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lyrics_outlined,
                                  size: 48,
                                  color: subTextColor.withOpacity(0.4),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No lyrics metadata found in this FLAC file',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isSynced
                            ? NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollStartNotification && notification.dragDetails != null) {
                                    _isUserScrolling = true;
                                  } else if (notification is ScrollEndNotification) {
                                    Future.delayed(const Duration(seconds: 3), () {
                                      if (mounted) _isUserScrolling = false;
                                    });
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  itemCount: _parsedLines.length,
                                  itemBuilder: (context, index) {
                                    final line = _parsedLines[index];
                                    final isActive = index == _activeIndex;

                                    return GestureDetector(
                                      onTap: () {
                                        if (line.timestampMs >= 0) {
                                          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                          _player.seek(line.timestampMs);
                                          if (!_player.isPlaying) {
                                            _player.play(widget.track.filePath);
                                          }
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 320),
                                        curve: Curves.easeOutCubic,
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isActive ? 12 : 4,
                                          vertical: isActive ? 10 : 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? activeAccent.withOpacity(isDark ? 0.20 : 0.12)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isActive
                                                ? activeAccent.withOpacity(0.40)
                                                : Colors.transparent,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            if (line.timestamp != null)
                                              AnimatedContainer(
                                                duration: const Duration(milliseconds: 280),
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                margin: const EdgeInsets.only(right: 12),
                                                decoration: BoxDecoration(
                                                  color: isActive
                                                      ? activeAccent
                                                      : (isDark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: Text(
                                                  line.timestamp!,
                                                  style: TextStyle(
                                                    fontFamily: 'JetBrainsMono',
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isActive
                                                        ? AppColors.getOnAccentColor(activeAccent, isDark: isDark)
                                                        : subTextColor,
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              child: AnimatedDefaultTextStyle(
                                                duration: const Duration(milliseconds: 320),
                                                curve: Curves.easeOutCubic,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontFamilyFallback: fontFallbacks,
                                                  fontSize: isActive ? 17.0 : 14.5,
                                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                                  height: 1.45,
                                                  letterSpacing: isActive ? -0.2 : -0.1,
                                                  color: isActive
                                                      ? (isDark ? Colors.white : activeAccent)
                                                      : (line.text.isEmpty
                                                          ? subTextColor.withOpacity(0.3)
                                                          : textColor.withOpacity(0.35)),
                                                ),
                                                child: Text(line.text.isEmpty ? '♪' : line.text),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: SelectableText(
                                  rawLyrics,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: fontFallbacks,
                                    fontSize: 14.5,
                                    height: 1.6,
                                    fontWeight: FontWeight.w400,
                                    color: textColor,
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),

          // 3. In-Sheet Floating Frosted Glass Toast Pill (Authentic GlassSurface with specular rim)
          if (_inSheetToast != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Center(
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(18),
                  style: GlassStyle.frosted,
                  borderless: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_inSheetIcon != null) ...[
                        Icon(_inSheetIcon, size: 16, color: activeAccent),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _inSheetToast!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
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
  );
  }
}

/// Organic Acoustic Wavy Ambient Lightfield
///
/// Features:
/// 1. Sinusoidal acoustic wavefront with Gaussian bell curve center peak.
/// 2. Non-linear cubic photon decay (opacity dissolves to 0.000 before reaching the top).
/// 3. Zero hard boundaries or bounding box edge lines.
class _AcousticAmbientGlowPainter extends CustomPainter {
  final Color accentColor;
  final double progress;

  _AcousticAmbientGlowPainter({
    required this.accentColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final animValue = (1.0 - progress);
    // Smooth sinusoidal breathing pulse: peaks softly, then dissolves like aurora mist
    final intensity = (math.sin(animValue * math.pi * 0.5) * animValue).clamp(0.0, 1.0);
    if (intensity <= 0.001) return;

    final width = size.width;
    final height = size.height;

    final path = Path();
    path.moveTo(0, height);

    final waveHeight = height * 0.88;
    const int points = 32;
    for (int i = 0; i <= points; i++) {
      final x = (i / points) * width;
      final normX = (x / width) * 2.0 - 1.0;
      final bell = math.exp(-normX * normX * 1.5);
      final wave = math.sin((x / width) * math.pi * 2.0 + 0.3) * 0.15 + 0.85;
      final y = height - (waveHeight * bell * wave * intensity);
      path.lineTo(x, y);
    }

    path.lineTo(width, height);
    path.close();

    final Rect bounds = Rect.fromLTWH(0, 0, width, height);
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.0),
        radius: 1.15,
        colors: [
          accentColor.withOpacity((0.42 * intensity).clamp(0.0, 1.0)),
          accentColor.withOpacity((0.20 * intensity).clamp(0.0, 1.0)),
          accentColor.withOpacity((0.05 * intensity).clamp(0.0, 1.0)),
          accentColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.40, 0.75, 1.0],
      ).createShader(bounds);

    canvas.drawPath(path, glowPaint);

    // Atmospheric diffuse floor catch
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          accentColor.withOpacity((0.25 * intensity).clamp(0.0, 1.0)),
          accentColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(bounds);

    canvas.drawRect(Rect.fromLTWH(0, height * 0.35, width, height * 0.65), basePaint);
  }

  @override
  bool shouldRepaint(covariant _AcousticAmbientGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
  }
}

class _LrcLine {
  final String? timestamp;
  final int timestampMs;
  final String text;

  _LrcLine({
    required this.timestamp,
    required this.timestampMs,
    required this.text,
  });
}
