import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/node_tone.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'vision_layout.dart';

enum MapNodeAction { edit, addCapability, addTask, toggleCollapse, delete }

/// 节点就地重命名输入框：Enter 提交、Esc 取消、失焦自动提交。
class InlineNodeTitle extends StatefulWidget {
  const InlineNodeTitle({
    super.key,
    required this.initial,
    required this.style,
    required this.onCommit,
    required this.onCancel,
    this.maxLines = 1,
  });

  final String initial;
  final TextStyle? style;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;
  final int maxLines;

  @override
  State<InlineNodeTitle> createState() => _InlineNodeTitleState();
}

class _InlineNodeTitleState extends State<InlineNodeTitle> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  late final FocusNode _focusNode = FocusNode();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
    _focusNode.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    if (_finished) return;
    _finished = true;
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onCancel();
      return;
    }
    widget.onCommit(text);
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    widget.onCancel();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        style: widget.style,
        maxLines: widget.maxLines,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: '',
        ),
        cursorWidth: 1.3,
      ),
    );
  }
}

/// 愿景卡：最大尺寸，顶部时间跨度徽章，底部极细主色进度线。
class VisionNodeCard extends StatelessWidget {
  const VisionNodeCard({
    super.key,
    required this.vision,
    required this.completed,
    required this.total,
    required this.progress,
    required this.capabilityCount,
    required this.dimmed,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.onAction,
    required this.onCommitTitle,
    required this.onCancelEdit,
  });

