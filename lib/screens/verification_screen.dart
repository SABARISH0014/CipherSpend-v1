import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import 'startup_screen.dart'; 
import 'mpin_setup_screen.dart';
import '../widgets/restricted_settings_dialog.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService _authService = AuthService();
  static const platform = MethodChannel('com.example.cipherspend/sms');

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
    bool isComplete = prefs.getBool(Constants.prefIsSetupComplete) ?? false;
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
    if (success) _navigateToSuccess();
  }

  Future<void> _handleSubmit() async {
    String input = _inputController.text.trim();
    if (input.isEmpty) return;

    if (_isLoginMode) {
      bool isValid = await _authService.validateMpin(input);
      if (isValid) {
        _navigateToSuccess();
      } else {
        setState(() => _statusMessage = "❌ ACCESS DENIED: Invalid MPIN");
        _inputController.clear();
      }
      return;
    }

    // New User Device Verification Logic
    if (input.length == 10) {
      var status = await Permission.sms.request();
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const RestrictedSettingsDialog(),
        );
        return;
      }
      if (!status.isGranted) {
        setState(() => _statusMessage = "❌ SMS Permission required to secure node.");
        return;
      }

      setState(() {
        _statusMessage = "⏳ Verifying Device Signature...";
        _isChecking = true;
      });

      try {
        final bool isVerified = await platform.invokeMethod('verifyLoopbackSms', {'phone': input});

        if (isVerified) {
          setState(() {
            _isChecking = false;
            _statusMessage = "✅ Node Verified. Initializing Vault...";
            _inputController.clear();
          });
          
          // Seamless transition to MPIN setup
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => const MPINSetupScreen())
            );
          }
        } else {
          setState(() {
            _isChecking = false;
            _statusMessage = "❌ Handshake Failed.";
          });
        }
      } on PlatformException catch (e) {
        setState(() {
          _isChecking = false;
          _statusMessage = "❌ Protocol Error: ${e.message}";
        });
      }
    } else {
      setState(() => _statusMessage = "Enter valid 10-digit vector");
    }
  }

  void _navigateToSuccess() {
    Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const StartupScreen(isSuccessMode: true))
    );
  }

  @override
  Widget build(BuildContext context) {
    String titleText = _isLoginMode ? "SYSTEM LOCKED" : "INITIALIZE VAULT";
    String hintText = _isLoginMode ? "Enter Security PIN" : "Enter Mobile Number";
    String buttonText = _isLoginMode ? "DECRYPT VAULT" : "VERIFY DEVICE";

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                // GLOWING SECURITY NODE
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
                  child: Icon(
                    _isLoginMode ? Icons.lock_outline_rounded : Icons.cell_tower_rounded,
                    size: 56,
                    color: Constants.colorPrimary,
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                
                const SizedBox(height: 40),
                
                // MICRO-HEADER TEXT
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- THE FINAL CONST FIX IS RIGHT HERE ---
                    const Icon(Icons.terminal_rounded, size: 14, color: Constants.colorPrimary),
                    const SizedBox(width: 8),
                    Text(
                      titleText, 
                      style: Constants.headerStyle.copyWith(fontSize: 18, letterSpacing: 4)
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                    
                const SizedBox(height: 12),
                
                Text(
                  _isLoginMode
                      ? "Awaiting decryption key or biometric signature."
                      : "Establishing secure loopback to verify device integrity.",
                  style: Constants.subHeaderStyle.copyWith(color: Colors.white54, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 48),
                
                // GLASSMORPHISM INPUT FIELD
                TextField(
                  controller: _inputController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                  obscureText: _isLoginMode,
                  maxLength: _isLoginMode ? 4 : 10,
                  style: TextStyle(
                    color: Constants.colorPrimary, 
                    fontSize: 28, 
                    letterSpacing: _isLoginMode ? 16 : 4, 
                    fontWeight: FontWeight.w900
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: Colors.black26,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: Colors.white24, fontSize: 16, letterSpacing: 1, fontWeight: FontWeight.normal
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
                _isChecking && !_isLoginMode
                    ? const CircularProgressIndicator(color: Constants.colorPrimary)
                    : Text(
                        _statusMessage,
                        style: TextStyle(
                            color: _statusMessage.contains("❌")
                                ? Constants.colorError
                                : Constants.colorPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
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
                    onPressed: _isChecking ? null : _handleSubmit,
                    icon: Icon(_isLoginMode ? Icons.key_rounded : Icons.send_to_mobile_rounded, size: 20),
                    label: Text(
                      buttonText, 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).scaleY(begin: 0.8, alignment: Alignment.bottomCenter),
                
                // BIOMETRIC SCANNER (Login Mode Only)
                if (_isLoginMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Text("OR SCAN BIOMETRIC", style: Constants.fontRegular.copyWith(fontSize: 10, color: Colors.white30, letterSpacing: 2)),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _triggerBiometric,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Constants.colorPrimary.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.3), width: 1),
                            ),
                            child: const Icon(Icons.fingerprint_rounded, size: 40, color: Constants.colorPrimary),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .fade(begin: 0.6, end: 1.0, duration: 1.5.seconds)
                         .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.5.seconds),
                      ],
                    ),
                  ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}