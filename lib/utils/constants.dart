import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Constants {
  // --- Secure Storage Keys (Critical Security) ---
  static const String keyMpinHash = "cipherspend_mpin_hash";
  static const String keyBiometricEnabled = "cipherspend_bio_enabled";

  // --- Shared Preferences Keys (User Settings) ---
  static const String prefIsSetupComplete = "is_setup_complete";
  static const String prefUserName = "user_name";
  static const String prefMonthlyBudget = "monthly_budget";
  static const String prefSalaryDate = "salary_date";

  // --- Database Configuration ---
  static const String dbName = "cipherspend.db";
  static const String tableTransactions = "transactions";
  static const String tableUserConfig = "user_config";

  // --- Premium UI Colors (Cyberpunk / Glassmorphism) ---
  static const Color colorPrimary = Color(0xFF00E676); // Neon Green
  static const Color colorAccent = Color(0xFFBB86FC); // AI/Neural Purple
  static const Color colorBackground = Color(0xFF0A0A0A); // Deep True Dark
  static const Color colorSurface = Color(0x0DFFFFFF); // 5% White for Glass
  static const Color colorError = Color(0xFFFF5252); // Danger Neon Red

  // --- Universal Typography (Space Grotesk) ---
  static TextStyle get fontRegular => GoogleFonts.spaceGrotesk(
        color: Colors.white70,
      );

  static TextStyle get headerStyle => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.2,
      );

  static TextStyle get subHeaderStyle => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        color: Colors.grey.shade400,
        letterSpacing: 0.5,
      );

  // --- Universal Glassmorphism Standard ---
  static BoxDecoration get glassDecoration => BoxDecoration(
        color: colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  // Use this inside a BackdropFilter for true glass effect
  static ImageFilter get glassBlur => ImageFilter.blur(sigmaX: 12, sigmaY: 12);
}