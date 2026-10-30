import 'package:flutter/material.dart';

/// Pure Monochromatic AMOLED & Material 3 Expressive Color Tokens
///
/// Strictly enforces R = G = B across all neutral dark containers to eliminate
/// navy blue or cyan IPS LCD light-bleed, matching LastWave's pitch-black theme.
class AppColors {
  AppColors._();

  // True Pitch Black AMOLED Substrate
  static const Color amoledCanvas = Color(0xFF000000);
  
  // Deep Obsidian Graphite Substrate (When AMOLED mode is OFF)
  static const Color graphiteCanvas = Color(0xFF121212);
  static const Color darkCanvas = Color(0xFF000000);

  // LastWave Obsidian Neutral Surfaces (Zero Border Architecture)
  static const Color surfaceLowest = Color(0xFF080808);
  static const Color surfaceLow = Color(0xFF101010);
  static const Color surfaceContainer = Color(0xFF141414);
  static const Color surfaceHigh = Color(0xFF1C1C1C);
  static const Color surfaceHighest = Color(0xFF242424);

  // Light Substrate Palettes
  static const Color lightCanvas = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFEFEFF2);
  static const Color lightSurfaceHigh = Color(0xFFE4E4E8);

  // High-Contrast Light Mode Typography (WCAG AAA Compliant)
  static const Color lightTextPrimary = Color(0xFF18181A);
  static const Color lightTextSecondary = Color(0xFF3C3C40);
  static const Color lightTextMuted = Color(0xFF6E6E73);

  // Audio Telemetry & Brand Accents
  static const Color accentPrimary = Color(0xFF00D2FF);
  static const Color genuineEmerald = Color(0xFF00E676);
  static const Color suspiciousAmber = Color(0xFFFFB300);
  static const Color fakeCoral = Color(0xFFFF3D3D);

  // Light Mode High-Contrast Accent Pills
  static const Color lightEmeraldPillBg = Color(0xFFE6F9EE);
  static const Color lightEmeraldText = Color(0xFF0A7E3E);
  static const Color lightAmberPillBg = Color(0xFFFFF7E6);
  static const Color lightAmberText = Color(0xFF9A6700);
  static const Color lightCoralPillBg = Color(0xFFFFEBEB);
  static const Color lightCoralText = Color(0xFFB71C1C);
  static const Color lightCyanPillBg = Color(0xFFE6F8FD);
  static const Color lightCyanText = Color(0xFF007A99);

  // Muted icon badges
  static const Color badgeCyan = Color(0xFF19323E);
  static const Color badgePurple = Color(0xFF28203B);
  static const Color badgeEmerald = Color(0xFF143324);
  static const Color badgeAmber = Color(0xFF382D16);

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
