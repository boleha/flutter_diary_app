import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeType {
  light,
  dark,
  system,
}

enum ImageStorageMode {
  copy, // 复制到应用文件夹
  reference, // 只保存引用
}

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _imageStorageModeKey = 'image_storage_mode';

  // 单例模式
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ThemeModeType _themeMode = ThemeModeType.system;
  ImageStorageMode _imageStorageMode = ImageStorageMode.copy;
  bool _isInitialized = false;

  ThemeModeType get themeMode => _themeMode;
  ImageStorageMode get imageStorageMode => _imageStorageMode;

  // 确保只初始化一次
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await _loadSettings();
    _isInitialized = true;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 2;
    _themeMode = ThemeModeType.values[themeIndex];
    final storageModeIndex = prefs.getInt(_imageStorageModeKey) ?? 0;
    _imageStorageMode = ImageStorageMode.values[storageModeIndex];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeModeType mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  /// 循环切换主题模式：system -> light -> dark -> system
  Future<void> cycleThemeMode() async {
    final next = switch (_themeMode) {
      ThemeModeType.system => ThemeModeType.light,
      ThemeModeType.light => ThemeModeType.dark,
      ThemeModeType.dark => ThemeModeType.system,
    };
    await setThemeMode(next);
  }

  Future<void> setImageStorageMode(ImageStorageMode mode) async {
    _imageStorageMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_imageStorageModeKey, mode.index);
    notifyListeners();
  }

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case ThemeModeType.light:
        return ThemeMode.light;
      case ThemeModeType.dark:
        return ThemeMode.dark;
      case ThemeModeType.system:
        return ThemeMode.system;
    }
  }
}
