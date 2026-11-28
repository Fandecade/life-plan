import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// 统一极简输入框：无标签、无浮字，仅 placeholder + 细边框。
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.textStyle,
    this.transparent = false,
    this.dense = false,
    this.focusNode,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextStyle? textStyle;
  final bool transparent;
  final bool dense;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _focused = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode == oldWidget.focusNode) return;
    _focusNode.removeListener(_handleFocus);
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool multiline = widget.maxLines > 1;
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      keyboardType:
          widget.keyboardType ??
          (multiline ? TextInputType.multiline : TextInputType.text),
      obscureText: widget.obscureText,
      style:
          widget.textStyle ??
          (multiline ? context.texts.bodyMedium : context.texts.bodyLarge),
      cursorWidth: 1.4,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: context.texts.bodyMedium?.copyWith(
          color: palette.textTertiary,
        ),
        isDense: true,
        filled: !widget.transparent,
        fillColor: widget.transparent
            ? Colors.transparent
            : palette.surfaceMuted,
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.dense ? 10 : 12,
          vertical: widget.dense ? 8 : (multiline ? 12 : 10),
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Icon(
                  widget.prefixIcon,
                  size: 15,
                  color: palette.textTertiary,
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.suffix,
        border: _border(
          palette,
          widget.transparent ? Colors.transparent : palette.hairline,
        ),
        enabledBorder: _border(
          palette,
          widget.transparent ? Colors.transparent : palette.hairline,
        ),
        focusedBorder: _border(palette, palette.accent.withValues(alpha: 0.55)),
        disabledBorder: _border(palette, palette.hairline),
      ),
    );
  }

  OutlineInputBorder _border(AppPalette palette, Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.dense ? AppRadius.sm : 10),
      borderSide: BorderSide(color: color, width: _focused ? 1.2 : 1),
    );
  }
}
