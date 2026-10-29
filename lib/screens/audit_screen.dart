import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../widgets/glass_card.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final List<FlacInfo> _tracks = [];
  bool _isScanning = false;
  int _scannedCount = 0;
  String _filter = 'all'; // 'all', 'genuine', 'suspicious', 'fake'

  Future<void> _scanFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    setState(() {
      _isScanning = true;
      _tracks.clear();
      _scannedCount = 0;
    });

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
        if (mounted) {
          setState(() {
            _tracks.add(info);
            _scannedCount++;
          });
        }
      }
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

  List<FlacInfo> get _filteredTracks {
    if (_filter == 'all') return _tracks;
    return _tracks.where((t) => t.status == _filter).toList();
  }

  int get _genuineCount => _tracks.where((t) => t.status == 'genuine').length;
  int get _suspiciousCount => _tracks.where((t) => t.status == 'suspicious').length;
  int get _fakeCount => _tracks.where((t) => t.status == 'fake').length;

  int get _averageScore {
    if (_tracks.isEmpty) return 0;
    final total = _tracks.fold<int>(0, (sum, item) => sum + item.score);
    return (total / _tracks.length).round();
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
    return Column(
      children: [
        // Top Action & Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GlassCard(
            borderRadius: 24,
            borderColor: const Color(0xFF6C63FF).withOpacity(0.3),
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.06),
            onTap: _isScanning ? null : _scanFolder,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.folder_special_rounded, color: Color(0xFF8E85FF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isScanning ? 'Scanning Library...' : 'Scan Music Folder',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isScanning ? 'Inspected $_scannedCount FLACs' : 'Select folder to batch audit FLACs',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF8E85FF)),
                  )
                else
                  const Icon(Icons.search_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),

        // Metrics Summary Bar (if scanned)
        if (_tracks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStatPill('Scanned', '${_tracks.length}', Colors.white70),
                const SizedBox(width: 8),
                _buildStatPill('Genuine', '$_genuineCount', const Color(0xFF00E676)),
                const SizedBox(width: 8),
                _buildStatPill('Suspicious', '$_suspiciousCount', const Color(0xFFFFB300)),
                const SizedBox(width: 8),
                _buildStatPill('Avg Score', '$_averageScore%', const Color(0xFF00D2FF)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('All (${_tracks.length})', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Genuine ($_genuineCount)', 'genuine'),
                const SizedBox(width: 8),
                _buildFilterChip('Suspicious ($_suspiciousCount)', 'suspicious'),
                const SizedBox(width: 8),
                _buildFilterChip('Fake ($_fakeCount)', 'fake'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Scanned Tracks List
        Expanded(
          child: _tracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.library_music_rounded, size: 54, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 14),
                      Text(
                        'No folder scanned yet',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the scan button above to audit your music library',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _filteredTracks.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final item = _filteredTracks[index];
                    final color = _getStatusColor(item.status);
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      borderRadius: 16,
                      borderColor: color.withOpacity(0.2),
                      child: Row(
                        children: [
                          // Score Circle Indicator
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.12),
                              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                '${item.score}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
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
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.bitrateKbps} kbps',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.durationStr,
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        borderRadius: 14,
        borderColor: color.withOpacity(0.2),
        backgroundColor: color.withOpacity(0.04),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D2FF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D2FF) : Colors.white12,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF00D2FF) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

