import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  @override
  void initState() {
    super.initState();
    _handleRouting();
  }

  Future<void> _handleRouting() async {
    if (widget.isSuccessMode) {
      // Success mode: After 1.5 seconds, go to Dashboard
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      // Boot mode: Check setup status after intro animation
      final prefs = await SharedPreferences.getInstance();
      bool isSetup = prefs.getBool(Constants.prefIsSetupComplete) ?? false;
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const VerificationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Vault / Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: widget.isSuccessMode 
                  ? Constants.glowingBorderDecoration 
                  : Constants.glassDecoration.copyWith(
                      borderRadius: BorderRadius.circular(100),
                    ),
              child: Icon(
                widget.isSuccessMode ? Icons.lock_open : Icons.security,
                size: 80,
                color: widget.isSuccessMode ? Constants.colorPrimary : Constants.colorAccent,
              ),
            )
            .animate(
              onPlay: (controller) => widget.isSuccessMode ? controller.forward() : controller.repeat(reverse: true),
            )
            .scale(
              begin: const Offset(1, 1), 
              end: widget.isSuccessMode ? const Offset(1.2, 1.2) : const Offset(1.1, 1.1), 
              duration: widget.isSuccessMode ? 500.ms : 1000.ms, 
              curve: Curves.easeInOut,
            )
            .then(delay: widget.isSuccessMode ? 200.ms : 0.ms)
            .shimmer(
              duration: 1000.ms,
              color: widget.isSuccessMode ? Colors.white : Constants.colorPrimary.withOpacity(0.5),
            ),
            
            const SizedBox(height: 32),
            
            // Text Below Logo
            if (widget.isSuccessMode)
              Text(
                "ACCESS GRANTED",
                style: Constants.headerStyle.copyWith(
                  color: Constants.colorPrimary,
                  letterSpacing: 4,
                ),
              ).animate().fade().slideY(begin: 0.5, curve: Curves.easeOutCubic)
            else
              Column(
                children: [
                  Text(
                    "CIPHER SPEND",
                    style: Constants.headerStyle.copyWith(
                      letterSpacing: 8,
                      fontSize: 28,
                    ),
                  ).animate().fade(duration: 800.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Text(
                    "Secure Local Vault",
                    style: Constants.subHeaderStyle,
                  ).animate(delay: 400.ms).fade(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
