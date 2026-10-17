import 'package:flutter/material.dart';
import 'package:legal_link/shared/tokens/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brass,
          brightness: Brightness.light,
          surface: AppColors.parchment,
        ).copyWith(
          primary: AppColors.brass,
          secondary: AppColors.oxford,
          onPrimary: AppColors.white,
          onSecondary: AppColors.white,
          onSurface: AppColors.oxford,
        );

    const normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.stone),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.parchment,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.parchment,
        foregroundColor: AppColors.oxford,
        elevation: 0,
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.oxford,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.oxford,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.oxford,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: AppColors.oxford,
          fontSize: 16,
          height: 1.6,
        ),
        bodySmall: TextStyle(color: AppColors.oxfordMuted, height: 1.5),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: normalBorder,
        enabledBorder: normalBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.brass, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.parchmentSunken,
          disabledForegroundColor: AppColors.oxfordMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
