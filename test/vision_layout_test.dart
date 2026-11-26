import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/modules/vision_map/vision_layout.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 22, 9);

  Vision makeVision({bool collapsed = false}) => Vision(
        id: 'v1',
        createdAt: now,
        updatedAt: now,
        title: '愿景',
        isCollapsed: collapsed,
      );

  Capability makeCapability(String id, {bool collapsed = false}) => Capability(
        id: id,
        createdAt: now,
        updatedAt: now,
        visionId: 'v1',
        title: id,
        isCollapsed: collapsed,
      );

  ActionItem makeTask(
    String id,
    String capabilityId, {
    String? parentId,
    bool collapsed = false,
  }) =>
      ActionItem(
        id: id,
        createdAt: now,
        updatedAt: now,
        title: id,
        capabilityId: capabilityId,
        parentId: parentId,
        isCollapsed: collapsed,
      );

  test('能力按子树高度纵向排列，任务不重叠', () {
    final Map<String, List<ActionItem>> tasks = <String, List<ActionItem>>{
      'c1': <ActionItem>[
        makeTask('t1', 'c1'),
        makeTask('t2', 'c1'),
        makeTask('t3', 'c1'),
      ],
      'c2': <ActionItem>[makeTask('t4', 'c2')],
    };

    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1'), makeCapability('c2')],
      tasksByCapability: tasks,
    );

    expect(layout.taskTopLeft.length, 4);

    final double t1 = layout.taskTopLeft['t1']!.dy;
    final double t2 = layout.taskTopLeft['t2']!.dy;
    final double t3 = layout.taskTopLeft['t3']!.dy;
    expect(t2 - t1, MapMetrics.taskHeight + MapMetrics.taskGapY);
    expect(t3 - t2, MapMetrics.taskHeight + MapMetrics.taskGapY);

    final double c2Top = layout.capabilityTopLeft['c2']!.dy;
    expect(
      c2Top,
      greaterThan(t3 + MapMetrics.taskHeight),
      reason: '第二个能力必须排在第一个能力的任务之后，不能重叠',
    );

    expect(layout.taskTopLeft['t1']!.dx, MapMetrics.taskX);
    expect(layout.capabilityTopLeft['c1']!.dx, MapMetrics.capabilityX);
    expect(layout.visionTopLeft.dx, MapMetrics.visionX);
  });

  test('愿景垂直居中于能力区域', () {
    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1'), makeCapability('c2')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[makeTask('t1', 'c1')],
        'c2': <ActionItem>[],
      },
    );

    final double visionCenter =
        layout.visionTopLeft.dy + MapMetrics.visionHeight / 2;
    final double abilityBottom = layout.capabilityTopLeft['c2']!.dy +
        MapMetrics.capabilityHeight;
    final double abilityCenter =
        (MapMetrics.topPadding + abilityBottom) / 2;

    expect(visionCenter, closeTo(abilityCenter, 0.6));
  });

  test('折叠能力后其任务退出布局，其余能力上移', () {
    final MindMapLayout expanded = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1'), makeCapability('c2')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[makeTask('t1', 'c1'), makeTask('t2', 'c1')],
        'c2': <ActionItem>[makeTask('t3', 'c2')],
      },
    );

    final MindMapLayout collapsed = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[
        makeCapability('c1', collapsed: true),
        makeCapability('c2'),
      ],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[makeTask('t1', 'c1'), makeTask('t2', 'c1')],
        'c2': <ActionItem>[makeTask('t3', 'c2')],
      },
    );

    expect(collapsed.taskTopLeft.containsKey('t1'), isFalse);
    expect(collapsed.taskTopLeft.containsKey('t2'), isFalse);
    expect(collapsed.taskTopLeft.containsKey('t3'), isTrue);
    expect(
      collapsed.capabilityTopLeft['c2']!.dy,
      lessThan(expanded.capabilityTopLeft['c2']!.dy),
    );
  });

  test('折叠愿景后整棵子树收缩到根节点', () {
    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(collapsed: true),
      capabilities: <Capability>[makeCapability('c1')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[makeTask('t1', 'c1')],
      },
    );

    expect(layout.capabilityTopLeft, isEmpty);
    expect(layout.taskTopLeft, isEmpty);
    expect(layout.visionTopLeft.dy, MapMetrics.topPadding);
    expect(layout.canvasSize.width, greaterThan(MapMetrics.taskX));
  });

  test('任务子级按列展开，同级子任务不重叠', () {
    final ActionItem parent = makeTask('t1', 'c1');
    final ActionItem childA = makeTask('t2', 'c1', parentId: 't1');
    final ActionItem childB = makeTask('t3', 'c1', parentId: 't1');
    final ActionItem grand = makeTask('t4', 'c1', parentId: 't2');

    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[parent, childA, childB, grand],
      },
    );

    const double step = MapMetrics.taskWidth + MapMetrics.taskColumnGap;
    expect(layout.taskTopLeft['t1']!.dx, MapMetrics.taskX);
    expect(layout.taskTopLeft['t2']!.dx, MapMetrics.taskX + step);
    expect(layout.taskTopLeft['t3']!.dx, MapMetrics.taskX + step);
    expect(layout.taskTopLeft['t4']!.dx, MapMetrics.taskX + step * 2);
    expect(layout.maxTaskDepth, 2);
    expect(
      layout.taskTopLeft['t3']!.dy - layout.taskTopLeft['t2']!.dy,
      MapMetrics.taskHeight + MapMetrics.taskGapY,
    );
  });

  test('折叠任务后其子任务退出布局', () {
    final ActionItem collapsedParent = makeTask('t1', 'c1', collapsed: true);
    final ActionItem child = makeTask('t2', 'c1', parentId: 't1');

    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[collapsedParent, child],
      },
    );

    expect(layout.taskTopLeft.containsKey('t1'), isTrue);
    expect(layout.taskTopLeft.containsKey('t2'), isFalse);
    expect(layout.maxTaskDepth, 0);
  });

  test('taskDepthOf 计算任务链层级', () {
    final ActionItem root = makeTask('t1', 'c1');
    final ActionItem child = makeTask('t2', 'c1', parentId: 't1');
    final ActionItem grand = makeTask('t3', 'c1', parentId: 't2');
    final Map<String, ActionItem> map = <String, ActionItem>{
      't1': root,
      't2': child,
      't3': grand,
    };

    expect(taskDepthOf(root, map), 0);
    expect(taskDepthOf(child, map), 1);
    expect(taskDepthOf(grand, map), 2);
  });

  test('纵向布局：愿景居顶居中，能力同一行，任务在其下方', () {
    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1'), makeCapability('c2')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[makeTask('t1', 'c1')],
        'c2': <ActionItem>[makeTask('t2', 'c2')],
      },
      vertical: true,
    );

    expect(layout.visionTopLeft.dy, MapMetrics.topPadding);
    expect(
      layout.visionTopLeft.dx,
      closeTo((layout.canvasSize.width - MapMetrics.visionWidth) / 2, 0.01),
      reason: '愿景应在画布水平居中',
    );

    final double c1 = layout.capabilityTopLeft['c1']!.dy;
    final double c2 = layout.capabilityTopLeft['c2']!.dy;
    expect(c2, c1, reason: '能力应排在同一行');
    expect(
      c1,
      greaterThan(layout.visionTopLeft.dy + MapMetrics.visionHeight),
      reason: '能力必须在愿景下方',
    );

    expect(
      layout.taskTopLeft['t1']!.dy,
      greaterThanOrEqualTo(c1 + MapMetrics.capabilityHeight),
      reason: '任务必须从能力下沿开始向下展开',
    );
    expect(
      layout.capabilityTopLeft['c2']!.dx,
      greaterThan(
        layout.capabilityTopLeft['c1']!.dx + MapMetrics.capabilityWidth,
      ),
      reason: '能力之间横向排列，不能重叠',
    );
    expect(layout.canvasSize.width, greaterThanOrEqualTo(720));
  });

  test('纵向布局：子任务在父任务下方，同级子任务同排且父节点居中', () {
    final ActionItem parent = makeTask('t1', 'c1');
    final ActionItem childA = makeTask('t2', 'c1', parentId: 't1');
    final ActionItem childB = makeTask('t3', 'c1', parentId: 't1');
    final ActionItem grand = makeTask('t4', 'c1', parentId: 't2');

    final MindMapLayout layout = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[parent, childA, childB, grand],
      },
      vertical: true,
    );

    final Offset parentPos = layout.taskTopLeft['t1']!;
    final Offset childAPos = layout.taskTopLeft['t2']!;
    final Offset childBPos = layout.taskTopLeft['t3']!;
    final Offset grandPos = layout.taskTopLeft['t4']!;

    expect(childAPos.dy - parentPos.dy, MapMetrics.taskHeight + 36);
    expect(childBPos.dy, childAPos.dy, reason: '同级子任务应排在同一行');
    expect(grandPos.dy, childAPos.dy + MapMetrics.taskHeight + 36);
    expect(grandPos.dx, childAPos.dx, reason: '子任务应垂直排在父任务正下方');
    expect(childBPos.dx, greaterThan(childAPos.dx));
    expect(layout.maxTaskDepth, 2);

    const double childrenWidth =
        MapMetrics.taskWidth * 2 + MapMetrics.taskColumnGap;
    final double expectedParentX =
        childAPos.dx + (childrenWidth - MapMetrics.taskWidth) / 2;
    expect(parentPos.dx, closeTo(expectedParentX, 0.01));
  });

  test('纵向布局：折叠能力后其任务退出且后续能力左移', () {
    final MindMapLayout expanded = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[makeCapability('c1'), makeCapability('c2')],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[
          makeTask('t1', 'c1'),
          makeTask('t2', 'c1'),
          makeTask('t3', 'c1'),
        ],
        'c2': <ActionItem>[makeTask('t4', 'c2')],
      },
      vertical: true,
    );

    final MindMapLayout collapsed = buildMindMapLayout(
      vision: makeVision(),
      capabilities: <Capability>[
        makeCapability('c1', collapsed: true),
        makeCapability('c2'),
      ],
      tasksByCapability: <String, List<ActionItem>>{
        'c1': <ActionItem>[
          makeTask('t1', 'c1'),
          makeTask('t2', 'c1'),
          makeTask('t3', 'c1'),
        ],
        'c2': <ActionItem>[makeTask('t4', 'c2')],
      },
      vertical: true,
    );

    expect(collapsed.taskTopLeft.containsKey('t1'), isFalse);
    expect(collapsed.taskTopLeft.containsKey('t4'), isTrue);
    expect(
      collapsed.capabilityTopLeft['c2']!.dx,
      lessThan(expanded.capabilityTopLeft['c2']!.dx),
    );
  });
}