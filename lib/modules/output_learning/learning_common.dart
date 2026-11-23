import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';

/// 五类学习的类型色，与导图/时间盒的低饱和风格保持一致。
class LearningVisuals {
  const LearningVisuals._();

  static const Map<LearningType, Color> _tones = <LearningType, Color>{
    LearningType.declarative: Color(0xFF5C7290),
    LearningType.procedural: Color(0xFF6B7F62),
    LearningType.project: Color(0xFF9A795C),
    LearningType.language: Color(0xFF8A6E86),
    LearningType.custom: Color(0xFF7B6F8A),
  };

  static Color toneOf(LearningType type) =>
      _tones[type] ?? const Color(0xFF5C7290);
}

/// `●●○○ 2/4` 形式的步骤进度。
String stepProgressLabel(LearningDraft draft) {
  final int total = draft.activeStepCount;
  final int current = draft.activeIndex + 1;
  final String dots = List<String>.generate(
    total,
    (int index) => index < current ? '●' : '○',
  ).join();
  return '$dots $current/$total';
}

/// 成果摘要：取第一个有内容的步骤，截断 60 字。
String draftSummary(LearningDraft draft) {
  for (final LearningStepDraft step in draft.fullSteps) {
    final String text = step.text.trim().replaceAll('\n', ' ');
    if (text.isEmpty) continue;
    return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  }
  final String blocker = draft.blocker.trim();
  return blocker.isEmpty ? '（未填写摘要）' : blocker;
}

/// 复习状态：逾期 / 今天 / N 天后。
String reviewDueLabel(LearningReview review, {DateTime? now}) {
  final DateTime today = AppDate.startOfDay(now ?? DateTime.now());
  final DateTime due = AppDate.startOfDay(review.dueDate);
  final int days = due.difference(today).inDays;
  if (days < 0) return '逾期 ${-days} 天';
  if (days == 0) return '今天该复习';
  return '$days 天后复习';
}