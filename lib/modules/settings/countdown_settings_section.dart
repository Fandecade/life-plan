import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/schedule_picker.dart';
import '../../core/state/home_settings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../modules/home/countdown_format.dart';

/// 主页倒计时管理：新增（自定义/任务）、上下排序、编辑、删除与自动隐藏。
class CountdownSection extends StatelessWidget {
  const CountdownSection({super.key});

  @override
  Widget build(BuildContext context) {
    final CountdownRepository repo = context.watch<CountdownRepository>();
    final ActionItemRepository actions = context.watch<ActionItemRepository>();
    final List<Countdown> items = repo.sorted();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '绑定任务时，时间以任务截止日为准。每个倒计时会作为独立卡片出现在主页。',
                  style: context.texts.bodySmall,
                ),
              ),
              Text(
                '${items.length} / ${HomeSettings.maxCountdowns}',
                style: context.texts.labelSmall,
              ),
            ],
          ),
          if (items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            for (int index = 0; index < items.length; index++)
              _CountdownRow(
                key: ValueKey<String>(items[index].id),
                item: items[index],
                index: index,
                total: items.length,
                taskTitle: items[index].isTaskBound
                    ? actions.byId(items[index].sourceTaskId)?.title
                    : null,
                taskDue: items[index].isTaskBound
                    ? actions.byId(items[index].sourceTaskId)?.dueDate
                    : null,
                taskMissing:
                    items[index].isTaskBound &&
                    actions.byId(items[index].sourceTaskId) == null,
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppGhostButton(
                label: '自定义倒计时',
                icon: Icons.add_rounded,
                onPressed: () => _addCustomCountdown(context),
              ),
              AppGhostButton(
                label: '从任务选择',
                icon: Icons.task_alt_rounded,
                onPressed: () => _pickCountdownTask(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    this.taskTitle,
    this.taskDue,
    this.taskMissing = false,
  });

  final Countdown item;
  final int index;
  final int total;
  final String? taskTitle;
  final DateTime? taskDue;
  final bool taskMissing;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final CountdownRepository repo = context.read<CountdownRepository>();
    final String title = item.title.trim().isEmpty
        ? (taskTitle ?? '倒计时')
        : item.title;
    final String subtitle;
    if (item.isTaskBound) {
      if (taskMissing) {
        subtitle = '任务已删除';
      } else if (taskDue == null) {
        subtitle = '任务未设置截止日';
      } else {
        subtitle = '任务 · ${countdownTargetLabel(taskDue!)}';
      }
    } else if (item.targetAt == null) {
      subtitle = '未设置时间';
    } else {
      subtitle = countdownTargetLabel(item.targetAt!, dateOnly: item.dateOnly);
    }

    final DateTime? dotTarget = item.isTaskBound ? taskDue : item.targetAt;
    final Color dotColor = dotTarget == null
        ? palette.textTertiary
        : countdownColorFor(
            target: dotTarget,

            dateOnly: item.dateOnly,
            customHex: item.colorHex,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: () => _editCountdown(context, item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: context.texts.titleSmall),
                      const SizedBox(height: 2),
                      Text(subtitle, style: context.texts.labelSmall),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: '颜色',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => _pickCountdownColor(context, item),
                icon: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.glassBorder),
                  ),
                ),
              ),
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
                onPressed: index >= total - 1 ? null : () => _move(context, 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: '删除',
                iconSize: 16,
                onPressed: () => repo.remove(item),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Row(
              children: <Widget>[
                Text('到期自动隐藏', style: context.texts.labelSmall),
                const Spacer(),
                Switch(
                  value: item.autoHideExpired,
                  onChanged: (bool value) =>
                      repo.save(item.copyWith(autoHideExpired: value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _move(BuildContext context, int delta) {
    final CountdownRepository repo = context.read<CountdownRepository>();
    final List<Countdown> items = repo.sorted();
    final int target = index + delta;
    if (target < 0 || target >= items.length) return;
    final Countdown moved = items.removeAt(index);
    items.insert(target, moved);
    repo.reorder(items);
  }
}

Future<void> _addCustomCountdown(BuildContext context) async {
  final CountdownRepository repo = context.read<CountdownRepository>();
  if (repo.all.length >= HomeSettings.maxCountdowns) {
    _countdownToast(context, '最多只能添加 ${HomeSettings.maxCountdowns} 个倒计时');
    return;
  }
  final String? title = await _promptCountdownTitle(context, initial: '倒计时');
  if (title == null || !context.mounted) return;
  final SchedulePickResult? picked = await pickScheduleResult(
    context,
    initialDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (picked == null || !context.mounted) return;
  await repo.create(
    title: title,
    targetAt: picked.start,
    dateOnly: picked.dateOnly,
  );
  await _enableCountdownCard(context);
}

Future<void> _pickCountdownTask(BuildContext context) async {
  final CountdownRepository repo = context.read<CountdownRepository>();
  if (repo.all.length >= HomeSettings.maxCountdowns) {
    _countdownToast(context, '最多只能添加 ${HomeSettings.maxCountdowns} 个倒计时');
    return;
  }
  final Set<String> bound = repo.all
      .map((Countdown item) => item.sourceTaskId)
      .whereType<String>()
      .toSet();
  final List<ActionItem> candidates = context
      .read<ActionItemRepository>()
      .all
      .where(
        (ActionItem item) =>
            !item.isCompleted &&
            item.dueDate != null &&
            !bound.contains(item.id),
      )
      .toList(growable: false);
  if (candidates.isEmpty) {
    _countdownToast(context, '没有可绑定的任务（需未完成且已设截止日）');
    return;
  }
  final ActionItem? task = await showModalBottomSheet<ActionItem>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      final AppPalette palette = sheetContext.palette;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: palette.glassEnabled ? palette.glass : palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: palette.glassBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: <Widget>[
                for (final ActionItem item in candidates)
                  ListTile(
                    dense: true,
                    title: Text(
                      item.title,
                      style: sheetContext.texts.bodyMedium,
                    ),
                    subtitle: Text(
                      '截止 ${countdownTargetLabel(item.dueDate!)}',
                      style: sheetContext.texts.labelSmall,
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(item),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (task == null || !context.mounted) return;
  await repo.create(title: task.title, sourceTaskId: task.id);
  await _enableCountdownCard(context);
}

Future<void> _editCountdown(BuildContext context, Countdown item) async {
  if (item.isTaskBound) {
    _countdownToast(context, '时间跟随任务截止日，请在任务中修改');
    return;
  }
  final String? title = await _promptCountdownTitle(
    context,
    initial: item.title,
  );
  if (title == null || !context.mounted) return;
  final SchedulePickResult? picked = await pickScheduleResult(
    context,
    initialDate: item.targetAt ?? DateTime.now().add(const Duration(days: 1)),
  );
  if (picked == null || !context.mounted) return;
  await context.read<CountdownRepository>().save(
    item.copyWith(
      title: title,
      targetAt: picked.start,
      dateOnly: picked.dateOnly,
    ),
  );
}

Future<String?> _promptCountdownTitle(
  BuildContext context, {
  required String initial,
}) {
  return showTextInputDialog(
    context,
    title: '倒计时标题',
    initial: initial,
    hintText: '例如：项目截止',
    validate: (String value) => value.isEmpty ? '请输入倒计时标题' : null,
  );
}

Future<void> _enableCountdownCard(BuildContext context) async {
  if (!context.mounted) return;
  _countdownToast(context, '倒计时已添加');
}

Future<void> _pickCountdownColor(BuildContext context, Countdown item) async {
  final AppPalette palette = context.palette;
  final List<_CountdownColorOption> options = <_CountdownColorOption>[
    const _CountdownColorOption(
      '自动',
      null,
      countdownCalm,
      gradient: LinearGradient(
        colors: <Color>[
          countdownCalm,
          countdownSoon,
          countdownNear,
          countdownUrgent,
        ],
      ),
    ),
    _CountdownColorOption('主题色', hexFromColor(palette.accent), palette.accent),
    const _CountdownColorOption('琥珀', '#C08A4E', Color(0xFFC08A4E)),
    const _CountdownColorOption('珊瑚', '#B05B52', Color(0xFFB05B52)),
    const _CountdownColorOption('雾蓝', '#7191AE', Color(0xFF7191AE)),
    const _CountdownColorOption('薰衣草', '#8E85B8', Color(0xFF8E85B8)),
  ];
  final String? choice = await showAppSheet<String>(
    context,
    builder: (BuildContext sheetContext) {
      final AppPalette p = sheetContext.palette;
      final bool autoSelected = item.colorHex == null;
      return AppSheetContent(
        title: '倒计时颜色',
        heightFactor: null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('自动：按紧迫度 绿 → 黄 → 橙 → 红', style: sheetContext.texts.labelSmall),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (final _CountdownColorOption option in options)
                  InkWell(
                    onTap: () =>
                        Navigator.of(sheetContext).pop(option.hex ?? 'auto'),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: option.gradient == null
                                ? option.color
                                : null,
                            gradient: option.gradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  (option.hex == null && autoSelected) ||
                                      (option.hex != null &&
                                          item.colorHex == option.hex)
                                  ? p.textPrimary
                                  : p.glassBorder,
                              width:
                                  (option.hex == null && autoSelected) ||
                                      (option.hex != null &&
                                          item.colorHex == option.hex)
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child:
                              (option.hex == null && autoSelected) ||
                                  (option.hex != null &&
                                      item.colorHex == option.hex)
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.label,
                          style: sheetContext.texts.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  final CountdownRepository repo = context.read<CountdownRepository>();
  if (choice == 'auto') {
    await repo.save(item.copyWith(clearColor: true));
  } else {
    await repo.save(item.copyWith(colorHex: choice));
  }
}

class _CountdownColorOption {
  const _CountdownColorOption(
    this.label,
    this.hex,
    this.color, {
    this.gradient,
  });

  final String label;
  final String? hex;
  final Color color;
  final Gradient? gradient;
}

void _countdownToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      width: 280,
    ),
  );
}
