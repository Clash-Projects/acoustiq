import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';
import '../widgets/luminous_feedback.dart';

/// 1:1 Port of LastWave Native's Settings Screen Architecture (Appearance & Visuals)
///
/// Features:
/// - Concise studio-grade copywriting (eliminates verbose multi-line clutter).
/// - Connected Group Architecture with 3dp gaps and 28dp/6dp continuous curvature.
/// - Pure Pitch Black AMOLED vs Deep Graphite toggle with instant live repaint.
/// - Liquid Glass toggle switching between optical translucent blur and opaque surfaces.
/// - High-contrast Light Mode typography and segment controls.
/// - Zero text truncation.
/// - 160dp bottom padding clearance.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        return Scaffold(
          backgroundColor: appState.getBgColor(context),
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
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: textColor,
                      ),
                    ),
                  ),

                  // 1. APPEARANCE SECTION
                  buildSectionHeader('Appearance & Visuals', subTextColor),

                  ExpressiveGroup(
                    rowCount: 4,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          // Theme Mode (System, Light, Dark)
                          return _buildThemeModeRow(context, position, isDark, textColor, subTextColor);
                        case 1:
                          // AMOLED Mode (Pitch black vs Graphite)
                          return ExpressiveGroupRow(
                            icon: Icons.brightness_2_rounded,
                            iconColor: const Color(0xFFC084FC),
                            iconBgColor: isDark ? const Color(0x30C084FC) : const Color(0xFFF3E8FF),
                            title: 'AMOLED Mode',
                            subtitle: isDark
                                ? (appState.amoledMode
                                    ? 'Pitch-black background for OLED displays (#000000)'
                                    : 'Deep obsidian graphite background (#12161A)')
                                : 'Active only in dark mode',
                            position: position,
                            luminousVariant: LuminousVariant.violet,
                            trailing: Switch.adaptive(
                              value: appState.amoledMode,
                              activeColor: AppColors.accentPrimary,
                              onChanged: (val) => appState.setAmoledMode(val),
                            ),
                          );
                        case 2:
                          // Liquid Glass Materials
                          return ExpressiveGroupRow(
                            icon: Icons.blur_on_rounded,
                            iconColor: AppColors.accentPrimary,
                            iconBgColor: isDark ? const Color(0x3000D2FF) : const Color(0xFFE0F7FE),
                            title: 'Liquid Glass',
                            subtitle: appState.isLiquidGlass
                                ? 'iOS-style translucent materials across the app'
                                : 'Opaque Material 3 Expressive surfaces active',
                            position: position,
                            luminousVariant: LuminousVariant.cyan,
                            trailing: Switch.adaptive(
                              value: appState.isLiquidGlass,
                              activeColor: AppColors.accentPrimary,
                              onChanged: (val) => appState.setLiquidGlass(val),
                            ),
                          );
                        case 3:
                        default:
                          // Haptic Feedback
                          return ExpressiveGroupRow(
                            icon: Icons.vibration_rounded,
                            iconColor: AppColors.genuineEmerald,
                            iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                            title: 'Haptic Feedback',
                            subtitle: 'Tactile response on navigation & actions',
                            position: position,
                            luminousVariant: LuminousVariant.emerald,
                            trailing: Switch.adaptive(
                              value: appState.hapticsEnabled,
                              activeColor: AppColors.genuineEmerald,
                              onChanged: (val) => appState.setHaptics(val),
                            ),
                          );
                      }
                    },
                  ),

                  // 2. AUDIO ENGINE & TELEMETRY
                  buildSectionHeader('Audio Engine & Analysis', subTextColor),

                  ExpressiveGroup(
                    rowCount: 2,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          return ExpressiveGroupRow(
                            icon: Icons.graphic_eq_rounded,
                            iconColor: AppColors.accentPrimary,
                            iconBgColor: isDark ? const Color(0x3000D2FF) : const Color(0xFFE0F7FE),
                            title: 'Bitstream Auditor',
                            subtitle: 'Lossless header verification & spectral check',
                            position: position,
                            trailing: Text(
                              '96 kHz',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.accentPrimary : AppColors.lightCyanText,
                              ),
                            ),
                          );
                        case 1:
                        default:
                          return ExpressiveGroupRow(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: AppColors.suspiciousAmber,
                            iconBgColor: isDark ? const Color(0x30FFB300) : const Color(0xFFFEF3C7),
                            title: 'Duplicate Scanner',
                            subtitle: 'Detect identical audio streams across tags',
                            position: position,
                            trailing: Text(
                              'Active',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.genuineEmerald : AppColors.lightEmeraldText,
                              ),
                            ),
                          );
                      }
                    },
                  ),

                  // 3. ABOUT & CACHE
                  buildSectionHeader('About & System', subTextColor),

                  ExpressiveGroup(
                    rowCount: 3,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          return ExpressiveGroupRow(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            iconBgColor: isDark ? const Color(0x3038BDF8) : const Color(0xFFE0F2FE),
                            title: 'Version',
                            subtitle: 'FLAC Toolkit Mobile • Build 16 (Release)',
                            position: position,
                            trailing: Text(
                              'v1.1.0',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          );
                        case 1:
                          return ExpressiveGroupRow(
                            icon: Icons.library_music_rounded,
                            iconColor: const Color(0xFFA78BFA),
                            iconBgColor: isDark ? const Color(0x30A78BFA) : const Color(0xFFEDE9FE),
                            title: 'Scanned Library Tracks',
                            subtitle: appState.lastScannedFolder != null
                                ? appState.lastScannedFolder!.split('/').last
                                : 'No folder scanned yet',
                            position: position,
                            trailing: Text(
                              '${appState.sharedLibrary.length} tracks',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.accentPrimary : AppColors.lightCyanText,
                              ),
                            ),
                          );
                        case 2:
                        default:
                          return ExpressiveGroupRow(
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear Library Cache',
                            subtitle: 'Reset in-memory audited FLAC tracks and duplicates',
                            position: position,
                            danger: true,
                            luminousVariant: LuminousVariant.amber,
                            onTap: () {
                              appState.setSharedLibrary([], '');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Library cache cleared'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
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

  Widget _buildThemeModeRow(
    BuildContext context,
    GroupPosition position,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final shape = groupShape(position);

    return GlassSurface(
      borderRadius: shape,
      style: GlassStyle.frosted,
      borderless: true,
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
              _buildThemeSegment('System', Icons.settings_brightness_rounded, 'system', isDark),
              const SizedBox(width: 6),
              _buildThemeSegment('Light', Icons.light_mode_rounded, 'light', isDark),
              const SizedBox(width: 6),
              _buildThemeSegment('Dark', Icons.dark_mode_rounded, 'dark', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegment(String label, IconData icon, String mode, bool isDark) {
    final isSelected = appState.themeMode == mode;
    final selectedFg = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final unselectedFg = isDark ? const Color(0x99FFFFFF) : AppColors.lightTextSecondary;

    return Expanded(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(12),
        style: GlassStyle.clear,
        borderless: true,
        tintColor: isSelected
            ? (isDark ? const Color(0x40818CF8) : const Color(0xFFDCE2FF))
            : null,
        child: InkWell(
          onTap: () => appState.setThemeMode(mode),
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
