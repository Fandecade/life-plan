import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/review_service.dart';
import 'package:life_planner/core/utils/date_utils.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_improvement');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('能力阶段成果：JSON 往返与达成计数', () async {
    final String visionId = bootstrap.visions.all.first.id;
    final Capability capability = Capability.create(
      visionId: visionId,
      title: '阶段成果测试能力',
    );
    await bootstrap.capabilities.put(capability);

    final List<CapabilityMilestone> milestones = <CapabilityMilestone>[
      const CapabilityMilestone(
        id: 'm-1',
        title: '能独立解释核心概念',
        evidence: 'https://example.com/note',
        achieved: true,
      ),
      const CapabilityMilestone(
        id: 'm-2',
        title: '能独立完成一个小项目',
      ),
    ];
    await bootstrap.capabilities.save(
      capability.copyWith(milestonesJson: encodeMilestones(milestones)),
    );

    final Capability loaded = bootstrap.capabilities.byId(capability.id)!;
    expect(loaded.milestones.length, 2);
    expect(loaded.achievedMilestones, 1);
    expect(loaded.milestones.first.evidence, contains('example.com'));

    final CapabilityMilestone toggled =
        loaded.milestones.last.copyWith(achieved: true);
    await bootstrap.capabilities.save(
      loaded.copyWith(
        milestonesJson: encodeMilestones(<CapabilityMilestone>[
          loaded.milestones.first,
          toggled,
        ]),
      ),
    );
    expect(bootstrap.capabilities.byId(capability.id)!.achievedMilestones, 2);
  });

  test('任务 If–Then 与认知负荷可持久化', () async {
    final ActionItem item = await bootstrap.actions.create(
      title: '任务预案测试',
      ifThenText: '如果晚上 20:00 吃完饭，那么先做 5 分钟闭卷回忆',
      cognitiveLoad: CognitiveLoad.high,
    );

    final ActionItem loaded = bootstrap.actions.byId(item.id)!;
    expect(loaded.ifThenText, contains('闭卷回忆'));
    expect(loaded.cognitiveLoad, CognitiveLoad.high);

    await bootstrap.actions.save(
      loaded.copyWith(
        ifThenText: '如果精力不足，那么只做 5 分钟微输出',
        cognitiveLoad: CognitiveLoad.low,
      ),
    );
    final ActionItem updated = bootstrap.actions.byId(item.id)!;
    expect(updated.ifThenText, contains('微输出'));
    expect(updated.cognitiveLoad, CognitiveLoad.low);

    await bootstrap.actions.softDelete(item.id);
  });

  test('复盘调整方案 / 预期 / 实际效果可跨周期保存', () async {
    final ReviewWindow current =
        ReviewWindow.of(ReviewPeriodType.weekly, DateTime.now());
    final ReviewWindow previous = bootstrap.reviewService.previousWindow(current);

    await bootstrap.reviewService.saveEntry(
      previous,
      adjustmentPlan: '把学习任务颗粒度缩小一半',
      expectedOutcome: '完成率 +10%',
    );
    await bootstrap.reviewService.saveEntry(
      current,
      adjustmentPlan: '把高负荷任务放到上午',
      expectedOutcome: '估时误差下降 20%',
    );

    final ReviewLog? previousLog =
        bootstrap.reviewLogs.forPeriod(previous.type, previous.periodKey);
    expect(previousLog!.adjustmentPlan, contains('颗粒度'));
    expect(previousLog.expectedOutcome, contains('完成率'));

    await bootstrap.reviewLogs.save(
      previousLog.copyWith(actualOutcome: '完成率 +6%，未达预期'),
    );
    final ReviewLog reloaded = bootstrap.reviewLogs
        .forPeriod(previous.type, previous.periodKey)!;
    expect(reloaded.actualOutcome, contains('+6%'));
    expect(reloaded.adjustmentPlan, contains('颗粒度'));
  });

  test('同一任务可追加多个时间块，默认仍只更新一个', () async {
    final DateTime base =
        AppDate.startOfDay(DateTime.now().add(const Duration(days: 1)));

    final ActionItem multi = await bootstrap.actions.create(
      title: '多次推进任务',
      estimatedMinutes: 30,
      status: ActionItemStatus.scheduled,
    );
    await bootstrap.schedules.scheduleAction(
      multi,
      DateTime(base.year, base.month, base.day, 9),
    );
    await bootstrap.schedules.scheduleAction(
      multi,
      DateTime(base.year, base.month, base.day, 14),
      append: true,
    );
    expect(
      bootstrap.timeBlocks.blocksForActionItem(multi.id).length,
      2,
      reason: 'append=true 应保留旧块并追加新块',
    );
    expect(bootstrap.timeBlocks.forActionItem(multi.id), isNotNull);

    final ActionItem single =
        await bootstrap.actions.create(title: '单块任务');
    await bootstrap.schedules.scheduleAction(
      single,
      DateTime(base.year, base.month, base.day, 9),
    );
    await bootstrap.schedules.scheduleAction(
      single,
      DateTime(base.year, base.month, base.day, 15),
    );
    expect(
      bootstrap.timeBlocks.blocksForActionItem(single.id).length,
      1,
      reason: '默认排期仍更新同一块，保持旧行为',
    );
    expect(
      bootstrap.timeBlocks.forActionItem(single.id)!.startAt.hour,
      15,
    );
  });

  test('项目可创建、关联能力并推进阶段', () async {
    final Capability capability = bootstrap.capabilities.all.first;
    final Project project = await bootstrap.projects.create(
      title: '项目仓储测试',
      goal: '验证项目阶段推进',
      capabilityIds: <String>[capability.id],
      stages: const <ProjectStage>[
        ProjectStage(id: 'p-1', title: '准备'),
        ProjectStage(id: 'p-2', title: '实现'),
      ],
      acceptance: '通过正确性测试',
      artifactUrl: 'https://example.com/demo',
    );

    final Project loaded = bootstrap.projects.byId(project.id)!;
    expect(loaded.capabilityIds, contains(capability.id));
    expect(loaded.stages.length, 2);
    expect(loaded.doneStages, 0);
    expect(
      bootstrap.projects
          .forCapability(capability.id)
          .any((Project item) => item.id == project.id),
      isTrue,
    );

    await bootstrap.projects.save(
      loaded.copyWith(
        stagesJson: jsonEncode(<Map<String, dynamic>>[
          loaded.stages.first.copyWith(done: true).toJson(),
          loaded.stages.last.toJson(),
        ]),
      ),
    );
    final Project advanced = bootstrap.projects.byId(project.id)!;
    expect(advanced.doneStages, 1);
    expect(advanced.stageProgress, 0.5);

    await bootstrap.projects.softDelete(project.id);
    expect(bootstrap.projects.byId(project.id), isNull);
  });

  test('认知负荷结构按任务负荷统计分钟', () async {
    final Capability capability = bootstrap.capabilities.all.first;
    final ActionItem task = await bootstrap.actions.create(
      title: '高负荷统计任务',
      capabilityId: capability.id,
      cognitiveLoad: CognitiveLoad.high,
    );
    await bootstrap.timeBlocks.schedule(
      title: task.title,
      startAt: DateTime.now(),
      durationMinutes: 45,
      actionItemId: task.id,
    );

    final ReviewSnapshot snapshot = bootstrap.reviewService.snapshot(
      ReviewWindow.of(ReviewPeriodType.daily, DateTime.now()),
    );
    expect(
      snapshot.loadMinutes[CognitiveLoad.high] ?? 0,
      greaterThanOrEqualTo(45),
    );
    expect(snapshot.capacityMinutes, greaterThanOrEqualTo(45));
    expect(snapshot.highLoadRate, greaterThan(0));
  });

  test('学习计时时长进入复盘「学习投入」', () async {
    final ActionItem task = await bootstrap.actions.create(
      title: '计时统计任务',
      executionMode: ExecutionMode.outputLearning,
    );
    final LearningSession session = await bootstrap.learningSessions.startFor(
      task,
      type: LearningType.declarative,
    );
    await bootstrap.learningSessions.put(
      session.copyWith(
        isFinished: true,
        completedAt: DateTime.now(),
        elapsedSeconds: 3600,
      ),
    );

    final ReviewSnapshot snapshot = bootstrap.reviewService.snapshot(
      ReviewWindow.of(ReviewPeriodType.monthly, DateTime.now()),
    );
    expect(snapshot.learningMinutes, greaterThanOrEqualTo(60));
    expect(snapshot.timedSessions, greaterThanOrEqualTo(1));
    expect(snapshot.learningHours, greaterThanOrEqualTo(1));
  });

  test('学习策略有效性：按知识类型与输出档位统计顺畅率', () async {
    final ActionItem task = await bootstrap.actions.create(
      title: '策略统计任务',
    );
    final LearningSession session = LearningSession.create(
      actionItemId: task.id,
    ).copyWith(isFinished: true, completedAt: DateTime.now());
    await bootstrap.learningSessions.put(session);
    for (int i = 0; i < 2; i++) {
      await bootstrap.learningReviews.put(
        LearningReview.create(
          sessionId: session.id,
          actionItemId: task.id,
          dueDate: DateTime.now(),
          intervalDays: 3,
        ).copyWith(
          isDone: true,
          outcome: ReviewOutcome.smooth,
          doneAt: DateTime.now(),
        ),
      );
    }

    final List<StrategyEffect> effects = bootstrap.reviewService
        .strategyEffects(ReviewWindow.of(ReviewPeriodType.monthly, DateTime.now()));
    final StrategyEffect effect = effects.firstWhere(
      (StrategyEffect item) =>
          item.type == session.learningType && item.mode == session.mode,
      orElse: () => const StrategyEffect(
        type: LearningType.custom,
        mode: LearningMode.full,
        samples: 0,
        smooth: 0,
      ),
    );
    expect(effect.samples, 2);
    expect(effect.smoothRate, 1);
  });

  test('指标分层：里程碑、证据与对齐度可统计', () async {
    final Capability capability = bootstrap.capabilities.all.first;
    final Artifact artifact = await bootstrap.artifacts.create(
      title: '分层指标证据',
      type: ArtifactType.explanation,
      capabilityId: capability.id,
    );
    final ReviewSnapshot snapshot = bootstrap.reviewService.snapshot(
      ReviewWindow.of(ReviewPeriodType.monthly, DateTime.now()),
    );
    expect(snapshot.milestonesTotal, greaterThanOrEqualTo(0));
    expect(snapshot.artifactCount, greaterThanOrEqualTo(1));
    expect(snapshot.alignmentTopRate, inInclusiveRange(0, 1));
    await bootstrap.artifacts.softDelete(artifact.id);
  });

  test('能力证据 Artifact 可创建并按能力 / 任务查询', () async {
    final Capability capability = bootstrap.capabilities.all.first;
    final ActionItem task = await bootstrap.actions.create(
      title: '成果证据任务',
      capabilityId: capability.id,
    );

    final Artifact artifact = await bootstrap.artifacts.create(
      title: 'DPLL 算法实现与正确性验证',
      type: ArtifactType.code,
      capabilityId: capability.id,
      actionItemId: task.id,
      sessionId: 'session-demo',
      url: 'https://github.com/example/dpll',
      note: '通过全部测试用例',
    );

    expect(
      bootstrap.artifacts
          .forCapability(capability.id)
          .any((Artifact item) => item.id == artifact.id),
      isTrue,
    );
    expect(
      bootstrap.artifacts
          .forActionItem(task.id)
          .any((Artifact item) => item.id == artifact.id),
      isTrue,
    );
    final Artifact loaded = bootstrap.artifacts.byId(artifact.id)!;
    expect(loaded.type, ArtifactType.code);
    expect(loaded.url, contains('github.com'));

    await bootstrap.artifacts.softDelete(artifact.id);
    await bootstrap.actions.softDelete(task.id);
    expect(bootstrap.artifacts.byId(artifact.id), isNull);
  });

  test('全量备份导出 / 恢复 roundtrip', () async {
    final int actionsBefore = bootstrap.actions.all.length;
    final int capabilitiesBefore = bootstrap.capabilities.all.length;
    final int visionsBefore = bootstrap.visions.all.length;
    expect(actionsBefore, greaterThan(0));

    final Map<String, dynamic> backup = bootstrap.db.exportData();
    await bootstrap.db.wipeData();
    expect(bootstrap.actions.all, isEmpty);
    expect(bootstrap.visions.all, isEmpty);

    await bootstrap.db.importData(backup);
    expect(bootstrap.actions.all.length, actionsBefore);
    expect(bootstrap.capabilities.all.length, capabilitiesBefore);
    expect(bootstrap.visions.all.length, visionsBefore);
  });
}