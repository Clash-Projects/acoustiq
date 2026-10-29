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
        final isDark = appState.themeMode != 'light';
        final bgColor = appState.isAmoled && isDark ? Colors.black : (isDark ? const Color(0xFF0D1017) : const Color(0xFFF2F4F8));

        return MaterialApp(
          title: 'FLAC Toolkit',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode == 'light'
              ? ThemeMode.light
              : (appState.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.system),
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F4F8),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF),
              secondary: Color(0xFF00C853),
              surface: Colors.white,
            ),
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: bgColor,
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF00D2FF),
              secondary: const Color(0xFF00E676),
              surface: appState.isAmoled ? const Color(0xFF0A0D14) : const Color(0xFF131722),
            ),
            fontFamily: 'Roboto',
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
        final bgColor = appState.getBgColor(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              // Main Scrollable Area & Screens
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Clean Modern Header Bar (No tacky PRO v1.0 watermark!)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D2FF).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.35)),
                            ),
                            child: const Icon(Icons.waves_rounded, color: Color(0xFF00D2FF), size: 19),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FLAC TOOLKIT',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Pro Audio Quality Analyzer',
                                style: TextStyle(
                                  fontSize: 10,
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

              // Floating 4-Tab Liquid Lens Navigation Bar
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: LiquidLensNavBar(
                  currentIndex: _currentIndex,
                  onTabSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
