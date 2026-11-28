import 'dart:async';
import 'package:flutter/services.dart';

/// Telemetry state representing the end-to-end audiophile signal path.
class AudioSignalPath {
  final String sourceFormat;
  final int sampleRate;
  final int bitDepth;
  final int channels;
  final String driver;
  final String endpoint;
  final bool isBitPerfect;

  const AudioSignalPath({
    this.sourceFormat = 'FLAC (Lossless)',
    this.sampleRate = 48000,
    this.bitDepth = 16,
    this.channels = 2,
    this.driver = 'AAudio',
    this.endpoint = 'Internal Audio Hardware',
    this.isBitPerfect = false,
  });

  String get sampleRateStr => '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
  String get bitDepthStr => '$bitDepth-bit';
  String get channelsStr => channels == 2 ? 'Stereo (2.0)' : 'Mono (1.0)';
}

/// Service bridging AcoustiQ to the native C/Kotlin audio engine (USB DAC + AAudio/OpenSL ES).
class NativeAudioService {
  static const MethodChannel _channel = MethodChannel('acoustiq/clash_native_audio');

  static final NativeAudioService _instance = NativeAudioService._internal();
  static NativeAudioService get instance => _instance;

  NativeAudioService._internal();

  bool _isPlaying = false;
  bool _isPaused = false;
  String? _currentFilePath;
  int _positionMs = 0;
  int _durationMs = 0;
  AudioSignalPath _signalPath = const AudioSignalPath();

  final StreamController<int> _positionController = StreamController<int>.broadcast();
  final StreamController<bool> _stateController = StreamController<bool>.broadcast();
  final StreamController<AudioSignalPath> _signalPathController = StreamController<AudioSignalPath>.broadcast();

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  String? get currentFilePath => _currentFilePath;
  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  AudioSignalPath get signalPath => _signalPath;

  Stream<int> get positionStream => _positionController.stream;
  Stream<bool> get stateStream => _stateController.stream;
  Stream<AudioSignalPath> get signalPathStream => _signalPathController.stream;

  /// Updates signal path metadata when fallback Android MediaPlayer handles playback.
  void setFallbackTelemetry({
    int sampleRate = 48000,
    int bitDepth = 16,
    int channels = 2,
  }) {
    _signalPath = AudioSignalPath(
      sourceFormat: 'FLAC Lossless',
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      channels: channels,
      driver: 'Android MediaPlayer',
      endpoint: 'Android AudioFlinger Mixer',
      isBitPerfect: false,
    );
    _signalPathController.add(_signalPath);
  }

  /// Queries connected USB DAC hardware and active driver capabilities.
  Future<Map<String, dynamic>> queryEngineStatus() async {
    try {
      final res = await _channel.invokeMethod<Map>('getAudioEngineStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'hasUsbDac': false,
      'usbDacName': 'No USB DAC detected',
      'defaultDriver': 'AAudio',
      'activeDriver': _signalPath.driver,
      'endpoint': _signalPath.endpoint,
      'isBitPerfect': false,
      'sampleRate': _signalPath.sampleRate,
      'bitDepth': _signalPath.bitDepth,
    };
  }

  /// Polls native playback progress, duration, completion flag, and live driver telemetry.
  Future<Map<String, dynamic>?> pollPlaybackState() async {
    try {
      final res = await _channel.invokeMethod<Map>('getPlaybackPosition');
      if (res != null) {
        final data = Map<String, dynamic>.from(res);
        _positionMs = (data['positionMs'] as num?)?.toInt() ?? _positionMs;
        final dur = (data['durationMs'] as num?)?.toInt() ?? 0;
        if (dur > 0) _durationMs = dur;
        _isPlaying = data['isPlaying'] == true;
        _isPaused = data['isPaused'] == true;

        final driver = data['driver']?.toString() ?? _signalPath.driver;
        final endpoint = data['endpoint']?.toString() ?? _signalPath.endpoint;
        final bitPerfect = data['bitPerfect'] == true;
        final rate = (data['sampleRate'] as num?)?.toInt() ?? _signalPath.sampleRate;
        final depth = (data['bitDepth'] as num?)?.toInt() ?? _signalPath.bitDepth;
        final ch = (data['channels'] as num?)?.toInt() ?? _signalPath.channels;

        if (driver != _signalPath.driver ||
            endpoint != _signalPath.endpoint ||
            bitPerfect != _signalPath.isBitPerfect ||
            rate != _signalPath.sampleRate ||
            depth != _signalPath.bitDepth) {
          _signalPath = AudioSignalPath(
            sourceFormat: 'FLAC Lossless',
            sampleRate: rate,
            bitDepth: depth,
            channels: ch,
            driver: driver,
            endpoint: endpoint,
            isBitPerfect: bitPerfect,
          );
          _signalPathController.add(_signalPath);
        }
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Starts native audio streaming for [filePath].
  Future<bool> play(
    String filePath, {
    int sampleRate = 48000,
    int bitDepth = 16,
    int channels = 2,
    bool preferUsb = true,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map>('startNativePlayback', {
        'filePath': filePath,
        'preferUsb': preferUsb,
      });

      if (res != null) {
        _isPlaying = true;
        _isPaused = false;
        _currentFilePath = filePath;
        _durationMs = (res['durationMs'] as num?)?.toInt() ?? 0;
        _positionMs = 0;

        final driver = res['driver']?.toString() ?? 'AAudio';
        final endpoint = res['endpoint']?.toString() ??
            (driver.contains('USB') ? 'External USB DAC' : 'Internal Audio Hardware (Shared Mixer)');
        final bitPerfect = res['bitPerfect'] == true;

        _signalPath = AudioSignalPath(
          sourceFormat: 'FLAC Lossless',
          sampleRate: (res['sampleRate'] as num?)?.toInt() ?? sampleRate,
          bitDepth: (res['bitDepth'] as num?)?.toInt() ?? bitDepth,
          channels: (res['channels'] as num?)?.toInt() ?? channels,
          driver: driver,
          endpoint: endpoint,
          isBitPerfect: bitPerfect,
        );

        _stateController.add(true);
        _signalPathController.add(_signalPath);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pauseNativePlayback');
      _isPaused = true;
      _stateController.add(false);
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resumeNativePlayback');
      _isPaused = false;
      _stateController.add(true);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopNativePlayback');
    } catch (_) {}
    _isPlaying = false;
    _isPaused = false;
    _currentFilePath = null;
    _positionMs = 0;
    _stateController.add(false);
    _positionController.add(0);
  }

  Future<void> seek(int positionMs) async {
    try {
      await _channel.invokeMethod('seekNativePlayback', {'positionMs': positionMs});
      _positionMs = positionMs;
      _positionController.add(positionMs);
    } catch (_) {}
  }

  void dispose() {
    _positionController.close();
    _stateController.close();
    _signalPathController.close();
  }
}
