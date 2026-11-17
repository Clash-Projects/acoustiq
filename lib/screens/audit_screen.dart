import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/audio_playback_service.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../widgets/audio_spectrum_stage.dart';
import '../widgets/glass_surface.dart';
import '../widgets/lyrics_viewer_sheet.dart';
import '../widgets/luminous_feedback.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_glass_dialog.dart';
import '../widgets/audio_preview_bar.dart';
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

    final qDir = Directory('/storage/emulated/0/Music/AcoustiQ_Quarantine');
    final qFiles = qDir.existsSync()
        ? qDir
            .listSync()
            .where((f) => f is File && f.path.toLowerCase().endsWith('.flac'))
            .cast<File>()
            .toList()
        : <File>[];

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
                if (qFiles.isNotEmpty) ...[
                  LuminousFeedback(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showQuarantineVaultSheet();
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
                            child: const Icon(Icons.shield_rounded, color: AppColors.suspiciousAmber, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'AcoustiQ Quarantine Vault',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.suspiciousAmber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${qFiles.length}',
                                        style: const TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.suspiciousAmber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Isolated fake FLACs • Tap to view or restore',
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
                ],
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
                                'Scan Music Folder',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/storage/emulated/0/Music • Standard music library',
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
                                'Scan Downloads Folder',
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

  void _showQuarantineVaultSheet() {
    final qDir = Directory('/storage/emulated/0/Music/AcoustiQ_Quarantine');
    if (!qDir.existsSync()) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = appState.isCurrentDark(context);
            final textColor = appState.getTextColor(context);
            final subTextColor = appState.getSubTextColor(context);
            final files = qDir
                .listSync()
                .where((f) => f is File && f.path.toLowerCase().endsWith('.flac'))
                .cast<File>()
                .toList();

            return GlassSurface(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              style: GlassStyle.frosted,
              borderless: false,
              padding: EdgeInsets.zero,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x40FFFFFF) : const Color(0x40000000),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.suspiciousAmber.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shield_rounded, color: AppColors.suspiciousAmber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quarantine Vault',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    '${files.length} isolated tracks hidden from music apps',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (files.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              'Quarantine vault is empty',
                              style: TextStyle(fontSize: 13, color: subTextColor),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BoundedBouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: files.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final f = files[i];
                              final name = p.basename(f.path);
                              final sizeMb = (f.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

                              return GlassSurface(
                                borderRadius: BorderRadius.circular(14),
                                style: GlassStyle.clear,
                                borderless: false,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.music_off_rounded, size: 20, color: AppColors.suspiciousAmber),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$sizeMb MB • Isolated (.nomedia)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: subTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Restore button
                                    LuminousFeedback(
                                      onTap: () async {
                                        await _restoreFromQuarantine(f);
                                        setModalState(() {});
                                        if (mounted) setState(() {});
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.restore_rounded, size: 14, color: AppColors.genuineEmerald),
                                            SizedBox(width: 4),
                                            Text(
                                              'Restore',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.genuineEmerald,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Delete button
                                    LuminousFeedback(
                                      onTap: () async {
                                        await _deleteQuarantinedFile(f);
                                        setModalState(() {});
                                        if (mounted) setState(() {});
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.fakeCoral.withOpacity(isDark ? 0.20 : 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.fakeCoral),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restoreFromQuarantine(File f) async {
    try {
      final musicDir = Directory('/storage/emulated/0/Music');
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }
      final targetPath = p.join(musicDir.path, p.basename(f.path));
      try {
        await f.rename(targetPath);
      } catch (_) {
        await f.copy(targetPath);
        await f.delete();
      }

      try {
        const channel = MethodChannel('flac_toolkit/audio_decoder');
        await channel.invokeMethod('rescanMediaFile', {'filePath': f.path});
        await channel.invokeMethod('rescanMediaFile', {'filePath': targetPath});
      } catch (_) {}

      try {
        final restoredTrack = await FlacParser.analyzeFile(targetPath);
        appState.addTrackToLibrary(restoredTrack);
      } catch (_) {}

      if (mounted) {
        showThemedSnackBar(
          context,
          'Restored "${p.basename(targetPath)}" to Music library',
          icon: Icons.restore_rounded,
          accentColor: AppColors.genuineEmerald,
        );
      }
    } catch (e) {
      if (mounted) {
        showThemedSnackBar(context, 'Restore failed: $e', icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _deleteQuarantinedFile(File f) async {
    showAppGlassDialog(
      context: context,
      title: 'Permanently Delete?',
      icon: Icons.delete_forever_rounded,
      iconColor: AppColors.fakeCoral,
      isDestructive: true,
      content: 'Permanently remove "${p.basename(f.path)}" from disk?\n\nThis action cannot be undone.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete Forever',
      onConfirm: () async {
        try {
          await f.delete();
          try {
            const channel = MethodChannel('flac_toolkit/audio_decoder');
            await channel.invokeMethod('rescanMediaFile', {'filePath': f.path});
          } catch (_) {}
          if (mounted) {
            showThemedSnackBar(
              context,
              'Permanently deleted "${p.basename(f.path)}"',
              icon: Icons.delete_outline_rounded,
              accentColor: AppColors.fakeCoral,
            );
          }
        } catch (e) {
          if (mounted) {
            showThemedSnackBar(context, 'Delete failed: $e', icon: Icons.error_outline_rounded);
          }
        }
      },
    );
  }

  void _showExportReportSheet(List<FlacInfo> tracks) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          style: GlassStyle.frosted,
          borderless: false,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.summarize_rounded, color: activeAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Audit Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tracks.length} tracks • Saved to Downloads folder',
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
              const SizedBox(height: 20),

              // Option 1: CSV Spreadsheet
              LuminousFeedback(
                onTap: () {
                  Navigator.pop(ctx);
                  _exportCsvReport(tracks);
                },
                borderRadius: BorderRadius.circular(16),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(16),
                  style: GlassStyle.clear,
                  borderless: false,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: AppColors.genuineEmerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spreadsheet Table (CSV)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Formatted table with cutoff kHz, purity score & audio MD5. Opens in Excel & Sheets.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subTextColor,
                                height: 1.3,
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

              const SizedBox(height: 10),

              // Option 2: Technical JSON Report
              LuminousFeedback(
                onTap: () {
                  Navigator.pop(ctx);
                  _exportJsonReport(tracks);
                },
                borderRadius: BorderRadius.circular(16),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(16),
                  style: GlassStyle.clear,
                  borderless: false,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.data_object_rounded, color: Color(0xFF38BDF8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Technical JSON Report',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Machine-readable JSON log with duration, sample rates, brickwall slope & verdicts.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subTextColor,
                                height: 1.3,
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
        );
      },
    );
  }

  Future<void> _exportCsvReport(List<FlacInfo> tracks) async {
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) downloadDir.createSync(recursive: true);

      final now = DateTime.now();
      final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'AcoustiQ_Audit_$ts.csv';
      final file = File(p.join(downloadDir.path, fileName));

      final buffer = StringBuffer();
      buffer.writeln('"Index","Title","Artist","Album","File Name","File Path","Size (MB)","Duration","Bit Depth","Sample Rate (Hz)","Bitrate (kbps)","Purity Score (%)","Status","Cutoff (kHz)","Brickwall Drop (dB)","Audio MD5","Verdict"');

      for (int i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        String sanitize(String s) => s.replaceAll('"', '""');
        buffer.writeln(
          '${i + 1},'
          '"${sanitize(t.title)}",'
          '"${sanitize(t.artist)}",'
          '"${sanitize(t.album)}",'
          '"${sanitize(t.fileName)}",'
          '"${sanitize(t.filePath)}",'
          '${t.fileSizeMb.toStringAsFixed(1)},'
          '"${t.durationStr}",'
          '${t.bitDepth},'
          '${t.sampleRate},'
          '${t.bitrateKbps},'
          '${t.score},'
          '"${t.status}",'
          '${t.cutoffKhz.toStringAsFixed(1)},'
          '${t.slopeDropDb.toStringAsFixed(1)},'
          '"${t.audioMd5 ?? "N/A"}",'
          '"${sanitize(t.verdict)}"',
        );
      }

      await file.writeAsString(buffer.toString(), flush: true);

      // Rescan with Android MediaStore
      try {
        const channel = MethodChannel('flac_toolkit/audio_decoder');
        await channel.invokeMethod('rescanMediaFile', {'filePath': file.path});
      } catch (_) {}

      if (mounted) {
        if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
        showThemedSnackBar(
          context,
          'Spreadsheet saved to Downloads: $fileName',
          icon: Icons.table_chart_rounded,
          accentColor: AppColors.genuineEmerald,
        );
      }
    } catch (e) {
      if (mounted) {
        showThemedSnackBar(context, 'Export failed: $e', icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _exportJsonReport(List<FlacInfo> tracks) async {
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) downloadDir.createSync(recursive: true);

      final now = DateTime.now();
      final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'AcoustiQ_Audit_$ts.json';
      final file = File(p.join(downloadDir.path, fileName));

      final genuineCount = tracks.where((t) => t.status == 'genuine').length;
      final suspiciousCount = tracks.where((t) => t.status == 'suspicious').length;
      final fakeCount = tracks.where((t) => t.status == 'fake').length;
      final avgScore = tracks.isNotEmpty
          ? (tracks.map((t) => t.score).reduce((a, b) => a + b) / tracks.length).round()
          : 0;

      final Map<String, dynamic> report = {
        'generator': 'AcoustiQ FLAC Audio Toolkit',
        'exportTimestamp': now.toIso8601String(),
        'totalTracks': tracks.length,
        'summary': {
          'genuine': genuineCount,
          'suspicious': suspiciousCount,
          'fake': fakeCount,
          'averageScore': avgScore,
        },
        'tracks': tracks.map((t) => {
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'fileName': t.fileName,
          'filePath': t.filePath,
          'fileSizeMb': t.fileSizeMb,
          'durationSec': t.durationSec,
          'durationFormatted': t.durationStr,
          'bitDepth': t.bitDepth,
          'sampleRate': t.sampleRate,
          'bitrateKbps': t.bitrateKbps,
          'score': t.score,
          'status': t.status,
          'cutoffKhz': t.cutoffKhz,
          'slopeDropDb': t.slopeDropDb,
          'audioMd5': t.audioMd5,
          'isFake24': t.isFake24,
          'verdict': t.verdict,
        }).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(report), flush: true);

      // Rescan with Android MediaStore
      try {
        const channel = MethodChannel('flac_toolkit/audio_decoder');
        await channel.invokeMethod('rescanMediaFile', {'filePath': file.path});
      } catch (_) {}

      if (mounted) {
        if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
        showThemedSnackBar(
          context,
          'JSON report saved to Downloads: $fileName',
          icon: Icons.data_object_rounded,
          accentColor: const Color(0xFF38BDF8),
        );
      }
    } catch (e) {
      if (mounted) {
        showThemedSnackBar(context, 'Export failed: $e', icon: Icons.error_outline_rounded);
      }
    }
  }

  void _openTrackDetail(FlacInfo track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TrackDetailModal(
        track: track,
        parentContext: context,
      ),
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

        final qDir = Directory('/storage/emulated/0/Music/AcoustiQ_Quarantine');
        final qCount = qDir.existsSync()
            ? qDir.listSync().where((f) => f is File && f.path.toLowerCase().endsWith('.flac')).length
            : 0;

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
                        if (tracks.isNotEmpty)
                          LuminousFeedback(
                            onTap: () => _showExportReportSheet(tracks),
                            borderRadius: BorderRadius.circular(12),
                            child: GlassSurface(
                              borderRadius: BorderRadius.circular(12),
                              style: GlassStyle.clear,
                              borderless: false,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.ios_share_rounded, size: 15, color: activeAccent),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Export',
                                    style: TextStyle(
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
                            if (qCount > 0) ...[
                              const SizedBox(width: 8),
                              LuminousFeedback(
                                onTap: _showQuarantineVaultSheet,
                                borderRadius: BorderRadius.circular(12),
                                child: GlassSurface(
                                  borderRadius: BorderRadius.circular(12),
                                  style: GlassStyle.clear,
                                  borderless: false,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 14, color: AppColors.suspiciousAmber),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Vault ($qCount)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.suspiciousAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                                        'Scan Music Library',
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
  final BuildContext? parentContext;

  const _TrackDetailModal({
    required this.track,
    this.parentContext,
  });

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
  void dispose() {
    if (AudioPlaybackService.instance.isPlaying) {
      AudioPlaybackService.instance.stop();
    }
    super.dispose();
  }

  Future<void> _quarantineTrack(BuildContext ctx, FlacInfo track) async {
    showAppGlassDialog(
      context: ctx,
      title: 'Move to Quarantine?',
      icon: Icons.shield_outlined,
      iconColor: AppColors.suspiciousAmber,
      confirmColor: AppColors.suspiciousAmber,
      content: 'This will move "${track.fileName}" to AcoustiQ_Quarantine with a .nomedia file.\n\nIt will be hidden from music players (Poweramp, Spotify, YouTube Music) without being permanently deleted.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Quarantine',
      onConfirm: () async {
        try {
          final oldFile = File(track.filePath);
          final quarantineDir = Directory('/storage/emulated/0/Music/AcoustiQ_Quarantine');
          if (!quarantineDir.existsSync()) {
            quarantineDir.createSync(recursive: true);
          }
          final nomedia = File(p.join(quarantineDir.path, '.nomedia'));
          if (!nomedia.existsSync()) {
            nomedia.createSync();
          }
          final targetPath = p.join(quarantineDir.path, p.basename(track.filePath));
          try {
            await oldFile.rename(targetPath);
          } catch (_) {
            await oldFile.copy(targetPath);
            await oldFile.delete();
          }

          // Rescan both old and new paths in Android MediaStore
          try {
            const channel = MethodChannel('flac_toolkit/audio_decoder');
            await channel.invokeMethod('rescanMediaFile', {'filePath': track.filePath});
            await channel.invokeMethod('rescanMediaFile', {'filePath': targetPath});
          } catch (_) {}

          appState.removeTrackFromLibrary(track.filePath);
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
          final targetContext = widget.parentContext ?? ctx;
          if (targetContext.mounted) {
            showThemedSnackBar(
              targetContext,
              'Track moved to Quarantine • Excluded from music players',
              icon: Icons.shield_rounded,
              accentColor: AppColors.suspiciousAmber,
            );
          }
        } catch (e) {
          if (ctx.mounted) {
            showThemedSnackBar(ctx, 'Quarantine failed: $e', icon: Icons.error_outline_rounded);
          }
        }
      },
    );
  }

  Future<void> _deleteTrack(BuildContext ctx, FlacInfo track) async {
    showAppGlassDialog(
      context: ctx,
      title: track.status == 'fake' ? 'Delete Fake FLAC?' : 'Delete Audio File?',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.fakeCoral,
      isDestructive: true,
      content: 'This will permanently delete:\n${track.fileName}\n(${track.fileSizeMb.toStringAsFixed(1)} MB)\n\nThis cannot be undone. Android MediaStore will be updated immediately.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      onConfirm: () async {
        try {
          try {
            const channel = MethodChannel('flac_toolkit/audio_decoder');
            await channel.invokeMethod('deleteMediaFile', {'filePath': track.filePath});
          } catch (_) {
            final f = File(track.filePath);
            if (f.existsSync()) f.deleteSync();
          }

          appState.removeTrackFromLibrary(track.filePath);
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
          final targetContext = widget.parentContext ?? ctx;
          if (targetContext.mounted) {
            showThemedSnackBar(
              targetContext,
              'Track permanently deleted & MediaStore refreshed',
              icon: Icons.delete_sweep_rounded,
              accentColor: AppColors.fakeCoral,
            );
          }
        } catch (e) {
          if (ctx.mounted) {
            showThemedSnackBar(ctx, 'Delete failed: $e', icon: Icons.error_outline_rounded);
          }
        }
      },
    );
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      style: GlassStyle.frosted,
      borderless: false,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x40FFFFFF) : const Color(0x40000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Scrollable Inspection Area
              Flexible(
                child: SingleChildScrollView(
                  physics: const BoundedBouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Unified Compact Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isDark
                                  ? AppColors.softElevation(elevation: 2.0)
                                  : AppColors.lightSoftElevation(elevation: 2.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _coverBytes != null
                                ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                                : Icon(Icons.album_rounded, size: 28, color: statusColor),
                          ),
                          const SizedBox(width: 12),
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedStatusBadge(
                                      status: track.status,
                                      color: statusColor,
                                      size: 22,
                                      animatePulse: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist.isNotEmpty ? '${track.artist} • ${track.album}' : 'Unknown Artist',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${track.bitDepth}-bit / ${(track.sampleRate / 1000).toStringAsFixed(1)}k',
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: subTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${track.fileSizeMb.toStringAsFixed(1)}MB • ${track.durationStr}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subTextColor,
                                      ),
                                    ),
                                    if (track.hasLyrics) ...[
                                      const SizedBox(width: 6),
                                      LuminousFeedback(
                                        onTap: () {
                                          Navigator.pop(context);
                                          showLyricsViewerSheet(context, track);
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.20 : 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lyrics_rounded, size: 11, color: Color(0xFF38BDF8)),
                                              SizedBox(width: 3),
                                              Text(
                                                'Lyrics',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF38BDF8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (_isAnalyzingDsp)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
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

                      // 2. Compact Audio Spectrum Stage
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
                        height: 110,
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Text(
                          track.verdict,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: subTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // 3. Audio Preview Bar
                      AudioPreviewBar(
                        filePath: track.filePath,
                        title: track.title.isNotEmpty ? track.title : track.fileName,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // 4. Sticky Bottom Action Bar (Pinned, Zero Clipping, Safe Area Aware)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x28000000) : const Color(0x10FFFFFF),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0x15FFFFFF) : const Color(0x0E000000),
                      width: 0.5,
                    ),
                  ),
                ),
                child: (track.status == 'fake' || track.status == 'suspicious')
                    ? Row(
                        children: [
                          Expanded(
                            child: LuminousFeedback(
                              onTap: () => _quarantineTrack(context, track),
                              borderRadius: BorderRadius.circular(13),
                              child: Container(
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.suspiciousAmber.withOpacity(isDark ? 0.22 : 0.15),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: AppColors.suspiciousAmber.withOpacity(0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shield_outlined, size: 16, color: AppColors.suspiciousAmber),
                                    SizedBox(width: 6),
                                    Text(
                                      'Quarantine',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.suspiciousAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LuminousFeedback(
                              onTap: () => _deleteTrack(context, track),
                              borderRadius: BorderRadius.circular(13),
                              child: Container(
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.fakeCoral.withOpacity(isDark ? 0.22 : 0.15),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: AppColors.fakeCoral.withOpacity(0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.fakeCoral),
                                    SizedBox(width: 6),
                                    Text(
                                      'Delete File',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.fakeCoral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 16, color: AppColors.genuineEmerald),
                              const SizedBox(width: 6),
                              Text(
                                'Authentic Lossless FLAC',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.genuineEmerald,
                                ),
                              ),
                            ],
                          ),
                          LuminousFeedback(
                            onTap: () => _deleteTrack(context, track),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 14, color: subTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
