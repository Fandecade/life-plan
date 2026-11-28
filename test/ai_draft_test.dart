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
      routines: bootstrap.weeklyRoutines,
      schedules: bootstrap.schedules,
      learningSessions: bootstrap.learningSessions,
      habits: bootstrap.foggHabits,
      reviewLogs: bootstrap.reviewLogs,
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
      const AiDraft(
        id: '5',
        tool: 'plan_learning',
        args: <String, dynamic>{
          'title': 'AI 学习计划',
          'capabilityTitle': 'AI 测试能力',
          'estimatedMinutes': 30,
          'scheduleDate': '2026-12-02',
          'startTime': '20:00',
        },
        summary: '创建学习计划「AI 学习计划」',
      ),
      const AiDraft(
        id: '6',
        tool: 'create_weekly_routine',
        args: <String, dynamic>{
          'title': 'AI 固定晨读',
          'weekday': 1,
          'startTime': '07:30',
          'durationMinutes': 30,
          'linkedTaskTitle': 'AI 学习计划',
        },
        summary: '固定安排「AI 固定晨读」',
      ),
      const AiDraft(
        id: '7',
        tool: 'create_habit_recipe',
        args: <String, dynamic>{
          'anchorPrompt': '打开文档后',
          'tinyBehavior': 'AI 微习惯',
          'anchorPeriod': 'morning',
        },
        summary: '微习惯「AI 微习惯」',
      ),
      const AiDraft(
        id: '8',
        tool: 'propose_review_adjustments',
        args: <String, dynamic>{
          'periodType': 'weekly',
          'periodKey': '2026-W48',
          'adjustments': 'AI 复盘调整',
          'focus': '聚焦 AI',
        },
        summary: '复盘调整建议',
      ),
    ];

    final AiApplyResult result = await applier.apply(drafts);
    expect(result.created, 8);
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

    final ActionItem learning = bootstrap.actions.all.firstWhere(
      (ActionItem item) => item.title == 'AI 学习计划',
    );
    expect(learning.executionMode, ExecutionMode.outputLearning);
    final WeeklyRoutine routine = bootstrap.weeklyRoutines.all.firstWhere(
      (WeeklyRoutine item) => item.title == 'AI 固定晨读',
    );
    expect(routine.weekday, 1);
    expect(routine.actionItemId, learning.id);
    final FoggHabit habit = bootstrap.foggHabits.all.firstWhere(
      (FoggHabit item) => item.tinyBehavior == 'AI 微习惯',
    );
    expect(habit.anchorPrompt, '打开文档后');
    expect(habit.anchorPeriod, AnchorPeriod.morning);
    final ReviewLog? review = bootstrap.reviewLogs.forPeriod(
      ReviewPeriodType.weekly,
      '2026-W48',
    );
    expect(review, isNotNull);
    expect(review!.adjustmentsText, contains('AI 复盘调整'));
    expect(review.focusText, '聚焦 AI');
    expect(applier.canUndo, isTrue);

    await applier.undoLast();
    expect(bootstrap.visions.byId(vision.id), isNull);
    expect(bootstrap.capabilities.byId(capability.id), isNull);
    expect(bootstrap.actions.byId(task.id), isNull);
    expect(bootstrap.actions.byId(learning.id), isNull);
    expect(bootstrap.weeklyRoutines.byId(routine.id), isNull);
    expect(bootstrap.foggHabits.byId(habit.id), isNull);
    expect(
      bootstrap.reviewLogs.forPeriod(ReviewPeriodType.weekly, '2026-W48'),
      isNull,
    );
    expect(bootstrap.timeBlocks.forActionItem(task.id), isNull);
    expect(applier.canUndo, isFalse);
  });

  test('更新与取消排期草稿可执行并可撤销', () async {
    final AiDraftApplier applier = AiDraftApplier(
      visions: bootstrap.visions,
      capabilities: bootstrap.capabilities,
      actions: bootstrap.actions,
      projects: bootstrap.projects,
      routines: bootstrap.weeklyRoutines,
      schedules: bootstrap.schedules,
      learningSessions: bootstrap.learningSessions,
      habits: bootstrap.foggHabits,
      reviewLogs: bootstrap.reviewLogs,
    );
    final AiApplyResult base = await applier.apply(<AiDraft>[
      const AiDraft(
        id: 'b1',
        tool: 'create_vision',
        args: <String, dynamic>{'title': 'UI 愿景'},
        summary: '创建愿景',
      ),
      const AiDraft(
        id: 'b2',
        tool: 'create_capability',
        args: <String, dynamic>{'visionTitle': 'UI 愿景', 'title': 'UI 能力'},
        summary: '创建能力',
      ),
      const AiDraft(
        id: 'b3',
        tool: 'create_project',
        args: <String, dynamic>{'title': 'UI 项目'},
        summary: '创建项目',
      ),
      const AiDraft(
        id: 'b4',
        tool: 'create_task',
        args: <String, dynamic>{'title': 'UI 任务', 'capabilityTitle': 'UI 能力'},
        summary: '创建任务',
      ),
      const AiDraft(
        id: 'b5',
        tool: 'schedule_task',
        args: <String, dynamic>{
          'taskTitle': 'UI 任务',
          'date': '2026-12-03',
          'startTime': '10:00',
          'durationMinutes': 30,
        },
        summary: '排期任务',
      ),
    ]);
    expect(base.created, 5);
    expect(base.errors, isEmpty);

    final Vision vision = bootstrap.visions.all.firstWhere(
      (Vision item) => item.title == 'UI 愿景',
    );
    final Capability capability = bootstrap.capabilities.all.firstWhere(
      (Capability item) => item.title == 'UI 能力',
    );
    final Project project = bootstrap.projects.all.firstWhere(
      (Project item) => item.title == 'UI 项目',
    );
    final ActionItem task = bootstrap.actions.all.firstWhere(
      (ActionItem item) => item.title == 'UI 任务',
    );
    expect(capability.targetLevel, '');
    expect(task.note, '');
    expect(project.status, ProjectStatus.active);
    expect(project.stages, isEmpty);
    expect(bootstrap.timeBlocks.forActionItem(task.id), isNotNull);

    final AiApplyResult update = await applier.apply(<AiDraft>[
      const AiDraft(
        id: 'u1',
        tool: 'update_vision',
        args: <String, dynamic>{
          'visionTitle': 'UI 愿景',
          'title': 'UI 愿景 2',
          'description': '新描述',
        },
        summary: '更新愿景',
      ),
      const AiDraft(
        id: 'u2',
        tool: 'update_capability',
        args: <String, dynamic>{
          'capabilityTitle': 'UI 能力',
          'targetLevel': '进阶',
        },
        summary: '更新能力',
      ),
      const AiDraft(
        id: 'u3',
        tool: 'update_task_fields',
        args: <String, dynamic>{
          'taskTitle': 'UI 任务',
          'note': '补充说明',
          'estimatedMinutes': 45,
        },
        summary: '更新任务',
      ),
      const AiDraft(
        id: 'u4',
        tool: 'update_project',
        args: <String, dynamic>{
          'projectTitle': 'UI 项目',
          'goal': '新目标',
          'status': 'paused',
        },
        summary: '更新项目',
      ),
      const AiDraft(
        id: 'u5',
        tool: 'add_project_stage',
        args: <String, dynamic>{'projectTitle': 'UI 项目', 'title': '阶段一'},
        summary: '添加项目阶段',
      ),
      const AiDraft(
        id: 'u6',
        tool: 'cancel_schedule',
        args: <String, dynamic>{'taskTitle': 'UI 任务'},
        summary: '取消排期',
      ),
    ]);
    expect(update.created, 6);
    expect(update.errors, isEmpty);

    expect(bootstrap.visions.byId(vision.id)!.title, 'UI 愿景 2');
    expect(bootstrap.capabilities.byId(capability.id)!.targetLevel, '进阶');
    expect(bootstrap.actions.byId(task.id)!.note, '补充说明');
    expect(bootstrap.actions.byId(task.id)!.estimatedMinutes, 45);
    expect(bootstrap.projects.byId(project.id)!.status, ProjectStatus.paused);
    expect(bootstrap.projects.byId(project.id)!.stages.single.title, '阶段一');
    expect(bootstrap.timeBlocks.forActionItem(task.id), isNull);

    await applier.undoLast();
    expect(bootstrap.visions.byId(vision.id)!.title, 'UI 愿景');
    expect(bootstrap.capabilities.byId(capability.id)!.targetLevel, '');
    expect(bootstrap.actions.byId(task.id)!.note, '');
    expect(bootstrap.projects.byId(project.id)!.status, ProjectStatus.active);
    expect(bootstrap.projects.byId(project.id)!.stages, isEmpty);
    final TimeBlock restored = bootstrap.timeBlocks.forActionItem(task.id)!;
    expect(restored.startAt.hour, 10);
    expect(applier.canUndo, isFalse);
  });
}
