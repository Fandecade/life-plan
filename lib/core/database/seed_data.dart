import '../models/models.dart';
import 'local_db.dart';
import 'repositories.dart';

/// 首次启动的示例数据，只为让空数据库也能看到完整交互；
/// 用户可在设置页一键清空或重新载入。
class SeedData {
  const SeedData._();

  static const String _flag = 'app.seeded';

  static Future<void> seedIfNeeded({
    required LocalDatabase db,
    required VisionRepository visions,
    required CapabilityRepository capabilities,
    required ActionItemRepository actions,
    required TimeBlockRepository timeBlocks,
  }) async {
    if (db.settings.get(_flag) == true) return;
    await db.settings.put(_flag, true);

    // 用户已有数据时不覆盖。
    if (db.visions.isNotEmpty || db.actionItems.isNotEmpty) return;

    final Vision vision = await visions.create(
      title: '成为能独立交付产品的创造者',
      description: '把想法稳定地变成可用的产品，并以此获得自由的工作节奏。',
      timeHorizon: '3年',
      colorHex: '#4A5F7A',
    );

    final Capability design = await capabilities.create(
      visionId: vision.id,
      title: '产品设计与实现',
      targetLevel: '能独立完成端到端产品',
    );
    final Capability expression = await capabilities.create(
      visionId: vision.id,
      title: '结构化表达与输出',
      targetLevel: '持续输出可复用的方法论',
    );

    await actions.create(
      title: '梳理作品集的项目结构（3 个主项目）',
      capabilityId: design.id,
      estimatedMinutes: 45,
    );

    await actions.create(
      title: '读完《学习之道》第 3 章，写下 3 个要点',
      capabilityId: expression.id,
      executionMode: ExecutionMode.outputLearning,
      estimatedMinutes: 30,
    );

    final ActionItem habitTask = await actions.create(
      title: '睡前 10 分钟写下今天的一个收获',
      capabilityId: expression.id,
      executionMode: ExecutionMode.foggHabit,
      estimatedMinutes: 10,
      status: ActionItemStatus.scheduled,
    );

    final DateTime now = DateTime.now();
    await timeBlocks.schedule(
      title: habitTask.title,
      startAt: DateTime(now.year, now.month, now.day, 21, 30),
      durationMinutes: 10,
      actionItemId: habitTask.id,
    );
  }

  /// 重新载入示例数据（设置页使用）。
  static Future<void> reload({
    required LocalDatabase db,
    required VisionRepository visions,
    required CapabilityRepository capabilities,
    required ActionItemRepository actions,
    required TimeBlockRepository timeBlocks,
  }) async {
    await db.settings.put(_flag, false);
    await seedIfNeeded(
      db: db,
      visions: visions,
      capabilities: capabilities,
      actions: actions,
      timeBlocks: timeBlocks,
    );
  }
}