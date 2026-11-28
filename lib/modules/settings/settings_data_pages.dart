import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/bootstrap.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/database/seed_data.dart';
import '../../core/plugin/app_module_descriptor.dart';
import '../../core/plugin/module_registry.dart';
import '../../core/state/ui_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/state_views.dart';
import 'settings_rows.dart';
import 'settings_sub_page.dart';

/// 模块管理：关闭后仅隐藏入口与扩展槽位。
class ModuleSettingsPage extends StatelessWidget {
  const ModuleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ModuleRegistry modules = context.watch<ModuleRegistry>();
    return SettingsSubPage(
      title: '模块管理',
      subtitle: '关闭后仅隐藏入口与扩展槽位，历史数据完整保留。',
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (int index = 0; index < modules.all.length; index++)
              ModuleRow(
                module: modules.all[index],
                enabled: modules.isEnabled(modules.all[index].id),
                showDivider: index != modules.all.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

/// 本地数据：统计、示例数据、备份与清空。
class LocalDataSettingsPage extends StatelessWidget {
  const LocalDataSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return SettingsSubPage(
      title: '本地数据',
      subtitle: '备份以文件为对象；所有数据保存在本机。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const LocalDataSection(),
          const SizedBox(height: AppSpacing.lg),
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
    );
  }
}

class ModuleRow extends StatelessWidget {
  const ModuleRow({
    super.key,
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
                              color: enabled
                                  ? palette.textPrimary
                                  : palette.textTertiary,
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
                    Text(module.description, style: context.texts.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: enabled,
                onChanged: module.isCore
                    ? null
                    : (bool value) => context.read<ModuleRegistry>().setEnabled(
                        module.id,
                        value,
                      ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: palette.hairline, height: 1),
      ],
    );
  }
}

class LocalDataSection extends StatelessWidget {
  const LocalDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final int actionCount = context.watch<ActionItemRepository>().count;
    final int blockCount = context.watch<TimeBlockRepository>().count;
    final int visionCount = context.watch<VisionRepository>().count;
    final int capabilityCount = context.watch<CapabilityRepository>().count;

    return SettingsCardGroup(
      children: <Widget>[
        SettingsRow(
          icon: Icons.insights_outlined,
          title: '数据统计',
          subtitle:
              '愿景 $visionCount · 能力 $capabilityCount · 行动单元 $actionCount · 时间块 $blockCount',
        ),
        SettingsRow(
          icon: Icons.refresh_rounded,
          title: '重新载入示例数据',
          subtitle: '覆盖当前演示数据，便于快速体验',
          onTap: () => _reloadSeed(context),
        ),
        SettingsRow(
          icon: Icons.download_rounded,
          title: '导出备份',
          subtitle: '生成 JSON 备份文件',
          onTap: () => _exportBackup(context),
        ),
        SettingsRow(
          icon: Icons.upload_rounded,
          title: '从文件恢复',
          subtitle: '选择 .json 备份并覆盖当前数据',
          onTap: () => _confirmImportBackup(context),
        ),
        SettingsRow(
          icon: Icons.delete_outline_rounded,
          title: '清空全部数据',
          subtitle: '不可撤销，建议先导出备份',
          danger: true,
          showDivider: false,
          onTap: () => _confirmWipe(context),
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

  Future<void> _exportBackup(BuildContext context) async {
    final AppBootstrap bootstrap = context.read<AppBootstrap>();
    final String raw = const JsonEncoder.withIndent('  ')
        .convert(bootstrap.db.exportData());
    final Uint8List bytes = Uint8List.fromList(utf8.encode(raw));
    final String fileName =
        'life-plan-backup-${AppDate.dateKey(DateTime.now())}.json';

    Uri? saved;
    try {
      saved = await FilePicker.saveFile(
        dialogTitle: '保存备份文件',
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, '导出失败：无法打开保存对话框');
      return;
    }
    if (!context.mounted) return;
    if (saved == null && !kIsWeb) return;

    final String size = '${(bytes.length / 1024).toStringAsFixed(1)} KB';
    _toast(
      context,
      kIsWeb ? '备份已下载 · $fileName · $size' : '备份已保存 · $fileName · $size',
    );
  }

  Future<void> _confirmImportBackup(BuildContext context) async {
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, '无法打开文件选择器');
      return;
    }
    if (file == null) return;

    String raw;
    try {
      raw = (await file.xFile.readAsString()).trim();
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, '无法读取所选文件');
      return;
    }
    if (!context.mounted) return;
    if (raw.isEmpty) {
      _toast(context, '备份文件为空');
      return;
    }

    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      _toast(context, '文件不是有效的备份 JSON');
      return;
    }
    if (parsed is! Map) {
      _toast(context, '文件不是有效的备份 JSON');
      return;
    }

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
          title: Text(
            '用「${file!.name}」恢复？',
            style: dialogContext.texts.titleLarge,
          ),
          content: Text(
            '当前全部业务数据会被覆盖，设置项保持不变。恢复后建议重启应用以刷新所有页面。',
            style: dialogContext.texts.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppPrimaryButton(
              label: '确认恢复',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final AppBootstrap bootstrap = context.read<AppBootstrap>();
      await bootstrap.db.importData(parsed.cast<String, dynamic>());
      if (!context.mounted) return;
      _toast(context, '备份已恢复，建议重启应用以刷新所有页面');
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, '恢复失败：备份结构无法识别');
    }
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
            style: dialogContext.texts.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
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
        content: Text(
          message,
          style: context.texts.bodyMedium?.copyWith(color: palette.background),
        ),
        backgroundColor: palette.textPrimary,
        behavior: SnackBarBehavior.floating,
        width: 260,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class LocalStat extends StatelessWidget {
  const LocalStat({super.key, required this.label, required this.value});

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
            style: context.texts.headlineSmall?.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }
}
