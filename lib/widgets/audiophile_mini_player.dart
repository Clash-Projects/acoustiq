import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../screens/audiophile_player_screen.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';

/// Floating Liquid Glass Audiophile MiniPlayer
/// Streamlined BitChord layout: 56dp height pill, true frosted glass (GlassSurface),
/// zero text truncation for Title & Artist, and high-contrast tactile transport button.
class AudiophileMiniPlayer extends StatefulWidget {
  const AudiophileMiniPlayer({super.key});

  @override
  State<AudiophileMiniPlayer> createState() => _AudiophileMiniPlayerState();
}

class _AudiophileMiniPlayerState extends State<AudiophileMiniPlayer>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlaybackService.instance;
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _player.addListener(_onPlaybackChanged);
    appState.addListener(_onPlaybackChanged);

    if (_player.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPlaybackChanged);
    appState.removeListener(_onPlaybackChanged);
    _rotationController.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    if (_player.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!_player.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final track = appState.activeTrack;
    if (track == null && !_player.isPlaying && _player.currentFilePath == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = _player.isPlaying;
    final isCurrent = _player.currentFilePath == track?.filePath;
    final pos = isCurrent ? _player.positionMs : 0;
    final dur = (isCurrent && _player.durationMs > 0)
        ? _player.durationMs
        : ((track?.durationSec ?? 0) * 1000).toInt();
    final progress = (dur > 0 && isCurrent) ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    final title = track?.title.isNotEmpty == true
        ? track!.title
        : (_player.currentFilePath?.split('/').last ?? 'Lossless Audio Stream');
    final artist = track?.artist.isNotEmpty == true
        ? track!.artist
        : 'Bit-Perfect Playback';

    final sampleRateStr = track != null
        ? '${(track.sampleRate / 1000).toStringAsFixed(1)}k'
        : '48k';
    final bitDepthStr = track != null ? '${track.bitDepth}b' : '24b';

    return Padding(
      padding: const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 10.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 180) {
            if (appState.hapticsEnabled) HapticFeedback.lightImpact();
            appState.setActiveTrack(null);
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 180) {
            if (appState.hapticsEnabled) HapticFeedback.lightImpact();
            appState.setActiveTrack(null);
          }
        },
        onTap: () {
          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
          openAudiophilePlayerScreen(context);
        },
        child: GlassSurface(
          style: GlassStyle.frosted,
          borderRadius: BorderRadius.circular(28.0),
          tintColor: const Color(0xFF111319).withOpacity(0.42),
          child: SizedBox(
            height: 56.0,
            child: Stack(
              children: [
                // Main Content Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      // 1. Artwork or Obsidian Vinyl Disc (40x40dp)
                      _buildArtwork(track, isPlaying),

                      const SizedBox(width: 12.0),

                      // 2. Track Title & Artist (Ample breathing room, zero truncation)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 10.0,
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  isPlaying ? 'BIT-PERFECT' : '$bitDepthStr/$sampleRateStr',
                                  style: const TextStyle(
                                    color: AppColors.genuineEmerald,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'JetBrainsMono',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8.0),

                      // 3. Tactile Circular Play / Pause Button (BitChord GLYPH_SLOT 40dp)
                      GestureDetector(
                        onTap: () {
                          if (appState.hapticsEnabled) {
                            HapticFeedback.lightImpact();
                          }
                          final path = track?.filePath ?? _player.currentFilePath;
                          if (path != null) {
                            _player.play(path);
                          }
                        },
                        child: Container(
                          width: 38.0,
                          height: 38.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.30),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 24.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Hairline Bottom Progress Indicator (2dp)
                Positioned(
                  left: 18.0,
                  right: 18.0,
                  bottom: 0,
                  height: 2.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1.0),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(FlacInfo? track, bool isPlaying) {
    final hasCover = track?.hasCover == true && track?.coverBytes != null;

    if (hasCover) {
      return Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 0.5,
          ),
          image: DecorationImage(
            image: MemoryImage(track!.coverBytes!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Obsidian Vinyl Platter Placeholder with Concentric Grooves
    return RotationTransition(
      turns: _rotationController,
      child: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0D0F14),
          border: Border.all(
            color: Colors.white.withOpacity(0.14),
            width: 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Groove Ring 1
            Container(
              width: 30.0,
              height: 30.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 0.5,
                ),
              ),
            ),
            // Groove Ring 2
            Container(
              width: 22.0,
              height: 22.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.07),
                  width: 0.5,
                ),
              ),
            ),
            // Center Vinyl Spindle Label
            Container(
              width: 14.0,
              height: 14.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPrimary.withOpacity(0.85),
              ),
              child: Center(
                child: Container(
                  width: 4.0,
                  height: 4.0,
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
