import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const lavender = Color(0xFF8874B8);

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        seedColor: lavender,
        backgroundColor: const Color(0xFFFBF9FC),
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        seedColor: const Color(0xFFC0AFE8),
        backgroundColor: const Color(0xFF17151B),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seedColor,
    required Color backgroundColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
    );
  }
}
