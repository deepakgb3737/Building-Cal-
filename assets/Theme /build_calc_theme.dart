import 'package:flutter/material.dart';

/// Shared color tokens for a premium building/construction calculator app.
/// Use these tokens across every screen; avoid hard-coded colors in widgets.
abstract final class BuildCalcColors {
  // Brand
  static const brand = Color(0xFFC65D17);
  static const brandHover = Color(0xFFA94B10);
  static const brandPressed = Color(0xFF873B0C);
  static const brandSoft = Color(0xFFFCEBDD);
  static const brandOn = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF263746);
  static const secondarySoft = Color(0xFFE8EEF2);

  // Light theme
  static const lightBackground = Color(0xFFF6F5F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF0EFEB);
  static const lightTextPrimary = Color(0xFF20252B);
  static const lightTextSecondary = Color(0xFF626B73);
  static const lightTextMuted = Color(0xFF858D94);
  static const lightBorder = Color(0xFFE2E4E5);
  static const lightBorderStrong = Color(0xFFC7CDD1);
  static const lightDivider = Color(0xFFECEDEB);
  static const lightDisabled = Color(0xFFB8BEC3);
  static const lightDisabledSurface = Color(0xFFECEEED);
  static const lightFocus = Color(0xFF2563EB);
  static const lightSelection = Color(0xFFFCEBDD);

  // Dark theme
  static const darkBackground = Color(0xFF111519);
  static const darkSurface = Color(0xFF191F24);
  static const darkSurfaceSubtle = Color(0xFF20272D);
  static const darkSurfaceElevated = Color(0xFF252D34);
  static const darkTextPrimary = Color(0xFFF4F5F6);
  static const darkTextSecondary = Color(0xFFB4BDC5);
  static const darkTextMuted = Color(0xFF89949D);
  static const darkBorder = Color(0xFF303A42);
  static const darkBorderStrong = Color(0xFF48545E);
  static const darkDivider = Color(0xFF293138);
  static const darkDisabled = Color(0xFF64717B);
  static const darkDisabledSurface = Color(0xFF252C32);
  static const darkFocus = Color(0xFF7AA7FF);
  static const darkSelection = Color(0xFF49301F);
  static const darkBrand = Color(0xFFFF8A3D);
  static const darkBrandOn = Color(0xFF24170F);

  // Status colors
  static const success = Color(0xFF218653);
  static const successLightBg = Color(0xFFE5F5EB);
  static const successDarkBg = Color(0xFF173B2A);
  static const successOnDark = Color(0xFF8FE0B1);
  static const warning = Color(0xFFA96700);
  static const warningLightBg = Color(0xFFFFF3D8);
  static const warningDarkBg = Color(0xFF463414);
  static const warningOnDark = Color(0xFFFFD27A);
  static const error = Color(0xFFC23838);
  static const errorLightBg = Color(0xFFFDEAEA);
  static const errorDarkBg = Color(0xFF481F22);
  static const errorOnDark = Color(0xFFFFAAAA);
  static const info = Color(0xFF2563A6);
  static const infoLightBg = Color(0xFFE8F1FC);
  static const infoDarkBg = Color(0xFF1A3049);
  static const infoOnDark = Color(0xFFA6CFFF);

  // Calculator category accents
  static const ceiling = Color(0xFFB45309);
  static const ceilingBg = Color(0xFFFFF0D9);
  static const measurement = Color(0xFF2563EB);
  static const measurementBg = Color(0xFFE8F0FF);
  static const area = Color(0xFF7C3AED);
  static const areaBg = Color(0xFFF0E9FF);
  static const flooring = Color(0xFFA16207);
  static const flooringBg = Color(0xFFFBF1D4);
  static const insulation = Color(0xFF0E7490);
  static const insulationBg = Color(0xFFDFF5F8);
  static const concrete = Color(0xFF596674);
  static const concreteBg = Color(0xFFE9EDF0);
  static const painting = Color(0xFFBE185D);
  static const paintingBg = Color(0xFFFCE7F3);
  static const plumbing = Color(0xFF0369A1);
  static const plumbingBg = Color(0xFFE0F2FE);
  static const electrical = Color(0xFFA16207);
  static const electricalBg = Color(0xFFFEF3C7);
  static const woodwork = Color(0xFF8A4B20);
  static const woodworkBg = Color(0xFFF7E8D9);
  static const roofing = Color(0xFFC2410C);
  static const roofingBg = Color(0xFFFFEDD5);
  static const waterproofing = Color(0xFF0F766E);
  static const waterproofingBg = Color(0xFFDDF7F1);
  static const brickwork = Color(0xFF9A3412);
  static const brickworkBg = Color(0xFFFBE9DF);
  static const cost = Color(0xFF218653);
  static const costBg = Color(0xFFE5F5EB);

  // Charts
  static const chartPrimary = Color(0xFFC65D17);
  static const chartSecondary = Color(0xFF2563EB);
  static const chartTertiary = Color(0xFF0F766E);
  static const chartQuaternary = Color(0xFF7C3AED);
}

abstract final class BuildCalcTheme {
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
          borderSide: const BorderSide(color: BuildCalcColors.lightFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BuildCalcColors.error, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BuildCalcColors.brand,
          foregroundColor: BuildCalcColors.brandOn,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          borderSide: const BorderSide(color: BuildCalcColors.darkFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BuildCalcColors.errorOnDark, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BuildCalcColors.darkBrand,
          foregroundColor: BuildCalcColors.darkBrandOn,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BuildCalcColors.darkBrand),
      ),
      dividerColor: BuildCalcColors.darkDivider,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BuildCalcColors.darkSurfaceElevated,
        contentTextStyle: const TextStyle(color: BuildCalcColors.darkTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
