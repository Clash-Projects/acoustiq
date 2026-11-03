import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../services/flac_parser.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/ambient_wallpaper.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/dev_lab_sheet.dart';

/// 1:1 Port of LastWave Native's Settings Architecture (Appearance & Visuals)
///
/// Features:
/// 1. 8-Preset Accent Palette Grid (Crimson, Violet, Ocean, Sage, Amber, Rose, Mono, Custom)
///    with 2x2 harmonized quadrant shades and animated checkmark selection.
/// 2. Apple WWDC25 Frosted & Clear Glass surfaces with hairline specular rim.
/// 3. Connected Group Architecture with 3dp gaps and 28dp/6dp continuous curvature.
/// 4. Pure Pitch Black AMOLED vs Deep Graphite live toggle.
/// 5. Liquid Glass toggle switching between optical blur and opaque surfaces.
/// 6. High-contrast Light Mode typography and segment controls.
/// 7. 96dp bottom padding (content glides behind the floating dock).
class SettingsScreen extends StatelessWidget {
  static int _devTapCount = 0;

  const SettingsScreen({super.key});

  Future<void> _quickScanDeviceMusic(BuildContext context) async {
    const path = '/storage/emulated/0/Music';
    final dir = Directory(path);
    if (!dir.existsSync()) {
      showThemedSnackBar(
        context,
        'Music folder /storage/emulated/0/Music not found',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.fakeCoral,
      );
      return;
    }

    if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
    showThemedSnackBar(
      context,
      'Scanning Music folder in background...',
      icon: Icons.hourglass_top_rounded,
    );

    final List<FlacInfo> tracks = [];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.flac')) {
          final info = await FlacParser.analyzeFile(entity.path);
          tracks.add(info);
        }
      }
      appState.setSharedLibrary(tracks, path);
      if (context.mounted) {
        showThemedSnackBar(
          context,
          'Audited ${tracks.length} tracks from Music folder',
          icon: Icons.verified_rounded,
          accentColor: AppColors.genuineEmerald,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showThemedSnackBar(
          context,
          'Scan error: $e',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.fakeCoral,
        );
      }
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
        final activeAccent = appState.getAccentColor(context);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Title
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
                    child: Text(
                      'Appearance & Visuals',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: textColor,
                      ),
                    ),
                  ),

                  // 1. ACOUSTIC SOUNDSTAGE PALETTE (Proprietary Hardware Modules)
                  buildSectionHeader('Acoustic Soundstage Palette', subTextColor),
                  _buildSoundstagePalette(context, isDark, textColor, subTextColor),

                  const SizedBox(height: 16),

                  // 2. AMBIENT ENVIRONMENT & WALLPAPER
                  buildSectionHeader('Ambient Glass Environment', subTextColor),
                  _buildWallpaperSection(context, isDark, textColor, subTextColor, activeAccent),

                  const SizedBox(height: 16),

                  // 3. THEME & GLASS MATERIALS
                  buildSectionHeader('Theme & Materials', subTextColor),
                  ExpressiveGroup(
                    rowCount: 3,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          // Theme Mode (System, Light, Dark)
                          return _buildThemeModeRow(context, position, isDark, textColor, subTextColor, activeAccent);
                        case 1:
                          // AMOLED Mode (Pitch black vs Graphite)
                          return ExpressiveGroupRow(
                            icon: Icons.brightness_2_rounded,
                            iconColor: const Color(0xFFC084FC),
                            iconBgColor: isDark ? const Color(0x30C084FC) : const Color(0xFFF3E8FF),
                            title: 'AMOLED Pure Black',
                            subtitle: isDark
                                ? (appState.amoledMode
                                    ? 'True 0-nit pitch black (#000000) for OLED panels'
                                    : 'Deep obsidian graphite (#12161A)')
                                : 'Active only in dark mode',
                            position: position,
                            trailing: Switch.adaptive(
                              value: appState.amoledMode,
                              activeColor: activeAccent,
                              onChanged: (val) {
                                if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                appState.setAmoledMode(val);
                              },
                            ),
                          );
                        case 2:
                        default:
                          // Liquid Glass Materials
                          return ExpressiveGroupRow(
                            icon: Icons.blur_on_rounded,
                            iconColor: activeAccent,
                            iconBgColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                            title: 'Liquid Glass Blur',
                            subtitle: appState.isLiquidGlass
                                ? 'Frosted optical blur & ambient glass styling'
                                : 'Solid opaque surfaces (Battery saver)',
                            position: position,
                            trailing: Switch.adaptive(
                              value: appState.isLiquidGlass,
                              activeColor: activeAccent,
                              onChanged: (val) {
                                if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                appState.setLiquidGlass(val);
                              },
                            ),
                          );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // 4. AUDIO ENGINE & SOUND STAGE
                  buildSectionHeader('Audio Engine & Sound Stage', subTextColor),
                  ExpressiveGroup(
                    rowCount: 3,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          // Visualizer Stage Switcher
                          return ExpressiveGroupRow(
                            icon: Icons.auto_graph_rounded,
                            iconColor: activeAccent,
                            iconBgColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                            title: 'Sound Stage Visualizer',
                            subtitle: 'Default style for the audio purity stage',
                            position: position,
                            trailing: Container(
                              height: 28,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0x20FFFFFF) : const Color(0x12000000),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _microVisualizerButton('gauge', Icons.speed_rounded, appState.visualizerMode, isDark, activeAccent),
                                  _microVisualizerButton('hybrid', Icons.electric_bolt_rounded, appState.visualizerMode, isDark, activeAccent),
                                  _microVisualizerButton('waveform', Icons.bar_chart_rounded, appState.visualizerMode, isDark, activeAccent),
                                ],
                              ),
                            ),
                          );
                        case 1:
                          // Haptic Feedback Switch
                          return ExpressiveGroupRow(
                            icon: Icons.vibration_rounded,
                            iconColor: const Color(0xFFA78BFA),
                            iconBgColor: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
                            title: 'Tactile Haptics',
                            subtitle: 'Vibrate lightly on tab switches and interactions',
                            position: position,
                            trailing: Switch.adaptive(
                              value: appState.hapticsEnabled,
                              activeColor: activeAccent,
                              onChanged: (val) {
                                appState.setHapticsEnabled(val);
                                if (val) HapticFeedback.mediumImpact();
                              },
                            ),
                          );
                        case 2:
                        default:
                          // Hardware MediaCodec Audio Engine Status
                          return ExpressiveGroupRow(
                            icon: Icons.memory_rounded,
                            iconColor: AppColors.genuineEmerald,
                            iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                            title: 'DSP Decoder Pipeline',
                            subtitle: 'MediaCodec hardware PCM extractor & 4096-pt Cooley-Tukey FFT',
                            position: position,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.genuineEmerald,
                                ),
                              ),
                            ),
                          );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // 5. STORAGE & MUSIC LIBRARY
                  buildSectionHeader('Storage & Music Library', subTextColor),
                  ExpressiveGroup(
                    rowCount: 4,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          return ExpressiveGroupRow(
                            icon: Icons.library_music_rounded,
                            iconColor: const Color(0xFFA78BFA),
                            iconBgColor: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
                            title: 'Audited Library',
                            subtitle: 'Indexed and verified FLAC tracks in memory',
                            position: position,
                            trailing: Text(
                              '${appState.sharedLibrary.length} tracks',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: activeAccent,
                              ),
                            ),
                          );
                        case 1:
                          return ExpressiveGroupRow(
                            icon: Icons.folder_rounded,
                            iconColor: AppColors.suspiciousAmber,
                            iconBgColor: isDark ? const Color(0x30FFB300) : const Color(0xFFFEF3C7),
                            title: 'Source Music Directory',
                            subtitle: appState.lastScannedFolder != null
                                ? appState.lastScannedFolder!
                                : 'No folder scanned yet',
                            position: position,
                            trailing: null,
                          );
                        case 2:
                          return ExpressiveGroupRow(
                            icon: Icons.flash_on_rounded,
                            iconColor: AppColors.genuineEmerald,
                            iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                            title: '1-Tap Quick Scan Music',
                            subtitle: '/storage/emulated/0/Music • Direct scan with zero SAF prompt',
                            position: position,
                            onTap: () => _quickScanDeviceMusic(context),
                            trailing: Icon(Icons.play_arrow_rounded, color: AppColors.genuineEmerald, size: 20),
                          );
                        case 3:
                        default:
                          return ExpressiveGroupRow(
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear Library Cache',
                            subtitle: 'Reset in-memory audited FLAC tracks and duplicate sets',
                            position: position,
                            danger: true,
                            onTap: () {
                              if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                              appState.setSharedLibrary([], '');
                              showThemedSnackBar(
                                context,
                                'Library cache cleared successfully',
                                icon: Icons.delete_sweep_rounded,
                              );
                            },
                          );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // 6. ABOUT & TOOLKIT DIAGNOSTICS
                  buildSectionHeader('About & Toolkit Diagnostics', subTextColor),
                  ExpressiveGroup(
                    rowCount: appState.devModeEnabled ? 4 : 3,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          return ExpressiveGroupRow(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            iconBgColor: isDark ? const Color(0x3038BDF8) : const Color(0xFFE0F2FE),
                            title: 'Engine Version',
                            subtitle: 'AcoustiQ Mobile • Build 45 (QA Lab Ready)',
                            position: position,
                            onTap: () {
                              _devTapCount++;
                              if (_devTapCount >= 5) {
                                _devTapCount = 0;
                                appState.toggleDevMode();
                                showThemedSnackBar(
                                  context,
                                  appState.devModeEnabled ? '🧪 AcoustiQ Dev Lab Activated!' : '🔒 Dev Lab Deactivated',
                                  icon: Icons.science_rounded,
                                );
                              } else if (_devTapCount >= 2) {
                                showThemedSnackBar(
                                  context,
                                  'Tap ${5 - _devTapCount} more times to toggle Dev Lab',
                                  duration: const Duration(milliseconds: 700),
                                );
                              }
                            },
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v1.1.0+45',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: activeAccent,
                                ),
                              ),
                            ),
                          );
                        case 1:
                          return ExpressiveGroupRow(
                            icon: Icons.vibration_rounded,
                            iconColor: AppColors.genuineEmerald,
                            iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                            title: 'Haptic Feedback',
                            subtitle: 'Tactile spring clicks on dock glide & button taps',
                            position: position,
                            trailing: Switch.adaptive(
                              value: appState.hapticsEnabled,
                              activeColor: AppColors.genuineEmerald,
                              onChanged: (val) => appState.setHaptics(val),
                            ),
                          );
                        case 2:
                          return ExpressiveGroupRow(
                            icon: Icons.verified_user_rounded,
                            iconColor: AppColors.genuineEmerald,
                            iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                            title: 'Integrity Standard',
                            subtitle: 'Read-only forensic analysis engine guarantees 100% audio safety',
                            position: position,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'VERIFIED',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.genuineEmerald,
                                ),
                              ),
                            ),
                          );
                        case 3:
                        default:
                          return ExpressiveGroupRow(
                            icon: Icons.science_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            iconBgColor: isDark ? const Color(0x3038BDF8) : const Color(0xFFE0F2FE),
                            title: 'AcoustiQ Dev Lab & QA',
                            subtitle: 'Mock audio injection, live theme matrix & modal contrast QA',
                            position: position,
                            onTap: () => showDevLabSheet(context),
                            trailing: LuminousFeedback(
                              onTap: () => showDevLabSheet(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: activeAccent.withOpacity(isDark ? 0.25 : 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: activeAccent.withOpacity(0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Open Lab',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: activeAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The Acoustic Soundstage Palette (Proprietary Hardware Modules with Live Spectrum Visualizers)
  Widget _buildSoundstagePalette(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final modules = [
      (
        id: 'Prism Cyan',
        title: 'Prism Cyan',
        subtitle: 'CD Master // 20 kHz Ref',
        color: const Color(0xFF00E5FF),
        pattern: [0.4, 0.7, 0.95, 0.6, 0.85, 1.0, 0.75, 0.5, 0.3],
      ),
      (
        id: 'Analog Amber',
        title: 'Analog Amber',
        subtitle: 'Tube Warmth // Vinyl Tone',
        color: const Color(0xFFFF9500),
        pattern: [0.6, 0.85, 0.7, 0.9, 0.6, 0.75, 0.5, 0.4, 0.3],
      ),
      (
        id: 'Acoustic Emerald',
        title: 'Acoustic Emerald',
        subtitle: 'Lossless Lock // Studio Monitor',
        color: const Color(0xFF00E676),
        pattern: [0.35, 0.55, 0.8, 1.0, 0.9, 0.75, 0.6, 0.45, 0.3],
      ),
      (
        id: 'Ultraviolet Hi-Res',
        title: 'Ultraviolet Hi-Res',
        subtitle: 'Ultrasonic // 96k Master',
        color: const Color(0xFF8B5CF6),
        pattern: [0.5, 0.75, 0.9, 0.7, 1.0, 0.85, 0.95, 0.65, 0.4],
      ),
      (
        id: 'Crimson Peak',
        title: 'Crimson Peak',
        subtitle: 'Dynamic // Transient Energy',
        color: const Color(0xFFFF3B30),
        pattern: [0.3, 0.6, 0.85, 1.0, 0.4, 0.95, 0.7, 0.5, 0.35],
      ),
      (
        id: 'Titanium Mono',
        title: 'Titanium Mono',
        subtitle: 'Studio Console // High-Contrast',
        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        pattern: [0.5, 0.5, 0.8, 0.8, 1.0, 1.0, 0.7, 0.7, 0.4],
      ),
    ];

    final currentPreset = appState.accentPreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2-Column Module Grid Pairs
        for (int r = 0; r < modules.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSoundstageModuleCard(
                  context: context,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  id: modules[r].id,
                  title: modules[r].title,
                  subtitle: modules[r].subtitle,
                  color: modules[r].color,
                  pattern: modules[r].pattern,
                  isSelected: currentPreset == modules[r].id ||
                      (modules[r].id == 'Prism Cyan' && currentPreset == 'Ocean') ||
                      (modules[r].id == 'Analog Amber' && currentPreset == 'Amber') ||
                      (modules[r].id == 'Acoustic Emerald' && currentPreset == 'Sage') ||
                      (modules[r].id == 'Ultraviolet Hi-Res' && currentPreset == 'Violet') ||
                      (modules[r].id == 'Crimson Peak' && currentPreset == 'Crimson') ||
                      (modules[r].id == 'Titanium Mono' && currentPreset == 'Mono'),
                  onSelect: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset(modules[r].id);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSoundstageModuleCard(
                  context: context,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  id: modules[r + 1].id,
                  title: modules[r + 1].title,
                  subtitle: modules[r + 1].subtitle,
                  color: modules[r + 1].color,
                  pattern: modules[r + 1].pattern,
                  isSelected: currentPreset == modules[r + 1].id ||
                      (modules[r + 1].id == 'Prism Cyan' && currentPreset == 'Ocean') ||
                      (modules[r + 1].id == 'Analog Amber' && currentPreset == 'Amber') ||
                      (modules[r + 1].id == 'Acoustic Emerald' && currentPreset == 'Sage') ||
                      (modules[r + 1].id == 'Ultraviolet Hi-Res' && currentPreset == 'Violet') ||
                      (modules[r + 1].id == 'Crimson Peak' && currentPreset == 'Crimson') ||
                      (modules[r + 1].id == 'Titanium Mono' && currentPreset == 'Mono'),
                  onSelect: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset(modules[r + 1].id);
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        // Master Card: Custom Resonance
        _buildCustomResonanceCard(
          context: context,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          isSelected: currentPreset == 'Custom Resonance' || currentPreset == 'Custom',
          customColor: appState.customColor,
          onSelect: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            appState.setAccentPreset('Custom Resonance');
          },
          onTune: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            appState.setAccentPreset('Custom Resonance');
            _openCustomColorPicker(context, isDark, textColor, subTextColor);
          },
        ),
      ],
    );
  }

  Widget _buildSoundstageModuleCard({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required String id,
    required String title,
    required String subtitle,
    required Color color,
    required List<double> pattern,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSelect,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color.withOpacity(isDark ? 0.9 : 0.8)
                  : (isDark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
              width: isSelected ? 1.5 : 0.85,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(isDark ? 0.22 : 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(16),
            style: GlassStyle.frosted,
            borderless: true,
            tintColor: isSelected ? color.withOpacity(isDark ? 0.16 : 0.08) : null,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.8), blurRadius: 4)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? textColor : textColor.withOpacity(0.9),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: AppColors.getOnAccentColor(color, isDark: isDark),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _MiniSoundstageWaveform(
                  color: color,
                  heights: pattern,
                  isAnimated: isSelected,
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9.0,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? color : subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomResonanceCard({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required bool isSelected,
    required Color customColor,
    required VoidCallback onSelect,
    required VoidCallback onTune,
  }) {
    final hexStr = '#${customColor.value.toRadixString(16).substring(2).toUpperCase()}';
    const pattern = [0.4, 0.65, 0.9, 0.75, 1.0, 0.8, 0.6, 0.45, 0.3];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSelect,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? customColor.withOpacity(isDark ? 0.9 : 0.8)
                  : (isDark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
              width: isSelected ? 1.5 : 0.85,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: customColor.withOpacity(isDark ? 0.22 : 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(16),
            style: GlassStyle.frosted,
            borderless: true,
            tintColor: isSelected ? customColor.withOpacity(isDark ? 0.16 : 0.08) : null,
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: customColor,
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: customColor.withOpacity(0.8), blurRadius: 4)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Custom Resonance',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? textColor : textColor.withOpacity(0.9),
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: customColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: AppColors.getOnAccentColor(customColor, isDark: isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MiniSoundstageWaveform(
                        color: customColor,
                        heights: pattern,
                        isAnimated: isSelected,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Active Chroma: $hexStr // Tap Tune to customize',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 9.0,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? customColor : subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Tune Button Pill
                GestureDetector(
                  onTap: onTune,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: customColor.withOpacity(isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: customColor.withOpacity(0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 14,
                          color: customColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'TUNE',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? Colors.white : customColor,
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
      ),
    );
  }

  /// Curated Ambient Glass Wallpaper & Environment Selector
  Widget _buildWallpaperSection(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    const presets = [
      (key: 'nebula', name: 'Obsidian\nNebula'),
      (key: 'abyss', name: 'Emerald\nAbyss'),
      (key: 'sunset', name: 'Sunset\nHorizon'),
      (key: 'solid', name: 'Solid\nCanvas'),
    ];

    final isCustom = appState.wallpaperPreset == 'custom';
    final customPath = appState.customWallpaperPath;
    final hasValidCustomFile = customPath != null && File(customPath).existsSync();

    return GlassSurface(
      borderRadius: BorderRadius.circular(24),
      style: GlassStyle.frosted,
      borderless: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Presets Row (4 Curated Atmospheric Environments)
          Row(
            children: [
              for (int i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _buildWallpaperPresetTile(
                    context: context,
                    presetKey: presets[i].key,
                    name: presets[i].name,
                    isSelected: appState.wallpaperPreset == presets[i].key,
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    activeAccent: activeAccent,
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                      appState.setWallpaperPreset(presets[i].key);
                    },
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // 2. Custom Wallpaper Loader Card (Persistent Slot & Direct Override)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (hasValidCustomFile && !isCustom) {
                  // Instant 1-tap activation of already saved custom wallpaper!
                  if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                  appState.setWallpaperPreset('custom');
                } else {
                  _pickCustomWallpaper(context);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCustom
                        ? activeAccent.withOpacity(0.6)
                        : (isDark ? const Color(0x1AFFFFFF) : const Color(0x10000000)),
                    width: isCustom ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Thumbnail preview or Gallery Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE2E8F0),
                        border: Border.all(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x22000000),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasValidCustomFile
                          ? Image.file(
                              File(customPath),
                              key: ValueKey(customPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                size: 20,
                                color: Color(0x88FFFFFF),
                              ),
                            )
                          : Icon(
                              Icons.wallpaper_rounded,
                              size: 22,
                              color: isCustom ? activeAccent : subTextColor,
                            ),
                    ),

                    const SizedBox(width: 12),

                    // Text Info (Uncluttered, responsive on mobile)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Wallpaper',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCustom && hasValidCustomFile
                                ? 'Active • Tap to replace photo'
                                : (hasValidCustomFile
                                    ? 'Saved photo • Tap to apply'
                                    : 'Choose personal photo for ambient glass'),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.0,
                              color: isCustom ? activeAccent : subTextColor,
                              fontWeight: isCustom ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Trailing Controls: Segmented Glass Capsule [ ✏️ Edit | ✕ Remove ]
                    if (isCustom && hasValidCustomFile)
                      Container(
                        height: 32,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x22FFFFFF) : const Color(0x12000000),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0x24FFFFFF) : const Color(0x18000000),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LuminousFeedback(
                              onTap: () => _pickCustomWallpaper(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.edit_rounded, size: 15, color: activeAccent),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                            ),
                            LuminousFeedback(
                              onTap: () {
                                if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                appState.clearCustomWallpaper();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.close_rounded, size: 15, color: subTextColor),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (hasValidCustomFile)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: activeAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: activeAccent.withOpacity(0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: activeAccent,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0E000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                          color: subTextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Preset Swatch Tile with Miniature Mesh Preview
  Widget _buildWallpaperPresetTile({
    required BuildContext context,
    required String presetKey,
    required String name,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? activeAccent
                      : (isDark ? const Color(0x24FFFFFF) : const Color(0x18000000)),
                  width: isSelected ? 2.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Mini live gradient preview
                    AmbientWallpaperView.buildPreview(presetKey, isDark),

                    // Active checkmark badge
                    if (isSelected)
                      Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.55),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              height: 1.15,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? textColor : subTextColor,
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _microVisualizerButton(String targetMode, IconData icon, String currentMode, bool isDark, Color activeAccent) {
    final isSelected = currentMode == targetMode;
    return GestureDetector(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
        appState.setVisualizerMode(targetMode);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0x50FFFFFF) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 13,
          color: isSelected ? activeAccent : (isDark ? const Color(0x88FFFFFF) : const Color(0x88000000)),
        ),
      ),
    );
  }

  /// Launch modern Android photo picker for custom gallery image & sandbox cleanly
  Future<void> _pickCustomWallpaper(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final oldPath = appState.customWallpaperPath;

        // 1. Evict old image from cache and clean up previous file
        if (oldPath != null) {
          try {
            await FileImage(File(oldPath)).evict();
            final oldFile = File(oldPath);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (_) {}
        }

        // 2. Generate timestamped file path to bust cache 100%
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final targetFile = File('${appDir.path}/custom_ambient_$timestamp.jpg');
        final bytes = await image.readAsBytes();
        await targetFile.writeAsBytes(bytes, flush: true);

        // 3. Clear Flutter ImageCache completely & evict new file
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await FileImage(targetFile).evict();

        appState.setCustomWallpaperPath(targetFile.path);
        if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
        if (context.mounted) {
          showThemedSnackBar(
            context,
            'Custom wallpaper applied to ambient environment',
            icon: Icons.wallpaper_rounded,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showThemedSnackBar(
          context,
          'Failed to pick wallpaper: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  /// Apple WWDC25 Frosted Glass Custom Accent Palette & Hue Scrub Sheet
  void _openCustomColorPicker(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final curColor = appState.customColor;
    final hsv = HSVColor.fromColor(curColor);
    double currentHue = hsv.hue;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      isScrollControlled: true,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeCustom = appState.customColor;
            final hexStr = '#${activeCustom.value.toRadixString(16).substring(2).toUpperCase()}';

            const swatches = [
              Color(0xFF00D2FF), // Electric Cyan
              Color(0xFF00E5FF), // Neon Teal
              Color(0xFF0091EA), // Deep Azure
              Color(0xFF536DFE), // Royal Indigo
              Color(0xFF7C4DFF), // Electric Purple
              Color(0xFFE040FB), // Vivid Magenta
              Color(0xFFFF4081), // Hot Pink
              Color(0xFFFF5252), // Sunset Coral
              Color(0xFFFF6E40), // Flame Orange
              Color(0xFFFFD700), // Amber Gold
              Color(0xFF00E676), // Lime Emerald
              Color(0xFF1DE9B6), // Mint Jade
            ];

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xE012161A) : const Color(0xF5FFFFFF),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0x33FFFFFF) : const Color(0x20000000),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x40FFFFFF) : const Color(0x30000000),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Header Row: Title & Active Color Swatch Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Custom Accent Color',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live chromatic palette across all surfaces',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),

                        // Live Swatch Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: activeCustom.withOpacity(0.60),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: activeCustom,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.35),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hexStr,
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 12 Curated Swatches Grid (6 across x 2 rows)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        for (final c in swatches)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                appState.setAccentPreset('Custom Resonance', c);
                                setModalState(() {
                                  currentHue = HSVColor.fromColor(c).hue;
                                });
                              },
                              child: Container(
                                width: (MediaQuery.of(context).size.width - 40 - (5 * 12)) / 6,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: activeCustom.value == c.value
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: activeCustom.value == c.value
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: activeCustom.value == c.value
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Spectrum Hue Slider Title
                    Text(
                      'SPECTRUM HUE',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: subTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Rainbow Track Container with Overlay Slider
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 36,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 14,
                            elevation: 4,
                          ),
                          overlayColor: Colors.transparent,
                          mouseCursor: const MaterialStatePropertyAll(SystemMouseCursors.click),
                        ),
                        child: Slider(
                          value: currentHue,
                          min: 0.0,
                          max: 360.0,
                          onChanged: (val) {
                            setModalState(() => currentHue = val);
                            final newCol = HSVColor.fromAHSV(1.0, val, 0.85, 0.95).toColor();
                            appState.setAccentPreset('Custom Resonance', newCol);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Done / Apply Pill Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                          Navigator.pop(modalCtx);
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: activeCustom,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Apply Accent Color',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildThemeModeRow(
    BuildContext context,
    GroupPosition position,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    final shape = groupShape(position);

    return GlassSurface(
      borderRadius: shape,
      style: GlassStyle.frosted,
      borderless: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x30818CF8) : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  size: 22,
                  color: Color(0xFF818CF8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose system default, light, or dark look',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Clean Borderless Segmented Button Row
          Row(
            children: [
              _buildThemeSegment('System', Icons.settings_brightness_rounded, 'system', isDark, activeAccent),
              const SizedBox(width: 6),
              _buildThemeSegment('Light', Icons.light_mode_rounded, 'light', isDark, activeAccent),
              const SizedBox(width: 6),
              _buildThemeSegment('Dark', Icons.dark_mode_rounded, 'dark', isDark, activeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegment(
    String label,
    IconData icon,
    String mode,
    bool isDark,
    Color activeAccent,
  ) {
    final isSelected = appState.themeMode == mode;
    final selectedFg = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final unselectedFg = isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary;

    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(12),
        style: GlassStyle.clear,
        borderless: false,
        tintColor: isSelected
            ? activeAccent.withOpacity(isDark ? 0.30 : 0.15)
            : null,
        child: InkWell(
          onTap: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            appState.setThemeMode(mode);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? selectedFg : unselectedFg,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? selectedFg : unselectedFg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSoundstageWaveform extends StatefulWidget {
  final Color color;
  final List<double> heights;
  final bool isAnimated;

  const _MiniSoundstageWaveform({
    super.key,
    required this.color,
    required this.heights,
    required this.isAnimated,
  });

  @override
  State<_MiniSoundstageWaveform> createState() => _MiniSoundstageWaveformState();
}

class _MiniSoundstageWaveformState extends State<_MiniSoundstageWaveform>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    if (widget.isAnimated) {
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MiniSoundstageWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated && _animController == null) {
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    } else if (!widget.isAnimated && _animController != null) {
      _animController?.dispose();
      _animController = null;
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animController == null) {
      return _buildBars(0.0);
    }
    return AnimatedBuilder(
      animation: _animController!,
      builder: (context, _) => _buildBars(_animController!.value),
    );
  }

  Widget _buildBars(double animVal) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.heights.length, (i) {
          final baseH = widget.heights[i];
          final phase = math.sin((animVal * math.pi * 2) + (i * 0.7));
          final scale = widget.isAnimated ? (baseH * (0.75 + 0.25 * phase)) : baseH;
          final h = math.max(4.0, 19.0 * scale.clamp(0.15, 1.0));

          return Container(
            width: 3.5,
            height: h,
            margin: const EdgeInsets.only(right: 3.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  widget.color.withOpacity(0.40),
                  widget.color,
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
