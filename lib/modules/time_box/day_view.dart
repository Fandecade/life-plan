
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/schedule_service.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import '../fogg_habit/habit_strip.dart';
import 'routine_schedule_view.dart';
import 'time_box_common.dart';

/// 日视图：06:00–24:00 时间轴，左侧待排期任务可直接拖入。
class DayView extends StatefulWidget {
  const DayView({
    super.key,
    required this.day,
    required this.blocks,
    required this.tasksById,
    required this.capabilities,
    required this.inboxItems,
    required this.onOpenAction,
    required this.onOpenReview,
    required this.onRoutineAction,
    required this.labels,
    required this.onPickTask,
    required this.focusSeq,
    this.focusBlockId,
  });

  final DateTime day;
  final List<TimeBlock> blocks;
  final Map<String, ActionItem> tasksById;
  final List<Capability> capabilities;
  final List<ActionItem> inboxItems;
  final ValueChanged<String> onOpenAction;
  final ValueChanged<String> onOpenReview;
  final void Function(TimeBlock block, RoutineBlockAction action) onRoutineAction;
  final TaskLabelResolver labels;
  /// [durationMinutes] 为空表示沿用任务自身的预计时长。
  final void Function(DateTime start, int? durationMinutes) onPickTask;

  /// 「已排班」跳转过来的目标时间块，用于滚动定位与短暂高亮。
  final String? focusBlockId;
  final int focusSeq;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  static const double _hourHeight = TimeBoxMetrics.dayHourHeight;
  static const double _labelWidth = 54;
  static const double _minBlockHeight = 26;
  static const double _railWidth = 224;

  final ScrollController _scroll = ScrollController(initialScrollOffset: 120);
  final GlobalKey _trackKey = GlobalKey();


  String? _moveId;
  double _moveDeltaY = 0;
  String? _resizeId;
  double _resizeDeltaY = 0;
  DateTime? _selectAnchor;
  DateTime? _selectCurrent;
  String? _highlightId;
  Timer? _highlightTimer;

