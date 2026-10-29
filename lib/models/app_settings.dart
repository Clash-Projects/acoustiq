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
    if (!isCurrentDark(context)) return const Color(0xFFF2F5FA);
    // Deep Frosted Obsidian canvas allowing true optical light diffusion
    return const Color(0xFF090D16);
  }

  Color getCardBgColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.white.withOpacity(_isLiquidGlass ? 0.82 : 0.96);
    }
    // Luminous frosted core: translucent, never flat muddy grey
    return _isLiquidGlass
        ? Colors.white.withOpacity(0.065)
        : const Color(0xFF131826);
  }

  Color getBorderColor(BuildContext context) {
    if (!isCurrentDark(context)) {
      return Colors.black.withOpacity(0.10);
    }
    return Colors.white.withOpacity(0.16);
  }

  Color getTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white : const Color(0xFF0F131C);
  }

  Color getSubTextColor(BuildContext context) {
    return isCurrentDark(context) ? Colors.white.withOpacity(0.58) : const Color(0xFF5E6778);
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
