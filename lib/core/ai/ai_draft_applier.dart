import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../database/repositories.dart';
import '../models/models.dart';
import '../services/review_service.dart';
import '../services/schedule_service.dart';
import 'ai_models.dart';

/// 执行模型草稿：按愿景 → 能力 → 阶段成果 → 项目 → 任务 → 排期顺序落库，
/// 并记录最近一次执行的逆操作供撤销。
class AiDraftApplier {
  AiDraftApplier({
    required this.visions,
    required this.capabilities,
    required this.actions,
    required this.projects,
    required this.routines,
    required this.schedules,
    required this.habits,
    required this.reviewLogs,
    required this.learningSessions,
    Box<dynamic>? undoBox,
  }) : _undoBox = undoBox {
    _restoreUndo();
  }

  final VisionRepository visions;
  final CapabilityRepository capabilities;
  final ActionItemRepository actions;
  final ProjectRepository projects;
  final WeeklyRoutineRepository routines;
  final ScheduleService schedules;
  final FoggHabitRepository habits;
  final ReviewLogRepository reviewLogs;
  final LearningSessionRepository learningSessions;
  final Box<dynamic>? _undoBox;

  final List<_UndoOp> _undo = <_UndoOp>[];

  bool get canUndo => _undo.isNotEmpty;

