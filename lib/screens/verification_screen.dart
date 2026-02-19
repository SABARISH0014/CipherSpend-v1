import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'profile_setup_screen.dart'; // Import this!

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService _authService = AuthService();

  // State variables
  bool _isChecking = true;
  bool _isLoginMode = false; // False = Setup Mode, True = Login Mode

  final TextEditingController _inputController = TextEditingController();
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _determineMode();
  }

  Future<void> _determineMode() async {
    // Check if user has completed full setup (Profile + MPIN)
    // We check 'is_setup_complete' which is set at the END of ProfileSetupScreen
    final prefs = await SharedPreferences.getInstance();
    bool isComplete = prefs.getBool(Constants.prefIsSetupComplete) ?? false;

    // Double check: Does MPIN exist?
    bool hasMpin = await _authService.isUserRegistered();

    setState(() {
      // Login Mode only if BOTH are true
      _isLoginMode = isComplete && hasMpin;
      _isChecking = false;

      if (_isLoginMode) {
        _triggerBiometric();
      }
    });
  }

  Future<void> _triggerBiometric() async {
    bool success = await _authService.authenticateBiometric();
    if (success) {
      _navigateToDashboard();
    }
  }

  void _handleSubmit() async {
    String input = _inputController.text.trim();
    if (input.isEmpty) return;

    if (_isLoginMode) {
      // --- LOGIN FLOW (Unlock Vault) ---
      bool isValid = await _authService.validateMpin(input);
      if (isValid) {
        _navigateToDashboard();
      } else {
        setState(() => _statusMessage = "❌ Incorrect MPIN");
        _inputController.clear();
      }
    } else {
      // --- SETUP FLOW (Create Vault) ---

      // Step 1: Mobile Number (Simulated Verification)
      if (input.length == 10) {
        setState(() {
          _statusMessage = "✅ Mobile Verified. Now Set 4-digit MPIN.";
          _inputController.clear();
        });
      }
      // Step 2: Set MPIN
      else if (input.length == 4) {
        // Save the MPIN
        await _authService.saveMpin(input);

        setState(() => _statusMessage = "✅ MPIN Secured!");
        await Future.delayed(const Duration(milliseconds: 500));

        // [CRITICAL FIX] Navigate to Profile Setup, NOT Dashboard
        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const ProfileSetupScreen()));
        }
      } else {
        setState(() =>
            _statusMessage = "Enter valid 10-digit Mobile or 4-digit MPIN");
      }
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Constants.colorBackground,
        body: Center(
            child: CircularProgressIndicator(color: Constants.colorPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person,
                size: 80, color: Constants.colorPrimary),
            const SizedBox(height: 20),
            Text(
              _isLoginMode ? "Welcome Back" : "Setup Vault",
              style: Constants.headerStyle,
            ),
            const SizedBox(height: 10),
            Text(
              _isLoginMode
                  ? "Enter your MPIN or use Fingerprint"
                  : "Verify Mobile & Set MPIN",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _inputController,
              keyboardType: TextInputType.number,
              obscureText: _isLoginMode || _inputController.text.length == 4,
              maxLength: _isLoginMode ? 4 : 10,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, letterSpacing: 5),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Constants.colorSurface,
                hintText: _isLoginMode ? "MPIN" : "Mobile / MPIN",
                hintStyle: const TextStyle(
                    color: Colors.grey, fontSize: 16, letterSpacing: 1),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(
                  color:
                      _statusMessage.contains("❌") ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.colorPrimary,
                    foregroundColor: Colors.black),
                onPressed: _handleSubmit,
                child: Text(_isLoginMode ? "UNLOCK VAULT" : "CONTINUE"),
              ),
            ),
            if (_isLoginMode)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: IconButton(
                  icon: const Icon(Icons.fingerprint,
                      size: 40, color: Constants.colorPrimary),
                  onPressed: _triggerBiometric,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
