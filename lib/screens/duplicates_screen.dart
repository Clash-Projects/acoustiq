import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../services/duplicate_detector.dart';
import '../widgets/glass_card.dart';

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  List<DuplicateGroup> _groups = [];
  bool _isScanning = false;
  int _scannedCount = 0;

  Future<void> _scanForDuplicates() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    setState(() {
      _isScanning = true;
      _groups.clear();
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

      final List<FlacInfo> tracks = [];
      for (final file in flacFiles) {
        final info = await FlacParser.analyzeFile(file.path);
        tracks.add(info);
        if (mounted) {
          setState(() => _scannedCount++);
        }
      }

      final detected = DuplicateDetector.findDuplicates(tracks);
      if (mounted) {
        setState(() {
          _groups = detected;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  double get _totalWastedMb {
    return _groups.fold<double>(0.0, (sum, g) => sum + g.wastedMb);
  }

  Future<void> _confirmDelete(DuplicateItem item, DuplicateGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Duplicate?', style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          'Delete "${item.info.fileName}" (${item.info.fileSizeMb} MB)?\n\nThis cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3D3D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final file = File(item.info.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        setState(() {
          group.items.remove(item);
          if (group.items.length <= 1) {
            _groups.remove(group);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Duplicate deleted successfully!'), backgroundColor: Color(0xFF00E676)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GlassCard(
            borderRadius: 24,
            borderColor: const Color(0xFFFFB300).withOpacity(0.3),
            backgroundColor: const Color(0xFFFFB300).withOpacity(0.06),
            onTap: _isScanning ? null : _scanForDuplicates,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.copy_all_rounded, color: Color(0xFFFFB300), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isScanning ? 'Analyzing Duplicates...' : 'Find Audio Duplicates',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isScanning ? 'Scanned $_scannedCount tracks' : 'Scan folder to identify redundant tracks',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFFB300)),
                  )
                else
                  const Icon(Icons.search_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),

        // Summary Bar if duplicates found
        if (_groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    borderRadius: 16,
                    borderColor: const Color(0xFFFFB300).withOpacity(0.25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_groups.length} Duplicate Sets Found',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D3D).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFF3D3D).withOpacity(0.4)),
                          ),
                          child: Text(
                            'Wasted: ${_totalWastedMb.toStringAsFixed(1)} MB',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3D3D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Duplicates List
        Expanded(
          child: _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cleaning_services_rounded, size: 54, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 14),
                      Text(
                        'No duplicate sets detected',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a directory to compare track purity and bitrates',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: _groups.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, gIndex) {
                    final group = _groups[gIndex];
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      borderRadius: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Title & Artist
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      group.artist,
                                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${group.items.length} copies',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),

                          // List items in this group
                          ...group.items.map((item) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: item.isBest
                                    ? const Color(0xFF00E676).withOpacity(0.08)
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: item.isBest
                                      ? const Color(0xFF00E676).withOpacity(0.4)
                                      : Colors.white10,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item.isBest
                                          ? const Color(0xFF00E676)
                                          : const Color(0xFFFFB300).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.isBest ? 'KEEP' : 'DUP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: item.isBest ? Colors.black : const Color(0xFFFFB300),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.info.fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.reason} • ${item.info.fileSizeMb} MB',
                                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!item.isBest)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3D3D), size: 20),
                                      onPressed: () => _confirmDelete(item, group),
                                      tooltip: 'Delete Duplicate',
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

