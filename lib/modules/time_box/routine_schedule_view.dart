import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/routine_service.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';

import 'time_box_common.dart';

/// 固定块在时间盒里的右键动作。
enum RoutineBlockAction { editRoutine, skipWeek, restore, deleteRoutine }

/// 时间盒内固定块的右键菜单。
Future<RoutineBlockAction?> showRoutineBlockMenu(
  BuildContext context, {
  required TimeBlock block,
  required Offset globalPosition,
}) async {
  final AppPalette palette = context.palette;
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromLTRB(
    globalPosition.dx,
    globalPosition.dy,
    overlay.size.width - globalPosition.dx,
    overlay.size.height - globalPosition.dy,
  );

  return showMenu<RoutineBlockAction>(
    context: context,
    position: position,
    color: palette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: palette.border),
    ),
    items: <PopupMenuEntry<RoutineBlockAction>>[
      PopupMenuItem<RoutineBlockAction>(
        value: RoutineBlockAction.editRoutine,
        height: 38,
        child: Text('编辑固定项', style: context.texts.bodyMedium),
      ),
      PopupMenuItem<RoutineBlockAction>(
        value: RoutineBlockAction.skipWeek,
        height: 38,
        child: Text('仅本周跳过', style: context.texts.bodyMedium),
      ),
      if (block.isOverridden)
        PopupMenuItem<RoutineBlockAction>(
          value: RoutineBlockAction.restore,
          height: 38,
          child: Text('恢复固定安排默认', style: context.texts.bodyMedium),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<RoutineBlockAction>(
        value: RoutineBlockAction.deleteRoutine,
        height: 38,
        child: Text(
          '从固定安排删除',
          style: context.texts.bodyMedium?.copyWith(color: palette.danger),
        ),
      ),
    ],
  );
}

const List<double> _routineDurations = <double>[30, 45, 60, 90, 120];

Color routineToneFor(WeeklyRoutine routine, AppPalette palette) {
  if (routine.kind == RoutineKind.fixedRoutine) {
    return const Color(0xFF7B6F8A);
  }
  return softCapabilityTones[routine.colorIndex % softCapabilityTones.length];
}

/// 打开「一周固定安排」编辑视图。
Future<bool> showRoutineSchedule(BuildContext context) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => const RoutineScheduleDialog(),
  );
  return changed ?? false;
}

class RoutineScheduleDialog extends StatelessWidget {
  const RoutineScheduleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<WeeklyRoutine> routines =
        context.watch<WeeklyRoutineRepository>().all;
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final List<Capability> capabilities =
        context.watch<CapabilityRepository>().all;
    final List<Vision> visions = context.watch<VisionRepository>().all;
    final TaskLabelResolver labels = TaskLabelResolver(
      capabilities: <String, Capability>{
        for (final Capability capability in capabilities) capability.id: capability,
      },
      visions: <String, Vision>{
        for (final Vision vision in visions) vision.id: vision,
      },
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
        AppSpacing.md,
        0,
      ),
      title: Row(
        children: <Widget>[
          Text('固定安排', style: context.texts.titleLarge),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '每周规律占位 · 修改某一周不影射其他周',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall,
            ),
          ),
          const Spacer(),
          AppGhostButton(
            label: '新建',
            icon: Icons.add_rounded,
            dense: true,
            onPressed: () => showRoutineEditor(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppGhostButton(
            label: '关闭',
            dense: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      content: SizedBox(
        width: 980,
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: _RoutineGrid(routines: routines, actions: actions, labels: labels),
      ),
    );
  }
}

class _RoutineGrid extends StatefulWidget {
  const _RoutineGrid({
    required this.routines,
    required this.actions,
    required this.labels,
  });

  final List<WeeklyRoutine> routines;
  final List<ActionItem> actions;
  final TaskLabelResolver labels;

