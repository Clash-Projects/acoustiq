import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

enum PlaybackRepeatMode { off, all, one }

/// Lightweight Native Audio Player Controller for Lossless FLAC Playback
class AudioPlaybackService {
  static const MethodChannel _channel = MethodChannel('flac_toolkit/audio_decoder');

  static final AudioPlaybackService instance = AudioPlaybackService._();
  AudioPlaybackService._();

  bool isPlaying = false;
  String? currentFilePath;
  int positionMs = 0;
  int durationMs = 0;

  PlaybackRepeatMode repeatMode = PlaybackRepeatMode.off;
  bool isShuffle = false;
  final math.Random _rng = math.Random();

  int get currentPositionMs => positionMs;
  bool get isPlayingNow => isPlaying;

  Timer? _positionTimer;
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }

  void toggleRepeat() {
    switch (repeatMode) {
      case PlaybackRepeatMode.off:
        repeatMode = PlaybackRepeatMode.all;
        break;
      case PlaybackRepeatMode.all:
        repeatMode = PlaybackRepeatMode.one;
        break;
      case PlaybackRepeatMode.one:
        repeatMode = PlaybackRepeatMode.off;
        break;
    }
    _notify();
  }

  void toggleShuffle() {
    isShuffle = !isShuffle;
    _notify();
  }

  Future<void> play(String filePath, {bool forceRestart = false}) async {
    try {
      if (!forceRestart) {
        if (currentFilePath == filePath && isPlaying) {
          await pause();
          return;
        }
        if (currentFilePath == filePath && !isPlaying && positionMs > 0) {
          await resume();
          return;
        }
      }

      currentFilePath = filePath;
      final res = await _channel.invokeMethod<Map>('playAudio', {'filePath': filePath});
      isPlaying = true;
      durationMs = (res?['durationMs'] as num?)?.toInt() ?? 0;
      positionMs = 0;
      _startTimer();
      _notify();
    } catch (_) {
      isPlaying = false;
      _notify();
    }
  }

  Future<void> playNext({bool fromAutoComplete = false}) async {
    final active = appState.activeTrack;
    final path = currentFilePath ?? active?.filePath;

    if (fromAutoComplete && repeatMode == PlaybackRepeatMode.one && path != null) {
      await play(path, forceRestart: true);
      return;
    }

    final queue = appState.sharedLibrary;
    if (queue.isEmpty) {
      if (fromAutoComplete && repeatMode == PlaybackRepeatMode.all && path != null) {
        await play(path, forceRestart: true);
      } else if (fromAutoComplete) {
        isPlaying = false;
        _stopTimer();
        _notify();
      } else if (durationMs > 0) {
        await seek((positionMs + 10000).clamp(0, durationMs));
      }
      return;
    }

    final currentIdx = path != null ? queue.indexWhere((t) => t.filePath == path) : -1;
    int nextIdx;

    if (isShuffle && queue.length > 1) {
      do {
        nextIdx = _rng.nextInt(queue.length);
      } while (nextIdx == currentIdx);
    } else {
      nextIdx = currentIdx + 1;
      if (nextIdx >= queue.length) {
        if (repeatMode == PlaybackRepeatMode.all || !fromAutoComplete) {
          nextIdx = 0;
        } else {
          isPlaying = false;
          _stopTimer();
          _notify();
          return;
        }
      }
    }

    final nextTrack = queue[nextIdx];
    appState.setActiveTrack(nextTrack);
    await play(nextTrack.filePath, forceRestart: true);
  }

  Future<void> playPrevious() async {
    if (positionMs > 3000) {
      await seek(0);
      return;
    }

    final queue = appState.sharedLibrary;
    final path = currentFilePath ?? appState.activeTrack?.filePath;
    if (queue.isEmpty) {
      await seek(0);
      return;
    }

    final currentIdx = path != null ? queue.indexWhere((t) => t.filePath == path) : 0;
    int prevIdx;
    if (isShuffle && queue.length > 1) {
      do {
        prevIdx = _rng.nextInt(queue.length);
      } while (prevIdx == currentIdx);
    } else {
      prevIdx = currentIdx - 1;
      if (prevIdx < 0) {
        prevIdx = queue.length - 1;
      }
    }

    final prevTrack = queue[prevIdx];
    appState.setActiveTrack(prevTrack);
    await play(prevTrack.filePath, forceRestart: true);
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pauseAudio');
      isPlaying = false;
      _stopTimer();
      _notify();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resumeAudio');
      isPlaying = true;
      _startTimer();
      _notify();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
    isPlaying = false;
    currentFilePath = null;
    positionMs = 0;
    _stopTimer();
    _notify();
  }

  Future<void> seek(int targetMs) async {
    try {
      await _channel.invokeMethod('seekAudio', {'positionMs': targetMs});
      positionMs = targetMs;
      _notify();
    } catch (_) {}
  }

  void _startTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      try {
        final res = await _channel.invokeMethod<Map>('getAudioPosition');
        if (res != null) {
          final nowPlaying = res['isPlaying'] as bool? ?? false;
          final pos = (res['positionMs'] as num?)?.toInt() ?? 0;
          final dur = (res['durationMs'] as num?)?.toInt() ?? 0;

          final wasPlaying = isPlaying;
          positionMs = pos;
          if (dur > 0) durationMs = dur;
          if (isPlaying != nowPlaying) {
            isPlaying = nowPlaying;
          }
          if (wasPlaying && !nowPlaying && durationMs > 0 && positionMs >= durationMs - 450) {
            _stopTimer();
            unawaited(playNext(fromAutoComplete: true));
            return;
          }
          if (!isPlaying && positionMs >= durationMs && durationMs > 0) {
            _stopTimer();
          }
          _notify();
        }
      } catch (_) {}
    });
  }

  void _stopTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}

