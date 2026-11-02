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
    this.error,
  });

  /// Concise Studio Badge (Prevents mobile UI text truncation)
  String get shortBadge {
    if (score >= 90) return 'GENUINE LOSSLESS';
    if (score >= 80) return 'STUDIO MASTER';
    if (score >= 50) return 'SUSPICIOUS UPSCALE';
    return 'FAKE LOSSLESS';
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
      error: error,
    );
  }
}
