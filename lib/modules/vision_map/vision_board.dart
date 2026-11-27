import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/ui_style.dart';
import '../../core/models/models.dart';
import '../../core/utils/progress_weight.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'vision_nodes.dart';

/// 人生规划「卡片」视图：一个愿景一张大卡，能力双列，任务按需展开。
///
/// 与图谱共享数据与回调，只负责排版与阅读节奏，不改变任何业务状态。
class VisionBoardView extends StatefulWidget {
  const VisionBoardView({
    super.key,
    required this.vision,
    required this.capabilities,
    required this.tasksByCapability,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onVisionAction,
    required this.onCapabilityAction,
  });

  final Vision vision;
  final List<Capability> capabilities;
  final Map<String, List<ActionItem>> tasksByCapability;
  final ValueChanged<ActionItem> onOpenTask;
  final ValueChanged<ActionItem> onToggleTask;
  final void Function(Vision vision, MapNodeAction action) onVisionAction;
  final void Function(Capability capability, MapNodeAction action)
      onCapabilityAction;

  @override
  State<VisionBoardView> createState() => _VisionBoardViewState();
}

class _VisionBoardViewState extends State<VisionBoardView> {
  static const double _maxContentWidth = 1120;
  static const int _previewTaskCount = 5;

  /// 默认全部收起：先看结构与进度，想深入再展开任务。
  final Set<String> _expanded = <String>{};
  final Set<String> _showAll = <String>{};
  final Set<String> _completedOpen = <String>{};
  bool _heroCollapsed = false;

  List<ActionItem> _tasksOf(Capability capability) =>
      widget.tasksByCapability[capability.id] ?? const <ActionItem>[];

  List<ActionItem> _rootTasks(Capability capability) {
    final List<ActionItem> items = _tasksOf(capability)
        .where((ActionItem item) => item.parentId == null)
        .toList(growable: false);
    items.sort(
      (ActionItem a, ActionItem b) => a.createdAt.compareTo(b.createdAt),
    );
    return items;
  }

  int _childrenOf(Capability capability, ActionItem task) => _tasksOf(capability)
      .where((ActionItem item) => item.parentId == task.id)
      .length;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color accent =
        context.hexColor(widget.vision.colorHex, fallback: palette.accent);
    final List<ActionItem> allTasks = <ActionItem>[
      for (final Capability capability in widget.capabilities)
        ..._tasksOf(capability),
    ];
    final int milestoneTotal = widget.capabilities.fold<int>(
      0,
      (int sum, Capability item) => sum + item.milestones.length,
    );
    final int milestoneDone = widget.capabilities.fold<int>(
      0,
      (int sum, Capability item) => sum + item.achievedMilestones,
    );
    final double progress = ProgressWeight.ratio(allTasks);
    final int doneTasks =
        allTasks.where((ActionItem item) => item.isCompleted).length;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double pageWidth = constraints.maxWidth > _maxContentWidth
            ? _maxContentWidth
            : constraints.maxWidth;
        final double hPad = pageWidth >= 720 ? 24 : 16;
        final double available = pageWidth - hPad * 2;
        final bool twoCol = available >= 640;
        const double gap = AppSpacing.md;
        final double cardWidth = twoCol ? (available - gap) / 2 : available;

