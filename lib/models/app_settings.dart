import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
  String _fontFamily = 'SF-Pro'; // 'SF-Pro', 'Geist', 'PlusJakartaSans', 'Inter'

  // Hardware Tiering & Low-Power Specs (Detected quietly)
  String _deviceModel = '';
  int _totalRamMb = 0;
  bool _isLowSpecDevice = false;
  int _activeTabIndex = 0;

  // AcoustiQ Developer Laboratory & QA Mode
  bool _devModeEnabled = true;
  FlacInfo? _injectedMockTrack;

  List<FlacInfo> _sharedLibrary = [];
  String? _lastScannedFolder;
  List<String> _recentFilePaths = [];

  bool get isLiquidGlass => _isLiquidGlass;
  bool get liquidGlassEnabled => _isLiquidGlass;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get amoledMode => _amoledMode;
  bool get audiophileMode => _audiophileMode;
  String get visualizerMode => _visualizerMode;
  String get fontFamily => _fontFamily;
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
  bool get strictLowPowerMode => !_isLiquidGlass;
  bool get autoHardwareTiering => true;
  String get deviceModel => _deviceModel;
  int get totalRamMb => _totalRamMb;
  bool get isLowSpecDevice => _isLowSpecDevice;
  int get activeTabIndex => _activeTabIndex;
  List<FlacInfo> get sharedLibrary => _sharedLibrary;
  String? get lastScannedFolder => _lastScannedFolder;
  List<String> get recentFilePaths => _recentFilePaths;

  /// Load persistent settings from device SharedPreferences
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final hasExistingPrefs = _prefs?.containsKey('is_liquid_glass') ?? false;
      final hasInitialized = (_prefs?.getBool('has_initialized_defaults') ?? false) || hasExistingPrefs;

      // Query hardware specs from native Android layer quietly
      try {
        const channel = MethodChannel('flac_toolkit/audio_decoder');
        final specs = await channel.invokeMethod<Map>('getDeviceHardwareSpecs');
        if (specs != null) {
          _deviceModel = specs['model']?.toString() ?? '';
          _totalRamMb = (specs['totalRamMb'] as int?) ?? 0;
          final isLowRam = specs['isLowRam'] == true;
          _isLowSpecDevice = isLowRam || _totalRamMb < 3500 || _deviceModel.toLowerCase().contains('acer');
        }
      } catch (_) {}

      if (!hasInitialized) {
        // First run on this device: establish device-appropriate defaults
        _isLiquidGlass = !_isLowSpecDevice;
        _motionPreset = _isLowSpecDevice ? 'reduced' : 'full';
        _hapticsEnabled = true;
        _amoledMode = true;
        _themeMode = 'dark';
        _accentPreset = 'Cyan';
        _fontFamily = 'SF-Pro';
        _wallpaperPreset = 'cloud';
        _audiophileMode = false;
        _visualizerMode = 'hybrid';

        // Persist all defaults immediately so they sustain across restarts
        await _prefs?.setBool('is_liquid_glass', _isLiquidGlass);
        await _prefs?.setString('motion_preset', _motionPreset);
        await _prefs?.setBool('haptics_enabled', _hapticsEnabled);
        await _prefs?.setBool('amoled_mode', _amoledMode);
        await _prefs?.setString('theme_mode', _themeMode);
        await _prefs?.setString('accent_preset', _accentPreset);
        await _prefs?.setString('font_family', _fontFamily);
        await _prefs?.setString('wallpaper_preset', _wallpaperPreset);
        await _prefs?.setBool('audiophile_mode', _audiophileMode);
        await _prefs?.setString('visualizer_mode', _visualizerMode);
        await _prefs?.setBool('has_initialized_defaults', true);
      } else {
        // Subsequent launches: ALWAYS restore saved user settings
        _isLiquidGlass = _prefs?.getBool('is_liquid_glass') ?? (!_isLowSpecDevice);
        _motionPreset = _prefs?.getString('motion_preset') ?? (_isLowSpecDevice ? 'reduced' : 'full');
        _hapticsEnabled = _prefs?.getBool('haptics_enabled') ?? true;
        _amoledMode = _prefs?.getBool('amoled_mode') ?? true;
        _themeMode = _prefs?.getString('theme_mode') ?? 'dark';
        _accentPreset = _prefs?.getString('accent_preset') ?? 'Cyan';
        _fontFamily = _prefs?.getString('font_family') ?? 'SF-Pro';
        _wallpaperPreset = _prefs?.getString('wallpaper_preset') ?? 'cloud';
        _audiophileMode = _prefs?.getBool('audiophile_mode') ?? false;
        _visualizerMode = _prefs?.getString('visualizer_mode') ?? 'hybrid';
      }

      // Verify custom wallpaper file still exists on disk
      if (_customWallpaperPath != null && !File(_customWallpaperPath!).existsSync()) {
        _customWallpaperPath = null;
        if (_wallpaperPreset == 'custom') {
          _wallpaperPreset = 'cloud';
        }
      }

      _lastScannedFolder = _prefs?.getString('last_scanned_folder');
      _recentFilePaths = _prefs?.getStringList('recent_file_paths') ?? [];
      await _loadLibraryCache();
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

  void setStrictLowPowerMode(bool enabled) {
    setLiquidGlass(!enabled);
  }

  void setAutoHardwareTiering(bool enabled) {
    // Preserved for binary/DevLab compatibility
    notifyListeners();
  }

  void setActiveTabIndex(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
    }
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

  void setFontFamily(String family) {
    if (_fontFamily != family) {
      _fontFamily = family;
      _prefs?.setString('font_family', family);
      notifyListeners();
    }
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

  Future<void> saveLibraryCache() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${docsDir.path}/library_cache.json');
      final data = {
        'folder': _lastScannedFolder,
        'timestamp': DateTime.now().toIso8601String(),
        'tracks': _sharedLibrary.map((t) => t.toJson()).toList(),
      };
      await cacheFile.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadLibraryCache() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${docsDir.path}/library_cache.json');
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        final folder = decoded['folder'] as String?;
        final trackList = (decoded['tracks'] as List<dynamic>?)
                ?.map((t) => FlacInfo.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [];
        if (trackList.isNotEmpty) {
          _sharedLibrary = trackList;
          if (folder != null) _lastScannedFolder = folder;
        }
      }
    } catch (_) {}
  }

  void setSharedLibrary(List<FlacInfo> tracks, String folder) {
    _sharedLibrary = tracks;
    _lastScannedFolder = folder;
    _prefs?.setString('last_scanned_folder', folder);
    saveLibraryCache();
    notifyListeners();
  }

  void setSharedLibraryLive(List<FlacInfo> tracks, String folder) {
    _sharedLibrary = tracks;
    _lastScannedFolder = folder;
    notifyListeners();
  }

  void updateTrackInLibrary(FlacInfo updated) {
    final idx = _sharedLibrary.indexWhere((t) => t.filePath == updated.filePath);
    if (idx != -1) {
      _sharedLibrary[idx] = updated;
      saveLibraryCache();
      notifyListeners();
    }
  }

  void removeTrackFromLibrary(String filePath) {
    _sharedLibrary.removeWhere((t) => t.filePath == filePath);
    saveLibraryCache();
    notifyListeners();
  }

  void addTrackToLibrary(FlacInfo track) {
    if (!_sharedLibrary.any((t) => t.filePath == track.filePath)) {
      _sharedLibrary.add(track);
      saveLibraryCache();
      notifyListeners();
    }
  }

  Future<void> clearLibraryCache() async {
    _sharedLibrary.clear();
    _lastScannedFolder = null;
    _prefs?.remove('last_scanned_folder');
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${docsDir.path}/library_cache.json');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (_) {}
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
