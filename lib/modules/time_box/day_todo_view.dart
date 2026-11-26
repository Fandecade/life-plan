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

/// 日视图「今日待办」全屏页：未定时间 + 已定时间两组。
///
/// 已完成项保留并划线；未定项通过「排期」打开日历（可只定日期）。
class DayTodoView extends StatelessWidget {
  const DayTodoView({super.key, required this.day, required this.onOpen});

  final DateTime day;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ActionItemRepository actions = context.watch<ActionItemRepository>();
    final TimeBlockRepository blocks = context.watch<TimeBlockRepository>();

    final List<TimeBlock> todayBlocks = blocks.all
        .where((TimeBlock block) => AppDate.isSameDay(block.startAt, day))
        .toList()
      ..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    final Set<String> scheduledTaskIds = <String>{
      for (final TimeBlock block in todayBlocks)
        if (block.actionItemId != null) block.actionItemId!,
    };
    final List<ActionItem> unscheduled = actions.all
        .where((ActionItem item) =>
            item.scheduledDate != null &&
            AppDate.isSameDay(item.scheduledDate!, day) &&
            !scheduledTaskIds.contains(item.id))
        .toList()
      ..sort((ActionItem a, ActionItem b) => a.createdAt.compareTo(b.createdAt));

    if (unscheduled.isEmpty && todayBlocks.isEmpty) {
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
        if (todayBlocks.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _groupLabel(context, '已定时间 · ${todayBlocks.length}'),
          const SizedBox(height: 6),
          for (final TimeBlock block in todayBlocks)
            _scheduledRow(context, palette, actions, block),
        ],
      ],
    );
  }

  Widget _groupLabel(BuildContext context, String text) {
    return Text(text, style: context.texts.labelSmall);
  }

  Widget _unscheduledRow(
    BuildContext context,
    AppPalette palette,
    ActionItem item,
  ) {
    final bool done = item.isCompleted;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => onOpen(item.id),
      child: Row(
        children: <Widget>[
          AppCheckCircle(
            checked: done,
            size: 18,
            padding: 0,
            onTap: () => _toggleTask(context, item),
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
    final ActionItem? task =
        block.actionItemId == null ? null : actions.byId(block.actionItemId!);
    final String title = task?.title ?? block.title;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: task == null ? null : () => onOpen(task.id),
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

  Future<void> _schedule(BuildContext context, ActionItem item) async {
    final SchedulePickResult? result = await pickScheduleResult(
      context,
      initialDate: item.scheduledDate ?? DateTime.now(),
      allowClearDate: item.scheduledDate != null,
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

/// 今日待办的完成切换：已完成再次点击需确认。
Future<void> _toggleTask(BuildContext context, ActionItem item) async {
  if (item.isCompleted) {
    final bool confirmed = await confirmCancelCompletion(context);
    if (!confirmed || !context.mounted) return;
  }
  await context.read<ActionItemRepository>().toggleCompleted(item.id);
}