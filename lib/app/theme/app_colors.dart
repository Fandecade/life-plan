import 'package:flutter/material.dart';

import 'ui_style.dart';

/// 全局语义色板：所有模块只允许从这里取色，保证整体克制、统一。
///
/// 经典风格保持原有暖白/灰蓝；新版风格使用冷调底 + 玻璃卡 + 主题色。
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
    this.style = AppUiStyle.classic,
    this.glass = const Color(0xFFFFFFFF),
    this.glassBorder = const Color(0xFFFFFFFF),
    this.glassHighlight = const Color(0xFFFFFFFF),
    this.accentStrong = const Color(0xFF4A5F7A),
    this.blobA = const Color(0x00000000),
    this.blobB = const Color(0x00000000),
    this.blobC = const Color(0x00000000),
    this.glassBlur = 0,
    this.glassEnabled = false,
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

  /// 当前界面风格。
  final AppUiStyle style;

  /// 玻璃卡填充、高光描边与模糊半径。
  final Color glass;
  final Color glassBorder;
  final Color glassHighlight;

  /// 主题色渐变深端。
  final Color accentStrong;

  /// 新版背景的环境光斑（透明表示不绘制）。
  final Color blobA;
  final Color blobB;
  final Color blobC;

  final double glassBlur;
  final bool glassEnabled;

  /// 暖纸灰底 + 纯白卡片（经典）
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

  /// 深炭灰底 + 稍亮卡片（经典深色）
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

  /// 新版浅色：冷调底 + 白玻璃 + 主题色光斑。
  static AppPalette refreshLight(
    AppAccentTheme theme, {
    bool glassEnabled = true,
  }) {
    return AppPalette(
      style: AppUiStyle.refresh,
      background: const Color(0xFFF1F2F5),
      surface: const Color(0xFFFFFFFF),
      surfaceMuted: const Color(0xFFE9EBEF),
      border: const Color(0xFFDDE1E7),
      hairline: const Color(0xFFE7EAEE),
      textPrimary: const Color(0xFF14161A),
      textSecondary: const Color(0xFF636B76),
      textTertiary: const Color(0xFF9AA1AB),
      accent: theme.accent,
      accentStrong: theme.strong,
      accentSoft: theme.soft,
      success: const Color(0xFF4F7A62),
      warning: const Color(0xFF9C7448),
      danger: const Color(0xFFA2564F),
      scrim: const Color(0x3D0F1115),
      glass: Colors.white.withValues(alpha: 0.46),
      glassBorder: Colors.white.withValues(alpha: 0.9),
      glassHighlight: Colors.white.withValues(alpha: 0.95),
      blobA: theme.soft.withValues(alpha: 0.9),
      blobB: const Color(0xFFDCE3F2).withValues(alpha: 0.55),
      blobC: const Color(0xFFF3E7DC).withValues(alpha: 0.45),
      glassBlur: glassEnabled ? 18 : 0,
      glassEnabled: glassEnabled,
    );
  }

  /// 新版深色：近黑底 + 深玻璃 + 提亮主题色。
  static AppPalette refreshDark(
    AppAccentTheme theme, {
    bool glassEnabled = true,
  }) {
    return AppPalette(
      style: AppUiStyle.refresh,
      background: const Color(0xFF0E1013),
      surface: const Color(0xFF17191E),
      surfaceMuted: const Color(0xFF1F2229),
      border: const Color(0xFF2A2E36),
      hairline: const Color(0xFF23262D),
      textPrimary: const Color(0xFFE8EAEE),
      textSecondary: const Color(0xFF9BA1AC),
      textTertiary: const Color(0xFF6E7580),
      accent: Color.lerp(theme.accent, Colors.white, 0.22)!,
      accentStrong: theme.accent,
      accentSoft: theme.accent.withValues(alpha: 0.18),
      success: const Color(0xFF7BA98C),
      warning: const Color(0xFFC6A075),
      danger: const Color(0xFFC67F79),
      scrim: const Color(0x80000000),
      glass: const Color(0x8C1C1F24),
      glassBorder: Colors.white.withValues(alpha: 0.12),
      glassHighlight: Colors.white.withValues(alpha: 0.18),
      blobA: theme.accent.withValues(alpha: 0.22),
      blobB: const Color(0xFF7F97C4).withValues(alpha: 0.16),
      blobC: const Color(0xFFC9A98A).withValues(alpha: 0.1),
      glassBlur: glassEnabled ? 18 : 0,
      glassEnabled: glassEnabled,
    );
  }

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
    AppUiStyle? style,
    Color? glass,
    Color? glassBorder,
    Color? glassHighlight,
    Color? accentStrong,
    Color? blobA,
    Color? blobB,
    Color? blobC,
    double? glassBlur,
    bool? glassEnabled,
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
      style: style ?? this.style,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      accentStrong: accentStrong ?? this.accentStrong,
      blobA: blobA ?? this.blobA,
      blobB: blobB ?? this.blobB,
      blobC: blobC ?? this.blobC,
      glassBlur: glassBlur ?? this.glassBlur,
      glassEnabled: glassEnabled ?? this.glassEnabled,
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
      style: t < 0.5 ? style : other.style,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      blobA: Color.lerp(blobA, other.blobA, t)!,
      blobB: Color.lerp(blobB, other.blobB, t)!,
      blobC: Color.lerp(blobC, other.blobC, t)!,
      glassBlur: glassBlur + (other.glassBlur - glassBlur) * t,
      glassEnabled: t < 0.5 ? glassEnabled : other.glassEnabled,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get texts => Theme.of(this).textTheme;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  bool get isRefreshStyle => palette.style == AppUiStyle.refresh;

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