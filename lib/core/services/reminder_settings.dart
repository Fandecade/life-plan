import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 提醒设置：总开关、时间盒提前量、微习惯汇总与只定日期任务提醒时间。
///
/// 只负责读写偏好，不做任何调度；调度与去重在 [ReminderService]。
class ReminderSettings extends ChangeNotifier {
  ReminderSettings(this._settings) {
    _enabled = _readBool(_enabledKey, true);
    _leadMinutes = _readLeadMinutes();
    _habitDigestMinutes = _readMinutes(_habitDigestKey, 20 * 60 + 30);
    _dateOnlyMinutes = _readMinutes(_dateOnlyKey, 9 * 60);
  }

  static const String _enabledKey = 'app.reminder.enabled';
  static const String _leadKey = 'app.reminder.leadMinutes';
  static const String _habitDigestKey = 'app.reminder.habitDigestMinutes';
  static const String _dateOnlyKey = 'app.reminder.dateOnlyMinutes';

  static const List<int> leadOptions = <int>[0, 5, 10, 15, 30];

  final Box<dynamic> _settings;
  bool _enabled = true;
  int _leadMinutes = 10;
  int _habitDigestMinutes = 20 * 60 + 30;
  int _dateOnlyMinutes = 9 * 60;

  bool get enabled => _enabled;

  int get leadMinutes => _leadMinutes;

  int get habitDigestMinutes => _habitDigestMinutes;

  int get dateOnlyMinutes => _dateOnlyMinutes;

  String get habitDigestLabel => minutesLabel(_habitDigestMinutes);

  String get dateOnlyLabel => minutesLabel(_dateOnlyMinutes);

  static String minutesLabel(int minutes) {
    final int hour = (minutes ~/ 60).clamp(0, 23);
    final int minute = (minutes % 60).clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    await _settings.put(_enabledKey, value);
  }

  Future<void> setLeadMinutes(int value) async {
    if (!leadOptions.contains(value) || _leadMinutes == value) return;
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
    if (stored is int && leadOptions.contains(stored)) return stored;
    return 10;
  }
}