import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/app_settings.dart';
import 'screens/inspect_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/duplicates_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/liquid_lens_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FlacToolkitApp());
}

class FlacToolkitApp extends StatelessWidget {
  const FlacToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        const darkCanvas = Color(0xFF060606);
        const lightCanvas = Color(0xFFF5F5F7);

        return MaterialApp(
          title: 'FLAC Toolkit',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode == 'light'
              ? ThemeMode.light
              : (appState.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.system),
          theme: ThemeData(
            fontFamily: 'Inter',
            brightness: Brightness.light,
            scaffoldBackgroundColor: lightCanvas,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00D2FF),
              secondary: Color(0xFF00E676),
              surface: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: 'Inter',
            brightness: Brightness.dark,
            scaffoldBackgroundColor: darkCanvas,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D2FF),
              secondary: Color(0xFF00E676),
              surface: Color(0xFF141414),
            ),
          ),
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InspectScreen(),
    AuditScreen(),
    DuplicatesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.storage,
        Permission.audio,
        Permission.manageExternalStorage,
      ].request();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);
        final screenWidth = MediaQuery.of(context).size.width;

        // Responsive dock width: Proportional on mobile (330dp) and tablet (480dp)
        final dockWidth = (screenWidth * 0.86).clamp(320.0, 500.0);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF060606) : const Color(0xFFF5F5F7),
          body: Stack(
            children: [
              // 1. Cinematic Architectural Acoustic Loft Substrate (Rich ambient light & diffusion geometry)
              Positioned.fill(
                child: CustomPaint(
                  painter: _AcousticLoftPainter(isDark: isDark),
                ),
              ),

              // 2. Responsive Content Container (Centered max 620px for tablets)
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      children: [
                        // Header Bar with Frosted Glass Badge
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06),
                                    width: 0.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.waves_rounded,
                                  color: isDark ? Colors.white : Colors.black87,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FLAC TOOLKIT',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'Pro Audio Quality Analyzer',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: subTextColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Active Tab Screen
                        Expanded(
                          child: IndexedStack(
                            index: _currentIndex,
                            children: _screens,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Floating Centered KowSU 3D Liquid Lens Navigation Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: SizedBox(
                    width: dockWidth,
                    child: LiquidLensNavBar(
                      currentIndex: _currentIndex,
                      onTabSelected: (index) {
                        setState(() => _currentIndex = index);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Architectural Acoustic Loft Environmental Substrate
///
/// Implements authentic cinematic daylight aperture, studio light pools,
/// and acoustic diffusion slats that give BackdropFilter high optical contrast
/// and real light rays to physically scatter into luminous frosted silica.
class _AcousticLoftPainter extends CustomPainter {
  final bool isDark;

  _AcousticLoftPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (isDark) {
      // 1. Deep Obsidian Base (R = G = B = 6, strictly neutral)
      final bgPaint = Paint()..color = const Color(0xFF060606);
      canvas.drawRect(rect, bgPaint);

      // 2. Cinematic Overhead Daylight Aperture (High-contrast neutral silver pool)
      final daylightShader = RadialGradient(
        center: const Alignment(0.0, -0.80),
        radius: 1.45,
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = daylightShader);

      // 3. Subtle Studio Spotlight Cone
      final studioShader = RadialGradient(
        center: const Alignment(0.0, -0.25),
        radius: 1.7,
        colors: [
          Colors.white.withOpacity(0.035),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = studioShader);

      // 4. Architectural Acoustic Diffusion Slats & Geometric Guides
      // When BackdropFilter blurs these slats, they scatter into genuine milky frosted silica!
      final verticalSlatPaint = Paint()
        ..color = Colors.white.withOpacity(0.045)
        ..strokeWidth = 1.2;

      const slatSpacing = 36.0;
      for (double x = 0.0; x < size.width; x += slatSpacing) {
        canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), verticalSlatPaint);
      }

      final horizontalSlatPaint = Paint()
        ..color = Colors.white.withOpacity(0.025)
        ..strokeWidth = 0.8;

      const horizSpacing = 72.0;
      for (double y = 0.0; y < size.height; y += horizSpacing) {
        canvas.drawLine(Offset(0.0, y), Offset(size.width, y), horizontalSlatPaint);
      }

      // 5. Bottom Ambient Refraction Light Pool (Directly behind the floating nav bar dock)
      final bottomGlowShader = RadialGradient(
        center: const Alignment(0.0, 0.98),
        radius: 0.90,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bottomGlowShader);
    } else {
      // Light Mode: Pure Porcelain Substrate (R = G = B = 245)
      final bgPaint = Paint()..color = const Color(0xFFF5F5F7);
      canvas.drawRect(rect, bgPaint);

      final daylightShader = RadialGradient(
        center: const Alignment(0.0, -0.60),
        radius: 1.3,
        colors: [
          Colors.white.withOpacity(0.95),
          const Color(0xFFEEEEF2),
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = daylightShader);

      final slatPaint = Paint()
        ..color = Colors.black.withOpacity(0.025)
        ..strokeWidth = 0.8;

      for (double x = 0.0; x < size.width; x += 36.0) {
        canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), slatPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticLoftPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
