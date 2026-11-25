import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/state/ui_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/state_views.dart';
import 'vision_canvas.dart';
import 'capability_milestones_dialog.dart';
import 'vision_editor_dialogs.dart';
import 'vision_nodes.dart';

class VisionMapPage extends StatefulWidget {
  const VisionMapPage({super.key});

  @override
  State<VisionMapPage> createState() => _VisionMapPageState();
}

class _VisionMapPageState extends State<VisionMapPage> {
  final TransformationController _transform = TransformationController();
  String? _activeVisionId;
  String? _dragOverVisionId;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Vision? _currentVision(List<Vision> visions) {
    for (final Vision vision in visions) {
      if (vision.id == _activeVisionId) return vision;
    }
    return visions.isEmpty ? null : visions.first;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<Vision> visions = context.watch<VisionRepository>().ordered;
    final UiController ui = context.watch<UiController>();
    final Vision? vision = _currentVision(visions);
    final String? focusCapabilityId = ui.focusCapabilityId;
    final String? focusTaskId = ui.focusTaskId;
    if (focusTaskId != null && vision != null) {
      final ActionItem? target = context.read<ActionItemRepository>().byId(focusTaskId);
      final String? targetVisionId = target?.capabilityId == null
          ? null
          : context
              .read<CapabilityRepository>()
              .byId(target!.capabilityId!)
              ?.visionId;
      if (targetVisionId != null && targetVisionId != vision.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _activeVisionId = targetVisionId);
        });
      }
    }
    if (focusCapabilityId != null && vision != null) {
      final Capability? target =
          context.read<CapabilityRepository>().byId(focusCapabilityId);
      if (target != null && target.visionId != vision.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _activeVisionId = target.visionId);
        });
      }
    }

    if (vision == null) {
      return EmptyState(
        icon: Icons.account_tree_outlined,
        title: '还没有愿景',
        description: '先写下 3 年后想成为的样子，再往下拆成能力与可执行任务。',
        action: AppPrimaryButton(
          label: '创建第一个愿景',
          icon: Icons.add_rounded,
          onPressed: _createVision,
        ),
      );
    }

    final List<Capability> capabilities = context
        .watch<CapabilityRepository>()
        .all
        .where((Capability capability) => capability.visionId == vision.id)
        .toList(growable: false);
    final List<ActionItem> actionItems = context.watch<ActionItemRepository>().all;

    final Map<String, List<ActionItem>> tasksByCapability =
        <String, List<ActionItem>>{};
    for (final Capability capability in capabilities) {
      final List<ActionItem> tasks = actionItems
          .where((ActionItem item) => item.capabilityId == capability.id)
          .toList();
      tasks.sort((ActionItem a, ActionItem b) => a.createdAt.compareTo(b.createdAt));
      tasksByCapability[capability.id] = tasks;
    }

    return Column(
      children: <Widget>[
        _toolbar(context, visions, vision),
        Divider(color: palette.hairline, height: 1),
        Expanded(
          child: ClipRect(
            child: VisionCanvas(
              key: ValueKey<String>(vision.id),
              vision: vision,
              capabilities: capabilities,
              tasksByCapability: tasksByCapability,
              transformController: _transform,
              onOpenTask: (ActionItem item) =>
                  context.read<UiController>().openDetail(item.id),
              onToggleTask: (ActionItem item) =>
                  context.read<ActionItemRepository>().toggleCompleted(item.id),
              onVisionAction: (Vision target, MapNodeAction action) =>
                  _handleVisionAction(vision, capabilities, tasksByCapability, action),
              onCapabilityAction:
                  (Capability capability, MapNodeAction action) =>
                      _handleCapabilityAction(
                capability,
                tasksByCapability[capability.id] ?? const <ActionItem>[],
                action,
              ),
              onTaskAction: _handleTaskAction,
              onRequestVisionSwitch: (String visionId) {
                setState(() => _activeVisionId = visionId);
                _transform.value = Matrix4.identity();
              },
              focusNodeId: focusCapabilityId,
              focusTaskId: focusTaskId,
              onFocusHandled: () {
                final UiController controller = context.read<UiController>();
                controller.consumeCapabilityFocus();
                controller.consumeTaskFocus();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _draggablePill(
    BuildContext context,
    AppPalette palette,
    List<Vision> visions,
    int index,
    Vision current,
  ) {
    final Vision vision = visions[index];
    final Color accent = context.hexColor(
      vision.colorHex,
      fallback: palette.accent,
    );
    final Widget pill = _VisionPill(
      vision: vision,
      selected: vision.id == current.id,
      onTap: () {
        setState(() => _activeVisionId = vision.id);
        _transform.value = Matrix4.identity();
      },
      onMenuRequested: (Offset position) =>
          _showVisionMenu(context, vision, position),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (DragTargetDetails<String> details) {
        if (details.data == vision.id) return false;
        setState(() => _dragOverVisionId = vision.id);
        return true;
      },
      onLeave: (_) {
        if (_dragOverVisionId == vision.id) {
          setState(() => _dragOverVisionId = null);
        }
      },
      onAcceptWithDetails: (DragTargetDetails<String> details) {
        setState(() => _dragOverVisionId = null);
        context.read<VisionRepository>().moveTo(details.data, index);
      },
      builder: (
        BuildContext context,
        List<String?> candidate,
        List<dynamic> rejected,
      ) {
        final bool active = candidate.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: active ? 2 : 0,
                height: 18,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Draggable<String>(
                data: vision.id,
                feedback: _pillFeedback(context, palette, vision, accent),
                childWhenDragging: Opacity(opacity: 0.35, child: pill),
                child: pill,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pillFeedback(
    BuildContext context,
    AppPalette palette,
    Vision vision,
    Color accent,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: accent.withValues(alpha: 0.6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.textPrimary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 196),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StatusDot(color: accent, size: 5),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                vision.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelLarge?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, List<Vision> visions, Vision current) {
    final AppPalette palette = context.palette;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < visions.length; i++)
                    _draggablePill(context, palette, visions, i, current),
                  AppIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '新建愿景',
                    onPressed: _createVision,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 18,
            child: VerticalDivider(
              thickness: 1,
              width: AppSpacing.md,
              color: palette.hairline,
            ),
          ),
          AppIconButton(
            icon: Icons.remove_rounded,
            tooltip: '缩小',
            onPressed: () => _zoom(0.86),
          ),
          AppIconButton(
            icon: Icons.add_rounded,
            tooltip: '放大',
            onPressed: () => _zoom(1.16),
          ),
          AppIconButton(
            icon: Icons.center_focus_strong_outlined,
            tooltip: '回到根节点',
            onPressed: () {
              _transform.value = Matrix4.identity();
              _toast('已回到愿景节点');
            },
          ),
          AppIconButton(
            icon: Icons.auto_awesome_motion_outlined,
            tooltip: '重新自动排版',
            onPressed: () => _relayout(current, context),
          ),
        ],
      ),
    );
  }

  void _zoom(double factor) {
    final Size size = MediaQuery.sizeOf(context);
    final Offset center = Offset(size.width * 0.5, size.height * 0.42);
    final Matrix4 matrix = _transform.value.clone()
      ..translate(center.dx, center.dy)
      ..scale(factor)
      ..translate(-center.dx, -center.dy);
    _transform.value = matrix;
  }

  Future<void> _relayout(Vision vision, BuildContext context) async {
    final CapabilityRepository capabilityRepo = context.read<CapabilityRepository>();
    final ActionItemRepository actionRepo = context.read<ActionItemRepository>();
    final VisionRepository visionRepo = context.read<VisionRepository>();

    final List<Capability> capabilities = capabilityRepo.all
        .where((Capability capability) => capability.visionId == vision.id)
        .toList(growable: false);
    for (final Capability capability in capabilities) {
      await capabilityRepo.save(capability.copyWith(posX: 0, posY: 0));
      for (final ActionItem item in actionRepo.forCapability(capability.id)) {
        await actionRepo.save(item.copyWith(posX: 0, posY: 0));
      }
    }
    await visionRepo.save(vision.copyWith(posX: 0, posY: 0));
    if (!mounted) return;
    _transform.value = Matrix4.identity();
    _toast('已恢复自动排版');
  }

  Future<void> _createVision() async {
    final List<String>? result = await showEditorDialog(
      context,
      title: '新建愿景',
      fields: const <EditorField>[
        EditorField(label: '愿景标题', hint: '例如：成为能独立交付产品的创造者'),
        EditorField(
          label: '一句话描述',
          hint: '为什么要走向这个方向',
          maxLines: 3,
        ),
        EditorField(label: '时间跨度', hint: '3年', initial: '3年'),
      ],
      confirmLabel: '创建',
    );
    if (result == null || !mounted) return;

    final Vision vision = await context.read<VisionRepository>().create(
          title: result[0],
          description: result.length > 1 ? result[1] : '',
          timeHorizon: result.length > 2 && result[2].isNotEmpty ? result[2] : '3年',
        );
    if (!mounted) return;
    setState(() => _activeVisionId = vision.id);
    _transform.value = Matrix4.identity();
  }

  Future<void> _handleVisionAction(
    Vision vision,
    List<Capability> capabilities,
    Map<String, List<ActionItem>> tasksByCapability,
    MapNodeAction action,
  ) async {
    switch (action) {
      case MapNodeAction.edit:
        await _editVision(vision);
      case MapNodeAction.toggleCollapse:
        await context
            .read<VisionRepository>()
            .save(vision.copyWith(isCollapsed: !vision.isCollapsed));
      case MapNodeAction.addCapability:
        await _createCapability(vision);
      case MapNodeAction.delete:
        await _deleteVision(vision);
      case MapNodeAction.addTask:
        break;
      case MapNodeAction.milestones:
        break;
    }
  }

  Future<void> _editVision(Vision vision) async {
    final List<String>? result = await showEditorDialog(
      context,
      title: '编辑愿景',
      fields: <EditorField>[
        EditorField(label: '愿景标题', initial: vision.title),
        EditorField(
          label: '一句话描述',
          initial: vision.description,
          maxLines: 3,
        ),
        EditorField(label: '时间跨度', initial: vision.timeHorizon),
      ],
    );
    if (result == null || !mounted) return;
    await context.read<VisionRepository>().save(
          vision.copyWith(
            title: result[0],
            description: result.length > 1 ? result[1] : '',
            timeHorizon: result.length > 2 && result[2].isNotEmpty
                ? result[2]
                : vision.timeHorizon,
          ),
        );
  }

  Future<void> _createCapability(Vision vision) async {
    final List<String>? result = await showEditorDialog(
      context,
      title: '添加能力',
      fields: const <EditorField>[
        EditorField(label: '能力名称', hint: '例如：产品设计与实现'),
        EditorField(label: '目标水平', hint: '例如：能独立完成端到端产品'),
      ],
      confirmLabel: '创建',
    );
    if (result == null || !mounted) return;
    await context.read<CapabilityRepository>().create(
          visionId: vision.id,
          title: result[0],
          targetLevel: result.length > 1 ? result[1] : '',
        );
  }

  Future<void> _deleteVision(Vision vision) async {
    final bool ok = await _confirm(
      title: '删除整个愿景？',
      message: '将同时软删除其下的能力与任务，数据仍保留在本地以便二期同步。',
    );
    if (!ok || !mounted) return;

    final CapabilityRepository capabilityRepo =
        context.read<CapabilityRepository>();
    final ActionItemRepository actionRepo = context.read<ActionItemRepository>();
    final List<Capability> capabilities = capabilityRepo.forVision(vision.id);
    final Set<String> capabilityIds =
        capabilities.map((Capability item) => item.id).toSet();
    final List<ActionItem> tasks = actionRepo.all
        .where((ActionItem item) =>
            item.capabilityId != null &&
            capabilityIds.contains(item.capabilityId))
        .toList(growable: false);

    for (final ActionItem item in tasks) {
      await actionRepo.softDelete(item.id);
    }
    for (final Capability capability in capabilities) {
      await capabilityRepo.softDelete(capability.id);
    }
    await context.read<VisionRepository>().softDelete(vision.id);
    if (!mounted) return;
    setState(() {
      if (_activeVisionId == vision.id) _activeVisionId = null;
    });
    _toast('愿景已删除');
  }

  /// 愿景切换胶囊的右键 / 长按菜单：调整顺序或删除。
  Future<void> _showVisionMenu(
    BuildContext anchorContext,
    Vision vision,
    Offset globalPosition,
  ) async {
    final AppPalette palette = anchorContext.palette;
    final RenderBox overlay =
        Overlay.of(anchorContext).context.findRenderObject()! as RenderBox;
    final String? action = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'up',
          height: 38,
          child: Text('前移', style: context.texts.bodyMedium),
        ),
        PopupMenuItem<String>(
          value: 'down',
          height: 38,
          child: Text('后移', style: context.texts.bodyMedium),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          height: 38,
          child: Text(
            '删除这个愿景',
            style: context.texts.bodyMedium?.copyWith(color: palette.danger),
          ),
        ),
      ],
    );
    if (action == null || !mounted) return;
    final VisionRepository repo = context.read<VisionRepository>();
    switch (action) {
      case 'up':
        await repo.move(vision.id, -1);
      case 'down':
        await repo.move(vision.id, 1);
      case 'delete':
        await _deleteVision(vision);
    }
  }

  Future<void> _handleCapabilityAction(
    Capability capability,
    List<ActionItem> tasks,
    MapNodeAction action,
  ) async {
    switch (action) {
      case MapNodeAction.edit:
        await _editCapability(capability);
      case MapNodeAction.toggleCollapse:
        await context
            .read<CapabilityRepository>()
            .save(capability.copyWith(isCollapsed: !capability.isCollapsed));
      case MapNodeAction.addTask:
        await _createTask(capability);
      case MapNodeAction.milestones:
        await showCapabilityMilestonesDialog(
          context,
          capability: capability,
        );
      case MapNodeAction.delete:
        await _deleteCapability(capability, tasks);
      case MapNodeAction.addCapability:
        break;
    }
  }

  Future<void> _handleTaskAction(
    ActionItem item,
    MapNodeAction action,
  ) async {
    switch (action) {
      case MapNodeAction.edit:
        context.read<UiController>().openDetail(item.id);
      case MapNodeAction.addTask:
        await _createSubTask(item);
      case MapNodeAction.delete:
        await _deleteTask(item);
      default:
        break;
    }
  }

  int _taskDepth(ActionItem item) {
    final ActionItemRepository repo = context.read<ActionItemRepository>();
    int depth = 1;
    String? parentId = item.parentId;
    int guard = 0;
    while (parentId != null && guard < 12) {
      final ActionItem? parent = repo.byId(parentId);
      if (parent == null) break;
      depth++;
      parentId = parent.parentId;
      guard++;
    }
    return depth;
  }

  Future<void> _createSubTask(ActionItem parent) async {
    if (_taskDepth(parent) >= 3) {
      _toast('最多 3 级子任务');
      return;
    }
    final TaskDraft? draft = await showTaskDialog(context);
    if (draft == null || !mounted) return;
    await context.read<ActionItemRepository>().create(
          title: draft.title,
          capabilityId: parent.capabilityId,
          parentId: parent.id,
          estimatedMinutes: draft.minutes,
        );
  }

  List<ActionItem> _descendantsOf(
    ActionItemRepository repo,
    String parentId,
  ) {
    final List<ActionItem> result = <ActionItem>[];
    for (final ActionItem child in repo.childrenOf(parentId)) {
      result.add(child);
      result.addAll(_descendantsOf(repo, child.id));
    }
    return result;
  }

  Future<void> _deleteTask(ActionItem item) async {
    final ActionItemRepository repo = context.read<ActionItemRepository>();
    final List<ActionItem> descendants = _descendantsOf(repo, item.id);
    final bool ok = await _confirm(
      title: '删除这个任务？',
      message: descendants.isEmpty
          ? '任务采用软删除，数据仍保留在本地以便二期同步。'
          : '其下 ${descendants.length} 个子任务也会一并软删除。',
    );
    if (!ok || !mounted) return;
    for (final ActionItem child in descendants) {
      await repo.softDelete(child.id);
    }
    await repo.softDelete(item.id);
    if (!mounted) return;
    _toast('任务已删除');
  }

  Future<void> _editCapability(Capability capability) async {
    final List<String>? result = await showEditorDialog(
      context,
      title: '编辑能力',
      fields: <EditorField>[
        EditorField(label: '能力名称', initial: capability.title),
        EditorField(label: '目标水平', initial: capability.targetLevel),
      ],
    );
    if (result == null || !mounted) return;
    await context.read<CapabilityRepository>().save(
          capability.copyWith(
            title: result[0],
            targetLevel: result.length > 1 ? result[1] : '',
          ),
        );
  }

  Future<void> _createTask(Capability capability) async {
    final TaskDraft? draft = await showTaskDialog(context);
    if (draft == null || !mounted) return;
    await context.read<ActionItemRepository>().create(
          title: draft.title,
          capabilityId: capability.id,
          estimatedMinutes: draft.minutes,
        );
  }

  Future<void> _deleteCapability(
    Capability capability,
    List<ActionItem> tasks,
  ) async {
    final bool ok = await _confirm(
      title: '删除这个能力？',
      message: '其下的 ${tasks.length} 个任务也会一并软删除。',
    );
    if (!ok || !mounted) return;
    final ActionItemRepository actionRepo = context.read<ActionItemRepository>();
    for (final ActionItem item in tasks) {
      await actionRepo.softDelete(item.id);
    }
    await context.read<CapabilityRepository>().softDelete(capability.id);
    if (!mounted) return;
    _toast('能力已删除');
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text(title, style: dialogContext.texts.titleLarge),
          content: Text(
            message,
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
    return result ?? false;
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

class _VisionPill extends StatelessWidget {
  const _VisionPill({
    required this.vision,
    required this.selected,
    required this.onTap,
    this.onMenuRequested,
  });

  final Vision vision;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onMenuRequested;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color accent = context.hexColor(vision.colorHex, fallback: palette.accent);
    return GestureDetector(
      onSecondaryTapUp: (TapUpDetails details) =>
          onMenuRequested?.call(details.globalPosition),
      onLongPressStart: (LongPressStartDetails details) =>
          onMenuRequested?.call(details.globalPosition),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? palette.border : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StatusDot(color: accent, size: 5),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 168),
                child: Text(
                  vision.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelLarge?.copyWith(
                    color: selected ? palette.textPrimary : palette.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}