import 'package:flutter/material.dart';
import 'flac_info.dart';

class AppState extends ChangeNotifier {
  bool _isLiquidGlass = true;
  bool _hapticsEnabled = true;
  bool _amoledMode = true;
  String _themeMode = 'dark'; // 'system', 'light', 'dark'
  
  List<FlacInfo> _sharedLibrary = [];
  String? _lastScannedFolder;

  bool get isLiquidGlass => _isLiquidGlass;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get amoledMode => _amoledMode;
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
    return _amoledMode ? const Color(0xFF000000) : const Color(0xFF0C0C0C);
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.white.withOpacity(_isLiquidGlass ? 0.85 : 0.98);
    }
    // True LastWave Obsidian Surface (R = G = B = 20)
    return const Color(0xFF141414);
  }

  Color getTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white : const Color(0xFF111111);
  }

  Color getSubTextColor(BuildContext context) {
    return isCurrentDark(context) ? const Color(0x99FFFFFF) : const Color(0x99000000);
  }

  void setLiquidGlass(bool value) {
    _isLiquidGlass = value;
    notifyListeners();
  }

  void setHaptics(bool value) {
    _hapticsEnabled = value;
    notifyListeners();
  }

  void setAmoledMode(bool value) {
    _amoledMode = value;
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
