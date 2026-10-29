import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../widgets/glass_card.dart';
import 'inspect_screen.dart';

class AuditScreen extends StatefulWidget {
  final ValueChanged<FlacInfo>? onInspectTrack;

  const AuditScreen({super.key, this.onInspectTrack});

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

  void _openTrackModal(FlacInfo track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: appState.isAmoled ? const Color(0xFF07090F) : const Color(0xFF101420),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.15))),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: InspectScreen(initialTrack: track),
            ),
          ],
        ),
      ),
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
                borderRadius: 22,
                borderColor: const Color(0xFF6C63FF).withOpacity(0.25),
                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.06),
                onTap: _isScanning ? null : _scanFolder,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.folder_special_rounded, color: Color(0xFF8E85FF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isScanning ? 'Scanning Library...' : 'Scan Music Folder',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55)),
                          ),
                        ],
                      ),
                    ),
                    if (_isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF8E85FF)),
                      )
                    else
                      const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
                  ],
                ),
              ),
            ),

            // 5 Summary Metrics Bar (Scanned, Genuine, Suspicious, Fake, Avg Score)
            if (tracks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _buildStatPill('Total', '${tracks.length}', Colors.white70),
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
                    _buildFilterChip('All (${tracks.length})', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Genuine ($genuineCount)', 'genuine'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Suspicious ($suspiciousCount)', 'suspicious'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Fake ($fakeCount)', 'fake'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Scanned Tracks List with Album Art Thumbnails
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.library_music_rounded, size: 52, color: Colors.white.withOpacity(0.15)),
                          const SizedBox(height: 12),
                          Text(
                            'No folder scanned yet',
                            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the scan button above to audit your music collection',
                            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.35)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      itemCount: filteredTracks.length + 1, // +1 for bottom buffer
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index == filteredTracks.length) {
                          // CRITICAL: 120px Bottom buffer so floating nav bar never overlaps!
                          return const SizedBox(height: 120);
                        }

                        final item = filteredTracks[index];
                        final color = _getStatusColor(item.status);

                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(10),
                          borderRadius: 16,
                          borderColor: color.withOpacity(0.22),
                          onTap: () => _openTrackModal(item),
                          child: Row(
                            children: [
                              // 42px Album Art Thumbnail or Icon
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
                                            color: Colors.white.withOpacity(0.06),
                                            child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 24),
                                          ),
                                  ),
                                  // Tiny circular score pill on top of artwork
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${item.score}',
                                      style: const TextStyle(
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
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.artist} • ${item.bitDepth}-bit / ${item.sampleRate ~/ 1000}kHz',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.55),
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.durationStr,
                                    style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.35)),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white.withOpacity(0.25)),
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
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(fontSize: 8.5, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D2FF).withOpacity(0.18) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D2FF) : Colors.white10,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF00D2FF) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
