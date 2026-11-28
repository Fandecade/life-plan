import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/schedule_picker.dart';
import '../../core/services/schedule_service.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/state_views.dart';

/// 日视图「今日待办」全屏页：未定时间 + 已定时间 + 已过期 + 已完成（折叠）。
///
/// 未完成项按分组展示；已完成项统一收进默认收起的「已完成」组并划线。
/// 逾期任务点圆圈弹出处理菜单：标记完成 / 顺延到今天 / 改期。
class DayTodoView extends StatefulWidget {
  const DayTodoView({super.key, required this.day, required this.onOpen});

  final DateTime day;
  final ValueChanged<String> onOpen;

  @override
  State<DayTodoView> createState() => _DayTodoViewState();
}

class _DayTodoViewState extends State<DayTodoView> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ActionItemRepository actions = context.watch<ActionItemRepository>();
    final TimeBlockRepository blocks = context.watch<TimeBlockRepository>();
    final DateTime dayStart = AppDate.startOfDay(widget.day);

    final List<TimeBlock> todayBlocks =
        blocks.all
            .where(
              (TimeBlock block) => AppDate.isSameDay(block.startAt, widget.day),
            )
            .toList()
          ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    final Set<String> todayBlockTaskIds = <String>{
      for (final TimeBlock block in todayBlocks)
        if (block.actionItemId != null) block.actionItemId!,
    };
    final List<TimeBlock> pendingBlocks = todayBlocks
        .where((TimeBlock block) => !block.isCompleted)
        .toList();
    final List<TimeBlock> doneBlocks = todayBlocks
        .where((TimeBlock block) => block.isCompleted)
        .toList();

    final List<ActionItem> overdue =
        actions.all
            .where(
              (ActionItem item) =>
                  !item.isCompleted &&
                  item.scheduledDate != null &&
                  AppDate.startOfDay(item.scheduledDate!).isBefore(dayStart) &&
                  !todayBlockTaskIds.contains(item.id),
            )
            .toList()
          ..sort(
            (ActionItem a, ActionItem b) =>
                a.scheduledDate!.compareTo(b.scheduledDate!),
          );
    final List<ActionItem> unscheduled =
        actions.all
            .where(
              (ActionItem item) =>
                  !item.isCompleted &&
                  item.scheduledDate != null &&
                  AppDate.isSameDay(item.scheduledDate!, widget.day) &&
                  !todayBlockTaskIds.contains(item.id),
            )
            .toList()
          ..sort(
            (ActionItem a, ActionItem b) => a.createdAt.compareTo(b.createdAt),
          );

    final Set<String> doneBlockTaskIds = <String>{
      for (final TimeBlock block in doneBlocks)
        if (block.actionItemId != null) block.actionItemId!,
    };
    final List<_DoneEntry> doneEntries = <_DoneEntry>[
      for (final TimeBlock block in doneBlocks) _DoneEntry.block(block),
      for (final ActionItem item in actions.all)
        if (item.isCompleted &&
            !doneBlockTaskIds.contains(item.id) &&
            item.completedAt != null &&
            AppDate.isSameDay(item.completedAt!, widget.day))
          _DoneEntry.task(item),
    ]..sort((_DoneEntry a, _DoneEntry b) => b.doneAt.compareTo(a.doneAt));

    if (unscheduled.isEmpty &&
        pendingBlocks.isEmpty &&
        overdue.isEmpty &&
        doneEntries.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist_rounded,
        title: '今天还没有待办',
        description: '在任务详情设置「计划日期」，或从任务池把任务排入今天。',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (unscheduled.isNotEmpty) ...<Widget>[
          _groupLabel(context, '未定时间 · ${unscheduled.length}'),
          const SizedBox(height: 6),
          for (final ActionItem item in unscheduled)
            _unscheduledRow(context, palette, item),
        ],
        if (pendingBlocks.isNotEmpty) ...<Widget>[
          if (unscheduled.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          _groupLabel(context, '已定时间 · ${pendingBlocks.length}'),
          const SizedBox(height: 6),
          for (final TimeBlock block in pendingBlocks)
            _scheduledRow(context, palette, actions, block),
        ],
        if (overdue.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _groupLabel(
            context,
            '已过期 · ${overdue.length}',
            color: palette.danger,
          ),
          const SizedBox(height: 6),
          for (final ActionItem item in overdue)
            _unscheduledRow(context, palette, item, overdue: true),
        ],
        if (doneEntries.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _doneHeader(context, doneEntries.length),
          if (_showDone) ...<Widget>[
            const SizedBox(height: 6),
            for (final _DoneEntry entry in doneEntries)
              if (entry.block != null)
                _scheduledRow(context, palette, actions, entry.block!)
              else
                _unscheduledRow(context, palette, entry.item!),
          ],
        ],
      ],
    );
  }

  Widget _groupLabel(BuildContext context, String text, {Color? color}) {
    return Text(text, style: context.texts.labelSmall?.copyWith(color: color));
  }

  Widget _doneHeader(BuildContext context, int count) {
    final AppPalette palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => setState(() => _showDone = !_showDone),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Text('已完成 · $count', style: context.texts.labelSmall),
            const SizedBox(width: 4),
            Icon(
              _showDone ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
              color: palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  int _overdueDays(ActionItem item) {
    final DateTime planned = AppDate.startOfDay(item.scheduledDate!);
    final int days = AppDate.startOfDay(widget.day).difference(planned).inDays;
    return days < 1 ? 1 : days;
  }

  Widget _unscheduledRow(
    BuildContext context,
    AppPalette palette,
    ActionItem item, {
    bool overdue = false,
  }) {
    final bool done = item.isCompleted;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => widget.onOpen(item.id),
      child: Row(
        children: <Widget>[
          AppCheckCircle(
            checked: done,
            size: 18,
            padding: 0,
            onTap: overdue && !done
                ? () => _showOverdueMenu(context, item)
                : () => _toggleTask(context, item),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyLarge?.copyWith(
                    color: done ? palette.textTertiary : null,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: palette.textTertiary,
                  ),
                ),
                if (overdue && item.scheduledDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '原定 ${AppDate.monthDayLabel(item.scheduledDate!)} · 逾期 ${_overdueDays(item)} 天',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.danger,
                      ),
                    ),
                  ),
                if (item.estimatedMinutes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      AppDate.durationLabel(item.estimatedMinutes!),
                      style: context.texts.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          if (!done) ...<Widget>[
            const SizedBox(width: 8),
            if (overdue)
              AppGhostButton(
                label: '处理',
                icon: Icons.more_horiz_rounded,
                dense: true,
                onPressed: () => _showOverdueMenu(context, item),
              )
            else
              AppGhostButton(
                label: '排期',
                icon: Icons.event_available_outlined,
                dense: true,
                onPressed: () => _schedule(context, item),
              ),
          ],
        ],
      ),
    );
  }

  Widget _scheduledRow(
    BuildContext context,
    AppPalette palette,
    ActionItemRepository actions,
    TimeBlock block,
  ) {
    final bool done = block.isCompleted;
    final ActionItem? task = block.actionItemId == null
        ? null
        : actions.byId(block.actionItemId!);
    final String title = task?.title ?? block.title;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: task == null ? null : () => widget.onOpen(task.id),
      child: Row(
        children: <Widget>[
          AppCheckCircle(
            checked: done,
            size: 18,
            padding: 0,
            onTap: () => _toggleBlock(context, block),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              AppDate.timeLabel(block.startAt),
              style: context.texts.labelSmall?.copyWith(
                color: done ? palette.textTertiary : palette.accent,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyLarge?.copyWith(
                color: done ? palette.textTertiary : null,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: palette.textTertiary,
              ),
            ),
          ),
          if (block.plannedMinutes > 0)
            Text(
              AppDate.durationLabel(block.plannedMinutes),
              style: context.texts.labelSmall,
            ),
        ],
      ),
    );
  }

  Future<void> _showOverdueMenu(BuildContext context, ActionItem item) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final AppPalette sheetPalette = sheetContext.palette;

        Widget option({
          required String label,
          required IconData icon,
          required String value,
          bool danger = false,
        }) {
          return ListTile(
            leading: Icon(
              icon,
              size: 18,
              color: danger ? sheetPalette.danger : sheetPalette.textSecondary,
            ),
            title: Text(
              label,
              style: sheetContext.texts.bodyMedium?.copyWith(
                color: danger ? sheetPalette.danger : sheetPalette.textPrimary,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(value),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Material(
              color: sheetPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: sheetPalette.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sheetContext.texts.titleSmall,
                      ),
                    ),
                  ),
                  option(
                    label: '标记完成',
                    icon: Icons.check_rounded,
                    value: 'done',
                  ),
                  option(
                    label: '顺延到今天',
                    icon: Icons.today_outlined,
                    value: 'defer',
                  ),
                  option(
                    label: '改期',
                    icon: Icons.event_available_outlined,
                    value: 'reschedule',
                  ),
                  option(
                    label: '取消',
                    icon: Icons.close_rounded,
                    value: 'cancel',
                    danger: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (action == null || action == 'cancel' || !context.mounted) return;
    switch (action) {
      case 'done':
        await context.read<ActionItemRepository>().setStatus(
          item.id,
          ActionItemStatus.completed,
        );
        break;
      case 'defer':
        await context.read<ScheduleService>().assignDate(item, widget.day);
        break;
      case 'reschedule':
        await _schedule(context, item);
        break;
    }
  }

  Future<void> _schedule(BuildContext context, ActionItem item) async {
    final DateTime? planned = item.scheduledDate;
    final bool plannedBeforeDay =
        planned != null &&
        AppDate.startOfDay(planned).isBefore(AppDate.startOfDay(widget.day));
    final SchedulePickResult? result = await pickScheduleResult(
      context,
      initialDate: plannedBeforeDay ? widget.day : (planned ?? DateTime.now()),
      allowClearDate: planned != null,
    );
    if (result == null || !context.mounted) return;
    final ScheduleService service = context.read<ScheduleService>();
    if (result.clearDate) {
      await service.assignDate(item, null);
      return;
    }
    if (result.dateOnly) {
      await service.assignDate(item, result.start);
    } else {
      await service.scheduleAction(
        item,
        result.start,
        durationMinutes: item.estimatedMinutes ?? 30,
      );
    }
  }

  Future<void> _toggleBlock(BuildContext context, TimeBlock block) async {
    final ScheduleService service = context.read<ScheduleService>();
    if (block.isCompleted) {
      final bool confirmed = await confirmCancelCompletion(context);
      if (!confirmed || !context.mounted) return;
      await service.uncompleteBlock(block);
      return;
    }
    await service.completeBlock(block);
  }
}

/// 已完成条目：任务或时间块，按完成时间排序。
class _DoneEntry {
  const _DoneEntry.task(this.item) : block = null;
  const _DoneEntry.block(this.block) : item = null;

  final ActionItem? item;
  final TimeBlock? block;

  DateTime get doneAt =>
      item?.completedAt ??
      item?.updatedAt ??
      block?.updatedAt ??
      DateTime.now();
}

/// 今日待办的完成切换：已完成再次点击需确认。
Future<void> _toggleTask(BuildContext context, ActionItem item) async {
  if (item.isCompleted) {
    final bool confirmed = await confirmCancelCompletion(context);
    if (!confirmed || !context.mounted) return;
  }
  await context.read<ActionItemRepository>().toggleCompleted(item.id);
}
