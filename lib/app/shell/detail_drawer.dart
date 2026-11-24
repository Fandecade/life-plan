import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
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

/// 通用行动单元详情抽屉：标题、状态、执行模式、时长、归属、排期与模块扩展槽位。
class ActionItemDetailDrawer extends StatefulWidget {
  const ActionItemDetailDrawer({super.key, required this.actionItemId});

  final String actionItemId;

  @override
  State<ActionItemDetailDrawer> createState() => _ActionItemDetailDrawerState();
}

class _ActionItemDetailDrawerState extends State<ActionItemDetailDrawer> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _ifThenController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final ActionItem? item =
        context.read<ActionItemRepository>().byId(widget.actionItemId);
    _titleController = TextEditingController(text: item?.title ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _ifThenController = TextEditingController(text: item?.ifThenText ?? '');
  }

  @override
  void didUpdateWidget(covariant ActionItemDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actionItemId != widget.actionItemId) {
      final ActionItem? item =
          context.read<ActionItemRepository>().byId(widget.actionItemId);
      _titleController.text = item?.title ?? '';
      _noteController.text = item?.note ?? '';
      _ifThenController.text = item?.ifThenText ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _noteController.dispose();
    _ifThenController.dispose();
    super.dispose();
  }

  /// 输入防抖保存：避免每次按键都触发落盘与整页重建。
  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final ActionItemRepository repo = context.read<ActionItemRepository>();
      final ActionItem? item = repo.byId(widget.actionItemId);
      if (item == null) return;
      final String title = _titleController.text.trim();
      repo.save(
        item.copyWith(
          title: title.isEmpty ? item.title : title,
          note: _noteController.text,
          ifThenText: _ifThenController.text,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ActionItemRepository repo = context.watch<ActionItemRepository>();
    final ActionItem? item = repo.byId(widget.actionItemId);

    if (item == null) {
      return Column(
        children: <Widget>[
          _header(context, null),
          const Expanded(
            child: EmptyState(
              icon: Icons.remove_circle_outline,
              title: '这条行动单元已不存在',
              description: '它可能已被删除或归档。',
            ),
          ),
        ],
      );
    }

    final List<Capability> capabilities = context.watch<CapabilityRepository>().all;
    final TimeBlock? block =
        context.watch<TimeBlockRepository>().forActionItem(item.id);
    final List<AppModuleDescriptor> slots =
        context.watch<ModuleRegistry>().detailSlotModules;

    return Column(
      children: <Widget>[
        _header(context, item),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: <Widget>[
              AppTextField(
                controller: _titleController,
                transparent: true,
                dense: false,
                maxLines: 3,
                minLines: 1,
                hintText: '未命名行动',
                textStyle: context.texts.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                onChanged: (_) => _scheduleSave(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  StatusDot(
                    color: item.isCompleted ? palette.success : palette.accent,
                  ),
                  const SizedBox(width: 6),
                  MetaText(
                    '${item.status.label} · 更新于 ${AppDate.friendlyDay(item.updatedAt)} ${AppDate.timeLabel(item.updatedAt)}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _section(
                context,
                '状态',
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: ActionItemStatus.values.map((ActionItemStatus status) {
                    final bool selected = item.status == status;
                    return AppChip(
                      label: status.label,
                      filled: selected,
                      color: _statusColor(status, palette),
                      onTap: () => repo.setStatus(item.id, status),
                    );
                  }).toList(growable: false),
                ),
              ),
              _section(
                context,
                '执行模式',
                SegmentBar<ExecutionMode>(
                  expand: true,
                  dense: true,
                  options: ExecutionMode.values
                      .map((ExecutionMode mode) =>
                          SegmentOption<ExecutionMode>(value: mode, label: mode.label))
                      .toList(growable: false),
                  value: item.executionMode,
                  onChanged: (ExecutionMode mode) =>
                      repo.save(item.copyWith(executionMode: mode)),
                ),
              ),
              _section(
                context,
                '预计时长',
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: <Widget>[
                    for (final int minutes in <int>[15, 30, 45, 60, 90])
                      AppChip(
                        label: AppDate.durationLabel(minutes),
                        filled: item.estimatedMinutes == minutes,
                        color: palette.accent,
                        onTap: () =>
                            repo.save(item.copyWith(estimatedMinutes: minutes)),
                      ),
                    if (item.estimatedMinutes != null)
                      AppChip(
                        label: '清除',
                        dense: true,
                        onTap: () =>
                            repo.save(item.copyWith(clearEstimatedMinutes: true)),
                      ),
                  ],
                ),
              ),
              _section(
                context,
                '归属能力',
                _capabilityPicker(context, item, capabilities),
              ),
              _section(
                context,
                '时间盒',
                _scheduleCard(context, item, block),
              ),
              _section(
                context,
                '截止日',
                _dueDateCard(context, item),
              ),
              _section(
                context,
                '备注与动机',
                AppTextField(
                  controller: _noteController,
                  maxLines: 4,
                  minLines: 3,
                  hintText: '为什么做这件事？完成后希望得到什么？',
                  onChanged: (_) => _scheduleSave(),
                ),
              ),
              _section(
                context,
                'If–Then 预案',
                AppTextField(
                  controller: _ifThenController,
                  maxLines: 3,
                  minLines: 2,
                  hintText: '如果……（触发情境），那么我就……（具体动作）',
                  onChanged: (_) => _scheduleSave(),
                ),
              ),
              _section(
                context,
                '认知负荷',
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: <Widget>[
                    for (final CognitiveLoad load in CognitiveLoad.values)
                      AppChip(
                        label: load.label,
                        filled: item.cognitiveLoad == load,
                        color: palette.accent,
                        onTap: () =>
                            repo.save(item.copyWith(cognitiveLoad: load)),
                      ),
                  ],
                ),
              ),
              if (slots.isNotEmpty)
                _section(
                  context,
                  '模块扩展',
                  Column(
                    children: slots
                        .map(
                          (AppModuleDescriptor module) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: module.detailSlotBuilder!(context, item),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              Divider(color: palette.hairline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '创建于 ${AppDate.friendlyDay(item.createdAt)} · ID ${item.shortId} · 同步状态 ${_syncLabel(item.syncStatus)}',
                style: context.texts.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: AppGhostButton(
                  label: '删除行动单元',
                  icon: Icons.delete_outline_rounded,
                  tone: palette.danger,
                  onPressed: () => _confirmDelete(item),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, ActionItem? item) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Text('行动单元', style: context.texts.labelMedium),
          const Spacer(),
          if (item != null)
            MetaText(
              item.isInbox ? '任务池' : item.status.label,
              color: palette.textTertiary,
            ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: '关闭',
            onPressed: () => context.read<UiController>().closeDetail(),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: title),
        const SizedBox(height: AppSpacing.sm),
        child,
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _capabilityPicker(
    BuildContext context,
    ActionItem item,
    List<Capability> capabilities,
  ) {
    final AppPalette palette = context.palette;
    Capability? current;
    for (final Capability capability in capabilities) {
      if (capability.id == item.capabilityId) {
        current = capability;
        break;
      }
    }

    return PopupMenuButton<String>(
      position: PopupMenuPosition.under,
      color: palette.surface,
      onSelected: (String value) {
        final ActionItemRepository repo = context.read<ActionItemRepository>();
        if (value == _noneCapability) {
          repo.save(item.copyWith(clearCapability: true));
        } else {
          repo.save(item.copyWith(capabilityId: value));
        }
      },
      itemBuilder: (BuildContext menuContext) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: _noneCapability,
          child: Text('不挂载（留在任务池）', style: menuContext.texts.bodyMedium),
        ),
        if (capabilities.isEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              '还没有能力节点，可在人生规划中创建',
              style: menuContext.texts.bodySmall,
            ),
          ),
        ...capabilities.map(
          (Capability capability) => PopupMenuItem<String>(
            value: capability.id,
            child: Text(capability.title, style: menuContext.texts.bodyMedium),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.hairline),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.link_rounded, size: 15, color: palette.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                current?.title ?? '未挂载（任务池）',
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, ActionItem item, TimeBlock? block) {
    final AppPalette palette = context.palette;
    if (block == null) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.event_busy_outlined, size: 16, color: palette.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '尚未排期',
                style: context.texts.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
            ),
            AppGhostButton(
              label: '排入时间盒',
              icon: Icons.event_available_outlined,
              dense: true,
              onPressed: () => _pickSchedule(item),
            ),
          ],
        ),
      );
    }

    final int blockCount =
        context.watch<TimeBlockRepository>().blocksForActionItem(item.id).length;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.event_available_outlined, size: 16, color: palette.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${AppDate.friendlyDay(block.startAt)} ${AppDate.timeRangeLabel(block.startAt, block.endAt)}',
                      style: context.texts.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppDate.durationLabel(block.plannedMinutes)} · ${block.isCompleted ? '已完成' : '待执行'}'
                      '${blockCount > 1 ? ' · 共 $blockCount 次排期' : ''}',
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              AppCheckCircle(
                checked: block.isCompleted,
                onTap: () {
                  final ScheduleService service = context.read<ScheduleService>();
                  if (block.isCompleted) {
                    service.uncompleteBlock(block);
                  } else {
                    service.completeBlock(block);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              AppGhostButton(
                label: '改期',
                icon: Icons.update_rounded,
                dense: true,
                onPressed: () => _pickSchedule(item),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppGhostButton(
                label: '再排一次',
                icon: Icons.event_repeat_outlined,
                dense: true,
                onPressed: () => _pickSchedule(item, append: true),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppGhostButton(
                label: '取消排期',
                dense: true,
                tone: palette.danger,
                onPressed: () => context.read<ScheduleService>().unschedule(item.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dueDateCard(BuildContext context, ActionItem item) {
    final AppPalette palette = context.palette;
    final DateTime? due = item.dueDate;
    final bool overdue = due != null &&
        !item.isCompleted &&
        AppDate.startOfDay(due).isBefore(AppDate.startOfDay(DateTime.now()));

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.flag_outlined,
            size: 16,
            color: due == null
                ? palette.textTertiary
                : (overdue ? palette.danger : palette.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              due == null
                  ? '未设置截止日'
                  : '${AppDate.fullDateLabel(due)}${overdue ? ' · 已逾期' : ''}',
              style: context.texts.bodyMedium?.copyWith(
                color: due == null
                    ? palette.textSecondary
                    : (overdue ? palette.danger : palette.textPrimary),
              ),
            ),
          ),
          AppGhostButton(
            label: due == null ? '设置' : '修改',
            icon: Icons.event_outlined,
            dense: true,
            onPressed: () => _pickDueDate(item),
          ),
          if (due != null)
            AppGhostButton(
              label: '清除',
              tone: palette.danger,
              dense: true,
              onPressed: () => _clearDueDate(item),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate(ActionItem item) async {
    final DateTime now = DateTime.now();
    final DateTime initial = item.dueDate ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: '选择截止日',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    await context.read<ActionItemRepository>().save(
          item.copyWith(dueDate: picked),
        );
    if (!mounted) return;
    _toast('截止日已设为 ${AppDate.monthDayLabel(picked)}');
  }

  Future<void> _clearDueDate(ActionItem item) async {
    await context.read<ActionItemRepository>().save(
          item.copyWith(clearDueDate: true),
        );
    if (!mounted) return;
    _toast('已清除截止日');
  }

  Future<void> _pickSchedule(
    ActionItem item, {
    bool append = false,
  }) async {
    final DateTime? start = await pickScheduleStart(context);
    if (start == null || !mounted) return;
    await context
        .read<ScheduleService>()
        .scheduleAction(item, start, append: append);
    if (!mounted) return;
    _toast(
      append
          ? '已追加一次排期：${AppDate.friendlyDay(start)} ${AppDate.timeLabel(start)}'
          : '已排入 ${AppDate.friendlyDay(start)} ${AppDate.timeLabel(start)}',
    );
  }

  Future<void> _confirmDelete(ActionItem item) async {
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
          title: Text('删除这条行动单元？', style: dialogContext.texts.titleLarge),
          content: Text(
            '删除采用软删除，数据仍保留在本地以便二期同步，但不会再出现在界面中。',
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
    await context.read<ActionItemRepository>().softDelete(item.id);
    if (!mounted) return;
    context.read<UiController>().closeDetail();
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

  static const String _noneCapability = '__none__';

  Color _statusColor(ActionItemStatus status, AppPalette palette) {
    switch (status) {
      case ActionItemStatus.completed:
        return palette.success;
      case ActionItemStatus.deferred:
        return palette.warning;
      case ActionItemStatus.inProgress:
        return palette.accent;
      case ActionItemStatus.consolidating:
        return palette.accent;
      case ActionItemStatus.scheduled:
        return palette.accent;
      case ActionItemStatus.inbox:
        return palette.textSecondary;
    }
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.localOnly:
        return '本地';
      case SyncStatus.pendingUpdate:
        return '待同步更新';
      case SyncStatus.pendingDelete:
        return '待同步删除';
      case SyncStatus.synced:
        return '已同步';
    }
  }
}