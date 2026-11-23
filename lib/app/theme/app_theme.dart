import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 圆角与间距规范，避免各模块自行发挥。
class AppRadius {
  const AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(14));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final ThemeData base = ThemeData(brightness: brightness, useMaterial3: true);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    ).copyWith(
      surface: palette.surface,
      onSurface: palette.textPrimary,
      primary: palette.accent,
      onPrimary:
          brightness == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF0F1216),
      outline: palette.border,
      outlineVariant: palette.hairline,
      error: palette.danger,
      onSurfaceVariant: palette.textSecondary,
      surfaceContainerHighest: palette.surfaceMuted,
      surfaceContainerHigh: palette.surfaceMuted,
      surfaceContainerLow: palette.surface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      colorScheme: scheme,
      textTheme: AppTypography.build(base.textTheme, palette),
      extensions: <ThemeExtension<dynamic>>[palette],
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 18),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: palette.surfaceMuted.withValues(alpha: 0.55),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(4),
        radius: const Radius.circular(4),
        thumbColor: WidgetStatePropertyAll<Color>(
          palette.textTertiary.withValues(alpha: 0.3),
        ),
        crossAxisMargin: 2,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accentSoft,
        selectionHandleColor: palette.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return brightness == Brightness.light
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF121417);
            }
            return palette.textTertiary;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) return palette.accent;
            return palette.surfaceMuted;
          },
        ),
        trackOutlineColor: WidgetStatePropertyAll<Color>(palette.border),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.light
              ? palette.textPrimary
              : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: TextStyle(
          fontSize: 11.5,
          color: brightness == Brightness.light ? Colors.white : palette.textPrimary,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}