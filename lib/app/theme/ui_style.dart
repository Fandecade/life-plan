import 'package:flutter/material.dart';

/// 界面风格：经典（保留）与新版（玻璃质感）。
enum AppUiStyle { classic, refresh }

/// 新版可切换的主题色。strong 用于渐变深端，soft 用于光斑与浅底。
enum AppAccentTheme {
  sage('苔绿', Color(0xFF5F7A4F), Color(0xFF7E9A6B), Color(0xFFDCE8D3)),
  citrus('柠檬', Color(0xFF8FA83A), Color(0xFFAFC44F), Color(0xFFEEF3CC)),
  lavender('薰衣草', Color(0xFF6E659C), Color(0xFF8E85B8), Color(0xFFE7E3F5)),
  sky('雾蓝', Color(0xFF54718C), Color(0xFF7191AE), Color(0xFFDDE8F2));

  const AppAccentTheme(this.label, this.strong, this.accent, this.soft);

  final String label;
  final Color strong;
  final Color accent;
  final Color soft;
}