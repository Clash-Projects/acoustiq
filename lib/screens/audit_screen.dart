import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_gauge.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  bool _isScanning = false;
  int _scannedCount = 0;
  String _filter = 'all'; // 'all', 'genuine', 'suspicious', 'fake'

  @override
  void initState() {
    super.initState();
    _scannedCount = appState.sharedLibrary.length;
  }

  Future<void> _scanFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    setState(() {
      _isScanning = true;
      _scannedCount = 0;
    });

    final List<FlacInfo> newTracks = [];

    try {
      final dir = Directory(dirPath);
      final List<File> flacFiles = [];

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.flac')) {
          flacFiles.add(entity);
        }
      }

      for (final file in flacFiles) {
        final info = await FlacParser.analyzeFile(file.path);
        newTracks.add(info);
        if (mounted) {
          setState(() {
            _scannedCount++;
          });
        }
      }

      appState.setSharedLibrary(newTracks, dirPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _openTrackDetail(FlacInfo track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TrackDetailModal(track: track),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'genuine':
        return const Color(0xFF00E676);
      case 'suspicious':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFFFF3D3D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        final tracks = appState.sharedLibrary;
        final filteredTracks = _filter == 'all'
            ? tracks
            : tracks.where((t) => t.status == _filter).toList();

        final genuineCount = tracks.where((t) => t.status == 'genuine').length;
        final suspiciousCount = tracks.where((t) => t.status == 'suspicious').length;
        final fakeCount = tracks.where((t) => t.status == 'fake').length;

        int averageScore = 0;
        if (tracks.isNotEmpty) {
          final total = tracks.fold<int>(0, (sum, item) => sum + item.score);
          averageScore = (total / tracks.length).round();
        }

        return Column(
          children: [
            // Top Action Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: GlassCard(
                borderRadius: 20,
                borderColor: const Color(0xFF00D2FF).withOpacity(0.25),
                backgroundColor: const Color(0xFF00D2FF).withOpacity(0.06),
                onTap: _isScanning ? null : _scanFolder,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2FF).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.folder_special_rounded, color: Color(0xFF00D2FF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isScanning ? 'Scanning Library...' : 'Scan Music Folder',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isScanning
                                ? 'Inspected $_scannedCount FLACs'
                                : appState.lastScannedFolder != null
                                    ? 'Folder: ${appState.lastScannedFolder!.split('/').last} (${tracks.length} tracks)'
                                    : 'Select folder to batch audit FLACs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF00D2FF)),
                      )
                    else
                      Icon(Icons.search_rounded, color: subTextColor, size: 22),
                  ],
                ),
              ),
            ),

            // 5 Summary Metrics Bar
            if (tracks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _buildStatPill('Total', '${tracks.length}', isDark ? Colors.white70 : Colors.black87),
                    const SizedBox(width: 6),
                    _buildStatPill('Genuine', '$genuineCount', const Color(0xFF00E676)),
                    const SizedBox(width: 6),
                    _buildStatPill('Suspicious', '$suspiciousCount', const Color(0xFFFFB300)),
                    const SizedBox(width: 6),
                    _buildStatPill('Fake', '$fakeCount', const Color(0xFFFF3D3D)),
                    const SizedBox(width: 6),
                    _buildStatPill('Avg', '$averageScore%', const Color(0xFF00D2FF)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _buildFilterChip('All (${tracks.length})', 'all', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Genuine ($genuineCount)', 'genuine', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Suspicious ($suspiciousCount)', 'suspicious', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Fake ($fakeCount)', 'fake', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Scanned Tracks List with Album Art Thumbnails
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.library_music_rounded, size: 50, color: subTextColor.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No folder scanned yet',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: subTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the scan button above to audit your music collection',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: subTextColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      itemCount: filteredTracks.length + 1,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index == filteredTracks.length) {
                          // CRITICAL: 140px Bottom buffer so floating nav bar never collides
                          return const SizedBox(height: 140);
                        }

                        final item = filteredTracks[index];
                        final color = _getStatusColor(item.status);

                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(10),
                          borderRadius: 16,
                          borderColor: color.withOpacity(0.22),
                          onTap: () => _openTrackDetail(item),
                          child: Row(
                            children: [
                              // 44px Album Art Thumbnail
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: item.coverBytes != null
                                        ? Image.memory(
                                            item.coverBytes!,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 44,
                                            height: 44,
                                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                                            child: Icon(Icons.music_note_rounded, color: subTextColor, size: 24),
                                          ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${item.score}',
                                      style: const TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.artist} • ${item.bitDepth}-bit / ${item.sampleRate ~/ 1000}kHz',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: subTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.bitrateKbps} kbps',
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: textColor.withOpacity(0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.durationStr,
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 10.5,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 16, color: subTextColor.withOpacity(0.5)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        borderRadius: 14,
        borderColor: color.withOpacity(0.2),
        backgroundColor: color.withOpacity(0.04),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8.5,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D2FF).withOpacity(0.18)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D2FF) : (isDark ? Colors.white10 : Colors.black12),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF00D2FF) : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

// DEDICATED TRACK DETAIL MODAL (Strictly neutral monochrome, zero navy blue)
class _TrackDetailModal extends StatelessWidget {
  final FlacInfo track;

  const _TrackDetailModal({required this.track});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'genuine':
        return const Color(0xFF00E676);
      case 'suspicious':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFFFF3D3D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final statusColor = _getStatusColor(track.status);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141414).withOpacity(0.92)
                : Colors.white.withOpacity(0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.50 : 0.10),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: subTextColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header: Title & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Track Inspection',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: subTextColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Score Gauge
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    borderColor: statusColor.withOpacity(0.25),
                    child: ScoreGauge(
                      score: track.score,
                      status: track.status,
                      cutoffKhz: track.cutoffKhz,
                      maxKhz: track.maxKhz,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Verdict Card
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: statusColor.withOpacity(0.07),
                    borderColor: statusColor.withOpacity(0.30),
                    child: Row(
                      children: [
                        Icon(
                          track.status == 'genuine'
                              ? Icons.verified_rounded
                              : track.status == 'suspicious'
                                  ? Icons.warning_amber_rounded
                                  : Icons.cancel_rounded,
                          color: statusColor,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AUDIT VERDICT',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.verdict,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Track & Specs Card
                  GlassCard(
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: track.coverBytes != null
                                  ? Image.memory(track.coverBytes!, width: 52, height: 52, fit: BoxFit.cover)
                                  : Container(
                                      width: 52,
                                      height: 52,
                                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                                      child: Icon(Icons.album_rounded, color: subTextColor, size: 30),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: subTextColor,
                                    ),
                                  ),
                                  Text(
                                    track.album,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10.5,
                                      color: subTextColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 22),
                        _specRow(Icons.speed_rounded, 'Format & Bitrate', '${track.bitrateKbps} kbps FLAC', textColor, subTextColor),
                        _specRow(Icons.tune_rounded, 'Bit Depth & Sample Rate', '${track.bitDepth}-bit / ${track.sampleRate} Hz', textColor, subTextColor),
                        _specRow(Icons.schedule_rounded, 'Duration & Channels', '${track.durationStr} (${track.channels == 2 ? "Stereo" : "${track.channels}ch"})', textColor, subTextColor),
                        _specRow(Icons.storage_rounded, 'File Size', '${track.fileSizeMb} MB', textColor, subTextColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _specRow(IconData icon, String label, String value, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: subTextColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: subTextColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
