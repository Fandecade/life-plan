import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/ai/ai_context_builder.dart';
import 'package:life_planner/core/ai/ai_draft_applier.dart';
import 'package:life_planner/core/ai/ai_models.dart';
import 'package:life_planner/core/ai/ai_tool_registry.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_ai_draft');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('写工具只生成草稿，不落库', () async {
    final AiToolRegistry tools = AiToolRegistry(
      context: AiContextBuilder(
        visions: bootstrap.visions,
        capabilities: bootstrap.capabilities,
        actions: bootstrap.actions,
        blocks: bootstrap.timeBlocks,
        projects: bootstrap.projects,
        habits: bootstrap.foggHabits,
        reviewLogs: bootstrap.reviewLogs,
      ),
      actions: bootstrap.actions,
      visions: bootstrap.visions,
      capabilities: bootstrap.capabilities,
      projects: bootstrap.projects,
      habits: bootstrap.foggHabits,
      reviewLogs: bootstrap.reviewLogs,
    );

    final Map<String, dynamic> output = await tools.execute(
      'create_vision',
      <String, dynamic>{'title': '草稿愿景'},
    );

    expect(output['draft'], isA<Map>());
    expect(
      bootstrap.visions.all.any((Vision item) => item.title == '草稿愿景'),
      isFalse,
      reason: '写工具不应直接创建实体',
    );
  });

  test('确认后按依赖顺序创建，并可撤销', () async {
    final AiDraftApplier applier = AiDraftApplier(
      visions: bootstrap.visions,
      capabilities: bootstrap.capabilities,
      actions: bootstrap.actions,
      projects: bootstrap.projects,
      schedules: bootstrap.schedules,
    );
    final List<AiDraft> drafts = <AiDraft>[
      const AiDraft(
        id: '1',
        tool: 'create_task',
        args: <String, dynamic>{
          'title': 'AI 测试任务',
          'capabilityTitle': 'AI 测试能力',
          'estimatedMinutes': 25,
        },
        summary: '创建任务「AI 测试任务」',
      ),
      const AiDraft(
        id: '2',
        tool: 'create_vision',
        args: <String, dynamic>{'title': 'AI 测试愿景'},
        summary: '创建愿景「AI 测试愿景」',
      ),
      const AiDraft(
        id: '3',
        tool: 'create_capability',
        args: <String, dynamic>{'visionTitle': 'AI 测试愿景', 'title': 'AI 测试能力'},
        summary: '创建能力「AI 测试能力」',
      ),
      const AiDraft(
        id: '4',
        tool: 'schedule_task',
        args: <String, dynamic>{
          'taskTitle': 'AI 测试任务',
          'date': '2026-12-01',
          'startTime': '09:30',
          'durationMinutes': 25,
        },
        summary: '排期「AI 测试任务」',
      ),
    ];

    final AiApplyResult result = await applier.apply(drafts);
    expect(result.created, 4);
    expect(result.errors, isEmpty);

    final Vision vision = bootstrap.visions.all.firstWhere(
      (Vision item) => item.title == 'AI 测试愿景',
    );
    final Capability capability = bootstrap.capabilities.all.firstWhere(
      (Capability item) =>
          item.title == 'AI 测试能力' && item.visionId == vision.id,
    );
    final ActionItem task = bootstrap.actions.all.firstWhere(
      (ActionItem item) => item.title == 'AI 测试任务',
    );
    expect(task.capabilityId, capability.id);
    final TimeBlock block = bootstrap.timeBlocks.all.firstWhere(
      (TimeBlock item) => item.actionItemId == task.id,
    );
    expect(block.startAt.hour, 9);
    expect(block.startAt.minute, 30);
    expect(applier.canUndo, isTrue);

    await applier.undoLast();
    expect(bootstrap.visions.byId(vision.id), isNull);
    expect(bootstrap.capabilities.byId(capability.id), isNull);
    expect(bootstrap.actions.byId(task.id), isNull);
    expect(bootstrap.timeBlocks.forActionItem(task.id), isNull);
    expect(applier.canUndo, isFalse);
  });
}
