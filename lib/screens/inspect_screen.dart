import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
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
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Select File Action Card
              GlassCard(
                borderRadius: 20,
                borderColor: const Color(0xFF00D2FF).withOpacity(0.25),
                backgroundColor: const Color(0xFF00D2FF).withOpacity(0.06),
                onTap: _isLoading ? null : _pickAndAnalyzeFile,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2FF).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.audio_file_rounded, color: Color(0xFF00D2FF), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _info == null ? 'Select FLAC File' : 'Change Audio File',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _info == null ? 'Tap to browse and inspect purity' : _info!.fileName,
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
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF00D2FF)),
                      )
                    else
                      Icon(Icons.folder_open_rounded, color: subTextColor, size: 22),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_info != null) ...[
                // Score Arc Meter & Cutoff Indicator
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  borderColor: _getStatusColor(_info!.status).withOpacity(0.25),
                  child: ScoreGauge(
                    score: _info!.score,
                    status: _info!.status,
                    cutoffKhz: _info!.cutoffKhz,
                    maxKhz: _info!.maxFrequencyKhz,
                  ),
                ),

                const SizedBox(height: 10),

                // Spectral Explanation Card
                GlassCard(
                  borderRadius: 20,
                  backgroundColor: _getStatusColor(_info!.status).withOpacity(0.07),
                  borderColor: _getStatusColor(_info!.status).withOpacity(0.30),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(_info!.status).withOpacity(0.18),
                        ),
                        child: Icon(
                          _info!.status == 'genuine'
                              ? Icons.verified_rounded
                              : (_info!.status == 'suspicious' ? Icons.warning_rounded : Icons.dangerous_rounded),
                          color: _getStatusColor(_info!.status),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _info!.status == 'genuine'
                                  ? 'Authentic Lossless Spectrum'
                                  : (_info!.status == 'suspicious' ? 'Suspicious Lossy Transcode' : 'Confirmed MP3 Upscale'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(_info!.status),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _info!.explanation,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: subTextColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Track & Metadata Info
                GlassCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _info!.coverBytes != null
                                ? Image.memory(
                                    _info!.coverBytes!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 52,
                                    height: 52,
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                                    child: Icon(Icons.album_rounded, color: subTextColor, size: 30),
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
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _info!.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: subTextColor,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _info!.album,
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

                      // Technical Specs Grid
                      _buildSpecRow(Icons.speed_rounded, 'Format & Bitrate', '${_info!.bitrateKbps} kbps FLAC', textColor, subTextColor),
                      _buildSpecRow(Icons.tune_rounded, 'Bit Depth & Sample Rate', '${_info!.bitDepth}-bit / ${_info!.sampleRate} Hz', textColor, subTextColor),
                      _buildSpecRow(Icons.schedule_rounded, 'Duration & Channels', '${_info!.durationStr} (${_info!.channels == 2 ? "Stereo" : "${_info!.channels}ch"})', textColor, subTextColor),
                      _buildSpecRow(Icons.storage_rounded, 'File Size', '${_info!.fileSizeMb} MB', textColor, subTextColor),
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
                        Icon(Icons.graphic_eq_rounded, size: 52, color: subTextColor.withOpacity(0.2)),
                        const SizedBox(height: 14),
                        Text(
                          'Ready to inspect audio purity',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick any .flac track to view spectrum cutoff & purity',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: subTextColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // CRITICAL: 140px Bottom buffer so floating nav bar never collides
              const SizedBox(height: 140),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
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
