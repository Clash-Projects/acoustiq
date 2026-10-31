import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// 1:1 Ambient Glass Wallpaper & Environment Engine
///
/// Renders an atmospheric lightfield behind all screens and floating glass docks.
/// Provides physical chromatic gradients, optical caustics, and custom user images
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
                      _buildNebulaMesh(isDark),
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
          case 'abyss':
            return _buildAbyssMesh(isDark);
          case 'sunset':
            return _buildSunsetMesh(isDark);
          case 'solid':
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
  /// Deep space cosmic violet, royal indigo & azure aurora
  Widget _buildNebulaMesh(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Deep Chromatic Canvas
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0E0E18),
                      Color(0xFF090A14),
                      Color(0xFF06070E),
                    ]
                  : const [
                      Color(0xFFEDE9FE),
                      Color(0xFFF3F0FF),
                      Color(0xFFF8FAFC),
                    ],
            ),
          ),
        ),

        // 2. High-Luminance Top-Right Radiant Orchid Bloom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, -0.60),
                radius: 1.25,
                colors: isDark
                    ? [
                        const Color(0xFF7B1FA2).withOpacity(0.55),
                        const Color(0xFF4A148C).withOpacity(0.30),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF9333EA).withOpacity(0.24),
                        const Color(0xFFC084FC).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // 3. Diagonal Silk Ribbon across center
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -0.3),
                end: const Alignment(0.7, 0.5),
                colors: isDark
                    ? [
                        Colors.transparent,
                        const Color(0xFF311B92).withOpacity(0.38),
                        const Color(0xFF1A237E).withOpacity(0.25),
                        Colors.transparent,
                      ]
                    : [
                        Colors.transparent,
                        const Color(0xFF818CF8).withOpacity(0.18),
                        const Color(0xFFA5B4FC).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.40, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // 4. Lower-Center Azure Aurora (Illuminates content gliding behind the dock)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.1, 0.75),
                radius: 1.15,
                colors: isDark
                    ? [
                        const Color(0xFF0D47A1).withOpacity(0.48),
                        const Color(0xFF1565C0).withOpacity(0.24),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF38BDF8).withOpacity(0.24),
                        const Color(0xFF7DD3FC).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 5. Micro-Texture Surface (Supplies spatial grain for realistic glass frosting)
        Positioned.fill(
          child: CustomPaint(
            painter: _MicroTexturePainter(isDark: isDark),
          ),
        ),
      ],
    );
  }

  /// Preset 2: Emerald Abyss
  /// Oceanic deep marine teal, emerald reefs & bioluminescent glow
  Widget _buildAbyssMesh(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Oceanic Canvas
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? const [
                      Color(0xFF051214),
                      Color(0xFF030D0F),
                      Color(0xFF02080A),
                    ]
                  : const [
                      Color(0xFFE6FFFA),
                      Color(0xFFF0FDF4),
                      Color(0xFFF8FAFC),
                    ],
            ),
          ),
        ),

        // 2. Top-Left Bioluminescent Mint Bloom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.80, -0.65),
                radius: 1.30,
                colors: isDark
                    ? [
                        const Color(0xFF00796B).withOpacity(0.55),
                        const Color(0xFF004D40).withOpacity(0.32),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF14B8A6).withOpacity(0.24),
                        const Color(0xFF5EEAD4).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),

        // 3. Diagonal Deep Marine Emerald Sweep
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(0.7, -0.4),
                end: const Alignment(-0.6, 0.6),
                colors: isDark
                    ? [
                        Colors.transparent,
                        const Color(0xFF00695C).withOpacity(0.42),
                        const Color(0xFF004D40).withOpacity(0.24),
                        Colors.transparent,
                      ]
                    : [
                        Colors.transparent,
                        const Color(0xFF34D399).withOpacity(0.20),
                        const Color(0xFF6EE7B7).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // 4. Lower-Center Electric Cyan Flare (Optically illuminates dock background)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.15, 0.80),
                radius: 1.15,
                colors: isDark
                    ? [
                        const Color(0xFF00B0FF).withOpacity(0.35),
                        const Color(0xFF00838F).withOpacity(0.20),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF06B6D4).withOpacity(0.22),
                        const Color(0xFF67E8F9).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 5. Micro-Texture Surface
        Positioned.fill(
          child: CustomPaint(
            painter: _MicroTexturePainter(isDark: isDark),
          ),
        ),
      ],
    );
  }

  /// Preset 3: Sunset Horizon
  /// Twilight dusk rose, burning ember & golden dusk flares
  Widget _buildSunsetMesh(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Twilight Canvas
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF160A10),
                      Color(0xFF10060B),
                      Color(0xFF0A0407),
                    ]
                  : const [
                      Color(0xFFFFF1F2),
                      Color(0xFFFFF7ED),
                      Color(0xFFFAF5FF),
                    ],
            ),
          ),
        ),

        // 2. Top-Right Vivid Crimson Magenta Bloom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, -0.65),
                radius: 1.30,
                colors: isDark
                    ? [
                        const Color(0xFFAD1457).withOpacity(0.55),
                        const Color(0xFF6A1B9A).withOpacity(0.30),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFF43F5E).withOpacity(0.24),
                        const Color(0xFFFB7185).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),

        // 3. Diagonal Warm Ember Flare
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -0.2),
                end: const Alignment(0.6, 0.6),
                colors: isDark
                    ? [
                        Colors.transparent,
                        const Color(0xFFC2185B).withOpacity(0.40),
                        const Color(0xFFD84315).withOpacity(0.28),
                        Colors.transparent,
                      ]
                    : [
                        Colors.transparent,
                        const Color(0xFFFB923C).withOpacity(0.20),
                        const Color(0xFFFDBA74).withOpacity(0.10),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.40, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // 4. Lower-Center Golden Dusk Aurora
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 0.78),
                radius: 1.15,
                colors: isDark
                    ? [
                        const Color(0xFFE65100).withOpacity(0.48),
                        const Color(0xFFBF360C).withOpacity(0.26),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFF59E0B).withOpacity(0.24),
                        const Color(0xFFFCD34D).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 5. Micro-Texture Surface
        Positioned.fill(
          child: CustomPaint(
            painter: _MicroTexturePainter(isDark: isDark),
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
              colors: [Color(0xFF00796B), Color(0xFF004D40), Color(0xFF001E1D)],
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
              colors: [Color(0xFFAD1457), Color(0xFFD84315), Color(0xFF1E0A12)],
            ),
          ),
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
      case 'nebula':
      default:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF7B1FA2), Color(0xFF1565C0), Color(0xFF0E0E18)],
            ),
          ),
        );
    }
  }
}

/// Optical Micro-Texture Grain Painter
///
/// Simulates physical optical stippling. When processed by a Gaussian blur shader,
/// this micro-texture produces tangible dispersion and genuine frosted glass aesthetics.
class _MicroTexturePainter extends CustomPainter {
  final bool isDark;

  const _MicroTexturePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.025) : Colors.black.withOpacity(0.018)
      ..style = PaintingStyle.fill;

    const step = 28.0;
    for (double x = 8.0; x < size.width; x += step) {
      for (double y = 8.0; y < size.height; y += step) {
        final offset = ((x.toInt() * 73 + y.toInt() * 37) % 7).toDouble();
        canvas.drawCircle(Offset(x + offset, y + offset), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MicroTexturePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
