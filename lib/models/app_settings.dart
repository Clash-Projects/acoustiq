import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flac_info.dart';
import '../ui/theme/colors.dart';

class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool _isLiquidGlass = true;
  bool _hapticsEnabled = true;
  bool _amoledMode = true;
  String _themeMode = 'dark'; // 'system', 'light', 'dark'
  String _accentPreset = 'Cyan'; // 'Cyan', 'Amber', 'Emerald', 'Violet', 'Crimson', 'Monochrome', 'Custom'
  Color _customColor = const Color(0xFF00E5FF);
  String _wallpaperPreset = 'cloud'; // 'cloud', 'vinyl', 'emerald', 'solid', 'custom'
  String? _customWallpaperPath;
  String _motionPreset = 'full'; // 'full' (120Hz micro-interactions), 'reduced' (transitions only), 'off' (static battery saver)

  bool _audiophileMode = false; // false = Everyday Music Lover, true = Acoustic Engineer / Pro
  String _visualizerMode = 'hybrid'; // 'hybrid', 'gauge', 'waveform'

  // AcoustiQ Developer Laboratory & QA Mode (Enabled for active QA cycle)
  bool _devModeEnabled = true;
  FlacInfo? _injectedMockTrack;

  List<FlacInfo> _sharedLibrary = [];
  String? _lastScannedFolder;
  List<String> _recentFilePaths = [];

  bool get isLiquidGlass => _isLiquidGlass;
  bool get liquidGlassEnabled => _isLiquidGlass;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get amoledMode => _amoledMode;
  bool get audiophileMode => true; // Unified mode: full precision always available
  String get visualizerMode => _visualizerMode;
  bool get devModeEnabled => _devModeEnabled;
  FlacInfo? get injectedMockTrack => _injectedMockTrack;
  String get themeMode => _themeMode;
  String get accentPreset => _accentPreset;
  Color get customColor => _customColor;
  String get wallpaperPreset => _wallpaperPreset;
  String? get customWallpaperPath => _customWallpaperPath;
  String get motionPreset => _motionPreset;
  bool get isFullMotion => _motionPreset == 'full';
  bool get isReducedMotion => _motionPreset == 'reduced';
  bool get isMotionOff => _motionPreset == 'off';
  List<FlacInfo> get sharedLibrary => _sharedLibrary;
  String? get lastScannedFolder => _lastScannedFolder;
  List<String> get recentFilePaths => _recentFilePaths;

  /// Load persistent settings from device SharedPreferences
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isLiquidGlass = _prefs?.getBool('is_liquid_glass') ?? true;
      _hapticsEnabled = _prefs?.getBool('haptics_enabled') ?? true;
      _amoledMode = _prefs?.getBool('amoled_mode') ?? true;
      _themeMode = _prefs?.getString('theme_mode') ?? 'dark';
      _accentPreset = _prefs?.getString('accent_preset') ?? 'Cyan';
      // Seamless migration from legacy LastWave and prototype preset names
      if (_accentPreset == 'Ocean' || _accentPreset == 'Prism Cyan') {
        _accentPreset = 'Cyan';
      } else if (_accentPreset == 'Amber' || _accentPreset == 'Analog Amber') {
        _accentPreset = 'Amber';
      } else if (_accentPreset == 'Sage' || _accentPreset == 'Acoustic Emerald') {
        _accentPreset = 'Emerald';
      } else if (_accentPreset == 'Violet' || _accentPreset == 'Ultraviolet Hi-Res') {
        _accentPreset = 'Violet';
      } else if (_accentPreset == 'Crimson' || _accentPreset == 'Crimson Peak') {
        _accentPreset = 'Crimson';
      } else if (_accentPreset == 'Mono' || _accentPreset == 'Titanium Mono') {
        _accentPreset = 'Monochrome';
      } else if (_accentPreset == 'Custom' || _accentPreset == 'Custom Resonance') {
        _accentPreset = 'Custom';
      }

      final savedColor = _prefs?.getInt('custom_color_value');
      if (savedColor != null) {
        _customColor = Color(savedColor);
      }

      _wallpaperPreset = _prefs?.getString('wallpaper_preset') ?? 'cloud';
      if (_wallpaperPreset == 'nebula' ||
          _wallpaperPreset == 'sunset' ||
          _wallpaperPreset == 'titanium' ||
          _wallpaperPreset == 'acoustic') {
        _wallpaperPreset = 'cloud';
        _prefs?.setString('wallpaper_preset', 'cloud');
      } else if (_wallpaperPreset == 'abyss') {
        _wallpaperPreset = 'emerald';
        _prefs?.setString('wallpaper_preset', 'emerald');
      }
      _customWallpaperPath = _prefs?.getString('custom_wallpaper_path');
      _motionPreset = _prefs?.getString('motion_preset') ?? 'full';

      _audiophileMode = _prefs?.getBool('audiophile_mode') ?? false;
      _visualizerMode = _prefs?.getString('visualizer_mode') ?? 'hybrid';
      _devModeEnabled = _prefs?.getBool('dev_mode_enabled') ?? true;

      // Verify custom wallpaper file still exists on disk
      if (_customWallpaperPath != null && !File(_customWallpaperPath!).existsSync()) {
        _customWallpaperPath = null;
        if (_wallpaperPreset == 'custom') {
          _wallpaperPreset = 'cloud';
        }
      }

      _lastScannedFolder = _prefs?.getString('last_scanned_folder');
      _recentFilePaths = _prefs?.getStringList('recent_file_paths') ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Color getAccentColor(BuildContext context) {
    switch (_accentPreset) {
      case 'Cyan':
      case 'Prism Cyan':
      case 'Ocean':
        return const Color(0xFF00E5FF);
      case 'Amber':
      case 'Analog Amber':
        return const Color(0xFFFF9500);
      case 'Emerald':
      case 'Acoustic Emerald':
      case 'Sage':
        return const Color(0xFF00E676);
      case 'Violet':
      case 'Ultraviolet Hi-Res':
        return const Color(0xFF8B5CF6);
      case 'Crimson':
      case 'Crimson Peak':
        return const Color(0xFFFF3B30);
      case 'Monochrome':
      case 'Titanium Mono':
      case 'Mono':
        return isCurrentDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
      case 'Rose':
        return const Color(0xFFE0507A);
      case 'Custom Color':
      case 'Custom Resonance':
      case 'Custom':
      default:
        return _customColor;
    }
  }

  bool isCurrentDark(BuildContext context) {
    if (_themeMode == 'light') return false;
    if (_themeMode == 'dark') return true;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Color getBgColor(BuildContext context) {
    if (!isCurrentDark(context)) return AppColors.lightCanvas;
    // AMOLED Mode: #000000 vs Graphite Mode: #12161A (The sleek view the user loves)
    return _amoledMode ? AppColors.amoledCanvas : AppColors.graphiteCanvas;
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return _isLiquidGlass
          ? Colors.white.withOpacity(0.90)
          : AppColors.lightSurface;
    }
    // Dark mode surfaces
    if (_amoledMode) {
      return _isLiquidGlass
          ? const Color(0x22FFFFFF)
          : const Color(0xFF101214);
    } else {
      return _isLiquidGlass
          ? const Color(0x28FFFFFF)
          : const Color(0xFF1E2228);
    }
  }

  Color getTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white : AppColors.lightTextPrimary;
  }

  Color getSubTextColor(BuildContext context) {
    return isCurrentDark(context)
        ? const Color(0x99FFFFFF)
        : AppColors.lightTextSecondary;
  }

  void setLiquidGlass(bool value) {
    _isLiquidGlass = value;
    _prefs?.setBool('is_liquid_glass', value);
    notifyListeners();
  }

  void setHaptics(bool value) {
    _hapticsEnabled = value;
    _prefs?.setBool('haptics_enabled', value);
    notifyListeners();
  }

  void setHapticsEnabled(bool value) => setHaptics(value);

  void setAmoledMode(bool value) {
    _amoledMode = value;
    _prefs?.setBool('amoled_mode', value);
    notifyListeners();
  }

  void setThemeMode(String value) {
    _themeMode = value;
    _prefs?.setString('theme_mode', value);
    notifyListeners();
  }

  void setAccentPreset(String preset, [Color? customColor]) {
    _accentPreset = preset;
    _prefs?.setString('accent_preset', preset);
    if (customColor != null) {
      _customColor = customColor;
      _prefs?.setInt('custom_color_value', customColor.value);
    }
    notifyListeners();
  }

  void setAudiophileMode(bool value) {
    _audiophileMode = value;
    _prefs?.setBool('audiophile_mode', value);
    notifyListeners();
  }

  void setVisualizerMode(String mode) {
    _visualizerMode = mode;
    _prefs?.setString('visualizer_mode', mode);
    notifyListeners();
  }

  void setMotionPreset(String preset) {
    _motionPreset = preset;
    _prefs?.setString('motion_preset', preset);
    notifyListeners();
  }

  void setWallpaperPreset(String preset) {
    _wallpaperPreset = preset;
    _prefs?.setString('wallpaper_preset', preset);
    notifyListeners();
  }

  void setCustomWallpaperPath(String? path) {
    _customWallpaperPath = path;
    if (path != null) {
      _wallpaperPreset = 'custom';
      _prefs?.setString('custom_wallpaper_path', path);
      _prefs?.setString('wallpaper_preset', 'custom');
    } else {
      _prefs?.remove('custom_wallpaper_path');
    }
    notifyListeners();
  }

  Future<void> clearCustomWallpaper() async {
    if (_customWallpaperPath != null) {
      try {
        final f = File(_customWallpaperPath!);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    _customWallpaperPath = null;
    _wallpaperPreset = 'cloud';
    _prefs?.remove('custom_wallpaper_path');
    _prefs?.setString('wallpaper_preset', 'cloud');
    notifyListeners();
  }

  void setSharedLibrary(List<FlacInfo> tracks, String folder) {
    _sharedLibrary = tracks;
    _lastScannedFolder = folder;
    _prefs?.setString('last_scanned_folder', folder);
    notifyListeners();
  }

  void removeTrackFromLibrary(String filePath) {
    _sharedLibrary.removeWhere((t) => t.filePath == filePath);
    notifyListeners();
  }

  void addRecentFilePath(String path) {
    _recentFilePaths.remove(path);
    _recentFilePaths.insert(0, path);
    if (_recentFilePaths.length > 20) {
      _recentFilePaths = _recentFilePaths.sublist(0, 20);
    }
    _prefs?.setStringList('recent_file_paths', _recentFilePaths);
    notifyListeners();
  }

  void setDevMode(bool enabled) {
    _devModeEnabled = enabled;
    _prefs?.setBool('dev_mode_enabled', enabled);
    notifyListeners();
  }

  void toggleDevMode() {
    setDevMode(!_devModeEnabled);
  }

  void injectMockTrack(FlacInfo? track) {
    _injectedMockTrack = track;
    notifyListeners();
  }
}

final appState = AppState();
