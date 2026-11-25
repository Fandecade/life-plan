import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/schedule_picker.dart';
import '../../core/services/schedule_service.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/state_views.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 任务池（Inbox）：随时呼出的轻量面板，承接临时待办与突发想法。
class InboxPanel extends StatefulWidget {
  const InboxPanel({super.key});

  @override
  State<InboxPanel> createState() => _InboxPanelState();
}

class _InboxPanelState extends State<InboxPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    _submitting = true;
    await context.read<ActionItemRepository>().create(title: text);
    if (!mounted) return;
    _controller.clear();
    _submitting = false;
    _focusNode.requestFocus();
  }

  Future<void> _schedule(ActionItem item) async {
    final SchedulePickResult? result = await pickScheduleResult(
      context,
      initialDate: DateTime.now(),
    );
    if (result == null || !mounted) return;
    final ScheduleService service = context.read<ScheduleService>();
    if (result.dateOnly) {
      await service.assignDate(item, result.start);
      if (!mounted) return;
      _toast('已安排到 ${AppDate.monthDayLabel(result.start)} 的今日待办');
      return;
    }
    await service.scheduleAction(item, result.start);
    if (!mounted) return;
    _toast(
      '已排入 ${AppDate.friendlyDay(result.start)} ${AppDate.timeLabel(result.start)}',
    );
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
        width: 280,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final UiController ui = context.watch<UiController>();

    return Column(
      children: <Widget>[
        Padding(
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
                    Text('任务池', style: context.texts.headlineSmall),
                    const SizedBox(height: 3),
                    Text(
                      '接住临时想法，之后统一排期或挂到某个能力下',
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: '关闭',
                onPressed: ui.closeInbox,
              ),
            ],
          ),
        ),
        Divider(color: palette.hairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: AppTextField(
            controller: _controller,
            focusNode: _focusNode,
            hintText: '写下一件想做但还没安排的事，回车加入',
            prefixIcon: Icons.add_rounded,
            onSubmitted: (_) => _add(),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppIconButton(
                icon: Icons.keyboard_return_rounded,
                tooltip: '加入任务池',
                iconSize: 15,
                onPressed: _add,
              ),
            ),
          ),
        ),
        Expanded(
          child: Consumer<ActionItemRepository>(
            builder: (BuildContext context, ActionItemRepository repo, _) {
              final List<ActionItem> inbox = repo.inboxItems;
              final List<ActionItem> scheduled = repo.scheduledItems;
              final TimeBlockRepository blocks = context.watch<TimeBlockRepository>();

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: <Widget>[
                  if (inbox.isEmpty)
                    const EmptyState(
                      compact: true,
                      icon: Icons.inbox_outlined,
                      title: '任务池是空的',
                      description: '任何还没安排时间的事，都可以先放在这里。',
                    )
                  else ...<Widget>[
                    SectionHeader(title: '待排期 · ${inbox.length}'),
                    const SizedBox(height: AppSpacing.sm),
                    ...inbox.map(
                      (ActionItem item) => _InboxRow(
                        item: item,
                        block: blocks.forActionItem(item.id),
                        onOpen: () => ui.openDetail(item.id),
                        onSchedule: () => _schedule(item),
                        onToggle: () => context
                            .read<ActionItemRepository>()
                            .toggleCompleted(item.id),
                      ),
                    ),
                  ],
                  if (scheduled.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(
                      title: '已排期',
                      subtitle: '可在时间盒模块查看完整排期',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...scheduled.take(4).map(
                          (ActionItem item) => _InboxRow(
                            item: item,
                            block: blocks.forActionItem(item.id),
                            muted: true,
                            onOpen: () => ui.openDetail(item.id),
                            onSchedule: () {},
                            onToggle: () => context
                                .read<ActionItemRepository>()
                                .toggleCompleted(item.id),
                          ),
                        ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.item,
    required this.onOpen,
    required this.onSchedule,
    required this.onToggle,
    this.block,
    this.muted = false,
  });

  final ActionItem item;
  final TimeBlock? block;
  final bool muted;
  final VoidCallback onOpen;
  final VoidCallback onSchedule;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppCheckCircle(checked: item.isCompleted, onTap: onToggle),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyLarge?.copyWith(
                    color: muted ? palette.textSecondary : palette.textPrimary,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (item.executionMode != ExecutionMode.standard)
                      AppChip(
                        label: item.executionMode.label,
                        dense: true,
                        color: palette.accent,
                        icon: _modeIcon(item.executionMode),
                      ),
                    if (item.estimatedMinutes != null)
                      MetaText(
                        AppDate.durationLabel(item.estimatedMinutes),
                        icon: Icons.schedule_rounded,
                      ),
                    if (block != null)
                      MetaText(
                        '${AppDate.friendlyDay(block!.startAt)} ${AppDate.timeLabel(block!.startAt)}',
                        icon: Icons.event_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!muted)
            AppIconButton(
              icon: Icons.event_available_outlined,
              tooltip: '排入时间盒',
              onPressed: onSchedule,
            ),
        ],
      ),
    );
  }

  IconData _modeIcon(ExecutionMode mode) {
    switch (mode) {
      case ExecutionMode.standard:
        return Icons.check_circle_outline;
      case ExecutionMode.outputLearning:
        return Icons.auto_stories_outlined;
      case ExecutionMode.foggHabit:
        return Icons.loop_outlined;
    }
  }
}