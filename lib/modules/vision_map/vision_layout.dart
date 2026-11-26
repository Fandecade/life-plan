import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../core/models/models.dart';

/// 画布几何常量：愿景 / 能力 / 任务多列固定尺寸，保证排版稳定可预测。
class MapMetrics {
  const MapMetrics._();

  static const double visionWidth = 288;
  static const double visionHeight = 118;
  static const double capabilityWidth = 236;
  static const double capabilityHeight = 88;
  static const double taskWidth = 252;
  static const double taskHeight = 56;

  static const double visionX = 96;
  static const double capabilityX = 452;
  static const double taskX = 772;

  /// 任务子级列之间的横向间距。
  static const double taskColumnGap = 44;

  static const double capabilityGapY = 30;
  static const double taskGapY = 10;

  static const double topPadding = 96;
  static const double edgePadding = 96;

  /// 任务链最大层级：任务本身为第 1 级，最多嵌套到第 3 级。
  static const int maxTaskDepth = 3;
}

class MindMapLayout {
  const MindMapLayout({
    required this.visionTopLeft,
    required this.capabilityTopLeft,
    required this.taskTopLeft,
    required this.canvasSize,
    required this.contentHeight,
    required this.maxTaskDepth,
  });

  final Offset visionTopLeft;
  final Map<String, Offset> capabilityTopLeft;
  final Map<String, Offset> taskTopLeft;
  final Size canvasSize;
  final double contentHeight;

  /// 本次布局中实际出现的最深任务层级（0 起）。
  final int maxTaskDepth;
}

/// 自动树状排版：
/// 能力沿纵向排列，任务以能力为中心展开；任务可再嵌套子任务，
/// 每一级任务占据一列，按子树高度排布避免重叠。
MindMapLayout buildMindMapLayout({
  required Vision vision,
  required List<Capability> capabilities,
  required Map<String, List<ActionItem>> tasksByCapability,
  bool vertical = false,
}) {
  if (vertical) {
    return _buildVerticalLayout(
      vision: vision,
      capabilities: capabilities,
      tasksByCapability: tasksByCapability,
    );
  }

  final Map<String, ActionItem> tasksById = <String, ActionItem>{};
  final Map<String, List<ActionItem>> childrenByParent =
      <String, List<ActionItem>>{};

  for (final List<ActionItem> list in tasksByCapability.values) {
    for (final ActionItem task in list) {
      tasksById[task.id] = task;
      final String? parentId = task.parentId;
      if (parentId != null && tasksById.containsKey(parentId)) {
        childrenByParent.putIfAbsent(parentId, () => <ActionItem>[]).add(task);
      }
    }
  }

  final Map<String, Offset> capabilityPositions = <String, Offset>{};
  final Map<String, Offset> taskPositions = <String, Offset>{};

  final List<Capability> visibleCapabilities =
      vision.isCollapsed ? const <Capability>[] : capabilities;

  double cursorY = MapMetrics.topPadding;
  int maxDepth = 0;

  for (final Capability capability in visibleCapabilities) {
    final List<ActionItem> all =
        tasksByCapability[capability.id] ?? const <ActionItem>[];
    // 根任务：没有父任务，或父任务已不在本能力子树中（孤儿节点兜底展示）。
    final List<ActionItem> roots = all
        .where((ActionItem task) =>
            task.parentId == null || !tasksById.containsKey(task.parentId))
        .toList(growable: false);

    final bool showTasks = !capability.isCollapsed && roots.isNotEmpty;
    final double tasksHeight =
        showTasks ? _measureTaskTree(roots, childrenByParent) : 0;
    final double blockHeight =
        math.max(tasksHeight, MapMetrics.capabilityHeight);

    final double capabilityTop =
        cursorY + (blockHeight - MapMetrics.capabilityHeight) / 2;
    capabilityPositions[capability.id] = Offset(
      MapMetrics.capabilityX + capability.posX,
      capabilityTop + capability.posY,
    );

    if (showTasks) {
      final double startY =
          capabilityTop + MapMetrics.capabilityHeight / 2 - tasksHeight / 2;
      final int deepest = _layoutTaskTree(
        roots,
        0,
        startY,
        taskPositions,
        childrenByParent,
        Offset.zero,
      );
      maxDepth = math.max(maxDepth, deepest);
    }

    cursorY += blockHeight + MapMetrics.capabilityGapY;
  }

  final double abilityAreaHeight = visibleCapabilities.isEmpty
      ? 0
      : math.max(0, cursorY - MapMetrics.topPadding - MapMetrics.capabilityGapY);

  final double visionTop = math.max(
    MapMetrics.topPadding,
    MapMetrics.topPadding + abilityAreaHeight / 2 - MapMetrics.visionHeight / 2,
  );

  final double contentHeight = math.max(
    cursorY - (visibleCapabilities.isEmpty ? 0 : MapMetrics.capabilityGapY),
    visionTop + MapMetrics.visionHeight,
  );

  final int columns = maxDepth + 1;
  final double canvasWidth = MapMetrics.taskX +
      columns * MapMetrics.taskWidth +
      (columns - 1) * MapMetrics.taskColumnGap +
      MapMetrics.edgePadding +
      120;
  final double canvasHeight = contentHeight + MapMetrics.edgePadding + 80;

  return MindMapLayout(
    visionTopLeft: Offset(MapMetrics.visionX + vision.posX, visionTop + vision.posY),
    capabilityTopLeft: capabilityPositions,
    taskTopLeft: taskPositions,
    canvasSize: Size(canvasWidth, math.max(canvasHeight, 720)),
    contentHeight: contentHeight,
    maxTaskDepth: maxDepth,
  );
}

