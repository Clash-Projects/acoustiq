import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';

/// 1:1 Port of LastWave's Expressive Settings Screen Architecture
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

        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Appearance Section Header
              _buildSectionHeader('APPEARANCE & VISUALS', subTextColor),
              const SizedBox(height: 8),

              // Theme Mode Selector Card (28dp Outer Radius)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
                  borderRadius: ExpressiveShapes.heroInner,
                  border: Border.all(
                    color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                    width: 0.5,
                  ),
                  boxShadow: AppColors.softElevation(elevation: 3.0),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withOpacity(isDark ? 0.20 : 0.14),
                            borderRadius: ExpressiveShapes.artwork,
                          ),
                          child: const Icon(Icons.palette_rounded, color: AppColors.accentPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Appearance',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Obsidian AMOLED dark or porcelain light look',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildThemeOption(context, 'System', Icons.brightness_auto_rounded, 'system'),
                        const SizedBox(width: 8),
                        _buildThemeOption(context, 'Light', Icons.light_mode_rounded, 'light'),
                        const SizedBox(width: 8),
                        _buildThemeOption(context, 'Dark', Icons.dark_mode_rounded, 'dark'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Connected Settings Group (Visuals & Haptics)
              _buildConnectedGroup(
                isDark: isDark,
                items: [
                  (
                    icon: Icons.blur_on_rounded,
                    title: 'Frosted Liquid Glass',
                    subtitle: 'Translucent optical diffusion across dock & cards',
                    trailing: Switch.adaptive(
                      value: appState.isLiquidGlass,
                      activeColor: AppColors.accentPrimary,
                      onChanged: (val) => appState.setLiquidGlass(val),
                    ),
                  ),
                  (
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    subtitle: 'Tactile selection clicks on tab transitions',
                    trailing: Switch.adaptive(
                      value: appState.hapticsEnabled,
                      activeColor: AppColors.accentPrimary,
                      onChanged: (val) => appState.setHaptics(val),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Audio Engine Section Header
              _buildSectionHeader('AUDIO ENGINE & HEURISTICS', subTextColor),
              const SizedBox(height: 8),

              _buildConnectedGroup(
                isDark: isDark,
                items: [
                  (
                    icon: Icons.memory_rounded,
                    title: 'Core Parser Engine',
                    subtitle: 'Native Dart 64-Bit Binary FLAC Stream Decoder',
                    trailing: null,
                  ),
                  (
                    icon: Icons.graphic_eq_rounded,
                    title: 'Nyquist Heuristics',
                    subtitle: 'High-Frequency Roll-Off & Spectral Threshold Test',
                    trailing: null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Library Cache Section Header
              _buildSectionHeader('LIBRARY CACHE', subTextColor),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
                  borderRadius: ExpressiveShapes.heroInner,
                  border: Border.all(
                    color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                    width: 0.5,
                  ),
                  boxShadow: AppColors.softElevation(elevation: 3.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${appState.sharedLibrary.length} Scanned Tracks',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appState.lastScannedFolder != null
                              ? 'From ${appState.lastScannedFolder!.split("/").last}'
                              : 'No folder scanned',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                    if (appState.sharedLibrary.isNotEmpty)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.fakeCoral,
                          side: BorderSide(color: AppColors.fakeCoral.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: ExpressiveShapes.badgePill),
                        ),
                        onPressed: () {
                          appState.setSharedLibrary([], '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Scanned library cleared')),
                          );
                        },
                        child: const Text('Clear', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. About & Version Section
              _buildSectionHeader('ABOUT & SYSTEM', subTextColor),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
                  borderRadius: ExpressiveShapes.heroInner,
                  border: Border.all(
                    color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                    width: 0.5,
                  ),
                  boxShadow: AppColors.softElevation(elevation: 3.0),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Version',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withOpacity(isDark ? 0.20 : 0.14),
                            borderRadius: ExpressiveShapes.badgePill,
                            border: Border.all(color: AppColors.accentPrimary.withOpacity(0.35), width: 0.5),
                          ),
                          child: const Text(
                            'v1.1.0 (Build 10)',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: isDark ? Colors.white10 : Colors.black12, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Design Architecture',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                        Text(
                          '1:1 LastWave Native Design',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildConnectedGroup({
    required bool isDark,
    required List<({IconData icon, String title, String subtitle, Widget? trailing})> items,
  }) {
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final position = items.length == 1
            ? GroupPosition.single
            : (i == 0
                ? GroupPosition.top
                : (i == items.length - 1 ? GroupPosition.bottom : GroupPosition.middle));

        return Padding(
          padding: const EdgeInsets.only(bottom: 3), // 3dp GROUP_GAP matching LastWave
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainer : AppColors.lightSurface,
              borderRadius: groupShape(position),
              border: Border.all(
                color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh,
                    borderRadius: ExpressiveShapes.artwork,
                  ),
                  child: Icon(item.icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? const Color(0xB3FFFFFF) : const Color(0x99000000),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.trailing != null) item.trailing!,
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, IconData icon, String value) {
    final isSelected = appState.themeMode == value;
    final isDark = appState.isCurrentDark(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => appState.setThemeMode(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentPrimary.withOpacity(isDark ? 0.20 : 0.16)
                : (isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHigh),
            borderRadius: ExpressiveShapes.statPill,
            border: Border.all(
              color: isSelected ? AppColors.accentPrimary : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.accentPrimary
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.accentPrimary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
