import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/shape.dart';
import '../widgets/expressive_group.dart';
import '../widgets/glass_surface.dart';

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

                  // 2. THEME & GLASS MATERIALS
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
                            title: 'Liquid Glass',
                            subtitle: appState.isLiquidGlass
                                ? 'Apple WWDC25 Gaussian blur & optical caustics'
                                : 'Opaque Material 3 Expressive surfaces active',
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

                  // 3. EXPERIMENTAL & INTERACTION
                  buildSectionHeader('Experimental & Physics', subTextColor),
                  ExpressiveGroup(
                    rowCount: 3,
                    itemBuilder: (context, index, position) {
                      switch (index) {
                        case 0:
                          // Haptic Feedback
                          return ExpressiveGroupRow(
                            icon: Icons.vibration_rounded,
                            iconColor: AppColors.genuineEmerald,
                            iconBgColor: isDark ? const Color(0x3000E676) : const Color(0xFFDCFCE7),
                            title: 'Haptic Feedback',
                            subtitle: 'Tactile spring clicks on dock glide & actions',
                            position: position,
                            trailing: Switch.adaptive(
                              value: appState.hapticsEnabled,
                              activeColor: AppColors.genuineEmerald,
                              onChanged: (val) => appState.setHaptics(val),
                            ),
                          );
                        case 1:
                          // High-Precision Forensic Analyzer
                          return ExpressiveGroupRow(
                            icon: Icons.graphic_eq_rounded,
                            iconColor: activeAccent,
                            iconBgColor: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                            title: 'Forensic Spectrum Stage',
                            subtitle: '2D Nyquist shelf curve with brickwall cutoff detector',
                            position: position,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: activeAccent.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: activeAccent,
                                ),
                              ),
                            ),
                          );
                        case 2:
                        default:
                          // Duplicate FLAC Auto-Marking
                          return ExpressiveGroupRow(
                            icon: Icons.copy_all_rounded,
                            iconColor: AppColors.suspiciousAmber,
                            iconBgColor: isDark ? const Color(0x30FFB300) : const Color(0xFFFEF3C7),
                            title: 'Duplicate FLAC Engine',
                            subtitle: 'Auto-identify and rank pure audio vs lossy upscales',
                            position: position,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.genuineEmerald.withOpacity(isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ON',
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

                  // 4. ABOUT & STORAGE
                  buildSectionHeader('System & Storage', subTextColor),
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
                            subtitle: 'FLAC Toolkit Mobile • Build 18 (Release)',
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
                            title: 'Audited Library',
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
                                color: activeAccent,
                              ),
                            ),
                          );
                        case 2:
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Library cache cleared successfully'),
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
    return GestureDetector(
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
                          color: shades.last.withOpacity(0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
    return GestureDetector(
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
                          color: (bg ?? const Color(0xFFE03030)).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