  final Vision vision;
  final int completed;
  final int total;
  final double progress;
  final int capabilityCount;
  final bool dimmed;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;
  final ValueChanged<MapNodeAction> onAction;
  final ValueChanged<String> onCommitTitle;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color accent = context.hexColor(vision.colorHex, fallback: palette.accent);
    final double ratio = progress.clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.38 : 1,
      child: GestureDetector(
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: MapMetrics.visionWidth,
          height: MapMetrics.visionHeight,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected || editing
                  ? accent.withValues(alpha: 0.6)
                  : palette.border,
              width: selected || editing ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppChip(
                    label: '愿景',
                    dense: true,
                    filled: true,
                    color: NodeTone.vision,
                  ),
                  const SizedBox(width: 4),
                  AppChip(label: vision.horizonLabel, dense: true, color: accent),
                  const Spacer(),
                  if (capabilityCount > 0)
                    AppIconButton(
                      icon: vision.isCollapsed
                          ? Icons.unfold_more_rounded
                          : Icons.unfold_less_rounded,
                      iconSize: 13,
                      size: 24,
                      tooltip: vision.isCollapsed ? '展开能力' : '折叠能力',
                      onPressed: () => onAction(MapNodeAction.toggleCollapse),
                    ),
                  _NodeMenu(
                    actions: <MapNodeAction>[
                      MapNodeAction.edit,
                      MapNodeAction.addCapability,
                      MapNodeAction.delete,
                    ],
                    onAction: onAction,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: editing
                    ? InlineNodeTitle(
                        initial: vision.title,
                        maxLines: 2,
                        style: context.texts.titleLarge?.copyWith(height: 1.3),
                        onCommit: onCommitTitle,
                        onCancel: onCancelEdit,
                      )
                    : Text(
                        vision.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleLarge?.copyWith(height: 1.3),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ProgressHairline(value: ratio, color: accent, height: 2.5),
                  ),
                  if (total > 0) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Text('$completed/$total', style: context.texts.labelSmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 能力卡：中等尺寸，标题 + 右侧极细完成度进度条与数字。
class CapabilityNodeCard extends StatelessWidget {
  const CapabilityNodeCard({
    super.key,
    required this.capability,
    required this.completed,
    required this.total,
    required this.progress,
    required this.dimmed,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.onAction,
    required this.onCommitTitle,
    required this.onCancelEdit,
  });

  final Capability capability;
  final int completed;
  final int total;
  final double progress;
  final bool dimmed;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;
  final ValueChanged<MapNodeAction> onAction;
  final ValueChanged<String> onCommitTitle;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double ratio = progress.clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.38 : 1,
      child: GestureDetector(
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: MapMetrics.capabilityWidth,
          height: MapMetrics.capabilityHeight,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 2,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            border: Border.all(
              color: selected || editing
                  ? palette.accent.withValues(alpha: 0.55)
                  : palette.border,
              width: selected || editing ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppChip(
                    label: '能力',
                    dense: true,
                    filled: true,
                    color: NodeTone.capability,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: editing
                        ? InlineNodeTitle(
                            initial: capability.title,
                            style: context.texts.titleMedium,
                            onCommit: onCommitTitle,
                            onCancel: onCancelEdit,
                          )
                        : Text(
                            capability.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.titleMedium,
                          ),
                  ),
                  if (total > 0)
                    AppIconButton(
                      icon: capability.isCollapsed
                          ? Icons.unfold_more_rounded
                          : Icons.unfold_less_rounded,
                      iconSize: 13,
                      size: 22,
                      tooltip: capability.isCollapsed ? '展开任务' : '折叠任务',
                      onPressed: () => onAction(MapNodeAction.toggleCollapse),
                    ),
                  _NodeMenu(
                    actions: <MapNodeAction>[
                      MapNodeAction.edit,
                      MapNodeAction.addTask,
                      MapNodeAction.delete,
                    ],
                    onAction: onAction,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ProgressHairline(
                      value: ratio,
                      height: 2,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$completed/$total',
                    style: context.texts.labelSmall?.copyWith(
                      color: total > 0 ? palette.textSecondary : palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 任务卡：紧凑圆角，左侧完成圆圈，有数据时才显示时长与模式图标；
/// 有子任务时右侧出现折叠箭头。
class TaskNodeCard extends StatelessWidget {
  const TaskNodeCard({
    super.key,
    required this.item,
    required this.dimmed,
    required this.selected,
    required this.editing,
    required this.childCount,
    this.statusNote,
    required this.onTap,

    required this.onToggleComplete,
    required this.onToggleCollapse,
    required this.onCommitTitle,
    required this.onCancelEdit,
  });

  final ActionItem item;
  final bool dimmed;
  final bool selected;
  final bool editing;
  final int childCount;

  /// 巩固中的复习提示（如「巩固·D3」），为空时显示任务/子任务标签。
  final String? statusNote;
  final VoidCallback onTap;

  final VoidCallback onToggleComplete;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onCommitTitle;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.38 : 1,
      child: GestureDetector(
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: MapMetrics.taskWidth,
          height: MapMetrics.taskHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected || editing
                  ? palette.accent.withValues(alpha: 0.55)
                  : palette.border,
              width: selected || editing ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 2.5,
                height: 26,
                decoration: BoxDecoration(
                  color: NodeTone.taskOrSubtask(isSubtask: item.parentId != null),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              AppCheckCircle(
                checked: item.isCompleted,
                size: 17,
                onTap: onToggleComplete,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: editing
                    ? InlineNodeTitle(
                        initial: item.title,
                        maxLines: 2,
                        style: context.texts.bodySmall?.copyWith(
                          fontSize: 12.5,
                          height: 1.25,
                          color: palette.textPrimary,
                        ),
                        onCommit: onCommitTitle,
                        onCancel: onCancelEdit,
                      )
                    : Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodyMedium?.copyWith(
                          decoration:
                              item.isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: palette.textTertiary,
                          color: item.isCompleted
                              ? palette.textTertiary
                              : palette.textPrimary,
                        ),
                      ),
              ),
              if (item.estimatedMinutes != null ||
                  item.executionMode != ExecutionMode.standard)
                const SizedBox(width: AppSpacing.xs + 2),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    statusNote ?? (item.parentId == null ? '任务' : '子任务'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 9.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: statusNote != null
                          ? palette.accent
                          : NodeTone.taskOrSubtask(
                              isSubtask: item.parentId != null,
                            ),
                    ),
                  ),
                  if (item.estimatedMinutes != null)
                    Text(
                      AppDate.durationLabel(item.estimatedMinutes),
                      style: context.texts.labelSmall,
                    ),
                  if (item.executionMode != ExecutionMode.standard)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        _modeIcon(item.executionMode),
                        size: 12,
                        color: palette.accent,
                      ),
                    ),
                ],
              ),
              if (childCount > 0)
                AppIconButton(
                  icon: item.isCollapsed
                      ? Icons.unfold_more_rounded
                      : Icons.unfold_less_rounded,
                  iconSize: 12,
                  size: 20,
                  tooltip: item.isCollapsed ? '展开子任务' : '折叠子任务',
                  onPressed: onToggleCollapse,
                ),
            ],
          ),
        ),
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

class _NodeMenu extends StatelessWidget {
  const _NodeMenu({required this.actions, required this.onAction});

  final List<MapNodeAction> actions;
  final ValueChanged<MapNodeAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext buttonContext) => AppIconButton(
        icon: Icons.more_horiz_rounded,
        iconSize: 15,
        size: 24,
        tooltip: '更多操作',
        onPressed: () => _openMenu(buttonContext),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final AppPalette palette = context.palette;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    RelativeRect position = const RelativeRect.fromLTRB(0, 0, 0, 0);
    if (box != null && overlay != null) {
      position = RelativeRect.fromRect(
        Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );
    }

    final MapNodeAction? action = await showMenu<MapNodeAction>(
      context: context,
      position: position,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: actions
          .map(
            (MapNodeAction item) => PopupMenuItem<MapNodeAction>(
              value: item,
              height: 38,
              child: Text(
                _labelOf(item),
                style: context.texts.bodyMedium?.copyWith(
                  color: item == MapNodeAction.delete ? palette.danger : null,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
    if (action != null) onAction(action);
  }

  String _labelOf(MapNodeAction action) {
    switch (action) {
      case MapNodeAction.edit:
        return '重命名';
      case MapNodeAction.addCapability:
        return '添加能力';
      case MapNodeAction.addTask:
        return '添加任务';
      case MapNodeAction.toggleCollapse:
        return '折叠 / 展开';
      case MapNodeAction.delete:
        return '删除';
    }
  }
}