import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_settings.dart';
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

  @override
  void initState() {
    super.initState();
    _checkSharedLibrary();
  }

  void _checkSharedLibrary() {
    if (appState.sharedLibrary.isNotEmpty) {
      final detected = DuplicateDetector.findDuplicates(appState.sharedLibrary);
      setState(() {
        _groups = detected;
        _scannedCount = appState.sharedLibrary.length;
      });
    }
  }

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

      appState.setSharedLibrary(tracks, dirPath);
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
        backgroundColor: const Color(0xFF131826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete Duplicate?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Delete "${item.info.fileName}" (${item.info.fileSizeMb} MB)?\n\nThis cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        appState.removeTrackFromLibrary(item.info.filePath);
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
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        return Column(
          children: [
            // Action Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: GlassCard(
                borderRadius: 22,
                borderColor: const Color(0xFFFFB300).withOpacity(0.25),
                backgroundColor: const Color(0xFFFFB300).withOpacity(0.06),
                onTap: _isScanning ? null : _scanForDuplicates,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.copy_all_rounded, color: Color(0xFFFFB300), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isScanning ? 'Analyzing Duplicates...' : 'Find Audio Duplicates',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isScanning
                                ? 'Scanned $_scannedCount tracks'
                                : appState.lastScannedFolder != null
                                    ? 'Analyzed from current library (${appState.sharedLibrary.length} tracks)'
                                    : 'Scan folder to identify redundant tracks',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: subTextColor),
                          ),
                        ],
                      ),
                    ),
                    if (_isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFFFB300)),
                      )
                    else
                      Icon(Icons.search_rounded, color: subTextColor, size: 22),
                  ],
                ),
              ),
            ),

            // Summary Bar if duplicates found
            if (_groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        borderRadius: 14,
                        borderColor: const Color(0xFFFFB300).withOpacity(0.25),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_groups.length} Duplicate Sets Found',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3D3D).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFF3D3D).withOpacity(0.4)),
                              ),
                              child: Text(
                                'Wasted: ${_totalWastedMb.toStringAsFixed(1)} MB',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFF3D3D),
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

            const SizedBox(height: 6),

            // Duplicates List
            Expanded(
              child: _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cleaning_services_rounded, size: 50, color: subTextColor.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No duplicate sets detected',
                            style: TextStyle(fontSize: 14, color: subTextColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select a directory or audit your library to find copies',
                            style: TextStyle(fontSize: 11.5, color: subTextColor.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      itemCount: _groups.length + 1,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, gIndex) {
                        if (gIndex == _groups.length) {
                          // CRITICAL: 140px Bottom buffer so floating nav bar never collides
                          return const SizedBox(height: 140);
                        }

                        final group = _groups[gIndex];
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
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
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          group.artist,
                                          style: TextStyle(fontSize: 11.5, color: subTextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${group.items.length} copies',
                                      style: TextStyle(fontSize: 10.5, color: subTextColor),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: Colors.white.withOpacity(0.07), height: 18),

                              // List items in this group
                              ...group.items.map((item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: item.isBest
                                        ? const Color(0xFF00E676).withOpacity(0.08)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: item.isBest
                                          ? const Color(0xFF00E676).withOpacity(0.35)
                                          : Colors.white.withOpacity(0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: item.isBest
                                              ? const Color(0xFF00E676)
                                              : const Color(0xFFFFB300).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          item.isBest ? 'KEEP' : 'DUP',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: item.isBest ? Colors.black : const Color(0xFFFFB300),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.info.fileName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.reason} • ${item.info.fileSizeMb} MB',
                                              style: TextStyle(fontSize: 10.5, color: subTextColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!item.isBest)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3D3D), size: 19),
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
      },
    );
  }
}
