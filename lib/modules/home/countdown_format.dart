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

/// 目标时间标签，如「11/28 18:00」。
String countdownTargetLabel(DateTime target) =>
    '${target.month}/${target.day} ${_two(target.hour)}:${_two(target.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');