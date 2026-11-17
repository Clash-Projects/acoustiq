import '../models/flac_info.dart';

class DuplicateGroup {
  final String key;
  final String title;
  final String artist;
  final List<DuplicateItem> items;
  final double wastedMb;
  final bool isMd5Identical;

  DuplicateGroup({
    required this.key,
    required this.title,
    required this.artist,
    required this.items,
    required this.wastedMb,
    this.isMd5Identical = false,
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

  /// Detects duplicate audio sets using a 2-stage precision engine:
  /// 1. Bit-Identical STREAMINFO MD5 hash matching (100% exact audio clones).
  /// 2. Metadata matching with strict duration tolerance (<= 4.0s) to prevent
  ///    Studio vs Live/Extended mixes from being erroneously grouped and deleted.
  static List<DuplicateGroup> findDuplicates(List<FlacInfo> tracks) {
    final validTracks = tracks.where((t) => t.error == null).toList();
    final List<DuplicateGroup> result = [];
    final Set<String> processedPaths = {};

    // --- Stage 1: Exact Bit-Identical FLAC STREAMINFO MD5 Matching ---
    final Map<String, List<FlacInfo>> md5Map = {};
    for (final track in validTracks) {
      final md5 = track.audioMd5;
      if (md5 != null && md5.isNotEmpty && md5.length == 32) {
        md5Map.putIfAbsent(md5, () => []).add(track);
      }
    }

    md5Map.forEach((md5, list) {
      if (list.length > 1) {
        final group = _buildGroup(
          key: 'md5_$md5',
          list: list,
          isMd5: true,
        );
        result.add(group);
        for (final t in list) {
          processedPaths.add(t.filePath);
        }
      }
    });

    // --- Stage 2: Normalized Metadata Matching with Strict Duration Tolerance (<= 4.0s) ---
    final Map<String, List<FlacInfo>> metaMap = {};
    for (final track in validTracks) {
      if (processedPaths.contains(track.filePath)) continue;

      final normArtist = normalize(track.artist);
      final normTitle = normalize(track.title);

      String key;
      if (normTitle.isNotEmpty && normArtist.isNotEmpty && normArtist != 'unknown artist') {
        key = '$normArtist - $normTitle';
      } else {
        key = normalize(track.fileName.replaceAll(RegExp(r'\.flac$', caseSensitive: false), ''));
      }

      metaMap.putIfAbsent(key, () => []).add(track);
    }

    metaMap.forEach((key, list) {
      if (list.length <= 1) return;

      // Cluster tracks by duration tolerance (<= 4.0s).
      // Tracks differing by > 4.0s (e.g. Studio 3:30 vs Live 6:15) belong to separate clusters.
      final List<List<FlacInfo>> clusters = [];

      for (final track in list) {
        bool addedToCluster = false;
        for (final cluster in clusters) {
          // Compare against the reference track of this cluster
          final ref = cluster.first;
          final durationDiff = (track.durationSec - ref.durationSec).abs();
          if (track.durationSec > 0 && ref.durationSec > 0 && durationDiff <= 4.0) {
            cluster.add(track);
            addedToCluster = true;
            break;
          }
        }
        if (!addedToCluster) {
          clusters.add([track]);
        }
      }

      for (int c = 0; c < clusters.length; c++) {
        final cluster = clusters[c];
        if (cluster.length > 1) {
          final groupKey = clusters.length > 1 ? '${key}_cluster$c' : key;
          result.add(_buildGroup(
            key: groupKey,
            list: cluster,
            isMd5: false,
          ));
        }
      }
    });

    return result;
  }

  static DuplicateGroup _buildGroup({
    required String key,
    required List<FlacInfo> list,
    required bool isMd5,
  }) {
    // Sort descending: score, then bitDepth, then sampleRate, then bitrateKbps, then smaller size
    final sorted = List<FlacInfo>.from(list)..sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      if (b.bitDepth != a.bitDepth) return b.bitDepth.compareTo(a.bitDepth);
      if (b.sampleRate != a.sampleRate) return b.sampleRate.compareTo(a.sampleRate);
      if (b.bitrateKbps != a.bitrateKbps) return b.bitrateKbps.compareTo(a.bitrateKbps);
      return a.fileSizeMb.compareTo(b.fileSizeMb);
    });

    final best = sorted.first;
    final items = <DuplicateItem>[];
    double wasted = 0.0;

    for (int i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final isBest = i == 0;
      if (!isBest) wasted += item.fileSizeMb;

      String reason;
      if (isBest) {
        reason = 'Highest Authenticity (${item.score}% • ${item.bitDepth}-bit / ${(item.sampleRate / 1000).toStringAsFixed(1)}k)';
      } else if (isMd5) {
        reason = 'Bit-Identical Audio Stream (MD5 Verified) • Redundant copy (${item.fileSizeMb.toStringAsFixed(1)} MB)';
      } else if (best.score > item.score) {
        reason = 'Lower Authenticity (${item.score}% vs ${best.score}%)';
      } else if (best.bitDepth > item.bitDepth) {
        reason = 'Lower Bit Depth (${item.bitDepth}-bit vs ${best.bitDepth}-bit)';
      } else if (best.sampleRate > item.sampleRate) {
        reason = 'Lower Sample Rate (${(item.sampleRate / 1000).toStringAsFixed(1)}k vs ${(best.sampleRate / 1000).toStringAsFixed(1)}k)';
      } else if (best.bitrateKbps > item.bitrateKbps) {
        reason = 'Lower Bitrate (${item.bitrateKbps} vs ${best.bitrateKbps} kbps)';
      } else {
        reason = 'Redundant Copy (${item.fileSizeMb.toStringAsFixed(1)} MB)';
      }

      items.add(DuplicateItem(
        info: item,
        isBest: isBest,
        reason: reason,
      ));
    }

    final displayTitle = best.title.isNotEmpty ? best.title : best.fileName;
    final displayArtist = best.artist.isNotEmpty ? best.artist : 'Unknown Artist';

    return DuplicateGroup(
      key: key,
      title: displayTitle,
      artist: displayArtist,
      items: items,
      wastedMb: double.parse(wasted.toStringAsFixed(2)),
      isMd5Identical: isMd5,
    );
  }
}

