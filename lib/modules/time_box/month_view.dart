import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/state_views.dart';
import 'time_box_common.dart';

/// 月视图：极简日历网格，只显示工时密度与块数，点击钻取到日视图。
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.anchor,
    required this.blocks,
    required this.onDrillDay,
  });

  final DateTime anchor;
  final List<TimeBlock> blocks;
  final ValueChanged<DateTime> onDrillDay;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<DateTime> days = monthGridDays(anchor);
    final int weeks = days.length ~/ 7;

    final List<TimeBlock> monthBlocks = blocks
        .where(
          (TimeBlock block) =>
              block.startAt.year == anchor.year &&
              block.startAt.month == anchor.month,
        )
        .toList(growable: false);

    final Map<String, int> minutesByDay = <String, int>{};
    final Map<String, int> countByDay = <String, int>{};
    for (final TimeBlock block in monthBlocks) {
      final String key = AppDate.dateKey(block.startAt);
      minutesByDay[key] = (minutesByDay[key] ?? 0) + block.plannedMinutes;
      countByDay[key] = (countByDay[key] ?? 0) + 1;
    }

    return Column(
      children: <Widget>[
        _summary(context, monthBlocks),
        Divider(color: palette.hairline, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              for (final String label in weekdayShortLabels)
                Expanded(
                  child: Center(
                    child: Text(label, style: context.texts.labelSmall),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: <Widget>[
                for (int week = 0; week < weeks; week++)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        for (int index = 0; index < 7; index++)
                          Expanded(
                            child: _cell(
                              context,
                              days[week * 7 + index],
                              minutesByDay[AppDate.dateKey(days[week * 7 + index])] ?? 0,
                              countByDay[AppDate.dateKey(days[week * 7 + index])] ?? 0,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, List<TimeBlock> monthBlocks) {
    final int minutes = totalMinutesOf(monthBlocks);
    final int completed =
        monthBlocks.where((TimeBlock block) => block.isCompleted).length;
    final int activeDays = monthBlocks
        .map((TimeBlock block) => AppDate.dateKey(block.startAt))
        .toSet()
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          _metric(context, '总投入', minutes > 0 ? AppDate.durationLabel(minutes) : '—'),
          _metric(context, '时间块', '${monthBlocks.length}'),
          _metric(context, '已完成', '$completed'),
          _metric(context, '有安排', '$activeDays 天'),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final AppPalette palette = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: context.texts.titleSmall?.copyWith(
              color: value == '—' ? palette.textTertiary : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    int minutes,
    int count,
  ) {
    final AppPalette palette = context.palette;
    final bool inMonth = day.month == anchor.month;
    final bool isToday = AppDate.isSameDay(day, DateTime.now());
    final bool isPast = AppDate.startOfDay(day).isBefore(
          AppDate.startOfDay(DateTime.now()),
        );

    return InkWell(
      onTap: () => onDrillDay(day),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: inMonth ? null : palette.surfaceMuted.withValues(alpha: 0.22),
          border: Border(
            right: BorderSide(color: palette.hairline),
            bottom: BorderSide(color: palette.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${day.day}',
                  style: context.texts.labelMedium?.copyWith(
                    color: isToday
                        ? palette.accent
                        : (inMonth
                            ? (isPast ? palette.textSecondary : palette.textPrimary)
                            : palette.textTertiary),
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isToday) ...<Widget>[
                  const SizedBox(width: 4),
                  StatusDot(color: palette.accent, size: 3.5),
                ],
                const Spacer(),
                if (count > 0)
                  Text('$count', style: context.texts.labelSmall),
              ],
            ),
            const Spacer(),
            if (minutes > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(color: palette.surfaceMuted),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: heatForMinutes(minutes),
                        child: ColoredBox(
                          color: palette.accent.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}