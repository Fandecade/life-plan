import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 新版背景：冷调底 + 三枚环境光斑；经典版原样返回。
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    if (!context.isModernStyle) return child;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: palette.background)),
        Positioned(
          top: -160,
          left: -120,
          width: 460,
          height: 460,
          child: _Blob(color: palette.blobA),
        ),
        Positioned(
          top: 80,
          right: -180,
          width: 520,
          height: 520,
          child: _Blob(color: palette.blobB),
        ),
        Positioned(
          bottom: -140,
          left: 60,
          width: 380,
          height: 380,
          child: _Blob(color: palette.blobC),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    if (color.a == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
