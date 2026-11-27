import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/widgets/app_card.dart';

/// 主页图表卡片容器。
class HomeChartCard extends StatelessWidget {
  const HomeChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.padding = AppSpacing.lg,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(title, style: context.texts.titleSmall),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: context.texts.labelSmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// 近 14 天：任务柱 + 学习折线。
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 132,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              points: points,
              barColor: palette.accent,
              lineColor: palette.accentStrong,
              gridColor: palette.hairline,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            _LegendDot(color: palette.accent, label: '完成任务'),
            const SizedBox(width: AppSpacing.md),
            _LegendLine(color: palette.accentStrong, label: '学习分钟'),
            const Spacer(),
            Text('近 14 天', style: context.texts.labelSmall),
          ],
        ),
      ],
    );
  }
}

/// 近四周：任务与学习双柱对比。
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.points});

  final List<WeeklyPoint> points;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 132,
          width: double.infinity,
          child: CustomPaint(
            painter: _WeeklyPainter(
              points: points,
              taskColor: palette.accent,
              learningColor: palette.accentStrong.withValues(alpha: 0.45),
              gridColor: palette.hairline,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (int i = 0; i < points.length; i++)
              Expanded(
                child: Text(
                  _weekLabel(points[i].start, i, points.length),
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            _LegendDot(color: palette.accent, label: '任务'),
            const SizedBox(width: AppSpacing.md),
            _LegendDot(
              color: palette.accentStrong.withValues(alpha: 0.45),
              label: '学习',
            ),
          ],
        ),
      ],
    );
  }

  String _weekLabel(DateTime start, int index, int total) {
    if (index == total - 1) return '本周';
    return '${start.month}.${start.day}';
  }
}

/// 近 30 天能力投入环形图。
class CapabilityRing extends StatelessWidget {
  const CapabilityRing({super.key, required this.shares});

  final List<CapabilityShare> shares;

  static const List<Color> _tones = <Color>[
    Color(0xFF7E9A6B),
    Color(0xFF7191AE),
    Color(0xFF8E85B8),
    Color(0xFFC3A26B),
    Color(0xFF9B7E73),
    Color(0xFF8C949E),
  ];

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int total = shares.fold<int>(
      0,
      (int sum, CapabilityShare share) => sum + share.count,
    );
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('近 30 天还没有完成记录。', style: context.texts.bodySmall),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _RingPainter(
              shares: shares,
              colors: <Color>[
                for (int i = 0; i < shares.length; i++)
                  _tones[i % _tones.length],
              ],
              trackColor: palette.surfaceMuted,
              centerText: '$total',
              centerColor: palette.textPrimary,
              labelColor: palette.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < shares.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _tones[i % _tones.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          shares[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${(shares[i].count / total * 100).round()}%',
                        style: context.texts.labelSmall?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: context.texts.labelSmall),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(width: 14, height: 2, color: color),
        const SizedBox(width: 5),
        Text(label, style: context.texts.labelSmall),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
  });

  final List<DailyPoint> points;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final int maxTasks = math.max(
      1,
      points.fold<int>(0, (int sum, DailyPoint p) => math.max(sum, p.tasks)),
    );
    final int maxLearning = math.max(
      1,
      points.fold<int>(
        0,
        (int sum, DailyPoint p) => math.max(sum, p.learningMinutes),
      ),
    );

    final double slot = size.width / points.length;
    final double barWidth = math.max(3, slot * 0.42);
    final Paint bar = Paint()..color = barColor;
    final Paint line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final Path path = Path();
    final List<Offset> linePoints = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final DailyPoint point = points[i];
      final double centerX = slot * i + slot / 2;
      final double barHeight =
          size.height * (point.tasks / maxTasks) * 0.82;
      if (point.tasks > 0) {
        final RRect rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - barWidth / 2,
            size.height - barHeight,
            barWidth,
            barHeight,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, bar);
      }
      final double lineY = size.height -
          size.height * (point.learningMinutes / maxLearning) * 0.82;
      linePoints.add(Offset(centerX, lineY));
    }

    for (int i = 0; i < linePoints.length; i++) {
      if (i == 0) {
        path.moveTo(linePoints[i].dx, linePoints[i].dy);
      } else {
        final Offset previous = linePoints[i - 1];
        final Offset current = linePoints[i];
        final double midX = (previous.dx + current.dx) / 2;
        path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
      }
    }
    canvas.drawPath(path, line);
    final Paint dot = Paint()..color = lineColor;
    for (final Offset point in linePoints) {
      canvas.drawCircle(point, 2.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}

class _WeeklyPainter extends CustomPainter {
  _WeeklyPainter({
    required this.points,
    required this.taskColor,
    required this.learningColor,
    required this.gridColor,
  });

  final List<WeeklyPoint> points;
  final Color taskColor;
  final Color learningColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final int maxValue = math.max(
      1,
      points.fold<int>(
        0,
        (int sum, WeeklyPoint p) =>
            math.max(sum, math.max(p.tasks, p.learningMinutes)),
      ),
    );
    final double slot = size.width / points.length;
    final double barWidth = math.max(5, slot * 0.22);
    final Paint taskPaint = Paint()..color = taskColor;
    final Paint learningPaint = Paint()..color = learningColor;

    for (int i = 0; i < points.length; i++) {
      final WeeklyPoint point = points[i];
      final double centerX = slot * i + slot / 2;
      final double taskHeight =
          size.height * (point.tasks / maxValue) * 0.84;
      final double learningHeight =
          size.height * (point.learningMinutes / maxValue) * 0.84;
      if (point.tasks > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX - barWidth - 1,
              size.height - taskHeight,
              barWidth,
              taskHeight,
            ),
            const Radius.circular(3),
          ),
          taskPaint,
        );
      }
      if (point.learningMinutes > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX + 1,
              size.height - learningHeight,
              barWidth,
              learningHeight,
            ),
            const Radius.circular(3),
          ),
          learningPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyPainter oldDelegate) => true;
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.shares,
    required this.colors,
    required this.trackColor,
    required this.centerText,
    required this.centerColor,
    required this.labelColor,
  });

  final List<CapabilityShare> shares;
  final List<Color> colors;
  final Color trackColor;
  final String centerText;
  final Color centerColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final int total = shares.fold<int>(
      0,
      (int sum, CapabilityShare share) => sum + share.count,
    );
    if (total == 0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 8;
    final double stroke = math.max(10, radius * 0.28);
    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    double start = -math.pi / 2;
    for (int i = 0; i < shares.length; i++) {
      final double sweep = 2 * math.pi * shares[i].count / total;
      final Paint paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.max(sweep - 0.02, 0.001),
        false,
        paint,
      );
      start += sweep;
    }

    final TextPainter totalPainter = TextPainter(
      text: TextSpan(
        text: centerText,
        style: TextStyle(
          color: centerColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    totalPainter.paint(
      canvas,
      Offset(
        center.dx - totalPainter.width / 2,
        center.dy - totalPainter.height / 2 - 6,
      ),
    );

    final TextPainter labelPainter = TextPainter(
      text: TextSpan(
        text: '完成',
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + totalPainter.height / 2 - 4,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}