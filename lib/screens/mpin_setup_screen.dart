import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      setState(() => _statusMessage = "PIN must be 4 digits");
      return;
    }

    // 1. Use Service to Hash & Save (Corrected Name)
    await _authService.saveMpin(_pinController.text);

    // 2. Prompt for Biometric Link
    // Note: authenticateBiometric() inside AuthService already checks if hardware is available.
    bool didAuthenticate = await _authService.authenticateBiometric();

    if (didAuthenticate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometrics Linked Successfully!")));
    }

    // 3. Navigate to Profile Setup
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
        title: const Text("Secure Vault Setup"),
        backgroundColor: Constants.colorSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline,
                size: 60, color: Constants.colorPrimary),
            const SizedBox(height: 20),
            Text("Set 4-Digit Vault PIN", style: Constants.headerStyle),
            const SizedBox(height: 10),
            Text(
              "This PIN encrypts your local database key.",
              textAlign: TextAlign.center,
              style: Constants.subHeaderStyle,
            ),
            const SizedBox(height: 30),

            // PIN INPUT
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 8, color: Colors.white),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Constants.colorSurface,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Constants.colorPrimary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(_statusMessage,
                style: const TextStyle(color: Constants.colorError)),
            const SizedBox(height: 20),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TapScaleWrapper(
                onTap: _saveMPIN,
                child: Container(
                  alignment: Alignment.center,
                  decoration: Constants.glowingBorderDecoration.copyWith(
                    color: Constants.colorPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Encrypt & Save",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          ].animate(interval: 50.ms).fade(duration: 300.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}
