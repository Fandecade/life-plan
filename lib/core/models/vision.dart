import 'package:uuid/uuid.dart';

import 'sync_entity.dart';

const _uuid = Uuid();

/// 愿景：人生规划图谱的一级根节点。
class Vision extends SyncEntity {
  const Vision({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    this.description = '',
    this.timeHorizon = '3年',
    this.colorHex = '#4A5F7A',
    this.posX = 0,
    this.posY = 0,
    this.isCollapsed = false,
    super.deletedAt,
    super.syncStatus,
  });

  final String title;
  final String description;
  final String timeHorizon;
  final String colorHex;
  final double posX;
  final double posY;
  final bool isCollapsed;

  String get horizonLabel => '$timeHorizon愿景';

  factory Vision.create({
    required String title,
    String description = '',
    String timeHorizon = '3年',
    String colorHex = '#4A5F7A',
  }) {
    final now = DateTime.now();
    return Vision(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      title: title,
      description: description,
      timeHorizon: timeHorizon,
      colorHex: colorHex,
    );
  }

  Vision copyWith({
    String? title,
    String? description,
    String? timeHorizon,
    String? colorHex,
    double? posX,
    double? posY,
    bool? isCollapsed,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Vision(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      title: title ?? this.title,
      description: description ?? this.description,
      timeHorizon: timeHorizon ?? this.timeHorizon,
      colorHex: colorHex ?? this.colorHex,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseToJson(),
        'title': title,
        'description': description,
        'timeHorizon': timeHorizon,
        'colorHex': colorHex,
        'posX': posX,
        'posY': posY,
        'isCollapsed': isCollapsed,
      };

  factory Vision.fromJson(Map<String, dynamic> json) {
    return Vision(
      id: json['id'] as String? ?? _uuid.v4(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timeHorizon: json['timeHorizon'] as String? ?? '3年',
      colorHex: json['colorHex'] as String? ?? '#4A5F7A',
      posX: (json['posX'] as num?)?.toDouble() ?? 0,
      posY: (json['posY'] as num?)?.toDouble() ?? 0,
      isCollapsed: json['isCollapsed'] as bool? ?? false,
      deletedAt: parseNullableDate(json['deletedAt']),
      syncStatus: SyncStatus.fromName(json['syncStatus']),
    );
  }
}