import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/bootstrap.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

import '../../core/database/repositories.dart';
import '../../core/database/seed_data.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/state/theme_controller.dart';
import '../../core/state/ui_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeController theme = context.watch<ThemeController>();
    final ModuleRegistry modules = context.watch<ModuleRegistry>();
    final double width = MediaQuery.sizeOf(context).width;
    final double horizontal = width < 700 ? AppSpacing.xl : AppSpacing.xxl;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(title: '外观'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
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
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: '模块管理',
                subtitle: '关闭后仅隐藏入口与扩展槽位，历史数据完整保留。',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int index = 0; index < modules.all.length; index++)
                      _ModuleRow(
                        module: modules.all[index],
                        enabled: modules.isEnabled(modules.all[index].id),
                        showDivider: index != modules.all.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: '本地数据'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(child: _LocalDataSection()),
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
                '当前版本 0.1.0 · Milestone 1 骨架。所有实体已预留 id / updatedAt / deletedAt / syncStatus，可直接接入服务端同步。',
                style: context.texts.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.module,
    required this.enabled,
    required this.showDivider,
  });

  final AppModuleDescriptor module;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
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
                child: Icon(
                  module.icon,
                  size: 16,
                  color: enabled ? palette.accent : palette.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            module.title,
                            style: context.texts.titleSmall?.copyWith(
                              color: enabled ? palette.textPrimary : palette.textTertiary,
                            ),
                          ),
                        ),
                        if (module.isCore) ...<Widget>[
                          const SizedBox(width: 6),
                          const AppChip(label: '核心', dense: true, filled: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.description,
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: enabled,
                onChanged: module.isCore
                    ? null
                    : (bool value) => context
                        .read<ModuleRegistry>()
                        .setEnabled(module.id, value),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: palette.hairline, height: 1),
      ],
    );
  }
}

class _LocalDataSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int actionCount = context.watch<ActionItemRepository>().count;
    final int blockCount = context.watch<TimeBlockRepository>().count;
    final int visionCount = context.watch<VisionRepository>().count;
    final int capabilityCount = context.watch<CapabilityRepository>().count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Stat(label: '愿景', value: visionCount),
            _Stat(label: '能力', value: capabilityCount),
            _Stat(label: '行动单元', value: actionCount),
            _Stat(label: '时间块', value: blockCount),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AppGhostButton(
              label: '重新载入示例数据',
              icon: Icons.refresh_rounded,
              onPressed: () => _reloadSeed(context),
            ),
            AppGhostButton(
              label: '清空全部数据',
              icon: Icons.delete_outline_rounded,
              tone: palette.danger,
              onPressed: () => _confirmWipe(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _reloadSeed(BuildContext context) async {
    final AppBootstrap bootstrap = context.read<AppBootstrap>();
    await SeedData.reload(
      db: bootstrap.db,
      visions: bootstrap.visions,
      capabilities: bootstrap.capabilities,
      actions: bootstrap.actions,
      timeBlocks: bootstrap.timeBlocks,
    );
    if (!context.mounted) return;
    context.read<UiController>().closeOverlays();
    _toast(context, '示例数据已载入');
  }

  Future<void> _confirmWipe(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text('清空全部本地数据？', style: dialogContext.texts.titleLarge),
          content: Text(
            '将删除愿景、能力、行动单元、时间块与复盘记录，且无法撤销。',
            style: dialogContext.texts.bodyMedium
                ?.copyWith(color: palette.textSecondary),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppPrimaryButton(
              label: '确认清空',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final AppBootstrap bootstrap = context.read<AppBootstrap>();
    await bootstrap.db.wipeData();
    if (!context.mounted) return;
    context.read<UiController>().closeOverlays();
    _toast(context, '本地数据已清空');
  }

  void _toast(BuildContext context, String message) {
    final AppPalette palette = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: context.texts.bodyMedium?.copyWith(color: palette.background)),
        backgroundColor: palette.textPrimary,
        behavior: SnackBarBehavior.floating,
        width: 260,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: context.texts.headlineSmall?.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }
}