  @override
  State<_RoutineGrid> createState() => _RoutineGridState();
}

class _RoutineGridState extends State<_RoutineGrid> {
  static const double labelWidth = 46;
  static const double columnWidth = 128;
  static const double hourHeight = 40;
  static const int startHour = 6;
  static const int endHour = 24;

  String? _dragId;
  Offset _dragDelta = Offset.zero;
  Axis? _dragAxis;
  Offset _lastGlobal = Offset.zero;
  String? _resizeId;
  double _resizeDeltaPx = 0;
  final Map<int, GlobalKey> _columnKeys = <int, GlobalKey>{
    for (int weekday = 1; weekday <= 7; weekday++) weekday: GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double contentHeight = (endHour - startHour) * hourHeight;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: labelWidth + columnWidth * 7,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SizedBox(width: labelWidth),
                  for (int weekday = 1; weekday <= 7; weekday++)
                    SizedBox(
                      width: columnWidth,
                      height: 34,
                      child: Center(
                        child: Text(
                          '周${weekdayShortLabels[weekday - 1]}',
                          style: context.texts.labelMedium,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: contentHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: labelWidth,
                      height: contentHeight,
                      child: Stack(
                        children: <Widget>[
                          for (int hour = startHour; hour <= endHour; hour += 2)
                            Positioned(
                              top: (hour - startHour) * hourHeight,
                              right: 6,
                              child: Text(
                                '${AppDate.two(hour)}:00',
                                style: context.texts.labelSmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (int weekday = 1; weekday <= 7; weekday++)
                      KeyedSubtree(
                        key: _columnKeys[weekday],
                        child: _dayColumn(
                          context,
                          weekday,
                          widget.routines
                              .where((WeeklyRoutine routine) =>
                                  routine.weekday == weekday)
                              .toList(growable: false),
                          contentHeight,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const SizedBox(width: labelWidth),
                  Icon(Icons.repeat_rounded, size: 11, color: palette.textTertiary),
                  const SizedBox(width: 4),
                  Text('固定事项（常规占用）', style: context.texts.labelSmall),
                  const SizedBox(width: 14),
                  Icon(Icons.link_rounded, size: 11, color: palette.textTertiary),
                  const SizedBox(width: 4),
                  Text('关联任务（可跳转）', style: context.texts.labelSmall),
                  const SizedBox(width: 14),
                  Text('点击空白新建 · 上下拖动改时间 · 左右拖动换天 · 点击块编辑',
                      style: context.texts.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayColumn(
    BuildContext context,
    int weekday,
    List<WeeklyRoutine> items,
    double contentHeight,
  ) {
    final AppPalette palette = context.palette;
    return Container(
      width: columnWidth,
      height: contentHeight,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.hairline)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) {
                final int raw =
                    startHour * 60 + (details.localPosition.dy / hourHeight * 60).round();
                final int snapped =
                    (raw / 30).round() * 30;
                _openEditor(
                  context,
                  weekday: weekday,
                  startMinutes: snapped.clamp(startHour * 60, endHour * 60 - 30),
                );
              },
              child: CustomPaint(
                painter: _RoutineGridPainter(
                  hourHeight: hourHeight,
                  startHour: startHour.toDouble(),
                  endHour: endHour.toDouble(),
                  color: palette.hairline,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          for (final WeeklyRoutine routine in items)
            Positioned(
              top: (routine.startMinutes - startHour * 60) / 60 * hourHeight +
                  (_dragId == routine.id && _dragAxis == Axis.vertical
                      ? _dragDelta.dy
                      : 0),
              left: 3 +
                  (_dragId == routine.id && _dragAxis == Axis.horizontal
                      ? _dragDelta.dx
                      : 0),
              width: columnWidth - 6,
              height: ((routine.durationMinutes / 60 * hourHeight) +
                      (_resizeId == routine.id ? _resizeDeltaPx : 0))
                  .clamp(20.0, contentHeight),
              child: _chip(context, routine),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, WeeklyRoutine routine) {
    final AppPalette palette = context.palette;
    final Color tone = routineToneFor(routine, palette);
    final bool linked = routine.kind == RoutineKind.linkedTask;
    final double height = routine.durationMinutes / 60 * hourHeight;

    return GestureDetector(
      onTap: () => showRoutineEditor(context, routine: routine),
      onPanStart: (_) => _startDrag(routine),
      onPanUpdate: (DragUpdateDetails details) => _updateDrag(routine, details),
      onPanEnd: (_) => _endDrag(routine),
      onPanCancel: _cancelDrag,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tone.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(5, 3, 4, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        linked ? Icons.link_rounded : Icons.repeat_rounded,
                        size: 10,
                        color: tone,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          routine.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 10.5,
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (height >= 34) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      '${AppDate.timeLabel(DateTime(2026, 1, 1, routine.startHour, routine.startMinute))}'
                      ' - ${AppDate.durationLabel(routine.durationMinutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  key: ValueKey<String>('routine-resize-${routine.id}'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => setState(() {
                    _resizeId = routine.id;
                    _resizeDeltaPx = 0;
                  }),
                  onVerticalDragUpdate: (DragUpdateDetails details) =>
                      setState(() => _resizeDeltaPx += details.delta.dy),
                  onVerticalDragEnd: (_) => _commitResize(routine),
                  onVerticalDragCancel: () => _commitResize(routine),
                  child: const SizedBox(height: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startDrag(WeeklyRoutine routine) {
    setState(() {
      _dragId = routine.id;
      _dragAxis = null;
      _dragDelta = Offset.zero;
    });
  }

  void _updateDrag(WeeklyRoutine routine, DragUpdateDetails details) {
    if (_dragId != routine.id) return;
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

  Future<void> _endDrag(WeeklyRoutine routine) async {
    final Axis? axis = _dragAxis;
    final Offset delta = _dragDelta;
    final Offset global = _lastGlobal;
    _cancelDrag();
    if (axis == null) return;

    if (axis == Axis.horizontal) {
      final int? targetWeekday = _weekdayAt(global);
      if (targetWeekday == null || targetWeekday == routine.weekday) return;
      await context.read<WeeklyRoutineRepository>().save(
            routine.copyWith(weekday: targetWeekday),
          );
      return;
    }

    final int snapped = (delta.dy / hourHeight * 60 / 30).round() * 30;
    if (snapped == 0) return;
    final int nextStart = (routine.startMinutes + snapped)
        .clamp(startHour * 60, endHour * 60 - routine.durationMinutes);
    await context.read<WeeklyRoutineRepository>().save(
          routine.copyWith(startMinutes: nextStart),
        );
  }

  int? _weekdayAt(Offset global) {
    for (int weekday = 1; weekday <= 7; weekday++) {
      final RenderBox? box =
          _columnKeys[weekday]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final Rect rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) return weekday;
    }
    return null;
  }

  Future<void> _commitResize(WeeklyRoutine routine) async {
    final double delta = _resizeDeltaPx;
    setState(() {
      _resizeId = null;
      _resizeDeltaPx = 0;
    });
    if (delta.abs() < 4) return;
    final int snapped = (delta / hourHeight * 60 / 15).round() * 15;
    if (snapped == 0) return;
    final int maxDuration = endHour * 60 - routine.startMinutes;
    final int nextDuration =
        (routine.durationMinutes + snapped).clamp(15, maxDuration);
    await context.read<WeeklyRoutineRepository>().save(
          routine.copyWith(durationMinutes: nextDuration),
        );
  }

  void _openEditor(
    BuildContext context, {
    required int weekday,
    required int startMinutes,
  }) {
    showRoutineEditor(
      context,
      weekday: weekday,
      startMinutes: startMinutes,
    );
  }
}

class _RoutineGridPainter extends CustomPainter {
  const _RoutineGridPainter({
    required this.hourHeight,
    required this.startHour,
    required this.endHour,
    required this.color,
  });

  final double hourHeight;
  final double startHour;
  final double endHour;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double hour = startHour; hour <= endHour; hour += 1) {
      final double y = (hour - startHour) * hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutineGridPainter oldDelegate) =>
      oldDelegate.hourHeight != hourHeight ||
      oldDelegate.startHour != startHour ||
      oldDelegate.endHour != endHour ||
      oldDelegate.color != color;
}

/// 新建 / 编辑固定安排项。
Future<bool> showRoutineEditor(
  BuildContext context, {
  WeeklyRoutine? routine,
  int? weekday,
  int? startMinutes,
}) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _RoutineEditorDialog(
      routine: routine,
      weekday: weekday,
      startMinutes: startMinutes,
    ),
  );
  return changed ?? false;
}

class _RoutineEditorDialog extends StatefulWidget {
  const _RoutineEditorDialog({
    this.routine,
    this.weekday,
    this.startMinutes,
  });

  final WeeklyRoutine? routine;
  final int? weekday;
  final int? startMinutes;

  @override
  State<_RoutineEditorDialog> createState() => _RoutineEditorDialogState();
}

class _RoutineEditorDialogState extends State<_RoutineEditorDialog> {
  late final TextEditingController _title;
  late RoutineKind _kind;
  late int _weekday;
  late int _startMinutes;
  late int _duration;
  String? _actionItemId;
  final Set<int> _copyTo = <int>{};
  bool _saving = false;

  bool get _isEditing => widget.routine != null;

  @override
  void initState() {
    super.initState();
    final WeeklyRoutine? routine = widget.routine;
    _title = TextEditingController(text: routine?.title ?? '');
    _kind = routine?.kind ?? RoutineKind.fixedRoutine;
    _weekday = routine?.weekday ?? widget.weekday ?? 1;
    _startMinutes = routine?.startMinutes ?? widget.startMinutes ?? 9 * 60;
    _duration = routine?.durationMinutes ?? 60;
    _actionItemId = routine?.actionItemId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (_startMinutes ~/ 60).clamp(0, 23),
        minute: (_startMinutes % 60).clamp(0, 59),
      ),
      helpText: '固定项开始时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    setState(() => _startMinutes = picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) return;
    if (_kind == RoutineKind.linkedTask && _actionItemId == null) return;

    setState(() => _saving = true);
    final WeeklyRoutineRepository repo =
        context.read<WeeklyRoutineRepository>();
    final WeeklyRoutine? existing = widget.routine;

    if (existing != null) {
      await repo.save(
        existing.copyWith(
          title: title,
          kind: _kind,
          weekday: _weekday,
          startMinutes: _startMinutes,
          durationMinutes: _duration,
          actionItemId: _kind == RoutineKind.linkedTask ? _actionItemId : null,
          clearActionItem: _kind != RoutineKind.linkedTask,
        ),
      );
    } else {
      await repo.create(
        title: title,
        weekday: _weekday,
        startMinutes: _startMinutes,
        durationMinutes: _duration,
        kind: _kind,
        actionItemId: _kind == RoutineKind.linkedTask ? _actionItemId : null,
        colorIndex: _weekday - 1,
      );
    }

    for (final int weekday in _copyTo) {
      if (weekday == _weekday) continue;
      await repo.create(
        title: title,
        weekday: weekday,
        startMinutes: _startMinutes,
        durationMinutes: _duration,
        kind: _kind,
        actionItemId: _kind == RoutineKind.linkedTask ? _actionItemId : null,
        colorIndex: weekday - 1,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final WeeklyRoutine? routine = widget.routine;
    if (routine == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text('删除固定项？', style: dialogContext.texts.titleLarge),
          content: Text(
            '将同时移除它尚未完成的生成块；已完成的记录会保留。',
            style: dialogContext.texts.bodyMedium
                ?.copyWith(color: palette.textSecondary),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppPrimaryButton(
              label: '删除',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await context.read<RoutineService>().deleteRoutine(routine);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final List<Capability> capabilities =
        context.watch<CapabilityRepository>().all;
    final List<Vision> visions = context.watch<VisionRepository>().all;

    String taskLabel = '选择任务';
    ActionItem? selectedAction;
    for (final ActionItem action in actions) {
      if (action.id == _actionItemId) {
        taskLabel = action.title;
        selectedAction = action;
        break;
      }
    }
    final TaskLabelResolver labels = TaskLabelResolver(
      capabilities: <String, Capability>{
        for (final Capability capability in capabilities) capability.id: capability,
      },
      visions: <String, Vision>{
        for (final Vision vision in visions) vision.id: vision,
      },
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
      title: Text(_isEditing ? '编辑固定项' : '新建固定项', style: context.texts.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppTextField(
                key: const ValueKey<String>('routine-title'),
                controller: _title,
                autofocus: true,
                hintText: '例如：午饭与午休 / 周二晚项目推进',
              ),
              const SizedBox(height: AppSpacing.md),
              Text('类型', style: context.texts.labelMedium),
              const SizedBox(height: 5),
              SegmentBar<RoutineKind>(
                expand: true,
                dense: true,
                options: RoutineKind.values
                    .map((RoutineKind kind) =>
                        SegmentOption<RoutineKind>(value: kind, label: kind.label))
                    .toList(growable: false),
                value: _kind,
                onChanged: (RoutineKind kind) => setState(() => _kind = kind),
              ),
              if (_kind == RoutineKind.linkedTask) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text('关联任务', style: context.texts.labelMedium),
                const SizedBox(height: 5),
                PopupMenuButton<String>(
                  position: PopupMenuPosition.under,
                  color: palette.surface,
                  onSelected: (String id) => setState(() => _actionItemId = id),
                  itemBuilder: (BuildContext menuContext) => actions
                      .where((ActionItem action) => !action.isCompleted)
                      .take(40)
                      .map(
                        (ActionItem action) => PopupMenuItem<String>(
                          value: action.id,
                          height: 40,
                          child: Text(
                            action.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: menuContext.texts.bodyMedium,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.link_rounded, size: 14, color: palette.textTertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            taskLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.bodyMedium,
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, size: 16, color: palette.textTertiary),
                      ],
                    ),
                  ),
                ),
                if (selectedAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels.labelOf(selectedAction) ?? '',
                      style: context.texts.labelSmall,
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('生效星期', style: context.texts.labelMedium),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (int weekday = 1; weekday <= 7; weekday++)
                    AppChip(
                      label: '周${weekdayShortLabels[weekday - 1]}',
                      dense: true,
                      filled: _weekday == weekday,
                      color: palette.accent,
                      onTap: () => setState(() => _weekday = weekday),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Text('开始时间', style: context.texts.labelMedium),
                  const Spacer(),
                  AppGhostButton(
                    label: AppDate.timeLabel(
                      DateTime(2026, 1, 1, _startMinutes ~/ 60, _startMinutes % 60),
                    ),
                    icon: Icons.schedule_rounded,
                    dense: true,
                    onPressed: _pickStartTime,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('时长', style: context.texts.labelMedium),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final double minutes in _routineDurations)
                    AppChip(
                      label: AppDate.durationLabel(minutes.round()),
                      dense: true,
                      filled: _duration == minutes.round(),
                      color: palette.accent,
                      onTap: () =>
                          setState(() => _duration = minutes.round()),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('同时复制到（可选）', style: context.texts.labelMedium),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (int weekday = 1; weekday <= 7; weekday++)
                    if (weekday != _weekday)
                      AppChip(
                        label: '周${weekdayShortLabels[weekday - 1]}',
                        dense: true,
                        filled: _copyTo.contains(weekday),
                        color: palette.success,
                        onTap: () => setState(() {
                          if (!_copyTo.add(weekday)) _copyTo.remove(weekday);
                        }),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      actions: <Widget>[
        if (_isEditing)
          AppGhostButton(
            label: '删除',
            tone: palette.danger,
            onPressed: _delete,
          ),
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          label: _isEditing ? '保存' : '创建',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}