  Future<AiApplyResult> apply(List<AiDraft> drafts) async {
    _undo.clear();
    final List<AiDraft> ordered = drafts.toList(growable: false)
      ..sort((AiDraft a, AiDraft b) => _order(a.tool) - _order(b.tool));
    final Map<String, String> visionIds = <String, String>{};
    final Map<String, String> capabilityIds = <String, String>{};
    final Map<String, String> projectIds = <String, String>{};
    final Map<String, String> taskIds = <String, String>{};
    final List<String> errors = <String>[];
    int created = 0;

    for (final AiDraft draft in ordered) {
      try {
        switch (draft.tool) {
          case 'create_vision':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('愿景标题为空');
            final Vision vision = await visions.create(
              title: title,
              description: _text(draft.args['description']),
            );
            visionIds[_key(title)] = vision.id;
            _undo.add(_UndoOp(_UndoKind.vision, vision.id));
            created++;
          case 'create_capability':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('能力标题为空');
            final String visionTitle = _text(draft.args['visionTitle']);
            final String? visionId =
                visionIds[_key(visionTitle)] ?? _findVision(visionTitle);
            if (visionId == null) throw const _DraftError('找不到要挂载的愿景');
            final Capability capability = Capability.create(
              visionId: visionId,
              title: title,
              targetLevel: _text(draft.args['targetLevel']),
            );
            await capabilities.save(capability);
            capabilityIds[_key(title)] = capability.id;
            _undo.add(_UndoOp(_UndoKind.capability, capability.id));
            created++;
          case 'add_milestone':
            final String capabilityTitle = _text(draft.args['capabilityTitle']);
            final String? capabilityId =
                capabilityIds[_key(capabilityTitle)] ??
                _findCapability(capabilityTitle);
            final Capability? capability = capabilities.byId(capabilityId);
            if (capability == null) throw const _DraftError('找不到对应能力');
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('阶段成果为空');
            final String original = capability.milestonesJson;
            final List<CapabilityMilestone> milestones = <CapabilityMilestone>[
              ...capability.milestones,
              CapabilityMilestone(
                id: const Uuid().v4(),
                title: title,
                evidence: _text(draft.args['evidence']),
              ),
            ];
            await capabilities.save(
              capability.copyWith(milestonesJson: encodeMilestones(milestones)),
            );
            _undo.add(
              _UndoOp(_UndoKind.milestone, capability.id, extra: original),
            );
            created++;
          case 'create_project':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('项目标题为空');
            final Project project = await projects.create(
              title: title,
              goal: _text(draft.args['goal']),
              acceptance: _text(draft.args['acceptance']),
            );
            projectIds[_key(title)] = project.id;
            _undo.add(_UndoOp(_UndoKind.project, project.id));
            created++;
          case 'create_task':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('任务标题为空');
            final ActionItem task = await actions.create(
              title: title,
              note: _text(draft.args['note']),
              estimatedMinutes: _minutes(draft.args['estimatedMinutes']),
              dueDate: _date(draft.args['dueDate']),
              capabilityId:
                  capabilityIds[_key(_text(draft.args['capabilityTitle']))] ??
                  _findCapability(_text(draft.args['capabilityTitle'])),
              projectId:
                  projectIds[_key(_text(draft.args['projectTitle']))] ??
                  _findProject(_text(draft.args['projectTitle'])),
            );
            taskIds[_key(title)] = task.id;
            _undo.add(_UndoOp(_UndoKind.task, task.id));
            created++;
          case 'schedule_task':
            final String taskTitle = _text(draft.args['taskTitle']);
            final String? taskId =
                taskIds[_key(taskTitle)] ?? _findTask(taskTitle);
            final ActionItem? task = actions.byId(taskId);
            if (task == null) throw const _DraftError('找不到要排期的任务');
            final DateTime? day = _date(draft.args['date']);
            if (day == null) throw const _DraftError('排期日期无效');
            final (int, int) time = _time(draft.args['startTime']);
            final DateTime start = DateTime(
              day.year,
              day.month,
              day.day,
              time.$1,
              time.$2,
            );
            await schedules.scheduleAction(
              task,
              start,
              durationMinutes: _minutes(draft.args['durationMinutes']),
            );
            _undo.add(_UndoOp(_UndoKind.schedule, task.id));
            created++;
          case 'plan_learning':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('学习计划标题为空');
            final ActionItem task = await actions.create(
              title: title,
              note: _text(draft.args['note']),
              executionMode: ExecutionMode.outputLearning,
              estimatedMinutes: _minutes(draft.args['estimatedMinutes']),
              dueDate: _date(draft.args['dueDate']),
              capabilityId:
                  capabilityIds[_key(_text(draft.args['capabilityTitle']))] ??
                  _findCapability(_text(draft.args['capabilityTitle'])),
              projectId:
                  projectIds[_key(_text(draft.args['projectTitle']))] ??
                  _findProject(_text(draft.args['projectTitle'])),
            );
            taskIds[_key(title)] = task.id;
            _undo.add(_UndoOp(_UndoKind.task, task.id));
            created++;
            final DateTime? scheduleDay = _date(draft.args['scheduleDate']);
            if (scheduleDay != null) {
              final (int, int) time = _time(draft.args['startTime']);
              await schedules.scheduleAction(
                task,
                DateTime(
                  scheduleDay.year,
                  scheduleDay.month,
                  scheduleDay.day,
                  time.$1,
                  time.$2,
                ),
                durationMinutes: task.estimatedMinutes,
              );
              _undo.add(_UndoOp(_UndoKind.schedule, task.id));
            }
          case 'create_weekly_routine':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('固定安排标题为空');
            final int weekday = ((draft.args['weekday'] as num?)?.toInt() ?? 1)
                .clamp(1, 7);
            final (int, int) time = _time(draft.args['startTime']);
            final int minutes = _minutes(draft.args['durationMinutes']) ?? 60;
            final String linkedTitle = _text(draft.args['linkedTaskTitle']);
            final String? linkedId = linkedTitle.isEmpty
                ? null
                : (taskIds[_key(linkedTitle)] ?? _findTask(linkedTitle));
            final WeeklyRoutine routine = await routines.create(
              title: title,
              weekday: weekday,
              startMinutes: time.$1 * 60 + time.$2,
              durationMinutes: minutes,
              kind: linkedId == null
                  ? RoutineKind.fixedRoutine
                  : RoutineKind.linkedTask,
              actionItemId: linkedId,
            );
            _undo.add(_UndoOp(_UndoKind.routine, routine.id));
            created++;
          case 'create_habit_recipe':
            final String anchor = _text(draft.args['anchorPrompt']);
            final String tiny = _text(draft.args['tinyBehavior']);
            if (anchor.isEmpty || tiny.isEmpty) {
              throw const _DraftError('锚点或微行为为空');
            }
            final String linkedTitle = _text(
              draft.args['linkedCapabilityTitle'],
            );
            final String? linkedCapability = linkedTitle.isEmpty
                ? null
                : (capabilityIds[_key(linkedTitle)] ??
                      _findCapability(linkedTitle));
            final String celebration = _text(draft.args['celebration']);
            final FoggHabit habit = await habits.create(
              anchorPrompt: anchor,
              tinyBehavior: tiny,
              linkedCapabilityId: linkedCapability,
              anchorPeriod: AnchorPeriod.fromName(draft.args['anchorPeriod']),
              celebration: celebration.isEmpty ? '握拳，默念：我做到了' : celebration,
              abilityFrictionTip: _text(draft.args['abilityFrictionTip']),
            );
            _undo.add(_UndoOp(_UndoKind.habit, habit.id));
            created++;
          case 'propose_review_adjustments':
            final ReviewPeriodType type = ReviewPeriodType.fromName(
              draft.args['periodType'],
            );
            final String key = _text(draft.args['periodKey']).isEmpty
                ? ReviewWindow.of(type, DateTime.now()).periodKey
                : _text(draft.args['periodKey']);
            final ReviewLog? existing = reviewLogs.forPeriod(type, key);
            final bool wasCreated = existing == null;
            final String? original = existing == null
                ? null
                : jsonEncode(existing.toJson());
            final ReviewLog log =
                existing ?? ReviewLog.create(periodType: type, periodKey: key);
            final String adjustments = _text(draft.args['adjustments']);
            final String focus = _text(draft.args['focus']);
            final String ifThen = _text(draft.args['ifThen']);
            final ReviewLog next = log.copyWith(
              adjustmentsText: _appendLine(log.adjustmentsText, adjustments),
              focusText: focus.isEmpty ? log.focusText : focus,
              ifThenText: ifThen.isEmpty ? log.ifThenText : ifThen,
            );
            await reviewLogs.save(next);
            _undo.add(
              _UndoOp(
                _UndoKind.review,
                next.id,
                extra: wasCreated ? null : original,
              ),
            );
            created++;
          case 'update_vision':
            final String title = _text(draft.args['visionTitle']);
            final Vision? vision = _findVisionEntity(title);
            if (vision == null) throw const _DraftError('找不到该愿景');
            final String original = jsonEncode(vision.toJson());
            final String nextTitle = _text(draft.args['title']);
            await visions.save(
              vision.copyWith(
                title: nextTitle.isEmpty ? null : nextTitle,
                description: draft.args['description'] == null
                    ? null
                    : _text(draft.args['description']),
              ),
            );
            _undo.add(
              _UndoOp(_UndoKind.visionUpdate, vision.id, extra: original),
            );
            created++;
          case 'update_capability':
            final String title = _text(draft.args['capabilityTitle']);
            final Capability? capability = _findCapabilityEntity(title);
            if (capability == null) throw const _DraftError('找不到该能力');
            final String original = jsonEncode(capability.toJson());
            final String nextTitle = _text(draft.args['title']);
            final String visionTitle = _text(draft.args['visionTitle']);
            final String? visionId = visionTitle.isEmpty
                ? null
                : (visionIds[_key(visionTitle)] ?? _findVision(visionTitle));
            await capabilities.save(
              capability.copyWith(
                title: nextTitle.isEmpty ? null : nextTitle,
                targetLevel: draft.args['targetLevel'] == null
                    ? null
                    : _text(draft.args['targetLevel']),
                visionId: visionId,
              ),
            );
            _undo.add(
              _UndoOp(
                _UndoKind.capabilityUpdate,
                capability.id,
                extra: original,
              ),
            );
            created++;
          case 'update_task_fields':
            final String taskTitle = _text(draft.args['taskTitle']);
            final ActionItem? task = _findTaskEntity(taskTitle);
            if (task == null) throw const _DraftError('找不到该任务');
            final String original = jsonEncode(task.toJson());
            final String nextTitle = _text(draft.args['title']);
            final String capTitle = _text(draft.args['capabilityTitle']);
            final String projTitle = _text(draft.args['projectTitle']);
            await actions.save(
              task.copyWith(
                title: nextTitle.isEmpty ? null : nextTitle,
                note: draft.args['note'] == null
                    ? null
                    : _text(draft.args['note']),
                estimatedMinutes: _minutes(draft.args['estimatedMinutes']),
                dueDate: _date(draft.args['dueDate']),
                capabilityId: capTitle.isEmpty
                    ? null
                    : (capabilityIds[_key(capTitle)] ??
                          _findCapability(capTitle)),
                projectId: projTitle.isEmpty
                    ? null
                    : (projectIds[_key(projTitle)] ?? _findProject(projTitle)),
              ),
            );
            _undo.add(_UndoOp(_UndoKind.taskUpdate, task.id, extra: original));
            created++;
          case 'update_project':
            final String projectTitle = _text(draft.args['projectTitle']);
            final Project? project = _findProjectEntity(projectTitle);
            if (project == null) throw const _DraftError('找不到该项目');
            final String original = jsonEncode(project.toJson());
            final String nextTitle = _text(draft.args['title']);
            final String statusName = _text(draft.args['status']);
            await projects.save(
              project.copyWith(
                title: nextTitle.isEmpty ? null : nextTitle,
                goal: draft.args['goal'] == null
                    ? null
                    : _text(draft.args['goal']),
                acceptance: draft.args['acceptance'] == null
                    ? null
                    : _text(draft.args['acceptance']),
                status: statusName.isEmpty
                    ? null
                    : ProjectStatus.fromName(statusName),
              ),
            );
            _undo.add(
              _UndoOp(_UndoKind.projectUpdate, project.id, extra: original),
            );
            created++;
          case 'add_project_stage':
            final String projectTitle = _text(draft.args['projectTitle']);
            final Project? project = _findProjectEntity(projectTitle);
            if (project == null) throw const _DraftError('找不到该项目');
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('阶段标题为空');
            final String original = project.stagesJson;
            final List<ProjectStage> stages = <ProjectStage>[
              ...project.stages,
              ProjectStage(id: const Uuid().v4(), title: title),
            ];
            await projects.save(
              project.copyWith(
                stagesJson: jsonEncode(
                  stages
                      .map((ProjectStage item) => item.toJson())
                      .toList(growable: false),
                ),
              ),
            );
            _undo.add(
              _UndoOp(_UndoKind.projectStage, project.id, extra: original),
            );
            created++;
          case 'cancel_schedule':
            final String taskTitle = _text(draft.args['taskTitle']);
            final ActionItem? task = _findTaskEntity(taskTitle);
            if (task == null) throw const _DraftError('找不到该任务');
            final TimeBlock? block = schedules.blocks.forActionItem(task.id);
            if (block == null) throw const _DraftError('该任务没有排期');
            final String restore = jsonEncode(<String, dynamic>{
              'startAt': block.startAt.toIso8601String(),
              'minutes': block.plannedMinutes,
            });
            await schedules.unschedule(task.id);
            _undo.add(
              _UndoOp(_UndoKind.scheduleRestore, task.id, extra: restore),
            );
            created++;
          case 'create_learning':
            final String title = _text(draft.args['title']);
            if (title.isEmpty) throw const _DraftError('学习主题为空');
            final LearningSession session = await learningSessions
                .startStandalone(
                  title: title,
                  type: LearningType.fromName(draft.args['learningType']),
                  mode: LearningMode.fromName(draft.args['mode']),
                );
            _undo.add(_UndoOp(_UndoKind.learning, session.id));
            created++;
          default:
            errors.add('未知草稿类型：${draft.tool}');
        }
      } catch (error) {
        errors.add(
          '${draft.summary}：${error is _DraftError ? error.message : error}',
        );
      }
    }
    await _persistUndo();
    return AiApplyResult(created: created, errors: errors);
  }

