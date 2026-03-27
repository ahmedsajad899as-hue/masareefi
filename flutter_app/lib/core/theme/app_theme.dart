import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final cairoText = GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 28, color: AppColors.textPrimaryLight),
      headlineMedium: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.textPrimaryLight),
      headlineSmall: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 20, color: AppColors.textPrimaryLight),
      titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimaryLight),
      titleMedium: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimaryLight),
      titleSmall: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimaryLight),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: AppColors.textPrimaryLight),
      bodyMedium: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondaryLight),
      bodySmall: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondaryLight),
      labelMedium: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondaryLight),
      labelSmall: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondaryLight),
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: cairoText,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondaryLight),
        hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
        errorStyle: GoogleFonts.cairo(color: AppColors.error, fontSize: 12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.cairo(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final cairoText = GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 28, color: AppColors.textPrimaryDark),
      headlineMedium: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.textPrimaryDark),
      headlineSmall: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 20, color: AppColors.textPrimaryDark),
      titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimaryDark),
      titleMedium: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimaryDark),
      titleSmall: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimaryDark),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: AppColors.textPrimaryDark),
      bodyMedium: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondaryDark),
      bodySmall: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondaryDark),
      labelMedium: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondaryDark),
      labelSmall: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondaryDark),
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: cairoText,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondaryDark),
        hintStyle: GoogleFonts.cairo(color: AppColors.textSecondaryDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A2A3A), space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
