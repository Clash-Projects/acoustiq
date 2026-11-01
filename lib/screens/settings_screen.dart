import 'dart:io';
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

                  // 1. ACCENT SECTION (LastWave 8-Preset Palette Grid)
                  buildSectionHeader('Accent', subTextColor),
                  _buildAccentGrid(context, isDark, textColor, subTextColor),

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

                  // 4. AUDIO ENGINE & AUDIOPHILE SETTINGS
                  buildSectionHeader('Audio Engine & Audiophile Settings', subTextColor),
                  ExpressiveGroup(
                    rowCount: 4,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          // Pro Audiophile Mode Switch
                          return ExpressiveGroupRow(
                            icon: Icons.science_rounded,
                            iconColor: const Color(0xFF00D2FF),
                            iconBgColor: const Color(0xFF00D2FF).withOpacity(isDark ? 0.20 : 0.12),
                            title: 'Pro Audiophile Mode',
                            subtitle: appState.audiophileMode
                                ? 'Displaying raw Nyquist limit, STFT dB slope, and bit-depth metrics'
                                : 'Everyday mode active • Simple human-friendly audio terms',
                            position: position,
                            trailing: Switch.adaptive(
                              value: appState.audiophileMode,
                              activeColor: activeAccent,
                              onChanged: (val) {
                                if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                                appState.setAudiophileMode(val);
                              },
                            ),
                          );
                        case 1:
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
                        case 2:
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
                        case 3:
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
                    rowCount: 3,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          return ExpressiveGroupRow(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            iconBgColor: isDark ? const Color(0x3038BDF8) : const Color(0xFFE0F2FE),
                            title: 'Engine Version',
                            subtitle: 'FLAC Toolkit Mobile • Build 20 (Release)',
                            position: position,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v1.1.0+20',
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
                        default:
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

  /// 8-Preset Accent Palette Grid (Exact 1:1 match with LastWave Image 1)
  Widget _buildAccentGrid(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    const presets = [
      (
        name: 'Crimson',
        shades: [Color(0xFF8B1A1A), Color(0xFFB71C1C), Color(0xFFEF9A9A), Color(0xFFE03030)],
      ),
      (
        name: 'Violet',
        shades: [Color(0xFF4C27B8), Color(0xFF673AB7), Color(0xFFB39DDB), Color(0xFF7C4DFF)],
      ),
      (
        name: 'Ocean',
        shades: [Color(0xFF135A7A), Color(0xFF1B7BA3), Color(0xFF72C3E5), Color(0xFF2196C6)],
      ),
      (
        name: 'Sage',
        shades: [Color(0xFF3B5E3B), Color(0xFF4E7D4E), Color(0xFFA5D6A5), Color(0xFF6B9E6B)],
      ),
      (
        name: 'Amber',
        shades: [Color(0xFF8C5E13), Color(0xFFB7791A), Color(0xFFFFE082), Color(0xFFE0A030)],
      ),
      (
        name: 'Rose',
        shades: [Color(0xFF8C2442), Color(0xFFB83259), Color(0xFFF48FB1), Color(0xFFE0507A)],
      ),
    ];

    return GlassSurface(
      borderRadius: BorderRadius.circular(24),
      style: GlassStyle.frosted,
      borderless: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Row 1: Crimson, Violet, Ocean, Sage
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _buildAccentTile(
                    context: context,
                    name: presets[i].name,
                    shades: presets[i].shades,
                    isSelected: appState.accentPreset == presets[i].name,
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                      appState.setAccentPreset(presets[i].name);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Amber, Rose, Mono, Custom
          Row(
            children: [
              Expanded(
                child: _buildAccentTile(
                  context: context,
                  name: presets[4].name,
                  shades: presets[4].shades,
                  isSelected: appState.accentPreset == presets[4].name,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  onTap: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset(presets[4].name);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAccentTile(
                  context: context,
                  name: presets[5].name,
                  shades: presets[5].shades,
                  isSelected: appState.accentPreset == presets[5].name,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  onTap: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset(presets[5].name);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Mono Tile
              Expanded(
                child: _buildSpecialAccentTile(
                  context: context,
                  name: 'Mono',
                  isSelected: appState.accentPreset == 'Mono',
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  icon: Icons.contrast_rounded,
                  bg: isDark ? const Color(0xFF22262B) : const Color(0xFFE2E4E8),
                  iconColor: isDark ? Colors.white : const Color(0xFF101828),
                  onTap: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset('Mono');
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Custom Tile (Rainbow Gradient)
              Expanded(
                child: _buildSpecialAccentTile(
                  context: context,
                  name: 'Custom',
                  isSelected: appState.accentPreset == 'Custom',
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  icon: Icons.colorize_rounded,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFE03030),
                      Color(0xFFE0A030),
                      Color(0xFF6B9E6B),
                      Color(0xFF2196C6),
                      Color(0xFF7C4DFF),
                      Color(0xFFE03030),
                    ],
                  ),
                  iconColor: Colors.white,
                  onTap: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset('Custom');
                    _openCustomColorPicker(context, isDark, textColor, subTextColor);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Quadrant 2x2 Swatch Tile for color presets
  Widget _buildAccentTile({
    required BuildContext context,
    required String name,
    required List<Color> shades,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
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
                        ? (isDark ? Colors.white : const Color(0xFF101828))
                        : Colors.transparent,
                    width: 2.0,
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
                    children: [
                      // 2x2 Quadrant Shades
                      Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: Container(color: shades[0])),
                                Expanded(child: Container(color: shades[1])),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: Container(color: shades[2])),
                                Expanded(child: Container(color: shades[3])),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Checkmark Badge when selected
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? textColor : subTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Special Tile for Mono and Custom (Rainbow gradient)
  Widget _buildSpecialAccentTile({
    required BuildContext context,
    required String name,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required IconData icon,
    Color? bg,
    Gradient? gradient,
    required Color iconColor,
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
                  color: bg,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF101828))
                        : Colors.transparent,
                    width: 2.0,
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
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: 22, color: iconColor),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? textColor : subTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
                                appState.setAccentPreset('Custom', c);
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
                            appState.setAccentPreset('Custom', newCol);
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