  Future<void> undoLast() async {
    while (_undo.isNotEmpty) {
      final _UndoOp op = _undo.removeLast();
      switch (op.kind) {
        case _UndoKind.vision:
          await visions.softDelete(op.id);
        case _UndoKind.capability:
          await capabilities.softDelete(op.id);
        case _UndoKind.milestone:
          final Capability? capability = capabilities.byId(op.id);
          if (capability != null) {
            await capabilities.save(
              capability.copyWith(milestonesJson: op.extra ?? '[]'),
            );
          }
        case _UndoKind.project:
          await projects.softDelete(op.id);
        case _UndoKind.task:
          await actions.softDelete(op.id);
        case _UndoKind.schedule:
          await schedules.unschedule(op.id);
        case _UndoKind.routine:
          await routines.softDelete(op.id);
        case _UndoKind.habit:
          await habits.softDelete(op.id);
        case _UndoKind.review:
          if (op.extra == null) {
            await reviewLogs.softDelete(op.id);
          } else {
            final ReviewLog old = ReviewLog.fromJson(
              (jsonDecode(op.extra!) as Map).cast<String, dynamic>(),
            );
            await reviewLogs.save(old);
          }
        case _UndoKind.learning:
          await learningSessions.softDelete(op.id);
        case _UndoKind.visionUpdate:
          if (op.extra != null) {
            await visions.save(
              Vision.fromJson(
                (jsonDecode(op.extra!) as Map).cast<String, dynamic>(),
              ),
            );
          }
        case _UndoKind.capabilityUpdate:
          if (op.extra != null) {
            await capabilities.save(
              Capability.fromJson(
                (jsonDecode(op.extra!) as Map).cast<String, dynamic>(),
              ),
            );
          }
        case _UndoKind.taskUpdate:
          if (op.extra != null) {
            await actions.save(
              ActionItem.fromJson(
                (jsonDecode(op.extra!) as Map).cast<String, dynamic>(),
              ),
            );
          }
        case _UndoKind.projectUpdate:
          if (op.extra != null) {
            await projects.save(
              Project.fromJson(
                (jsonDecode(op.extra!) as Map).cast<String, dynamic>(),
              ),
            );
          }
        case _UndoKind.projectStage:
          final Project? project = projects.byId(op.id);
          if (project != null) {
            await projects.save(project.copyWith(stagesJson: op.extra ?? '[]'));
          }
        case _UndoKind.scheduleRestore:
          if (op.extra != null) {
            final Map<String, dynamic> data = (jsonDecode(op.extra!) as Map)
                .cast<String, dynamic>();
            final ActionItem? task = actions.byId(op.id);
            final DateTime? start = DateTime.tryParse(
              '${data['startAt'] ?? ''}',
            );
            if (task != null && start != null) {
              await schedules.scheduleAction(
                task,
                start,
                durationMinutes: (data['minutes'] as num?)?.toInt(),
              );
            }
          }
      }
    }
    await _persistUndo();
  }

