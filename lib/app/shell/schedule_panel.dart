import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/schedule_service.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/state_views.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 已排班面板：按日期列出所有时间块，点击任意条目跳到时间盒对应位置。
class SchedulePanel extends StatelessWidget {
  const SchedulePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<TimeBlock> blocks = List<TimeBlock>.from(
      context.watch<TimeBlockRepository>().all,
    )..sort((TimeBlock a, TimeBlock b) => a.startAt.compareTo(b.startAt));
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final List<Capability> capabilities =
        context.watch<CapabilityRepository>().all;
    final List<Vision> visions = context.watch<VisionRepository>().all;
    final UiController ui = context.watch<UiController>();

    final Map<String, ActionItem> tasksById = <String, ActionItem>{
      for (final ActionItem item in actions) item.id: item,
    };
    final Map<String, Capability> capabilitiesById = <String, Capability>{
      for (final Capability item in capabilities) item.id: item,
    };
    final Map<String, Vision> visionsById = <String, Vision>{
      for (final Vision item in visions) item.id: item,
    };

    final List<TimeBlock> pending = blocks
        .where((TimeBlock block) => !block.isCompleted)
        .toList(growable: false);
    final List<TimeBlock> done = blocks
        .where((TimeBlock block) => block.isCompleted)
        .toList(growable: false);

    final List<Widget> rows = <Widget>[];
    String? lastDateKey;
    for (final TimeBlock block in pending) {
      final String key = AppDate.dateKey(block.startAt);
      if (key != lastDateKey) {
        if (lastDateKey != null) {
          rows.add(const SizedBox(height: AppSpacing.sm));
        }
        rows.add(_dateHeader(context, block.startAt));
        rows.add(const SizedBox(height: 6));
        lastDateKey = key;
      }
      rows.add(_blockRow(
        context,
        block,
        tasksById[block.actionItemId],
        capabilitiesById,
        visionsById,
        ui,
      ));
    }

    return Column(
      children: <Widget>[
        _header(context, pending.length, done.length, ui),
        Divider(color: palette.hairline),
        Expanded(
          child: blocks.isEmpty
              ? const EmptyState(
                  icon: Icons.event_note_outlined,
                  title: '还没有排班',
                  description: '去时间盒拖拽圈选时间格，或从任务池把任务排期。',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: <Widget>[
                    if (pending.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          '当前没有待执行的时间块。',
                          style: context.texts.bodySmall,
                        ),
                      )
                    else
                      ...rows,
                    if (done.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(title: '已完成 · ${done.length}'),
                      const SizedBox(height: AppSpacing.sm),
                      ...done.map(
                        (TimeBlock block) => _blockRow(
                          context,
                          block,
                          tasksById[block.actionItemId],
                          capabilitiesById,
                          visionsById,
                          ui,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    int pending,
    int done,
    UiController ui,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('安排记录', style: context.texts.headlineSmall),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$pending 待执行 · $done 已完成',
                      style: context.texts.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '点击任意条目跳到时间盒对应位置',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: '关闭',
            onPressed: ui.closeSchedule,
          ),
        ],
      ),
    );
  }

  Widget _dateHeader(BuildContext context, DateTime date) {
    final AppPalette palette = context.palette;
    final bool isToday = AppDate.isSameDay(date, DateTime.now());
    return Row(
      children: <Widget>[
        StatusDot(
          color: isToday ? palette.accent : palette.textTertiary,
          size: 4,
        ),
        const SizedBox(width: 6),
        Text(
          '${AppDate.friendlyDay(date)} · ${AppDate.weekdayLabel(date)}',
          style: context.texts.labelMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(width: 6),
        Text(AppDate.monthDayLabel(date), style: context.texts.labelSmall),
      ],
    );
  }

  Widget _blockRow(
    BuildContext context,
    TimeBlock block,
    ActionItem? task,
    Map<String, Capability> capabilitiesById,
    Map<String, Vision> visionsById,
    UiController ui,
  ) {
    final AppPalette palette = context.palette;
    final String? capabilityId = task?.capabilityId;
    final Capability? capability =
        capabilityId == null ? null : capabilitiesById[capabilityId];
    final Vision? vision =
        capability == null ? null : visionsById[capability.visionId];
    final List<String> parts = <String>[
      if (vision != null) vision.title,
      if (capability != null) capability.title,
    ];
    final String? label = parts.isEmpty ? null : parts.join(' · ');

    return AppCard(
      key: ValueKey<String>('schedule-row-${block.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 9,
      ),
      onTap: () => ui.jumpToSchedule(block.startAt, block.id),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppDate.timeLabel(block.startAt), style: context.texts.titleSmall),
                Text(AppDate.timeLabel(block.endAt), style: context.texts.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  block.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyMedium?.copyWith(
                    decoration:
                        block.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: palette.textTertiary,
                    color: block.isCompleted
                        ? palette.textTertiary
                        : palette.textPrimary,
                  ),
                ),
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (block.actionItemId != null)
            AppCheckCircle(
              checked: block.isCompleted,
              size: 16,
              padding: 0,
              onTap: () => _toggle(context, block),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: palette.textTertiary,
            ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, TimeBlock block) async {
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