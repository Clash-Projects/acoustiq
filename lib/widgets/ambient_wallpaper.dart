import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 1:1 Ambient Glass Wallpaper & Environment Engine
///
/// Renders an atmospheric lightfield behind all screens and floating glass docks.
/// On AMOLED screens, uniform #000000 has zero optical variance, rendering blur
/// mathematically invisible (Blur(0,0,0) = (0,0,0)). This engine provides physical
/// chromatic gradients and custom user images so that Gaussian blur, specular rims,
/// and liquid caustics have real photons to refract.
class AmbientWallpaperView extends StatelessWidget {
  const AmbientWallpaperView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final preset = appState.wallpaperPreset;

        if (preset == 'custom' && appState.customWallpaperPath != null) {
          final file = File(appState.customWallpaperPath!);
          if (file.existsSync()) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Base user wallpaper
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildNebulaMesh(isDark),
                ),
                // Soft Scrim for AAA Text Readability & Specular Rim Contrast
                Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.48)
                      : Colors.white.withOpacity(0.65),
                ),
              ],
            );
          }
        }

        switch (preset) {
          case 'abyss':
            return _buildAbyssMesh(isDark);
          case 'sunset':
            return _buildSunsetMesh(isDark);
          case 'pure_black':
            return _buildPureBlack(context, isDark);
          case 'nebula':
          default:
            return _buildNebulaMesh(isDark);
        }
      },
    );
  }

  Widget _buildPureBlack(BuildContext context, bool isDark) {
    final bg = appState.getBgColor(context);
    return Container(color: bg);
  }

  /// Preset 1: Obsidian Nebula
  /// Deep space cosmic violet & indigo lightfields
  Widget _buildNebulaMesh(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: isDark ? const Color(0xFF07080E) : const Color(0xFFF1F3F8),
        ),
        // Top-Right Cosmic Violet Glow
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, -0.65),
                radius: 1.35,
                colors: isDark
                    ? [
                        const Color(0xFF5A189A).withOpacity(0.45),
                        const Color(0xFF3C096C).withOpacity(0.25),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF9D4EDD).withOpacity(0.20),
                        const Color(0xFFC77DFF).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Bottom-Left Deep Indigo / Ocean Flare
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.85, 0.75),
                radius: 1.30,
                colors: isDark
                    ? [
                        const Color(0xFF0D47A1).withOpacity(0.40),
                        const Color(0xFF1565C0).withOpacity(0.20),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF42A5F5).withOpacity(0.20),
                        const Color(0xFF90CAF9).withOpacity(0.08),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),
        // Subtle Mid-field Electric Ambiance
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, 0.15),
                radius: 0.95,
                colors: isDark
                    ? [
                        const Color(0xFF7C4DFF).withOpacity(0.18),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFB388FF).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Preset 2: Emerald Abyss
  /// Oceanic deep teal & bioluminescent emerald glow
  Widget _buildAbyssMesh(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: isDark ? const Color(0xFF030A09) : const Color(0xFFF0FDF8),
        ),
        // Top-Left Bioluminescent Teal Bloom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.85, -0.65),
                radius: 1.35,
                colors: isDark
                    ? [
                        const Color(0xFF004D40).withOpacity(0.50),
                        const Color(0xFF00695C).withOpacity(0.25),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF00BFA5).withOpacity(0.22),
                        const Color(0xFF64FFDA).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Bottom-Right Deep Oceanic Blue
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, 0.75),
                radius: 1.30,
                colors: isDark
                    ? [
                        const Color(0xFF00363A).withOpacity(0.45),
                        const Color(0xFF01579B).withOpacity(0.22),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF26C6DA).withOpacity(0.20),
                        const Color(0xFF80DEEA).withOpacity(0.08),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),
        // Subtle Mint Shimmer
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.1, -0.1),
                radius: 0.90,
                colors: isDark
                    ? [
                        const Color(0xFF00E676).withOpacity(0.12),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF69F0AE).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Preset 3: Sunset Horizon
  /// Twilight dusk rose & warm ember flares
  Widget _buildSunsetMesh(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: isDark ? const Color(0xFF0D0609) : const Color(0xFFFFF1F4),
        ),
        // Top-Right Deep Magenta / Orchid Bloom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, -0.60),
                radius: 1.35,
                colors: isDark
                    ? [
                        const Color(0xFF880E4F).withOpacity(0.48),
                        const Color(0xFF4A148C).withOpacity(0.25),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFEC407A).withOpacity(0.22),
                        const Color(0xFFF48FB1).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Bottom-Left Ember Amber / Flame Flare
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.80, 0.70),
                radius: 1.30,
                colors: isDark
                    ? [
                        const Color(0xFFBF360C).withOpacity(0.42),
                        const Color(0xFFE65100).withOpacity(0.22),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFFF7043).withOpacity(0.20),
                        const Color(0xFFFFAB91).withOpacity(0.08),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),
        // Mid-field Rose Glow
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.15, 0.1),
                radius: 0.95,
                colors: isDark
                    ? [
                        const Color(0xFFE040FB).withOpacity(0.15),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFFF4081).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Miniature preview swatch for Settings Screen
  static Widget buildPreview(String preset, bool isDark) {
    switch (preset) {
      case 'abyss':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF004D40), Color(0xFF00363A), Color(0xFF001514)],
            ),
          ),
        );
      case 'sunset':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF880E4F), Color(0xFFBF360C), Color(0xFF1A0A10)],
            ),
          ),
        );
      case 'pure_black':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF000000),
            border: Border.all(
              color: const Color(0x33FFFFFF),
              width: 1,
            ),
          ),
        );
      case 'nebula':
      default:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF5A189A), Color(0xFF0D47A1), Color(0xFF0A0C16)],
            ),
          ),
        );
    }
  }
}
