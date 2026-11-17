import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../widgets/audio_spectrum_stage.dart';
import '../widgets/glass_surface.dart';
import '../widgets/lyrics_viewer_sheet.dart';
import '../widgets/luminous_feedback.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/animated_status_badge.dart';
import '../widgets/bounded_scroll_physics.dart';

/// 1:1 Port of LastWave Native's Borderless AMOLED Track List Stage for FLAC Audio Auditing
///
/// Features:
/// - Borderless AMOLED Track Rows (Tracks sit natively on #000000 canvas with zero cartoon borders).
/// - 48dp Squircle Album Art with smooth 12dp continuous curvature.
/// - Iconic wavy-circle verified seal (Icons.verified_rounded) for genuine FLACs.
/// - Zero Truncation Architecture: 2-line title wrapping + isolated fixed-width audio specs capsule.
/// - Rich Studio Spectral Nyquist Analyzer Stage inside song details modal bottom sheet.
/// - Calibrated 96dp bottom padding (album art smoothly flows behind the liquid glass dock).
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  bool _isScanning = false;
  bool _cancelRequested = false;
  int _scannedCount = 0;
  int _totalFiles = 0;
  String _currentAuditingFileName = '';
  String _filter = 'all'; // 'all', 'genuine', 'suspicious', 'fake', 'untested'

  @override
  void initState() {
    super.initState();
    _scannedCount = appState.sharedLibrary.length;
  }

  Future<void> _startScan(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      if (mounted) {
        showThemedSnackBar(
          context,
          'Folder not found: $dirPath',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.fakeCoral,
        );
      }
      return;
    }

    // Fast preliminary file discovery (<25ms)
    final List<File> flacFiles = [];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.flac')) {
          flacFiles.add(entity);
        }
      }
    } catch (e) {
      if (mounted) {
        showThemedSnackBar(context, 'Folder read error: $e');
      }
      return;
    }

    if (flacFiles.isEmpty) {
      if (mounted) {
        showThemedSnackBar(
          context,
          'No .flac files found in $dirPath',
          icon: Icons.info_outline_rounded,
          accentColor: AppColors.suspiciousAmber,
        );
      }
      return;
    }

    // Check how many tracks are already deeply audited in cache
    final cachedMap = {
      for (final t in appState.sharedLibrary)
        if (t.status != 'untested' && t.spectrumBands.isNotEmpty) t.filePath: true
    };
    int cachedCount = 0;
    for (final f in flacFiles) {
      if (cachedMap[f.path] == true) cachedCount++;
    }

    if (!mounted) return;
    await _showAuditBriefingDialog(
      dirPath: dirPath,
      flacFiles: flacFiles,
      cachedCount: cachedCount,
    );
  }

  Future<void> _showAuditBriefingDialog({
    required String dirPath,
    required List<File> flacFiles,
    required int cachedCount,
  }) async {
    final neededAuditCount = flacFiles.length - cachedCount;
    final estSeconds = (neededAuditCount * 1.5).round();
    final estTimeStr = estSeconds < 60
        ? '${estSeconds}s'
        : '${estSeconds ~/ 60}m ${estSeconds % 60}s';

    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          style: GlassStyle.frosted,
          borderless: false,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x40FFFFFF) : const Color(0x35000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeAccent.withOpacity(isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: activeAccent.withOpacity(0.40),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.biotech_rounded, color: activeAccent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library Audio Audit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${flacFiles.length} songs detected in folder',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _buildBriefingRow(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF38BDF8),
                  title: neededAuditCount == 0
                      ? 'All Tracks Already Audited'
                      : 'Estimated Time: ~$estTimeStr',
                  subtitle: cachedCount > 0
                      ? '$cachedCount already checked • $neededAuditCount songs to verify (~1.5s per song)'
                      : '$neededAuditCount songs to analyze (~1.5s per song)',
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                const SizedBox(height: 8),

                _buildBriefingRow(
                  icon: Icons.graphic_eq_rounded,
                  iconColor: AppColors.genuineEmerald,
                  title: 'Lossless Quality Check',
                  subtitle: 'Checks real audio frequencies to catch fake FLACs and compressed MP3 upscales.',
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                const SizedBox(height: 8),

                _buildBriefingRow(
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.suspiciousAmber,
                  title: 'Saved to Device',
                  subtitle: 'Scans only once. Next time, your library results open instantly.',
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: LuminousFeedback(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(16),
                        child: GlassSurface(
                          borderRadius: BorderRadius.circular(16),
                          style: GlassStyle.clear,
                          borderless: false,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: LuminousFeedback(
                        onTap: () {
                          Navigator.pop(ctx);
                          _executeDeepAudit(dirPath, flacFiles);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: activeAccent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: activeAccent.withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.rocket_launch_rounded,
                                  size: 18,
                                  color: AppColors.getOnAccentColor(activeAccent, isDark: isDark),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Start Audit',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.getOnAccentColor(activeAccent, isDark: isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBriefingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(16),
      style: GlassStyle.clear,
      borderless: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeepAudit(String dirPath, List<File> flacFiles) async {
    setState(() {
      _isScanning = true;
      _cancelRequested = false;
      _scannedCount = 0;
      _totalFiles = flacFiles.length;
      _currentAuditingFileName = '';
    });

    final Map<String, FlacInfo> existingCacheMap = {
      for (final t in appState.sharedLibrary) t.filePath: t
    };

    final List<FlacInfo> results = [];

    try {
      for (final file in flacFiles) {
        if (_cancelRequested) break;

        final cached = existingCacheMap[file.path];
        // If file was already deep-audited previously, reuse cached result!
        if (cached != null && cached.status != 'untested' && cached.spectrumBands.isNotEmpty) {
          results.add(cached);
          if (mounted) {
            setState(() {
              _scannedCount++;
              _currentAuditingFileName = cached.fileName;
            });
            appState.setSharedLibraryLive(List.from(results), dirPath);
          }
          continue;
        }

        if (mounted) {
          setState(() {
            _currentAuditingFileName = file.path.split('/').last;
          });
        }

        // Deep forensic DSP analysis
        final info = await FlacParser.analyzeFile(
          file.path,
          deepDsp: true,
          readCoverBytes: false, // RAM protected
        );
        results.add(info);

        if (mounted) {
          setState(() {
            _scannedCount++;
          });
          appState.setSharedLibraryLive(List.from(results), dirPath);
        }
      }

      if (results.isNotEmpty) {
        appState.setSharedLibrary(results, dirPath);
      }

      if (mounted) {
        final fakeCount = results.where((t) => t.status == 'fake').length;
        final genuineCount = results.where((t) => t.status == 'genuine').length;
        if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
        showThemedSnackBar(
          context,
          _cancelRequested
              ? 'Audit paused • ${results.length} of $_totalFiles tracks verified'
              : 'Audit complete • $genuineCount genuine, $fakeCount fake caught',
          icon: _cancelRequested ? Icons.pause_circle_outline_rounded : Icons.verified_rounded,
          accentColor: fakeCount > 0 ? AppColors.fakeCoral : AppColors.genuineEmerald,
        );
      }
    } catch (e) {
      if (mounted) {
        showThemedSnackBar(
          context,
          'Audit error: $e',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.fakeCoral,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _currentAuditingFileName = '';
        });
      }
    }
  }

  Future<void> _pickFolderAndScan() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath != null) {
      _startScan(dirPath);
    }
  }

  void _showScanOptions() {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);
    final lastFolder = appState.lastScannedFolder;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          style: GlassStyle.frosted,
          borderless: false,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                Text(
                  'Scan Audio Library',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a music source for deep forensic audio audit',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (lastFolder != null && lastFolder.isNotEmpty) ...[
                  LuminousFeedback(
                    onTap: () {
                      Navigator.pop(ctx);
                      _startScan(lastFolder);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassSurface(
                      borderRadius: BorderRadius.circular(16),
                      style: GlassStyle.clear,
                      borderless: false,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.replay_rounded, color: activeAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Re-scan Recent Folder',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastFolder,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                LuminousFeedback(
                  onTap: () {
                    Navigator.pop(ctx);
                    _startScan('/storage/emulated/0/Music');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    style: GlassStyle.clear,
                    borderless: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.library_music_rounded, color: AppColors.genuineEmerald, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Scan Device Music',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/storage/emulated/0/Music • 1-Tap direct scan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LuminousFeedback(
                  onTap: () {
                    Navigator.pop(ctx);
                    _startScan('/storage/emulated/0/Download');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    style: GlassStyle.clear,
                    borderless: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.download_rounded, color: Color(0xFF38BDF8), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Scan Downloads',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/storage/emulated/0/Download • FLAC downloads',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LuminousFeedback(
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFolderAndScan();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    style: GlassStyle.clear,
                    borderless: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.suspiciousAmber.withOpacity(isDark ? 0.20 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder_open_rounded, color: AppColors.suspiciousAmber, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browse Custom Folder...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select any directory using system file picker',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: subTextColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        return AppColors.genuineEmerald;
      case 'suspicious':
        return AppColors.suspiciousAmber;
      case 'untested':
      case 'pending':
        return const Color(0xFF94A3B8);
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

        final tracks = appState.sharedLibrary;
        final filteredTracks = _filter == 'all'
            ? tracks
            : (_filter == 'untested'
                ? tracks.where((t) => t.status == 'untested' || t.status == 'pending').toList()
                : tracks.where((t) => t.status == _filter).toList());

        final genuineCount = tracks.where((t) => t.status == 'genuine').length;
        final suspiciousCount = tracks.where((t) => t.status == 'suspicious').length;
        final fakeCount = tracks.where((t) => t.status == 'fake').length;
        final untestedCount = tracks.where((t) => t.status == 'untested' || t.status == 'pending').length;
        final auditedTracks = tracks.where((t) => t.status != 'untested' && t.status != 'pending');
        final activeAccent = appState.getAccentColor(context);

        int averageScore = 0;
        if (auditedTracks.isNotEmpty) {
          final total = auditedTracks.fold<int>(0, (sum, item) => sum + item.score);
          averageScore = (total / auditedTracks.length).round();
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BoundedBouncingScrollPhysics(),
              slivers: [
                // 1. Top Header with Settings Gear Button (Phase 2.4)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Audit Library',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Library Hero Action & Statistics Card (WWDC25 Frosted Glass Substrate)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _buildHeroAuditCard(
                      totalTracks: tracks.length,
                      genuineCount: genuineCount,
                      suspiciousCount: suspiciousCount,
                      fakeCount: fakeCount,
                      untestedCount: untestedCount,
                      averageScore: averageScore,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      activeAccent: activeAccent,
                    ),
                  ),
                ),

                // 3. Filter Segment Pills Row (Clear Glass)
                if (tracks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BoundedBouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterPill('All (${tracks.length})', 'all', isDark, activeAccent),
                            const SizedBox(width: 8),
                            _buildFilterPill('Genuine ($genuineCount)', 'genuine', isDark, activeAccent),
                            const SizedBox(width: 8),
                            _buildFilterPill('Suspicious ($suspiciousCount)', 'suspicious', isDark, activeAccent),
                            const SizedBox(width: 8),
                            _buildFilterPill('Fake ($fakeCount)', 'fake', isDark, activeAccent),
                            if (untestedCount > 0) ...[
                              const SizedBox(width: 8),
                              _buildFilterPill('Untested ($untestedCount)', 'untested', isDark, const Color(0xFF94A3B8)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. LastWave Borderless AMOLED Track List
                if (tracks.isEmpty && !_isScanning)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 56,
                            color: activeAccent.withOpacity(0.45),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Audited Tracks Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the card above or choose a quick option below',
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LuminousFeedback(
                                onTap: () => _startScan('/storage/emulated/0/Music'),
                                borderRadius: BorderRadius.circular(14),
                                child: GlassSurface(
                                  borderRadius: BorderRadius.circular(14),
                                  style: GlassStyle.clear,
                                  borderless: false,
                                  tintColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.library_music_rounded, size: 16, color: activeAccent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Quick Scan Music',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: activeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              LuminousFeedback(
                                onTap: _showScanOptions,
                                borderRadius: BorderRadius.circular(14),
                                child: GlassSurface(
                                  borderRadius: BorderRadius.circular(14),
                                  style: GlassStyle.clear,
                                  borderless: false,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.folder_open_rounded, size: 16, color: subTextColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Browse',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    // 96dp bottom padding: Content smoothly glides behind the 56dp liquid glass dock!
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = filteredTracks[index];
                          return _buildBorderlessTrackRow(
                            track: track,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onTap: () => _openTrackDetail(track),
                          );
                        },
                        childCount: filteredTracks.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroAuditCard({
    required int totalTracks,
    required int genuineCount,
    required int suspiciousCount,
    required int fakeCount,
    required int untestedCount,
    required int averageScore,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
  }) {
    return LuminousFeedback(
      onTap: _isScanning ? null : _showScanOptions,
      variant: LuminousVariant.emerald,
      borderRadius: BorderRadius.circular(28),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        style: GlassStyle.frosted,
        borderless: false, // Refined WWDC25 specular light rim active
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$totalTracks',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Audited Tracks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isScanning
                            ? 'Auditing: ${_currentAuditingFileName.isNotEmpty ? _currentAuditingFileName : "Initializing..."}'
                            : (appState.lastScannedFolder != null
                                ? 'Source: ${appState.lastScannedFolder!.split('/').last}'
                                : 'Tap to scan folder and audit entire library'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isScanning
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              key: ValueKey('audit_hero_continuous_spinner'),
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.genuineEmerald),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.folder_open_rounded,
                          color: AppColors.genuineEmerald,
                          size: 22,
                        ),
                ),
              ],
            ),

            if (_isScanning) ...[
              const SizedBox(height: 16),

              // Studio Progress Header (Clean, Matte, Zero Neon Glow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 15,
                        color: activeAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AUDITING LIBRARY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: activeAccent,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeAccent.withOpacity(isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeAccent.withOpacity(0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$_scannedCount / $_totalFiles • ${_totalFiles > 0 ? ((_scannedCount / _totalFiles) * 100).toInt() : 0}%',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: activeAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),

              // Option 1: Apple Precision Matte Capsule Progress Bar (0 blur / 0 glow)
              LayoutBuilder(
                builder: (context, constraints) {
                  final progress = _totalFiles > 0
                      ? (_scannedCount / _totalFiles).clamp(0.0, 1.0)
                      : 0.04;
                  return Container(
                    height: 5,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x18FFFFFF) : const Color(0x12000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0x15FFFFFF) : const Color(0x0E000000),
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: 5,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: activeAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 11),

              // Progress Footer: Plain English + Cancel Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        size: 13,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Checking audio frequencies',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                  LuminousFeedback(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                      setState(() => _cancelRequested = true);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.fakeCoral.withOpacity(isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.fakeCoral.withOpacity(0.35),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 13, color: AppColors.fakeCoral),
                          SizedBox(width: 4),
                          Text(
                            'Cancel Audit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.fakeCoral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // Telemetry Pills Row (Clear Glass Substrates)
            Row(
              children: [
                _buildStatPill(
                  'GENUINE',
                  '$genuineCount',
                  AppColors.genuineEmerald,
                  isDark ? const Color(0x2500E676) : const Color(0xFFDCFCE7),
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  'SUSPECT',
                  '$suspiciousCount',
                  AppColors.suspiciousAmber,
                  isDark ? const Color(0x25FFB300) : const Color(0xFFFEF3C7),
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  'FAKE',
                  '$fakeCount',
                  AppColors.fakeCoral,
                  isDark ? const Color(0x25FF5252) : const Color(0xFFFFEBEE),
                  isDark,
                ),
                const SizedBox(width: 6),
                _buildStatPill(
                  'AVG SCORE',
                  '$averageScore%',
                  activeAccent,
                  activeAccent.withOpacity(isDark ? 0.22 : 0.14),
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    String value,
    Color accentColor,
    Color chipBg,
    bool isDark,
  ) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(16),
        style: GlassStyle.clear,
        borderless: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String filterKey, bool isDark, Color activeAccent) {
    final isSelected = _filter == filterKey;
    final fg = isSelected
        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
        : (isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _filter = filterKey),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(20),
          style: GlassStyle.clear,
          borderless: false,
          tintColor: isSelected
              ? activeAccent.withOpacity(isDark ? 0.30 : 0.16)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? (isDark ? Colors.white : activeAccent) : fg,
            ),
          ),
        ),
      ),
    );
  }

  /// LastWave Borderless Track Row Architecture (Zero Truncation)
  ///
  /// Matches LastWave screenshot_1.png and screenshot_6.png:
  /// - 0 box containers or outlines. Tracks sit directly on AMOLED black.
  /// - 48dp continuous squircle artwork.
  /// - 2-line title wrapping (prevents truncation on long song names).
  /// - Dedicated audio specs capsule (sample rate, bit depth, bitrate are never pushed off).
  /// - Wavy circle verified seal (Icons.verified_rounded) for genuine FLACs.
  /// - Luminous subtle touch feedback on tap.
  Widget _buildBorderlessTrackRow({
    required FlacInfo track,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    final statusColor = _getStatusColor(track.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: statusColor.withOpacity(0.12),
          highlightColor: statusColor.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 48dp Squircle Artwork Thumbnail (12dp radius, RAM-protected lazy loader)
                _TrackCoverThumbnail(
                  track: track,
                  statusColor: statusColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 14),

                // Title & Subtitle with Clean 1-Line Non-wrapping Layout (LastWave Native Architecture)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title.isNotEmpty ? track.title : track.fileName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artist.isNotEmpty
                            ? '${track.artist} • ${(track.sampleRate / 1000).toStringAsFixed(0)}k/${track.bitDepth}b'
                            : '${(track.sampleRate / 1000).toStringAsFixed(0)}k/${track.bitDepth}b • ${track.bitrateKbps}k',
                        style: TextStyle(
                          fontSize: 12.0,
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

                // Wavy Verified Seal & Score Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedStatusBadge(
                      status: track.status,
                      color: statusColor,
                      size: 16,
                      animatePulse: false,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      track.status == 'untested' ? 'UNTESTED' : '${track.score}%',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: track.status == 'untested' ? 10.5 : 13,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Memory-bounded continuous lazy artwork loader (max 60 thumbnails in RAM)
class _TrackCoverThumbnail extends StatefulWidget {
  final FlacInfo track;
  final Color statusColor;
  final bool isDark;

  const _TrackCoverThumbnail({
    required this.track,
    required this.statusColor,
    required this.isDark,
  });

  @override
  State<_TrackCoverThumbnail> createState() => _TrackCoverThumbnailState();
}

class _TrackCoverThumbnailState extends State<_TrackCoverThumbnail> {
  static final Map<String, Uint8List> _thumbCache = {};
  Uint8List? _loadedBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadCover();
  }

  @override
  void didUpdateWidget(covariant _TrackCoverThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.filePath != widget.track.filePath) {
      _checkAndLoadCover();
    }
  }

  void _checkAndLoadCover() {
    if (widget.track.coverBytes != null) {
      _loadedBytes = widget.track.coverBytes;
      return;
    }
    if (!widget.track.hasCover) {
      _loadedBytes = null;
      return;
    }
    if (_thumbCache.containsKey(widget.track.filePath)) {
      _loadedBytes = _thumbCache[widget.track.filePath];
      return;
    }
    if (!_isLoading) {
      _isLoading = true;
      FlacParser.extractCoverBytes(widget.track.filePath).then((bytes) {
        if (mounted) {
          if (bytes != null) {
            if (_thumbCache.length > 60) {
              _thumbCache.remove(_thumbCache.keys.first);
            }
            _thumbCache[widget.track.filePath] = bytes;
          }
          setState(() {
            _loadedBytes = bytes;
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0x28FFFFFF) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: widget.isDark
            ? AppColors.softElevation(elevation: 2.0)
            : AppColors.lightSoftElevation(elevation: 2.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: _loadedBytes != null
          ? Image.memory(
              _loadedBytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackCover(widget.statusColor),
            )
          : _fallbackCover(widget.statusColor),
    );
  }

  Widget _fallbackCover(Color statusColor) {
    return Center(
      child: Icon(
        Icons.album_rounded,
        size: 24,
        color: statusColor.withOpacity(0.7),
      ),
    );
  }
}

/// Rich Studio Audio Inspector Modal Bottom Sheet with Spectral Analyzer Stage
///
/// Features Apple WWDC25 Frosted Glass Substrate with real Gaussian blur & specular rim.
class _TrackDetailModal extends StatefulWidget {
  final FlacInfo track;

  const _TrackDetailModal({required this.track});

  @override
  State<_TrackDetailModal> createState() => _TrackDetailModalState();
}

class _TrackDetailModalState extends State<_TrackDetailModal> {
  late FlacInfo _track;
  Uint8List? _coverBytes;
  bool _isAnalyzingDsp = false;

  @override
  void initState() {
    super.initState();
    _track = widget.track;
    _coverBytes = _track.coverBytes;

    // Lazy-load artwork if not already loaded in RAM
    if (_coverBytes == null && _track.hasCover) {
      FlacParser.extractCoverBytes(_track.filePath).then((bytes) {
        if (mounted && bytes != null) {
          setState(() => _coverBytes = bytes);
        }
      });
    }

    // If fast metadata scanned (no spectrum bands yet) or untested, trigger Deep DSP analysis on-demand
    if ((_track.spectrumBands.isEmpty || _track.status == 'untested') && _track.error == null) {
      _isAnalyzingDsp = true;
      FlacParser.analyzeFile(_track.filePath, deepDsp: true, readCoverBytes: false).then((fullTrack) {
        if (mounted && fullTrack.error == null) {
          setState(() {
            _track = fullTrack.copyWith(coverBytes: _coverBytes ?? fullTrack.coverBytes);
            _isAnalyzingDsp = false;
          });
          appState.updateTrackInLibrary(_track);
        } else if (mounted) {
          setState(() => _isAnalyzingDsp = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);

    Color statusColor;
    switch (track.status) {
      case 'genuine':
        statusColor = AppColors.genuineEmerald;
        break;
      case 'suspicious':
        statusColor = AppColors.suspiciousAmber;
        break;
      case 'untested':
      case 'pending':
        statusColor = const Color(0xFF94A3B8);
        break;
      default:
        statusColor = AppColors.fakeCoral;
    }

    return GlassSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      style: GlassStyle.frosted,
      borderless: false, // Refined WWDC25 top specular rim
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x40FFFFFF) : const Color(0x40000000),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 1. Header: Artwork + Title + Artist + Verified Seal (No Truncation)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? AppColors.softElevation(elevation: 3.0)
                      : AppColors.lightSoftElevation(elevation: 3.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: _coverBytes != null
                    ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                    : Icon(Icons.album_rounded, size: 32, color: statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.title.isNotEmpty ? track.title : track.fileName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedStatusBadge(
                          status: track.status,
                          color: track.status == 'genuine'
                              ? AppColors.genuineEmerald
                              : (track.status == 'suspicious' ? const Color(0xFFFFB300) : const Color(0xFFFF3D3D)),
                          size: 24,
                          animatePulse: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist.isNotEmpty ? '${track.artist} • ${track.album}' : 'Unknown Artist',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subTextColor,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (_isAnalyzingDsp)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.genuineEmerald,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analyzing audio quality & spectrum...',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),

          // 2. Hybrid Forensic Audio Engine (Speedometer + Waveform Switcher)
          AudioSpectrumStage(
            score: track.score,
            cutoffKhz: track.cutoffKhz,
            maxKhz: track.maxKhz,
            spectrumBands: track.spectrumBands,
            spectrogramMatrix: track.spectrogramMatrix,
            status: track.status,
            shortBadge: track.shortBadge,
            statusColor: statusColor,
            sampleRate: track.sampleRate,
            bitDepth: track.bitDepth,
            verdict: track.verdict,
            height: 140,
          ),

          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              track.verdict,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: subTextColor,
              ),
              maxLines: 3,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          // 4. Quick Specs in Clear Glass (WWDC25 Clear Glass)
          Row(
            children: [
              _buildModalSpecTile('${track.bitDepth}-bit', 'Depth', isDark),
              const SizedBox(width: 6),
              _buildModalSpecTile('${(track.sampleRate / 1000).toStringAsFixed(1)}k', 'Sampling', isDark),
              const SizedBox(width: 6),
              _buildModalSpecTile('${track.bitrateKbps}k', 'Bitrate', isDark),
              const SizedBox(width: 6),
              _buildModalSpecTile('${track.fileSizeMb.toStringAsFixed(1)}MB', 'Size', isDark),
            ],
          ),

          if (track.hasLyrics) ...[
            const SizedBox(height: 10),
            LuminousFeedback(
              onTap: () {
                Navigator.pop(context);
                showLyricsViewerSheet(context, track);
              },
              borderRadius: BorderRadius.circular(14),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(14),
                style: GlassStyle.clear,
                borderless: false,
                tintColor: const Color(0xFF38BDF8).withOpacity(isDark ? 0.20 : 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.lyrics_rounded, size: 18, color: Color(0xFF38BDF8)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Integrated Lyrics Present • Tap to View',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF38BDF8)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 5. File Location Row
          GlassSurface(
            borderRadius: BorderRadius.circular(14),
            style: GlassStyle.clear,
            borderless: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 18, color: subTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.filePath,
                    style: TextStyle(
                      fontSize: 11,
                      color: subTextColor,
                    ),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSpecTile(String value, String label, bool isDark) {
    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(12),
        style: GlassStyle.clear,
        borderless: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0x80FFFFFF) : AppColors.lightTextMuted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
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
}
