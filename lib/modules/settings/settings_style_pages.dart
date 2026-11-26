import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/ui_style.dart';
import '../../core/state/theme_controller.dart';
import '../../core/state/ui_style_controller.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import 'settings_sub_page.dart';

/// 外观：跟随系统 / 浅色 / 深色。
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();
    return SettingsSubPage(
      title: '外观',
      subtitle: '主题模式会即时应用到所有页面。',
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SegmentBar<ThemeMode>(
          expand: true,
          options: const <SegmentOption<ThemeMode>>[
            SegmentOption<ThemeMode>(value: ThemeMode.system, label: '跟随系统'),
            SegmentOption<ThemeMode>(value: ThemeMode.light, label: '浅色'),
            SegmentOption<ThemeMode>(value: ThemeMode.dark, label: '深色'),
          ],
          value: theme.mode,
          onChanged: (ThemeMode mode) =>
              context.read<ThemeController>().setMode(mode),
        ),
      ),
    );
  }
}

/// 界面风格：经典 / 新版、主题色、降低透明效果。
class InterfaceStyleSettingsPage extends StatelessWidget {
  const InterfaceStyleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsSubPage(
      title: '界面风格',
      subtitle: '经典版可随时切回；新版支持 4 套主题色与玻璃质感。',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InterfaceStyleSection(),
      ),
    );
  }
}

class InterfaceStyleSection extends StatelessWidget {
  const InterfaceStyleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final UiStyleController ui = context.watch<UiStyleController>();
    final AppPalette palette = context.palette;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: StyleChoice(
                      label: '经典',
                      selected: !ui.isRefresh,
                      onTap: () => ui.setStyle(AppUiStyle.classic),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StyleChoice(
                      label: '新版',
                      selected: ui.isRefresh,
                      onTap: () => ui.setStyle(AppUiStyle.refresh),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('主题色', style: context.texts.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  for (final AppAccentTheme theme in AppAccentTheme.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Tooltip(
                        message: theme.label,
                        child: InkWell(
                          onTap: () => ui.setAccent(theme),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: theme.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ui.accent == theme
                                    ? palette.textPrimary
                                    : palette.glassBorder,
                                width: ui.accent == theme ? 2 : 1,
                              ),
                            ),
                            child: ui.accent == theme
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!ui.isRefresh) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text('切换到新版后生效', style: context.texts.labelSmall),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        SettingsSwitchRow(
          title: '降低透明效果',
          subtitle: '关闭玻璃模糊，低端机更流畅',
          value: !ui.glassEnabled,
          onChanged: (bool value) => ui.setGlassEnabled(!value),
        ),
      ],
    );
  }
}

class StyleChoice extends StatelessWidget {
  const StyleChoice({
    super.key,
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
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.textPrimary : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: context.texts.bodyMedium?.copyWith(
            color: selected ? palette.background : palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 通用「标题 + 说明 + Switch」行，供多个设置页复用。
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 10,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.texts.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: context.texts.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}