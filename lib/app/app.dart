import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/database/repositories.dart';
import '../core/plugin/module_registry.dart';
import '../core/services/schedule_service.dart';
import '../core/state/theme_controller.dart';
import '../core/state/ui_controller.dart';
import 'bootstrap.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class LifePlannerApp extends StatelessWidget {
  const LifePlannerApp({super.key, required this.bootstrap});

  final AppBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppBootstrap>.value(value: bootstrap),
        ChangeNotifierProvider<ThemeController>.value(value: bootstrap.theme),
        ChangeNotifierProvider<ModuleRegistry>.value(value: bootstrap.modules),
        ChangeNotifierProvider<VisionRepository>.value(value: bootstrap.visions),
        ChangeNotifierProvider<CapabilityRepository>.value(
          value: bootstrap.capabilities,
        ),
        ChangeNotifierProvider<ActionItemRepository>.value(value: bootstrap.actions),
        ChangeNotifierProvider<TimeBlockRepository>.value(
          value: bootstrap.timeBlocks,
        ),
        ChangeNotifierProvider<LearningSessionRepository>.value(
          value: bootstrap.learningSessions,
        ),
        ChangeNotifierProvider<LearningReviewRepository>.value(
          value: bootstrap.learningReviews,
        ),
        Provider<ScheduleService>.value(value: bootstrap.schedules),
        ChangeNotifierProvider<UiController>(create: (_) => UiController()),
      ],
      child: Consumer<ThemeController>(
        builder: (BuildContext context, ThemeController theme, Widget? child) {
          return MaterialApp(
            title: '人生规划',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
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