import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/action_line.dart';
import '../../core/services/habit_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_chip.dart';

/// 行动线诊断与配方推演视图（多习惯散点 + 单习惯参数调节）。
///
/// 返回应用后的配方版本；用户取消时返回 null。
Future<HabitRecipeVersion?> showHabitActionLineDialog(
  BuildContext context, {
  required FoggHabit habit,
  HabitRecipeVersion? compareVersion,
}) {
  return showAppSheet<HabitRecipeVersion>(
    context,
    builder: (BuildContext sheetContext) => AppSheetContent(
      title: '行动线诊断与推演',
      subtitle: 'B = M × A × P · 滑动调参并生成新配方',
      heightFactor: 0.9,
      maxWidth: 900,
      scrollable: false,
      child: HabitActionLineView(
        habit: habit,
        compareVersion: compareVersion,
        padding: EdgeInsets.zero,
        onApplied: (HabitRecipeVersion version) =>
            Navigator.of(sheetContext).pop(version),
      ),
    ),
  );
}

/// 行动线诊断视图：弹窗与「行动线诊断」标签页共用。
class HabitActionLineView extends StatefulWidget {
  const HabitActionLineView({
    super.key,
    required this.habit,
    this.compareVersion,
    this.onApplied,
    this.onClose,
    this.scrollable = true,
    this.padding = EdgeInsets.zero,
  });

  final FoggHabit habit;
  final HabitRecipeVersion? compareVersion;
  final ValueChanged<HabitRecipeVersion>? onApplied;
  final VoidCallback? onClose;

  /// 弹窗内需要内部滚动；嵌入页面时交给外层 ListView。
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  State<HabitActionLineView> createState() => _HabitActionLineViewState();
}

class _HabitActionLineViewState extends State<HabitActionLineView> {
  late final HabitService _service;
  late String _selectedId;
  ActionLineModel _line = const ActionLineModel();
  double _ability = 5;
  double _motivation = 5;
  bool _applying = false;
  bool _chartDragging = false;

  String _cacheSignature = '';
  Map<String, ActionPoint> _currentPoints = <String, ActionPoint>{};

  @override
  void initState() {
    super.initState();
    _service = context.read<HabitService>();
    _selectedId = widget.habit.id;
    final ActionPoint point = _service.currentActionPoint(widget.habit);
    _ability = point.ability;
    _motivation = point.motivation;
  }

  List<FoggHabit> _visibleHabits() {
    final List<FoggHabit> all = context.watch<FoggHabitRepository>().all;
    return all
        .where(
          (FoggHabit habit) =>
              habit.isActive ||
              habit.id == widget.habit.id ||
              habit.id == _selectedId,
        )
        .toList(growable: false);
  }

  void _ensurePoints(List<FoggHabit> habits) {
    final String signature = habits
        .map((FoggHabit habit) => habit.id)
        .join('|');
    if (signature == _cacheSignature) return;
    _cacheSignature = signature;
    _currentPoints = <String, ActionPoint>{
      for (final FoggHabit habit in habits)
        habit.id: _service.currentActionPoint(habit),
    };
  }

  FoggHabit _selected(List<FoggHabit> habits) {
    for (final FoggHabit habit in habits) {
      if (habit.id == _selectedId) return habit;
    }
    return habits.isEmpty ? widget.habit : habits.first;
  }

  ActionPoint _currentOf(FoggHabit habit) =>
      _currentPoints[habit.id] ?? _service.currentActionPoint(habit);

  ActionPoint get _preview => ActionPoint(_ability, _motivation);

  void _select(FoggHabit habit) {
    final ActionPoint point = _currentOf(habit);
    setState(() {
      _selectedId = habit.id;
      _ability = point.ability;
      _motivation = point.motivation;
    });
  }

