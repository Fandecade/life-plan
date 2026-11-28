import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/node_tone.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';
import 'time_box_common.dart';

/// 从人生规划的全部任务（含子任务）中挑选一个排入指定时间点。
Future<ActionItem?> showTaskPicker(
  BuildContext context, {
  required List<ActionItem> tasks,
  required TaskLabelResolver labels,
  required DateTime target,
  int? durationMinutes,
}) {
  return showAppSheet<ActionItem>(
    context,
    builder: (BuildContext dialogContext) => _TaskPickerDialog(
      tasks: tasks,
      labels: labels,
      target: target,
      durationMinutes: durationMinutes,
    ),
  );
}

class _TaskPickerDialog extends StatefulWidget {
  const _TaskPickerDialog({
    required this.tasks,
    required this.labels,
    required this.target,
    this.durationMinutes,
  });

  final List<ActionItem> tasks;
  final TaskLabelResolver labels;
  final DateTime target;
  final int? durationMinutes;

  @override
  State<_TaskPickerDialog> createState() => _TaskPickerDialogState();
}

class _TaskPickerDialogState extends State<_TaskPickerDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _targetLabel() {
    final DateTime start = widget.target;
    final int? minutes = widget.durationMinutes;
    final String day = AppDate.friendlyDay(start);
    if (minutes == null) return '$day ${AppDate.timeLabel(start)}';
    final DateTime end = start.add(Duration(minutes: minutes));
    return '$day ${AppDate.timeLabel(start)} - ${AppDate.timeLabel(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final String query = _query.toLowerCase();

    final List<ActionItem> filtered =
        widget.tasks.where((ActionItem item) {
          if (query.isEmpty) return true;
          final String label = widget.labels.labelOf(item)?.toLowerCase() ?? '';
          return item.title.toLowerCase().contains(query) ||
              label.contains(query);
        }).toList()..sort((ActionItem a, ActionItem b) {
          final int byDone = (a.isCompleted ? 1 : 0).compareTo(
            b.isCompleted ? 1 : 0,
          );
          if (byDone != 0) return byDone;
          return a.createdAt.compareTo(b.createdAt);
        });

    return AppSheetContent(
      title: '安排任务',
      subtitle: _targetLabel(),
      heightFactor: 0.72,
      maxWidth: 520,
      scrollable: false,
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        children: <Widget>[
          AppTextField(
            controller: _search,
            dense: true,
            hintText: '搜索任务、能力或愿景',
            prefixIcon: Icons.search_rounded,
            onChanged: (String value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: '没有匹配的任务',
                    description: '换个关键词，或去人生规划里新建任务',
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _row(context, filtered[index]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Text('任务来自人生规划 · 含子任务', style: context.texts.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ActionItem item) {
    final AppPalette palette = context.palette;
    final bool isSubtask = item.parentId != null;
    final Color tone = NodeTone.taskOrSubtask(isSubtask: isSubtask);
    final String? label = widget.labels.labelOf(item);

    return InkWell(
      key: ValueKey<String>('task-option-${item.id}'),
      onTap: () => Navigator.of(context).pop(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xxs,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 2.5,
              height: 32,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyMedium?.copyWith(
                      color: item.isCompleted
                          ? palette.textTertiary
                          : palette.textPrimary,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Text(
                        isSubtask ? '子任务' : '任务',
                        style: context.texts.labelSmall?.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (label != null) ...<Widget>[
                        Text(' · ', style: context.texts.labelSmall),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.labelSmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (item.estimatedMinutes != null)
                  Text(
                    AppDate.durationLabel(item.estimatedMinutes),
                    style: context.texts.labelSmall,
                  ),
                const SizedBox(height: 2),
                Text(
                  item.status.label,
                  style: context.texts.labelSmall?.copyWith(
                    color: item.status == ActionItemStatus.completed
                        ? palette.success
                        : (item.status == ActionItemStatus.scheduled
                              ? palette.accent
                              : palette.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
