import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  test('五类学习目标都是 4 步，并带各自的复习间隔', () {
    for (final LearningType type in LearningType.values) {
      final LearningMethodTemplate template = methodOf(type);
      expect(template.stepCount, 4, reason: '${type.label} 应有 4 步');
      expect(template.intervals, isNotEmpty);
    }
    expect(intervalsOf(LearningType.declarative), <int>[1, 3, 7, 15, 30]);
    expect(intervalsOf(LearningType.procedural), <int>[1, 3, 7]);
    expect(intervalsOf(LearningType.project), <int>[1, 7, 15, 30]);
    expect(intervalsOf(LearningType.language), <int>[1, 3, 7, 15]);
  });

  test('仅陈述性与自定义支持 5 分钟微输出', () {
    expect(LearningType.declarative.supportsQuick, isTrue);
    expect(LearningType.custom.supportsQuick, isTrue);
    expect(LearningType.procedural.supportsQuick, isFalse);
    expect(LearningType.project.supportsQuick, isFalse);
    expect(LearningType.language.supportsQuick, isFalse);
  });

  test('草稿编码解码保留两档内容、步骤进度与卡点链接', () {
    LearningDraft draft = LearningDraft.initial(LearningType.declarative);
    draft = draft.withActiveText('三个核心问题');
    draft = draft.withActiveIndex(1);
    draft = draft.withActiveText('与旧知识建立联系');
    draft = draft.copyWith(blocker: '适用边界不清', link: 'https://example.com/note');
    draft = draft.withMode(LearningMode.quick).withActiveText('一句话结论');

    final LearningDraft restored =
        LearningDraft.decode(draft.encode(), LearningType.declarative);

    expect(restored.type, LearningType.declarative);
    expect(restored.fullSteps[0].text, '三个核心问题');
    expect(restored.fullSteps[1].text, '与旧知识建立联系');
    expect(restored.quickSteps.first.text, '一句话结论');
    expect(restored.blocker, '适用边界不清');
    expect(restored.link, 'https://example.com/note');
    expect(restored.mode, LearningMode.quick);
    expect(restored.filledStepCount, 2);
  });

  test('旧版数组格式的草稿回退为初始 4 步', () {
    final LearningDraft draft = LearningDraft.decode('[]', LearningType.procedural);
    expect(draft.fullSteps.length, 4);
    expect(draft.type, LearningType.procedural);
    expect(draft.hasContent, isFalse);
  });

  test('间隔推进：顺畅翻倍（上限 60）、模糊保持、遗忘回到 1 天', () {
    expect(nextIntervalDays(3, ReviewOutcome.smooth), 6);
    expect(nextIntervalDays(30, ReviewOutcome.smooth), 60);
    expect(nextIntervalDays(45, ReviewOutcome.smooth), 60);
    expect(nextIntervalDays(7, ReviewOutcome.vague), 7);
    expect(nextIntervalDays(15, ReviewOutcome.forgotten), 1);
  });

  test('会话与复习提醒 JSON 往返保留学习类型与复习结果', () {
    final LearningSession session = LearningSession.create(
      actionItemId: 'a1',
      learningType: LearningType.language,
    );
    final LearningSession restoredSession =
        LearningSession.fromJson(session.toJson());
    expect(restoredSession.learningType, LearningType.language);
    expect(restoredSession.isFinished, isFalse);

    final LearningReview review = LearningReview.create(
      sessionId: session.id,
      actionItemId: 'a1',
      dueDate: DateTime(2026, 11, 23),
      intervalDays: 1,
    ).copyWith(
      outcome: ReviewOutcome.vague,
      isDone: true,
      doneAt: DateTime(2026, 11, 23, 20),
    );
    final LearningReview restoredReview = LearningReview.fromJson(review.toJson());
    expect(restoredReview.intervalDays, 1);
    expect(restoredReview.outcome, ReviewOutcome.vague);
    expect(restoredReview.isDone, isTrue);
  });
}