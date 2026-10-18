import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:legal_link/shared/tokens/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light(String language) {
    final isBangla = language == 'bn';

    TextStyle heading({
      required double fontSize,
      required FontWeight fontWeight,
      required double height,
      Color color = AppColors.oxford,
    }) {
      if (isBangla) {
        return GoogleFonts.notoSansBengali(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
      }

      return GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
      );
    }

    TextStyle body({
      required double fontSize,
      required FontWeight fontWeight,
      required double height,
      Color color = AppColors.oxford,
      double? letterSpacing,
    }) {
      if (isBangla) {
        return GoogleFonts.notoSansBengali(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
      }

      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
        letterSpacing: letterSpacing,
      );
    }

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

    final textTheme = TextTheme(
      headlineLarge: heading(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineMedium: heading(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      headlineSmall: heading(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      titleLarge: body(fontSize: 18, fontWeight: FontWeight.w700, height: 1.35),
      titleMedium: body(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: body(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
      bodyLarge: body(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
      bodyMedium: body(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
      bodySmall: body(
        fontSize: isBangla ? 16 : 13,
        fontWeight: FontWeight.w400,
        height: isBangla ? 1.6 : 1.45,
        color: AppColors.oxfordMuted,
      ),
      labelLarge: body(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: isBangla ? null : 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.parchment,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.parchment,
        foregroundColor: AppColors.oxford,
        elevation: 0,
        titleTextStyle: textTheme.headlineSmall,
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
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
