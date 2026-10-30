import 'package:flutter/material.dart';
import 'flac_info.dart';

class AppState extends ChangeNotifier {
  bool _isLiquidGlass = true;
  bool _hapticsEnabled = true;
  String _themeMode = 'dark'; // 'system', 'light', 'dark'
  
  List<FlacInfo> _sharedLibrary = [];
  String? _lastScannedFolder;

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
    if (!isCurrentDark(context)) return const Color(0xFFF5F5F7);
    // Absolute Pure Neutral Obsidian Canvas (R = G = B = 8, ZERO navy blue or teal subpixel glow)
    return const Color(0xFF080808);
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.white.withOpacity(_isLiquidGlass ? 0.78 : 0.95);
    }
    // Pure neutral obsidian charcoal card core (R = G = B = 20)
    return _isLiquidGlass
        ? const Color(0xFF141414).withOpacity(0.72)
        : const Color(0xFF141414);
  }

  Color getBorderColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.black.withOpacity(0.08);
    }
    // Sub-pixel hairline perimeter: neutral white with subtle opacity
    return Colors.white.withOpacity(0.11);
  }

  Color getTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white : const Color(0xFF111111);
  }

  Color getSubTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white.withOpacity(0.60) : const Color(0xFF666666);
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
