import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/constants.dart';
import 'dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _salaryDateController = TextEditingController();

  final LocalAuthentication _localAuth = LocalAuthentication();

  String _errorMessage = "";

  // [NEW] Track if the user has completed the fingerprint step
  bool _isBiometricRegistered = false;

  @override
  void initState() {
    super.initState();
    int today = DateTime.now().day;
    _salaryDateController.text = today.toString();
  }

  // [NEW] Dedicated method for the registration button
  Future<void> _registerBiometric() async {
    setState(() => _errorMessage = "");
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() => _errorMessage =
            "Biometrics are not supported or set up on this device.");
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to register your vault lock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        setState(() {
          _isBiometricRegistered = true;
          _errorMessage = ""; // Clear any previous errors
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Authentication error: $e");
    }
  }

  Future<void> _completeSetup() async {
    // 1. Check Biometric Status First
    if (!_isBiometricRegistered) {
      setState(
          () => _errorMessage = "Please register your biometric lock first.");
      return;
    }

    final String name = _nameController.text.trim();
    final String budgetStr = _budgetController.text.trim();
    final String salaryDateStr = _salaryDateController.text.trim();

    // 2. Validation
    if (name.isEmpty || budgetStr.isEmpty || salaryDateStr.isEmpty) {
      setState(() => _errorMessage = "All fields are required.");
      return;
    }

    final double? budget = double.tryParse(budgetStr);
    final int? salaryDate = int.tryParse(salaryDateStr);

    if (budget == null || budget <= 0) {
      setState(() => _errorMessage = "Please enter a valid budget.");
      return;
    }

    if (salaryDate == null || salaryDate < 1 || salaryDate > 31) {
      setState(() => _errorMessage = "Salary date must be between 1 and 31.");
      return;
    }

    // 3. Save Data (Only happens if validation passes AND biometrics are registered)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.prefUserName, name);
    await prefs.setDouble(Constants.prefMonthlyBudget, budget);
    await prefs.setInt(Constants.prefSalaryDate, salaryDate);

    // Lock in the vault status
    await prefs.setBool('prefBiometricEnabled', true);
    await prefs.setBool(Constants.prefIsSetupComplete, true);

    // 4. Navigation
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 80,
                  color: Constants.colorPrimary,
                ),
                const SizedBox(height: 24),

                const Text(
                  "Initialize Vault",
                  style: Constants.headerStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "This data stays local and encrypted on your device.",
                  style: Constants.subHeaderStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // [NEW] Biometric Registration Card
                GestureDetector(
                  onTap: _isBiometricRegistered ? null : _registerBiometric,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isBiometricRegistered
                          ? Colors.green.withOpacity(0.1)
                          : Constants.colorSurface,
                      border: Border.all(
                        color: _isBiometricRegistered
                            ? Colors.green
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: _isBiometricRegistered
                              ? Colors.green
                              : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isBiometricRegistered
                                    ? "Vault Lock Registered"
                                    : "Setup Biometric Lock",
                                style: TextStyle(
                                  color: _isBiometricRegistered
                                      ? Colors.green
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (!_isBiometricRegistered)
                                const Text(
                                  "Tap to scan your fingerprint",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        if (_isBiometricRegistered)
                          const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Name Field
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "User Name",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.person_outline, color: Colors.grey),
                    filled: true,
                    fillColor: Constants.colorSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Budget Field
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Monthly Budget (₹)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.grey),
                    filled: true,
                    fillColor: Constants.colorSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Salary Date Field (Auto-filled)
                TextField(
                  controller: _salaryDateController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Salary Cycle Start Date",
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: "Day of the month (1-31)",
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        color: Colors.grey),
                    filled: true,
                    fillColor: Constants.colorSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Error Message Display
                if (_errorMessage.isNotEmpty) ...[
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                        color: Constants.colorError, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.colorPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _completeSetup,
                    child: const Text(
                      "Finalize & Enter",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
