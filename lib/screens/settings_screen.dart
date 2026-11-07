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
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _activeSubPageIndex; // null = Master Hub, 0 = Appearance, 1 = Audio Engine, 2 = Library, 3 = About
  static int _devTapCount = 0;

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
            child: PopScope(
              canPop: _activeSubPageIndex == null,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && _activeSubPageIndex != null) {
                  if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                  setState(() => _activeSubPageIndex = null);
                }
              },
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: appState.isMotionOff ? 0 : 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  if (appState.isMotionOff) return child;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _activeSubPageIndex == null
                    ? _buildMasterHub(context, isDark, textColor, subTextColor, activeAccent)
                    : _buildSubPageView(context, _activeSubPageIndex!, isDark, textColor, subTextColor, activeAccent),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMasterHub(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    final libraryCount = appState.sharedLibrary.length;
    final motionLabel = appState.motionPreset == 'full'
        ? '120Hz Full'
        : (appState.motionPreset == 'reduced' ? 'Reduced' : 'Motion Off');

    return SingleChildScrollView(
      key: const ValueKey('master_settings_hub'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings & System',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'AcoustiQ High-Res Audio Engine • v1.1.0',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Appearance & Visuals Card
          _buildHubCard(
            context: context,
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            accentColor: activeAccent,
            icon: Icons.palette_rounded,
            title: 'Appearance & Visuals',
            subtitle: 'Accent colors, ambient wallpapers, theme modes & smooth animations',
            badges: [
              appState.accentPreset.toUpperCase(),
              appState.amoledMode && isDark ? 'PURE BLACK' : (isDark ? 'DARK' : 'LIGHT'),
              if (appState.isLiquidGlass) 'GLASS BLUR',
              motionLabel.toUpperCase(),
            ],
            onTap: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = 0);
            },
          ),

          // 2. Audio Engine & Detection Card
          _buildHubCard(
            context: context,
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            accentColor: AppColors.genuineEmerald,
            icon: Icons.memory_rounded,
            title: 'Audio Engine & Detection',
            subtitle: 'Lossless audio decoder, visualizer style & haptic feedback',
            badges: [
              'AUDIO READY',
              '${appState.visualizerMode.toUpperCase()} VISUALIZER',
              if (appState.hapticsEnabled) 'HAPTICS ON',
            ],
            onTap: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = 1);
            },
          ),

          // 3. Storage & Music Library Card
          _buildHubCard(
            context: context,
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            accentColor: const Color(0xFFA78BFA),
            icon: Icons.library_music_rounded,
            title: 'Library & Storage Management',
            subtitle: 'Music folders, audited tracks & library scanning',
            badges: [
              '$libraryCount TRACKS',
              if (appState.lastScannedFolder != null) 'FOLDER LINKED' else 'READY TO SCAN',
            ],
            onTap: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = 2);
            },
          ),

          // 4. Diagnostics & About AcoustiQ Card
          _buildHubCard(
            context: context,
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            accentColor: const Color(0xFF38BDF8),
            icon: Icons.info_outline_rounded,
            title: 'Diagnostics & About AcoustiQ',
            subtitle: 'App version, verification standards & privacy guarantee',
            badges: [
              'VERSION 1.1.0',
              'OFFLINE & PRIVATE',
              if (appState.devModeEnabled) 'DEV LAB',
            ],
            onTap: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = 3);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> badges,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x24FFFFFF) : const Color(0x16000000),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x1A000000) : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(20),
            style: GlassStyle.frosted,
            borderless: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentColor.withOpacity(0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: subTextColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: subTextColor.withOpacity(0.65),
                      size: 22,
                    ),
                  ],
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: badges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0x28FFFFFF) : const Color(0x15000000),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: textColor.withOpacity(0.85),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubPageView(
    BuildContext context,
    int index,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    switch (index) {
      case 0:
        return _buildAppearanceSubPage(context, isDark, textColor, subTextColor, activeAccent);
      case 1:
        return _buildAudioEngineSubPage(context, isDark, textColor, subTextColor, activeAccent);
      case 2:
        return _buildLibrarySubPage(context, isDark, textColor, subTextColor, activeAccent);
      case 3:
      default:
        return _buildAboutSubPage(context, isDark, textColor, subTextColor, activeAccent);
    }
  }

  Widget _buildSubPageHeader({
    required String title,
    required String subtitle,
    required VoidCallback onBack,
    required Color textColor,
    required Color subTextColor,
    required Color activeAccent,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 6, bottom: 12),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: isDark ? const Color(0x2AFFFFFF) : const Color(0x18000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 12,
                      color: textColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
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
        ],
      ),
    );
  }

  Widget _buildAppearanceSubPage(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('subpage_appearance'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubPageHeader(
            title: 'Appearance & Visuals',
            subtitle: 'Accent colors, ambient wallpapers, theme modes & animations',
            onBack: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = null);
            },
            textColor: textColor,
            subTextColor: subTextColor,
            activeAccent: activeAccent,
            isDark: isDark,
          ),

          // 1. ACCENT COLOR GRID
          buildSectionHeader('Accent Color', subTextColor),
          _buildAccentColorGrid(context, isDark, textColor, subTextColor),

          const SizedBox(height: 16),

          // 2. AMBIENT WALLPAPER
          buildSectionHeader('Ambient Wallpaper', subTextColor),
          _buildWallpaperSection(context, isDark, textColor, subTextColor, activeAccent),

          const SizedBox(height: 16),

          // 3. DISPLAY & SURFACES
          buildSectionHeader('Display & Surfaces', subTextColor),
          ExpressiveGroup(
            rowCount: 3,
            itemBuilder: (context, index, position) {
              switch (index) {
                case 0:
                  return _buildThemeModeRow(context, position, isDark, textColor, subTextColor, activeAccent);
                case 1:
                  return ExpressiveGroupRow(
                    icon: Icons.brightness_2_rounded,
                    iconColor: const Color(0xFFC084FC),
                    iconBgColor: isDark ? const Color(0x30C084FC) : const Color(0xFFF3E8FF),
                    title: 'Pure Black (OLED)',
                    subtitle: isDark
                        ? (appState.amoledMode
                            ? 'Deep pure black backgrounds to save battery on OLED screens'
                            : 'Soft graphite dark backgrounds')
                        : 'Active only when dark mode is enabled',
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
                  return ExpressiveGroupRow(
                    icon: Icons.blur_on_rounded,
                    iconColor: activeAccent,
                    iconBgColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                    title: 'Glass Blur Effect',
                    subtitle: appState.isLiquidGlass
                        ? 'Frosted translucent glass across cards and dialogs'
                        : 'Solid opaque surfaces to save battery on older devices',
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

          // 4. MOTION & ANIMATIONS
          _buildMotionHubSection(context, isDark, textColor, subTextColor, activeAccent),
        ],
      ),
    );
  }

  Widget _buildMotionHubSection(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    final currentPreset = appState.motionPreset;

    final IconData statusIcon;
    final String statusBadge;
    final Color statusBadgeBg;
    final Color statusBadgeText;
    final String statusTitle;
    final String statusBody1;
    final String statusBody2;

    switch (currentPreset) {
      case 'reduced':
        statusIcon = Icons.tune_rounded;
        statusBadge = 'BALANCED';
        statusBadgeBg = AppColors.suspiciousAmber.withOpacity(isDark ? 0.25 : 0.15);
        statusBadgeText = AppColors.suspiciousAmber;
        statusTitle = 'Essential Screen Transitions';
        statusBody1 = 'Page transitions remain smooth and responsive.';
        statusBody2 = 'Continuous looping waveforms are paused to save battery.';
        break;
      case 'off':
        statusIcon = Icons.block_rounded;
        statusBadge = 'BATTERY SAVER';
        statusBadgeBg = const Color(0xFF64748B).withOpacity(isDark ? 0.25 : 0.15);
        statusBadgeText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        statusTitle = 'Instant Static Rendering';
        statusBody1 = 'Zero animation overhead across the entire app.';
        statusBody2 = 'Maximum battery life and optimal performance on low-power devices.';
        break;
      case 'full':
      default:
        statusIcon = Icons.bolt_rounded;
        statusBadge = '120Hz SMOOTH';
        statusBadgeBg = AppColors.genuineEmerald.withOpacity(isDark ? 0.25 : 0.15);
        statusBadgeText = AppColors.genuineEmerald;
        statusTitle = 'Full Fluid Animations';
        statusBody1 = 'High-refresh 120Hz screen transitions and active visualizers.';
        statusBody2 = 'Recommended for modern displays for maximum visual fluidity.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionHeader('Motion & Animations', subTextColor),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0x24FFFFFF) : const Color(0x16000000),
              width: 0.85,
            ),
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(20),
            style: GlassStyle.frosted,
            borderless: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.motion_photos_on_rounded, color: activeAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motion Smoothness',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Animation refresh rate & power balance',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 3-way segment buttons (Clean Native Vector Icons, zero emojis)
                Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildMotionSegment('full', Icons.bolt_rounded, 'Full', currentPreset, isDark, activeAccent, textColor),
                      _buildMotionSegment('reduced', Icons.tune_rounded, 'Reduced', currentPreset, isDark, activeAccent, textColor),
                      _buildMotionSegment('off', Icons.block_rounded, 'Off', currentPreset, isDark, activeAccent, textColor),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Formatted Status Card (Structured typography, bold highlights, line gaps)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBadgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusBadgeText),
                                const SizedBox(width: 4),
                                Text(
                                  statusBadge,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: statusBadgeText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusTitle,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: activeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusBody1,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: subTextColor,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: activeAccent.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusBody2,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: subTextColor,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMotionSegment(
    String presetKey,
    IconData icon,
    String label,
    String activePreset,
    bool isDark,
    Color activeAccent,
    Color textColor,
  ) {
    final isSelected = activePreset == presetKey;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            appState.setMotionPreset(presetKey);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0x3DFFFFFF) : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? activeAccent : textColor.withOpacity(0.55),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? textColor : textColor.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioEngineSubPage(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('subpage_audio_engine'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubPageHeader(
            title: 'Audio Engine & Detection',
            subtitle: 'Hardware decoding pipeline, visualizer & detection rules',
            onBack: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = null);
            },
            textColor: textColor,
            subTextColor: subTextColor,
            activeAccent: activeAccent,
            isDark: isDark,
          ),

          // 1. HARDWARE DSP DECODER PIPELINE
          buildSectionHeader('Hardware DSP Decoder Pipeline', subTextColor),
          ExpressiveGroup(
            rowCount: 2,
            itemBuilder: (context, index, position) {
              if (index == 0) {
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
              } else {
                return ExpressiveGroupRow(
                  icon: Icons.auto_graph_rounded,
                  iconColor: activeAccent,
                  iconBgColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                  title: 'Sound Stage Visualizer',
                  subtitle: 'Purity stage style for inspected tracks',
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
              }
            },
          ),

          const SizedBox(height: 16),

          // 2. TACTILE HAPTICS
          buildSectionHeader('Tactile Feedback', subTextColor),
          ExpressiveGroup(
            rowCount: 1,
            itemBuilder: (context, index, position) {
              return ExpressiveGroupRow(
                icon: Icons.vibration_rounded,
                iconColor: const Color(0xFFA78BFA),
                iconBgColor: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
                title: 'Tactile Haptics',
                subtitle: 'Vibrate lightly on tab switches, tune scrubbers and interactions',
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
            },
          ),

          const SizedBox(height: 16),

          // 3. LOSSLESS DETECTION RULES & CRITERIA
          buildSectionHeader('Lossless Verification Engine', subTextColor),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0x24FFFFFF) : const Color(0x16000000),
                width: 0.85,
              ),
            ),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(18),
              style: GlassStyle.frosted,
              borderless: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_rounded, color: AppColors.genuineEmerald, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AcoustiQ Forensic Purity Standard',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '1. Full Ultrasonic Reach (>20 kHz):\nVerifies harmonic energy above human hearing limit. Lossy MP3s hard-cutoff sharply at 16 kHz or 20 kHz.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: subTextColor, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '2. Brickwall Shelf Detection:\nIdentifies telltale horizontal spectral cutoffs indicating fraudulent upsampled lossy files packed in FLAC containers.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: subTextColor, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '3. Continuous Dynamic Scoring (10% - 99%):\nHolistic mathematical scoring across spectral density, frequency ceiling, and high-frequency content.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: subTextColor, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrarySubPage(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('subpage_library_storage'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubPageHeader(
            title: 'Library & Storage',
            subtitle: 'Index FLAC audio files, manage paths & cache storage',
            onBack: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = null);
            },
            textColor: textColor,
            subTextColor: subTextColor,
            activeAccent: activeAccent,
            isDark: isDark,
          ),

          // 1. AUDIO LIBRARY STATUS
          buildSectionHeader('Indexed Audio Library', subTextColor),
          ExpressiveGroup(
            rowCount: 2,
            itemBuilder: (context, index, position) {
              if (index == 0) {
                return ExpressiveGroupRow(
                  icon: Icons.library_music_rounded,
                  iconColor: const Color(0xFFA78BFA),
                  iconBgColor: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
                  title: 'Audited Library',
                  subtitle: 'Verified FLAC tracks currently loaded in memory',
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
              } else {
                return ExpressiveGroupRow(
                  icon: Icons.folder_rounded,
                  iconColor: AppColors.suspiciousAmber,
                  iconBgColor: isDark ? const Color(0x30FFB300) : const Color(0xFFFEF3C7),
                  title: 'Source Music Directory',
                  subtitle: appState.lastScannedFolder ?? 'No folder scanned yet',
                  position: position,
                  trailing: null,
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // 2. FAST DEVICE AUDIT
          buildSectionHeader('Device Scan Tools', subTextColor),
          ExpressiveGroup(
            rowCount: 1,
            itemBuilder: (context, index, position) {
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
            },
          ),

          const SizedBox(height: 16),

          // 3. STORAGE & CACHE MAINTENANCE
          buildSectionHeader('Storage & Cache Maintenance', subTextColor),
          ExpressiveGroup(
            rowCount: 1,
            itemBuilder: (context, index, position) {
              return ExpressiveGroupRow(
                icon: Icons.delete_outline_rounded,
                title: 'Clear Library Cache',
                subtitle: 'Reset in-memory audited FLAC tracks and duplicate cache',
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSubPage(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color activeAccent,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('subpage_about_diagnostics'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubPageHeader(
            title: 'Diagnostics & About',
            subtitle: 'Engine build, hardware specs & QA Developer Lab',
            onBack: () {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              setState(() => _activeSubPageIndex = null);
            },
            textColor: textColor,
            subTextColor: subTextColor,
            activeAccent: activeAccent,
            isDark: isDark,
          ),

          // 1. ENGINE & BUILD INFO
          buildSectionHeader('Engine & Build', subTextColor),
          ExpressiveGroup(
            rowCount: appState.devModeEnabled ? 2 : 1,
            itemBuilder: (context, index, position) {
              if (index == 0) {
                return ExpressiveGroupRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  iconBgColor: isDark ? const Color(0x3038BDF8) : const Color(0xFFE0F2FE),
                  title: 'Engine Version',
                  subtitle: 'AcoustiQ Mobile • Build 62 (Sprint 3.4)',
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
                      'v1.1.0+62',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activeAccent,
                      ),
                    ),
                  ),
                );
              } else {
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

          const SizedBox(height: 16),

          // 2. HARDWARE & DECODER ARCHITECTURE
          buildSectionHeader('Hardware Architecture', subTextColor),
          ExpressiveGroup(
            rowCount: 2,
            itemBuilder: (context, index, position) {
              if (index == 0) {
                return ExpressiveGroupRow(
                  icon: Icons.developer_board_rounded,
                  iconColor: const Color(0xFFC084FC),
                  iconBgColor: isDark ? const Color(0x30C084FC) : const Color(0xFFF3E8FF),
                  title: 'DSP Execution Target',
                  subtitle: 'Arm64-v8a • Native C++ libflac + Flutter Skia Engine',
                  position: position,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NEON SIMD',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              } else {
                return ExpressiveGroupRow(
                  icon: Icons.speed_rounded,
                  iconColor: AppColors.genuineEmerald,
                  iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                  title: 'Continuous STFT Engine',
                  subtitle: '262k sample continuous window with 96x96 Bilinear Mesh',
                  position: position,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'GPU TEXTURE',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.genuineEmerald,
                      ),
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // 3. PRIVACY & LOCAL-FIRST GUARANTEE
          buildSectionHeader('Privacy & Integrity', subTextColor),
          ExpressiveGroup(
            rowCount: 1,
            itemBuilder: (context, index, position) {
              return ExpressiveGroupRow(
                icon: Icons.verified_user_rounded,
                iconColor: AppColors.genuineEmerald,
                iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                title: 'Local-First Analysis',
                subtitle: '100% on-device audio decoding. Zero cloud telemetry or tracking.',
                position: position,
                trailing: Icon(Icons.lock_outline_rounded, color: AppColors.genuineEmerald, size: 18),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Sleek Studio Accent Color Grid (Clean Swatches, Zero Waveform Clutter)
  Widget _buildAccentColorGrid(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final presets = [
      (
        id: 'Cyan',
        title: 'Cyan',
        subtitle: 'Cool Electric',
        color: const Color(0xFF00E5FF),
      ),
      (
        id: 'Amber',
        title: 'Amber',
        subtitle: 'Warm Golden',
        color: const Color(0xFFFF9500),
      ),
      (
        id: 'Emerald',
        title: 'Emerald',
        subtitle: 'Fresh Studio',
        color: const Color(0xFF00E676),
      ),
      (
        id: 'Violet',
        title: 'Violet',
        subtitle: 'Vivid Hi-Res',
        color: const Color(0xFF8B5CF6),
      ),
      (
        id: 'Crimson',
        title: 'Crimson',
        subtitle: 'Dynamic Energy',
        color: const Color(0xFFFF3B30),
      ),
      (
        id: 'Monochrome',
        title: 'Monochrome',
        subtitle: 'Clean Contrast',
        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      ),
    ];

    final currentPreset = appState.accentPreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2-Column Clean Swatch Grid
        for (int r = 0; r < presets.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAccentColorCard(
                  context: context,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  id: presets[r].id,
                  title: presets[r].title,
                  subtitle: presets[r].subtitle,
                  color: presets[r].color,
                  isSelected: currentPreset == presets[r].id ||
                      (presets[r].id == 'Cyan' && (currentPreset == 'Prism Cyan' || currentPreset == 'Ocean')) ||
                      (presets[r].id == 'Amber' && (currentPreset == 'Analog Amber')) ||
                      (presets[r].id == 'Emerald' && (currentPreset == 'Acoustic Emerald' || currentPreset == 'Sage')) ||
                      (presets[r].id == 'Violet' && (currentPreset == 'Ultraviolet Hi-Res')) ||
                      (presets[r].id == 'Crimson' && (currentPreset == 'Crimson Peak')) ||
                      (presets[r].id == 'Monochrome' && (currentPreset == 'Titanium Mono' || currentPreset == 'Mono')),
                  onSelect: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset(presets[r].id);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAccentColorCard(
                  context: context,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  id: presets[r + 1].id,
                  title: presets[r + 1].title,
                  subtitle: presets[r + 1].subtitle,
                  color: presets[r + 1].color,
                  isSelected: currentPreset == presets[r + 1].id ||
                      (presets[r + 1].id == 'Cyan' && (currentPreset == 'Prism Cyan' || currentPreset == 'Ocean')) ||
                      (presets[r + 1].id == 'Amber' && (currentPreset == 'Analog Amber')) ||
                      (presets[r + 1].id == 'Emerald' && (currentPreset == 'Acoustic Emerald' || currentPreset == 'Sage')) ||
                      (presets[r + 1].id == 'Violet' && (currentPreset == 'Ultraviolet Hi-Res')) ||
                      (presets[r + 1].id == 'Crimson' && (currentPreset == 'Crimson Peak')) ||
                      (presets[r + 1].id == 'Monochrome' && (currentPreset == 'Titanium Mono' || currentPreset == 'Mono')),
                  onSelect: () {
                    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                    appState.setAccentPreset(presets[r + 1].id);
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        // Master Card: Custom Color (Inline Chromatic Tuner)
        _CustomColorCard(
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          isSelected: currentPreset == 'Custom' || currentPreset == 'Custom Resonance' || currentPreset == 'Custom Color',
          customColor: appState.customColor,
          onSelect: () {
            if (appState.hapticsEnabled) HapticFeedback.selectionClick();
            appState.setAccentPreset('Custom');
          },
        ),
      ],
    );
  }

  Widget _buildAccentColorCard({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required String id,
    required String title,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSelect,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: AppColors.getOnAccentColor(color, isDark: isDark),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? textColor : textColor.withOpacity(0.9),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? color : subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _CustomColorCard extends StatefulWidget {
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final bool isSelected;
  final Color customColor;
  final VoidCallback onSelect;

  const _CustomColorCard({
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    required this.isSelected,
    required this.customColor,
    required this.onSelect,
  });

  @override
  State<_CustomColorCard> createState() => _CustomColorCardState();
}

class _CustomColorCardState extends State<_CustomColorCard> {
  bool _isExpanded = false;
  late double _currentHue;

  static const swatches = [
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

  @override
  void initState() {
    super.initState();
    _currentHue = HSVColor.fromColor(widget.customColor).hue;
  }

  @override
  void didUpdateWidget(covariant _CustomColorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected && _isExpanded) {
      _isExpanded = false;
    }
    if (oldWidget.customColor != widget.customColor) {
      final fromColorHue = HSVColor.fromColor(widget.customColor).hue;
      if ((fromColorHue - _currentHue).abs() > 2.0) {
        _currentHue = fromColorHue;
      }
    }
  }

  Widget _buildSwatchItem(Color c) {
    final isSelected = widget.customColor.value == c.value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
          appState.setAccentPreset('Custom', c);
          setState(() {
            _currentHue = HSVColor.fromColor(c).hue;
          });
        },
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
              width: isSelected ? 2.0 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.withOpacity(0.55),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Center(
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hexStr = '#${widget.customColor.value.toRadixString(16).substring(2).toUpperCase()}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? widget.customColor.withOpacity(widget.isDark ? 0.9 : 0.8)
                : (widget.isDark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
            width: widget.isSelected ? 1.5 : 0.85,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: widget.customColor.withOpacity(widget.isDark ? 0.22 : 0.12),
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
          tintColor: widget.isSelected
              ? widget.customColor.withOpacity(widget.isDark ? 0.16 : 0.08)
              : null,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onSelect,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: widget.customColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.customColor.withOpacity(0.40),
                                  blurRadius: widget.isSelected ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: widget.isSelected
                                ? Center(
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 17,
                                      color: AppColors.getOnAccentColor(
                                        widget.customColor,
                                        isDark: widget.isDark,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Custom Color',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isSelected
                                        ? widget.textColor
                                        : widget.textColor.withOpacity(0.9),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: widget.customColor.withOpacity(widget.isDark ? 0.20 : 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        hexStr,
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: widget.customColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _isExpanded ? 'Adjust hue below' : 'Tap Tune to adjust',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: widget.subTextColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Tune / Done Button Pill
                  GestureDetector(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                      if (!widget.isSelected) {
                        widget.onSelect();
                      }
                      setState(() {
                        _isExpanded = !_isExpanded;
                        _currentHue = HSVColor.fromColor(widget.customColor).hue;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: widget.customColor.withOpacity(widget.isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: widget.customColor.withOpacity(0.4),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isExpanded ? Icons.check_rounded : Icons.palette_outlined,
                            size: 13,
                            color: widget.customColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded ? 'DONE' : 'TUNE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: widget.isDark ? Colors.white : widget.customColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Smooth inline expansion
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: _isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            color: widget.isDark
                                ? const Color(0x22FFFFFF)
                                : const Color(0x14000000),
                          ),
                          Text(
                            'CURATED PALETTE PRESETS',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: widget.subTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (int i = 0; i < 6; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(child: _buildSwatchItem(swatches[i])),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (int i = 6; i < 12; i++) ...[
                                if (i > 6) const SizedBox(width: 8),
                                Expanded(child: _buildSwatchItem(swatches[i])),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SPECTRUM HUE',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: widget.subTextColor,
                                ),
                              ),
                              Text(
                                hexStr,
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: widget.customColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
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
                                trackHeight: 30,
                                activeTrackColor: Colors.transparent,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                  elevation: 3,
                                ),
                                overlayColor: Colors.transparent,
                                mouseCursor: const MaterialStatePropertyAll(
                                  SystemMouseCursors.click,
                                ),
                              ),
                              child: Slider(
                                value: _currentHue.clamp(0.0, 360.0),
                                min: 0.0,
                                max: 360.0,
                                onChanged: (val) {
                                  setState(() => _currentHue = val);
                                  final newCol = HSVColor.fromAHSV(
                                    1.0,
                                    val,
                                    0.85,
                                    0.95,
                                  ).toColor();
                                  appState.setAccentPreset('Custom', newCol);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
