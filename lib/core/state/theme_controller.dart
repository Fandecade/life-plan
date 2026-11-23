import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// 主题模式控制：跟随系统 / 浅色 / 深色，持久化到本地设置 box。
class ThemeController extends ChangeNotifier {
  ThemeController(this._settings) {
    _mode = _readMode();
  }

  static const String _key = 'app.themeMode';

  final Box<dynamic> _settings;
  late ThemeMode _mode;

  ThemeMode get mode => _mode;

  String get label => labelFor(_mode);

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _settings.put(_key, mode.name);
    notifyListeners();
  }

  ThemeMode _readMode() {
    final Object? stored = _settings.get(_key);
    if (stored is String) {
      for (final ThemeMode mode in ThemeMode.values) {
        if (mode.name == stored) return mode;
      }
    }
    return ThemeMode.system;
  }

  static String labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }
}