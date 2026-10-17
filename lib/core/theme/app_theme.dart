import 'package:flutter/material.dart';
import 'build_calc_colors.dart';
import '../../ui/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: BuildCalcColors.brand,
      brightness: Brightness.light,
      surface: BuildCalcColors.lightSurface,
    ).copyWith(
      primary: BuildCalcColors.brand,
      onPrimary: BuildCalcColors.brandOn,
      secondary: BuildCalcColors.secondary,
      onSecondary: Colors.white,
      surface: BuildCalcColors.lightSurface,
      error: BuildCalcColors.error,
      outline: BuildCalcColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: BuildCalcColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: BuildCalcColors.lightBackground,
        foregroundColor: BuildCalcColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: BuildCalcColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BuildCalcColors.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BuildCalcColors.lightSurface,
        labelStyle: const TextStyle(color: BuildCalcColors.lightTextSecondary),
        hintStyle: const TextStyle(color: BuildCalcColors.lightTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BuildCalcColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BuildCalcColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: BuildCalcColors.lightFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: BuildCalcColors.error, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BuildCalcColors.brand,
          foregroundColor: BuildCalcColors.brandOn,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BuildCalcColors.brand),
      ),
      dividerColor: BuildCalcColors.lightDivider,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BuildCalcColors.secondary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: BuildCalcColors.darkBrand,
      brightness: Brightness.dark,
      surface: BuildCalcColors.darkSurface,
    ).copyWith(
      primary: BuildCalcColors.darkBrand,
      onPrimary: BuildCalcColors.darkBrandOn,
      secondary: const Color(0xFF8DA9C0),
      surface: BuildCalcColors.darkSurface,
      error: BuildCalcColors.errorOnDark,
      outline: BuildCalcColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: BuildCalcColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: BuildCalcColors.darkBackground,
        foregroundColor: BuildCalcColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: BuildCalcColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BuildCalcColors.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BuildCalcColors.darkSurfaceSubtle,
        labelStyle: const TextStyle(color: BuildCalcColors.darkTextSecondary),
        hintStyle: const TextStyle(color: BuildCalcColors.darkTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BuildCalcColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BuildCalcColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: BuildCalcColors.darkFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: BuildCalcColors.errorOnDark, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BuildCalcColors.darkBrand,
          foregroundColor: BuildCalcColors.darkBrandOn,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BuildCalcColors.darkBrand),
      ),
      dividerColor: BuildCalcColors.darkDivider,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BuildCalcColors.darkSurfaceElevated,
        contentTextStyle:
            const TextStyle(color: BuildCalcColors.darkTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
