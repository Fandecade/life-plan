import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'time_box_common.dart';

/// 月视图：看节奏密度、关键复习节点与周期复盘，不塞细碎任务标题。
///
/// 点击日期先弹出「当天简报」（负荷 / 块概览 / 复习节点），
/// 再由简报里的按钮进入当日时间盒。
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.anchor,
    required this.blocks,
    required this.reviewDays,
    required this.consolidatingCount,
    required this.completedCount,
    required this.reviewed,
    required this.dueTasksByDay,
    this.habitDotsByDay = const <String, int>{},
    required this.onEnterDay,
  });

  final DateTime anchor;
  final List<TimeBlock> blocks;

  /// 有到期间隔复习的日期（dateKey）。
  final Set<String> reviewDays;
  final int consolidatingCount;
  final int completedCount;
  final bool reviewed;

  /// 当天截止的任务标题（dateKey → titles）。
  final Map<String, List<String>> dueTasksByDay;

  /// 每日完成的微习惯数（dateKey → 次数），月历底部微节律点。
  final Map<String, int> habitDotsByDay;
  final ValueChanged<DateTime> onEnterDay;

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
                              minutesByDay[AppDate.dateKey(
                                    days[week * 7 + index],
                                  )] ??
                                  0,
                              countByDay[AppDate.dateKey(
                                    days[week * 7 + index],
                                  )] ??
                                  0,
                              dueTasksByDay[AppDate.dateKey(
                                    days[week * 7 + index],
                                  )] ??
                                  const <String>[],
                              habitDotsByDay[AppDate.dateKey(
                                    days[week * 7 + index],
                                  )] ??
                                  0,
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
    final AppPalette palette = context.palette;
    final int minutes = totalMinutesOf(monthBlocks);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          _metric(
            context,
            '总投入',
            minutes > 0 ? AppDate.durationLabel(minutes) : '—',
          ),
          _metric(context, '时间块', '${monthBlocks.length}'),
          _metric(context, '巩固中', '$consolidatingCount'),
          _metric(context, '已完成', '$completedCount'),
          const SizedBox(width: AppSpacing.sm),
          AppChip(
            label: reviewed ? '已复盘' : '待复盘',
            dense: true,
            filled: true,
            color: reviewed ? palette.success : palette.warning,
          ),
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
    List<String> dueTasks,
    int habitDots,
  ) {
    final AppPalette palette = context.palette;
    final bool inMonth = day.month == anchor.month;
    final bool isToday = AppDate.isSameDay(day, DateTime.now());
    final bool isPast = AppDate.startOfDay(day)
        .isBefore(AppDate.startOfDay(DateTime.now()));
    final bool hasReview = reviewDays.contains(AppDate.dateKey(day));

    return InkWell(
      onTap: () => _showDayBrief(context, day),
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
                              ? (isPast
                                    ? palette.textSecondary
                                    : palette.textPrimary)
                              : palette.textTertiary),
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isToday) ...<Widget>[
                  const SizedBox(width: 4),
                  StatusDot(color: palette.accent, size: 3.5),
                ],
                const Spacer(),
                if (dueTasks.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: palette.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: palette.danger.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      dueTasks.length > 1 ? 'DDL ${dueTasks.length}' : 'DDL',
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 8,
                        height: 1,
                        color: palette.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (hasReview)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 10,
                      color: palette.warning,
                    ),
                  ),
                if (count > 0) ...<Widget>[
                  const SizedBox(width: 3),
                  Text('$count', style: context.texts.labelSmall),
                ],
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
            if (habitDots > 0) ...<Widget>[
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  for (
                    int i = 0;
                    i < (habitDots > 4 ? 4 : habitDots);
                    i++
                  ) ...<Widget>[
                    if (i > 0) const SizedBox(width: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  if (habitDots > 4) ...<Widget>[
                    const SizedBox(width: 3),
                    Text(
                      '+${habitDots - 4}',
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 8,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDayBrief(BuildContext context, DateTime day) async {
    final List<TimeBlock> dayBlocks =
        blocks
            .where((TimeBlock block) => AppDate.isSameDay(block.startAt, day))
            .toList()
          ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    final int minutes = totalMinutesOf(dayBlocks);
    final bool hasReview = reviewDays.contains(AppDate.dateKey(day));
    final List<String> dueTasks =
        dueTasksByDay[AppDate.dateKey(day)] ?? const <String>[];

    final bool? enter = await showAppSheet<bool>(
      context,
      builder: (BuildContext sheetContext) {
        final AppPalette p = sheetContext.palette;
        return AppSheetContent(
          title: '${AppDate.monthDayLabel(day)} · ${AppDate.weekdayLabel(day)}',
          subtitle:
              '负荷 ${minutes > 0 ? AppDate.durationLabel(minutes) : '—'}'
              ' · ${dayBlocks.length} 个时间块'
              '${dueTasks.isNotEmpty ? ' · DDL ${dueTasks.length}' : ''}'
              '${hasReview ? ' · 有复习节点' : ''}',
          heightFactor: null,
          actions: <Widget>[
            AppGhostButton(
              label: '关闭',
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
            AppPrimaryButton(
              label: '进入当日时间盒',
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (dueTasks.isNotEmpty) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.flag_rounded, size: 13, color: p.danger),
                    const SizedBox(width: 5),
                    Text(
                      '截止任务',
                      style: sheetContext.texts.labelMedium?.copyWith(
                        color: p.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final String title in dueTasks.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        Text('· ', style: sheetContext.texts.bodyMedium),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sheetContext.texts.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (dueTasks.length > 3)
                  Text(
                    '还有 ${dueTasks.length - 3} 个截止任务…',
                    style: sheetContext.texts.labelSmall,
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (dayBlocks.isEmpty)
                Text('当天没有排期', style: sheetContext.texts.bodyMedium)
              else
                for (final TimeBlock block in dayBlocks.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 42,
                          child: Text(
                            AppDate.timeLabel(block.startAt),
                            style: sheetContext.texts.labelSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            block.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sheetContext.texts.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              if (dayBlocks.length > 6)
                Text(
                  '还有 ${dayBlocks.length - 6} 个时间块…',
                  style: sheetContext.texts.labelSmall,
                ),
            ],
          ),
        );
      },
    );
    if (enter == true && context.mounted) {
      onEnterDay(day);
    }
  }
}
