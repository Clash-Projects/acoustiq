import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../widgets/glass_card.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Appearance Section Header
              _buildSectionHeader('APPEARANCE & VISUALS', subTextColor),
              const SizedBox(height: 8),

              // Theme Mode Selector Card
              GlassCard(
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2FF).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.palette_rounded, color: Color(0xFF00D2FF), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Mode',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              'Choose system, light, or dark look',
                              style: TextStyle(fontSize: 11, color: subTextColor),
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

              // Toggles Group
              GlassCard(
                borderRadius: 20,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSwitchTile(
                      context,
                      icon: Icons.contrast_rounded,
                      title: 'AMOLED Mode',
                      subtitle: 'Pure pitch black background (#000000)',
                      value: appState.isAmoled,
                      onChanged: (val) => appState.setAmoled(val),
                    ),
                    Divider(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), height: 1),
                    _buildSwitchTile(
                      context,
                      icon: Icons.blur_on_rounded,
                      title: 'Liquid Glass',
                      subtitle: 'iOS-style translucent materials across the app',
                      value: appState.isLiquidGlass,
                      onChanged: (val) => appState.setLiquidGlass(val),
                    ),
                    Divider(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), height: 1),
                    _buildSwitchTile(
                      context,
                      icon: Icons.vibration_rounded,
                      title: 'Haptic Feedback',
                      subtitle: 'Tactile vibration on tab slide & actions',
                      value: appState.hapticsEnabled,
                      onChanged: (val) => appState.setHaptics(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Audio Engine Section Header
              _buildSectionHeader('AUDIO ANALYSIS ENGINE', subTextColor),
              const SizedBox(height: 8),

              GlassCard(
                borderRadius: 20,
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Core Engine', 'Native Dart 64-Bit Binary Parser'),
                    Divider(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), height: 20),
                    _buildInfoRow(context, 'Cutoff Heuristic', 'Spectral Frequency Roll-off Analysis'),
                    Divider(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), height: 20),
                    _buildInfoRow(context, 'Release Version', 'v1.1.0 (Build 2)'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Library Cache Section Header
              _buildSectionHeader('LIBRARY CACHE', subTextColor),
              const SizedBox(height: 8),

              GlassCard(
                borderRadius: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${appState.sharedLibrary.length} Scanned Tracks',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appState.lastScannedFolder != null
                              ? 'From ${appState.lastScannedFolder!.split("/").last}'
                              : 'No folder scanned',
                          style: TextStyle(fontSize: 11, color: subTextColor),
                        ),
                      ],
                    ),
                    if (appState.sharedLibrary.isNotEmpty)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF3D3D),
                          side: BorderSide(color: const Color(0xFFFF3D3D).withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          appState.setSharedLibrary([], '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Scanned library cleared')),
                          );
                        },
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),

              // CRITICAL: 140px Bottom buffer so floating nav bar NEVER collides
              const SizedBox(height: 140),
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.1,
        ),
      ),
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
                ? const Color(0xFF00D2FF).withOpacity(0.18)
                : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF00D2FF) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF00D2FF) : (isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF00D2FF) : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: subTextColor),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF00D2FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: subTextColor)),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor)),
      ],
    );
  }
}