        return Center(
          child: SizedBox(
            width: pageWidth,
            child: ListView(
              padding: EdgeInsets.fromLTRB(hPad, AppSpacing.xl, hPad, 40),
              children: <Widget>[
                _buildHero(
                  context,
                  palette,
                  accent,
                  progress: progress,
                  doneTasks: doneTasks,
                  taskCount: allTasks.length,
                  milestoneDone: milestoneDone,
                  milestoneTotal: milestoneTotal,
                ),
                const SizedBox(height: AppSpacing.xl + 4),
                if (!_heroCollapsed) ...<Widget>[
                  _buildCapabilityHeader(context, palette, accent),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.capabilities.isEmpty)
                    _buildEmptyCapabilities(context, palette, accent)
                  else
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: <Widget>[
                        for (final Capability capability
                            in widget.capabilities)
                          SizedBox(
                            width: cardWidth,
                            child: _buildCapabilityCard(
                              context,
                              palette,
                              accent,
                              capability,
                            ),
                          ),
                      ],
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '还有 ${widget.capabilities.length} 个能力，点击上方卡片展开',
                      style: context.texts.labelSmall
                          ?.copyWith(color: palette.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(
    BuildContext context,
    AppPalette palette,
    Color accent, {
    required double progress,
    required int doneTasks,
    required int taskCount,
    required int milestoneDone,
    required int milestoneTotal,
  }) {
    final Vision vision = widget.vision;
    final String description = vision.description.trim();
    return _BoardSurface(
      key: const ValueKey<String>('vision-board-hero'),
      accent: accent,
      radius: AppRadius.xl + 4,
      padding: const EdgeInsets.all(AppSpacing.xl),
      elevated: true,
      onTap: () => setState(() => _heroCollapsed = !_heroCollapsed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppChip(
                label: '愿景',
                color: accent,
                filled: true,
                dense: true,
              ),
              const SizedBox(width: 6),
              AppChip(label: vision.timeHorizon, dense: true),
              const Spacer(),
              _menuButton(
                context,
                items: <PopupMenuEntry<String>>[
                  _menuItem(context, 'edit', '编辑愿景'),
                  _menuItem(context, 'add', '添加能力'),
                  _menuItem(context, 'delete', '删除愿景', danger: true),
                ],
                onSelected: (String value) {
                  switch (value) {
                    case 'edit':
                      widget.onVisionAction(vision, MapNodeAction.edit);
                    case 'add':
                      widget.onVisionAction(
                        vision,
                        MapNodeAction.addCapability,
                      );
                    case 'delete':
                      widget.onVisionAction(vision, MapNodeAction.delete);
                  }
                },
              ),
              const SizedBox(width: 2),
              Icon(
                _heroCollapsed
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
                size: 18,
                color: palette.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            vision.title.isEmpty ? '未命名愿景' : vision.title,
            style: context.texts.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          if (description.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium?.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg + 2),
          Row(
            children: <Widget>[
              Text(
                '${(progress * 100).round()}%',
                style: context.texts.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ProgressHairline(
                  value: progress,
                  color: accent,
                  height: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${widget.capabilities.length} 个能力 · $taskCount 个任务'
            '（完成 $doneTasks）'
            '${milestoneTotal > 0 ? ' · $milestoneDone/$milestoneTotal 阶段成果' : ''}',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityHeader(
    BuildContext context,
    AppPalette palette,
    Color accent,
  ) {
    return Row(
      children: <Widget>[
        Text(
          '能力',
          style: context.texts.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${widget.capabilities.length}',
          style: context.texts.labelSmall?.copyWith(color: palette.textTertiary),
        ),
        const Spacer(),
        AppGhostButton(
          label: '添加能力',
          icon: Icons.add_rounded,
          dense: true,
          tone: accent,
          onPressed: () => widget.onVisionAction(
            widget.vision,
            MapNodeAction.addCapability,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCapabilities(
    BuildContext context,
    AppPalette palette,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl + 8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.workspaces_outline,
            size: 22,
            color: palette.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '这个愿景还没有能力',
            style: context.texts.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '先拆出 2–4 个关键能力，再落到具体任务。',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppGhostButton(
            label: '添加第一个能力',
            icon: Icons.add_rounded,
            dense: true,
            tone: accent,
            onPressed: () => widget.onVisionAction(
              widget.vision,
              MapNodeAction.addCapability,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityCard(
    BuildContext context,
    AppPalette palette,
    Color accent,
    Capability capability,
  ) {
    final List<ActionItem> tasks = _tasksOf(capability);
    final List<ActionItem> roots = _rootTasks(capability);
    final List<ActionItem> pending =
        roots.where((ActionItem item) => !item.isCompleted).toList();
    final List<ActionItem> completed =
        roots.where((ActionItem item) => item.isCompleted).toList();
    final bool expanded = _expanded.contains(capability.id);
    final bool showAll = _showAll.contains(capability.id);
    final List<ActionItem> visible =
        showAll ? pending : pending.take(_previewTaskCount).toList();
    final int hiddenCount = pending.length - visible.length;
    final double progress = ProgressWeight.ratio(tasks);
    final int milestoneTotal = capability.milestones.length;
    final int milestoneDone = capability.achievedMilestones;

    return _BoardSurface(
      key: ValueKey<String>('vision-board-capability-${capability.id}'),
      accent: accent,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () {
        setState(() {
          if (expanded) {
            _expanded.remove(capability.id);
          } else {
            _expanded.add(capability.id);
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusDot(color: accent, size: 6),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  capability.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _menuButton(
                context,
                items: <PopupMenuEntry<String>>[
                  _menuItem(context, 'edit', '编辑能力'),
                  _menuItem(context, 'milestones', '阶段成果'),
                  _menuItem(context, 'addTask', '添加任务'),
                  _menuItem(context, 'delete', '删除能力', danger: true),
                ],
                onSelected: (String value) {
                  switch (value) {
                    case 'edit':
                      widget.onCapabilityAction(
                        capability,
                        MapNodeAction.edit,
                      );
                    case 'milestones':
                      widget.onCapabilityAction(
                        capability,
                        MapNodeAction.milestones,
                      );
                    case 'addTask':
                      widget.onCapabilityAction(
                        capability,
                        MapNodeAction.addTask,
                      );
                    case 'delete':
                      widget.onCapabilityAction(
                        capability,
                        MapNodeAction.delete,
                      );
                  }
                },
              ),
            ],
          ),
          if (capability.targetLevel.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              capability.targetLevel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md + 2),
          Row(
            children: <Widget>[
              Expanded(
                child: ProgressHairline(
                  value: progress,
                  color: accent,
                  height: 3,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(progress * 100).round()}%',
                style: context.texts.labelMedium?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              AppChip(label: '${roots.length} 个任务', dense: true),
              if (milestoneTotal > 0)
                AppChip(
                  label: '阶段成果 $milestoneDone/$milestoneTotal',
                  dense: true,
                ),
              if (completed.isNotEmpty)
                AppChip(label: '已完成 ${completed.length}', dense: true),
            ],
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: palette.hairline),
            const SizedBox(height: 6),
            if (roots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  '还没有任务，点右上「⋯」添加',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              )
            else ...<Widget>[
              KeyedSubtree(
                key: ValueKey<String>(
                  'vision-board-tasks-${capability.id}',
                ),
                child: Column(
                  children: <Widget>[
                    for (final ActionItem task in visible)
                      _buildTaskRow(
                        context,
                        palette,
                        accent,
                        capability,
                        task,
                        childCount: _childrenOf(capability, task),
                      ),
                  ],
                ),
              ),
              if (hiddenCount > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppGhostButton(
                    label: '查看全部 +$hiddenCount',
                    dense: true,
                    onPressed: () =>
                        setState(() => _showAll.add(capability.id)),
                  ),
                ),
              if (completed.isNotEmpty) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppGhostButton(
                    label: _completedOpen.contains(capability.id)
                        ? '收起已完成'
                        : '展开已完成',
                    dense: true,
                    onPressed: () {
                      setState(() {
                        if (_completedOpen.contains(capability.id)) {
                          _completedOpen.remove(capability.id);
                        } else {
                          _completedOpen.add(capability.id);
                        }
                      });
                    },
                  ),
                ),
                if (_completedOpen.contains(capability.id))
                  for (final ActionItem task in completed)
                    _buildTaskRow(
                      context,
                      palette,
                      accent,
                      capability,
                      task,
                      childCount: _childrenOf(capability, task),
                    ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    AppPalette palette,
    Color accent,
    Capability capability,
    ActionItem task, {
    required int childCount,
  }) {
    final bool done = task.isCompleted;
    final DateTime? date = task.dueDate ?? task.scheduledDate;
    final String? note = _statusNote(task);
    return InkWell(
      key: ValueKey<String>('vision-board-task-${task.id}'),
      onTap: () => widget.onOpenTask(task),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            AppCheckCircle(
              checked: done,
              size: 17,
              padding: 2,
              color: accent,
              onTap: () => widget.onToggleTask(task),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium?.copyWith(
                  color: done ? palette.textTertiary : palette.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (childCount > 0) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '+$childCount',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
            if (note != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                note,
                style: context.texts.labelSmall?.copyWith(color: accent),
              ),
            ],
            if (date != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                '${date.month}/${date.day}',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _statusNote(ActionItem item) {
    switch (item.status) {
      case ActionItemStatus.consolidating:
        return '巩固中';
      case ActionItemStatus.inProgress:
        return '进行中';
      case ActionItemStatus.deferred:
        return '已推迟';
      case ActionItemStatus.completed:
      case ActionItemStatus.scheduled:
      case ActionItemStatus.inbox:
        return null;
    }
  }

  Widget _menuButton(
    BuildContext context, {
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      padding: EdgeInsets.zero,
      iconSize: 18,
      position: PopupMenuPosition.under,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: context.palette.textTertiary,
      ),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => items,
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String value,
    String label, {
    bool danger = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Text(
        label,
        style: context.texts.bodyMedium?.copyWith(
          color: danger ? context.palette.danger : null,
        ),
      ),
    );
  }
}

/// 卡片底板：愿景色只做低透明渐变与描边，保持整体克制。
class _BoardSurface extends StatelessWidget {
  const _BoardSurface({
    super.key,
    required this.accent,
    required this.child,
    this.radius = AppRadius.xl,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.elevated = false,
  });

  final Color accent;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color base = palette.style == AppUiStyle.refresh &&
            palette.glassEnabled
        ? palette.glass
        : palette.surface;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Widget body = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              accent.withValues(alpha: elevated ? 0.20 : 0.09),
              base,
            ),
            base,
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: Color.alphaBlend(
            accent.withValues(alpha: elevated ? 0.22 : 0.12),
            palette.glassBorder,
          ),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: body,
      ),
    );
  }
}