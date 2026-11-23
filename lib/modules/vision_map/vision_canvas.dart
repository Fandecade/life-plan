import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/utils/progress_weight.dart';
import '../../core/widgets/state_views.dart';
import 'vision_layout.dart';
import 'vision_nodes.dart';

enum MapNodeType { vision, capability, task }

class MapSelection {
  const MapSelection(this.type, this.id, {this.capabilityId});

  final MapNodeType type;
  final String id;
  final String? capabilityId;
}

/// 人生规划画布：自动树状布局 + 手动拖拽微调 + 贝塞尔连线 + 路径高亮
/// + XMind 式键盘流（空格重命名 / Enter 同级 / Tab 子级）。
class VisionCanvas extends StatefulWidget {
  const VisionCanvas({
    super.key,
    required this.vision,
    required this.capabilities,
    required this.tasksByCapability,
    required this.transformController,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onVisionAction,
    required this.onCapabilityAction,
    required this.onRequestVisionSwitch,
  });

  final Vision vision;
  final List<Capability> capabilities;
  final Map<String, List<ActionItem>> tasksByCapability;
  final TransformationController transformController;
  final ValueChanged<ActionItem> onOpenTask;
  final ValueChanged<ActionItem> onToggleTask;
  final void Function(Vision vision, MapNodeAction action) onVisionAction;
  final void Function(Capability capability, MapNodeAction action) onCapabilityAction;
  final ValueChanged<String> onRequestVisionSwitch;

  @override
  State<VisionCanvas> createState() => _VisionCanvasState();
}

