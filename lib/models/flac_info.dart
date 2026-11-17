import 'dart:typed_data';

class FlacInfo {
  final String filePath;
  final String fileName;
  final double fileSizeMb;
  final String title;
  final String artist;
  final String album;
  final int sampleRate;
  final int bitDepth;
  final int channels;
  final double durationSec;
  final String durationStr;
  final int bitrateKbps;
  final bool hasCover;
  final Uint8List? coverBytes;
  final double cutoffKhz;
  final double maxKhz;
  final double slopeDropDb;
  final int score;
  final String verdict;
  final String status; // "genuine", "suspicious", "fake"
  final bool isFake24;
  final List<double> spectrumBands;
  final List<List<double>> spectrogramMatrix;
  final bool hasLyrics;
  final String? lyricsText;
  String? get lyrics => lyricsText;
  final String? audioMd5;
  final String? error;

  FlacInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSizeMb,
    required this.title,
    required this.artist,
    required this.album,
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
    required this.durationSec,
    required this.durationStr,
    required this.bitrateKbps,
    required this.hasCover,
    this.coverBytes,
    required this.cutoffKhz,
    required this.maxKhz,
    this.slopeDropDb = 0.0,
    required this.score,
    required this.verdict,
    required this.status,
    required this.isFake24,
    this.spectrumBands = const [],
    this.spectrogramMatrix = const [],
    this.hasLyrics = false,
    this.lyricsText,
    this.audioMd5,
    this.error,
  });

  /// Concise Studio Badge (Prevents mobile UI text truncation)
  String get shortBadge {
    if (status == 'untested' || status == 'pending') return 'UNTESTED';
    if (score >= 90) return 'GENUINE LOSSLESS';
    if (score >= 80) return 'STUDIO MASTER';
    if (score >= 50) return 'SUSPICIOUS UPSCALE';
    return 'FAKE LOSSLESS';
  }

  FlacInfo copyWith({
    String? filePath,
    String? fileName,
    double? fileSizeMb,
    String? title,
    String? artist,
    String? album,
    int? sampleRate,
    int? bitDepth,
    int? channels,
    double? durationSec,
    String? durationStr,
    int? bitrateKbps,
    bool? hasCover,
    Uint8List? coverBytes,
    double? cutoffKhz,
    double? maxKhz,
    double? slopeDropDb,
    int? score,
    String? verdict,
    String? status,
    bool? isFake24,
    List<double>? spectrumBands,
    List<List<double>>? spectrogramMatrix,
    bool? hasLyrics,
    String? lyricsText,
    String? audioMd5,
    String? error,
  }) {
    return FlacInfo(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      channels: channels ?? this.channels,
      durationSec: durationSec ?? this.durationSec,
      durationStr: durationStr ?? this.durationStr,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      hasCover: hasCover ?? this.hasCover,
      coverBytes: coverBytes ?? this.coverBytes,
      cutoffKhz: cutoffKhz ?? this.cutoffKhz,
      maxKhz: maxKhz ?? this.maxKhz,
      slopeDropDb: slopeDropDb ?? this.slopeDropDb,
      score: score ?? this.score,
      verdict: verdict ?? this.verdict,
      status: status ?? this.status,
      isFake24: isFake24 ?? this.isFake24,
      spectrumBands: spectrumBands ?? this.spectrumBands,
      spectrogramMatrix: spectrogramMatrix ?? this.spectrogramMatrix,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      lyricsText: lyricsText ?? this.lyricsText,
      audioMd5: audioMd5 ?? this.audioMd5,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'fileSizeMb': fileSizeMb,
      'title': title,
      'artist': artist,
      'album': album,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'channels': channels,
      'durationSec': durationSec,
      'durationStr': durationStr,
      'bitrateKbps': bitrateKbps,
      'hasCover': hasCover,
      'cutoffKhz': cutoffKhz,
      'maxKhz': maxKhz,
      'slopeDropDb': slopeDropDb,
      'score': score,
      'verdict': verdict,
      'status': status,
      'isFake24': isFake24,
      'spectrumBands': spectrumBands,
      'hasLyrics': hasLyrics,
      'lyricsText': lyricsText,
      'audioMd5': audioMd5,
      if (error != null) 'error': error,
    };
  }

  factory FlacInfo.fromJson(Map<String, dynamic> json) {
    return FlacInfo(
      filePath: json['filePath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSizeMb: (json['fileSizeMb'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 44100,
      bitDepth: (json['bitDepth'] as num?)?.toInt() ?? 16,
      channels: (json['channels'] as num?)?.toInt() ?? 2,
      durationSec: (json['durationSec'] as num?)?.toDouble() ?? 0.0,
      durationStr: json['durationStr'] as String? ?? '0m 00s',
      bitrateKbps: (json['bitrateKbps'] as num?)?.toInt() ?? 0,
      hasCover: json['hasCover'] as bool? ?? false,
      coverBytes: null, // Lazy-loaded on demand to preserve RAM
      cutoffKhz: (json['cutoffKhz'] as num?)?.toDouble() ?? 0.0,
      maxKhz: (json['maxKhz'] as num?)?.toDouble() ?? 0.0,
      slopeDropDb: (json['slopeDropDb'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      verdict: json['verdict'] as String? ?? '',
      status: json['status'] as String? ?? 'genuine',
      isFake24: json['isFake24'] as bool? ?? false,
      spectrumBands: (json['spectrumBands'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      spectrogramMatrix: const [], // Lazy-loaded on demand during deep analysis
      hasLyrics: json['hasLyrics'] as bool? ?? false,
      lyricsText: json['lyricsText'] as String?,
      audioMd5: json['audioMd5'] as String?,
      error: json['error'] as String?,
    );
  }

  factory FlacInfo.withError(String filePath, String fileName, String error) {
    return FlacInfo(
      filePath: filePath,
      fileName: fileName,
      fileSizeMb: 0.0,
      title: fileName,
      artist: 'Unknown',
      album: 'Unknown',
      sampleRate: 0,
      bitDepth: 0,
      channels: 0,
      durationSec: 0,
      durationStr: '0m 00s',
      bitrateKbps: 0,
      hasCover: false,
      cutoffKhz: 0,
      maxKhz: 0,
      slopeDropDb: 0.0,
      score: 0,
      verdict: error,
      status: 'fake',
      isFake24: false,
      spectrumBands: const [],
      spectrogramMatrix: const [],
      hasLyrics: false,
      lyricsText: null,
      audioMd5: null,
      error: error,
    );
  }
}
