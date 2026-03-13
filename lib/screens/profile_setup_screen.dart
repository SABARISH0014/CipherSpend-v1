import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';
import 'dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with WidgetsBindingObserver {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _salaryDateController = TextEditingController();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const platform = MethodChannel('com.example.cipherspend/sms');

  String _errorMessage = "";
  bool _isBiometricRegistered = false;

  bool _waitingForListenerPermission = false;
  bool _waitingForUsagePermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    int today = DateTime.now().day;
    _salaryDateController.text = today.toString();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _budgetController.dispose();
    _salaryDateController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_waitingForListenerPermission) {
        setState(() => _waitingForListenerPermission = false);
        _askSmartPromptAndProceed();
      } else if (_waitingForUsagePermission) {
        setState(() => _waitingForUsagePermission = false);
        _askDedupePreference();
      }
    }
  }

  Future<void> _registerBiometric() async {
    setState(() => _errorMessage = "");
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(
          () => _errorMessage =
              "Biometrics are not supported or set up on this device.",
        );
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_biometric_enabled', true);

        setState(() {
          _isBiometricRegistered = true;
          _errorMessage = "";
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Authentication error: $e");
    }
  }

  Future<void> _completeSetup() async {
    final String name = _nameController.text.trim();
    final String budgetStr = _budgetController.text.trim();
    final String salaryDateStr = _salaryDateController.text.trim();

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.prefUserName, name);
    await prefs.setDouble(Constants.prefMonthlyBudget, budget);
    await prefs.setInt(Constants.prefSalaryDate, salaryDate);

    await Permission.sms.request();

    if (!mounted) return;
    await _checkStorageAndProceed();
  }

  // --- STEP 1: STORAGE ACCESS ---
  Future<void> _checkStorageAndProceed() async {
    try {
      bool isStorageGranted = await Permission.storage.isGranted;
      bool isManageGranted = await Permission.manageExternalStorage.isGranted;

      if (isStorageGranted || isManageGranted) {
        _checkListenerAndProceed();
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _buildGlassDialog(
            title: "STORAGE ACCESS",
            icon: Icons.folder_shared_rounded,
            content:
                "CipherSpend requires storage access to securely generate and export your monthly visual reports to PDF and CSV formats.\n\nTap ENABLE on the next prompt to authorize.",
            onSkip: () {
              Navigator.pop(ctx);
              _checkListenerAndProceed();
            },
            onAllow: () async {
              Navigator.pop(ctx);
              await [
                Permission.storage,
                Permission.manageExternalStorage,
              ].request();
              if (!mounted) return;
              _checkListenerAndProceed();
            },
          ),
        );
      }
    } catch (e) {
      _checkListenerAndProceed();
    }
  }

  // --- STEP 2: NOTIFICATION LISTENER ---
  Future<void> _checkListenerAndProceed() async {
    bool isEnabled = false;
    try {
      isEnabled = await platform.invokeMethod('isNotificationListenerEnabled');
    } catch (e) {
      isEnabled = false;
    }

    if (isEnabled) {
      _askSmartPromptAndProceed();
    } else {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildGlassDialog(
          title: "UPI TRACKING",
          icon: Icons.notifications_active_rounded,
          content:
              "To track GPay, PhonePe, and Paytm transactions automatically, CipherSpend needs 'Notification Access'.\n\n1. Tap ENABLE below.\n2. Find 'CipherSpend' in the list.\n3. Toggle it ON and press Allow.",
          onSkip: () {
            Navigator.pop(ctx);
            _askSmartPromptAndProceed();
          },
          onAllow: () async {
            setState(() {
              _waitingForListenerPermission = true;
            });
            Navigator.pop(ctx);
            await platform.invokeMethod('openNotificationSettings');
          },
        ),
      );
    }
  }

  // --- STEP 3: SMART PROMPTS (USAGE ACCESS) ---
  Future<void> _askSmartPromptAndProceed() async {
    bool hasAccess = false;
    try {
      hasAccess = await platform.invokeMethod('hasUsageAccess');
    } catch (e) {
      hasAccess = false;
    }

    if (hasAccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smart_prompt_enabled', true);
      if (!mounted) return;
      _askDedupePreference();
    } else {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildGlassDialog(
          title: "SMART PROMPTS",
          icon: Icons.auto_awesome_rounded,
          content:
              "If a payment app doesn't send a notification, CipherSpend can detect when you close the app and proactively ask if you made a payment.\n\nTo enable this, we need 'Usage Access'.\n1. Tap ENABLE below.\n2. Find 'CipherSpend' and turn ON 'Permit usage access'.",
          onSkip: () async {
            Navigator.pop(ctx);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('smart_prompt_enabled', false);
            if (!mounted) return;
            _askDedupePreference();
          },
          onAllow: () async {
            setState(() {
              _waitingForUsagePermission = true;
            });
            Navigator.pop(ctx);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('smart_prompt_enabled', true);
            await platform.invokeMethod('openUsageAccessSettings');
          },
        ),
      );
    }
  }

  // --- STEP 4: DUPLICATE PREFERENCE ---
  Future<void> _askDedupePreference() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildGlassDialog(
        title: "DUPLICATE HANDLING",
        icon: Icons.difference_rounded,
        content:
            "Banks and apps often send multiple alerts for the same transaction (e.g., an SMS and a GPay notification).\n\nShould the system automatically drop duplicates, or ask you every time one is detected?",
        skipText: "ASK ME",
        allowText: "AUTO-DROP",
        onSkip: () async {
          Navigator.pop(ctx);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('dedupe_rule', 'ask');
          if (!mounted) return;
          _finishSetupAndNavigate();
        },
        onAllow: () async {
          Navigator.pop(ctx);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('dedupe_rule', 'auto_drop');
          if (!mounted) return;
          _finishSetupAndNavigate();
        },
      ),
    );
  }

  // --- STEP 5: FINISH SETUP AND NAVIGATE ---
  Future<void> _finishSetupAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.prefIsSetupComplete, true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  // --- UI HELPER FOR GLASS DIALOGS (CYBERPUNK UPGRADE) ---
  Widget _buildGlassDialog({
    required String title,
    required String content,
    required IconData icon,
    required VoidCallback onSkip,
    required VoidCallback onAllow,
    String skipText = "SKIP",
    String allowText = "ENABLE",
  }) {
    return BackdropFilter(
      filter: Constants.glassBlur,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20), 
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: Constants.glassDecoration.copyWith(
            border: Border.all(color: Constants.colorAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: Constants.colorAccent.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Constants.colorAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: Constants.headerStyle.copyWith(fontSize: 18, letterSpacing: 1.5))),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                content, 
                style: Constants.fontRegular.copyWith(height: 1.5, color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                      onPressed: onSkip,
                      child: Text(
                        skipText, 
                        style: Constants.fontRegular.copyWith(fontWeight: FontWeight.bold, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Constants.colorAccent,
                        foregroundColor: Colors.black,
                        elevation: 8,
                        shadowColor: Constants.colorAccent.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onAllow,
                      child: Text(
                        allowText,
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms).fadeIn(),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Constants.colorPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 0.5),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Constants.colorPrimary.withOpacity(0.5), width: 1.5)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "SYSTEM CONFIGURATION", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // GLOWING SECURITY NODE (Shrunk for better fit)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20), // Reduced from 28
                    decoration: BoxDecoration(
                      color: Constants.colorSurface.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Constants.colorPrimary.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Constants.colorPrimary.withOpacity(0.15), 
                          blurRadius: 30, // Reduced from 40
                          spreadRadius: 6  // Reduced from 8
                        ),
                        BoxShadow(
                          color: Constants.colorPrimary.withOpacity(0.3), 
                          blurRadius: 8, 
                          spreadRadius: 2
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded, 
                      size: 40, // Reduced from 56
                      color: Constants.colorPrimary
                    ),
                  ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms),
                ),
                
                const SizedBox(height: 24), // Reduced from 32 to tighten up the spacing
                
                Center(
                  child: Text(
                    "This data stays strictly local and encrypted on your device.",
                    style: Constants.subHeaderStyle.copyWith(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms),
                ),
                const SizedBox(height: 40),

                // BIOMETRIC CYBER-NODE
                _buildSectionHeader(Icons.fingerprint_rounded, "BIOMETRIC SECURITY").animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 12),
                
                GestureDetector(
                  onTap: _isBiometricRegistered ? null : _registerBiometric,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Constants.colorSurface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: _isBiometricRegistered ? Colors.green.withOpacity(0.05) : Constants.colorAccent.withOpacity(0.05),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          _isBiometricRegistered ? Colors.green.withOpacity(0.1) : Constants.colorAccent.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Glowing Edge
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: _isBiometricRegistered ? Colors.green : Constants.colorAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: _isBiometricRegistered ? Colors.green.withOpacity(0.8) : Constants.colorAccent.withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isBiometricRegistered ? Colors.green.withOpacity(0.1) : Constants.colorAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _isBiometricRegistered ? Colors.green.withOpacity(0.3) : Constants.colorAccent.withOpacity(0.3), width: 1),
                                    ),
                                    child: Icon(Icons.fingerprint_rounded, color: _isBiometricRegistered ? Colors.green : Constants.colorAccent, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isBiometricRegistered ? "Vault Lock Registered" : "Setup Biometric Lock",
                                          style: TextStyle(
                                            color: _isBiometricRegistered ? Colors.green : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (!_isBiometricRegistered)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text("Tap to scan your fingerprint", style: Constants.fontRegular.copyWith(fontSize: 11, color: Colors.white54)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_isBiometricRegistered)
                                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                
                const SizedBox(height: 32),

                // IDENTITY MODULE
                _buildSectionHeader(Icons.badge_rounded, "USER IDENTITY").animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: _buildInputDecoration("Alias / Username", Icons.person_outline),
                ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.05),
                
                const SizedBox(height: 24),

                // FINANCIAL MODULE
                _buildSectionHeader(Icons.data_usage_rounded, "FINANCIAL TARGETS").animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 12),
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: _buildInputDecoration("Monthly Target Budget (₹)", Icons.account_balance_wallet_outlined),
                ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.05),
                
                const SizedBox(height: 24),

                // TEMPORAL MODULE
                _buildSectionHeader(Icons.history_rounded, "TEMPORAL CYCLE").animate().fadeIn(delay: 700.ms),
                const SizedBox(height: 12),
                TextField(
                  controller: _salaryDateController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: _buildInputDecoration("Salary Cycle Start Date", Icons.calendar_today_outlined, hint: "Day of the month (1-31)"),
                ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.05),

                const SizedBox(height: 32),

                if (_errorMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Constants.colorError, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ).animate().shake(),
                    ),
                  ),

                // FINALIZE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.colorPrimary,
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: Constants.colorPrimary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _completeSetup,
                    icon: const Icon(Icons.power_settings_new_rounded, size: 20),
                    label: const Text(
                      "INITIALIZE SYSTEM",
                      style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w900),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms).scale(curve: Curves.easeOutBack),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}