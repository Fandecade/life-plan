import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 执行模式：同一个行动单元可以按不同方式推进。
enum ExecutionMode {
  standard('标准任务'),
  outputLearning('输出式学习'),
  foggHabit('福格微习惯');

  const ExecutionMode(this.label);

  final String label;

  static ExecutionMode fromName(Object? value) => ExecutionMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ExecutionMode.standard,
      );
}

enum ActionItemStatus {
  inbox('任务池'),
  scheduled('已排期'),
  inProgress('进行中'),
  consolidating('待巩固'),
  completed('已完成'),
  deferred('已延后');

  const ActionItemStatus(this.label);

  final String label;

  static ActionItemStatus fromName(Object? value) => ActionItemStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ActionItemStatus.inbox,
      );
}

/// 统一行动单元：导图叶子节点、时间盒时间块、学习步骤、习惯任务
/// 全部指向这一份数据，避免重复录入。
class ActionItem extends SyncEntity {
  const ActionItem({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    this.capabilityId,
    this.parentId,
    this.note = '',
    this.executionMode = ExecutionMode.standard,
    this.estimatedMinutes,
    this.status = ActionItemStatus.inbox,
    this.posX = 0,
    this.posY = 0,
    this.completedAt,
    this.dueDate,
    this.isCollapsed = false,
    super.deletedAt,
    super.syncStatus,
  });

  final String? capabilityId;
  final String? parentId;
  final String title;
  final String note;
  final ExecutionMode executionMode;
  final int? estimatedMinutes;
  final ActionItemStatus status;
  final double posX;
  final double posY;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final bool isCollapsed;

  bool get isCompleted => status == ActionItemStatus.completed;

  bool get isOpen =>
      status == ActionItemStatus.inbox ||
      status == ActionItemStatus.scheduled ||
      status == ActionItemStatus.inProgress;

  bool get isInbox => status == ActionItemStatus.inbox;

  factory ActionItem.create({
    required String title,
    String? capabilityId,
    String? parentId,
    String note = '',
    ExecutionMode executionMode = ExecutionMode.standard,
    int? estimatedMinutes,
    ActionItemStatus status = ActionItemStatus.inbox,
    DateTime? dueDate,
  }) {
    final now = DateTime.now();
    return ActionItem(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title,
      capabilityId: capabilityId,
      parentId: parentId,
      note: note,
      executionMode: executionMode,
      estimatedMinutes: estimatedMinutes,
      status: status,
      dueDate: dueDate,
    );
  }

  ActionItem copyWith({
    String? capabilityId,
    bool clearCapability = false,
    String? parentId,
    bool clearParent = false,
    String? title,
    String? note,
    ExecutionMode? executionMode,
    int? estimatedMinutes,
    bool clearEstimatedMinutes = false,
    ActionItemStatus? status,
    double? posX,
    double? posY,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCollapsed,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return ActionItem(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      capabilityId: clearCapability ? null : (capabilityId ?? this.capabilityId),
      parentId: clearParent ? null : (parentId ?? this.parentId),
      note: note ?? this.note,
      executionMode: executionMode ?? this.executionMode,
      estimatedMinutes:
          clearEstimatedMinutes ? null : (estimatedMinutes ?? this.estimatedMinutes),
      status: status ?? this.status,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isCollapsed: isCollapsed ?? this.isCollapsed,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'capabilityId': capabilityId,
        'parentId': parentId,
        'title': title,
        'note': note,
        'executionMode': executionMode.name,
        'estimatedMinutes': estimatedMinutes,
        'status': status.name,
        'posX': posX,
        'posY': posY,
        'completedAt': completedAt?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'isCollapsed': isCollapsed,
      };

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      capabilityId: json['capabilityId'] as String?,
      parentId: json['parentId'] as String?,
      note: json['note'] as String? ?? '',
      executionMode: ExecutionMode.fromName(json['executionMode']),
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      status: ActionItemStatus.fromName(json['status']),
      posX: (json['posX'] as num?)?.toDouble() ?? 0,
      posY: (json['posY'] as num?)?.toDouble() ?? 0,
      completedAt: parseNullableDate(json['completedAt']),
      dueDate: parseNullableDate(json['dueDate']),
      isCollapsed: json['isCollapsed'] as bool? ?? false,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}