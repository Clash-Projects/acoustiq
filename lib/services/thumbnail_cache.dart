import 'dart:typed_data';
import 'flac_parser.dart';

/// Lightweight In-Memory Artwork & Thumbnail Cache Service
/// Resolves and caches 48x48 / full album artwork on-demand for fast, lag-free UI rendering.
class ThumbnailCacheService {
  ThumbnailCacheService._();
  static final ThumbnailCacheService instance = ThumbnailCacheService._();

  final Map<String, Uint8List?> _cache = {};
  final Set<String> _pending = {};

  /// Synchronously retrieve cached thumbnail bytes if available
  Uint8List? getCached(String filePath) => _cache[filePath];

  /// Asynchronously retrieve or extract cover bytes from FLAC metadata
  Future<Uint8List?> getOrLoadCover(String filePath) async {
    if (_cache.containsKey(filePath)) {
      return _cache[filePath];
    }

    if (_pending.contains(filePath)) {
      // Avoid duplicate parallel extraction jobs for the same path
      while (_pending.contains(filePath)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cache[filePath];
    }

    _pending.add(filePath);
    try {
      final bytes = await FlacParser.extractCoverBytes(filePath);
      _cache[filePath] = bytes;
      return bytes;
    } catch (_) {
      _cache[filePath] = null;
      return null;
    } finally {
      _pending.remove(filePath);
    }
  }

  /// Store manually resolved bytes into cache
  void put(String filePath, Uint8List? bytes) {
    _cache[filePath] = bytes;
  }

  /// Clear cache when library rescan occurs
  void clear() {
    _cache.clear();
    _pending.clear();
  }
}
