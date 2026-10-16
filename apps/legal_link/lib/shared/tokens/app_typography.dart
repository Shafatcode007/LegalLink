import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography definitions for Ain Sohay / LegalLink.
/// Enforces Playfair Display for headings, Inter for UI/English body,
/// and Noto Sans Bengali for Bangla text (minimum 16sp, line-height 1.6).
abstract final class AppTypography {
  // --- Font Family Getters ---
  static TextStyle displayHeading({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.oxford,
    double? height,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle uiBody({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.oxford,
    double? height = 1.5,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Bangla typography rule: Minimum 16sp, line-height 1.6 to prevent conjunct/matra collapse.
  static TextStyle banglaBody({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.oxford,
    double height = 1.6,
  }) {
    assert(fontSize >= 16, 'Bangla text must be at least 16sp to prevent glyph collapse.');
    return GoogleFonts.notoSansBengali(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle buttonText({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.parchment,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  static TextStyle badgeText({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.white,
  }) {
    return GoogleFonts.notoSansBengali(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }
}
