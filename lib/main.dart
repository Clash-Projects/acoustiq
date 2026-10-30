import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/app_settings.dart';
import 'screens/inspect_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/duplicates_screen.dart';
import 'screens/settings_screen.dart';
import 'ui/theme/colors.dart';
import 'ui/theme/shape.dart';
import 'widgets/lastwave_dock.dart';

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
        return MaterialApp(
          title: 'FLAC Toolkit',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode == 'light'
              ? ThemeMode.light
              : (appState.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.system),
          theme: ThemeData(
            fontFamily: 'Inter',
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.lightCanvas,
            colorScheme: const ColorScheme.light(
              primary: AppColors.accentPrimary,
              secondary: AppColors.genuineEmerald,
              surface: AppColors.lightSurface,
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: 'Inter',
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.darkCanvas,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentPrimary,
              secondary: AppColors.genuineEmerald,
              surface: AppColors.surfaceContainer,
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

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkCanvas : AppColors.lightCanvas,
          body: Stack(
            children: [
              // 1. Subtle Cinematic Ambient Substrate (Obsidian Base with Soft Daylight Aperture)
              Positioned.fill(
                child: CustomPaint(
                  painter: _AcousticSubstratePainter(isDark: isDark),
                ),
              ),

              // 2. Responsive Content Container (Centered max 700px for tablets/large screens)
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        // Top Header Row matching LastWave's HeaderRow
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // App Brand Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceHigh,
                                  borderRadius: ExpressiveShapes.badgePill,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.waves_rounded,
                                      color: AppColors.accentPrimary,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'FLAC TOOLKIT',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Live Telemetry Pill matching LastWave's LiveListenTimer
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceHigh : AppColors.lightSurfaceHigh,
                                  borderRadius: ExpressiveShapes.badgePill,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.headset_rounded,
                                      color: AppColors.genuineEmerald,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${appState.sharedLibrary.length} TRACKS',
                                      style: TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Active Screen
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

              // 3. Floating 1:1 LastWave Navigation Dock
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: LastWaveNavBar(
                    currentIndex: _currentIndex,
                    onTabSelected: (index) {
                      setState(() => _currentIndex = index);
                    },
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

/// Subtle Optical Substrate Painter
/// Provides genuine optical contrast and soft overhead daylight pool without harsh lines
class _AcousticSubstratePainter extends CustomPainter {
  final bool isDark;

  _AcousticSubstratePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (isDark) {
      // 1. Deep Obsidian Base (R = G = B = 6, strictly neutral)
      canvas.drawRect(rect, Paint()..color = AppColors.darkCanvas);

      // 2. Overhead Daylight Aperture (High-contrast neutral pool)
      final daylightShader = RadialGradient(
        center: const Alignment(0.0, -0.85),
        radius: 1.4,
        colors: [
          Colors.white.withOpacity(0.09),
          Colors.white.withOpacity(0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = daylightShader);

      // 3. Subtle bottom lift under dock
      final bottomGlowShader = RadialGradient(
        center: const Alignment(0.0, 0.95),
        radius: 0.8,
        colors: [
          Colors.white.withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = bottomGlowShader);
    } else {
      canvas.drawRect(rect, Paint()..color = AppColors.lightCanvas);

      final daylightShader = RadialGradient(
        center: const Alignment(0.0, -0.70),
        radius: 1.2,
        colors: [
          Colors.white.withOpacity(0.9),
          const Color(0xFFEEEEF2),
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = daylightShader);
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticSubstratePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
