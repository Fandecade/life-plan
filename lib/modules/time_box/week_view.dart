import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/state_views.dart';
import 'routine_schedule_view.dart';
import 'time_box_common.dart';

/// 周视图：7 天时间矩阵。
///
/// 块支持两种拖动：
/// - 水平拖动 → 跨天改期（保留时刻）；
/// - 上下拖动 → 同一天内改开始时间（15 分钟吸附）。
class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.anchor,
    required this.blocks,
    required this.tasksById,
    required this.capabilities,
    required this.onOpenAction,
    required this.onOpenReview,
    required this.onRoutineAction,
    required this.onMoveBlock,
    required this.onRescheduleBlock,
    required this.labels,
    required this.onPickTask,
  });

  final DateTime anchor;
  final List<TimeBlock> blocks;
  final Map<String, ActionItem> tasksById;
  final List<Capability> capabilities;
  final ValueChanged<String> onOpenAction;
  final ValueChanged<String> onOpenReview;
  final void Function(TimeBlock block, RoutineBlockAction action) onRoutineAction;
  final void Function(TimeBlock block, DateTime day) onMoveBlock;
  final void Function(TimeBlock block, DateTime newStart) onRescheduleBlock;
  final TaskLabelResolver labels;
  final void Function(DateTime start, int? durationMinutes) onPickTask;

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  static const double _labelWidth = 52;
  static const double _columnWidth = 132;
  static const double _hourHeight = TimeBoxMetrics.weekHourHeight;

  final Map<int, GlobalKey> _columnKeys = <int, GlobalKey>{
    for (int weekday = 1; weekday <= 7; weekday++) weekday: GlobalKey(),
  };

  String? _dragId;
  Axis? _dragAxis;
  Offset _dragDelta = Offset.zero;
  Offset _lastGlobal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<DateTime> days = weekDaysOf(widget.anchor);

    final Map<String, List<TimeBlock>> byDay = <String, List<TimeBlock>>{};
    for (final DateTime day in days) {
      byDay[AppDate.dateKey(day)] = <TimeBlock>[];
    }
    for (final TimeBlock block in widget.blocks) {
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
                    for (int index = 0; index < days.length; index++)
                      KeyedSubtree(
                        key: _columnKeys[index + 1],
                        child: _dayColumn(
                          context,
                          days[index],
                          byDay[AppDate.dateKey(days[index])] ?? const <TimeBlock>[],
                          contentHeight,
                        ),
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

    return Container(
      width: _columnWidth,
      height: contentHeight,
      decoration: BoxDecoration(
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
                  onTap: () => widget.onPickTask(
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
              top: yForTime(block.startAt, _hourHeight) +
                  (_dragId == block.id && _dragAxis == Axis.vertical
                      ? _dragDelta.dy
                      : 0),
              left: 3 +
                  (_dragId == block.id && _dragAxis == Axis.horizontal
                      ? _dragDelta.dx
                      : 0),
              width: _columnWidth - 6,
              height: math.max(
                18,
                block.plannedMinutes / 60 * _hourHeight - 1,
              ),
              child: _block(context, block),
            ),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, TimeBlock block) {
    return GestureDetector(
      onTap: () {
        final String? reviewId = block.learningReviewId;
        if (reviewId != null) {
          widget.onOpenReview(reviewId);
          return;
        }
        final String? id = block.actionItemId;
        if (id != null) widget.onOpenAction(id);
      },
      onSecondaryTapUp: (TapUpDetails details) async {
        if (block.routineId == null) return;
        final RoutineBlockAction? routineAction = await showRoutineBlockMenu(
          context,
          block: block,
          globalPosition: details.globalPosition,
        );
        if (routineAction != null) {
          widget.onRoutineAction(block, routineAction);
        }
      },
      onLongPressStart: (LongPressStartDetails details) async {
        if (block.routineId == null) return;
        final RoutineBlockAction? routineAction = await showRoutineBlockMenu(
          context,
          block: block,
          globalPosition: details.globalPosition,
        );
        if (routineAction != null) {
          widget.onRoutineAction(block, routineAction);
        }
      },
      onPanStart: (_) => _startDrag(block),
      onPanUpdate: (DragUpdateDetails details) => _updateDrag(block, details),
      onPanEnd: (_) => _endDrag(block),
      onPanCancel: _cancelDrag,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: _labelOf(block) ?? block.title,
          waitDuration: const Duration(milliseconds: 400),
          child: Opacity(
            opacity: _dragId == block.id ? 0.85 : 1,
            child: _chip(context, block),
          ),
        ),
      ),
    );
  }

  void _startDrag(TimeBlock block) {
    setState(() {
      _dragId = block.id;
      _dragAxis = null;
      _dragDelta = Offset.zero;
    });
  }

  void _updateDrag(TimeBlock block, DragUpdateDetails details) {
    if (_dragId != block.id) return;
    _lastGlobal = details.globalPosition;

    if (_dragAxis == null) {
      final Offset total = _dragDelta + details.delta;
      if (total.distance < 6) {
        setState(() => _dragDelta = total);
        return;
      }
      _dragAxis = total.dx.abs() >= total.dy.abs()
          ? Axis.horizontal
          : Axis.vertical;
    }

    setState(() {
      _dragDelta += _dragAxis == Axis.horizontal
          ? Offset(details.delta.dx, 0)
          : Offset(0, details.delta.dy);
    });
  }

  void _cancelDrag() {
    setState(() {
      _dragId = null;
      _dragAxis = null;
      _dragDelta = Offset.zero;
    });
  }

  Future<void> _endDrag(TimeBlock block) async {
    final Axis? axis = _dragAxis;
    final Offset delta = _dragDelta;
    final Offset global = _lastGlobal;
    _cancelDrag();
    if (axis == null) return;

    if (axis == Axis.horizontal) {
      final DateTime? targetDay = _dayAt(global);
      if (targetDay == null ||
          AppDate.isSameDay(targetDay, block.startAt)) {
        return;
      }
      widget.onMoveBlock(block, targetDay);
      return;
    }

    final int snapped =
        (delta.dy / _hourHeight * 60 / TimeBoxMetrics.snapMinutes).round() *
            TimeBoxMetrics.snapMinutes;
    if (snapped == 0) return;

    final int duration = block.plannedMinutes;
    final DateTime dayStart = DateTime(
      block.startAt.year,
      block.startAt.month,
      block.startAt.day,
      TimeBoxMetrics.startHour,
    );
    final int maxStart = TimeBoxMetrics.endHour * 60 - duration;
    int minutes = block.startAt.hour * 60 + block.startAt.minute + snapped;
    minutes = minutes.clamp(TimeBoxMetrics.startHour * 60, maxStart);
    final DateTime newStart =
        dayStart.add(Duration(minutes: minutes - TimeBoxMetrics.startHour * 60));
    widget.onRescheduleBlock(block, newStart);
  }

  DateTime? _dayAt(Offset global) {
    final List<DateTime> days = weekDaysOf(widget.anchor);
    for (int weekday = 1; weekday <= 7; weekday++) {
      final RenderBox? box =
          _columnKeys[weekday]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final Rect rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) return days[weekday - 1];
    }
    return null;
  }

  String? _labelOf(TimeBlock block) {
    final ActionItem? action =
        block.actionItemId == null ? null : widget.tasksById[block.actionItemId];
    return widget.labels.labelOf(action);
  }

  Widget _chip(BuildContext context, TimeBlock block) {
    final AppPalette palette = context.palette;
    final ActionItem? action =
        block.actionItemId == null ? null : widget.tasksById[block.actionItemId];
    final Color tone =
        toneForCapability(action?.capabilityId, widget.capabilities, palette);

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