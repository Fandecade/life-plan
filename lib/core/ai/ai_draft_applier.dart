import 'package:uuid/uuid.dart';

import '../database/repositories.dart';
import '../models/models.dart';
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
  });

  final VisionRepository visions;
  final CapabilityRepository capabilities;
  final ActionItemRepository actions;
  final ProjectRepository projects;
  final WeeklyRoutineRepository routines;
  final ScheduleService schedules;

  final List<_UndoOp> _undo = <_UndoOp>[];

  bool get canUndo => _undo.isNotEmpty;

  Future<AiApplyResult> apply(List<AiDraft> drafts) async {
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
          default:
            errors.add('未知草稿类型：${draft.tool}');
        }
      } catch (error) {
        errors.add(
          '${draft.summary}：${error is _DraftError ? error.message : error}',
        );
      }
    }
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
      }
    }
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
    'create_capability' => 1,
    'add_milestone' => 2,
    'create_project' => 3,
    'create_task' => 4,
    'plan_learning' => 4,
    'schedule_task' => 5,
    'create_weekly_routine' => 6,
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
}

class _UndoOp {
  const _UndoOp(this.kind, this.id, {this.extra});

  final _UndoKind kind;
  final String id;
  final String? extra;
}
