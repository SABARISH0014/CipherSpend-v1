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

  // --- UI Colors & Themes (Cyberpunk Aesthetic) ---
  static const Color colorPrimary = Color(0xFF00E676); // Cyber Green
  static const Color colorBackground = Color(0xFF0A0A0A); // Deep Dark
  static const Color colorSurface = Color(0xFF1E1E1E); // Card Background
  static const Color colorAccent = Color(0xFFBB86FC); // Neon AI/Training
  static const Color colorError = Color(0xFFFF5252); // Danger

  // --- Typography (Using Google Fonts natively) ---
  static final TextStyle headerStyle = GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1.2,
  );

  static final TextStyle subHeaderStyle = GoogleFonts.spaceGrotesk(
    fontSize: 16,
    color: Colors.grey,
  );

  static final TextStyle bodyStyle = GoogleFonts.spaceGrotesk(
    fontSize: 14,
    color: Colors.white70,
  );

  // --- Motion & Design System Constants ---
  
  // Universal Glassmorphism Standard
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white10),
  );
  
  // Neon Glow for active/success states
  static BoxDecoration get glowingBorderDecoration => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colorPrimary.withOpacity(0.5), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: colorPrimary.withOpacity(0.2),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
  );

  // Danger Glow for active/error states
  static BoxDecoration get dangerGlowDecoration => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colorError.withOpacity(0.5), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: colorError.withOpacity(0.2),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
  );
}

/// A Reusable Wrapper for Tactile Micro-Interactions
/// Wraps any widget to scale it down slightly when tapped.
class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const TapScaleWrapper({Key? key, required this.child, required this.onTap}) : super(key: key);

  @override
  _TapScaleWrapperState createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
