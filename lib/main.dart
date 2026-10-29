import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
        final isDark = appState.themeMode != 'light';
        const bgColor = Color(0xFF090D16);

        return MaterialApp(
          title: 'FLAC Toolkit',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode == 'light'
              ? ThemeMode.light
              : (appState.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.system),
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F5FA),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF),
              secondary: Color(0xFF00C853),
              surface: Colors.white,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: bgColor,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D2FF),
              secondary: Color(0xFF00E676),
              surface: Color(0xFF121726),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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
        final bgColor = appState.getBgColor(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              // Atmospheric Aurora Light Spheres (Provides ambient light for BackdropFilter to diffuse!)
              if (isDark) ...[
                Positioned(
                  top: -50,
                  right: -40,
                  child: Container(
                    width: 290,
                    height: 290,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1E2D4A).withOpacity(0.38),
                          const Color(0xFF141D30).withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: -60,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1B243B).withOpacity(0.32),
                          const Color(0xFF101524).withOpacity(0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFD8E4F8).withOpacity(0.60),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Main Scrollable Area & Screens
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Clean Modern Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.10)),
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
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Pro Audio Quality Analyzer',
                                style: GoogleFonts.inter(
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

              // Floating Centered KowSU-style Liquid Lens Navigation Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: SizedBox(
                    width: 316,
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
