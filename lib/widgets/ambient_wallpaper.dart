import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 1:1 Ambient Glass Wallpaper & Environment Engine
///
/// Renders an atmospheric lightfield behind all screens and floating glass docks.
/// Provides physical acoustic materials, chromatic gradients, and custom user images
/// so that Gaussian blur, specular rims, and liquid lenses have real photons to refract.
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
                      _buildSolidFallback(isDark),
                ),
                // Soft Scrim for AAA Text Readability & Specular Rim Contrast
                Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.40)
                      : Colors.white.withOpacity(0.60),
                ),
              ],
            );
          }
        }

        switch (preset) {
          case 'cloud':
            return _buildAssetWallpaper('assets/wallpapers/dusk_cloud.webp', isDark);
          case 'vinyl':
          case 'acoustic':
          case 'titanium':
            return _buildAssetWallpaper('assets/wallpapers/studio_vinyl.webp', isDark);
          case 'emerald':
          case 'abyss':
            return _buildAssetWallpaper('assets/wallpapers/misty_emerald.webp', isDark);
          case 'solid':
          case 'pure_black':
            return _buildPureBlack(context, isDark);
          default:
            return _buildAssetWallpaper('assets/wallpapers/dusk_cloud.webp', isDark);
        }
      },
    );
  }

  Widget _buildPureBlack(BuildContext context, bool isDark) {
    final bg = appState.getBgColor(context);
    return Container(color: bg);
  }

  Widget _buildSolidFallback(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F1218) : const Color(0xFFF1F5F9),
    );
  }

  /// Preset 1: Dusk Storm Cloud / Preset 2: Studio Vinyl / Preset 3: Misty Emerald
  /// Real-world environment photos with deep contrast and natural illumination.
  Widget _buildAssetWallpaper(String assetPath, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base photographic wallpaper asset
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) =>
              _buildSolidFallback(isDark),
        ),
        // Soft optical scrim ensuring AAA text contrast and specular rim definition
        Container(
          color: isDark
              ? Colors.black.withOpacity(0.36)
              : Colors.white.withOpacity(0.62),
        ),
      ],
    );
  }

  /// Miniature preview swatch for Settings Screen
  static Widget buildPreview(String preset, bool isDark) {
    switch (preset) {
      case 'cloud':
        return Image.asset(
          'assets/wallpapers/thumbs/dusk_cloud_thumb.webp',
          fit: BoxFit.cover,
        );
      case 'vinyl':
      case 'titanium':
      case 'acoustic':
        return Image.asset(
          'assets/wallpapers/thumbs/studio_vinyl_thumb.webp',
          fit: BoxFit.cover,
        );
      case 'emerald':
      case 'abyss':
        return Image.asset(
          'assets/wallpapers/thumbs/misty_emerald_thumb.webp',
          fit: BoxFit.cover,
        );
      case 'solid':
      case 'pure_black':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF101216) : const Color(0xFFF1F3F8),
            border: Border.all(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
              width: 1,
            ),
          ),
        );
      default:
        return Image.asset(
          'assets/wallpapers/thumbs/dusk_cloud_thumb.webp',
          fit: BoxFit.cover,
        );
    }
  }
}
