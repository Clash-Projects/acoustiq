import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';
import 'signal_path_sheet.dart';

/// WWDC25 Frosted Glass Inline Audio Preview Bar
class AudioPreviewBar extends StatefulWidget {
  final String filePath;
  final String title;
  final FlacInfo? trackInfo;

  const AudioPreviewBar({
    super.key,
    required this.filePath,
    required this.title,
    this.trackInfo,
  });

  @override
  State<AudioPreviewBar> createState() => _AudioPreviewBarState();
}

class _AudioPreviewBarState extends State<AudioPreviewBar> {
  final _player = AudioPlaybackService.instance;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerStateChanged);
  }

  @override
  void didUpdateWidget(covariant AudioPreviewBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath && _player.isPlaying) {
      _player.stop();
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onPlayerStateChanged() {
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
    final isPlaying = isCurrent && _player.isPlaying;
    final pos = isCurrent ? _player.positionMs : 0;
    final dur = isCurrent ? _player.durationMs : 0;
    final progress = (dur > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    final isDark = appState.isCurrentDark(context);
    final activeAccent = appState.getAccentColor(context);
    final onAccentColor = AppColors.getOnAccentColor(activeAccent, isDark: isDark);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);

    return GlassSurface(
      borderRadius: BorderRadius.circular(16),
      style: GlassStyle.frosted,
      borderless: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play / Pause Circle
              LuminousFeedback(
                onTap: () {
                  if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                  if (!isPlaying) {
                    if (widget.trackInfo != null) {
                      appState.setActiveTrack(widget.trackInfo);
                    } else if (appState.activeTrack?.filePath != widget.filePath) {
                      final match = appState.sharedLibrary.where((t) => t.filePath == widget.filePath).firstOrNull;
                      if (match != null) {
                        appState.setActiveTrack(match);
                      }
                    }
                  }
                  _player.play(widget.filePath);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: activeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.40 : 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 22,
                    color: onAccentColor,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title and Timestamps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isPlaying ? 'Now Playing Lossless' : 'Audio Preview',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dur > 0 ? '${_formatTime(pos)} / ${_formatTime(dur)}' : 'Ready to play',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Scrubber Bar
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        if (dur <= 0) return;
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final local = details.localPosition;
                        final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
                        _player.seek((ratio * dur).toInt());
                      },
                      onTapDown: (details) {
                        if (dur <= 0) return;
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final local = details.localPosition;
                        final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
                        _player.seek((ratio * dur).toInt());
                      },
                      behavior: HitTestBehavior.opaque,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 5,
                          width: double.infinity,
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              color: activeAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Utility Row: Signal Path Frosted Badge + Audiophile Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LuminousFeedback(
                onTap: () => showSignalPathSheet(context, trackTitle: widget.title),
                borderRadius: BorderRadius.circular(8),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(8),
                  style: GlassStyle.frosted,
                  borderless: false,
                  tintColor: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route_rounded, size: 11, color: AppColors.genuineEmerald),
                      SizedBox(width: 4),
                      Text(
                        'SIGNAL PATH',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.genuineEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                isPlaying ? 'Bit-Perfect AAudio Stream' : 'ClashPlayer C++ Pipeline',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

