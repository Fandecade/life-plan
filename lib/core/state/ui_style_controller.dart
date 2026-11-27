import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../app/theme/ui_style.dart';

/// 界面风格偏好：经典/新版、新版主题色、是否启用玻璃模糊。
class UiStyleController extends ChangeNotifier {
  UiStyleController(this._settings) {
    _style = _readStyle();
    _accent = _readAccent();
    _glassEnabled = _readBool(_glassKey, true);
    _visionView = _readVisionView();
  }

  static const String _styleKey = 'app.ui.style';
  static const String _accentKey = 'app.ui.accent';
  static const String _glassKey = 'app.ui.glassEnabled';
  static const String _visionViewKey = 'app.ui.visionView';

  final Box<dynamic> _settings;
  AppUiStyle _style = AppUiStyle.classic;
  AppAccentTheme _accent = AppAccentTheme.sage;
  bool _glassEnabled = true;
  VisionViewMode _visionView = VisionViewMode.map;

  AppUiStyle get style => _style;

  AppAccentTheme get accent => _accent;

  bool get glassEnabled => _glassEnabled;

  VisionViewMode get visionView => _visionView;

  bool get isRefresh => _style == AppUiStyle.refresh;

  Future<void> setStyle(AppUiStyle value) async {
    if (_style == value) return;
    _style = value;
    notifyListeners();
    await _settings.put(_styleKey, value.name);
  }

  Future<void> setAccent(AppAccentTheme value) async {
    if (_accent == value) return;
    _accent = value;
    notifyListeners();
    await _settings.put(_accentKey, value.name);
  }

  Future<void> setGlassEnabled(bool value) async {
    if (_glassEnabled == value) return;
    _glassEnabled = value;
    notifyListeners();
    await _settings.put(_glassKey, value);
  }

  Future<void> setVisionView(VisionViewMode value) async {
    if (_visionView == value) return;
    _visionView = value;
    notifyListeners();
    await _settings.put(_visionViewKey, value.name);
  }

  AppUiStyle _readStyle() {
    final Object? stored = _settings.get(_styleKey);
    if (stored is String) {
      for (final AppUiStyle value in AppUiStyle.values) {
        if (value.name == stored) return value;
      }
    }
    return AppUiStyle.classic;
  }

  AppAccentTheme _readAccent() {
    final Object? stored = _settings.get(_accentKey);
    if (stored is String) {
      for (final AppAccentTheme value in AppAccentTheme.values) {
        if (value.name == stored) return value;
      }
    }
    return AppAccentTheme.sage;
  }

  bool _readBool(String key, bool fallback) {
    final Object? stored = _settings.get(key);
    return stored is bool ? stored : fallback;
  }

  VisionViewMode _readVisionView() {
    final Object? stored = _settings.get(_visionViewKey);
    if (stored is String) {
      for (final VisionViewMode value in VisionViewMode.values) {
        if (value.name == stored) return value;
      }
    }
    return VisionViewMode.map;
  }
}