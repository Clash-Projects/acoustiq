import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flac_toolkit/models/flac_info.dart';
import 'package:flac_toolkit/services/thumbnail_cache.dart';

FlacInfo _makeTrack({
  String status = 'genuine',
  int score = 95,
  Uint8List? coverBytes,
  List<List<double>> spectrogramMatrix = const [],
}) {
  return FlacInfo(
    filePath: '/music/demo.flac',
    fileName: 'demo.flac',
    fileSizeMb: 42.5,
    title: 'Paaro',
    artist: 'Aditya Rikhari',
    album: 'Paaro',
    sampleRate: 96000,
    bitDepth: 24,
    channels: 2,
    durationSec: 153.0,
    durationStr: '2m 33s',
    bitrateKbps: 2840,
    hasCover: coverBytes != null,
    coverBytes: coverBytes,
    cutoffKhz: 24.0,
    maxKhz: 48.0,
    slopeDropDb: 1.5,
    score: score,
    verdict: 'Studio Master',
    status: status,
    isFake24: false,
    spectrumBands: const [0.8, 0.7, 0.5],
    spectrogramMatrix: spectrogramMatrix,
    hasLyrics: true,
    lyricsText: '[00:01.00]Test line',
    audioMd5: 'abc123md5',
  );
}

void main() {
  group('FlacInfo model', () {
    test('computes shortBadge across all quality tiers', () {
      expect(_makeTrack(status: 'untested', score: 99).shortBadge, 'UNTESTED');
      expect(_makeTrack(status: 'pending', score: 99).shortBadge, 'UNTESTED');
      expect(_makeTrack(score: 94).shortBadge, 'GENUINE LOSSLESS');
      expect(_makeTrack(score: 84).shortBadge, 'STUDIO MASTER');
      expect(_makeTrack(score: 65).shortBadge, 'SUSPICIOUS UPSCALE');
      expect(_makeTrack(score: 25).shortBadge, 'FAKE LOSSLESS');
    });

    test('round-trips JSON while keeping heavy binary/matrix fields lazy', () {
      final original = _makeTrack(
        coverBytes: Uint8List.fromList([1, 2, 3, 4]),
        spectrogramMatrix: const [
          [0.1, 0.2],
        ],
      );
      final json = original.toJson();
      final decoded = FlacInfo.fromJson(json);

      expect(decoded.filePath, original.filePath);
      expect(decoded.title, original.title);
      expect(decoded.sampleRate, 96000);
      expect(decoded.bitDepth, 24);
      expect(decoded.score, 95);
      expect(decoded.spectrumBands, [0.8, 0.7, 0.5]);
      expect(decoded.lyricsText, '[00:01.00]Test line');
      expect(decoded.audioMd5, 'abc123md5');
      expect(decoded.coverBytes, isNull);
      expect(decoded.spectrogramMatrix, isEmpty);
    });

    test('copyWith updates target fields without mutating source', () {
      final base = _makeTrack(score: 88);
      final updated = base.copyWith(score: 98, status: 'genuine');

      expect(base.score, 88);
      expect(updated.score, 98);
      expect(updated.title, base.title);
      expect(updated.lyrics, base.lyricsText);
    });
  });

  group('ThumbnailCacheService', () {
    setUp(() => ThumbnailCacheService.instance.clear());
    tearDown(() => ThumbnailCacheService.instance.clear());

    test('stores, retrieves, and clears cached bytes', () {
      final cache = ThumbnailCacheService.instance;
      final bytes = Uint8List.fromList([10, 20, 30]);

      expect(cache.getCached('/music/a.flac'), isNull);
      cache.put('/music/a.flac', bytes);
      expect(cache.getCached('/music/a.flac'), bytes);

      cache.clear();
      expect(cache.getCached('/music/a.flac'), isNull);
    });
  });
}
