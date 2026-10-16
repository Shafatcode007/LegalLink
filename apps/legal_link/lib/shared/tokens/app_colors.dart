import 'package:flutter/material.dart';

/// Ain Sohay / LegalLink Design Token Colors.
/// Strict adherence to the Parchment Minimalist Legal design system (Role B2).
abstract final class AppColors {
  // --- Base Canvas ---
  /// Base canvas for page backgrounds and card surfaces: #F0EEE8
  static const Color parchment = Color(0xFFF0EEE8);

  /// Elevated surface for dialogs, sheets, and hover states: #F7F5F1
  static const Color parchmentElevated = Color(0xFFF7F5F1);

  /// Inset wells, timeline troughs, and disabled fills: #E7E4DC
  static const Color parchmentSunken = Color(0xFFE7E4DC);

  // --- Text (Oxford) ---
  /// Primary text, dark bands, and iconography: #1A1E28
  static const Color oxford = Color(0xFF1A1E28);

  /// Secondary text on Parchment: #3A404F
  static const Color oxfordSoft = Color(0xFF3A404F);

  /// Timestamps and helper text: #6B7280
  static const Color oxfordMuted = Color(0xFF6B7280);

  // --- Primary Accent (Brass) ---
  /// Primary buttons, active states, and focus rings: #7F5B12
  static const Color brass = Color(0xFF7F5B12);

  /// Button hover/pressed state: #6E4C0E
  static const Color brassHover = Color(0xFF6E4C0E);

  /// Brass-tinted wash for selected rows, chips, and loading glows: #EFE7D6
  static const Color brassWash = Color(0xFFEFE7D6);

  // --- Verified Advocate Badge ONLY (Forest Green) ---
  /// Forest green strictly reserved for verified advocate badge: #2F4A38
  static const Color verifiedForest = Color(0xFF2F4A38);

  // --- SOS & Critical (Burgundy) ---
  /// Burgundy strictly reserved for SOS button and critical alerts: #7A2230
  static const Color burgundy = Color(0xFF7A2230);

  /// SOS pressed state: #631A26
  static const Color burgundyHover = Color(0xFF631A26);

  /// SOS alert banner background: #F3E2E4
  static const Color burgundyWash = Color(0xFFF3E2E4);

  // --- Borders & Dividers (Stone) ---
  /// Dividers, borders, rails, and illustration strokes: #CFC7B6
  static const Color stone = Color(0xFFCFC7B6);

  /// Archived/disabled labels (never body copy): #8A8271
  static const Color stoneText = Color(0xFF8A8271);

  // --- White & Pure Contrast ---
  static const Color white = Color(0xFFFFFFFF);
}
