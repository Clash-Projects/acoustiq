import '../models/flac_info.dart';

class DuplicateGroup {
  final String key;
  final String title;
  final String artist;
  final List<DuplicateItem> items;
  final double wastedMb;

  DuplicateGroup({
    required this.key,
    required this.title,
    required this.artist,
    required this.items,
    required this.wastedMb,
  });
}

class DuplicateItem {
  final FlacInfo info;
  final bool isBest;
  final String reason;

  DuplicateItem({
    required this.info,
    required this.isBest,
    required this.reason,
  });
}

class DuplicateDetector {
  static String normalize(String text) {
    if (text.isEmpty) return '';
    String t = text.toLowerCase().trim();
    // Remove (official video), [remastered], etc.
    t = t.replaceAll(RegExp(r'[\(\[\{](official\s*(audio|video|lyric\s*video)?|audio|remastered|remaster)[\)\]\}]'), '');
    // Remove feat / ft
    t = t.replaceAll(RegExp(r'\b(feat\.?|ft\.?)\b.*'), '');
    // Remove punctuation
    t = t.replaceAll(RegExp(r'[^\w\s]'), '');
    // Collapse whitespace
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<DuplicateGroup> findDuplicates(List<FlacInfo> tracks) {
    final Map<String, List<FlacInfo>> groups = {};

    for (final track in tracks) {
      if (track.error != null) continue;
      final normArtist = normalize(track.artist);
      final normTitle = normalize(track.title);

      String key;
      if (normTitle.isNotEmpty && normArtist.isNotEmpty && normArtist != 'unknown artist') {
        key = '$normArtist - $normTitle';
      } else {
        key = normalize(track.fileName);
      }

      groups.putIfAbsent(key, () => []).add(track);
    }

    final List<DuplicateGroup> result = [];

    groups.forEach((key, list) {
      if (list.length > 1) {
        // Sort descending: score, then bitrate, then sampleRate
        list.sort((a, b) {
          int cmp = b.score.compareTo(a.score);
          if (cmp != 0) return cmp;
          cmp = b.bitrateKbps.compareTo(a.bitrateKbps);
          if (cmp != 0) return cmp;
          return b.sampleRate.compareTo(a.sampleRate);
        });

        final best = list.first;
        final items = <DuplicateItem>[];
        double wasted = 0.0;

        for (int i = 0; i < list.length; i++) {
          final item = list[i];
          final isBest = i == 0;
          if (!isBest) wasted += item.fileSizeMb;

          String reason;
          if (isBest) {
            reason = 'Best Quality (${item.bitDepth}-bit / ${item.sampleRate ~/ 1000}kHz, ${item.bitrateKbps} kbps)';
          } else {
            final diff = best.score - item.score;
            if (diff > 0) {
              reason = 'Lower Score (-$diff pts, ${item.bitrateKbps} kbps)';
            } else {
              reason = 'Lower Bitrate (${item.bitrateKbps} vs ${best.bitrateKbps} kbps)';
            }
          }

          items.add(DuplicateItem(
            info: item,
            isBest: isBest,
            reason: reason,
          ));
        }

        result.add(DuplicateGroup(
          key: key,
          title: best.title,
          artist: best.artist,
          items: items,
          wastedMb: double.parse(wasted.toStringAsFixed(2)),
        ));
      }
    });

    return result;
  }
}

