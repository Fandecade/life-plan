import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';

/// 安排结果：起始时间与时长（都可随手改，不写死）。
class ReviewScheduleResult {
  const ReviewScheduleResult({required this.start, required this.minutes});

  final DateTime start;
  final int minutes;
}

/// 自由安排日期、时间与时长：复盘里改期与时间盒共用同一套时间块语义。
Future<ReviewScheduleResult?> showReviewScheduleDialog(
  BuildContext context, {
  required DateTime initial,
  int? initialMinutes,
  String title = '安排时间',
  String hint = '确认后同步到时间盒',
  bool showDuration = true,
}) {
  return showDialog<ReviewScheduleResult>(
    context: context,
    builder: (BuildContext dialogContext) => _ReviewScheduleDialog(
      initial: initial,
      initialMinutes: initialMinutes,
      title: title,
      hint: hint,
      showDuration: showDuration,
    ),
  );
}

class _ReviewScheduleDialog extends StatefulWidget {
  const _ReviewScheduleDialog({
    required this.initial,
    required this.initialMinutes,
    required this.title,
    required this.hint,
    required this.showDuration,
  });

  final DateTime initial;
  final int? initialMinutes;
  final String title;
  final String hint;
  final bool showDuration;

  @override
  State<_ReviewScheduleDialog> createState() => _ReviewScheduleDialogState();
}

class _ReviewScheduleDialogState extends State<_ReviewScheduleDialog> {
  late DateTime _day;
  late int _hour;
  late int _minute;
  late int _minutes;
  late List<int> _durations;

  @override
  void initState() {
    super.initState();
    _day = AppDate.startOfDay(widget.initial);
    final int rounded =
        ((widget.initial.minute + 29) ~/ 30) * 30;
    int hour = widget.initial.hour;
    int minute = rounded;
    if (minute >= 60) {
      hour += 1;
      minute = 0;
    }
    if (hour > 23) {
      hour = 23;
      minute = 30;
    }
    _hour = hour;
    _minute = minute;
    final int initialMinutes = widget.initialMinutes ?? 30;
    _minutes = initialMinutes;
    _durations = <int>[10, 15, 20, 30, 45, 60];
    if (!_durations.contains(initialMinutes)) {
      _durations = <int>[initialMinutes, ..._durations]
        ..sort((int a, int b) => a.compareTo(b));
    }
  }

  List<DateTime> get _quickDays {
    final DateTime today = AppDate.startOfDay(DateTime.now());
    return <DateTime>[
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
      today.add(const Duration(days: 7)),
    ];
  }

  List<String> get _quickLabels => const <String>['今天', '明天', '后天', '一周后'];

  void _shiftDay(int direction) {
    setState(() => _day = _day.add(Duration(days: direction)));
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<String> times = <String>[
      for (int minutes = 6 * 60; minutes <= 23 * 60 + 30; minutes += 30)
        '${AppDate.two(minutes ~/ 60)}:${AppDate.two(minutes % 60)}',
    ];

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
      title: Text(widget.title, style: context.texts.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppIconButton(
                  icon: Icons.chevron_left_rounded,
                  iconSize: 18,
                  size: 26,
                  tooltip: '前一天',
                  onPressed: () => _shiftDay(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      AppDate.monthDayWithWeekday(_day),
                      style: context.texts.titleSmall,
                    ),
                  ),
                ),
                AppIconButton(
                  icon: Icons.chevron_right_rounded,
                  iconSize: 18,
                  size: 26,
                  tooltip: '后一天',
                  onPressed: () => _shiftDay(1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (int i = 0; i < _quickDays.length; i++)
                  AppChip(
                    label: _quickLabels[i],
                    dense: true,
                    filled: AppDate.isSameDay(_quickDays[i], _day),
                    color: palette.accent,
                    onTap: () => setState(() => _day = _quickDays[i]),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('时间', style: context.texts.labelSmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final String time in times)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: AppChip(
                          label: time,
                          dense: true,
                          filled: time ==
                              '${AppDate.two(_hour)}:${AppDate.two(_minute)}',
                          color: palette.accent,
                          onTap: () => setState(() {
                            final List<String> parts = time.split(':');
                            _hour = int.parse(parts[0]);
                            _minute = int.parse(parts[1]);
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showDuration) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text('时长', style: context.texts.labelSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final int minutes in _durations)
                    AppChip(
                      label: '$minutes 分钟',
                      dense: true,
                      filled: minutes == _minutes,
                      color: palette.accent,
                      onTap: () => setState(() => _minutes = minutes),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(widget.hint, style: context.texts.labelSmall),
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
        AppPrimaryButton(
          label: '确认安排',
          onPressed: () => Navigator.of(context).pop(
            ReviewScheduleResult(
              start: DateTime(_day.year, _day.month, _day.day, _hour, _minute),
              minutes: _minutes,
            ),
          ),
        ),
      ],
    );
  }
}