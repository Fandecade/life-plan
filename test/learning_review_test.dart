import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_planner/app/bootstrap.dart';
import 'package:life_planner/core/models/models.dart';

void main() {
  late AppBootstrap bootstrap;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('life_planner_learning_test');
    bootstrap = await AppBootstrap.create(storagePath: tempDir.path);
  });

  tearDownAll(() async {
    bootstrap.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('完成学习后按类型生成 1/3/7/15/30 天复习提醒', () async {
    final ActionItem item = bootstrap.actions.all.first;
    final LearningSession session = await bootstrap.learningSessions.startFor(
      item,
      type: LearningType.declarative,
    );

    final List<LearningReview> reviews =
        await bootstrap.learningReviews.scheduleFor(
      sessionId: session.id,
      actionItemId: item.id,
      type: LearningType.declarative,
      base: DateTime(2026, 11, 22),
    );

    expect(reviews, hasLength(5));
    expect(
      reviews.map((LearningReview review) => review.intervalDays).toList(),
      <int>[1, 3, 7, 15, 30],
    );
    expect(reviews.first.dueDate, DateTime(2026, 11, 23));
    expect(
      bootstrap.learningReviews.forActionItem(item.id).length,
      greaterThanOrEqualTo(5),
    );
  });

  test('主动回忆结果决定下一次间隔：顺畅翻倍、遗忘回到 1 天', () async {
    final ActionItem item = bootstrap.actions.all.first;
    final List<LearningReview> reviews =
        await bootstrap.learningReviews.scheduleFor(
      sessionId: 'session-x',
      actionItemId: item.id,
      type: LearningType.procedural,
      base: DateTime(2026, 11, 22),
    );

    final LearningReview first = reviews.first;
    final LearningReview next = await bootstrap.learningReviews.completeReview(
      first,
      ReviewOutcome.smooth,
      base: DateTime(2026, 11, 23),
    );
    expect(next.intervalDays, 2);
    expect(next.isDone, isFalse);
    expect(next.dueDate, DateTime(2026, 11, 25));

    final LearningReview afterForgetting =
        await bootstrap.learningReviews.completeReview(
      next,
      ReviewOutcome.forgotten,
      base: DateTime(2026, 11, 25),
    );
    expect(afterForgetting.intervalDays, 1);
    expect(afterForgetting.dueDate, DateTime(2026, 11, 26));

    final LearningReview done =
        bootstrap.learningReviews.byId(first.id)!;
    expect(done.isDone, isTrue);
    expect(done.outcome, ReviewOutcome.smooth);
  });
}