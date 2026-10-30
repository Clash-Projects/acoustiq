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
        const darkCanvas = Color(0xFF0A0B0E);
        const lightCanvas = Color(0xFFF6F7FA);

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
              primary: Color(0xFF007AFF),
              secondary: Color(0xFF00C853),
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
              surface: Color(0xFF131418),
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
          backgroundColor: isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF6F7FA),
          body: Stack(
            children: [
              // 1. Environmental Acoustic Loft Substrate (Allows BackdropFilter to physically frost!)
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
                        // Header Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
                                    width: 0.5,
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

              // 3. Floating Centered KowSU / LastWave Magnifying Liquid Lens Navigation Bar
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
/// Implements subtle architectural daylight and acoustic diffusion slats
/// that give BackdropFilter real optical contrast and light rays to diffuse,
/// replicating the "Good Morning Concrete Loft" aesthetic with ZERO navy blue.
class _AcousticLoftPainter extends CustomPainter {
  final bool isDark;

  _AcousticLoftPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (isDark) {
      // 1. Neutral Obsidian Base
      final bgPaint = Paint()..color = const Color(0xFF0A0B0E);
      canvas.drawRect(rect, bgPaint);

      // 2. Cinematic Overhead Daylight Aperture (Top-center light pool)
      final daylightShader = RadialGradient(
        center: const Alignment(0.0, -0.70),
        radius: 1.35,
        colors: [
          const Color(0xFFE2E8F0).withOpacity(0.065),
          const Color(0xFF94A3B8).withOpacity(0.020),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = daylightShader);

      // 3. Subtle Acoustic Slats (Vertical diffusion geometry)
      final slatPaint = Paint()
        ..color = Colors.white.withOpacity(0.015)
        ..strokeWidth = 1.0;

      const slatSpacing = 36.0;
      for (double x = 0.0; x < size.width; x += slatSpacing) {
        canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), slatPaint);
      }
    } else {
      // Light Mode: Pure Porcelain Substrate
      final bgPaint = Paint()..color = const Color(0xFFF6F7FA);
      canvas.drawRect(rect, bgPaint);

      final daylightShader = RadialGradient(
        center: const Alignment(0.0, -0.60),
        radius: 1.3,
        colors: [
          Colors.white.withOpacity(0.95),
          const Color(0xFFEEF0F5),
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = daylightShader);
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticLoftPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
