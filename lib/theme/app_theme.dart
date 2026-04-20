import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF003C8F);
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color accent = Color(0xFF1E88E5);
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE3EDFB);
  static const Color border = Color(0xFFD6E0EE);
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF6B7A8D);
  static const Color textHint = Color(0xFF9EADC0);
  static const Color normal = Color(0xFF2E7D32);
  static const Color normalLight = Color(0xFFE8F5E9);
  static const Color normalBg = Color(0xFFDCEEDC);
  static const Color warning = Color(0xFFE65100);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color warningBg = Color(0xFFFFE0B2);
  static const Color critical = Color(0xFFB71C1C);
  static const Color criticalLight = Color(0xFFFFEBEE);
  static const Color criticalBg = Color(0xFFFFCDD2);
  static const Color emergency = Color(0xFFC62828);
  static const Color emergencyDark = Color(0xFF8B0000);
  static const Color emergencyLight = Color(0xFFFF5252);
  static const Color ecgGreen = Color(0xFF00C853);
  static const Color ecgBackground = Color(0xFF001A00);
  static const Color shadow = Color(0x1A1565C0);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 57,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -1),
        displayMedium: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5),
        displaySmall: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3),
        headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3),
        headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.2),
        headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary),
        titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary),
        labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary),
      ),
    );
  }
}
