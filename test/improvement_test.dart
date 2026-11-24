import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';
import 'package:life_planner/core/services/review_service.dart';

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