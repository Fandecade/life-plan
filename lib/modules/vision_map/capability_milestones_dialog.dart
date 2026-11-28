import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/state_views.dart';

const _uuid = Uuid();

/// 能力的阶段成果（Milestone）：能力达到某个水平时可以独立完成什么。
///
/// 它是能力的验收标准与证据入口，不计入任务完成数。
Future<void> showCapabilityMilestonesDialog(
  BuildContext context, {
  required Capability capability,
}) {
  return showAppSheet<void>(
    context,
    builder: (BuildContext dialogContext) =>
        _CapabilityMilestonesDialog(capability: capability),
  );
}

class _CapabilityMilestonesDialog extends StatefulWidget {
  const _CapabilityMilestonesDialog({required this.capability});

  final Capability capability;

  @override
  State<_CapabilityMilestonesDialog> createState() =>
      _CapabilityMilestonesDialogState();
}

class _CapabilityMilestonesDialogState
    extends State<_CapabilityMilestonesDialog> {
  late List<CapabilityMilestone> _items;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _evidence = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List<CapabilityMilestone>.from(widget.capability.milestones);
  }

  @override
  void dispose() {
    _title.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await context.read<CapabilityRepository>().save(
      widget.capability.copyWith(milestonesJson: encodeMilestones(_items)),
    );
  }

  void _add() {
    final String title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _items.add(
        CapabilityMilestone(
          id: _uuid.v4(),
          title: title,
          evidence: _evidence.text.trim(),
        ),
      );
      _title.clear();
      _evidence.clear();
    });
    _persist();
  }

  Future<void> _toggle(CapabilityMilestone milestone) async {
    if (milestone.achieved) {
      final bool confirmed = await confirmCancelMilestone(context);
      if (!confirmed || !mounted) return;
    }
    final int index = _items.indexWhere(
      (CapabilityMilestone item) => item.id == milestone.id,
    );
    if (index < 0) return;
    setState(() {
      _items[index] = milestone.achieved
          ? milestone.copyWith(achieved: false, clearAchievedAt: true)
          : milestone.copyWith(achieved: true, achievedAt: DateTime.now());
    });
    _persist();
  }

  void _remove(CapabilityMilestone milestone) {
    setState(() {
      _items.removeWhere((CapabilityMilestone item) => item.id == milestone.id);
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int achieved = _items
        .where((CapabilityMilestone item) => item.achieved)
        .length;
    final List<Artifact> artifacts = context
        .watch<ArtifactRepository>()
        .forCapability(widget.capability.id);

    return AppSheetContent(
      title: '阶段成果',
      titleTrailing: AppChip(
        label: '$achieved/${_items.length}',
        dense: true,
        filled: true,
        color: palette.accent,
      ),
      heightFactor: 0.82,
      maxWidth: 620,
      scrollable: false,
      actions: <Widget>[
        AppPrimaryButton(
          label: '完成',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '阶段成果是能力的验收标准：达到时，你能独立完成什么？'
            '它不计入任务数，只作为能力证据与复盘依据。',
            style: context.texts.bodySmall,
          ),
          if (artifacts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '能力证据 · ${artifacts.length}（来自学习成果库）',
              style: context.texts.labelSmall,
            ),
            const SizedBox(height: 3),
            for (final Artifact artifact in artifacts.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${artifact.title} · ${artifact.type.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall,
                      ),
                    ),
                    if (artifact.url.isNotEmpty)
                      Text('有链接', style: context.texts.labelSmall),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '还没有阶段成果，先加一条「可验收」的成果。',
                style: context.texts.bodySmall,
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (final CapabilityMilestone item in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: AppCheckCircle(
                                checked: item.achieved,
                                size: 18,
                                padding: 0,
                                onTap: () => _toggle(item),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.title,
                                    style: context.texts.bodyMedium?.copyWith(
                                      decoration: item.achieved
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: palette.textTertiary,
                                      color: item.achieved
                                          ? palette.textSecondary
                                          : null,
                                    ),
                                  ),
                                  if (item.evidence.isNotEmpty)
                                    Text(
                                      item.evidence,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.labelSmall,
                                    ),
                                ],
                              ),
                            ),
                            if (item.achieved && item.achievedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  AppDate.monthDayLabel(item.achievedAt!),
                                  style: context.texts.labelSmall,
                                ),
                              ),
                            AppIconButton(
                              icon: Icons.close_rounded,
                              iconSize: 13,
                              size: 24,
                              tooltip: '删除这条阶段成果',
                              onPressed: () => _remove(item),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: palette.hairline, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Text('新增阶段成果', style: context.texts.labelSmall),
          const SizedBox(height: 4),
          AppTextField(
            key: const ValueKey<String>('milestone-title'),
            controller: _title,
            hintText: '例：能独立解释 SAT 的基本理论',
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 6),
          AppTextField(
            key: const ValueKey<String>('milestone-evidence'),
            controller: _evidence,
            hintText: '证据链接（可选）：GitHub / 文档 / 录音',
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: AppGhostButton(
              label: '添加',
              icon: Icons.add_rounded,
              dense: true,
              onPressed: _add,
            ),
          ),
        ],
      ),
    );
  }
}
