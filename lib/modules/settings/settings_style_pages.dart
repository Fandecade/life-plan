import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/ui_style.dart';
import '../../core/state/theme_controller.dart';
import '../../core/state/ui_style_controller.dart';
import '../../core/widgets/app_chip.dart';
import 'settings_rows.dart';
import 'settings_sub_page.dart';

/// 外观：主题模式 + 界面风格 + 主题色 + 降低透明效果。
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();
    final UiStyleController ui = context.watch<UiStyleController>();
    final AppPalette palette = context.palette;

    return SettingsSubPage(
      title: '外观',
      subtitle: '主题模式、界面风格与主题色会即时应用到所有页面。',
      child: SettingsCardGroup(
        children: <Widget>[
          SettingsControlRow(
            icon: Icons.brightness_6_outlined,
            title: '主题模式',
            subtitle: '跟随系统 / 浅色 / 深色',
            child: SegmentBar<ThemeMode>(
              expand: true,
              options: const <SegmentOption<ThemeMode>>[
                SegmentOption<ThemeMode>(
                  value: ThemeMode.system,
                  label: '跟随系统',
                ),
                SegmentOption<ThemeMode>(value: ThemeMode.light, label: '浅色'),
                SegmentOption<ThemeMode>(value: ThemeMode.dark, label: '深色'),
              ],
              value: theme.mode,
              onChanged: (ThemeMode mode) =>
                  context.read<ThemeController>().setMode(mode),
            ),
          ),
          SettingsControlRow(
            icon: Icons.palette_outlined,
            title: '界面风格',
            subtitle: '简洁无玻璃 / 新版玻璃质感',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: StyleChoice(
                    label: '简洁',
                    selected: ui.isFlat,
                    onTap: () => ui.setStyle(AppUiStyle.flat),
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
          ),
          SettingsControlRow(
            icon: Icons.color_lens_outlined,
            title: '主题色',
            subtitle: '4 套主题色，两种风格通用',
            showDivider: ui.isRefresh,
            child: Row(
              children: <Widget>[
                for (final AppAccentTheme accent in AppAccentTheme.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Tooltip(
                      message: accent.label,
                      child: InkWell(
                        onTap: () => ui.setAccent(accent),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: accent.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ui.accent == accent
                                  ? palette.textPrimary
                                  : palette.glassBorder,
                              width: ui.accent == accent ? 2 : 1,
                            ),
                          ),
                          child: ui.accent == accent
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (ui.isRefresh)
            SettingsRow(
              icon: Icons.blur_on_outlined,
              title: '降低透明效果',
              subtitle: '关闭玻璃模糊，低端机更流畅',
              showDivider: false,
              trailing: Switch(
                value: !ui.glassEnabled,
                onChanged: (bool value) => ui.setGlassEnabled(!value),
              ),
            ),
        ],
      ),
    );
  }
}

/// 风格二选一胶囊。
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
