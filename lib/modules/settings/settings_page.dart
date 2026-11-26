import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/services/reminder_settings.dart';
import '../../core/state/home_settings.dart';
import '../../core/state/theme_controller.dart';
import '../../core/state/ui_style_controller.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import 'reminder_settings_page.dart';
import 'settings_data_pages.dart';
import 'settings_home_pages.dart';
import 'settings_style_pages.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeController theme = context.watch<ThemeController>();
    final UiStyleController ui = context.watch<UiStyleController>();
    final HomeSettings home = context.watch<HomeSettings>();
    final ReminderSettings reminder = context.watch<ReminderSettings>();
    final ModuleRegistry modules = context.watch<ModuleRegistry>();
    final double width = MediaQuery.sizeOf(context).width;
    final double horizontal = width < 700 ? AppSpacing.xl : AppSpacing.xxl;

    final List<AppModuleDescriptor> navModules = <AppModuleDescriptor>[
      for (final String id in home.bottomModules)
        ...modules.all.where((AppModuleDescriptor module) => module.id == id),
    ];
    final String navSummary = <String>[
      '主页',
      for (final AppModuleDescriptor module in navModules) module.title,
      '设置',
    ].join(' · ');

    final String themeLabel = switch (theme.mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };

    final List<_SettingsEntryData> entries = <_SettingsEntryData>[
      _SettingsEntryData(
        icon: Icons.brightness_6_outlined,
        title: '外观',
        summary: themeLabel,
        builder: () => const AppearanceSettingsPage(),
      ),
      _SettingsEntryData(
        icon: Icons.palette_outlined,
        title: '界面风格',
        summary: ui.isRefresh ? '新版 · ${ui.accent.label}' : '经典',
        builder: () => const InterfaceStyleSettingsPage(),
      ),
      _SettingsEntryData(
        icon: Icons.home_outlined,
        title: '主页',
        summary: '${home.cards.length} / ${HomeCard.values.length} 张卡片',
        builder: () => const HomeCardsSettingsPage(),
      ),
      _SettingsEntryData(
        icon: Icons.view_sidebar_outlined,
        title: '底部导航',
        summary: navSummary,
        builder: () => const BottomNavSettingsPage(),
      ),
      _SettingsEntryData(
        icon: Icons.alarm_outlined,
        title: '提醒',
        summary: reminder.summaryLabel,
        builder: () => const ReminderSettingsPage(),
      ),
      _SettingsEntryData(
        icon: Icons.extension_outlined,
        title: '模块管理',
        summary: '已启用 ${modules.enabled.length} / ${modules.all.length}',
        builder: () => const ModuleSettingsPage(),
      ),
      _SettingsEntryData(
        icon: Icons.storage_outlined,
        title: '本地数据',
        summary: '备份、恢复与示例数据',
        builder: () => const LocalDataSettingsPage(),
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: AppSpacing.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int index = 0; index < entries.length; index++)
                      Column(
                        children: <Widget>[
                          _SettingsEntry(
                            data: entries[index],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => entries[index].builder(),
                              ),
                            ),
                          ),
                          if (index != entries.length - 1)
                            Divider(
                              color: palette.hairline,
                              height: 1,
                              indent: AppSpacing.lg,
                              endIndent: AppSpacing.lg,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  StatusDot(color: palette.success),
                  const SizedBox(width: 6),
                  Text('本地存储正常 · Hive', style: context.texts.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '当前版本 0.1.0 · 所有实体已预留 id / updatedAt / deletedAt / syncStatus，可直接接入服务端同步。',
                style: context.texts.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsEntryData {
  const _SettingsEntryData({
    required this.icon,
    required this.title,
    required this.summary,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget Function() builder;
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({required this.data, required this.onTap});

  final _SettingsEntryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(data.icon, size: 16, color: palette.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(data.title, style: context.texts.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    data.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}