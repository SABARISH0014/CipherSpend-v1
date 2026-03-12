import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for Android Permissions
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'mpin_setup_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService _authService = AuthService();
  // Native bridge to talk to MainActivity.kt
  static const platform = MethodChannel('com.example.cipherspend/sms');

  // State variables
  bool _isChecking = true;
  bool _isLoginMode = false;

  final TextEditingController _inputController = TextEditingController();
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _determineMode();
  }

  Future<void> _determineMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if Profile is completely set up
    bool isComplete = prefs.getBool(Constants.prefIsSetupComplete) ?? false;
    // Check if MPIN is saved in Secure Storage
    bool hasMpin = await _authService.isUserRegistered();

    setState(() {
      _isLoginMode = isComplete && hasMpin;
      _isChecking = false;

      if (_isLoginMode) {
        _triggerBiometric();
      }
    });
  }

  Future<void> _triggerBiometric() async {
    bool success = await _authService.authenticateBiometric();
    if (success) _navigateToDashboard();
  }

  Future<void> _handleSubmit() async {
    String input = _inputController.text.trim();
    if (input.isEmpty) return;

    // ==========================================
    // LOGIN FLOW (Unlock Vault)
    // ==========================================
    if (_isLoginMode) {
      bool isValid = await _authService.validateMpin(input);
      if (isValid) {
        _navigateToDashboard();
      } else {
        setState(() => _statusMessage = "❌ Incorrect MPIN");
        _inputController.clear();
      }
      return;
    }

    // ==========================================
    // SETUP FLOW - STEP 1: REAL LOOPBACK SMS
    // ==========================================
    if (!_isLoginMode) {
      if (input.length == 10) {
        // 1. Ask user for SMS Permissions explicitly
        var status = await Permission.sms.request();
        if (!status.isGranted) {
          setState(() => _statusMessage =
              "❌ SMS Permission is strictly required to verify the device.");
          return;
        }

        // 2. Start Native SMS Process
        setState(() {
          _statusMessage = "⏳ Sending real SMS to $input...";
          _isChecking = true; // Show loading indicator
        });

        try {
          final bool isVerified = await platform
              .invokeMethod('verifyLoopbackSms', {'phone': input});

          if (isVerified) {
            setState(() {
              _isChecking = false;
            });
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const MPINSetupScreen()));
            }
          } else {
            setState(() {
              _isChecking = false;
              _statusMessage = "❌ SMS Verification Failed or Timed Out.";
            });
          }
        } on PlatformException catch (e) {
          setState(() {
            _isChecking = false;
            _statusMessage = "❌ Native Error: ${e.message}";
          });
        }
      } else {
        setState(() => _statusMessage = "Enter a valid 10-digit Mobile Number");
      }
      return;
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic UI Text based on current state
    String titleText = _isLoginMode
        ? "Welcome Back"
        : "Setup Vault";

    String hintText = _isLoginMode
        ? "Enter MPIN"
        : "Enter 10-Digit Mobile";

    String buttonText = _isLoginMode
        ? "UNLOCK VAULT"
        : "VERIFY SMS";

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _isLoginMode
                    ? Icons.lock_person
                    : Icons.phonelink_ring,
                size: 80,
                color: Constants.colorPrimary)
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1500.ms),
            const SizedBox(height: 20),
            Text(titleText, style: Constants.headerStyle),
            const SizedBox(height: 10),
            Text(
              _isLoginMode
                  ? "Enter your MPIN or use Fingerprint"
                  : "We will send an SMS to verify this device",
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _inputController,
              keyboardType: TextInputType.number,
              obscureText: _isLoginMode,
              maxLength: _isLoginMode ? 4 : 10,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, letterSpacing: 5),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Constants.colorSurface,
                hintText: hintText,
                hintStyle: const TextStyle(
                    color: Colors.grey, fontSize: 16, letterSpacing: 1),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ).animate().fade(duration: 500.ms).slideY(begin: 0.1),
            const SizedBox(height: 20),

            // Loading indicator while waiting for the native SMS to loop back
            _isChecking && !_isLoginMode
                ? const CircularProgressIndicator(color: Constants.colorPrimary)
                : Text(
                    _statusMessage,
                    style: TextStyle(
                        color: _statusMessage.contains("❌")
                            ? Colors.red
                            : Colors.green,
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
                onPressed: _isChecking ? null : _handleSubmit,
                child: Text(buttonText),
              ),
            ).animate().fade(duration: 500.ms).slideY(begin: 0.1),
            if (_isLoginMode)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: TapScaleWrapper(
                  onTap: _triggerBiometric,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Constants.colorPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fingerprint,
                        size: 40, color: Constants.colorPrimary),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(duration: 2.seconds, color: Colors.white),
                ),
              ).animate().fade(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}
