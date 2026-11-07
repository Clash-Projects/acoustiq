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
                      _buildAbyssMesh(isDark),
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
          case 'titanium':
            return _buildDarkTitanium(isDark);
          case 'acoustic':
            return _buildStudioAcoustic(isDark);
          case 'solid':
          case 'pure_black':
            return _buildPureBlack(context, isDark);
          case 'abyss':
          default:
            return _buildAbyssMesh(isDark);
        }
      },
    );
  }

  Widget _buildPureBlack(BuildContext context, bool isDark) {
    final bg = appState.getBgColor(context);
    return Container(color: bg);
  }

  /// Preset 1: Emerald Abyss
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

  /// Preset 2: Dark Titanium
  /// Precision brushed gunmetal audio chassis with specular rim highlights
  Widget _buildDarkTitanium(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Metallic Canvas
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF16181D),
                      Color(0xFF0F1115),
                      Color(0xFF08090C),
                    ]
                  : const [
                      Color(0xFFF1F5F9),
                      Color(0xFFE2E8F0),
                      Color(0xFFCBD5E1),
                    ],
            ),
          ),
        ),

        // 2. High-Luminance Brushed Specular Rim Reflection
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.65, -0.70),
                radius: 1.35,
                colors: isDark
                    ? [
                        const Color(0xFF94A3B8).withOpacity(0.16),
                        const Color(0xFF64748B).withOpacity(0.08),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFFFFFFF).withOpacity(0.50),
                        const Color(0xFFE2E8F0).withOpacity(0.20),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // 3. Diagonal Sub-Surface Rim Sheen
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -0.4),
                end: const Alignment(0.7, 0.6),
                colors: isDark
                    ? [
                        Colors.transparent,
                        const Color(0xFF334155).withOpacity(0.15),
                        const Color(0xFF1E293B).withOpacity(0.08),
                        Colors.transparent,
                      ]
                    : [
                        Colors.transparent,
                        const Color(0xFFFFFFFF).withOpacity(0.35),
                        const Color(0xFFF8FAFC).withOpacity(0.15),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.40, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // 4. Physical Brushed Metal Striations
        Positioned.fill(
          child: CustomPaint(
            painter: _TitaniumBrushedPainter(isDark: isDark),
          ),
        ),
      ],
    );
  }

  /// Preset 3: Studio Acoustic
  /// Professional recording studio soundproofing foam wedges & acoustic diffuser geometry
  Widget _buildStudioAcoustic(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Studio Obsidian Canvas
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [
                      Color(0xFF111318),
                      Color(0xFF0C0D11),
                      Color(0xFF07080A),
                    ]
                  : const [
                      Color(0xFFF8FAFC),
                      Color(0xFFF1F5F9),
                      Color(0xFFE2E8F0),
                    ],
            ),
          ),
        ),

        // 2. Subtle Acoustic Monitor Center Glow
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.30),
                radius: 1.20,
                colors: isDark
                    ? [
                        const Color(0xFF1E293B).withOpacity(0.20),
                        const Color(0xFF0F172A).withOpacity(0.10),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFCBD5E1).withOpacity(0.25),
                        const Color(0xFFE2E8F0).withOpacity(0.12),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // 3. Acoustic Foam Wedge / Diffuser Baffle Matrix
        Positioned.fill(
          child: CustomPaint(
            painter: _AcousticDiffuserPainter(isDark: isDark),
          ),
        ),
      ],
    );
  }

  /// Miniature preview swatch for Settings Screen
  static Widget buildPreview(String preset, bool isDark) {
    switch (preset) {
      case 'titanium':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
          ),
          child: const CustomPaint(
            painter: _TitaniumBrushedPainter(isDark: true),
          ),
        );
      case 'acoustic':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E222A), Color(0xFF13151B), Color(0xFF090A0D)],
            ),
          ),
          child: const CustomPaint(
            painter: _AcousticDiffuserPainter(isDark: true),
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
      case 'abyss':
      default:
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

/// Titanium Brushed Metal Striations Painter
///
/// Simulates fine horizontal directional brushed striations found on
/// premium studio audio amplifiers and DAC chassis.
class _TitaniumBrushedPainter extends CustomPainter {
  final bool isDark;

  const _TitaniumBrushedPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const step = 4.0;
    for (double y = 0.0; y < size.height; y += step) {
      final hash = (y * 73 + 19).toInt();
      final alphaFactor = ((hash % 10) / 10.0);
      final alpha = (isDark ? 0.032 : 0.024) * alphaFactor;
      linePaint.color = (isDark ? Colors.white : Colors.black).withOpacity(alpha);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TitaniumBrushedPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Studio Acoustic Foam Diffuser Painter
///
/// Simulates the alternating geometric pyramid wedge baffles of recording studio
/// acoustic wall paneling.
class _AcousticDiffuserPainter extends CustomPainter {
  final bool isDark;

  const _AcousticDiffuserPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 52.0;
    final lightPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.028 : 0.40)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.075 : 0.045)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.015 : 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    int row = 0;
    for (double y = 0; y < size.height; y += tileSize, row++) {
      int col = 0;
      for (double x = 0; x < size.width; x += tileSize, col++) {
        final invert = (row + col) % 2 == 0;
        final pathA = Path();
        final pathB = Path();

        if (invert) {
          pathA.moveTo(x, y);
          pathA.lineTo(x + tileSize, y);
          pathA.lineTo(x, y + tileSize);
          pathA.close();

          pathB.moveTo(x + tileSize, y);
          pathB.lineTo(x + tileSize, y + tileSize);
          pathB.lineTo(x, y + tileSize);
          pathB.close();
        } else {
          pathA.moveTo(x, y);
          pathA.lineTo(x + tileSize, y);
          pathA.lineTo(x + tileSize, y + tileSize);
          pathA.close();

          pathB.moveTo(x, y);
          pathB.lineTo(x + tileSize, y + tileSize);
          pathB.lineTo(x, y + tileSize);
          pathB.close();
        }

        canvas.drawPath(pathA, lightPaint);
        canvas.drawPath(pathB, shadowPaint);
        canvas.drawRect(Rect.fromLTWH(x, y, tileSize, tileSize), borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticDiffuserPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