class _VisionCanvasState extends State<VisionCanvas> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'vision-canvas');

  MapSelection? _selection;
  MapSelection? _editing;
  String? _dragId;
  Offset _dragDelta = Offset.zero;
  bool _dragging = false;

  Map<String, ActionItem> _tasksById = <String, ActionItem>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant VisionCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vision.id != widget.vision.id) {
      _selection = null;
      _editing = null;
      _dragId = null;
      _dragDelta = Offset.zero;
      _dragging = false;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 选中与高亮
  // ---------------------------------------------------------------------------

  Offset _withDrag(String id, Offset position) =>
      _dragId == id ? position + _dragDelta : position;

  bool _capabilityDimmed(String capabilityId) {
    final MapSelection? selection = _selection;
    if (selection == null || selection.type == MapNodeType.vision) return false;
    if (selection.type == MapNodeType.capability) {
      return selection.id != capabilityId;
    }
    return selection.capabilityId != capabilityId;
  }

  bool _taskDimmed(ActionItem item) {
    final MapSelection? selection = _selection;
    if (selection == null || selection.type == MapNodeType.vision) return false;
    if (selection.type == MapNodeType.capability) {
      return item.capabilityId != selection.id;
    }
    if (item.id == selection.id) return false;
    return !_isRelated(item.id, selection.id);
  }

  /// 是否位于选中任务的祖先链或子孙树上。
  bool _isRelated(String itemId, String selectedId) {
    return _isDescendant(itemId, selectedId) || _isDescendant(selectedId, itemId);
  }

  bool _isDescendant(String itemId, String ancestorId) {
    String? parentId = _tasksById[itemId]?.parentId;
    final Set<String> guard = <String>{itemId};
    while (parentId != null && guard.add(parentId)) {
      if (parentId == ancestorId) return true;
      parentId = _tasksById[parentId]?.parentId;
    }
    return false;
  }

  void _select(MapSelection selection) {
    setState(() => _selection = selection);
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // 键盘快捷键
  // ---------------------------------------------------------------------------

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;

    // 编辑态：Tab 提交并新建子节点，Esc 取消；其余交给输入框处理。
    if (_editing != null) {
      if (key == LogicalKeyboardKey.escape) {
        _cancelEditing();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) {
        _commitEditing(thenAddChild: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final MapSelection? selection = _selection;
    if (selection == null) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.space) {
      _openDetails(selection);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _addSibling(selection);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _addChild(selection);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openDetails(MapSelection selection) {
    switch (selection.type) {
      case MapNodeType.vision:
        widget.onVisionAction(widget.vision, MapNodeAction.edit);
      case MapNodeType.capability:
        for (final Capability capability in widget.capabilities) {
          if (capability.id == selection.id) {
            widget.onCapabilityAction(capability, MapNodeAction.edit);
            break;
          }
        }
      case MapNodeType.task:
        final ActionItem? item = _tasksById[selection.id];
        if (item != null) widget.onOpenTask(item);
    }
  }


  void _cancelEditing() {
    setState(() => _editing = null);
    _focusNode.requestFocus();
  }

  void _commitEditing({bool thenAddChild = false}) {
    final MapSelection? editing = _editing;
    if (editing == null) return;
    // 实际写入由 InlineNodeTitle 的 onCommit 回调完成，这里只负责收尾。
    setState(() {
      _editing = null;
      _selection = editing;
    });
    _focusNode.requestFocus();
    if (thenAddChild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addChild(editing);
      });
    }
  }

  Future<void> _commitTitle(MapSelection target, String text) async {
    final String value = text.trim();
    if (value.isEmpty) {
      _cancelEditing();
      return;
    }
    setState(() {
      _editing = null;
      _selection = target;
    });
    _focusNode.requestFocus();
    if (target.type == MapNodeType.vision) {
      await context.read<VisionRepository>().save(
            widget.vision.copyWith(title: value),
          );
    } else if (target.type == MapNodeType.capability) {
      for (final Capability capability in widget.capabilities) {
        if (capability.id == target.id) {
          await context.read<CapabilityRepository>().save(
                capability.copyWith(title: value),
              );
          break;
        }
      }
    } else {
      final ActionItem? item = _tasksById[target.id];
      if (item != null) {
        await context.read<ActionItemRepository>().save(
              item.copyWith(title: value),
            );
      }
    }
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _addChild(MapSelection selection) async {
    late MapSelection created;
    if (selection.type == MapNodeType.vision) {
      final Capability capability = await context
          .read<CapabilityRepository>()
          .create(visionId: widget.vision.id, title: '新能力');
      created = MapSelection(MapNodeType.capability, capability.id);
    } else if (selection.type == MapNodeType.capability) {
      final ActionItem item = await context.read<ActionItemRepository>().create(
            title: '新任务',
            capabilityId: selection.id,
            estimatedMinutes: 30,
          );
      created = MapSelection(
        MapNodeType.task,
        item.id,
        capabilityId: selection.id,
      );
    } else {
      final ActionItem? parent = _tasksById[selection.id];
      if (parent == null) return;
      final int depth = taskDepthOf(parent, _tasksById);
      if (depth >= MapMetrics.maxTaskDepth - 1) {
        _toast('任务最多 ${MapMetrics.maxTaskDepth} 级');
        return;
      }
      final ActionItem item = await context.read<ActionItemRepository>().create(
            title: '新子任务',
            capabilityId: parent.capabilityId,
            parentId: parent.id,
          );
      created = MapSelection(
        MapNodeType.task,
        item.id,
        capabilityId: parent.capabilityId,
      );
    }

    if (!mounted) return;
    setState(() {
      _selection = created;
      _editing = created;
    });
    _focusNode.requestFocus();
  }

  Future<void> _addSibling(MapSelection selection) async {
    late MapSelection created;
    if (selection.type == MapNodeType.vision) {
      final Vision vision = await context.read<VisionRepository>().create(
            title: '新愿景',
            colorHex: widget.vision.colorHex,
          );
      if (!mounted) return;
      widget.onRequestVisionSwitch(vision.id);
      return;
    }
    if (selection.type == MapNodeType.capability) {
      final Capability capability = await context
          .read<CapabilityRepository>()
          .create(visionId: widget.vision.id, title: '新能力');
      created = MapSelection(MapNodeType.capability, capability.id);
    } else {
      final ActionItem? item = _tasksById[selection.id];
      if (item == null) return;
      final ActionItem sibling = await context.read<ActionItemRepository>().create(
            title: '新任务',
            capabilityId: item.capabilityId,
            parentId: item.parentId,
          );
      created = MapSelection(
        MapNodeType.task,
        sibling.id,
        capabilityId: item.capabilityId,
      );
    }

    if (!mounted) return;
    setState(() {
      _selection = created;
      _editing = created;
    });
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // 拖拽微调
  // ---------------------------------------------------------------------------

  void _startDrag(String id) {
    setState(() {
      _dragId = id;
      _dragDelta = Offset.zero;
      _dragging = true;
    });
  }

  void _updateDrag(Offset delta) {
    if (_dragId == null) return;
    final double scale =
        widget.transformController.value.getMaxScaleOnAxis().clamp(0.2, 4.0);
    setState(() => _dragDelta += delta / scale);
  }

  Future<void> _endDrag({
    Vision? vision,
    Capability? capability,
    ActionItem? actionItem,
  }) async {
    if (_dragId != null && _dragDelta != Offset.zero) {
      if (vision != null) {
        await context.read<VisionRepository>().save(
              vision.copyWith(
                posX: vision.posX + _dragDelta.dx,
                posY: vision.posY + _dragDelta.dy,
              ),
            );
      } else if (capability != null) {
        await context.read<CapabilityRepository>().save(
              capability.copyWith(
                posX: capability.posX + _dragDelta.dx,
                posY: capability.posY + _dragDelta.dy,
              ),
            );
      } else if (actionItem != null) {
        await context.read<ActionItemRepository>().save(
              actionItem.copyWith(
                posX: actionItem.posX + _dragDelta.dx,
                posY: actionItem.posY + _dragDelta.dy,
              ),
            );
      }
    }
    if (!mounted) return;
    setState(() {
      _dragId = null;
      _dragDelta = Offset.zero;
      _dragging = false;
    });
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    _tasksById = <String, ActionItem>{};
    for (final List<ActionItem> list in widget.tasksByCapability.values) {
      for (final ActionItem item in list) {
        _tasksById[item.id] = item;
      }
    }
    final Map<String, List<ActionItem>> childrenByParent =
        <String, List<ActionItem>>{};
    for (final ActionItem item in _tasksById.values) {
      final String? parentId = item.parentId;
      if (parentId != null && _tasksById.containsKey(parentId)) {
        childrenByParent
            .putIfAbsent(parentId, () => <ActionItem>[])
            .add(item);
      }
    }

    final MindMapLayout layout = buildMindMapLayout(
      vision: widget.vision,
      capabilities: widget.capabilities,
      tasksByCapability: widget.tasksByCapability,
    );

    final Offset visionPosition = _withDrag(
      widget.vision.id,
      layout.visionTopLeft,
    );

    final Map<String, Offset> capabilityPositions = <String, Offset>{};
    for (final Capability capability in widget.capabilities) {
      final Offset? base = layout.capabilityTopLeft[capability.id];
      if (base == null) continue;
      capabilityPositions[capability.id] = _withDrag(capability.id, base);
    }

    final Map<String, Offset> taskPositions = <String, Offset>{};
    for (final ActionItem item in _tasksById.values) {
      final Offset? base = layout.taskTopLeft[item.id];
      if (base == null) continue;
      taskPositions[item.id] = _withDrag(item.id, base);
    }

    // 巩固中的任务显示下一条复习节点（如「巩固·D3」）。
    final List<LearningReview> pendingReviews =
        context.watch<LearningReviewRepository>().pending;
    final Map<String, String> masteryNotes = <String, String>{};
    final Map<String, DateTime> earliestDue = <String, DateTime>{};
    for (final LearningReview review in pendingReviews) {
      final ActionItem? reviewItem = _tasksById[review.actionItemId];
      if (reviewItem == null ||
          reviewItem.status != ActionItemStatus.consolidating) {
        continue;
      }
      final DateTime? previous = earliestDue[reviewItem.id];
      if (previous == null || review.dueDate.isBefore(previous)) {
        earliestDue[reviewItem.id] = review.dueDate;
        masteryNotes[reviewItem.id] = '巩固·D${review.intervalDays}';
      }
    }

    final List<MapConnection> connections = <MapConnection>[];
    final Offset visionRight =
        visionPosition + const Offset(MapMetrics.visionWidth, MapMetrics.visionHeight / 2);

    for (final Capability capability in widget.capabilities) {
      final Offset? capPosition = capabilityPositions[capability.id];
      if (capPosition == null) continue;

      connections.add(
        MapConnection(
          from: visionRight,
          to: capPosition + const Offset(0, MapMetrics.capabilityHeight / 2),
          highlighted: _selection?.type == MapNodeType.capability &&
              _selection?.id == capability.id,
          dimmed: _capabilityDimmed(capability.id),
        ),
      );

      final List<ActionItem> all =
          widget.tasksByCapability[capability.id] ?? const <ActionItem>[];
      for (final ActionItem item in all) {
        final Offset? taskPosition = taskPositions[item.id];
        if (taskPosition == null) continue;

        final bool highlighted = _selection?.id == item.id;
        Offset from;
        final String? parentId = item.parentId;
        final Offset? parentPosition =
            parentId == null ? null : taskPositions[parentId];
        if (parentPosition != null) {
          from = parentPosition + const Offset(MapMetrics.taskWidth, MapMetrics.taskHeight / 2);
        } else if (item.parentId == null || !_tasksById.containsKey(item.parentId)) {
          from = capPosition + const Offset(MapMetrics.capabilityWidth, MapMetrics.capabilityHeight / 2);
        } else {
          continue;
        }

        connections.add(
          MapConnection(
            from: from,
            to: taskPosition + const Offset(0, MapMetrics.taskHeight / 2),
            highlighted: highlighted,
            dimmed: _taskDimmed(item) || _capabilityDimmed(capability.id),
          ),
        );
      }
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() => _selection = null);
                _focusNode.requestFocus();
              },
              child: InteractiveViewer(
                transformationController: widget.transformController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(1600),
                minScale: 0.35,
                maxScale: 2.2,
                panEnabled: !_dragging,
                child: SizedBox(
                  width: layout.canvasSize.width,
                  height: layout.canvasSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MapConnectionsPainter(
                            connections: connections,
                            baseColor: palette.border,
                            accentColor: palette.accent,
                          ),
                        ),
                      ),
                      Positioned(
                        left: visionPosition.dx,
                        top: visionPosition.dy,
                        child: _DraggableNode(
                          onPanStart: () => _startDrag(widget.vision.id),
                          onPanUpdate: _updateDrag,
                          onPanEnd: () => _endDrag(vision: widget.vision),
                          child: VisionNodeCard(
                            vision: widget.vision,
                            completed: _visionCompleted(),
                            total: _visionTotal(),
                            progress: ProgressWeight.ratio(<ActionItem>[
                              for (final List<ActionItem> list
                                  in widget.tasksByCapability.values)
                                ...list,
                            ]),
                            capabilityCount: widget.capabilities.length,
                            dimmed: false,
                            selected: _selection?.type == MapNodeType.vision,
                            editing: _editing?.type == MapNodeType.vision,
                            onTap: () => _select(
                              MapSelection(MapNodeType.vision, widget.vision.id),
                            ),

                            onAction: (MapNodeAction action) =>
                                widget.onVisionAction(widget.vision, action),
                            onCommitTitle: (String text) => _commitTitle(
                              MapSelection(MapNodeType.vision, widget.vision.id),
                              text,
                            ),
                            onCancelEdit: _cancelEditing,
                          ),
                        ),
                      ),
                      for (final Capability capability in widget.capabilities)
                        if (capabilityPositions[capability.id] != null)
                          Positioned(
                            left: capabilityPositions[capability.id]!.dx,
                            top: capabilityPositions[capability.id]!.dy,
                            child: _DraggableNode(
                              onPanStart: () => _startDrag(capability.id),
                              onPanUpdate: _updateDrag,
                              onPanEnd: () => _endDrag(capability: capability),
                              child: CapabilityNodeCard(
                                capability: capability,
                                completed: _capabilityCompleted(capability.id),
                                total: (widget.tasksByCapability[capability.id] ??
                                        const <ActionItem>[])
                                    .length,
                                progress: ProgressWeight.ratio(
                                  widget.tasksByCapability[capability.id] ??
                                      const <ActionItem>[],
                                ),
                                dimmed: _capabilityDimmed(capability.id),
                                selected: _selection?.type == MapNodeType.capability &&
                                    _selection?.id == capability.id,
                                editing: _editing?.type == MapNodeType.capability &&
                                    _editing?.id == capability.id,
                                onTap: () => _select(
                                  MapSelection(MapNodeType.capability, capability.id),
                                ),

                                onAction: (MapNodeAction action) =>
                                    widget.onCapabilityAction(capability, action),
                                onCommitTitle: (String text) => _commitTitle(
                                  MapSelection(MapNodeType.capability, capability.id),
                                  text,
                                ),
                                onCancelEdit: _cancelEditing,
                              ),
                            ),
                          ),
                      for (final ActionItem item in _tasksById.values)
                        if (taskPositions[item.id] != null)
                          Positioned(
                            left: taskPositions[item.id]!.dx,
                            top: taskPositions[item.id]!.dy,
                            child: _DraggableNode(
                              onPanStart: () => _startDrag(item.id),
                              onPanUpdate: _updateDrag,
                              onPanEnd: () => _endDrag(actionItem: item),
                              child: TaskNodeCard(
                                item: item,
                                dimmed: _taskDimmed(item),
                                selected: _selection?.type == MapNodeType.task &&
                                    _selection?.id == item.id,
                                editing: _editing?.type == MapNodeType.task &&
                                    _editing?.id == item.id,
                                childCount:
                                    (childrenByParent[item.id] ?? const <ActionItem>[])
                                        .length,
                                statusNote: masteryNotes[item.id],
                                onTap: () {
                                  _select(
                                    MapSelection(
                                      MapNodeType.task,
                                      item.id,
                                      capabilityId: item.capabilityId,
                                    ),
                                  );
                                  widget.onOpenTask(item);
                                },

                                onToggleComplete: () => widget.onToggleTask(item),
                                onToggleCollapse: () => _toggleTaskCollapse(item),
                                onCommitTitle: (String text) => _commitTitle(
                                  MapSelection(
                                    MapNodeType.task,
                                    item.id,
                                    capabilityId: item.capabilityId,
                                  ),
                                  text,
                                ),
                                onCancelEdit: _cancelEditing,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: _ShortcutHint(selection: _selection, tasksById: _tasksById),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTaskCollapse(ActionItem item) {
    return context.read<ActionItemRepository>().save(
          item.copyWith(isCollapsed: !item.isCollapsed),
        );
  }

  int _visionCompleted() {
    int count = 0;
    widget.tasksByCapability.forEach((_, List<ActionItem> list) {
      count += list.where((ActionItem item) => item.isCompleted).length;
    });
    return count;
  }

  int _visionTotal() {
    int count = 0;
    widget.tasksByCapability.forEach((_, List<ActionItem> list) {
      count += list.length;
    });
    return count;
  }

  int _capabilityCompleted(String capabilityId) {
    final List<ActionItem> list =
        widget.tasksByCapability[capabilityId] ?? const <ActionItem>[];
    return list.where((ActionItem item) => item.isCompleted).length;
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

class _DraggableNode extends StatelessWidget {
  const _DraggableNode({
    required this.child,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final Widget child;
  final VoidCallback onPanStart;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => onPanStart(),
      onPanUpdate: (DragUpdateDetails details) => onPanUpdate(details.delta),
      onPanEnd: (_) => onPanEnd(),
      onPanCancel: onPanEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: child,
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.selection, required this.tasksById});

  final MapSelection? selection;
  final Map<String, ActionItem> tasksById;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<String> hints = <String>['点击节点选中'];

    final MapSelection? current = selection;
    if (current != null) {
      hints.add('空格 详情');
      switch (current.type) {
        case MapNodeType.vision:
          hints.addAll(<String>['Tab 添加能力', 'Enter 新建愿景']);
        case MapNodeType.capability:
          hints.addAll(<String>['Tab 添加任务', 'Enter 同级能力']);
        case MapNodeType.task:
          hints.add('Enter 同级任务');
          final ActionItem? item = tasksById[current.id];
          if (item != null) {
            final int depth = taskDepthOf(item, tasksById);
            hints.add(
              depth >= MapMetrics.maxTaskDepth - 1
                  ? '已达任务最大层级'
                  : 'Tab 添加子任务',
            );
          }
      }
    }

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: palette.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < hints.length; index++) ...<Widget>[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: StatusDot(color: palette.border, size: 3),
                ),
              Text(
                hints[index],
                style: context.texts.labelSmall?.copyWith(
                  color: hints[index] == '已达任务最大层级'
                      ? palette.warning
                      : palette.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapConnectionsPainter extends CustomPainter {
  _MapConnectionsPainter({
    required this.connections,
    required this.baseColor,
    required this.accentColor,
  });

  final List<MapConnection> connections;
  final Color baseColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final MapConnection connection in connections) {
      final double dx = connection.to.dx - connection.from.dx;
      final Path path = Path()
        ..moveTo(connection.from.dx, connection.from.dy)
        ..cubicTo(
          connection.from.dx + dx * 0.45,
          connection.from.dy,
          connection.to.dx - dx * 0.45,
          connection.to.dy,
          connection.to.dx,
          connection.to.dy,
        );

      final Color color = connection.highlighted
          ? accentColor
          : baseColor.withValues(alpha: connection.dimmed ? 0.2 : 1);
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = connection.highlighted ? 1.7 : 1.2
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawPath(path, paint);

      if (connection.highlighted) {
        canvas.drawCircle(connection.to, 2.2, Paint()..color = accentColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapConnectionsPainter oldDelegate) => true;
}