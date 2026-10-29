import 'package:flutter/material.dart';
import 'flac_info.dart';

class AppState extends ChangeNotifier {
  bool _isAmoled = true;
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
    if (!isCurrentDark(context)) return const Color(0xFFF2F4F8);
    return _isAmoled ? Colors.black : const Color(0xFF0D1017);
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.white.withOpacity(_isLiquidGlass ? 0.80 : 0.95);
    }
    return _isLiquidGlass
        ? Colors.white.withOpacity(0.055)
        : const Color(0xFF131722);
  }

  Color getBorderColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.black.withOpacity(0.08);
    }
    return Colors.white.withOpacity(0.09);
  }

  Color getTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white : const Color(0xFF11141A);
  }

  Color getSubTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white.withOpacity(0.55) : const Color(0xFF5A6272);
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
