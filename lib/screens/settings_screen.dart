import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';

/// 1:1 Port of LastWave Native's Settings Screen Architecture (Appearance & Visuals)
///
/// Features:
/// - True Connected Group Architecture with 3dp gaps and 28dp/6dp continuous curvature.
/// - Pure Pitch Black AMOLED background with zero white border outlines.
/// - 140dp bottom padding clearance ensuring the floating dock never obscures settings.
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
          backgroundColor: isDark ? AppColors.amoledCanvas : AppColors.lightCanvas,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
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
                          // AMOLED Mode (Pitch black substrate)
                          return ExpressiveGroupRow(
                            icon: Icons.brightness_2_rounded,
                            iconColor: const Color(0xFFC084FC),
                            iconBgColor: isDark ? const Color(0xFF261D36) : const Color(0xFFF3E8FF),
                            title: 'AMOLED Mode',
                            subtitle: 'Pure pitch-black substrate (Dark mode only)',
                            position: position,
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
                            iconBgColor: isDark ? const Color(0xFF162B38) : const Color(0xFFE0F7FE),
                            title: 'Liquid Glass',
                            subtitle: '3D optical lens & visionOS translucent materials',
                            position: position,
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
                            iconBgColor: isDark ? const Color(0xFF142B1F) : const Color(0xFFDCFCE7),
                            title: 'Haptic Feedback',
                            subtitle: 'Tactile spring clicks on dock transitions & actions',
                            position: position,
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
                            iconBgColor: isDark ? const Color(0xFF162B38) : const Color(0xFFE0F7FE),
                            title: 'Bitstream Auditor',
                            subtitle: 'Lossless header verification & spectral Nyquist check',
                            position: position,
                            trailing: Text(
                              '96 kHz',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          );
                        case 1:
                        default:
                          return ExpressiveGroupRow(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: AppColors.suspiciousAmber,
                            iconBgColor: isDark ? const Color(0xFF332714) : const Color(0xFFFEF3C7),
                            title: 'Auto-scan Duplicate Hashes',
                            subtitle: 'Detect identical audio streams with mismatched tags',
                            position: position,
                            trailing: Text(
                              'Active',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.genuineEmerald,
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
                            iconBgColor: isDark ? const Color(0xFF132A38) : const Color(0xFFE0F2FE),
                            title: 'Version',
                            subtitle: 'FLAC Toolkit Mobile • Build 11 (Release)',
                            position: position,
                            trailing: Text(
                              'v1.1.0',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: subTextColor,
                              ),
                            ),
                          );
                        case 1:
                          return ExpressiveGroupRow(
                            icon: Icons.library_music_rounded,
                            iconColor: const Color(0xFFA78BFA),
                            iconBgColor: isDark ? const Color(0xFF261D3B) : const Color(0xFFEDE9FE),
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
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                          );
                        case 2:
                        default:
                          return ExpressiveGroupRow(
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear Scanned Library Cache',
                            subtitle: 'Reset in-memory audited FLAC tracks and duplicates',
                            position: position,
                            danger: true,
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
    final rowBg = isDark ? AppColors.surfaceContainer : AppColors.lightSurface;

    return Material(
      color: rowBg,
      borderRadius: shape,
      child: Padding(
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
                    color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    size: 22,
                    color: Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
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
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Segmented Button Row (Matching LastWave_3.png)
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
      ),
    );
  }

  Widget _buildThemeSegment(String label, IconData icon, String mode, bool isDark) {
    final isSelected = appState.themeMode == mode;
    final selectedBg = isDark ? const Color(0xFF283548) : const Color(0xFFE0E7FF);
    final selectedFg = isDark ? Colors.white : const Color(0xFF3730A3);

    final unselectedBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F1F4);
    final unselectedFg = isDark ? const Color(0x99FFFFFF) : const Color(0x99000000);

    return Expanded(
      child: Material(
        color: isSelected ? selectedBg : unselectedBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => appState.setThemeMode(mode),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 38,
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
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