  Future<void> _apply(FoggHabit habit) async {
    if (_applying) return;
    setState(() => _applying = true);
    final HabitRecipeVersion version = await _service.applyActionLinePlan(
      habit,
      _preview,
    );
    if (!mounted) return;
    widget.onApplied?.call(version);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<FoggHabit> habits = _visibleHabits();
    _ensurePoints(habits);
    final FoggHabit selected = _selected(habits);
    final bool above = _line.isAbove(_preview);
    final int done = _service.completedInLastDays(selected, 7);
    final int versionCount = context
        .read<HabitRecipeVersionRepository>()
        .forHabit(selected.id)
        .length;
    final int versionLabel = versionCount < 1 ? 1 : versionCount;

    final HabitRecipeVersion? compare = widget.compareVersion;
    ActionPoint? historical;
    int? historyRevision;
    if (compare != null && compare.habitId == selected.id) {
      historical = habitActionPoint(
        selected.copyWith(
          anchorPrompt: compare.anchorPrompt,
          tinyBehavior: compare.tinyBehavior,
          celebration: compare.celebration,
          frictions: FrictionProfile.decode(compare.frictionsJson),
        ),
        compare.completedIn7Days,
      );
      historyRevision = compare.revision;
    }

    final List<_ChartPoint> points = <_ChartPoint>[
      for (final FoggHabit habit in habits)
        _ChartPoint(
          habit: habit,
          ability: habit.id == selected.id
              ? _ability
              : _currentOf(habit).ability,
          motivation: habit.id == selected.id
              ? _motivation
              : _currentOf(habit).motivation,
          selected: habit.id == selected.id,
        ),
    ];

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('行动线诊断与推演', style: context.texts.titleLarge)),
            Text(
              'B = M × A × P',
              style: context.texts.labelSmall?.copyWith(color: palette.accent),
            ),
            if (widget.onClose != null) ...<Widget>[
              const SizedBox(width: 4),
              AppIconButton(
                icon: Icons.close_rounded,
                iconSize: 16,
                size: 26,
                tooltip: '关闭',
                onPressed: widget.onClose,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '行为发生公式：B = M（动机）× A（能力）× P（提示）。'
          '滑动调节习惯参数或行动线门槛。',
          style: context.texts.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _chartPanel(context, palette, points, historical, historyRevision),
        const SizedBox(height: AppSpacing.md),
        _diagnosisPanel(
          context,
          palette,
          habits,
          selected,
          above,
          done,
          versionLabel,
          historical,
          historyRevision,
        ),
      ],
    );

    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.scrollable)
            Flexible(
              child: SingleChildScrollView(
                physics: _chartDragging
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: content,
              ),
            )
          else
            content,
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (widget.onClose != null) ...<Widget>[
                AppGhostButton(label: '取消', onPressed: widget.onClose),
                const SizedBox(width: 8),
              ],
              AppPrimaryButton(
                label: _applying ? '生成中…' : '应用并生成新配方',
                onPressed: _applying ? null : () => _apply(selected),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartPanel(
    BuildContext context,
    AppPalette palette,
    List<_ChartPoint> points,
    ActionPoint? historical,
    int? historyRevision,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 240,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 16,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text('动机（低 → 高）', style: context.texts.labelSmall),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final Size size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final Rect plot = Rect.fromLTRB(
                            10,
                            10,
                            size.width - 10,
                            size.height - 10,
                          );
                          return Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (PointerDownEvent event) =>
                                _handlePointerDown(
                                  event.localPosition,
                                  plot,
                                  points,
                                ),
                            onPointerMove: (PointerMoveEvent event) {
                              if (!_chartDragging) return;
                              _setPreview(event.localPosition, plot);
                            },
                            onPointerUp: (_) {
                              if (_chartDragging) {
                                setState(() => _chartDragging = false);
                              }
                            },
                            onPointerCancel: (_) {
                              if (_chartDragging) {
                                setState(() => _chartDragging = false);
                              }
                            },
                            child: CustomPaint(
                              key: const ValueKey<String>('action-line-canvas'),
                              painter: _ActionLineChartPainter(
                                plot: plot,
                                line: _line,
                                points: points,
                                historical: historical,
                                historicalLabel: historyRevision == null
                                    ? null
                                    : 'v$historyRevision',
                                accent: palette.accent,
                                success: palette.success,
                                danger: palette.danger,
                                axis: palette.border,
                                surface: palette.surface,
                                muted: palette.textTertiary,
                                labelStyle:
                                    context.texts.labelSmall ??
                                    const TextStyle(),
                                regionStyle:
                                    context.texts.labelSmall?.copyWith(
                                      fontSize: 9,
                                    ) ??
                                    const TextStyle(fontSize: 9),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          );
                        },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('能力（极难 → 极易）', style: context.texts.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diagnosisPanel(
    BuildContext context,
    AppPalette palette,
    List<FoggHabit> habits,
    FoggHabit selected,
    bool above,
    int done,
    int versionLabel,
    ActionPoint? historical,
    int? historyRevision,
  ) {
    final Color tone = above ? palette.success : palette.danger;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('选择诊断习惯', style: context.texts.titleSmall),
              const SizedBox(width: 8),
              Text('点击节点或下方标签进行配方调整', style: context.texts.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final FoggHabit habit in habits)
                AppChip(
                  label: habit.tinyBehavior,
                  dense: true,
                  filled: habit.id == selected.id,
                  color: habit.id == selected.id
                      ? palette.accent
                      : palette.textSecondary,
                  onTap: () => _select(habit),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        selected.tinyBehavior,
                        style: context.texts.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppChip(
                      label: 'v$versionLabel',
                      dense: true,
                      color: palette.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    AppChip(
                      label: above ? '行动线之上（易触发）' : '行动线下方（困难卡阻）',
                      dense: true,
                      filled: true,
                      color: tone,
                    ),
                  ],
                ),
                if (historical != null && historyRevision != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      AppChip(
                        label:
                            '历史 v$historyRevision：'
                            '${_line.isAbove(historical) ? '线上' : '线下'}',
                        dense: true,
                        color: palette.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '灰色 = 历史 v$historyRevision',
                        style: context.texts.labelSmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(_formula(selected), style: context.texts.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  _diagnosis(selected, done),
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text('COM-B', style: context.texts.labelSmall),
                    const SizedBox(width: 6),
                    for (final String dimension in const <String>[
                      '能力',
                      '机会',
                      '动机',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: AppChip(
                          label: dimension,
                          dense: true,
                          filled: _combFocus(selected) == dimension,
                          color: palette.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_combHint(selected), style: context.texts.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                _sliders(context, palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _combFocus(FoggHabit habit) {
    if (habit.frictions.energy || habit.frictions.brain) return '能力';
    final ActionPoint point = _preview;
    final double gap =
        _line.requiredMotivation(point.ability) - point.motivation;
    if (!_line.isAbove(point) && gap > 0.6) return '动机';
    return '机会';
  }

  String _combHint(FoggHabit habit) {
    switch (_combFocus(habit)) {
      case '能力':
        return 'COM-B · 能力优先：先把微行为缩小，或补一次短训练。';
      case '动机':
        return 'COM-B · 动机优先：明确意义、强化即时庆祝，或换更稳的锚点。';
      default:
        return 'COM-B · 机会优先：调整环境、时间窗与锚点提示。';
    }
  }

  Widget _sliders(BuildContext context, AppPalette palette) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _slider(
                context,
                palette,
                label: '能力值（降低微行为难度）',
                value: _ability,
                min: 0,
                max: 10,
                steps: 20,
                onChanged: (double value) => setState(() => _ability = value),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _slider(
                context,
                palette,
                label: '动机值（强化渴望 / 锚点）',
                value: _motivation,
                min: 0,
                max: 10,
                steps: 20,
                onChanged: (double value) =>
                    setState(() => _motivation = value),
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _slider(
                context,
                palette,
                label: '行动线门槛（环境阻力）',
                value: _line.threshold,
                min: 1,
                max: 8,
                steps: 14,
                onChanged: (double value) => setState(() {
                  _line = ActionLineModel(
                    threshold: value,
                    curvature: _line.curvature,
                  );
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _slider(
                context,
                palette,
                label: '行动线弯曲度（动机敏锐度）',
                value: _line.curvature,
                min: 0.6,
                max: 3,
                steps: 12,
                onChanged: (double value) => setState(() {
                  _line = ActionLineModel(
                    threshold: _line.threshold,
                    curvature: value,
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _slider(
    BuildContext context,
    AppPalette palette, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int steps,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: context.texts.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value.toStringAsFixed(1),
              style: context.texts.labelSmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 26,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: palette.accent.withValues(alpha: 0.7),
              inactiveTrackColor: palette.surfaceMuted,
              thumbColor: palette.accent,
              overlayColor: palette.accent.withValues(alpha: 0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: steps,
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _handlePointerDown(Offset local, Rect plot, List<_ChartPoint> points) {
    for (final _ChartPoint point in points) {
      final Offset offset = _offsetOf(plot, point.ability, point.motivation);
      if ((offset - local).distance >= 20) continue;

      final ActionPoint current = _currentOf(point.habit);
      setState(() {
        _selectedId = point.habit.id;
        if (!point.selected) {
          _ability = current.ability;
          _motivation = current.motivation;
        }
        _chartDragging = true;
      });
      return;
    }
    if (_chartDragging) setState(() => _chartDragging = false);
  }

  void _setPreview(Offset local, Rect plot) {
    setState(() {
      _ability = ((local.dx - plot.left) / plot.width * 10).clamp(0, 10);
      _motivation = ((plot.bottom - local.dy) / plot.height * 10).clamp(0, 10);
    });
  }

  String _formula(FoggHabit habit) {
    final String anchor = habit.anchorPrompt.isEmpty
        ? '日常锚点'
        : habit.anchorPrompt;
    final String celebration = habit.celebration.isEmpty
        ? '给自己一个即时庆祝'
        : habit.celebration;
    return '在「$anchor」之后，我将「${habit.tinyBehavior}」。'
        '随后，我「$celebration」！';
  }

  String _diagnosis(FoggHabit habit, int done) {
    final ActionPoint point = _preview;
    if (_line.isAbove(point)) {
      return done >= 4
          ? '近 7 天完成 $done/7 次，落点在行动线上方，节奏稳定，可保持当前配方。'
          : '近 7 天完成 $done/7 次，落点已在线上方，先保持小动作让习惯固化。';
    }
    final double gap =
        _line.requiredMotivation(point.ability) - point.motivation;
    if (habit.frictions.count >= 2) {
      return '近 7 天仅完成 $done/7 次。卡阻诊断：能力阻力'
          '（${habit.frictions.labels.join(' / ')}）。'
          '福格配方建议：优先拆解微行为「${habit.tinyBehavior}」，'
          '把它降到 15 秒可启动的程度。';
    }
    return '近 7 天仅完成 $done/7 次。卡阻诊断：动机欠缺 '
        '${gap.toStringAsFixed(1)} 分。'
        '福格配方建议：不要强行提升动机，先缩小微行为或换更稳的锚点。';
  }
}

class _ChartPoint {
  const _ChartPoint({
    required this.habit,
    required this.ability,
    required this.motivation,
    required this.selected,
  });

  final FoggHabit habit;
  final double ability;
  final double motivation;
  final bool selected;
}

Offset _offsetOf(Rect plot, double ability, double motivation) => Offset(
  plot.left + ability / 10 * plot.width,
  plot.bottom - motivation / 10 * plot.height,
);

class _ActionLineChartPainter extends CustomPainter {
  const _ActionLineChartPainter({
    required this.plot,
    required this.line,
    required this.points,
    required this.historical,
    required this.historicalLabel,
    required this.accent,
    required this.success,
    required this.danger,
    required this.axis,
    required this.surface,
    required this.muted,
    required this.labelStyle,
    required this.regionStyle,
  });

  final Rect plot;
  final ActionLineModel line;
  final List<_ChartPoint> points;
  final ActionPoint? historical;
  final String? historicalLabel;
  final Color accent;
  final Color success;
  final Color danger;
  final Color axis;
  final Color surface;
  final Color muted;
  final TextStyle labelStyle;
  final TextStyle regionStyle;

  Offset _offset(ActionPoint point) =>
      _offsetOf(plot, point.ability, point.motivation);

  @override
  void paint(Canvas canvas, Size size) {
    // 分区：线下（卡阻）→ 浅粉，线上（易触发）→ 浅绿
    canvas.drawRect(plot, Paint()..color = danger.withValues(alpha: 0.045));

    final Path curve = Path();
    for (int i = 0; i <= 48; i++) {
      final double ability = i / 48 * 10;
      final Offset point = _offset(
        ActionPoint(ability, line.requiredMotivation(ability)),
      );
      if (i == 0) {
        curve.moveTo(point.dx, point.dy);
      } else {
        curve.lineTo(point.dx, point.dy);
      }
    }
    final Path aboveArea = Path.from(curve)
      ..lineTo(plot.right, plot.top)
      ..lineTo(plot.left, plot.top)
      ..close();
    canvas.drawPath(
      aboveArea,
      Paint()..color = success.withValues(alpha: 0.06),
    );

    // 轴与刻度
    final Paint axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );
    for (int value = 0; value <= 10; value += 2) {
      final double x = plot.left + value / 10 * plot.width;
      canvas.drawLine(
        Offset(x, plot.bottom),
        Offset(x, plot.bottom + 3),
        axisPaint,
      );
      final double y = plot.bottom - value / 10 * plot.height;
      canvas.drawLine(
        Offset(plot.left - 3, y),
        Offset(plot.left, y),
        axisPaint,
      );
    }

    // 行动线
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent.withValues(alpha: 0.8)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );

    _text(
      canvas,
      '易触发区',
      Offset(plot.left + 8, plot.top + 6),
      regionStyle.copyWith(color: success.withValues(alpha: 0.85)),
    );
    _text(
      canvas,
      '卡阻区',
      Offset(plot.right - 40, plot.bottom - 18),
      regionStyle.copyWith(color: danger.withValues(alpha: 0.8)),
    );

    // 历史点
    final ActionPoint? historic = historical;
    if (historic != null) {
      final Offset point = _offset(historic);
      canvas.drawCircle(
        point,
        5,
        Paint()..color = muted.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = muted.withValues(alpha: 0.85)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
      if (historicalLabel != null) {
        _pointLabel(
          canvas,
          historicalLabel!,
          point,
          muted.withValues(alpha: 0.9),
          false,
        );
      }
    }

    // 习惯点与标签
    for (final _ChartPoint point in points) {
      final Offset offset = _offsetOf(plot, point.ability, point.motivation);
      final bool above = line.isAbove(
        ActionPoint(point.ability, point.motivation),
      );
      final Color tone = point.selected
          ? (above ? success : danger)
          : accent.withValues(alpha: 0.5);
      canvas.drawCircle(
        offset,
        point.selected ? 6 : 4.5,
        Paint()..color = tone,
      );
      if (point.selected) {
        canvas.drawCircle(
          offset,
          6,
          Paint()
            ..color = surface
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke,
        );
      }
      _pointLabel(
        canvas,
        point.habit.tinyBehavior,
        offset,
        point.selected ? tone : muted,
        point.selected,
      );
    }
  }

  void _pointLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    bool bold,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 96);

    double left = offset.dx - painter.width / 2;
    left = left.clamp(plot.left + 2, plot.right - painter.width - 2);
    double top = offset.dy - painter.height - 10;
    if (top < plot.top + 2) {
      top = offset.dy + 10;
    }
    painter.paint(canvas, Offset(left, top));
  }

  void _text(Canvas canvas, String text, Offset offset, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ActionLineChartPainter oldDelegate) =>
      oldDelegate.plot != plot ||
      oldDelegate.line.threshold != line.threshold ||
      oldDelegate.line.curvature != line.curvature ||
      oldDelegate.points != points ||
      oldDelegate.historical?.ability != historical?.ability ||
      oldDelegate.historical?.motivation != historical?.motivation ||
      oldDelegate.accent != accent;
}
