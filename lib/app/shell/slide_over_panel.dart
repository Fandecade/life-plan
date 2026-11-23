import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum PanelSide { right, bottom }

/// 通用滑出面板：桌面端从右侧滑出，移动端从底部滑出。
///
/// 不使用 Drawer，便于「任务池」与「详情抽屉」两个面板共存并按层级互斥。
class SlideOverPanel extends StatelessWidget {
  const SlideOverPanel({
    super.key,
    required this.open,
    required this.onClose,
    required this.child,
    this.side = PanelSide.right,
    this.width = 408,
    this.heightFraction = 0.9,
  });

  final bool open;
  final VoidCallback onClose;
  final Widget child;
  final PanelSide side;
  final double width;
  final double heightFraction;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Size size = MediaQuery.sizeOf(context);
    final bool horizontal = side == PanelSide.right;
    final double panelWidth = horizontal ? math.min(width, size.width) : size.width;
    final double panelHeight =
        horizontal ? size.height : size.height * heightFraction;
    final BorderRadius radius = horizontal
        ? BorderRadius.zero
        : const BorderRadius.vertical(top: Radius.circular(18));

    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: <Widget>[
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: open ? 1 : 0,
            child: GestureDetector(
              onTap: onClose,
              child: ColoredBox(color: palette.scrim, child: const SizedBox.expand()),
            ),
          ),
          Align(
            alignment: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: open
                  ? Offset.zero
                  : (horizontal ? const Offset(1, 0) : const Offset(0, 1)),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Container(
                width: panelWidth,
                height: panelHeight,
                decoration: horizontal
                    ? BoxDecoration(
                        color: palette.surface,
                        border: Border(left: BorderSide(color: palette.border)),
                      )
                    : BoxDecoration(
                        color: palette.surface,
                        borderRadius: radius,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                child: ClipRRect(borderRadius: radius, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}