double _measureTaskTree(
  List<ActionItem> tasks,
  Map<String, List<ActionItem>> childrenByParent,
) {
  double total = 0;
  for (int index = 0; index < tasks.length; index++) {
    final ActionItem task = tasks[index];
    final List<ActionItem> children =
        task.isCollapsed ? const <ActionItem>[] : (childrenByParent[task.id] ?? const <ActionItem>[]);
    final double childrenHeight =
        children.isEmpty ? 0 : _measureTaskTree(children, childrenByParent);
    total += math.max(MapMetrics.taskHeight, childrenHeight);
    if (index != tasks.length - 1) total += MapMetrics.taskGapY;
  }
  return total;
}

/// 返回本次递归出现的最深层级（0 起）。
int _layoutTaskTree(
  List<ActionItem> tasks,
  int depth,
  double startY,
  Map<String, Offset> positions,
  Map<String, List<ActionItem>> childrenByParent,
  Offset manualOffset,
) {
  double cursor = startY;
  final double columnX =
      MapMetrics.taskX + depth * (MapMetrics.taskWidth + MapMetrics.taskColumnGap);
  int deepest = depth;

  for (int index = 0; index < tasks.length; index++) {
    final ActionItem task = tasks[index];
    final List<ActionItem> children = task.isCollapsed
        ? const <ActionItem>[]
        : (childrenByParent[task.id] ?? const <ActionItem>[]);
    final double childrenHeight =
        children.isEmpty ? 0 : _measureTaskTree(children, childrenByParent);
    final double blockHeight = math.max(MapMetrics.taskHeight, childrenHeight);
    final double top = cursor + (blockHeight - MapMetrics.taskHeight) / 2;

    positions[task.id] =
        Offset(columnX + task.posX, top + task.posY);

    if (children.isNotEmpty) {
      final double childStart =
          top + MapMetrics.taskHeight / 2 - childrenHeight / 2;
      final int childDeepest = _layoutTaskTree(
        children,
        depth + 1,
        childStart,
        positions,
        childrenByParent,
        Offset.zero,
      );
      deepest = math.max(deepest, childDeepest);
    }

    cursor += blockHeight + MapMetrics.taskGapY;
  }

  return deepest;
}


/// 纵向布局：愿景在上、能力横向排列、任务按层级向下展开。
MindMapLayout _buildVerticalLayout({
  required Vision vision,
  required List<Capability> capabilities,
  required Map<String, List<ActionItem>> tasksByCapability,
}) {
  final Map<String, ActionItem> tasksById = <String, ActionItem>{};
  final Map<String, List<ActionItem>> childrenByParent =
      <String, List<ActionItem>>{};
  for (final List<ActionItem> list in tasksByCapability.values) {
    for (final ActionItem task in list) {
      tasksById[task.id] = task;
      final String? parentId = task.parentId;
      if (parentId != null && tasksById.containsKey(parentId)) {
        childrenByParent.putIfAbsent(parentId, () => <ActionItem>[]).add(task);
      }
    }
  }

  final List<Capability> visibleCapabilities =
      vision.isCollapsed ? const <Capability>[] : capabilities;
  final Map<String, List<ActionItem>> rootsByCapability =
      <String, List<ActionItem>>{};
  for (final Capability capability in visibleCapabilities) {
    final List<ActionItem> all =
        tasksByCapability[capability.id] ?? const <ActionItem>[];
    rootsByCapability[capability.id] = all
        .where((ActionItem task) =>
            task.parentId == null || !tasksById.containsKey(task.parentId))
        .toList(growable: false);
  }

  final Map<String, Offset> capabilityPositions = <String, Offset>{};
  final Map<String, Offset> taskPositions = <String, Offset>{};

  final double abilityRowY =
      MapMetrics.topPadding + MapMetrics.visionHeight + 56;
  double cursorX = MapMetrics.edgePadding;
  int maxDepth = 0;

  for (final Capability capability in visibleCapabilities) {
    final List<ActionItem> roots = rootsByCapability[capability.id]!;
    final bool showTasks = !capability.isCollapsed && roots.isNotEmpty;
    final double tasksWidth =
        showTasks ? _measureTaskTreeWidth(roots, childrenByParent) : 0;
    final double blockWidth = math.max(MapMetrics.capabilityWidth, tasksWidth);

    final double capabilityX =
        cursorX + (blockWidth - MapMetrics.capabilityWidth) / 2;
    capabilityPositions[capability.id] = Offset(
      capabilityX + capability.posX,
      abilityRowY + capability.posY,
    );

    if (showTasks) {
      final double startX = cursorX + (blockWidth - tasksWidth) / 2;
      final double startY =
          abilityRowY + MapMetrics.capabilityHeight + 36;
      final int deepest = _layoutVerticalTaskTree(
        roots,
        0,
        startX,
        startY,
        taskPositions,
        childrenByParent,
      );
      maxDepth = math.max(maxDepth, deepest);
    }

    cursorX += blockWidth + 56;
  }

  double maxTaskBottom = abilityRowY + MapMetrics.capabilityHeight;
  for (final Offset position in taskPositions.values) {
    maxTaskBottom = math.max(
      maxTaskBottom,
      position.dy + MapMetrics.taskHeight,
    );
  }
  final double contentHeight = maxTaskBottom;

  final double contentWidth = math.max(
    cursorX - 56 + MapMetrics.edgePadding,
    MapMetrics.visionWidth + MapMetrics.edgePadding * 2,
  );
  final double canvasWidth = math.max(contentWidth, 720);
  final double canvasHeight = contentHeight + MapMetrics.edgePadding + 80;
  final double visionX = (canvasWidth - MapMetrics.visionWidth) / 2;

  return MindMapLayout(
    visionTopLeft: Offset(
      visionX + vision.posX,
      MapMetrics.topPadding + vision.posY,
    ),
    capabilityTopLeft: capabilityPositions,
    taskTopLeft: taskPositions,
    canvasSize: Size(canvasWidth, math.max(canvasHeight, 720)),
    contentHeight: contentHeight,
    maxTaskDepth: maxDepth,
  );
}