  static const String _kUndo = 'ai.undo';

  void _restoreUndo() {
    final Object? raw = _undoBox?.get(_kUndo);
    if (raw is! String || raw.trim().isEmpty) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final Object? item in decoded) {
        if (item is! Map) continue;
        final _UndoKind? kind = _kindFromName('${item['kind'] ?? ''}');
        final String id = '${item['id'] ?? ''}';
        if (kind == null || id.isEmpty) continue;
        _undo.add(_UndoOp(kind, id, extra: item['extra'] as String?));
      }
    } catch (_) {
      _undo.clear();
    }
  }

  Future<void> _persistUndo() async {
    final Box<dynamic>? box = _undoBox;
    if (box == null) return;
    if (_undo.isEmpty) {
      await box.delete(_kUndo);
      return;
    }
    await box.put(
      _kUndo,
      jsonEncode(<Map<String, dynamic>>[
        for (final _UndoOp op in _undo)
          <String, dynamic>{
            'kind': op.kind.name,
            'id': op.id,
            'extra': op.extra,
          },
      ]),
    );
  }

  _UndoKind? _kindFromName(String name) {
    for (final _UndoKind kind in _UndoKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  Vision? _findVisionEntity(String title) {
    for (final Vision vision in visions.all) {
      if (_key(vision.title) == _key(title)) return vision;
    }
    return null;
  }

  Capability? _findCapabilityEntity(String title) {
    for (final Capability capability in capabilities.all) {
      if (_key(capability.title) == _key(title)) return capability;
    }
    return null;
  }

  Project? _findProjectEntity(String title) {
    for (final Project project in projects.all) {
      if (_key(project.title) == _key(title)) return project;
    }
    return null;
  }

  ActionItem? _findTaskEntity(String title) {
    for (final ActionItem item in actions.all) {
      if (_key(item.title) == _key(title)) return item;
    }
    return null;
  }

  String _appendLine(String base, String extra) {
    if (extra.isEmpty) return base;
    return base.trim().isEmpty ? extra : '$base\n$extra';
  }

  String? _findVision(String title) {
    if (title.isEmpty) {
      return visions.ordered.isEmpty ? null : visions.ordered.first.id;
    }
    for (final Vision vision in visions.all) {
      if (_key(vision.title) == _key(title)) return vision.id;
    }
    return null;
  }

  String? _findCapability(String title) {
    if (title.isEmpty) return null;
    for (final Capability capability in capabilities.all) {
      if (_key(capability.title) == _key(title)) return capability.id;
    }
    return null;
  }

  String? _findProject(String title) {
    if (title.isEmpty) return null;
    for (final Project project in projects.all) {
      if (_key(project.title) == _key(title)) return project.id;
    }
    return null;
  }

  String? _findTask(String title) {
    for (final ActionItem item in actions.all) {
      if (!item.isCompleted && _key(item.title) == _key(title)) return item.id;
    }
    return null;
  }

  String _text(Object? value) => '${value ?? ''}'.trim();

  String _key(String value) => value.trim().toLowerCase();

  int? _minutes(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  DateTime? _date(Object? value) {
    final String raw = _text(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  (int, int) _time(Object? value) {
    final List<String> parts = _text(value).split(':');
    final int hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
    final int minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return (hour.clamp(0, 23).toInt(), minute.clamp(0, 59).toInt());
  }

  int _order(String tool) => switch (tool) {
    'create_vision' => 0,
    'update_vision' => 10,
    'create_capability' => 1,
    'update_capability' => 11,
    'add_milestone' => 2,
    'create_project' => 3,
    'update_project' => 12,
    'add_project_stage' => 13,
    'create_task' => 4,
    'plan_learning' => 4,
    'create_learning' => 4,
    'update_task_fields' => 14,
    'schedule_task' => 5,
    'cancel_schedule' => 15,
    'create_weekly_routine' => 6,
    'create_habit_recipe' => 7,
    'propose_review_adjustments' => 8,
    _ => 9,
  };
}

class _DraftError implements Exception {
  const _DraftError(this.message);

  final String message;

  @override
  String toString() => message;
}

enum _UndoKind {
  vision,
  capability,
  milestone,
  project,
  task,
  schedule,
  routine,
  habit,
  review,
  visionUpdate,
  capabilityUpdate,
  taskUpdate,
  projectUpdate,
  projectStage,
  scheduleRestore,
  learning,
}

class _UndoOp {
  const _UndoOp(this.kind, this.id, {this.extra});

  final _UndoKind kind;
  final String id;
  final String? extra;
}
