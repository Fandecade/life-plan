import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/state/ui_controller.dart';
import '../theme/app_colors.dart';
import 'desktop_side_nav.dart';
import 'detail_drawer.dart';
import 'inbox_panel.dart';
import 'mobile_bottom_nav.dart';
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

class _AppShellState extends State<AppShell> {
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
                body: Stack(
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
                  ],
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
