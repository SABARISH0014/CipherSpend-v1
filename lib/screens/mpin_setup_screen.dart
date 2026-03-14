import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'profile_setup_screen.dart'; 

class MPINSetupScreen extends StatefulWidget {
  const MPINSetupScreen({super.key});

  @override
  State<MPINSetupScreen> createState() => _MPINSetupScreenState();
}

class _MPINSetupScreenState extends State<MPINSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final AuthService _authService = AuthService();
  String _statusMessage = "";

  Future<void> _saveMPIN() async {
    if (_pinController.text.length != 4) {
      setState(() => _statusMessage = "❌ SEQUENCE MUST BE 4 DIGITS");
      return;
    }

    // 1. Save the MPIN securely
    await _authService.saveMpin(_pinController.text);

    // 2. Immediately route to Profile Setup (Biometrics will be handled there)
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text("VAULT INITIALIZATION", style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center( 
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                // GLOWING ENCRYPTION NODE
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Constants.colorSurface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Constants.colorPrimary.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: Constants.colorPrimary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.enhanced_encryption_rounded, size: 56, color: Constants.colorPrimary),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                
                const SizedBox(height: 40),
                
                // MICRO-HEADER TEXT
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security_rounded, size: 14, color: Constants.colorPrimary),
                    const SizedBox(width: 8),
                    Text(
                      "SECURITY PROTOCOL", 
                      style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 4)
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                
                const SizedBox(height: 12),
                
                Text(
                  "Set a 4-digit master sequence to securely encrypt your offline ledger.",
                  textAlign: TextAlign.center,
                  style: Constants.subHeaderStyle.copyWith(color: Colors.white54, fontSize: 13, height: 1.4),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 48),

                // GLASSMORPHISM INPUT FIELD
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(
                    fontSize: 32, 
                    letterSpacing: 16, 
                    color: Constants.colorPrimary, 
                    fontWeight: FontWeight.w900
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: Colors.black26,
                    hintText: "••••",
                    hintStyle: const TextStyle(
                      color: Colors.white24, fontSize: 32, letterSpacing: 16, fontWeight: FontWeight.normal
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Constants.colorPrimary.withValues(alpha: 0.5), width: 1.5)
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),

                const SizedBox(height: 24),
                
                // STATUS MESSAGE
                Text(
                  _statusMessage, 
                  style: const TextStyle(color: Constants.colorError, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)
                ).animate(target: _statusMessage.isNotEmpty ? 1 : 0).shake(),
                
                const SizedBox(height: 32),

                // ACTION BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.colorPrimary,
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: Constants.colorPrimary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saveMPIN,
                    icon: const Icon(Icons.shield_rounded, size: 20),
                    label: const Text(
                      "ENCRYPT & PROCEED", 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).scaleY(begin: 0.8, alignment: Alignment.bottomCenter)
              ],
            ),
          ),
        ),
      ),
    );
  }
}