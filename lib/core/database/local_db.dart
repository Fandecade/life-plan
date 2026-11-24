
import 'package:hive_flutter/hive_flutter.dart';

/// 本地持久化入口。
///
/// Milestone 1 采用 Hive（纯 Dart 实现，桌面 / Web / 移动端零原生依赖），
/// 所有实体以 JSON 字符串落入对应 box，并保留 sync 字段供二期服务端同步使用。
class LocalDatabase {
  static const String boxVisions = 'visions';
  static const String boxCapabilities = 'capabilities';
  static const String boxActionItems = 'action_items';
  static const String boxTimeBlocks = 'time_blocks';
  static const String boxLearningSessions = 'learning_sessions';
  static const String boxLearningReviews = 'learning_reviews';
  static const String boxWeeklyRoutines = 'weekly_routines';
  static const String boxRoutineExceptions = 'routine_exceptions';
  static const String boxFoggHabits = 'fogg_habits';
  static const String boxHabitLogs = 'habit_logs';
  static const String boxBehaviorCandidates = 'behavior_candidates';
  static const String boxHabitRecipeVersions = 'habit_recipe_versions';
  static const String boxReviewLogs = 'review_logs';
  static const String boxSettings = 'settings';

  late final Box<String> visions;
  late final Box<String> capabilities;
  late final Box<String> actionItems;
  late final Box<String> timeBlocks;
  late final Box<String> learningSessions;
  late final Box<String> learningReviews;
  late final Box<String> weeklyRoutines;
  late final Box<String> routineExceptions;
  late final Box<String> foggHabits;
  late final Box<String> habitLogs;
  late final Box<String> behaviorCandidates;
  late final Box<String> habitRecipeVersions;
  late final Box<String> reviewLogs;
  late final Box<dynamic> settings;

  /// [storagePath] 为空时走 Flutter 默认目录（移动/桌面/Web）；
  /// 测试环境可传入临时目录，避免依赖 path_provider 原生实现。
  Future<void> open({String? storagePath}) async {
    if (storagePath == null) {
      await Hive.initFlutter('life_planner');
    } else {
      Hive.init(storagePath);
    }
    visions = await Hive.openBox<String>(boxVisions);
    capabilities = await Hive.openBox<String>(boxCapabilities);
    actionItems = await Hive.openBox<String>(boxActionItems);
    timeBlocks = await Hive.openBox<String>(boxTimeBlocks);
    learningSessions = await Hive.openBox<String>(boxLearningSessions);
    learningReviews = await Hive.openBox<String>(boxLearningReviews);
    weeklyRoutines = await Hive.openBox<String>(boxWeeklyRoutines);
    routineExceptions = await Hive.openBox<String>(boxRoutineExceptions);
    foggHabits = await Hive.openBox<String>(boxFoggHabits);
    habitLogs = await Hive.openBox<String>(boxHabitLogs);
    behaviorCandidates = await Hive.openBox<String>(boxBehaviorCandidates);
    habitRecipeVersions = await Hive.openBox<String>(boxHabitRecipeVersions);
    reviewLogs = await Hive.openBox<String>(boxReviewLogs);
    settings = await Hive.openBox<dynamic>(boxSettings);
  }

  List<Box<String>> get entityBoxes => <Box<String>>[
        visions,
        capabilities,
        actionItems,
        timeBlocks,
        learningSessions,
        learningReviews,
        weeklyRoutines,
        routineExceptions,
        foggHabits,
        habitLogs,
        behaviorCandidates,
        habitRecipeVersions,
        reviewLogs,
      ];

  /// 清空全部业务数据，保留设置项。
  Future<void> wipeData() async {
    for (final box in entityBoxes) {
      await box.clear();
    }
  }

  /// 全量导出：13 个业务 box 的 JSON 字符串（不含设置）。
  Map<String, dynamic> exportData() {
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final box in entityBoxes) {
      final Map<String, dynamic> entries = <String, dynamic>{};
      for (final Object? key in box.keys) {
        final Object? value = box.get(key);
        if (value is String) entries['$key'] = value;
      }
      result[box.name] = entries;
    }
    return result;
  }

  /// 全量导入：先清空业务数据，再按 box 写回。
  Future<void> importData(Map<String, dynamic> data) async {
    await wipeData();
    for (final box in entityBoxes) {
      final Object? values = data[box.name];
      if (values is! Map) continue;
      for (final MapEntry<dynamic, dynamic> entry in values.entries) {
        final Object? value = entry.value;
        if (value is String) {
          await box.put('${entry.key}', value);
        }
      }
    }
  }

  Future<void> wipeAll() async {
    await wipeData();
    await settings.clear();
  }

  Future<void> close() => Hive.close();
}