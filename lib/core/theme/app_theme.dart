import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

/// Assembles the app [ThemeData] from the paper design tokens.
abstract final class AppTheme {
  static ThemeData light() {
    final TextTheme textTheme = TextTheme(
      displayLarge: AppFonts.display(size: 34, weight: FontWeight.w800, height: 1.05),
      headlineMedium: AppFonts.display(size: 26, weight: FontWeight.w800, height: 1.05),
      titleLarge: AppFonts.display(size: 20, weight: FontWeight.w700),
      titleMedium: AppFonts.display(size: 15, weight: FontWeight.w700),
      bodyLarge: AppFonts.display(size: 16),
      bodyMedium: AppFonts.display(size: 14),
      bodySmall: AppFonts.display(size: 13, weight: FontWeight.w500, color: AppColors.inkMuted),
      labelSmall: AppFonts.label(),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        onPrimary: AppColors.paper,
        secondary: AppColors.accent,
        onSecondary: AppColors.ink,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
        onError: AppColors.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppFonts.display(size: 14, color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.inkFaint,
        thickness: AppStroke.thin,
        space: AppSpacing.md,
      ),
    );
  }
}
