import 'package:flutter/material.dart';

class Constants {
  // --- Secure Storage Keys ---
  static const String keyMpinHash = "cipherspend_mpin_hash";
  static const String keyBiometricEnabled = "cipherspend_bio_enabled";

  // --- Shared Preferences Keys ---
  static const String prefIsSetupComplete = "is_setup_complete";
  static const String prefUserName = "user_name";
  static const String prefMonthlyBudget = "monthly_budget";
  static const String prefSalaryDate = "salary_date";

  // --- Database Configuration ---
  static const String dbName = "cipherspend.db";
  static const String tableTransactions = "transactions";
  static const String tableUserConfig = "user_config";

  // --- UI Colors & Themes ---
  // A strict dark mode palette for "Hacker/Cyber" aesthetic
  static const Color colorPrimary = Color(0xFF00E676); // Cyber Green
  static const Color colorBackground = Color(0xFF121212); // Deep Dark
  static const Color colorSurface = Color(0xFF1E1E1E); // Card Background
  static const Color colorError = Color(0xFFCF6679);

  static const TextStyle headerStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 1.2);

  static const TextStyle subHeaderStyle =
      TextStyle(fontSize: 16, color: Colors.grey);
}
