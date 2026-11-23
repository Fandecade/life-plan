import 'package:flutter/material.dart';

/// 全局语义色板：所有模块只允许从这里取色，保证整体克制、统一。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color scrim;

  /// 暖纸灰底 + 纯白卡片
  static const AppPalette light = AppPalette(
    background: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F3F5),
    border: Color(0xFFE6E8EC),
    hairline: Color(0xFFEDEFF2),
    textPrimary: Color(0xFF1A1D21),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    accent: Color(0xFF4A5F7A),
    accentSoft: Color(0xFFE8EDF4),
    success: Color(0xFF4F7A62),
    warning: Color(0xFF9C7448),
    danger: Color(0xFFA2564F),
    scrim: Color(0x3D0F1115),
  );

  /// 深炭灰底 + 稍亮卡片
  static const AppPalette dark = AppPalette(
    background: Color(0xFF121417),
    surface: Color(0xFF1C1F24),
    surfaceMuted: Color(0xFF23272E),
    border: Color(0xFF2A2E37),
    hairline: Color(0xFF23272E),
    textPrimary: Color(0xFFE7E9EC),
    textSecondary: Color(0xFF9BA1AC),
    textTertiary: Color(0xFF6F7683),
    accent: Color(0xFF8FA6C4),
    accentSoft: Color(0xFF232A35),
    success: Color(0xFF7BA98C),
    warning: Color(0xFFC6A075),
    danger: Color(0xFFC67F79),
    scrim: Color(0x80000000),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? scrim,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get texts => Theme.of(this).textTheme;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// 解析实体里保存的 #RRGGBB 颜色，带兜底。
  Color hexColor(String? hex, {Color fallback = const Color(0xFF4A5F7A)}) {
    if (hex == null || hex.isEmpty) return fallback;
    final String value = hex.replaceFirst('#', '');
    if (value.length != 6) return fallback;
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return fallback;
    return Color(0xFF000000 | parsed);
  }
}