/// 子树横向占用宽度（纵向布局里，同级任务左右排列）。
double _measureTaskTreeWidth(
  List<ActionItem> tasks,
  Map<String, List<ActionItem>> childrenByParent,
) {
  double total = 0;
  for (int index = 0; index < tasks.length; index++) {
    final ActionItem task = tasks[index];
    final List<ActionItem> children = task.isCollapsed
        ? const <ActionItem>[]
        : (childrenByParent[task.id] ?? const <ActionItem>[]);
    final double childrenWidth = children.isEmpty
        ? 0
        : _measureTaskTreeWidth(children, childrenByParent);
    total += math.max(MapMetrics.taskWidth, childrenWidth);
    if (index != tasks.length - 1) total += MapMetrics.taskColumnGap;
  }
  return total;
}

int _layoutVerticalTaskTree(
  List<ActionItem> tasks,
  int depth,
  double startX,
  double rowY,
  Map<String, Offset> positions,
  Map<String, List<ActionItem>> childrenByParent,
) {
  double cursorX = startX;
  int deepest = depth;
  for (final ActionItem task in tasks) {
    final List<ActionItem> children = task.isCollapsed
        ? const <ActionItem>[]
        : (childrenByParent[task.id] ?? const <ActionItem>[]);
    final double childrenWidth = children.isEmpty
        ? 0
        : _measureTaskTreeWidth(children, childrenByParent);
    final double blockWidth = math.max(MapMetrics.taskWidth, childrenWidth);
    final double x = cursorX + (blockWidth - MapMetrics.taskWidth) / 2;
    positions[task.id] = Offset(x + task.posX, rowY + task.posY);

    if (children.isNotEmpty) {
      final double childStartX = cursorX + (blockWidth - childrenWidth) / 2;
      final double childY = rowY + MapMetrics.taskHeight + 36;
      final int childDeepest = _layoutVerticalTaskTree(
        children,
        depth + 1,
        childStartX,
        childY,
        positions,
        childrenByParent,
      );
      deepest = math.max(deepest, childDeepest);
    }

    cursorX += blockWidth + MapMetrics.taskColumnGap;
  }
  return deepest;
}

/// 计算某个任务在链路上的层级（0 = 顶层任务，1 = 子任务，2 = 子子任务）。
int taskDepthOf(ActionItem item, Map<String, ActionItem> tasksById) {
  int depth = 0;
  String? parentId = item.parentId;
  final Set<String> guard = <String>{item.id};
  while (parentId != null && guard.add(parentId)) {
    final ActionItem? parent = tasksById[parentId];
    if (parent == null) break;
    depth++;
    parentId = parent.parentId;
    if (depth > 10) break;
  }
  return depth;
}

/// 一条连线：愿景→能力，能力→任务，或任务→子任务。
class MapConnection {
  const MapConnection({
    required this.from,
    required this.to,
    this.highlighted = false,
    this.dimmed = false,
  });

  final Offset from;
  final Offset to;
  final bool highlighted;
  final bool dimmed;

  MapConnection copyWith({bool? highlighted, bool? dimmed}) {
    return MapConnection(
      from: from,
      to: to,
      highlighted: highlighted ?? this.highlighted,
      dimmed: dimmed ?? this.dimmed,
    );
  }
}