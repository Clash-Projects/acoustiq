import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_gauge.dart';

class InspectScreen extends StatefulWidget {
  final FlacInfo? initialTrack;

  const InspectScreen({super.key, this.initialTrack});

  @override
  State<InspectScreen> createState() => _InspectScreenState();
}

class _InspectScreenState extends State<InspectScreen> {
  FlacInfo? _info;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _info = widget.initialTrack;
  }

  Future<void> _pickAndAnalyzeFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['flac'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final analyzed = await FlacParser.analyzeFile(path);
        setState(() {
          _info = analyzed;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error choosing file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Select File Button / Action Card
          GlassCard(
            borderRadius: 22,
            borderColor: const Color(0xFF00D2FF).withOpacity(0.25),
            backgroundColor: const Color(0xFF00D2FF).withOpacity(0.06),
            onTap: _isLoading ? null : _pickAndAnalyzeFile,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D2FF).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.audio_file_rounded, color: Color(0xFF00D2FF), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _info == null ? 'Select FLAC File' : 'Change Audio File',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _info == null ? 'Tap to browse and inspect purity' : _info!.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF00D2FF)),
                  )
                else
                  const Icon(Icons.folder_open_rounded, color: Colors.white70, size: 22),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (_info != null) ...[
            // Score Arc Meter & Cutoff Indicator
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              borderColor: _getStatusColor(_info!.status).withOpacity(0.25),
              child: ScoreGauge(
                score: _info!.score,
                status: _info!.status,
                cutoffKhz: _info!.cutoffKhz,
                maxKhz: _info!.maxKhz,
              ),
            ),

            const SizedBox(height: 12),

            // Verdict Box
            GlassCard(
              padding: const EdgeInsets.all(14),
              backgroundColor: _getStatusColor(_info!.status).withOpacity(0.07),
              borderColor: _getStatusColor(_info!.status).withOpacity(0.30),
              child: Row(
                children: [
                  Icon(
                    _info!.status == 'genuine'
                        ? Icons.verified_rounded
                        : _info!.status == 'suspicious'
                            ? Icons.warning_amber_rounded
                            : Icons.cancel_rounded,
                    color: _getStatusColor(_info!.status),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDIT VERDICT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _getStatusColor(_info!.status),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _info!.verdict,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Track & Metadata Info
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Album Cover or Music Icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _info!.coverBytes != null
                            ? Image.memory(
                                _info!.coverBytes!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: Colors.white.withOpacity(0.08),
                                child: const Icon(Icons.album_rounded, color: Colors.white54, size: 32),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _info!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _info!.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _info!.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white10, height: 24),

                  // Technical Specs Grid
                  _buildSpecRow(Icons.speed_rounded, 'Format & Bitrate', '${_info!.bitrateKbps} kbps FLAC'),
                  _buildSpecRow(Icons.tune_rounded, 'Bit Depth & Sample Rate', '${_info!.bitDepth}-bit / ${_info!.sampleRate} Hz'),
                  _buildSpecRow(Icons.schedule_rounded, 'Duration & Channels', '${_info!.durationStr} (${_info!.channels == 2 ? "Stereo" : "${_info!.channels}ch"})'),
                  _buildSpecRow(Icons.storage_rounded, 'File Size', '${_info!.fileSizeMb} MB'),
                ],
              ),
            ),
          ] else ...[
            // Empty State
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 56, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(height: 14),
                    Text(
                      'Ready to inspect audio purity',
                      style: TextStyle(fontSize: 14.5, color: Colors.white.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick any .flac track to view spectrum cutoff & purity',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // CRITICAL: 120px Bottom buffer so floating nav bar never overlaps!
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
