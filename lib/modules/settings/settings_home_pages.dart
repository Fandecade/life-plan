import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router/module_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/state/home_settings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import 'countdown_settings_section.dart';

import 'settings_sub_page.dart';

/// 主页卡片：拖拽排序、尺寸与显示开关，以及快捷入口选择。
class HomeCardsSettingsPage extends StatelessWidget {
  const HomeCardsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSubPage(
      title: '主页',
      subtitle: '拖拽调整顺序；设置每张卡片的尺寸与显示；图表默认关闭。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppCard(
            padding: EdgeInsets.zero,
            child: HomeCardsSection(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('快捷入口', style: context.texts.titleMedium),
          const SizedBox(height: 4),
          Text(
            '选择主页上显示的常用模块，最多 ${HomeSettings.maxShortcuts} 个。',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppCard(child: ShortcutSection()),
          const SizedBox(height: AppSpacing.xl),
          Text('倒计时', style: context.texts.titleMedium),
          const SizedBox(height: 4),
          Text(
            '最多 ${HomeSettings.maxCountdowns} 个；可自定义或绑定任务截止日。',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppCard(child: CountdownSection()),
        ],
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

  @override
  Widget build(BuildContext context) {
    final HomeSettings settings = context.watch<HomeSettings>();
    final List<HomeCard> order = settings.order;
    return Column(
      children: <Widget>[
        for (int index = 0; index < order.length; index++)
          _HomeCardRow(
            key: ValueKey<String>('home-card-${order[index].name}'),
            card: order[index],
            index: index,
            size: settings.sizeOf(order[index]),
            enabled: settings.isEnabled(order[index]),
          ),
      ],
    );
  }
}

class _HomeCardRow extends StatelessWidget {
  const _HomeCardRow({
    super.key,
    required this.card,
    required this.index,
    required this.size,
    required this.enabled,
  });

  final HomeCard card;
  final int index;
  final HomeCardSize size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final HomeSettings settings = context.read<HomeSettings>();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                card.label,
                                style: context.texts.titleSmall,
                              ),
                            ),
                            if (card.isChart) ...<Widget>[
                              const SizedBox(width: 6),
                              const AppChip(
                                label: '图表',
                                dense: true,
                                filled: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.description,
                          style: context.texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Switch(
                    value: enabled,
                    onChanged: (bool value) =>
                        settings.setCardEnabled(card, value),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6),
                child: Row(
                  children: <Widget>[
                    for (final HomeCardSize value in HomeCardSize.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _SizePill(
                          label: value.label,
                          selected: size == value,
                          onTap: () => settings.setSize(card, value),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: '上移',
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      onPressed: index == 0 ? null : () => _move(context, -1),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                    IconButton(
                      tooltip: '下移',
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      onPressed: index >= settings.order.length - 1
                          ? null
                          : () => _move(context, 1),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: palette.hairline, height: 1),
      ],
    );
  }

  void _move(BuildContext context, int delta) {
    final HomeSettings settings = context.read<HomeSettings>();
    final List<HomeCard> order = <HomeCard>[...settings.order];
    final int target = index + delta;
    if (target < 0 || target >= order.length) return;
    final HomeCard moved = order.removeAt(index);
    order.insert(target, moved);
    settings.setOrder(order);
  }
}

class _SizePill extends StatelessWidget {
  const _SizePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? palette.textPrimary : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: selected ? palette.background : palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class ShortcutSection extends StatelessWidget {
  const ShortcutSection({super.key});

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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final AppModuleDescriptor module in modules)
                ModuleChip(
                  module: module,
                  selected: settings.shortcutIds.contains(module.id),
                  onTap: () {
                    final List<String> ids =
                        List<String>.from(settings.shortcutIds);
                    if (ids.contains(module.id)) {
                      ids.remove(module.id);
                    } else {
                      if (ids.length >= HomeSettings.maxShortcuts) return;
                      ids.add(module.id);
                    }
                    settings.setShortcutIds(ids);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '已选 ${settings.shortcutIds.length} / ${HomeSettings.maxShortcuts}',
            style: context.texts.labelSmall,
          ),
        ],
      ),
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