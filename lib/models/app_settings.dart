import 'package:flutter/material.dart';
import 'flac_info.dart';

class AppState extends ChangeNotifier {
  bool _isAmoled = false; // Default to Deep Cosmic Obsidian for genuine glass refraction
  bool _isLiquidGlass = true;
  bool _hapticsEnabled = true;
  String _themeMode = 'dark'; // 'system', 'light', 'dark'
  
  List<FlacInfo> _sharedLibrary = [];
  String? _lastScannedFolder;

  bool get isAmoled => _isAmoled;
  bool get isLiquidGlass => _isLiquidGlass;
  bool get hapticsEnabled => _hapticsEnabled;
  String get themeMode => _themeMode;
  List<FlacInfo> get sharedLibrary => _sharedLibrary;
  String? get lastScannedFolder => _lastScannedFolder;

  bool isCurrentDark(BuildContext context) {
    if (_themeMode == 'light') return false;
    if (_themeMode == 'dark') return true;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Color getBgColor(BuildContext context) {
    if (!isCurrentDark(context)) return const Color(0xFFF0F3F8);
    // Deep Cosmic Obsidian allows true light refraction through glass
    return _isAmoled ? Colors.black : const Color(0xFF080B11);
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.white.withOpacity(_isLiquidGlass ? 0.85 : 0.98);
    }
    // Luminous glass core: translucent, never solid muddy grey
    return _isLiquidGlass
        ? Colors.white.withOpacity(0.065)
        : const Color(0xFF111520);
  }

  Color getBorderColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.black.withOpacity(0.08);
    }
    return Colors.white.withOpacity(0.12);
  }

  Color getTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white : const Color(0xFF0F131C);
  }

  Color getSubTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white.withOpacity(0.55) : const Color(0xFF5E6778);
  }

  void setAmoled(bool value) {
    _isAmoled = value;
    notifyListeners();
  }

  void setLiquidGlass(bool value) {
    _isLiquidGlass = value;
    notifyListeners();
  }

  void setHaptics(bool value) {
    _hapticsEnabled = value;
    notifyListeners();
  }

  void setThemeMode(String value) {
    _themeMode = value;
    notifyListeners();
  }

  void setSharedLibrary(List<FlacInfo> tracks, String folder) {
    _sharedLibrary = tracks;
    _lastScannedFolder = folder;
    notifyListeners();
  }

  void removeTrackFromLibrary(String filePath) {
    _sharedLibrary.removeWhere((t) => t.filePath == filePath);
    notifyListeners();
  }
}

final appState = AppState();
