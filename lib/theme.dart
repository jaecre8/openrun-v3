import 'package:flutter/material.dart';

class AppColors {
  static const main = Color(0xFFF90069);
  static const mainSoft = Color(0xFFFFE6F0);
  static const bg = Color(0xFFF5F5F7);
  static const text = Color(0xFF222222);
  static const sub = Color(0xFF8A8A8E);
  static const line = Color(0xFFE9E9EC);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.main,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mainSoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.main : AppColors.sub,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.main : null),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      ),
    );
