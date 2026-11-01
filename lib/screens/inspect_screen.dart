import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/audio_spectrum_stage.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';
import '../widgets/lyrics_viewer_sheet.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Studio-Grade Audio Inspector Architecture
///
/// Features:
/// - Apple WWDC25 Frosted Glass Substrate with delicate 0.5dp specular light rim.
/// - Embedded album cover artwork (72dp continuous squircle).
/// - Studio Spectral Nyquist Analyzer Stage (32-band real-time audio frequency visualizer).
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - Concise studio-grade badges that never truncate.
/// - Calibrated 96dp bottom padding (content glides behind the liquid glass dock).
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
    if (_info == null && appState.recentFilePaths.isNotEmpty) {
      _loadLastRecentTrack();
    }
  }

  Future<void> _loadLastRecentTrack() async {
    final recent = appState.recentFilePaths;
    for (final path in recent) {
      if (File(path).existsSync()) {
        final analyzed = await FlacParser.analyzeFile(path);
        if (mounted && analyzed.error == null) {
          setState(() => _info = analyzed);
        }
        break;
      }
    }
  }

  Future<void> _loadFileFromPath(String path) async {
    setState(() => _isLoading = true);
    try {
      final analyzed = await FlacParser.analyzeFile(path);
      if (analyzed.error == null) {
        appState.addRecentFilePath(path);
      }
      if (mounted) {
        setState(() {
          _info = analyzed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing file: $e'),
            backgroundColor: AppColors.fakeCoral,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSelectTrackTapped() {
    if (appState.recentFilePaths.isEmpty && appState.sharedLibrary.isEmpty) {
      _pickAndAnalyzeFile();
    } else {
      _showTrackSelectionSheet();
    }
  }

  void _showTrackSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);
        final activeAccent = appState.getAccentColor(context);
        final recent = appState.recentFilePaths;
        final library = appState.sharedLibrary;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: GlassSurface(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            style: GlassStyle.frosted,
            borderless: false,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SafeArea(
              top: false,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x40FFFFFF) : const Color(0x35000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose FLAC Track',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    LuminousFeedback(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndAnalyzeFile();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: GlassSurface(
                        borderRadius: BorderRadius.circular(12),
                        style: GlassStyle.clear,
                        borderless: false,
                        tintColor: activeAccent.withOpacity(isDark ? 0.22 : 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 14, color: activeAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Browse Files',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: activeAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (recent.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
                          child: Text(
                            'RECENT TRACKS',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        ...recent.take(5).map((path) {
                          final name = path.split('/').last;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: LuminousFeedback(
                              onTap: () {
                                Navigator.pop(ctx);
                                _loadFileFromPath(path);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: GlassSurface(
                                borderRadius: BorderRadius.circular(14),
                                style: GlassStyle.clear,
                                borderless: false,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.history_rounded, size: 20, color: activeAccent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            path,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 10.5,
                                              color: subTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.chevron_right_rounded, size: 16, color: subTextColor),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      if (library.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            'FROM AUDITED LIBRARY (${library.length})',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: subTextColor,
                            ),
                          ),
                        ),
                        ...library.take(30).map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: LuminousFeedback(
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _info = t);
                                appState.addRecentFilePath(t.filePath);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: GlassSurface(
                                borderRadius: BorderRadius.circular(14),
                                style: GlassStyle.clear,
                                borderless: false,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: t.hasCover && t.coverBytes != null
                                          ? Image.memory(t.coverBytes!, fit: BoxFit.cover)
                                          : Icon(Icons.album_rounded, size: 18, color: _getStatusColor(t.status)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.title.isNotEmpty ? t.title : t.fileName,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            t.artist.isNotEmpty ? t.artist : '${t.bitDepth}-bit • ${(t.sampleRate / 1000).toStringAsFixed(1)}k',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: subTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${t.score}%',
                                      style: TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _getStatusColor(t.status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
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
        if (analyzed.error == null) {
          appState.addRecentFilePath(path);
        }
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
            backgroundColor: AppColors.fakeCoral,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'genuine':
        return AppColors.genuineEmerald;
      case 'suspicious':
        return AppColors.suspiciousAmber;
      default:
        return AppColors.fakeCoral;
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              // 96dp bottom padding: content glides behind the liquid glass dock!
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Title
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
                    child: Text(
                      'Inspect',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: textColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 1. Studio Audio Hero Stage (WWDC25 Frosted Glass Substrate)
                  _buildStudioHeroStage(isDark, textColor, subTextColor),

                  const SizedBox(height: 18),

                  // 2. Technical Stream Specifications (Connected Group)
                  if (_info != null) ...[
                    buildSectionHeader('Stream Telemetry & Integrity', subTextColor),
                    _buildStreamTelemetryGroup(isDark, textColor, subTextColor),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudioHeroStage(bool isDark, Color textColor, Color subTextColor) {
    final activeAccent = appState.getAccentColor(context);
    final statusColor = _info != null ? _getStatusColor(_info!.status) : activeAccent;

    return LuminousFeedback(
      onTap: _isLoading ? null : _onSelectTrackTapped,
      variant: _info?.status == 'genuine' ? LuminousVariant.emerald : LuminousVariant.cyan,
      borderRadius: BorderRadius.circular(28),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        style: GlassStyle.frosted,
        borderless: false, // Refined WWDC25 specular light rim active
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Action Row (Embedded Artwork + File Title & Action)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 72dp Continuous Squircle Album Cover Artwork
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isDark
                        ? AppColors.softElevation(elevation: 3.0)
                        : AppColors.lightSoftElevation(elevation: 3.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: activeAccent,
                            ),
                          ),
                        )
                      : (_info != null && _info!.hasCover && _info!.coverBytes != null
                          ? Image.memory(
                              _info!.coverBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallbackArtwork(statusColor),
                            )
                          : _fallbackArtwork(statusColor)),
                ),
                const SizedBox(width: 14),
                // Title & Subtitle with Clean 2-Line Soft Wrapping
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _info != null
                            ? (_info!.title.isNotEmpty ? _info!.title : _info!.fileName)
                            : 'Select FLAC Track',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _info != null
                            ? (_info!.artist.isNotEmpty
                                ? '${_info!.artist} • ${_info!.album}'
                                : _info!.filePath.split('/').last)
                            : 'Tap to inspect audio authenticity & spectral cutoff',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.35,
                          color: subTextColor,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                LuminousFeedback(
                  onTap: _isLoading ? null : _onSelectTrackTapped,
                  borderRadius: BorderRadius.circular(12),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(12),
                    style: GlassStyle.clear,
                    borderless: false,
                    tintColor: activeAccent.withOpacity(isDark ? 0.22 : 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      _info != null ? 'Change' : 'Browse',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: activeAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_info != null) ...[
              const SizedBox(height: 20),

              // 2. Hybrid Forensic Audio Engine (32-Bar Waveform + 2D STFT Spectrogram)
              AudioSpectrumStage(
                score: _info!.score,
                cutoffKhz: _info!.cutoffKhz,
                maxKhz: _info!.maxKhz,
                spectrumBands: _info!.spectrumBands,
                status: _info!.status,
                shortBadge: _info!.shortBadge,
                statusColor: statusColor,
                sampleRate: _info!.sampleRate,
                bitDepth: _info!.bitDepth,
                verdict: _info!.verdict,
                height: 136,
              ),

              // Detailed explanation text under spectrum
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  _info!.verdict,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    height: 1.3,
                    color: subTextColor,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 12),

              // 4. Clean High-Contrast Spec Pills in Clear Glass (FittedBox auto-scaling for mobile & tablet)
              Row(
                children: [
                  _buildSpecTile('${_info!.bitDepth}-bit', 'Depth', isDark),
                  const SizedBox(width: 6),
                  _buildSpecTile('${(_info!.sampleRate / 1000).toStringAsFixed(1)} kHz', 'Sampling', isDark),
                  const SizedBox(width: 6),
                  _buildSpecTile('${_info!.bitrateKbps} kbps', 'Bitrate', isDark),
                  const SizedBox(width: 6),
                  _buildSpecTile('${_info!.fileSizeMb.toStringAsFixed(1)} MB', 'Size', isDark),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallbackArtwork(Color statusColor) {
    return Center(
      child: Icon(
        Icons.album_rounded,
        size: 34,
        color: statusColor,
      ),
    );
  }

  Widget _buildSpecTile(String value, String label, bool isDark) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(14),
        style: GlassStyle.clear,
        borderless: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamTelemetryGroup(bool isDark, Color textColor, Color subTextColor) {
    if (_info == null) return const SizedBox.shrink();
    final activeAccent = appState.getAccentColor(context);

    final rows = [
      (
        icon: Icons.verified_user_rounded,
        iconColor: AppColors.genuineEmerald,
        iconBg: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
        title: 'Audio Integrity',
        subtitle: _info!.verdict,
        trailing: Text(
          _info!.status == 'genuine' ? 'Lossless' : 'Transcode',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _info!.status == 'genuine'
                ? AppColors.genuineEmerald
                : AppColors.fakeCoral,
          ),
        ),
        onTap: null,
      ),
      (
        icon: Icons.graphic_eq_rounded,
        iconColor: activeAccent,
        iconBg: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
        title: 'Audio Channels',
        subtitle: '${_info!.channels == 2 ? 'Stereo (2.0)' : 'Mono'} • FLAC Stream',
        trailing: Text(
          '${_info!.channels} ch',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: subTextColor,
          ),
        ),
        onTap: null,
      ),
      (
        icon: Icons.timer_outlined,
        iconColor: const Color(0xFFA78BFA),
        iconBg: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
        title: 'Duration & Bitrate',
        subtitle: '${_info!.bitrateKbps} kbps average',
        trailing: Text(
          _info!.durationStr,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        onTap: null,
      ),
      (
        icon: Icons.lyrics_rounded,
        iconColor: const Color(0xFF38BDF8),
        iconBg: isDark ? const Color(0x3038BDF8) : const Color(0xFFE0F2FE),
        title: 'Integrated Lyrics',
        subtitle: _info!.hasLyrics
            ? 'Vorbis Lyrics embedded in FLAC • Tap to view'
            : 'No lyrics metadata detected in file',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _info!.hasLyrics ? 'View' : 'None',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _info!.hasLyrics ? AppColors.genuineEmerald : subTextColor,
              ),
            ),
            if (_info!.hasLyrics) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16, color: activeAccent),
            ],
          ],
        ),
        onTap: _info!.hasLyrics ? () => showLyricsViewerSheet(context, _info!) : null,
      ),
      (
        icon: Icons.folder_open_rounded,
        iconColor: AppColors.suspiciousAmber,
        iconBg: isDark ? const Color(0x30FFB300) : const Color(0xFFFEF3C7),
        title: 'File Location',
        subtitle: _info!.filePath,
        trailing: null,
        onTap: null,
      ),
    ];

    return ExpressiveGroup(
      rowCount: rows.length,
      itemBuilder: (context, index, position) {
        final r = rows[index];
        return ExpressiveGroupRow(
          icon: r.icon,
          iconColor: r.iconColor,
          iconBgColor: r.iconBg,
          title: r.title,
          subtitle: r.subtitle,
          position: position,
          trailing: r.trailing,
          onTap: r.onTap,
        );
      },
    );
  }
}
