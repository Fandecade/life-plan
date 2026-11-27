import 'package:flutter/material.dart';

/// 倒计时剩余时间的展示格式。
///
/// > 24h：「3 天 04:12」；1–24h：「04:12:33」；< 1h：「12:33」；到期：「已到期」。
String formatCountdown(Duration remaining) {
  if (remaining.inSeconds <= 0) return '已到期';
  final int days = remaining.inDays;
  final int hours = remaining.inHours % 24;
  final int minutes = remaining.inMinutes % 60;
  final int seconds = remaining.inSeconds % 60;
  if (days > 0) return '$days 天 ${_two(hours)}:${_two(minutes)}';
  if (hours > 0) {
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  }
  return '${_two(minutes)}:${_two(seconds)}';
}

/// 目标日期与今天相差的天数（只比较日期）。
int countdownDayDiff(DateTime target, DateTime now) {
  final DateTime t = DateTime(target.year, target.month, target.day);
  final DateTime n = DateTime(now.year, now.month, now.day);
  return t.difference(n).inDays;
}

/// 只选日期时的剩余展示：「已到期」/「今天」/「剩 N 天」。
String formatDateOnlyCountdown(DateTime target, DateTime now) {
  final int days = countdownDayDiff(target, now);
  if (days < 0) return '已到期';
  if (days == 0) return '今天';
  return '剩 $days 天';
}

/// 目标时间标签，如「11/28 18:00」；只选日期时为「11/28」。
String countdownTargetLabel(DateTime target, {bool dateOnly = false}) {
  if (dateOnly) return '${target.month}/${target.day}';
  return '${target.month}/${target.day} ${_two(target.hour)}:${_two(target.minute)}';
}

/// 自动变色的紧迫度四档：绿（充裕）→ 黄（7 天内）→ 橙（3 天内）→ 红（1 天内 / 已到期）。
const Color countdownCalm = Color(0xFF5B9A6F);
const Color countdownSoon = Color(0xFFD7B94C);
const Color countdownNear = Color(0xFFE08A3C);
const Color countdownUrgent = Color(0xFFD9534F);

/// 倒计时颜色：自定义固定色优先；否则按剩余时间在绿 → 黄 → 橙 → 红之间取档。
Color countdownColorFor({
  required DateTime target,
  DateTime? now,
  bool dateOnly = false,
  String? customHex,
}) {
  final Color? custom = parseHexColor(customHex);
  if (custom != null) return custom;
  final DateTime current = now ?? DateTime.now();
  if (dateOnly) {
    final int days = countdownDayDiff(target, current);
    if (days <= 1) return countdownUrgent;
    if (days <= 3) return countdownNear;
    if (days <= 7) return countdownSoon;
    return countdownCalm;
  }
  final Duration remaining = target.difference(current);
  if (remaining <= const Duration(days: 1)) return countdownUrgent;
  if (remaining <= const Duration(days: 3)) return countdownNear;
  if (remaining <= const Duration(days: 7)) return countdownSoon;
  return countdownCalm;
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final String value = hex.replaceFirst('#', '');
  if (value.length != 6) return null;
  final int? parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

String? hexFromColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _two(int value) => value.toString().padLeft(2, '0');