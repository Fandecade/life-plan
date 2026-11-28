import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/shell/glass_background.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reminder_settings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/text_input_dialog.dart';

import 'settings_rows.dart';

/// 二级「提醒设置」：应用内/系统通知开关、提前量（含自定义）与两个兜底时刻。
class ReminderSettingsPage extends StatelessWidget {
  const ReminderSettingsPage({super.key});

  Future<void> _pickLead(
    BuildContext context,
    ReminderSettings settings,
  ) async {
    const int custom = -1;
    final int? choice = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        final bool customSelected =
            settings.leadMinutes != 0 &&
            !ReminderSettings.leadOptions.contains(settings.leadMinutes);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text('提前多久提醒', style: dialogContext.texts.titleLarge),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final int value in ReminderSettings.leadOptions)
                _ChoiceTile(
                  label: value == 0 ? '到点提醒' : '$value 分钟',
                  selected: settings.leadMinutes == value,
                  onTap: () => Navigator.of(dialogContext).pop(value),
                ),
              _ChoiceTile(
                label: '自定义…',
                selected: customSelected,
                onTap: () => Navigator.of(dialogContext).pop(custom),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return;
    if (choice != custom) {
      await settings.setLeadMinutes(choice);
      return;
    }
    final String? raw = await showTextInputDialog(
      context,
      title: '自定义提前量',
      initial: '${settings.leadMinutes == 0 ? 10 : settings.leadMinutes}',
      hintText: '0 – 1440',
      suffixText: '分钟',
      keyboardType: TextInputType.number,
      digitsOnly: true,
      validate: (String value) {
        final int? minutes = int.tryParse(value);
        if (minutes == null ||
            minutes < 0 ||
            minutes > ReminderSettings.maxLeadMinutes) {
          return '请输入 0–1440 的整数';
        }
        return null;
      },
    );
    if (raw == null || !context.mounted) return;
    final int? minutes = int.tryParse(raw);
    if (minutes != null) await settings.setLeadMinutes(minutes);
  }

  Future<void> _pickTime(
    BuildContext context,
    int current,
    Future<void> Function(int minutes) onPicked,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: '选择提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    await onPicked(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ReminderSettings settings = context.watch<ReminderSettings>();
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text('提醒设置', style: context.texts.titleLarge),
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: GlassBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              '应用内提醒与系统通知可分别关闭；系统通知在 Android / macOS 关闭应用后仍会送达。',
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsCardGroup(
              children: <Widget>[
                SettingsRow(
                  icon: Icons.notifications_active_outlined,
                  title: '应用内提醒',
                  subtitle: '应用打开或回到前台时的顶部横幅',
                  trailing: Switch(
                    value: settings.inAppEnabled,
                    onChanged: settings.setInAppEnabled,
                  ),
                ),
                SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: '系统通知',
                  subtitle: '关闭应用后仍能提醒（Web 不支持）',
                  trailing: Switch(
                    value: settings.systemEnabled,
                    onChanged: (bool value) {
                      settings.setSystemEnabled(value);
                      context.read<NotificationService>().syncUpcoming();
                    },
                  ),
                ),
                SettingsRow(
                  icon: Icons.timer_outlined,
                  title: '时间盒提前量',
                  subtitle: '按任务开始时间提前提醒',
                  onTap: () => _pickLead(context, settings),
                  trailing: _ValueTrailing(value: settings.leadLabel),
                ),
                SettingsRow(
                  icon: Icons.event_available_outlined,
                  title: '只定日期任务',
                  subtitle: '当天没有具体时段的待办',
                  onTap: () => _pickTime(
                    context,
                    settings.dateOnlyMinutes,
                    settings.setDateOnlyMinutes,
                  ),
                  trailing: _ValueTrailing(value: settings.dateOnlyLabel),
                ),
                SettingsRow(
                  icon: Icons.checklist_rounded,
                  title: '微习惯汇总',
                  subtitle: '每天一次，只提醒未完成的习惯',
                  showDivider: false,
                  onTap: () => _pickTime(
                    context,
                    settings.habitDigestMinutes,
                    settings.setHabitDigestMinutes,
                  ),
                  trailing: _ValueTrailing(value: settings.habitDigestLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueTrailing extends StatelessWidget {
  const _ValueTrailing({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: context.texts.bodyMedium?.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: palette.textTertiary,
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
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
    return ListTile(
      dense: true,
      title: Text(label, style: context.texts.bodyMedium),
      trailing: selected
          ? Icon(Icons.check_rounded, size: 16, color: palette.accent)
          : null,
      onTap: onTap,
    );
  }
}