  bool get _isToday => AppDate.isSameDay(widget.day, DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToFocus();
    });
  }

  @override
  void didUpdateWidget(covariant DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusSeq != widget.focusSeq) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToFocus();
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToFocus() {
    final String? id = widget.focusBlockId;
    if (id == null) return;
    TimeBlock? target;
    for (final TimeBlock block in widget.blocks) {
      if (block.id == id) {
        target = block;
        break;
      }
    }
    if (target == null) return;

    final double offset = yForTime(target.startAt, _hourHeight) - 96;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        offset.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _highlightId = id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Map<String, BlockSlot> slots = layoutOverlaps(widget.blocks);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showRail = constraints.maxWidth >= 900;
        return Row(
          children: <Widget>[
            if (showRail)
              _InboxRail(
                items: widget.inboxItems,
                onQuickSchedule: _quickSchedule,
                onOpen: (ActionItem item) => widget.onOpenAction(item.id),
              ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: showRail ? palette.hairline : Colors.transparent,
                    ),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    if (_isToday) const HabitAnchorStrip(),
                    Expanded(
                      child: _timeline(
                        context,
                        slots,
                        constraints.maxWidth - (showRail ? _railWidth : 0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _timeline(
    BuildContext context,
    Map<String, BlockSlot> slots,
    double availableWidth,
  ) {
    final AppPalette palette = context.palette;
    final double trackWidth = availableWidth - _labelWidth;
    final double contentHeight = TimeBoxMetrics.dayMinutes / 60 * _hourHeight + 8;

    return DragTarget<ActionItem>(
      onAcceptWithDetails: _handleDrop,
      builder: (BuildContext context, List<ActionItem?> candidate, _) {
        final bool hovering = candidate.isNotEmpty;
        return DecoratedBox(
          decoration: hovering
              ? BoxDecoration(
                  color: palette.accentSoft.withValues(alpha: 0.35),
                )
              : const BoxDecoration(),
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: contentHeight,
              child: Stack(
                key: _trackKey,
                children: <Widget>[
                  for (int hour = TimeBoxMetrics.startHour;
                      hour <= TimeBoxMetrics.endHour;
                      hour++)
                    Positioned(
                      top: (hour - TimeBoxMetrics.startHour) * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: _labelWidth - 10,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Transform.translate(
                                offset: const Offset(0, -5),
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: context.texts.labelSmall,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: hour == TimeBoxMetrics.startHour
                                  ? Colors.transparent
                                  : palette.hairline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: _labelWidth,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      key: const ValueKey<String>('time-track'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (TapUpDetails details) =>
                          _handleTapAt(details.localPosition),
                      onVerticalDragStart: (DragStartDetails details) =>
                          _handleSelectStart(details.localPosition),
                      onVerticalDragUpdate: (DragUpdateDetails details) =>
                          _handleSelectUpdate(details.localPosition),
                      onVerticalDragEnd: (_) => _handleSelectEnd(),
                      onVerticalDragCancel: _clearSelection,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (_selectStart != null && _selectEnd != null)
                    _selectionOverlay(context),
                  if (_isToday)
                    Positioned(
                      top: yForTime(DateTime.now(), _hourHeight),
                      left: _labelWidth - 5,
                      right: 8,
                      child: IgnorePointer(
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: palette.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: palette.accent.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final TimeBlock block in widget.blocks)
                    ..._positionedBlock(
                      context,
                      block,
                      slots[block.id] ?? const BlockSlot(left: 0, width: 1),
                      trackWidth,
                      contentHeight,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _positionedBlock(
    BuildContext context,
    TimeBlock block,
    BlockSlot slot,
    double trackWidth,
    double contentHeight,
  ) {
    final bool moving = _moveId == block.id;
    final bool resizing = _resizeId == block.id;

    double top = yForTime(block.startAt, _hourHeight);
    double height =
        math.max(_minBlockHeight, block.plannedMinutes / 60 * _hourHeight - 2);
    if (moving) {
      top = (top + _moveDeltaY).clamp(0.0, math.max(0, contentHeight - height - 4));
    }
    if (resizing) {
      height = math.max(_minBlockHeight, height + _resizeDeltaY);
      top = math.min(top, contentHeight - height - 4);
    }

    final double left = _labelWidth + 6 + slot.left * (trackWidth - 12);
    final double width = math.max(80, slot.width * (trackWidth - 12) - 6);

    return <Widget>[
      Positioned(
        key: ValueKey<String>('time-block-${block.id}'),
        top: top,
        left: left,
        width: width,
        height: height,
        child: _blockCard(context, block, height),
      ),
    ];
  }

  Widget _blockCard(BuildContext context, TimeBlock block, double height) {
    final AppPalette palette = context.palette;
    final ActionItem? action =
        block.actionItemId == null ? null : widget.tasksById[block.actionItemId];
    final Color tone =
        toneForCapability(action?.capabilityId, widget.capabilities, palette);
    final String? label = widget.labels.labelOf(action);
    final bool showMeta = label != null && height >= 58;
    final bool showTime = height >= 78;
    final String? statusTag;
    if (block.isOverridden) {
      statusTag = '本周特例';
    } else if (block.learningReviewId != null) {
      statusTag = block.isCompleted ? '已回忆' : '待回忆';
    } else if (action != null) {
      if (action.isCompleted) {
        statusTag = '已掌握';
      } else if (action.status == ActionItemStatus.consolidating) {
        statusTag = '已输出 · 巩固中';
      } else {
        statusTag = null;
      }
    } else {
      statusTag = null;
    }

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
      onPanStart: (_) => setState(() {
        _moveId = block.id;
        _moveDeltaY = 0;
      }),
      onPanUpdate: (DragUpdateDetails details) =>
          setState(() => _moveDeltaY += details.delta.dy),
      onPanEnd: (_) => _commitMove(block),
      onPanCancel: () => _commitMove(block),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: tone.withValues(alpha: context.isDarkMode ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(7),
                border: Border(left: BorderSide(color: tone, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (block.routineId != null) ...<Widget>[
                        Icon(
                          block.actionItemId != null
                              ? Icons.link_rounded
                              : Icons.repeat_rounded,
                          size: 10,
                          color: tone,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(
                          block.title,
                          maxLines: showTime || showMeta ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: palette.textPrimary,
                            decoration: block.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: palette.textTertiary,
                          ),
                        ),
                      ),
                      if (block.actionItemId != null)
                        AppCheckCircle(
                          checked: block.isCompleted,
                          size: 15,
                          padding: 0,
                          onTap: () => _toggle(block),
                        ),
                    ],
                  ),
                  if (showMeta) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 10,
                        color: tone,
                      ),
                    ),
                  ],
                  if (showTime) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          AppDate.timeRangeLabel(block.startAt, block.endAt),
                          style: context.texts.labelSmall,
                        ),
                        if (statusTag != null) ...<Widget>[
                          const Spacer(),
                          Flexible(
                            child: Text(
                              statusTag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.labelSmall?.copyWith(
                                color: statusTag == '本周特例'
                                    ? palette.warning
                                    : ((statusTag == '已掌握' ||
                                            statusTag == '已回忆')
                                        ? palette.success
                                        : palette.accent),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_highlightId == block.id)

              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              width: 18,
              height: 18,
              child: Tooltip(
                message: '拖动调整时长（15 分钟）',
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    key: ValueKey<String>('resize-block-${block.id}'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => setState(() {
                      _resizeId = block.id;
                      _resizeDeltaY = 0;
                    }),
                    onVerticalDragUpdate: (DragUpdateDetails details) =>
                        setState(() => _resizeDeltaY += details.delta.dy),
                    onVerticalDragEnd: (_) => _commitResize(block),
                    onVerticalDragCancel: () => _commitResize(block),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CustomPaint(
                          size: const Size(7, 7),
                          painter: _ResizeGripPainter(
                            color: tone.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 拖拽圈选时间格
  // -------------------------------------------------------------------------

  DateTime? get _selectStart {
    final DateTime? anchor = _selectAnchor;
    final DateTime? current = _selectCurrent;
    if (anchor == null || current == null) return null;
    return anchor.isBefore(current) ? anchor : current;
  }

  DateTime? get _selectEnd {
    final DateTime? anchor = _selectAnchor;
    final DateTime? current = _selectCurrent;
    if (anchor == null || current == null) return null;
    final DateTime later = anchor.isAfter(current) ? anchor : current;
    return later.add(const Duration(minutes: TimeBoxMetrics.snapMinutes));
  }

  void _handleSelectStart(Offset local) {
    final DateTime time = timeForY(local.dy, widget.day, _hourHeight);
    setState(() {
      _selectAnchor = time;
      _selectCurrent = time;
    });
  }

  void _handleSelectUpdate(Offset local) {
    if (_selectAnchor == null) return;
    final DateTime time = timeForY(local.dy, widget.day, _hourHeight);
    if (time == _selectCurrent) return;
    setState(() => _selectCurrent = time);
  }

  void _clearSelection() {
    if (_selectAnchor == null && _selectCurrent == null) return;
    setState(() {
      _selectAnchor = null;
      _selectCurrent = null;
    });
  }

  void _handleTapAt(Offset local) {
    final DateTime start = timeForY(local.dy, widget.day, _hourHeight);
    widget.onPickTask(start, null);
  }

  void _handleSelectEnd() {
    final DateTime? start = _selectStart;
    final DateTime? end = _selectEnd;
    _clearSelection();
    if (start == null || end == null) return;
    final int minutes = end.difference(start).inMinutes;
    if (minutes < TimeBoxMetrics.snapMinutes) return;
    widget.onPickTask(start, minutes);
  }

  Widget _selectionOverlay(BuildContext context) {
    final AppPalette palette = context.palette;
    final DateTime? start = _selectStart;
    final DateTime? end = _selectEnd;
    if (start == null || end == null) return const SizedBox.shrink();

    final double top = yForTime(start, _hourHeight);
    final double height = math.max(
      TimeBoxMetrics.snapMinutes / 60 * _hourHeight,
      end.difference(start).inMinutes / 60 * _hourHeight,
    );

    return Positioned(
      top: top,
      left: _labelWidth + 6,
      right: 8,
      height: height,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${AppDate.timeLabel(start)} - ${AppDate.timeLabel(end)}',
            style: context.texts.labelSmall?.copyWith(color: palette.accent),
          ),
        ),
      ),
    );
  }

  void _toggle(TimeBlock block) {
    final ScheduleService service = context.read<ScheduleService>();
    if (block.isCompleted) {
      service.uncompleteBlock(block);
    } else {
      service.completeBlock(block);
    }
  }

  Future<void> _commitMove(TimeBlock block) async {
    final double delta = _moveDeltaY;
    setState(() {
      _moveId = null;
      _moveDeltaY = 0;
    });
    if (delta.abs() < 4) return;

    final int snapped =
        (delta / _hourHeight * 60 / TimeBoxMetrics.snapMinutes).round() *
            TimeBoxMetrics.snapMinutes;
    if (snapped == 0) return;

    final int duration = block.plannedMinutes;
    final DateTime dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      TimeBoxMetrics.startHour,
    );
    final int maxStartMinutes =
        TimeBoxMetrics.endHour * 60 - duration;

    DateTime newStart = block.startAt.add(Duration(minutes: snapped));
    int startMinutes = newStart.hour * 60 + newStart.minute;
    if (startMinutes < TimeBoxMetrics.startHour * 60) {
      startMinutes = TimeBoxMetrics.startHour * 60;
    }
    if (startMinutes > maxStartMinutes) startMinutes = maxStartMinutes;
    newStart = dayStart.add(Duration(minutes: startMinutes - TimeBoxMetrics.startHour * 60));

    await context.read<TimeBlockRepository>().save(
          block.copyWith(
            startAt: newStart,
            endAt: newStart.add(Duration(minutes: duration)),
            isOverridden: block.routineId != null ? true : null,
          ),
        );
  }

  Future<void> _commitResize(TimeBlock block) async {
    final double delta = _resizeDeltaY;
    setState(() {
      _resizeId = null;
      _resizeDeltaY = 0;
    });
    if (delta.abs() < 4) return;

    final int snapped =
        (delta / _hourHeight * 60 / TimeBoxMetrics.snapMinutes).round() *
            TimeBoxMetrics.snapMinutes;
    if (snapped == 0) return;

    final int startMinutes = block.startAt.hour * 60 + block.startAt.minute;
    final int maxDuration = TimeBoxMetrics.endHour * 60 - startMinutes;
    final int duration =
        (block.plannedMinutes + snapped).clamp(TimeBoxMetrics.snapMinutes, maxDuration);

    await context.read<TimeBlockRepository>().save(
          block.copyWith(
            endAt: block.startAt.add(Duration(minutes: duration)),
            isOverridden: block.routineId != null ? true : null,
          ),
        );
  }

  Future<void> _handleDrop(DragTargetDetails<ActionItem> details) async {
    final RenderBox? box =
        _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset local = box.globalToLocal(details.offset);
    final DateTime start = timeForY(local.dy, widget.day, _hourHeight);
    await context.read<ScheduleService>().scheduleAction(details.data, start);
    if (!mounted) return;
    _toast('已排入 ${AppDate.timeLabel(start)}');
  }

  Future<void> _quickSchedule(ActionItem item) async {
    final int duration = item.estimatedMinutes ?? 30;
    DateTime candidate = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      9,
    );
    final DateTime limit = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      23,
      45,
    );

    while (candidate.isBefore(limit)) {
      final DateTime end = candidate.add(Duration(minutes: duration));
      final bool conflict = widget.blocks.any(
        (TimeBlock block) =>
            candidate.isBefore(block.endAt) && end.isAfter(block.startAt),
      );
      if (!conflict) break;
      candidate = candidate.add(const Duration(minutes: 30));
    }

    await context.read<ScheduleService>().scheduleAction(item, candidate);
    if (!mounted) return;
    _toast('已排入 ${AppDate.timeLabel(candidate)}');
  }

  void _toast(String message) {
    final AppPalette palette = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: context.texts.bodyMedium?.copyWith(color: palette.background),
        ),
        backgroundColor: palette.textPrimary,
        behavior: SnackBarBehavior.floating,
        width: 240,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ResizeGripPainter extends CustomPainter {
  const _ResizeGripPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.35, size.height),
      Offset(size.width, size.height * 0.35),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height),
      Offset(size.width, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ResizeGripPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _InboxRail extends StatelessWidget {
  const _InboxRail({
    required this.items,
    required this.onQuickSchedule,
    required this.onOpen,
  });

  final List<ActionItem> items;
  final ValueChanged<ActionItem> onQuickSchedule;
  final ValueChanged<ActionItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return SizedBox(
      width: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 2,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('待排期', style: context.texts.labelMedium),
                    const SizedBox(width: 6),
                    Text(
                      '${items.length}',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '拖到右侧时间轴，或点一下自动排期',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.inbox_outlined,
                    title: '没有待排期任务',
                    description: '在任务池里先收集想法',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm + 2,
                      0,
                      AppSpacing.sm + 2,
                      AppSpacing.lg,
                    ),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ActionItem item = items[index];
                      final Widget card = AppCard(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: 7,
                        ),
                        onTap: () => onQuickSchedule(item),
                        child: Row(
                          children: <Widget>[
                            StatusDot(color: palette.accent, size: 4),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall?.copyWith(
                                  color: palette.textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (item.estimatedMinutes != null) ...<Widget>[
                              const SizedBox(width: 4),
                              Text(
                                AppDate.durationLabel(item.estimatedMinutes),
                                style: context.texts.labelSmall,
                              ),
                            ],
                          ],
                        ),
                      );

                      return Draggable<ActionItem>(
                        data: item,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 196,
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm + 2,
                                vertical: 8,
                              ),
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.35, child: card),
                        child: GestureDetector(
                          onDoubleTap: () => onOpen(item),
                          child: card,
                        ),
                      );
                    },
                  ),
          ),
          Divider(color: palette.hairline, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Text('拖动改时间', style: context.texts.labelSmall),
                const Spacer(),
                const AppChip(label: '15 分钟吸附', dense: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}