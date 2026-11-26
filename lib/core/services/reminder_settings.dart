import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 提醒设置：应用内与系统通知可分别开关，提前量默认「到点提醒」。
///
/// 只负责读写偏好，不做任何调度；调度与去重在 [ReminderService]。
class ReminderSettings extends ChangeNotifier {
  ReminderSettings(this._settings) {
    _inAppEnabled = _readBool(_inAppKey, true);
    _systemEnabled = _readBool(_systemKey, _readBool(_legacyEnabledKey, true));
    _leadMinutes = _readLeadMinutes();
    _habitDigestMinutes = _readMinutes(_habitDigestKey, 20 * 60 + 30);
    _dateOnlyMinutes = _readMinutes(_dateOnlyKey, 9 * 60);
  }

  static const String _inAppKey = 'app.reminder.inAppEnabled';
  static const String _systemKey = 'app.reminder.systemEnabled';
  static const String _legacyEnabledKey = 'app.reminder.enabled';
  static const String _leadKey = 'app.reminder.leadMinutes';
  static const String _habitDigestKey = 'app.reminder.habitDigestMinutes';
  static const String _dateOnlyKey = 'app.reminder.dateOnlyMinutes';

  static const List<int> leadOptions = <int>[0, 5, 10, 15, 30];

  /// 自定义提前量的上限：一天。
  static const int maxLeadMinutes = 24 * 60;

  final Box<dynamic> _settings;
  bool _inAppEnabled = true;
  bool _systemEnabled = true;
  int _leadMinutes = 0;
  int _habitDigestMinutes = 20 * 60 + 30;
  int _dateOnlyMinutes = 9 * 60;

  /// 应用内横幅提醒。
  bool get inAppEnabled => _inAppEnabled;

  /// 系统本地通知（Android / macOS）。
  bool get systemEnabled => _systemEnabled;

  int get leadMinutes => _leadMinutes;

  int get habitDigestMinutes => _habitDigestMinutes;

  int get dateOnlyMinutes => _dateOnlyMinutes;

  String get leadLabel =>
      _leadMinutes == 0 ? '到点提醒' : '提前 $_leadMinutes 分钟';

  String get habitDigestLabel => minutesLabel(_habitDigestMinutes);

  String get dateOnlyLabel => minutesLabel(_dateOnlyMinutes);

  /// 设置页入口的摘要，例如「应用内 + 系统通知 · 到点提醒」。
  String get summaryLabel {
    final List<String> channels = <String>[];
    if (_inAppEnabled) channels.add('应用内');
    if (_systemEnabled) channels.add('系统通知');
    if (channels.isEmpty) return '已关闭';
    return '${channels.join(' + ')} · $leadLabel';
  }

  static String minutesLabel(int minutes) {
    final int hour = (minutes ~/ 60).clamp(0, 23);
    final int minute = (minutes % 60).clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> setInAppEnabled(bool value) async {
    if (_inAppEnabled == value) return;
    _inAppEnabled = value;
    notifyListeners();
    await _settings.put(_inAppKey, value);
  }

  Future<void> setSystemEnabled(bool value) async {
    if (_systemEnabled == value) return;
    _systemEnabled = value;
    notifyListeners();
    await _settings.put(_systemKey, value);
  }

  Future<void> setLeadMinutes(int value) async {
    if (value < 0 || value > maxLeadMinutes || _leadMinutes == value) return;
    _leadMinutes = value;
    notifyListeners();
    await _settings.put(_leadKey, value);
  }

  Future<void> setHabitDigestMinutes(int value) async {
    final int normalized = value.clamp(0, 23 * 60 + 59);
    if (_habitDigestMinutes == normalized) return;
    _habitDigestMinutes = normalized;
    notifyListeners();
    await _settings.put(_habitDigestKey, normalized);
  }

  Future<void> setDateOnlyMinutes(int value) async {
    final int normalized = value.clamp(0, 23 * 60 + 59);
    if (_dateOnlyMinutes == normalized) return;
    _dateOnlyMinutes = normalized;
    notifyListeners();
    await _settings.put(_dateOnlyKey, normalized);
  }

  bool _readBool(String key, bool fallback) {
    final Object? stored = _settings.get(key);
    return stored is bool ? stored : fallback;
  }

  int _readMinutes(String key, int fallback) {
    final Object? stored = _settings.get(key);
    if (stored is int && stored >= 0 && stored < 24 * 60) return stored;
    return fallback;
  }

  int _readLeadMinutes() {
    final Object? stored = _settings.get(_leadKey);
    if (stored is int && stored >= 0 && stored <= maxLeadMinutes) {
      return stored;
    }
    return 0;
  }
}