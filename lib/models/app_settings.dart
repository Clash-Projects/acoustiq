import 'package:flutter/material.dart';
import 'flac_info.dart';
import '../ui/theme/colors.dart';

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
    if (!isCurrentDark(context)) return AppColors.lightCanvas;
    // AMOLED Mode: #000000 vs Graphite Mode: #121212
    return _amoledMode ? AppColors.amoledCanvas : AppColors.graphiteCanvas;
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return _isLiquidGlass
          ? Colors.white.withOpacity(0.85)
          : AppColors.lightSurface;
    }
    // Dark mode surfaces
    if (_amoledMode) {
      return _isLiquidGlass
          ? const Color(0xE6101010)
          : const Color(0xFF141414);
    } else {
      return _isLiquidGlass
          ? const Color(0xE61C1C1C)
          : const Color(0xFF202020);
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
