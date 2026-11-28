import 'package:flutter_test/flutter_test.dart';
import 'package:flac_toolkit/models/flac_info.dart';
import 'package:flac_toolkit/utils/lyrics_parser.dart';

FlacInfo _trackWithLyrics(String? lyricsText, {String filePath = '/tmp/nonexistent_song.flac'}) {
  return FlacInfo(
    filePath: filePath,
    fileName: 'song.flac',
    fileSizeMb: 28.4,
    title: 'Test Track',
    artist: 'Test Artist',
    album: 'Test Album',
    sampleRate: 44100,
    bitDepth: 16,
    channels: 2,
    durationSec: 180.0,
    durationStr: '3m 00s',
    bitrateKbps: 920,
    hasCover: false,
    cutoffKhz: 22.0,
    maxKhz: 22.05,
    score: 96,
    verdict: 'Genuine Lossless',
    status: 'genuine',
    isFake24: false,
    lyricsText: lyricsText,
  );
}

void main() {
  group('OfflineLyricsParser', () {
    test('returns none for null or empty lyrics', () {
      expect(OfflineLyricsParser.resolveForTrack(null).kind, LyricsSyncKind.none);
      expect(OfflineLyricsParser.resolveForTrack(_trackWithLyrics('')).kind, LyricsSyncKind.none);
      expect(OfflineLyricsParser.resolveForTrack(_trackWithLyrics('   ')).hasLyrics, isFalse);
    });

    test('detects instrumental markers', () {
      for (final marker in ['instrumental', '[Instrumental]', '♪']) {
        final result = OfflineLyricsParser.resolveForTrack(_trackWithLyrics(marker));
        expect(result.kind, LyricsSyncKind.instrumental);
        expect(result.hasLyrics, isTrue);
        expect(result.isSynced, isFalse);
      }
    });

    test('parses plain unsynced lyrics cleanly', () {
      final result = OfflineLyricsParser.resolveForTrack(
        _trackWithLyrics('Line one\nLine two\nLine three'),
      );
      expect(result.kind, LyricsSyncKind.plain);
      expect(result.plainText, 'Line one\nLine two\nLine three');
      expect(result.isSynced, isFalse);
      expect(result.isRtl, isFalse);
    });

    test('parses standard LRC with offset, metadata tags, and binary search active index', () {
      const lrc = '''
[ti:Paro]
[ar:Aditya Rikhari]
[offset:+250]
[00:05.00]Pehli line
[00:10.50]Doosri line
[00:25.00]Teesri line
''';
      final result = OfflineLyricsParser.resolveForTrack(_trackWithLyrics(lrc));
      expect(result.kind, LyricsSyncKind.lineSynced);
      expect(result.isSynced, isTrue);
      expect(result.parsedOffsetMs, 250);

      // Intro gap (>= 3.5s before first vocal at 5000ms) + 3 sung lines + interlude (>= 4.5s gap)
      expect(result.lines.first.isInterlude, isTrue);
      expect(result.lines.first.timeMs, 0);

      final sungLines = result.lines.where((l) => !l.isInterlude).toList();
      expect(sungLines.map((l) => l.text).toList(), ['Pehli line', 'Doosri line', 'Teesri line']);
      expect(sungLines.map((l) => l.timeMs).toList(), [5000, 10500, 25000]);

      // Binary search activeIndexAt sanity checks
      expect(result.activeIndexAt(500), 0); // Intro interlude at 0ms
      final idxFirst = result.lines.indexOf(sungLines[0]);
      final idxSecond = result.lines.indexOf(sungLines[1]);
      expect(result.activeIndexAt(5100), idxFirst);
      expect(result.activeIndexAt(12000), idxSecond);
    });

    test('parses enhanced word-synced LRC syllables', () {
      const elrc = '[00:01.00]<00:01.00>Look <00:01.40>at <00:01.80>the <00:02.20>stars';
      final result = OfflineLyricsParser.resolveForTrack(_trackWithLyrics(elrc));

      expect(result.kind, LyricsSyncKind.wordSynced);
      expect(result.lines.length, 1);
      final line = result.lines.first;
      expect(line.text, 'Look at the stars');
      expect(line.hasSyllables, isTrue);
      expect(line.syllables.map((s) => s.text).toList(), ['Look ', 'at ', 'the ', 'stars']);
      expect(line.syllables.first.timeMs, 1000);
      expect(line.syllables.first.durationMs, 400);
    });

    test('detects RTL scripts cleanly', () {
      expect(OfflineLyricsParser.isRtlText('أحبك جدا'), isTrue);
      expect(OfflineLyricsParser.isRtlText('पारो मेरी पारो'), isFalse);
      expect(OfflineLyricsParser.isRtlText('Look at the stars'), isFalse);
    });
  });
}
