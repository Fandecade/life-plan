import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 排版层级：字号克制、字重不超过 600、标题带轻微负字距。
class AppTypography {
  const AppTypography._();

  static TextTheme build(TextTheme base, AppPalette palette) {
    TextStyle style(
      TextStyle? origin,
      double size,
      FontWeight weight, {
      double letterSpacing = 0,
      double height = 1.45,
      Color? color,
    }) {
      return (origin ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color ?? palette.textPrimary,
      );
    }

    return base.copyWith(
      displaySmall: style(base.displaySmall, 28, FontWeight.w600,
          letterSpacing: -0.8, height: 1.25),
      headlineMedium: style(base.headlineMedium, 23, FontWeight.w600,
          letterSpacing: -0.5, height: 1.3),
      headlineSmall: style(base.headlineSmall, 20, FontWeight.w600,
          letterSpacing: -0.35, height: 1.35),
      titleLarge: style(base.titleLarge, 17, FontWeight.w600,
          letterSpacing: -0.25, height: 1.35),
      titleMedium: style(base.titleMedium, 15, FontWeight.w500,
          letterSpacing: -0.1, height: 1.4),
      titleSmall: style(base.titleSmall, 13.5, FontWeight.w500, height: 1.4),
      bodyLarge: style(base.bodyLarge, 14.5, FontWeight.w400, height: 1.6),
      bodyMedium: style(base.bodyMedium, 13.5, FontWeight.w400, height: 1.55),
      bodySmall: style(base.bodySmall, 12, FontWeight.w400,
          height: 1.5, color: palette.textTertiary),
      labelLarge: style(base.labelLarge, 13, FontWeight.w500, height: 1.3),
      labelMedium: style(base.labelMedium, 11.5, FontWeight.w500,
          letterSpacing: 0.15, height: 1.3, color: palette.textSecondary),
      labelSmall: style(base.labelSmall, 10.5, FontWeight.w500,
          letterSpacing: 0.25, height: 1.3, color: palette.textTertiary),
    );
  }
}