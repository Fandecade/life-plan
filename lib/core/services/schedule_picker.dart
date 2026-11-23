import 'package:flutter/material.dart';

/// 统一的「选择日期 + 开始时间」交互，任务池与详情抽屉共用。
Future<DateTime?> pickScheduleStart(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final DateTime now = DateTime.now();
  final DateTime initial = initialDate ?? now;

  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: now.subtract(const Duration(days: 180)),
    lastDate: now.add(const Duration(days: 730)),
    helpText: '选择日期',
    cancelText: '取消',
    confirmText: '下一步',
  );
  if (date == null || !context.mounted) return null;

  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(
      DateTime(initial.year, initial.month, initial.day, 9),
    ),
    helpText: '选择开始时间',
    cancelText: '取消',
    confirmText: '确定',
  );
  if (time == null || !context.mounted) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}