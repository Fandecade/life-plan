import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/database/repositories.dart';
import '../../core/models/models.dart';
import '../../core/services/action_line.dart';
import '../../core/services/habit_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';

/// 行动线诊断与配方推演视图。
///
/// 返回应用后的配方版本；用户取消时返回 null。
Future<HabitRecipeVersion?> showHabitActionLineDialog(
  BuildContext context, {
  required FoggHabit habit,
  HabitRecipeVersion? compareVersion,
}) {
  return showDialog<HabitRecipeVersion>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ActionLineDialog(habit: habit, compareVersion: compareVersion),
  );
}

class _ActionLineDialog extends StatefulWidget {
  const _ActionLineDialog({required this.habit, this.compareVersion});

  final FoggHabit habit;

  /// 从「配方调整记录」打开时，展示该历史版本的落点作对比。
  final HabitRecipeVersion? compareVersion;

  @override
  State<_ActionLineDialog> createState() => _ActionLineDialogState();
}

class _ActionLineDialogState extends State<_ActionLineDialog> {
  ActionLineModel _line = const ActionLineModel();
  late ActionPoint _current;
  late ActionPoint _preview;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final HabitService service = context.read<HabitService>();
    _current = service.currentActionPoint(widget.habit);
    _preview = _current;
  }

  bool get _above => _line.isAbove(_preview);

  void _nudgeRight() {
    setState(() {
      _preview = _preview
          .copyWith(ability: (_preview.ability + 2.5).clamp(0, 10));
    });
  }

  void _nudgeUp() {
    setState(() {
      _preview = _preview
          .copyWith(motivation: (_preview.motivation + 2).clamp(0, 10));
    });
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    final HabitService service = context.read<HabitService>();
    final HabitRecipeVersion version =
        await service.applyActionLinePlan(widget.habit, _preview);
    if (!mounted) return;
    Navigator.of(context).pop(version);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final HabitService service = context.read<HabitService>();
    final int done = service.completedInLastDays(widget.habit, 7);
    final int versionCount =
        context.read<HabitRecipeVersionRepository>().forHabit(widget.habit.id).length;
    final int versionLabel = versionCount < 1 ? 1 : versionCount;
    final HabitRecipeVersion? compare = widget.compareVersion;
    final ActionPoint? historical = compare == null
        ? null
        : habitActionPoint(
            widget.habit.copyWith(
              anchorPrompt: compare.anchorPrompt,
              tinyBehavior: compare.tinyBehavior,
              celebration: compare.celebration,
              frictions: FrictionProfile.decode(compare.frictionsJson),
            ),
            compare.completedIn7Days,
          );
    final String advice = actionLineAdvice(
      habit: widget.habit,
      point: _preview,
      line: _line,
      completedInLast7Days: done,
    );

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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.habit.tinyBehavior,
                  style: context.texts.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                label: 'v$versionLabel',
                dense: true,
                color: palette.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              AppChip(
                label: '当前落点：${_line.isAbove(_current) ? '行动线之上' : '行动线之下'}',
                dense: true,
                color: _line.isAbove(_current)
                    ? palette.success
                    : palette.warning,
              ),
              const SizedBox(width: 6),
              AppChip(
                label: '推演：${_above ? '会触发' : '仍会卡住'}',
                dense: true,
                filled: true,
                color: _above ? palette.success : palette.warning,
              ),
              if (historical != null) ...<Widget>[
                const SizedBox(width: 6),
                AppChip(
                  label: '历史 v${compare!.revision}：'
                      '${_line.isAbove(historical) ? '线上' : '线下'}',
                  dense: true,
                  color: palette.textTertiary,
                ),
              ],
              const SizedBox(width: 6),
              Text('近 7 天 $done 次', style: context.texts.labelSmall),
            ],
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
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _canvas(context, palette, historical),
            const SizedBox(height: 6),
            Text(
              historical == null
                  ? '实心 = 当前落点 · 空心 = 推演落点'
                  : '实心 = 当前 · 空心 = 推演 · 灰色 = 历史 v${compare!.revision}',
              style: context.texts.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(advice, style: context.texts.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            _slider(
              context,
              palette,
              label: '行动线门槛',
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
            _slider(
              context,
              palette,
              label: '曲线弧度',
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
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                AppGhostButton(
                  label: '缩小微行为（右移）',
                  icon: Icons.east_rounded,
                  dense: true,
                  onPressed: _nudgeRight,
                ),
                AppGhostButton(
                  label: '强化锚点 / 庆祝（上移）',
                  icon: Icons.north_rounded,
                  dense: true,
                  onPressed: _nudgeUp,
                ),
                AppGhostButton(
                  label: '复位推演',
                  icon: Icons.restart_alt_rounded,
                  dense: true,
                  onPressed: () => setState(() => _preview = _current),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      actions: <Widget>[
        AppGhostButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          label: _applying ? '生成中…' : '应用并生成新配方',
          onPressed: _applying ? null : _apply,
        ),
      ],
    );
  }

  Widget _canvas(
    BuildContext context,
    AppPalette palette,
    ActionPoint? historical,
  ) {
    return SizedBox(
      height: 236,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text('动机 低 → 高', style: context.texts.labelSmall),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final Size size =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      final Rect plot = Rect.fromLTRB(
                        8,
                        8,
                        size.width - 8,
                        size.height - 8,
                      );
                      return Container(
                        key: const ValueKey<String>('action-line-canvas'),
                        decoration: BoxDecoration(
                          color: palette.surfaceMuted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: palette.hairline),
                        ),
                        child: LayoutBuilder(
                          builder: (BuildContext _, BoxConstraints _) {
                            return Listener(
                              onPointerDown: (PointerDownEvent event) =>
                                  _setPreview(event.localPosition, plot),
                              onPointerMove: (PointerMoveEvent event) =>
                                  _setPreview(event.localPosition, plot),
                              child: Stack(
                                children: <Widget>[
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _ActionLinePainter(
                                        plot: plot,
                                        line: _line,
                                        current: _current,
                                        preview: _preview,
                                        accent: palette.accent,
                                        axis: palette.border,
                                        surface: palette.surface,
                                        historical: historical,
                                        muted: palette.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text('难做', style: context.texts.labelSmall),
                    const Spacer(),
                    Text('能力', style: context.texts.labelSmall),
                    const Spacer(),
                    Text('易做', style: context.texts.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setPreview(Offset local, Rect plot) {
    final ActionPoint point = ActionPoint(
      ((local.dx - plot.left) / plot.width * 10).clamp(0, 10),
      ((plot.bottom - local.dy) / plot.height * 10).clamp(0, 10),
    );
    setState(() => _preview = point);
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
    return Row(
      children: <Widget>[
        SizedBox(
          width: 76,
          child: Text(label, style: context.texts.labelSmall),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: palette.accent.withValues(alpha: 0.7),
              inactiveTrackColor: palette.surfaceMuted,
              thumbColor: palette.accent,
              overlayColor: palette.accent.withValues(alpha: 0.08),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: steps,
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toStringAsFixed(1),
            style: context.texts.labelSmall?.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _ActionLinePainter extends CustomPainter {
  const _ActionLinePainter({
    required this.plot,
    required this.line,
    required this.current,
    required this.preview,
    required this.accent,
    required this.axis,
    required this.surface,
    required this.historical,
    required this.muted,
  });

  final Rect plot;
  final ActionLineModel line;
  final ActionPoint current;
  final ActionPoint preview;
  final Color accent;
  final Color axis;
  final Color surface;
  final ActionPoint? historical;
  final Color muted;

  Offset _offset(ActionPoint point) => Offset(
        plot.left + point.ability / 10 * plot.width,
        plot.bottom - point.motivation / 10 * plot.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final Paint axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.1;

    // L 型轴
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

    // 每 2 分一个刻度
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

    // 行动线与「会触发」区域
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
    final Path fill = Path.from(curve)
      ..lineTo(plot.right, plot.top)
      ..lineTo(plot.left, plot.top)
      ..close();
    canvas.drawPath(fill, Paint()..color = accent.withValues(alpha: 0.07));
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent.withValues(alpha: 0.65)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // 当前点：实心
    final Offset currentOffset = _offset(current);
    canvas.drawCircle(
      currentOffset,
      5,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      currentOffset,
      5,
      Paint()
        ..color = surface
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // 推演点：空心，并用虚线连到当前点
    final Offset previewOffset = _offset(preview);
    final double distance = (previewOffset - currentOffset).distance;
    if (distance > 8) {
      _dashedLine(
        canvas,
        currentOffset,
        previewOffset,
        Paint()
          ..color = accent.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
    }
    canvas.drawCircle(
      previewOffset,
      6,
      Paint()..color = accent.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      previewOffset,
      6,
      Paint()
        ..color = accent
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // 历史版本落点：灰色，供 v1 → v2 对比
    final ActionPoint? historic = historical;
    if (historic != null) {
      final Offset historicOffset = _offset(historic);
      _dashedLine(
        canvas,
        currentOffset,
        historicOffset,
        Paint()
          ..color = muted.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        historicOffset,
        5,
        Paint()..color = muted.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        historicOffset,
        5,
        Paint()
          ..color = muted.withValues(alpha: 0.8)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const double dash = 3;
    const double gap = 3;
    final double total = (to - from).distance;
    if (total == 0) return;
    final Offset unit = (to - from) / total;
    double travelled = 0;
    while (travelled < total) {
      final double end = (travelled + dash).clamp(0, total);
      canvas.drawLine(from + unit * travelled, from + unit * end, paint);
      travelled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ActionLinePainter oldDelegate) =>
      oldDelegate.plot != plot ||
      oldDelegate.line.threshold != line.threshold ||
      oldDelegate.line.curvature != line.curvature ||
      oldDelegate.current.ability != current.ability ||
      oldDelegate.current.motivation != current.motivation ||
      oldDelegate.preview.ability != preview.ability ||
      oldDelegate.preview.motivation != preview.motivation ||
      oldDelegate.historical?.ability != historical?.ability ||
      oldDelegate.historical?.motivation != historical?.motivation ||
      oldDelegate.accent != accent;
}