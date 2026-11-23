import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/habit_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';


/// 打开「配方」流程：行为候选 → 焦点地图 → 5 维降阻 → 锚点与庆祝。
Future<bool> showHabitRecipeDialog(
  BuildContext context, {
  FoggHabit? habit,
  String? linkedActionItemId,
}) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _HabitRecipeDialog(
      habit: habit,
      linkedActionItemId: linkedActionItemId,
    ),
  );
  return changed ?? false;
}

class _HabitRecipeDialog extends StatefulWidget {
  const _HabitRecipeDialog({this.habit, this.linkedActionItemId});

  final FoggHabit? habit;
  final String? linkedActionItemId;

  @override
  State<_HabitRecipeDialog> createState() => _HabitRecipeDialogState();
}

class _HabitRecipeDialogState extends State<_HabitRecipeDialog> {
  late final TextEditingController _anchor;
  late final TextEditingController _tiny;
  late final TextEditingController _celebration;
  late final TextEditingController _frictionNote;
  late final TextEditingController _candidateInput;
  late AnchorPeriod _period;
  late FrictionProfile _frictions;
  late String? _actionItemId;
  bool _saving = false;
  bool _advancing = false;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final FoggHabit? habit = widget.habit;
    _anchor = TextEditingController(text: habit?.anchorPrompt ?? '');
    _tiny = TextEditingController(text: habit?.tinyBehavior ?? '');
    _celebration = TextEditingController(
      text: habit?.celebration ?? '握拳，默念：我做到了',
    );
    _frictions = habit?.frictions ?? const FrictionProfile();
    _frictionNote = TextEditingController(text: _frictions.note);
    _candidateInput = TextEditingController();
    _period = habit?.anchorPeriod ?? AnchorPeriod.anytime;
    _actionItemId = habit?.linkedActionItemId ?? widget.linkedActionItemId;
  }

  @override
  void dispose() {
    _anchor.dispose();
    _tiny.dispose();
    _celebration.dispose();
    _frictionNote.dispose();
    _candidateInput.dispose();
    super.dispose();
  }

  FrictionProfile _currentFrictions() => _frictions.copyWith(
        note: _frictionNote.text.trim(),
      );

  Future<void> _addCandidate() async {
    final String title = _candidateInput.text.trim();
    if (title.isEmpty) return;
    await context.read<BehaviorCandidateRepository>().add(
          title: title,
          impact: 4,
          effort: 2,
        );
    _candidateInput.clear();
  }

  Future<void> _save() async {
    final String anchor = _anchor.text.trim();
    final String tiny = _tiny.text.trim();
    if (anchor.isEmpty || tiny.isEmpty) return;
    setState(() => _saving = true);

    final FoggHabitRepository habits = context.read<FoggHabitRepository>();
    final HabitService service = context.read<HabitService>();
    final FrictionProfile frictions = _currentFrictions();

    final FoggHabit target;
    if (_isEditing) {
      target = widget.habit!.copyWith(
        anchorPrompt: anchor,
        tinyBehavior: tiny,
        celebration: _celebration.text.trim(),
        anchorPeriod: _period,
        frictions: frictions,
        linkedActionItemId: _actionItemId,
        clearLinkedActionItem: _actionItemId == null,
      );
    } else {
      target = await habits.create(
        anchorPrompt: anchor,
        tinyBehavior: tiny,
        celebration: _celebration.text.trim().isEmpty
            ? '握拳，默念：我做到了'
            : _celebration.text.trim(),
        anchorPeriod: _period,
        frictions: frictions,
        linkedActionItemId: _actionItemId,
      );
    }

    await service.saveRecipe(
      target,
      note: _isEditing ? '更新配方' : '首次创建配方',
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _advance() async {
    if (_advancing) return;
    setState(() => _advancing = true);
    final FoggHabitRepository habits = context.read<FoggHabitRepository>();
    final HabitService service = context.read<HabitService>();
    final FoggHabit? existing =
        widget.habit ?? habits.forActionItem(_actionItemId ?? '');
    final FoggHabit source = existing ??
        FoggHabit.create(
          anchorPrompt: _anchor.text.trim(),
          tinyBehavior: _tiny.text.trim(),
        );
    await service.saveRecipe(
      source.copyWith(
        tinyBehavior: _progressivelySmaller(source.tinyBehavior),
        motivationNote: '动作升级：稳定后小幅提升',
      ),
      note: '稳定执行后升级动作',
    );
    if (!mounted) return;
    setState(() => _advancing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已生成升级版配方，并留存版本记录')),
    );
  }

  String _progressivelySmaller(String text) {
    if (text.isEmpty) return '打开文档，写下 1 句话';
    return '$text（先做一半）';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<ActionItem> actions = context.watch<ActionItemRepository>().all;
    final List<BehaviorCandidate> candidates =
        context.watch<BehaviorCandidateRepository>().all;

    String actionTitle = '不关联任务';
    for (final ActionItem action in actions) {
      if (action.id == _actionItemId) {
        actionTitle = action.title;
        break;
      }
    }

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      title: Row(
        children: <Widget>[
          Text(
            _isEditing ? '调整配方' : '新建微习惯',
            style: context.texts.titleLarge,
          ),
          const Spacer(),
          if (_isEditing)
            AppGhostButton(
              label: '动作升级',
              icon: Icons.trending_up_rounded,
              dense: true,
              onPressed: _advancing ? null : _advance,
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: 640,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _label(context, '锚点场景（首选提示）'),
                AppTextField(
                  key: const ValueKey<String>('habit-anchor'),
                  controller: _anchor,
                  hintText: '例如：早上泡好咖啡后 / 晚饭后坐到书桌前',
                ),
                const SizedBox(height: AppSpacing.md),
                _label(context, '微行为（15 秒～2 分钟可启动）'),
                AppTextField(
                  key: const ValueKey<String>('habit-tiny'),
                  controller: _tiny,
                  hintText: '例如：打开文档写 3 行要点',
                ),
                const SizedBox(height: AppSpacing.md),
                _label(context, '即时庆祝'),
                AppTextField(
                  controller: _celebration,
                  hintText: '握拳 / 默念短句 / 微笑',
                ),
                const SizedBox(height: AppSpacing.md),
                _label(context, '锚点时段'),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final AnchorPeriod period in AnchorPeriod.values)
                      AppChip(
                        label: period.label,
                        dense: true,
                        filled: _period == period,
                        color: palette.accent,
                        onTap: () => setState(() => _period = period),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(context, '5 维阻力检查（勾选后先降阻，再谈坚持）'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _frictionChip(context, '时间', _frictions.time, (v) {
                      setState(() => _frictions = _frictions.copyWith(time: v));
                    }),
                    _frictionChip(context, '金钱', _frictions.money, (v) {
                      setState(() => _frictions = _frictions.copyWith(money: v));
                    }),
                    _frictionChip(context, '体力', _frictions.energy, (v) {
                      setState(() => _frictions = _frictions.copyWith(energy: v));
                    }),
                    _frictionChip(context, '脑力', _frictions.brain, (v) {
                      setState(() => _frictions = _frictions.copyWith(brain: v));
                    }),
                    _frictionChip(context, '日程习惯', _frictions.routine, (v) {
                      setState(() => _frictions = _frictions.copyWith(routine: v));
                    }),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _frictionNote,
                  dense: true,
                  hintText: '降阻准备：提前把笔记本摊在桌上…',
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(context, '行为集群与焦点地图'),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _candidateInput,
                        dense: true,
                        hintText: '输入候选行为，回车加入',
                        onSubmitted: (_) => _addCandidate(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppGhostButton(
                      label: '加入',
                      icon: Icons.add_rounded,
                      dense: true,
                      onPressed: _addCandidate,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 200,
                  child: _FocusMap(candidates: candidates),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '点击节点确认是否放入焦点地图；左上为「高影响 · 易起步」黄金行为区。',
                  style: context.texts.labelSmall,
                ),
                if (candidates.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final BehaviorCandidate candidate in candidates)
                        AppChip(
                          label: candidate.title,
                          dense: true,
                          filled: candidate.isSelected,
                          color: candidate.isGolden
                              ? palette.success
                              : palette.accent,
                          onTap: () async {
                            await context
                                .read<BehaviorCandidateRepository>()
                                .save(
                                  candidate.copyWith(
                                    isSelected: !candidate.isSelected,
                                  ),
                                );
                            if (candidate.isSelected) return;
                            _tiny.text = candidate.title;
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: palette.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        actionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall,
                      ),
                    ),
                    AppGhostButton(
                      label: '更换',
                      dense: true,
                      onPressed: () => _pickAction(actions),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      actions: <Widget>[
        if (_isEditing)
          AppGhostButton(
            label: '停用',
            tone: palette.danger,
            onPressed: () async {
              await context.read<FoggHabitRepository>().save(
                    widget.habit!.copyWith(isActive: false),
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            },
          ),
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          label: _isEditing ? '保存配方' : '创建习惯',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _pickAction(List<ActionItem> actions) async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppPalette palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: palette.border),
          ),
          title: Text('关联任务（可选）', style: dialogContext.texts.titleLarge),
          content: SizedBox(
            width: 420,
            height: MediaQuery.sizeOf(dialogContext).height * 0.45,
            child: ListView(
              children: <Widget>[
                ListTile(
                  title: Text('不关联任务', style: dialogContext.texts.bodyMedium),
                  onTap: () => Navigator.of(dialogContext).pop(''),
                ),
                for (final ActionItem action in actions)
                  ListTile(
                    title: Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dialogContext.texts.bodyMedium,
                    ),
                    onTap: () => Navigator.of(dialogContext).pop(action.id),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            AppGhostButton(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _actionItemId = picked.isEmpty ? null : picked);
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: context.texts.labelMedium),
    );
  }

  Widget _frictionChip(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final AppPalette palette = context.palette;
    return AppChip(
      label: label,
      dense: true,
      filled: value,
      color: value ? palette.warning : palette.textSecondary,
      onTap: () => onChanged(!value),
    );
  }
}

/// 简化的四象限焦点地图：横轴难度（左易右难），纵轴影响力（上高下低）。
class _FocusMap extends StatelessWidget {
  const _FocusMap({required this.candidates});

  final List<BehaviorCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceMuted.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.hairline),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _QuadrantPainter(color: palette.hairline),
                ),
              ),
              Positioned(
                left: 6,
                top: 4,
                child: Text(
                  '黄金区',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: Text(
                  '低影响 · 难做',
                  style: context.texts.labelSmall,
                ),
              ),
              for (final BehaviorCandidate candidate in candidates)
                Positioned(
                  left: ((candidate.effort - 1) / 4) * (width - 96) + 2,
                  top: (1 - (candidate.impact - 1) / 4) * (height - 26) + 2,
                  child: Opacity(
                    opacity: candidate.isSelected ? 1 : 0.55,
                    child: GestureDetector(
                      onTap: () async {
                        await context
                            .read<BehaviorCandidateRepository>()
                            .save(
                              candidate.copyWith(
                                isSelected: !candidate.isSelected,
                              ),
                            );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        constraints: const BoxConstraints(maxWidth: 92),
                        decoration: BoxDecoration(
                          color: candidate.isGolden
                              ? palette.success.withValues(alpha: 0.16)
                              : palette.surface,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: candidate.isSelected
                                ? (candidate.isGolden
                                    ? palette.success
                                    : palette.accent)
                                : palette.border,
                          ),
                        ),
                        child: Text(
                          candidate.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: candidate.isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuadrantPainter extends CustomPainter {
  const _QuadrantPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QuadrantPainter oldDelegate) =>
      oldDelegate.color != color;
}