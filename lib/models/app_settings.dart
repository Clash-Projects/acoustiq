import 'package:flutter/material.dart';
import 'flac_info.dart';
import '../ui/theme/colors.dart';

class AppState extends ChangeNotifier {
  bool _isLiquidGlass = true;
  bool _hapticsEnabled = true;
  bool _amoledMode = true;
  String _themeMode = 'dark'; // 'system', 'light', 'dark'
  String _accentPreset = 'Ocean'; // 'Crimson', 'Violet', 'Ocean', 'Sage', 'Amber', 'Rose', 'Mono', 'Custom'
  Color _customColor = const Color(0xFF2196C6);
  
  List<FlacInfo> _sharedLibrary = [];
  String? _lastScannedFolder;

  bool get isLiquidGlass => _isLiquidGlass;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get amoledMode => _amoledMode;
  String get themeMode => _themeMode;
  String get accentPreset => _accentPreset;
  Color get customColor => _customColor;
  List<FlacInfo> get sharedLibrary => _sharedLibrary;
  String? get lastScannedFolder => _lastScannedFolder;

  Color getAccentColor(BuildContext context) {
    switch (_accentPreset) {
      case 'Crimson':
        return const Color(0xFFE03030);
      case 'Violet':
        return const Color(0xFF7C4DFF);
      case 'Ocean':
        return const Color(0xFF2196C6);
      case 'Sage':
        return const Color(0xFF6B9E6B);
      case 'Amber':
        return const Color(0xFFE0A030);
      case 'Rose':
        return const Color(0xFFE0507A);
      case 'Mono':
        return isCurrentDark(context) ? Colors.white : const Color(0xFF101828);
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
    // AMOLED Mode: #000000 vs Graphite Mode: #12161A
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

  void setAccentPreset(String preset, [Color? customColor]) {
    _accentPreset = preset;
    if (customColor != null) {
      _customColor = customColor;
    }
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
