import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/state/ui_controller.dart';
import '../router/module_routes.dart';
import '../theme/app_colors.dart';
import 'desktop_side_nav.dart';
import 'detail_drawer.dart';
import 'glass_background.dart';
import 'inbox_panel.dart';
import 'mobile_bottom_nav.dart';
import 'reminder_banner.dart';
import 'schedule_panel.dart';
import 'slide_over_panel.dart';
import 'top_bar.dart';

/// 响应式工作台外壳：
/// 桌面/平板 = 左侧折叠导航 + 右侧滑出面板；移动端 = 底部导航 + 底部面板。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Timer? _reminderTicker;
  Timer? _bannerTimer;
  final Queue<ReminderEvent> _pendingReminders = Queue<ReminderEvent>();
  ReminderEvent? _currentReminder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReminders());
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureNotifications());
    _reminderTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkReminders(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTicker?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkReminders();
  }

  void _checkReminders() {
    if (!mounted) return;
    final List<ReminderEvent> events = context.read<ReminderService>().tick();
    unawaited(context.read<NotificationService>().syncUpcoming());
    if (events.isEmpty) return;
    _pendingReminders.addAll(events);
    _showNextReminder();
  }

  Future<void> _ensureNotifications() async {
    if (!mounted) return;
    final NotificationService notifications = context.read<NotificationService>();
    notifications.onIntent = _handleNotificationIntent;
    await notifications.initialize();
    if (!mounted) return;
    await notifications.syncUpcoming();
  }

  void _handleNotificationIntent(String actionId, String payload) {
    final ReminderEvent? event = _decodeReminder(payload);
    if (event == null) return;
    switch (actionId) {
      case 'complete':
        unawaited(
          _runNotificationAction(
            () => context.read<ReminderService>().complete(event),
          ),
        );
      case 'snooze':
        unawaited(
          _runNotificationAction(
            () => context.read<ReminderService>().snooze(event),
          ),
        );
      default:
        _openEvent(event);
    }
  }

  Future<void> _runNotificationAction(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    await context.read<NotificationService>().syncUpcoming();
  }

  ReminderEvent? _decodeReminder(String payload) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map) {
        return ReminderEvent.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // 无效 payload 直接忽略。
    }
    return null;
  }

  void _showNextReminder() {
    if (!mounted || _currentReminder != null) return;
    if (_pendingReminders.isEmpty) return;
    setState(() => _currentReminder = _pendingReminders.removeFirst());
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 20), _dismissReminder);
  }

  void _dismissReminder() {
    if (!mounted) return;
    _bannerTimer?.cancel();
    setState(() => _currentReminder = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNextReminder());
  }

  Future<void> _completeReminder() async {
    final ReminderEvent? event = _currentReminder;
    if (event == null) return;
    await context.read<ReminderService>().complete(event);
    if (!mounted) return;
    _dismissReminder();
  }

  Future<void> _snoozeReminder() async {
    final ReminderEvent? event = _currentReminder;
    if (event == null) return;
    await context.read<ReminderService>().snooze(event);
    if (!mounted) return;
    _dismissReminder();
  }

  void _openReminder() {
    final ReminderEvent? event = _currentReminder;
    if (event == null) return;
    _openEvent(event);
    _dismissReminder();
  }

  void _openEvent(ReminderEvent event) {
    final UiController ui = context.read<UiController>();
    switch (event.kind) {
      case ReminderKind.timeBlock:
      case ReminderKind.routineBlock:
        final DateTime startAt = event.startAt ?? DateTime.now();
        if (event.blockIds.isNotEmpty) {
          ui.jumpToSchedule(startAt, event.blockIds.first);
        } else {
          ui.setRoute(AppRoutes.timeBox);
        }
      case ReminderKind.dateOnlyTask:
        final String? taskId = event.taskId;
        if (taskId != null) ui.openDetail(taskId);
      case ReminderKind.habitDigest:
        ui.setRoute(AppRoutes.foggHabit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final UiController ui = context.watch<UiController>();
    final ModuleRegistry registry = context.watch<ModuleRegistry>();
    final List<AppModuleDescriptor> modules = registry.enabled;

    AppModuleDescriptor? current;
    for (final AppModuleDescriptor module in modules) {
      if (module.routeName == ui.currentRoute) {
        current = module;
        break;
      }
    }

    // 当前模块被停用（或首次启动）时，自动回到首个可用模块。
    if (current == null && modules.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final String target = modules.first.routeName;
        if (context.read<UiController>().currentRoute != target) {
          context.read<UiController>().setRoute(target);
        }
      });
    }

    final String? detailItemId = ui.detailItemId;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= 920;
        final Widget page = current == null
            ? const SizedBox.shrink()
            : current.pageBuilder(context);

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                ui.openInbox,
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                ui.openInbox,
            const SingleActivator(LogicalKeyboardKey.escape): ui.closeOverlays,
          },
          child: Focus(
            autofocus: true,
            // 安卓返回键：先关闭详情 / 任务池 / 安排记录面板，再退出应用。
            child: PopScope<Object?>(
              canPop: !ui.hasOverlay,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;
                ui.closeOverlays();
              },
              child: Scaffold(
                backgroundColor: palette.background,
                body: GlassBackground(
                  child: Stack(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (isDesktop)
                          DesktopSideNav(
                            modules: modules,
                            currentRoute: ui.currentRoute,
                            collapsed: ui.navCollapsed,
                            onToggle: ui.toggleNav,
                            onSelect: ui.setRoute,
                          ),
                        Expanded(
                          child: Column(
                            children: <Widget>[
                              SafeArea(
                                bottom: false,
                                child: TopBar(
                                  title: current?.title ?? '人生规划',
                                  isDesktop: isDesktop,
                                ),
                              ),
                              Expanded(
                                child: KeyedSubtree(
                                  key: ValueKey<String>(ui.currentRoute),
                                  child: page,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SlideOverPanel(
                      open: ui.detailOpen,
                      side: isDesktop ? PanelSide.right : PanelSide.bottom,
                      width: 408,
                      onClose: ui.closeDetail,
                      child: detailItemId == null
                          ? const SizedBox.shrink()
                          : ActionItemDetailDrawer(
                              key: ValueKey<String>(detailItemId),
                              actionItemId: detailItemId,
                            ),
                    ),
                    SlideOverPanel(
                      open: ui.inboxOpen,
                      side: isDesktop ? PanelSide.right : PanelSide.bottom,
                      width: 432,
                      heightFraction: 0.92,
                      onClose: ui.closeInbox,
                      child: const InboxPanel(),
                    ),
                    SlideOverPanel(
                      open: ui.scheduleOpen,
                      side: isDesktop ? PanelSide.right : PanelSide.bottom,
                      width: 432,
                      heightFraction: 0.92,
                      onClose: ui.closeSchedule,
                      child: const SchedulePanel(),
                    ),
                    if (_currentReminder != null)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top +
                            (isDesktop ? 62 : 56),
                        right: isDesktop ? 24 : 12,
                        left: isDesktop ? null : 12,
                        child: SizedBox(
                          width: isDesktop
                              ? 340
                              : MediaQuery.sizeOf(context).width - 24,
                          child: ReminderBanner(
                            event: _currentReminder!,
                            onComplete: _completeReminder,
                            onSnooze: _snoozeReminder,
                            onOpen: _openReminder,
                            onDismiss: _dismissReminder,
                          ),
                        ),
                      ),
                  ],
                  ),
                ),
                bottomNavigationBar: isDesktop
                    ? null
                    : MobileBottomNav(
                        modules: modules,
                        currentRoute: ui.currentRoute,
                        onSelect: ui.setRoute,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
