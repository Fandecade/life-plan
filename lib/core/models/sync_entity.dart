/// 所有核心实体的同步预留状态。
enum SyncStatus {
  localOnly(0),
  pendingUpdate(1),
  pendingDelete(2),
  synced(3);

  const SyncStatus(this.code);

  final int code;

  static SyncStatus fromName(Object? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncStatus.localOnly,
    );
  }
}

DateTime parseDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? parseNullableDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// 统一行动单元的同步基类。
///
/// 二期接入服务端时，只需围绕 id / updatedAt / deletedAt / syncStatus
/// 这一组字段做增量推送与冲突合并，业务字段无需改动。
abstract class SyncEntity {
  const SyncEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  bool get isDeleted => deletedAt != null;

  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  /// 子类实现：序列化为可落入本地 box 的 JSON。
  Map<String, dynamic> toJson();

  Map<String, dynamic> baseToJson() => <String, dynamic>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'syncStatus': syncStatus.name,
      };
}