import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/ai/ai_assistant_service.dart';
import '../core/ai/ai_settings_controller.dart';
import '../core/database/repositories.dart';
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
import '../core/state/ui_controller.dart';
import '../core/state/ui_style_controller.dart';
import 'bootstrap.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/ui_style.dart';

class LifePlannerApp extends StatelessWidget {
  const LifePlannerApp({super.key, required this.bootstrap});

  final AppBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppBootstrap>.value(value: bootstrap),
        ChangeNotifierProvider<ThemeController>.value(value: bootstrap.theme),
        ChangeNotifierProvider<UiStyleController>.value(
          value: bootstrap.uiStyle,
        ),
        ChangeNotifierProvider<HomeSettings>.value(
          value: bootstrap.homeSettings,
        ),
        Provider<DashboardService>.value(value: bootstrap.dashboard),
        ChangeNotifierProvider<ReminderSettings>.value(
          value: bootstrap.reminderSettings,
        ),
        Provider<ReminderService>.value(value: bootstrap.reminders),
        Provider<NotificationService>.value(value: bootstrap.notifications),
        ChangeNotifierProvider<AiSettingsController>.value(
          value: bootstrap.aiSettings,
        ),
        ChangeNotifierProvider<AiAssistantService>.value(
          value: bootstrap.aiAssistant,
        ),
        ChangeNotifierProvider<ModuleRegistry>.value(value: bootstrap.modules),
        ChangeNotifierProvider<VisionRepository>.value(
          value: bootstrap.visions,
        ),
        ChangeNotifierProvider<CapabilityRepository>.value(
          value: bootstrap.capabilities,
        ),
        ChangeNotifierProvider<ActionItemRepository>.value(
          value: bootstrap.actions,
        ),
        ChangeNotifierProvider<TimeBlockRepository>.value(
          value: bootstrap.timeBlocks,
        ),
        ChangeNotifierProvider<LearningSessionRepository>.value(
          value: bootstrap.learningSessions,
        ),
        ChangeNotifierProvider<LearningReviewRepository>.value(
          value: bootstrap.learningReviews,
        ),
        ChangeNotifierProvider<WeeklyRoutineRepository>.value(
          value: bootstrap.weeklyRoutines,
        ),
        ChangeNotifierProvider<RoutineExceptionRepository>.value(
          value: bootstrap.routineExceptions,
        ),
        ChangeNotifierProvider<ReviewLogRepository>.value(
          value: bootstrap.reviewLogs,
        ),
        ChangeNotifierProvider<FoggHabitRepository>.value(
          value: bootstrap.foggHabits,
        ),
        ChangeNotifierProvider<HabitLogRepository>.value(
          value: bootstrap.habitLogs,
        ),
        ChangeNotifierProvider<BehaviorCandidateRepository>.value(
          value: bootstrap.behaviorCandidates,
        ),
        ChangeNotifierProvider<HabitRecipeVersionRepository>.value(
          value: bootstrap.habitRecipeVersions,
        ),
        ChangeNotifierProvider<ArtifactRepository>.value(
          value: bootstrap.artifacts,
        ),
        ChangeNotifierProvider<ProjectRepository>.value(
          value: bootstrap.projects,
        ),
        ChangeNotifierProvider<CountdownRepository>.value(
          value: bootstrap.countdowns,
        ),
        Provider<HabitService>.value(value: bootstrap.habitService),
        Provider<ReviewService>.value(value: bootstrap.reviewService),
        Provider<ScheduleService>.value(value: bootstrap.schedules),
        Provider<RoutineService>.value(value: bootstrap.routines),
        ChangeNotifierProvider<UiController>(create: (_) => UiController()),
      ],
      child: Consumer2<ThemeController, UiStyleController>(
        builder:
            (
              BuildContext context,
              ThemeController theme,
              UiStyleController uiStyle,
              Widget? child,
            ) {
              final bool glassStyle = uiStyle.style == AppUiStyle.refresh;
              return MaterialApp(
                title: '人生规划',
                debugShowCheckedModeBanner: false,
                theme: glassStyle
                    ? AppTheme.refreshLight(
                        uiStyle.accent,
                        glassEnabled: uiStyle.glassEnabled,
                      )
                    : AppTheme.flatLight(uiStyle.accent),
                darkTheme: glassStyle
                    ? AppTheme.refreshDark(
                        uiStyle.accent,
                        glassEnabled: uiStyle.glassEnabled,
                      )
                    : AppTheme.flatDark(uiStyle.accent),
                themeMode: theme.mode,
                themeAnimationDuration: const Duration(milliseconds: 260),
                themeAnimationCurve: Curves.easeOutCubic,
                locale: const Locale('zh', 'CN'),
                supportedLocales: const <Locale>[
                  Locale('zh', 'CN'),
                  Locale('en', 'US'),
                ],
                localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                scrollBehavior: const _AppScrollBehavior(),
                home: const AppShell(),
              );
            },
      ),
    );
  }
}

/// 桌面端允许鼠标/触控板拖拽滚动，移动端保持原生手感。
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
