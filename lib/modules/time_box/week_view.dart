import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/state_views.dart';
import 'time_box_common.dart';

/// 周视图：7 天时间矩阵，支持跨天拖拽改期。
class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.anchor,
    required this.blocks,
    required this.tasksById,
    required this.capabilities,
    required this.onOpenAction,
    required this.onOpenReview,
    required this.onMoveBlock,
    required this.labels,
    required this.onPickTask,
  });

  final DateTime anchor;
  final List<TimeBlock> blocks;
  final Map<String, ActionItem> tasksById;
  final List<Capability> capabilities;
  final ValueChanged<String> onOpenAction;
  final ValueChanged<String> onOpenReview;
  final void Function(TimeBlock block, DateTime day) onMoveBlock;
  final TaskLabelResolver labels;
  final void Function(DateTime start, int? durationMinutes) onPickTask;

  static const double _labelWidth = 52;
  static const double _columnWidth = 132;
  static const double _hourHeight = TimeBoxMetrics.weekHourHeight;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<DateTime> days = weekDaysOf(anchor);

    final Map<String, List<TimeBlock>> byDay = <String, List<TimeBlock>>{};
    for (final DateTime day in days) {
      byDay[AppDate.dateKey(day)] = <TimeBlock>[];
    }
    for (final TimeBlock block in blocks) {
      byDay[AppDate.dateKey(block.startAt)]?.add(block);
    }
    for (final List<TimeBlock> list in byDay.values) {
      list.sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    }

    const double contentHeight =
        (TimeBoxMetrics.endHour - TimeBoxMetrics.startHour) * _hourHeight;
    final double gridWidth = _labelWidth + days.length * _columnWidth;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: gridWidth,
          child: Column(
            children: <Widget>[
              Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.hairline)),
                ),
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: _labelWidth),
                    for (int index = 0; index < days.length; index++)
                      SizedBox(
                        width: _columnWidth,
                        child: _dayHeader(
                          context,
                          days[index],
                          byDay[AppDate.dateKey(days[index])] ?? const <TimeBlock>[],
                          index,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: contentHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: _labelWidth,
                      height: contentHeight,
                      child: Stack(
                        children: <Widget>[
                          for (int hour = TimeBoxMetrics.startHour;
                              hour <= TimeBoxMetrics.endHour;
                              hour += 2)
                            Positioned(
                              top: (hour - TimeBoxMetrics.startHour) * _hourHeight,
                              right: 8,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: context.texts.labelSmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final DateTime day in days)
                      _dayColumn(
                        context,
                        day,
                        byDay[AppDate.dateKey(day)] ?? const <TimeBlock>[],
                        contentHeight,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayHeader(
    BuildContext context,
    DateTime day,
    List<TimeBlock> dayBlocks,
    int index,
  ) {
    final AppPalette palette = context.palette;
    final bool isToday = AppDate.isSameDay(day, DateTime.now());
    final int minutes = totalMinutesOf(dayBlocks);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('周${weekdayShortLabels[index]}', style: context.texts.labelSmall),
        const SizedBox(height: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '${day.day}',
              style: context.texts.titleSmall?.copyWith(
                color: isToday ? palette.accent : palette.textPrimary,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isToday) ...<Widget>[
              const SizedBox(width: 4),
              StatusDot(color: palette.accent, size: 4),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          minutes > 0 ? AppDate.durationLabel(minutes) : '—',
          style: context.texts.labelSmall,
        ),
      ],
    );
  }

  Widget _dayColumn(
    BuildContext context,
    DateTime day,
    List<TimeBlock> dayBlocks,
    double contentHeight,
  ) {
    final AppPalette palette = context.palette;

    return DragTarget<TimeBlock>(
      onAcceptWithDetails: (DragTargetDetails<TimeBlock> details) {
        if (AppDate.isSameDay(details.data.startAt, day)) return;
        onMoveBlock(details.data, day);
      },
      builder: (BuildContext context, List<TimeBlock?> candidate, _) {
        return Container(
          width: _columnWidth,
          height: contentHeight,
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? palette.accentSoft.withValues(alpha: 0.35)
                : null,
            border: Border(left: BorderSide(color: palette.hairline)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int hour = TimeBoxMetrics.startHour;
                  hour < TimeBoxMetrics.endHour;
                  hour++)
                Positioned(
                  key: ValueKey<String>(
                    'week-slot-${AppDate.dateKey(day)}-$hour',
                  ),
                  top: (hour - TimeBoxMetrics.startHour) * _hourHeight,
                  left: 0,
                  right: 0,
                  height: _hourHeight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPickTask(
                        DateTime(day.year, day.month, day.day, hour),
                        null,
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(height: 1, color: palette.hairline),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              for (final TimeBlock block in dayBlocks)
                Positioned(
                  top: yForTime(block.startAt, _hourHeight),
                  left: 3,
                  right: 3,
                  height: math.max(
                    18,
                    block.plannedMinutes / 60 * _hourHeight - 1,
                  ),
                  child: Draggable<TimeBlock>(
                    data: block,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: _columnWidth - 6,
                        child: _chip(context, block),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _chip(context, block),
                    ),
                    child: Tooltip(
                      message: _labelOf(block) ?? block.title,
                      waitDuration: const Duration(milliseconds: 400),
                      child: GestureDetector(
                        onTap: () {
                          final String? reviewId = block.learningReviewId;
                          if (reviewId != null) {
                            onOpenReview(reviewId);
                            return;
                          }
                          final String? id = block.actionItemId;
                          if (id != null) onOpenAction(id);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: _chip(context, block),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String? _labelOf(TimeBlock block) {
    final ActionItem? action =
        block.actionItemId == null ? null : tasksById[block.actionItemId];
    return labels.labelOf(action);
  }

  Widget _chip(BuildContext context, TimeBlock block) {
    final AppPalette palette = context.palette;
    final ActionItem? action =
        block.actionItemId == null ? null : tasksById[block.actionItemId];
    final Color tone =
        toneForCapability(action?.capabilityId, capabilities, palette);

    return Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: context.isDarkMode ? 0.26 : 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: tone, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 1, 3, 1),
      child: Text(
        block.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.texts.labelSmall?.copyWith(
          fontSize: 10.5,
          color: palette.textPrimary,
          height: 1.25,
          decoration:
              block.isCompleted ? TextDecoration.lineThrough : null,
          decorationColor: palette.textTertiary,
        ),
      ),
    );
  }
}