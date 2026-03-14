import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'profile_setup_screen.dart';
import 'verification_screen.dart';
import 'dashboard_screen.dart';

class StartupScreen extends StatefulWidget {
  final bool isSuccessMode;

  const StartupScreen({super.key, this.isSuccessMode = false});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Logic branch: Success transition vs Initial Boot sequence
    if (widget.isSuccessMode) {
      _handleSuccessTransition();
    } else {
      _handleInitialBoot();
    }
  }

  // Handle the logic for checking user status on cold boot
  Future<void> _handleInitialBoot() async {
    // Futuristic show-off delay for animations to play out
    await Future.delayed(const Duration(milliseconds: 2500)); 
    
    final prefs = await SharedPreferences.getInstance();
    bool isComplete = prefs.getBool(Constants.prefIsSetupComplete) ?? false;
    bool hasMpin = await _authService.isUserRegistered();

    if (!mounted) return;

    if (isComplete && hasMpin) {
      // Returning User -> Go to Verification (Login Mode)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const VerificationScreen()));
    } else if (hasMpin && !isComplete) {
      // Interrupted Setup (Has PIN but no profile) -> Go to Profile Setup
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
    } else {
      // Brand New User -> Go to Verification (SMS Setup Mode)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const VerificationScreen()));
    }
  }

  // Handle the logic after a successful MPIN/Biometric unlock
  Future<void> _handleSuccessTransition() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // MICRO-HEADER TEXT
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.terminal_rounded, size: 14, color: Constants.colorPrimary),
                const SizedBox(width: 8),
                Text(
                  widget.isSuccessMode ? "ACCESS GRANTED" : "SYS_BOOT_SEQ", 
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.bold)
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 40),

            // GLOWING CYBER-NODE LOGO
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Constants.colorSurface.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Constants.colorPrimary.withValues(alpha: widget.isSuccessMode ? 0.3 : 0.15),
                    blurRadius: widget.isSuccessMode ? 60 : 40,
                    spreadRadius: widget.isSuccessMode ? 12 : 8,
                  ),
                  BoxShadow(
                    color: Constants.colorPrimary.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Icon(
                widget.isSuccessMode ? Icons.lock_open_rounded : Icons.hub_rounded,
                size: 70,
                color: Constants.colorPrimary,
              ),
            )
            .animate(target: widget.isSuccessMode ? 1 : 0)
            .scale(end: const Offset(1.15, 1.15), duration: 600.ms, curve: Curves.easeOutBack)
            .then()
            .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5)),
            
            const SizedBox(height: 48),
            
            // APP BRANDING TITLE
            Text(
              widget.isSuccessMode ? "VAULT DECRYPTED" : "CIPHER SPEND",
              style: Constants.headerStyle.copyWith(
                letterSpacing: 6,
                fontSize: 24,
                color: Colors.white,
                shadows: [
                  Shadow(color: Constants.colorPrimary.withValues(alpha: 0.5), blurRadius: 10)
                ]
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutQuad),
            
            const SizedBox(height: 16),
            
            // ANIMATED STATUS SUBTITLE
            Text(
              widget.isSuccessMode ? "Initializing dashboard interface..." : "Air-Gapped Local Intelligence",
              style: Constants.fontRegular.copyWith(letterSpacing: 2, color: Colors.white54, fontSize: 12),
            )
            .animate()
            .fadeIn(delay: 600.ms, duration: 600.ms),

            const SizedBox(height: 40),

            // NEON CYLON/SCANNER PROGRESS BAR
            Container(
              width: 140,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Constants.colorPrimary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(color: Constants.colorPrimary, blurRadius: 6, spreadRadius: 1)
                    ]
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: 0, end: 100, duration: 800.ms, curve: Curves.easeInOut),
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}