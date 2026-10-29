import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.themeMode != 'light';
        final bgColor = appState.isAmoled
            ? const Color(0xFF07090E)
            : const Color(0xFF121622);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.2,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Appearance & Visuals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Theme Selector Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Theme',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose dark or system appearance',
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildThemeOption('System', Icons.brightness_auto_rounded, 'system'),
                              const SizedBox(width: 8),
                              _buildThemeOption('Light', Icons.light_mode_rounded, 'light'),
                              const SizedBox(width: 8),
                              _buildThemeOption('Dark', Icons.dark_mode_rounded, 'dark'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Toggles Group
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            icon: Icons.contrast_rounded,
                            title: 'AMOLED Mode',
                            subtitle: 'Pure black background (#000000)',
                            value: appState.isAmoled,
                            onChanged: (val) => appState.setAmoled(val),
                          ),
                          Divider(color: Colors.white.withOpacity(0.06), height: 1),
                          _buildSwitchTile(
                            icon: Icons.blur_on_rounded,
                            title: 'Liquid Glass',
                            subtitle: 'iOS-style refractive translucent materials',
                            value: appState.isLiquidGlass,
                            onChanged: (val) => appState.setLiquidGlass(val),
                          ),
                          Divider(color: Colors.white.withOpacity(0.06), height: 1),
                          _buildSwitchTile(
                            icon: Icons.vibration_rounded,
                            title: 'Haptic Feedback',
                            subtitle: 'Tactile vibration on tab slide & actions',
                            value: appState.hapticsEnabled,
                            onChanged: (val) => appState.setHaptics(val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'FLAC Toolkit • Native Flutter 64-Bit Core',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(String label, IconData icon, String value) {
    final isSelected = appState.themeMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => appState.setThemeMode(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00D2FF).withOpacity(0.2) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF00D2FF) : Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF00D2FF) : Colors.white60),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.5)),
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
}
