import 'package:flutter_test/flutter_test.dart';
import 'package:flac_toolkit/models/flac_info.dart';
import 'package:flac_toolkit/services/duplicate_detector.dart';

FlacInfo _track({
  required String path,
  String title = 'Song',
  String artist = 'Artist',
  int sampleRate = 44100,
  int bitDepth = 16,
  int bitrateKbps = 900,
  double sizeMb = 30.0,
  double durationSec = 200.0,
  int score = 95,
  String status = 'genuine',
  String? md5,
}) {
  return FlacInfo(
    filePath: path,
    fileName: path.split('/').last,
    fileSizeMb: sizeMb,
    title: title,
    artist: artist,
    album: 'Album',
    sampleRate: sampleRate,
    bitDepth: bitDepth,
    channels: 2,
    durationSec: durationSec,
    durationStr: '3m 20s',
    bitrateKbps: bitrateKbps,
    hasCover: false,
    cutoffKhz: status == 'genuine' ? 22.0 : 16.0,
    maxKhz: sampleRate / 2000.0,
    score: score,
    verdict: status,
    status: status,
    isFake24: false,
    audioMd5: md5,
  );
}

void main() {
  group('DuplicateDetector', () {
    test('normalizes featured artists and bracketed suffixes cleanly', () {
      expect(
        DuplicateDetector.normalize('Yellow (Official Video) feat. Someone'),
        'yellow',
      );
      expect(
        DuplicateDetector.normalize('Paaro [Remastered]'),
        'paaro',
      );
    });

    test('stage 1 groups identical MD5 hashes cleanly', () {
      const md5 = 'aabbccddeeff00112233445566778899';
      final a = _track(path: '/music/copy1.flac', sizeMb: 28.0, md5: md5);
      final b = _track(path: '/music/copy2.flac', sizeMb: 31.0, md5: md5);

      final groups = DuplicateDetector.findDuplicates([a, b]);
      expect(groups.length, 1);
      expect(groups.first.isMd5Identical, isTrue);
      expect(groups.first.items.length, 2);
      // Prefers smaller identical MD5 copy (saves more storage)
      expect(groups.first.acoustiqPickPath, '/music/copy1.flac');
    });

    test('stage 2 separates studio vs extended live edits (> 4s delta) and prefers genuine master', () {
      final genuine = _track(
        path: '/music/master.flac',
        title: 'Hymn',
        artist: 'Band',
        sampleRate: 96000,
        bitDepth: 24,
        score: 98,
        status: 'genuine',
        durationSec: 210.0,
        sizeMb: 55.0,
      );
      final fake = _track(
        path: '/music/upsample.flac',
        title: 'Hymn (Remastered)',
        artist: 'Band',
        sampleRate: 44100,
        bitDepth: 16,
        score: 35,
        status: 'fake',
        durationSec: 211.5,
        sizeMb: 25.0,
      );
      final liveExtended = _track(
        path: '/music/live.flac',
        title: 'Hymn',
        artist: 'Band',
        durationSec: 360.0, // > 4s away -> different recording
      );

      final groups = DuplicateDetector.findDuplicates([fake, genuine, liveExtended]);
      expect(groups.length, 1);
      expect(groups.first.isMd5Identical, isFalse);
      expect(groups.first.items.length, 2);
      expect(groups.first.acoustiqPickPath, '/music/master.flac');
    });
  });
}
