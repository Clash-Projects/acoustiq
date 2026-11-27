import 'dart:io';
import '../models/flac_info.dart';

enum LyricsSyncKind {
  none,
  plain,
  lineSynced,
  wordSynced,
  instrumental,
}

class LyricSyllable {
  final int timeMs;
  final int durationMs;
  final String text;

  const LyricSyllable({
    required this.timeMs,
    required this.durationMs,
    required this.text,
  });
}

class ParsedLyricLine {
  final int timeMs;
  final int durationMs;
  final String text;
  final bool isInterlude;
  final bool isRtl;
  final List<LyricSyllable> syllables;

  const ParsedLyricLine({
    required this.timeMs,
    required this.durationMs,
    required this.text,
    this.isInterlude = false,
    this.isRtl = false,
    this.syllables = const [],
  });

  bool get hasSyllables => syllables.isNotEmpty;
  int get endMs => timeMs + durationMs;
}

class ParsedLyricsResult {
  final LyricsSyncKind kind;
  final List<ParsedLyricLine> lines;
  final String? plainText;
  final String rawExportText;
  final String sourceLabel;
  final int parsedOffsetMs;
  final bool isRtl;

  const ParsedLyricsResult({
    required this.kind,
    this.lines = const [],
    this.plainText,
    this.rawExportText = '',
    this.sourceLabel = 'Embedded FLAC',
    this.parsedOffsetMs = 0,
    this.isRtl = false,
  });

  bool get hasLyrics =>
      kind == LyricsSyncKind.wordSynced ||
      kind == LyricsSyncKind.lineSynced ||
      kind == LyricsSyncKind.plain ||
      kind == LyricsSyncKind.instrumental;

  bool get isSynced =>
      kind == LyricsSyncKind.wordSynced || kind == LyricsSyncKind.lineSynced;

  /// Binary-searches the active row index for [positionMs], or -1 before first line.
  int activeIndexAt(int positionMs) {
    if (lines.isEmpty) return -1;
    if (positionMs < lines.first.timeMs) return -1;
    int lo = 0;
    int hi = lines.length - 1;
    int ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].timeMs <= positionMs) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

/// Strictly 100% offline LRC / Enhanced-LRC / Vorbis Plain lyrics parser.
/// Never triggers network requests and resolves synchronously with zero loading delay.
class OfflineLyricsParser {
  static final RegExp _lineTimeTag = RegExp(r'\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]');
  static final RegExp _wordTimeTag = RegExp(r'<(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?>');
  static final RegExp _metaTag = RegExp(r'^\[(ar|ti|al|au|length|by|re|ve|id):([^\]]*)\]$', caseSensitive: false);
  static final RegExp _offsetTag = RegExp(r'^\[offset:([+-]?\d+)\]$', caseSensitive: false);
  static final RegExp _rtlRegex = RegExp(r'[\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC]');

  static bool isRtlText(String? text) {
    if (text == null || text.isEmpty) return false;
    return _rtlRegex.hasMatch(text);
  }

  static int _parseStampMs(String minStr, String secStr, String? fracStr) {
    final mm = int.tryParse(minStr) ?? 0;
    final ss = int.tryParse(secStr) ?? 0;
    int ms = 0;
    if (fracStr != null && fracStr.isNotEmpty) {
      if (fracStr.length == 1) {
        ms = (int.tryParse(fracStr) ?? 0) * 100;
      } else if (fracStr.length == 2) {
        ms = (int.tryParse(fracStr) ?? 0) * 10;
      } else {
        ms = int.tryParse(fracStr.substring(0, 3)) ?? 0;
      }
    }
    return (mm * 60 + ss) * 1000 + ms;
  }

