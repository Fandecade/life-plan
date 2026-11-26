import '../core/database/local_db.dart';
import '../core/database/repositories.dart';
import '../core/database/seed_data.dart';
import '../core/plugin/core_modules.dart';
import '../core/plugin/module_registry.dart';
import '../core/services/dashboard_service.dart';
import '../core/services/habit_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/reminder_service.dart';
import '../core/services/reminder_settings.dart';
import '../core/services/review_service.dart';
import '../core/services/routine_service.dart';
import '../core/services/schedule_service.dart';
import '../core/state/home_settings.dart';
import '../core/state/theme_controller.dart';
import '../core/state/ui_style_controller.dart';

/// 组合根：一次性装配本地数据库、仓储、插件注册中心与全局服务。
///
/// 二期接入服务端时，仅需在这里替换仓储实现或注入同步器，
/// 模块层与界面层无需改动。
class AppBootstrap {
  AppBootstrap._({
    required this.db,
    required this.visions,
    required this.capabilities,
    required this.actions,
    required this.timeBlocks,
    required this.learningSessions,
    required this.learningReviews,
    required this.weeklyRoutines,
    required this.routineExceptions,
    required this.reviewLogs,
    required this.foggHabits,
    required this.habitLogs,
    required this.behaviorCandidates,
    required this.habitRecipeVersions,
    required this.artifacts,
    required this.projects,
    required this.habitService,
    required this.reviewService,
    required this.routines,
    required this.schedules,
    required this.modules,
    required this.theme,
    required this.uiStyle,
    required this.homeSettings,
    required this.dashboard,
    required this.reminderSettings,
    required this.reminders,
    required this.notifications,
  });

  final LocalDatabase db;
  final VisionRepository visions;
  final CapabilityRepository capabilities;
  final ActionItemRepository actions;
  final TimeBlockRepository timeBlocks;
  final LearningSessionRepository learningSessions;
  final LearningReviewRepository learningReviews;
  final WeeklyRoutineRepository weeklyRoutines;
  final RoutineExceptionRepository routineExceptions;
  final ReviewLogRepository reviewLogs;
  final FoggHabitRepository foggHabits;
  final HabitLogRepository habitLogs;
  final BehaviorCandidateRepository behaviorCandidates;
  final HabitRecipeVersionRepository habitRecipeVersions;
  final ArtifactRepository artifacts;
  final ProjectRepository projects;
  final HabitService habitService;
  final ReviewService reviewService;
  final RoutineService routines;
  final ScheduleService schedules;
  final ModuleRegistry modules;
  final ThemeController theme;
  final UiStyleController uiStyle;
  final HomeSettings homeSettings;
  final DashboardService dashboard;
  final ReminderSettings reminderSettings;
  final ReminderService reminders;
  final NotificationService notifications;

