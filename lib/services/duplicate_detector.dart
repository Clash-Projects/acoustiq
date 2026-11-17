import '../models/flac_info.dart';

class DuplicateGroup {
  final String key;
  final String title;
  final String artist;
  final List<DuplicateItem> items;
  final double wastedMb;
  final bool isMd5Identical;
  final String bestFilePath;

  DuplicateGroup({
    required this.key,
    required this.title,
    required this.artist,
    required this.items,
    required this.wastedMb,
    this.isMd5Identical = false,
    required this.bestFilePath,
  });

  DuplicateGroup copyWith({
    List<DuplicateItem>? items,
    double? wastedMb,
    String? bestFilePath,
  }) {
    return DuplicateGroup(
      key: key,
      title: title,
      artist: artist,
      items: items ?? this.items,
      wastedMb: wastedMb ?? this.wastedMb,
      isMd5Identical: isMd5Identical,
      bestFilePath: bestFilePath ?? this.bestFilePath,
    );
  }

  DuplicateGroup withCustomBest(String targetPath) {
    final updatedItems = items.map((it) {
      final isTarget = it.info.filePath == targetPath;
      return it.copyWith(isBest: isTarget);
    }).toList();

    double newWasted = 0.0;
    for (final it in updatedItems) {
      if (!it.isBest) newWasted += it.info.fileSizeMb;
    }

    return copyWith(
      items: updatedItems,
      wastedMb: double.parse(newWasted.toStringAsFixed(2)),
      bestFilePath: targetPath,
    );
  }
}

class DuplicateItem {
  final FlacInfo info;
  final bool isBest;
  final String reason;
  final List<String> superiorityBadges;
  final double vectorScore;

  DuplicateItem({
    required this.info,
    required this.isBest,
    required this.reason,
    this.superiorityBadges = const [],
    this.vectorScore = 0.0,
  });

  DuplicateItem copyWith({
    bool? isBest,
    String? reason,
    List<String>? superiorityBadges,
    double? vectorScore,
  }) {
    return DuplicateItem(
      info: info,
      isBest: isBest ?? this.isBest,
      reason: reason ?? this.reason,
      superiorityBadges: superiorityBadges ?? this.superiorityBadges,
      vectorScore: vectorScore ?? this.vectorScore,
    );
  }
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

  static double _calculateVectorScore(FlacInfo t, bool isMd5, FlacInfo? smallestFile) {
    double score = 0.0;
    // 1. Lossless Purity (0 - 1000 base pts)
    if (t.status != 'untested' && t.score > 0) {
      score += t.score * 10.0;
    } else {
      score += 500.0;
    }

    // 2. Bit depth (24-bit studio master bonus)
    if (t.bitDepth >= 24) {
      score += 150.0;
    } else if (t.bitDepth >= 20) {
      score += 50.0;
    }

    // 3. Sample rate (88.2k/96k/192k studio bonus)
    if (t.sampleRate >= 88200) {
      score += 150.0;
    } else if (t.sampleRate >= 48000) {
      score += 30.0;
    }

    // 4. Embedded metadata (lyrics & artwork)
    if (t.hasLyrics) score += 60.0;
    if (t.hasCover) score += 40.0;

    // 5. Compression efficiency or bitrate
    if (isMd5 && smallestFile != null && t.filePath == smallestFile.filePath) {
      score += 80.0; // Bit-identical: smaller file is better compressed
    } else {
      score += (t.bitrateKbps / 100.0);
    }

    return score;
  }

  static List<String> _buildSuperiorityBadges(FlacInfo t, bool isMd5, bool isSmallest) {
    final badges = <String>[];
    if (t.status == 'genuine' && t.score >= 80) {
      badges.add('🏆 Master');
    } else if (t.status == 'fake' || t.score < 50) {
      badges.add('⚠️ Transcode');
    }

    if (t.bitDepth >= 24 || t.sampleRate >= 88200) {
      badges.add('✨ Hi-Res ${(t.sampleRate / 1000).toStringAsFixed(0)}k');
    }

    if (t.hasLyrics) {
      badges.add('🎵 Synced Lyrics');
    }

    if (isMd5 && isSmallest) {
      badges.add('💾 Best Compression');
    }

    return badges;
  }

  static DuplicateGroup _buildGroup({
    required String key,
    required List<FlacInfo> list,
    required bool isMd5,
  }) {
    FlacInfo? smallestInMd5;
    if (isMd5 && list.isNotEmpty) {
      smallestInMd5 = list.reduce((a, b) => a.fileSizeMb < b.fileSizeMb ? a : b);
    }

    // Multi-Vector Ranking: Score based on purity, bit-depth, sampling, lyrics, and compression
    final scoredTracks = list.map((t) {
      final vScore = _calculateVectorScore(t, isMd5, smallestInMd5);
      return MapEntry(t, vScore);
    }).toList();

    scoredTracks.sort((a, b) {
      if ((b.value - a.value).abs() > 0.001) {
        return b.value.compareTo(a.value);
      }
      return a.key.fileSizeMb.compareTo(b.key.fileSizeMb);
    });

    final sorted = scoredTracks.map((e) => e.key).toList();
    final best = sorted.first;

    final items = <DuplicateItem>[];
    double wasted = 0.0;

    for (int i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final itemVectorScore = scoredTracks[i].value;
      final isBest = i == 0;
      if (!isBest) wasted += item.fileSizeMb;

      final isSmallest = item.filePath == smallestInMd5?.filePath;
      final badges = _buildSuperiorityBadges(item, isMd5, isSmallest);

      String reason;
      if (isBest) {
        if (isMd5) {
          reason = 'Bit-Identical Audio • Best Compression (${item.fileSizeMb.toStringAsFixed(1)} MB)';
        } else if (item.status == 'genuine') {
          reason = 'Highest Authenticity (${item.score}% • ${item.bitDepth}-bit / ${(item.sampleRate / 1000).toStringAsFixed(1)}k)';
        } else {
          reason = 'Highest Quality (${item.bitDepth}-bit / ${(item.sampleRate / 1000).toStringAsFixed(1)}k • ${item.bitrateKbps} kbps)';
        }
      } else if (isMd5) {
        reason = 'Bit-Identical Audio Stream (MD5 Verified) • Redundant copy (${item.fileSizeMb.toStringAsFixed(1)} MB)';
      } else if (best.score > item.score && item.score > 0) {
        reason = 'Lower Authenticity (${item.score}% vs ${best.score}%) • Likely lossy transcode';
      } else if (best.bitDepth > item.bitDepth) {
        reason = 'Lower Resolution (${item.bitDepth}-bit vs ${best.bitDepth}-bit Studio Master)';
      } else if (best.sampleRate > item.sampleRate) {
        reason = 'Lower Sample Rate (${(item.sampleRate / 1000).toStringAsFixed(1)}k vs ${(best.sampleRate / 1000).toStringAsFixed(1)}k)';
      } else if (!item.hasLyrics && best.hasLyrics) {
        reason = 'Missing Synced Lyrics & lower metadata fidelity';
      } else if (best.bitrateKbps > item.bitrateKbps) {
        reason = 'Lower Bitrate (${item.bitrateKbps} vs ${best.bitrateKbps} kbps)';
      } else {
        reason = 'Redundant Duplicate Copy (${item.fileSizeMb.toStringAsFixed(1)} MB)';
      }

      items.add(DuplicateItem(
        info: item,
        isBest: isBest,
        reason: reason,
        superiorityBadges: badges,
        vectorScore: itemVectorScore,
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
      bestFilePath: best.filePath,
    );
  }
}
