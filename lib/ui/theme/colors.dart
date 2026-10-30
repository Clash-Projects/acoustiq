import 'package:flutter/material.dart';

/// Pure Monochromatic AMOLED & Material 3 Color Tokens
///
/// Strictly enforces R = G = B across all neutral dark containers to eliminate
/// navy blue or cyan IPS LCD light-bleed, matching LastWave's pitch-black theme.
class AppColors {
  AppColors._();

  // Dark Substrate Palettes (Obsidian / Neutral)
  static const Color darkCanvas = Color(0xFF060606);
  static const Color surfaceLowest = Color(0xFF0C0C0C);
  static const Color surfaceLow = Color(0xFF121212);
  static const Color surfaceContainer = Color(0xFF181818);
  static const Color surfaceHigh = Color(0xFF222222);
  static const Color surfaceHighest = Color(0xFF2A2A2A);

  // Light Substrate Palettes
  static const Color lightCanvas = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFF0F0F2);
  static const Color lightSurfaceHigh = Color(0xFFE5E5EA);

  // Audio Telemetry & Brand Accents
  static const Color accentPrimary = Color(0xFF00D2FF);
  static const Color genuineEmerald = Color(0xFF00E676);
  static const Color suspiciousAmber = Color(0xFFFFB300);
  static const Color fakeCoral = Color(0xFFFF3D3D);

  // Hairline Outlines (Restrained, Sub-pixel)
  static const Color darkHairline = Color(0x26FFFFFF); // 15% opacity white
  static const Color lightHairline = Color(0x14000000); // 8% opacity black

  // Soft Ambient Drop Shadows (Never harsh outlines)
  static List<BoxShadow> softElevation({double elevation = 4.0}) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.40),
        blurRadius: elevation * 3.5,
        offset: Offset(0, elevation * 1.2),
      ),
    ];
  }
}