  static Future<AppBootstrap> create({String? storagePath}) async {
    final LocalDatabase db = LocalDatabase();
    await db.open(storagePath: storagePath);

    final VisionRepository visions = VisionRepository(db.visions);
    final CapabilityRepository capabilities = CapabilityRepository(db.capabilities);
    final ActionItemRepository actions = ActionItemRepository(db.actionItems);
    final TimeBlockRepository timeBlocks = TimeBlockRepository(db.timeBlocks);
    final LearningSessionRepository learningSessions =
        LearningSessionRepository(db.learningSessions);
    final LearningReviewRepository learningReviews =
        LearningReviewRepository(db.learningReviews);
    final WeeklyRoutineRepository weeklyRoutines =
        WeeklyRoutineRepository(db.weeklyRoutines);
    final RoutineExceptionRepository routineExceptions =
        RoutineExceptionRepository(db.routineExceptions);
    final ReviewLogRepository reviewLogs = ReviewLogRepository(db.reviewLogs);
    final FoggHabitRepository foggHabits = FoggHabitRepository(db.foggHabits);
    final HabitLogRepository habitLogs = HabitLogRepository(db.habitLogs);
    final BehaviorCandidateRepository behaviorCandidates =
        BehaviorCandidateRepository(db.behaviorCandidates);
    final HabitRecipeVersionRepository habitRecipeVersions =
        HabitRecipeVersionRepository(db.habitRecipeVersions);
    final ArtifactRepository artifacts = ArtifactRepository(db.artifacts);
    final ProjectRepository projects = ProjectRepository(db.projects);
    final HabitService habitService = HabitService(
      habits: foggHabits,
      logs: habitLogs,
      versions: habitRecipeVersions,
    );
    final RoutineService routines = RoutineService(
      routines: weeklyRoutines,
      exceptions: routineExceptions,
      blocks: timeBlocks,
      actions: actions,
    );
    final ScheduleService schedules =
        ScheduleService(actions: actions, blocks: timeBlocks);
    final ReviewService reviewService = ReviewService(
      logs: reviewLogs,
      actions: actions,
      blocks: timeBlocks,
      capabilities: capabilities,
      sessions: learningSessions,
      learningReviews: learningReviews,
      habits: foggHabits,
      habitLogs: habitLogs,
      habitVersions: habitRecipeVersions,
      artifacts: artifacts,
      schedules: schedules,
    );
    final ModuleRegistry modules = ModuleRegistry(
      modules: buildModuleDescriptors(),
      settings: db.settings,
    );
    final ThemeController theme = ThemeController(db.settings);
    final UiStyleController uiStyle = UiStyleController(db.settings);
    final HomeSettings homeSettings = HomeSettings(db.settings);
    final DashboardService dashboard = DashboardService(
      actions: actions,
      blocks: timeBlocks,
      habits: foggHabits,
      habitLogs: habitLogs,
      sessions: learningSessions,
    );
    final ReminderSettings reminderSettings = ReminderSettings(db.settings);
    final ReminderService reminders = ReminderService(
      settings: reminderSettings,
      actions: actions,
      blocks: timeBlocks,
      routines: weeklyRoutines,
      exceptions: routineExceptions,
      habits: foggHabits,
      habitService: habitService,
      schedules: schedules,
      routineService: routines,
      settingsBox: db.settings,
    );
    final NotificationService notifications = NotificationService(
      reminders: reminders,
      settings: reminderSettings,
    );

    await SeedData.seedIfNeeded(
      db: db,
      visions: visions,
      capabilities: capabilities,
      actions: actions,
      timeBlocks: timeBlocks,
    );

    return AppBootstrap._(
      db: db,
      visions: visions,
      capabilities: capabilities,
      actions: actions,
      timeBlocks: timeBlocks,
      learningSessions: learningSessions,
      learningReviews: learningReviews,
      weeklyRoutines: weeklyRoutines,
      routineExceptions: routineExceptions,
      reviewLogs: reviewLogs,
      foggHabits: foggHabits,
      habitLogs: habitLogs,
      behaviorCandidates: behaviorCandidates,
      habitRecipeVersions: habitRecipeVersions,
      artifacts: artifacts,
      projects: projects,
      habitService: habitService,
      reviewService: reviewService,
      routines: routines,
      schedules: schedules,
      modules: modules,
      theme: theme,
      uiStyle: uiStyle,
      homeSettings: homeSettings,
      dashboard: dashboard,
      reminderSettings: reminderSettings,
      reminders: reminders,
      notifications: notifications,
    );
  }

  void dispose() {
    visions.dispose();
    capabilities.dispose();
    actions.dispose();
    timeBlocks.dispose();
    learningSessions.dispose();
    learningReviews.dispose();
    weeklyRoutines.dispose();
    routineExceptions.dispose();
    reviewLogs.dispose();
    foggHabits.dispose();
    habitLogs.dispose();
    behaviorCandidates.dispose();
    habitRecipeVersions.dispose();
    artifacts.dispose();
    projects.dispose();
    modules.dispose();
    theme.dispose();
    uiStyle.dispose();
    homeSettings.dispose();
    reminderSettings.dispose();
    db.close();
  }
}