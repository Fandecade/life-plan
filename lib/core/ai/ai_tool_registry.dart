import 'dart:convert';

import '../database/repositories.dart';
import '../models/models.dart';
import 'ai_context_builder.dart';
import 'ai_models.dart';

/// P0 只读工具：让模型按需查询应用数据，不直接修改任何实体。
class AiToolRegistry {
  AiToolRegistry({
    required this.context,
    required this.actions,
    required this.visions,
    required this.capabilities,
    required this.projects,
    required this.habits,
    required this.reviewLogs,
  });

  final AiContextBuilder context;
  final ActionItemRepository actions;
  final VisionRepository visions;
  final CapabilityRepository capabilities;
  final ProjectRepository projects;
  final FoggHabitRepository habits;
  final ReviewLogRepository reviewLogs;

  List<AiToolSpec> get specs => <AiToolSpec>[
    const AiToolSpec(
      name: 'get_app_snapshot',
      description: '获取应用整体快照：愿景、能力、未完成任务、今日待办、逾期、项目、习惯与最近复盘。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    AiToolSpec(
      name: 'list_tasks',
      description: '列出未完成任务，可按关键词或状态过滤。返回 id、标题、计划日、截止日、预计时长与归属。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'keyword': <String, dynamic>{
            'type': 'string',
            'description': '标题关键词',
          },
          'status': <String, dynamic>{
            'type': 'string',
            'description': 'inbox / scheduled / inProgress / deferred',
          },
          'limit': <String, dynamic>{'type': 'integer', 'default': 30},
        },
      },
    ),
    const AiToolSpec(
      name: 'list_visions',
      description: '列出愿景与描述，返回 id。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    const AiToolSpec(
      name: 'list_capabilities',
      description: '列出能力（含所属愿景、目标水平、阶段成果）。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    const AiToolSpec(
      name: 'list_projects',
      description: '列出项目与状态。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    const AiToolSpec(
      name: 'list_habits',
      description: '列出启用中的福格微习惯（锚点与微行为）。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
    const AiToolSpec(
      name: 'get_review_summary',
      description: '获取最近 3 条复盘摘要（事实、卡点、调整）。',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    ),
  ];

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    switch (name) {
      case 'get_app_snapshot':
        return context.buildSnapshot();
      case 'list_tasks':
        return _listTasks(arguments);
      case 'list_visions':
        return <String, dynamic>{
          'items': visions.all
              .map(
                (Vision vision) => <String, dynamic>{
                  'id': vision.id,
                  'title': vision.title,
                  'description': vision.description,
                },
              )
              .toList(growable: false),
        };
      case 'list_capabilities':
        return <String, dynamic>{
          'items': capabilities.all
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
        };
      case 'list_projects':
        return <String, dynamic>{
          'items': projects.all
              .map(
                (Project project) => <String, dynamic>{
                  'id': project.id,
                  'title': project.title,
                  'status': project.status.label,
                },
              )
              .toList(growable: false),
        };
      case 'list_habits':
        return <String, dynamic>{
          'items': habits.all
              .where((FoggHabit habit) => habit.isActive)
              .map(
                (FoggHabit habit) => <String, dynamic>{
                  'id': habit.id,
                  'anchor': habit.anchorPrompt,
                  'tinyBehavior': habit.tinyBehavior,
                },
              )
              .toList(growable: false),
        };
      case 'get_review_summary':
        return <String, dynamic>{
          'items': reviewLogs.all
              .take(3)
              .map(
                (ReviewLog log) => <String, dynamic>{
                  'period': log.periodKey,
                  'type': log.periodType.label,
                  'wins': log.winsText,
                  'blockers': log.blockersText,
                  'adjustments': log.adjustmentsText,
                  'focus': log.focusText,
                },
              )
              .toList(growable: false),
        };
      default:
        return <String, dynamic>{'error': '未知工具：$name'};
    }
  }

  Map<String, dynamic> _listTasks(Map<String, dynamic> arguments) {
    final String keyword = '${arguments['keyword'] ?? ''}'.trim().toLowerCase();
    final String status = '${arguments['status'] ?? ''}'.trim();
    final int limit = (arguments['limit'] as num?)?.toInt().clamp(1, 100) ?? 30;

    final List<ActionItem> items = actions.all
        .where((ActionItem item) => !item.isCompleted)
        .where(
          (ActionItem item) => status.isEmpty || item.status.name == status,
        )
        .where(
          (ActionItem item) =>
              keyword.isEmpty ||
              item.title.toLowerCase().contains(keyword) ||
              item.note.toLowerCase().contains(keyword),
        )
        .take(limit)
        .toList(growable: false);

    return <String, dynamic>{
      'items': items
          .map(
            (ActionItem item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'note': item.note,
              'status': item.status.label,
              'scheduledDate': item.scheduledDate?.toIso8601String(),
              'dueDate': item.dueDate?.toIso8601String(),
              'estimatedMinutes': item.estimatedMinutes,
              'capabilityId': item.capabilityId,
              'projectId': item.projectId,
              'parentId': item.parentId,
            },
          )
          .toList(growable: false),
    };
  }

  String encodeResult(Object result) => jsonEncode(result);
}
