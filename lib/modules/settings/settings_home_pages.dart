import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router/module_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/state/home_settings.dart';
import '../../core/widgets/app_card.dart';
import 'settings_style_pages.dart';
import 'settings_sub_page.dart';

/// 主页卡片开关。
class HomeCardsSettingsPage extends StatelessWidget {
  const HomeCardsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsSubPage(
      title: '主页',
      subtitle: '选择主页上显示的卡片。',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: HomeCardsSection(),
      ),
    );
  }
}

/// 底部导航模块配置。
class BottomNavSettingsPage extends StatelessWidget {
  const BottomNavSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsSubPage(
      title: '底部导航',
      subtitle: '主页与设置固定显示，可再添加最多 3 个模块。',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: BottomNavSection(),
      ),
    );
  }
}

class HomeCardsSection extends StatelessWidget {
  const HomeCardsSection({super.key});

  static const Map<HomeCard, (String, String)> _labels =
      <HomeCard, (String, String)>{
    HomeCard.overview: ('今日概览', '完成任务、打卡、学习与完成时间块'),
    HomeCard.heatmap: ('热力图', '最近 12 周的活跃度'),
    HomeCard.rhythm: ('节奏指标', '连续记录、本周完成率与学习时长'),
    HomeCard.todos: ('今日待办', '当天安排的待办事项'),
    HomeCard.habits: ('今日习惯', '今日打卡情况'),
    HomeCard.shortcuts: ('快捷入口', '时间盒、学习、项目、复盘'),
  };

  @override
  Widget build(BuildContext context) {
    final HomeSettings settings = context.watch<HomeSettings>();
    final List<HomeCard> cards = HomeCard.values;
    return Column(
      children: <Widget>[
        for (int i = 0; i < cards.length; i++) ...<Widget>[
          SettingsSwitchRow(
            title: _labels[cards[i]]!.$1,
            subtitle: _labels[cards[i]]!.$2,
            value: settings.isEnabled(cards[i]),
            onChanged: (bool value) =>
                settings.setCardEnabled(cards[i], value),
          ),
          if (i != cards.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class BottomNavSection extends StatelessWidget {
  const BottomNavSection({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeSettings settings = context.watch<HomeSettings>();
    final List<AppModuleDescriptor> modules = context
        .watch<ModuleRegistry>()
        .enabled
        .where(
          (AppModuleDescriptor module) =>
              module.routeName != AppRoutes.settings,
        )
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('主页与设置为固定项。', style: context.texts.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final AppModuleDescriptor module in modules)
                ModuleChip(
                  module: module,
                  selected: settings.bottomModules.contains(module.id),
                  onTap: () {
                    final List<String> ids =
                        List<String>.from(settings.bottomModules);
                    if (ids.contains(module.id)) {
                      ids.remove(module.id);
                    } else {
                      if (ids.length >= HomeSettings.maxBottomModules) return;
                      ids.add(module.id);
                    }
                    settings.setBottomModules(ids);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '已选 ${settings.bottomModules.length} / ${HomeSettings.maxBottomModules}（不含主页与设置）',
            style: context.texts.labelSmall,
          ),
        ],
      ),
    );
  }
}

class ModuleChip extends StatelessWidget {
  const ModuleChip({
    super.key,
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final AppModuleDescriptor module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Material(
      color: selected ? palette.accentSoft : palette.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                module.icon,
                size: 14,
                color: selected ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                module.title,
                style: context.texts.labelSmall?.copyWith(
                  color: selected ? palette.accent : palette.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}