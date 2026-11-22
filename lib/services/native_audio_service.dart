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
    this.driver = 'AAudio Low-Latency',
    this.endpoint = 'Internal Audio Hardware',
    this.isBitPerfect = true,
  });

  String get sampleRateStr => '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
  String get bitDepthStr => '$bitDepth-bit';
  String get channelsStr => channels == 2 ? 'Stereo (2.0)' : 'Mono (1.0)';
}

/// Service bridging AcoustiQ to the native ClashPlayer C++ audio engine.
class NativeAudioService {
  static const MethodChannel _channel = MethodChannel('acoustiq/clash_native_audio');

  static final NativeAudioService _instance = NativeAudioService._internal();
  static NativeAudioService get instance => _instance;

  NativeAudioService._internal() {
    _startPositionPoller();
  }

  bool _isPlaying = false;
  bool _isPaused = false;
  String? _currentFilePath;
  int _positionMs = 0;
  int _durationMs = 0;
  AudioSignalPath _signalPath = const AudioSignalPath();

  Timer? _poller;

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

  void _startPositionPoller() {
    _poller = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!_isPlaying || _isPaused) return;
      try {
        final res = await _channel.invokeMethod<Map>('getPlaybackPosition');
        if (res != null) {
          _positionMs = (res['positionMs'] as num?)?.toInt() ?? _positionMs;
          _durationMs = (res['durationMs'] as num?)?.toInt() ?? _durationMs;
          _positionController.add(_positionMs);
        }
      } catch (_) {}
    });
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
      'defaultDriver': 'AAudio Low-Latency',
      'activeDriver': 'AAudio',
      'isBitPerfect': true,
      'sampleRate': 48000,
      'bitDepth': 16,
    };
  }

  /// Starts native audio streaming for [filePath].
  Future<bool> play(String filePath, {int sampleRate = 48000, int bitDepth = 16, int channels = 2}) async {
    try {
      final res = await _channel.invokeMethod<Map>('startNativePlayback', {
        'filePath': filePath,
        'preferUsb': true,
      });

      if (res != null) {
        _isPlaying = true;
        _isPaused = false;
        _currentFilePath = filePath;
        _durationMs = (res['durationMs'] as num?)?.toInt() ?? 0;
        final driver = res['driver']?.toString() ?? 'AAudio';
        final bitPerfect = res['bitPerfect'] == true;

        _signalPath = AudioSignalPath(
          sourceFormat: 'FLAC Lossless Master',
          sampleRate: (res['sampleRate'] as num?)?.toInt() ?? sampleRate,
          bitDepth: bitDepth,
          channels: (res['channels'] as num?)?.toInt() ?? channels,
          driver: driver,
          endpoint: driver.contains('USB') ? 'External USB DAC' : 'AAudio AudioFlinger Direct',
          isBitPerfect: bitPerfect,
        );

        _stateController.add(true);
        _signalPathController.add(_signalPath);
        return true;
      }
    } catch (e) {
      // Fallback
    }
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
      _isPlaying = false;
      _isPaused = false;
      _currentFilePath = null;
      _positionMs = 0;
      _stateController.add(false);
      _positionController.add(0);
    } catch (_) {}
  }

  Future<void> seek(int positionMs) async {
    try {
      await _channel.invokeMethod('seekNativePlayback', {'positionMs': positionMs});
      _positionMs = positionMs;
      _positionController.add(positionMs);
    } catch (_) {}
  }

  void dispose() {
    _poller?.cancel();
    _positionController.close();
    _stateController.close();
    _signalPathController.close();
  }
}
