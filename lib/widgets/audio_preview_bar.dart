import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

/// WWDC25 Frosted Glass Inline Audio Preview Bar
class AudioPreviewBar extends StatefulWidget {
  final String filePath;
  final String title;

  const AudioPreviewBar({
    super.key,
    required this.filePath,
    required this.title,
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
                        color: activeAccent.withOpacity(0.35),
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
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          dur > 0 ? '${_formatTime(pos)} / ${_formatTime(dur)}' : 'Tap to listen',
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
        ],
      ),
    );
  }
}

