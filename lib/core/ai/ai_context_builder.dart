import '../database/repositories.dart';
import '../models/models.dart';
import '../utils/date_utils.dart';

/// 为 AI 构建精简的项目快照，避免一次性发送全部数据。
class AiContextBuilder {
  AiContextBuilder({
    required this.visions,
    required this.capabilities,
    required this.actions,
    required this.blocks,
    required this.projects,
    required this.habits,
    required this.reviewLogs,
  });

  final VisionRepository visions;
  final CapabilityRepository capabilities;
  final ActionItemRepository actions;
  final TimeBlockRepository blocks;
  final ProjectRepository projects;
  final FoggHabitRepository habits;
  final ReviewLogRepository reviewLogs;

  Map<String, dynamic> buildSnapshot({DateTime? now}) {
    final DateTime today = now ?? DateTime.now();
    final List<ActionItem> allActions = actions.all;
    final List<ActionItem> pending = allActions
        .where((ActionItem item) => !item.isCompleted)
        .toList();

    return <String, dynamic>{
      'today': AppDate.fullDateLabel(today),
      'counts': <String, dynamic>{
        'visions': visions.all.length,
        'capabilities': capabilities.all.length,
        'pendingTasks': pending.length,
        'projects': projects.all.length,
        'habits': habits.all.length,
      },
      'visions': visions.all
          .take(20)
          .map(
            (Vision vision) => <String, dynamic>{
              'id': vision.id,
              'title': vision.title,
              'description': vision.description,
            },
          )
          .toList(growable: false),
      'capabilities': capabilities.all
          .take(40)
          .map(
            (Capability capability) => <String, dynamic>{
              'id': capability.id,
              'visionId': capability.visionId,
              'title': capability.title,
              'targetLevel': capability.targetLevel,
              'milestones': capability.milestones
                  .map((CapabilityMilestone item) => item.title)
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'pendingTasks': pending
          .take(50)
          .map(
            (ActionItem item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'status': item.status.label,
              'scheduledDate': item.scheduledDate == null
                  ? null
                  : AppDate.dateKey(item.scheduledDate!),
              'dueDate': item.dueDate == null
                  ? null
                  : AppDate.dateKey(item.dueDate!),
              'estimatedMinutes': item.estimatedMinutes,
              'capabilityId': item.capabilityId,

              'projectId': item.projectId,
            },
          )
          .toList(growable: false),
      'todayTasks': pending
          .where(
            (ActionItem item) =>
                item.scheduledDate != null &&
                AppDate.isSameDay(item.scheduledDate!, today),
          )
          .map(
            (ActionItem item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
            },
          )
          .toList(growable: false),
      'overdueTasks': pending
          .where(
            (ActionItem item) =>
                item.scheduledDate != null &&
                AppDate.startOfDay(item.scheduledDate!)
                    .isBefore(AppDate.startOfDay(today)),
          )
          .map(
            (ActionItem item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'scheduledDate': AppDate.dateKey(item.scheduledDate!),
            },
          )
          .toList(growable: false),
      'projects': projects.all
          .take(20)
          .map(
            (Project project) => <String, dynamic>{
              'id': project.id,
              'title': project.title,
              'status': project.status.label,
            },
          )
          .toList(growable: false),
      'habits': habits.all
          .where((FoggHabit habit) => habit.isActive)
          .take(20)
          .map(
            (FoggHabit habit) => <String, dynamic>{
              'id': habit.id,
              'title': habit.tinyBehavior,
              'anchor': habit.anchorPrompt,
            },
          )
          .toList(growable: false),
      'recentReviews': reviewLogs.all
          .take(3)
          .map(
            (ReviewLog log) => <String, dynamic>{
              'period': log.periodKey,
              'type': log.periodType.label,
              'wins': log.winsText,
              'blockers': log.blockersText,
              'adjustments': log.adjustmentsText,
            },
          )
          .toList(growable: false),
    };
  }
}
