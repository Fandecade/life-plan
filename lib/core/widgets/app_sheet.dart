import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/ui_style.dart';
import 'app_button.dart';

/// 移动端断点，与 AppShell 保持一致。
const double kAppSheetMobileBreakpoint = 920;

bool appSheetIsMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kAppSheetMobileBreakpoint;

/// 统一的自适应子窗口：
/// - 手机 / 平板竖屏：从底部滑入，默认占约 68% 屏高；
/// - 桌面：居中玻璃对话框，宽 620。
///
/// 所有模块的新建 / 编辑 / 选择 / 确认弹层都应走这里，保证主题一致。
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? barrierColor,
}) {
  final AppPalette palette = context.palette;
  if (appSheetIsMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor ?? palette.scrim,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor ?? palette.scrim,
    builder: (BuildContext dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: builder(dialogContext),
    ),
  );
}

/// 子窗口的内容外壳：标题 + 可滚动内容 + 底部动作区。
///
/// 手机端顶部有拖拽把手与 28 圆角；桌面端为居中玻璃卡片。
class AppSheetContent extends StatelessWidget {
  const AppSheetContent({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const <Widget>[],
    this.heightFactor = 0.68,
    this.maxWidth = 620,
    this.titleTrailing,
    this.showClose = true,
    this.contentPadding,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  /// 手机端高度占比；传 null 表示随内容自适应（适合确认类）。
  final double? heightFactor;
  final double maxWidth;
  final Widget? titleTrailing;
  final bool showClose;
  final EdgeInsetsGeometry? contentPadding;

  /// 内容是否由外壳统一包裹滚动。内容内部自带滚动时应传 false。
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool mobile = appSheetIsMobile(context);
    final bool glass =
        palette.style == AppUiStyle.refresh && palette.glassEnabled;
    final Size size = MediaQuery.sizeOf(context);

    final EdgeInsets resolvedPadding = contentPadding is EdgeInsets
        ? contentPadding! as EdgeInsets
        : const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.md,
          );

    final Widget body = scrollable
        ? SingleChildScrollView(padding: resolvedPadding, child: child)
        : Padding(padding: resolvedPadding, child: child);

    final BorderRadius radius = mobile
        ? const BorderRadius.vertical(top: Radius.circular(28))
        : BorderRadius.circular(28);

    final Widget bodyRegion = heightFactor == null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.5),
            child: body,
          )
        : Flexible(child: body);

    final Widget card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (mobile) _DragHandle(palette: palette),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            mobile ? AppSpacing.xxs : AppSpacing.lg,
            AppSpacing.sm,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(title, style: context.texts.titleLarge)),
                  ?titleTrailing,
                  if (showClose)
                    AppIconButton(
                      icon: Icons.close_rounded,
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 40),
                  child: Text(subtitle!, style: context.texts.bodySmall),
                ),
            ],
          ),
        ),
        bodyRegion,
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ),
          ),
      ],
    );

    final Widget cardSurface = Material(
      color: glass ? palette.glass : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: glass ? palette.glassBorder : palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: card,
    );

    final Widget surface = mobile
        ? cardSurface
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: cardSurface,
          );

    final Widget visual = glass && palette.glassBlur > 0
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: palette.glassBlur,
                sigmaY: palette.glassBlur,
              ),
              child: surface,
            ),
          )
        : surface;

    if (mobile) {
      final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
      final double available = (size.height - keyboard)
          .clamp(size.height * 0.35, size.height)
          .toDouble();
      final Widget content = heightFactor == null
          ? SafeArea(top: false, child: visual)
          : SizedBox(
              height: available * heightFactor!,
              child: SafeArea(top: false, child: visual),
            );
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: content,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: size.height * 0.84,
      ),
      child: visual,
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: 2),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: palette.textTertiary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
