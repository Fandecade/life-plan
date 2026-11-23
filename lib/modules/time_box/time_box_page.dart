import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/routine_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import 'day_view.dart';
import 'month_view.dart';
import 'routine_schedule_view.dart';
import 'task_picker.dart';
import 'time_box_common.dart';
import 'week_view.dart';
import 'year_view.dart';

enum TimeBoxScope { day, week, month, year }

/// 全局时间盒：日 / 周 / 月 / 年 四级时间视图。
class TimeBoxPage extends StatefulWidget {
  const TimeBoxPage({super.key});

  @override
  State<TimeBoxPage> createState() => _TimeBoxPageState();
}

class _TimeBoxPageState extends State<TimeBoxPage> {
  TimeBoxScope _scope = TimeBoxScope.day;
  DateTime _anchor = DateTime.now();
  String? _focusBlockId;
  int _focusSeq = 0;
  String? _routineScopeKey;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final UiController ui = context.watch<UiController>();
    final DateTime? focusDate = ui.focusDate;
    if (focusDate != null) {
      final String? focusBlockId = ui.focusBlockId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _scope = TimeBoxScope.day;
          _anchor = focusDate;
          _focusBlockId = focusBlockId;
          _focusSeq += 1;
        });
        ui.consumeScheduleFocus();
      });
    }
    if (_scope == TimeBoxScope.day || _scope == TimeBoxScope.week) {
      final DateTime from =
          _scope == TimeBoxScope.day ? _anchor : AppDate.startOfWeek(_anchor);
      final DateTime to = _scope == TimeBoxScope.day
          ? _anchor
          : from.add(const Duration(days: 6));
      _ensureRoutines(from, to);
    }
    final List<TimeBlock> allBlocks = context.watch<TimeBlockRepository>().all;
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final List<Capability> capabilities = context.watch<CapabilityRepository>().all;
    final List<Vision> visions = context.watch<VisionRepository>().all;
    final Map<String, ActionItem> tasksById = <String, ActionItem>{
      for (final ActionItem item in actions) item.id: item,
    };
    final TaskLabelResolver labels = TaskLabelResolver(
      capabilities: <String, Capability>{
        for (final Capability capability in capabilities) capability.id: capability,
      },
      visions: <String, Vision>{
        for (final Vision vision in visions) vision.id: vision,
      },
    );

    return Column(
      children: <Widget>[
        _header(context),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: _body(
            context,
            _filterBlocks(allBlocks),
            tasksById,
            capabilities,
            actions,
            labels,
            ui,
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final Widget scopeBar = SegmentBar<TimeBoxScope>(
      dense: true,
      options: const <SegmentOption<TimeBoxScope>>[
        SegmentOption<TimeBoxScope>(value: TimeBoxScope.day, label: '日'),
        SegmentOption<TimeBoxScope>(value: TimeBoxScope.week, label: '周'),
        SegmentOption<TimeBoxScope>(value: TimeBoxScope.month, label: '月'),
        SegmentOption<TimeBoxScope>(value: TimeBoxScope.year, label: '年'),
      ],
      value: _scope,
      onChanged: (TimeBoxScope scope) => setState(() => _scope = scope),
    );

    final Widget nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: '上一段',
          onPressed: () => _shift(-1),
        ),
        SizedBox(
          width: 156,
          child: Center(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.titleSmall,
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: '下一段',
          onPressed: () => _shift(1),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppGhostButton(
          label: '今天',
          dense: true,
          onPressed: () => setState(() => _anchor = DateTime.now()),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 760) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      scopeBar,
                      const SizedBox(width: AppSpacing.sm),
                      AppGhostButton(
                        label: '固定安排',
                        icon: Icons.event_repeat_rounded,
                        dense: true,
                        onPressed: _openRoutineSchedule,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  nav,
                ],
              ),
            );
          }
          return Row(
            children: <Widget>[
              scopeBar,
              const SizedBox(width: AppSpacing.sm),
              AppGhostButton(
                label: '固定安排',
                icon: Icons.event_repeat_rounded,
                dense: true,
                onPressed: _openRoutineSchedule,
              ),
              const Spacer(),
              nav,
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<TimeBlock> blocks,
    Map<String, ActionItem> tasksById,
    List<Capability> capabilities,
    List<ActionItem> actions,
    TaskLabelResolver labels,
    UiController ui,
  ) {
    switch (_scope) {
      case TimeBoxScope.day:
        final List<ActionItem> inbox = actions
            .where((ActionItem item) => item.isInbox)
            .toList()
          ..sort((ActionItem a, ActionItem b) => a.createdAt.compareTo(b.createdAt));
        return DayView(
          day: _anchor,
          blocks: blocks,
          tasksById: tasksById,
          capabilities: capabilities,
          inboxItems: inbox,
          onOpenAction: ui.openDetail,
          onOpenReview: ui.openReview,
          onRoutineAction: _handleRoutineAction,
          labels: labels,
          onPickTask: _pickTaskAt,
          focusBlockId: _focusBlockId,
          focusSeq: _focusSeq,
        );
      case TimeBoxScope.week:
        return WeekView(
          anchor: _anchor,
          blocks: blocks,
          tasksById: tasksById,
          capabilities: capabilities,
          onOpenAction: ui.openDetail,
          onOpenReview: ui.openReview,
          onRoutineAction: _handleRoutineAction,
          onMoveBlock: _moveBlock,
          onRescheduleBlock: _rescheduleBlock,
          labels: labels,
          onPickTask: _pickTaskAt,
        );
      case TimeBoxScope.month:
        final Set<String> reviewDays = <String>{
          for (final LearningReview review
              in context.watch<LearningReviewRepository>().pending)
            AppDate.dateKey(review.dueDate),
        };
        final int consolidatingCount = actions
            .where((ActionItem item) =>
                item.status == ActionItemStatus.consolidating)
            .length;
        final int completedCount = actions
            .where(
              (ActionItem item) =>
                  item.status == ActionItemStatus.completed,
            )
            .length;
        final bool reviewed = context
            .watch<ReviewLogRepository>()
            .hasMonthly('${_anchor.year}-${AppDate.two(_anchor.month)}');
        // 未完成任务的截止日 → 月历 DDL 徽章
        final Map<String, List<String>> dueTasksByDay = <String, List<String>>{};
        for (final ActionItem item in actions) {
          final DateTime? due = item.dueDate;
          if (due == null || item.isCompleted) continue;
          dueTasksByDay
              .putIfAbsent(AppDate.dateKey(due), () => <String>[])
              .add(item.title);
        }
        return MonthView(
          anchor: _anchor,
          blocks: blocks,
          reviewDays: reviewDays,
          consolidatingCount: consolidatingCount,
          completedCount: completedCount,
          reviewed: reviewed,
          dueTasksByDay: dueTasksByDay,
          onEnterDay: (DateTime day) {
            setState(() {
              _anchor = day;
              _scope = TimeBoxScope.day;
            });
          },
        );
      case TimeBoxScope.year:
        final ReviewLogRepository reviewLogs =
            context.watch<ReviewLogRepository>();
        return YearView(
          anchor: _anchor,
          blocks: blocks,
          reviewedMonths: reviewLogs.reviewedMonthsOf(_anchor.year),
          visionTitles: context
              .watch<VisionRepository>()
              .all
              .map((Vision vision) => vision.title)
              .toList(growable: false),
          onDrillMonth: (int month) {
            setState(() {
              _anchor = DateTime(_anchor.year, month);
              _scope = TimeBoxScope.month;
            });
          },
        );
    }
  }

  List<TimeBlock> _filterBlocks(List<TimeBlock> all) {
    switch (_scope) {
      case TimeBoxScope.day:
        return all
            .where((TimeBlock block) => AppDate.isSameDay(block.startAt, _anchor))
            .toList(growable: false);
      case TimeBoxScope.week:
        final DateTime start = AppDate.startOfWeek(_anchor);
        final DateTime end = start.add(const Duration(days: 7));
        return all
            .where(
              (TimeBlock block) =>
                  !block.startAt.isBefore(start) && block.startAt.isBefore(end),
            )
            .toList(growable: false);
      case TimeBoxScope.month:
        return all
            .where(
              (TimeBlock block) =>
                  block.startAt.year == _anchor.year &&
                  block.startAt.month == _anchor.month,
            )
            .toList(growable: false);
      case TimeBoxScope.year:
        return all
            .where((TimeBlock block) => block.startAt.year == _anchor.year)
            .toList(growable: false);
    }
  }

  String get _label {
    switch (_scope) {
      case TimeBoxScope.day:
        return '${AppDate.monthDayLabel(_anchor)} · ${AppDate.weekdayLabel(_anchor)}';
      case TimeBoxScope.week:
        final DateTime start = AppDate.startOfWeek(_anchor);
        final DateTime end = start.add(const Duration(days: 6));
        return '${AppDate.monthDayLabel(start)} - ${AppDate.monthDayLabel(end)}';
      case TimeBoxScope.month:
        return '${_anchor.year}年${_anchor.month}月';
      case TimeBoxScope.year:
        return '${_anchor.year}年';
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_scope) {
        case TimeBoxScope.day:
          _anchor = _anchor.add(Duration(days: direction));
        case TimeBoxScope.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
        case TimeBoxScope.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction);
        case TimeBoxScope.year:
          _anchor = DateTime(_anchor.year + direction);
      }
    });
  }

  void _ensureRoutines(DateTime from, DateTime to) {
    final String key = '${AppDate.dateKey(from)}|${AppDate.dateKey(to)}';
    if (_routineScopeKey == key) return;
    _routineScopeKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RoutineService>().ensureGenerated(from, to);
    });
  }

  Future<void> _openRoutineSchedule() async {
    final bool changed = await showRoutineSchedule(context);
    if (!mounted || !changed) return;
    await context.read<RoutineService>().refreshAllGenerated();
    if (!mounted) return;
    _routineScopeKey = null;
    setState(() {});
  }

  Future<void> _handleRoutineAction(
    TimeBlock block,
    RoutineBlockAction action,
  ) async {
    final RoutineService service = context.read<RoutineService>();
    final WeeklyRoutineRepository routines =
        context.read<WeeklyRoutineRepository>();

    switch (action) {
      case RoutineBlockAction.skipWeek:
        await service.skipForWeek(block);
        if (!mounted) return;
        _toast('本周已跳过，其他周次保持原课表');
      case RoutineBlockAction.restore:
        await service.restoreDefault(block);
        if (!mounted) return;
        _toast('已恢复为固定安排默认');
      case RoutineBlockAction.editRoutine:
        final WeeklyRoutine? routine =
            block.routineId == null ? null : routines.byId(block.routineId!);
        if (routine == null) return;
        final bool changed = await showRoutineEditor(context, routine: routine);
        if (!mounted || !changed) return;
        await service.refreshGenerated(routine.id);
        if (!mounted) return;
        _routineScopeKey = null;
        setState(() {});
        _toast('固定项已更新，本周按新时间重新生成');
      case RoutineBlockAction.deleteRoutine:
        final WeeklyRoutine? routine =
            block.routineId == null ? null : routines.byId(block.routineId!);
        if (routine == null) return;
        await service.deleteRoutine(routine);
        if (!mounted) return;
        _routineScopeKey = null;
        setState(() {});
        _toast('已从固定安排删除');
    }
  }

  Future<void> _pickTaskAt(DateTime start, int? durationMinutes) async {
    final List<ActionItem> tasks = context.read<ActionItemRepository>().all;
    final List<Capability> capabilities = context.read<CapabilityRepository>().all;
    final List<Vision> visions = context.read<VisionRepository>().all;
    final TaskLabelResolver labels = TaskLabelResolver(
      capabilities: <String, Capability>{
        for (final Capability capability in capabilities) capability.id: capability,
      },
      visions: <String, Vision>{
        for (final Vision vision in visions) vision.id: vision,
      },
    );

    final ActionItem? item = await showTaskPicker(
      context,
      tasks: tasks,
      labels: labels,
      target: start,
      durationMinutes: durationMinutes,
    );
    if (item == null || !mounted) return;

    await context.read<ScheduleService>().scheduleAction(
          item,
          start,
          durationMinutes: durationMinutes,
        );
    if (!mounted) return;
    final int minutes = durationMinutes ?? item.estimatedMinutes ?? 30;
    final DateTime end = start.add(Duration(minutes: minutes));
    _toast('已排入 ${AppDate.timeLabel(start)} - ${AppDate.timeLabel(end)}');
  }

  Future<void> _rescheduleBlock(TimeBlock block, DateTime newStart) async {
    await context.read<TimeBlockRepository>().save(
          block.copyWith(
            startAt: newStart,
            endAt: newStart.add(Duration(minutes: block.plannedMinutes)),
            isOverridden: block.routineId != null ? true : null,
          ),
        );
    if (!mounted) return;
    _toast('已改到 ${AppDate.timeLabel(newStart)}');
  }

  Future<void> _moveBlock(TimeBlock block, DateTime day) async {
    final DateTime start = DateTime(
      day.year,
      day.month,
      day.day,
      block.startAt.hour,
      block.startAt.minute,
    );
    await context.read<TimeBlockRepository>().save(
          block.copyWith(
            startAt: start,
            endAt: start.add(Duration(minutes: block.plannedMinutes)),
          ),
        );
    if (!mounted) return;
    _toast('已改到 ${AppDate.monthDayLabel(day)}');
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