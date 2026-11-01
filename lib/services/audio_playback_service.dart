import 'dart:async';
import 'package:flutter/services.dart';

/// Lightweight Native Audio Player Controller for Lossless FLAC Preview
class AudioPlaybackService {
  static const MethodChannel _channel = MethodChannel('flac_toolkit/audio_decoder');

  static final AudioPlaybackService instance = AudioPlaybackService._();
  AudioPlaybackService._();

  bool isPlaying = false;
  String? currentFilePath;
  int positionMs = 0;
  int durationMs = 0;

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
    for (final l in _listeners) {
      l();
    }
  }

  Future<void> play(String filePath) async {
    try {
      if (currentFilePath == filePath && isPlaying) {
        await pause();
        return;
      }
      if (currentFilePath == filePath && !isPlaying && positionMs > 0) {
        await resume();
        return;
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

          positionMs = pos;
          if (dur > 0) durationMs = dur;
          if (isPlaying != nowPlaying) {
            isPlaying = nowPlaying;
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

