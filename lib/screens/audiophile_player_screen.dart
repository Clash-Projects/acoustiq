import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import '../widgets/glass_surface.dart';
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

  String _formatTime(int ms) {
    final totalSec = (ms / 1000).floor();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final track = appState.activeTrack;
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
    final bitrateStr = track != null && track.bitrateKbps > 0
        ? '${track.bitrateKbps} kbps'
        : 'Lossless';

    final hasCover = track?.hasCover == true && track?.coverBytes != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E12),
      body: Stack(
        children: [
          // 0. Ambient Dynamic Artwork Backdrop (Full Screen Blur)
          if (hasCover)
            Positioned.fill(
              child: Image.memory(
                track!.coverBytes!,
                fit: BoxFit.cover,
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Container(
                color: const Color(0xFF0A0C10).withOpacity(hasCover ? 0.78 : 1.0),
              ),
            ),
          ),

          // 1. Full Screen Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        splashRadius: 24,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'AUDIOPHILE PLAYBACK',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.50),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ClashPlayer C++ Engine',
                              style: TextStyle(
                                color: AppColors.genuineEmerald.withOpacity(0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48), // Balance symmetry with back button
                    ],
                  ),
                ),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),

                        // Large Vinyl Record / Artwork Platter Hero
                        _buildHeroArtwork(track, isPlaying),

                        const SizedBox(height: 32),

                        // Track Title & Artist
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$artist • $album',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Single Dedicated Signal Path Quality Badge (Tap to Inspect)
                        GestureDetector(
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.lightImpact();
                            }
                            showSignalPathSheet(
                              context,
                              trackTitle: title,
                              sampleRate: track?.sampleRate ?? 48000,
                              bitDepth: track?.bitDepth ?? 16,
                            );
                          },
                          child: GlassSurface(
                            style: GlassStyle.frosted,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    color: AppColors.genuineEmerald,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isPlaying
                                        ? 'BIT-PERFECT • $bitDepthStr / $sampleRateStr'
                                        : '$bitDepthStr / $sampleRateStr • Tap to inspect path',
                                    style: const TextStyle(
                                      color: AppColors.genuineEmerald,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'JetBrainsMono',
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: AppColors.genuineEmerald.withOpacity(0.60),
                                    size: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Frosted Audio Metadata Chips (Wrap layout: Zero Overflow Guaranteed)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFrostedChip('FLAC LOSSLESS', Icons.audio_file_rounded),
                            _buildFrostedChip(bitrateStr, Icons.speed_rounded),
                            if (track != null && track.cutoffKhz > 0)
                              _buildFrostedChip(
                                '${track.cutoffKhz.toStringAsFixed(1)} kHz Nyquist',
                                Icons.graphic_eq_rounded,
                              ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Scrubber Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            activeTrackColor: AppColors.accentPrimary,
                            inactiveTrackColor: Colors.white.withOpacity(0.12),
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: progress,
                            onChangeStart: (_) {
                              setState(() => _isDraggingScrubber = true);
                            },
                            onChanged: (val) {
                              setState(() => _dragValue = val);
                            },
                            onChangeEnd: (val) {
                              setState(() => _isDraggingScrubber = false);
                              if (dur > 0) {
                                _player.seek((val * dur).toInt());
                              }
                            },
                          ),
                        ),

                        // Timestamps
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatTime(currentPos),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                  fontFamily: 'JetBrainsMono',
                                ),
                              ),
                              Text(
                                _formatTime(dur),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                  fontFamily: 'JetBrainsMono',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Tactile Transport Controls (Frosted Glass)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 10s Rewind
                            GestureDetector(
                              onTap: () {
                                if (appState.hapticsEnabled) {
                                  HapticFeedback.lightImpact();
                                }
                                final target = (pos - 10000).clamp(0, dur);
                                _player.seek(target);
                              },
                              child: GlassSurface(
                                style: GlassStyle.frosted,
                                borderRadius: BorderRadius.circular(25),
                                child: const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                    child: Icon(
                                      Icons.replay_10_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Main Play / Pause Button (68x68dp)
                            GestureDetector(
                              onTap: () {
                                if (appState.hapticsEnabled) {
                                  HapticFeedback.mediumImpact();
                                }
                                final path = track?.filePath ?? _player.currentFilePath;
                                if (path != null) {
                                  _player.play(path);
                                }
                              },
                              child: Container(
                                width: 68,
                                height: 68,
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
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 38,
                                  ),
                                ),
                              ),
                            ),

                            // 10s Forward
                            GestureDetector(
                              onTap: () {
                                if (appState.hapticsEnabled) {
                                  HapticFeedback.lightImpact();
                                }
                                final target = (pos + 10000).clamp(0, dur);
                                _player.seek(target);
                              },
                              child: GlassSurface(
                                style: GlassStyle.frosted,
                                borderRadius: BorderRadius.circular(25),
                                child: const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                    child: Icon(
                                      Icons.forward_10_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroArtwork(FlacInfo? track, bool isPlaying) {
    final hasCover = track?.hasCover == true && track?.coverBytes != null;

    if (hasCover) {
      return Container(
        width: 230,
        height: 230,
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
            image: MemoryImage(track!.coverBytes!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // High-End Studio Vinyl Platter with Concentric Grooves
    return RotationTransition(
      turns: _rotationController,
      child: Container(
        width: 230,
        height: 230,
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
            // Outer Groove Ring
            Container(
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.8,
                ),
              ),
            ),
            // Middle Groove Ring
            Container(
              width: 154,
              height: 154,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.8,
                ),
              ),
            ),
            // Inner Groove Ring
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                  width: 0.8,
                ),
              ),
            ),
            // Center Spindle Label with AcoustiQ Motif
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPrimary.withOpacity(0.90),
                border: Border.all(
                  color: Colors.white.withOpacity(0.30),
                  width: 1.0,
                ),
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

  Widget _buildFrostedChip(String text, IconData icon) {
    return GlassSurface(
      style: GlassStyle.frosted,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
