import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';

/// 排期结果：只定日期（dateOnly）或具体开始时间。
class SchedulePickResult {
  const SchedulePickResult({
    required this.start,
    this.dateOnly = false,
    this.clearDate = false,
  });

  final DateTime start;
  final bool dateOnly;

  /// true = 清除该任务已有的计划日期（不排期、不建块）。
  final bool clearDate;
}

/// 统一的「选择日期 +（可选）开始时间」交互，任务池与详情抽屉共用。
///
/// 保留日历 + 表盘的原流程，并在日历底部增加「只安排到这一天」：
/// 不进入时间选择，直接作为当日待办。
Future<SchedulePickResult?> pickScheduleResult(
  BuildContext context, {
  DateTime? initialDate,
  bool allowClearDate = false,
}) async {
  final DateTime initial = initialDate ?? DateTime.now();
  final _DateChoice? choice = await showDialog<_DateChoice>(
    context: context,
    builder: (BuildContext dialogContext) => _ScheduleDateDialog(
      initial: initial,
      allowClearDate: allowClearDate,
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice.clearDate) {
    return SchedulePickResult(
      start: DateTime.now(),
      clearDate: true,
    );
  }
  if (choice.dateOnly) {
    return SchedulePickResult(
      start: DateTime(choice.date.year, choice.date.month, choice.date.day),
      dateOnly: true,
    );
  }

  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
    helpText: '选择开始时间',
    cancelText: '取消',
    confirmText: '排入',
  );
  if (time == null || !context.mounted) return null;
  return SchedulePickResult(
    start: DateTime(
      choice.date.year,
      choice.date.month,
      choice.date.day,
      time.hour,
      time.minute,
    ),
  );
}

/// 兼容旧调用：只关心具体开始时间时使用。
Future<DateTime?> pickScheduleStart(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final SchedulePickResult? result = await pickScheduleResult(
    context,
    initialDate: initialDate,
  );
  return result?.start;
}

class _DateChoice {
  const _DateChoice({
    required this.date,
    required this.dateOnly,
    this.clearDate = false,
  });

  final DateTime date;
  final bool dateOnly;
  final bool clearDate;
}

class _ScheduleDateDialog extends StatefulWidget {
  const _ScheduleDateDialog({
    required this.initial,
    required this.allowClearDate,
  });

  final DateTime initial;
  final bool allowClearDate;

  @override
  State<_ScheduleDateDialog> createState() => _ScheduleDateDialogState();
}

class _ScheduleDateDialogState extends State<_ScheduleDateDialog> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double availableWidth = MediaQuery.sizeOf(context).width - 96;
    final bool narrow = availableWidth < 480;
    final double width = math.max(320, math.min(560, availableWidth));

    final Widget calendar = SizedBox(
      height: 340,
      child: CalendarDatePicker(
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onDateChanged: (DateTime value) => setState(() => _date = value),
      ),
    );

    final Widget summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          AppDate.monthDayWithWeekday(_date),
          style: context.texts.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '可以选择具体开始时间，也可以只安排到这一天。',
          style: context.texts.bodySmall,
        ),
      ],
    );

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      title: Text('排入时间盒', style: context.texts.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: width,
        child: narrow
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  summary,
                  const SizedBox(height: AppSpacing.sm),
                  calendar,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 140, child: summary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: calendar),
                ],
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (widget.allowClearDate)
          AppGhostButton(
            label: '清除日期',
            onPressed: () => Navigator.of(context).pop(
              _DateChoice(
                date: _date,
                dateOnly: true,
                clearDate: true,
              ),
            ),
          ),
        AppGhostButton(
          label: '只安排到这一天',
          onPressed: () => Navigator.of(context).pop(
            _DateChoice(date: _date, dateOnly: true),
          ),
        ),
        AppPrimaryButton(
          label: '下一步',
          onPressed: () => Navigator.of(context).pop(
            _DateChoice(date: _date, dateOnly: false),
          ),
        ),
      ],
    );
  }
}