  static ParsedLyricsResult resolveForTrack(FlacInfo? track) {
    if (track == null) {
      return const ParsedLyricsResult(kind: LyricsSyncKind.none, sourceLabel: 'No Track');
    }

    String raw = track.lyricsText?.trim() ?? '';
    String sourceLabel = 'Embedded FLAC Vorbis';

    if (raw.isEmpty && track.filePath.isNotEmpty) {
      final dot = track.filePath.lastIndexOf('.');
      if (dot > 0) {
        final sidecar = File('${track.filePath.substring(0, dot)}.lrc');
        try {
          if (sidecar.existsSync()) {
            final lrc = sidecar.readAsStringSync().trim();
            if (lrc.isNotEmpty) {
              raw = lrc;
              sourceLabel = 'Local .lrc File';
            }
          }
        } catch (_) {}
      }
    }

    if (raw.isEmpty) {
      return ParsedLyricsResult(kind: LyricsSyncKind.none, sourceLabel: sourceLabel);
    }

    final lowerRaw = raw.toLowerCase();
    if (lowerRaw == 'instrumental' || lowerRaw == '[instrumental]' || lowerRaw == '♪') {
      return ParsedLyricsResult(
        kind: LyricsSyncKind.instrumental,
        rawExportText: raw,
        sourceLabel: sourceLabel,
      );
    }

    final hasLrc = _lineTimeTag.hasMatch(raw);
    if (!hasLrc) {
      return ParsedLyricsResult(
        kind: LyricsSyncKind.plain,
        plainText: raw,
        rawExportText: raw,
        sourceLabel: sourceLabel,
        isRtl: isRtlText(raw),
      );
    }

    int offsetMs = 0;
    final rawRows = <_RawTimedRow>[];

    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final offMatch = _offsetTag.firstMatch(trimmed);
      if (offMatch != null) {
        offsetMs = int.tryParse(offMatch.group(1) ?? '0') ?? 0;
        continue;
      }
      if (_metaTag.hasMatch(trimmed)) continue;

      final matches = _lineTimeTag.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      // Strip leading/multiple [mm:ss.xx] stamps to get body
      final lastEnd = matches.last.end;
      final body = trimmed.substring(lastEnd).trim();

      // Check enhanced LRC <mm:ss.xx> word timestamps inside body
      final wordMatches = _wordTimeTag.allMatches(body).toList();
      final List<LyricSyllable> parsedWords = [];
      String cleanText = body;

      if (wordMatches.isNotEmpty) {
        cleanText = body.replaceAll(_wordTimeTag, '').replaceAll(RegExp(r'\s+'), ' ').trim();
        for (int wi = 0; wi < wordMatches.length; wi++) {
          final wm = wordMatches[wi];
          final wTimeMs = _parseStampMs(wm.group(1)!, wm.group(2)!, wm.group(3));
          final textStart = wm.end;
          final textEnd = (wi + 1 < wordMatches.length) ? wordMatches[wi + 1].start : body.length;
          final segment = body.substring(textStart, textEnd);
          if (segment.isNotEmpty) {
            final nextTimeMs = (wi + 1 < wordMatches.length)
                ? _parseStampMs(
                    wordMatches[wi + 1].group(1)!,
                    wordMatches[wi + 1].group(2)!,
                    wordMatches[wi + 1].group(3),
                  )
                : (wTimeMs + 500);
            parsedWords.add(LyricSyllable(
              timeMs: wTimeMs,
              durationMs: (nextTimeMs - wTimeMs).clamp(120, 6000),
              text: segment,
            ));
          }
        }
      }

      for (final m in matches) {
        final tMs = _parseStampMs(m.group(1)!, m.group(2)!, m.group(3));
        rawRows.add(_RawTimedRow(
          timeMs: tMs,
          text: cleanText,
          syllables: parsedWords,
        ));
      }
    }

    if (rawRows.isEmpty) {
      return ParsedLyricsResult(
        kind: LyricsSyncKind.plain,
        plainText: raw,
        rawExportText: raw,
        sourceLabel: sourceLabel,
        isRtl: isRtlText(raw),
      );
    }

    rawRows.sort((a, b) => a.timeMs.compareTo(b.timeMs));

    // Filter consecutive blank markers cleanly and construct final timed list with interlude dots
    final List<ParsedLyricLine> finalLines = [];
    bool anyWordSync = false;

    for (int i = 0; i < rawRows.length; i++) {
      final row = rawRows[i];
      final nextMs = (i + 1 < rawRows.length) ? rawRows[i + 1].timeMs : (row.timeMs + 4000);
      final gapMs = (nextMs - row.timeMs).clamp(300, 120000);

      if (row.text.isEmpty || row.text == '♪' || row.text == '...') {
        // Explicit blank/instrumental line in LRC -> render as interlude dots if >= 2.2s
        if (gapMs >= 2200) {
          finalLines.add(ParsedLyricLine(
            timeMs: row.timeMs,
            durationMs: gapMs,
            text: '',
            isInterlude: true,
          ));
        }
        continue;
      }

      // Intro instrumental dots if first vocal enters after 3.5s
      if (finalLines.isEmpty && row.timeMs >= 3500) {
        finalLines.add(ParsedLyricLine(
          timeMs: 0,
          durationMs: row.timeMs,
          text: '',
          isInterlude: true,
        ));
      }

      if (row.syllables.isNotEmpty) {
        anyWordSync = true;
      }

      final activeDur = row.syllables.isNotEmpty
          ? (row.syllables.last.timeMs + row.syllables.last.durationMs - row.timeMs).clamp(400, gapMs)
          : gapMs.clamp(500, 9000);

      finalLines.add(ParsedLyricLine(
        timeMs: row.timeMs,
        durationMs: activeDur,
        text: row.text,
        isInterlude: false,
        isRtl: isRtlText(row.text),
        syllables: row.syllables,
      ));

      // Long vocal gap between sung lines (>= 7.0s total gap after estimated line end) -> interlude dots
      final silentGapStart = row.timeMs + activeDur;
      final remainingGap = nextMs - silentGapStart;
      if (i + 1 < rawRows.length && remainingGap >= 4500 && rawRows[i + 1].text.isNotEmpty) {
        finalLines.add(ParsedLyricLine(
          timeMs: silentGapStart,
          durationMs: remainingGap,
          text: '',
          isInterlude: true,
        ));
      }
    }

    if (finalLines.isEmpty) {
      return ParsedLyricsResult(
        kind: LyricsSyncKind.instrumental,
        rawExportText: raw,
        sourceLabel: sourceLabel,
      );
    }

    final meaningful = finalLines.where((l) => !l.isInterlude).toList();
    final rtlCount = meaningful.where((l) => l.isRtl).length;
    final overallRtl = meaningful.isNotEmpty && rtlCount > (meaningful.length / 2);

    return ParsedLyricsResult(
      kind: anyWordSync ? LyricsSyncKind.wordSynced : LyricsSyncKind.lineSynced,
      lines: finalLines,
      rawExportText: raw,
      sourceLabel: sourceLabel,
      parsedOffsetMs: offsetMs,
      isRtl: overallRtl,
    );
  }
}

class _RawTimedRow {
  final int timeMs;
  final String text;
  final List<LyricSyllable> syllables;

  _RawTimedRow({
    required this.timeMs,
    required this.text,
    required this.syllables,
  });
}
