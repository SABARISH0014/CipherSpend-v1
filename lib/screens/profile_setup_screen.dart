import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sms_service.dart';
import '../utils/constants.dart';
import '../widgets/sync_overlay.dart';
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
  final SmsService _smsService = SmsService();

  static const platform = MethodChannel('com.example.cipherspend/sms');

  String _errorMessage = "";
  bool _isBiometricRegistered = false;

  bool _isSyncing = false;
  int _totalToSync = 0;
  int _currentSynced = 0;

  // Track which settings page the user is returning from
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

  // Detect when user returns from Android Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_waitingForListenerPermission) {
        setState(() => _waitingForListenerPermission = false);
        _askSmartPromptAndProceed(); // Move to next step in the chain
      } else if (_waitingForUsagePermission) {
        setState(() => _waitingForUsagePermission = false);
        _askDedupePreference(); // Move to next step in the chain
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
    if (!_isBiometricRegistered) {
      setState(
        () => _errorMessage = "Please register your biometric lock first.",
      );
      return;
    }

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
    await prefs.setBool('prefBiometricEnabled', true);
    await prefs.setBool(Constants.prefIsSetupComplete, true);

    // Ask for SMS Permission first
    await Permission.sms.request();

    // Start the Permission Chain
    await _checkStorageAndProceed();
  }

  // --- STEP 1: STORAGE ACCESS ---
  Future<void> _checkStorageAndProceed() async {
    try {
      if (await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        _checkListenerAndProceed();
      } else {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Constants.colorSurface,
              title: const Text(
                "Step 1: Storage Access",
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                "CipherSpend requires storage access to generate and export your monthly visual reports to PDF and CSV formats.\n\n"
                "Tap ALLOW on the next prompt to enable this.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _checkListenerAndProceed(); // Skip
                  },
                  child: const Text(
                    "SKIP",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.colorPrimary,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await [
                      Permission.storage,
                      Permission.manageExternalStorage,
                    ].request();
                    _checkListenerAndProceed(); // Move to next step
                  },
                  child: const Text(
                    "ALLOW",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
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
      print("Warning: Native check failed - $e");
      isEnabled = false; 
    }

    if (isEnabled) {
      _askSmartPromptAndProceed();
    } else {
      if (!mounted) return; 
      
      // [FIX] Removed early flag assignment here

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Constants.colorSurface,
          title: const Text(
            "Step 2: Enable UPI Tracking",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "To track GPay, PhonePe, and Paytm transactions automatically, CipherSpend needs 'Notification Access'.\n\n"
            "1. Tap ENABLE below.\n"
            "2. Find 'CipherSpend' in the list.\n"
            "3. Toggle it ON and press Allow.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _askSmartPromptAndProceed();
              },
              child: const Text(
                "SKIP",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorPrimary,
              ),
              onPressed: () async {
                // [FIX] The flag is now safely assigned ONLY when the user clicks the button
                setState(() {
                  _waitingForListenerPermission = true;
                });
                Navigator.pop(ctx);
                await platform.invokeMethod('openNotificationSettings');
              },
              child: const Text(
                "ENABLE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
      print("Warning: Native check failed - $e");
      hasAccess = false; 
    }

    if (hasAccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smart_prompt_enabled', true);
      _askDedupePreference();
    } else {
      if (!mounted) return;
      
      // [FIX] Removed early flag assignment here

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Constants.colorSurface,
          title: const Text(
            "Step 3: Smart Prompts",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "If a payment app doesn't send a notification, CipherSpend can detect when you close the app and proactively ask if you made a payment.\n\n"
            "To enable this, we need 'Usage Access'.\n"
            "1. Tap ENABLE below.\n"
            "2. Find 'CipherSpend' and turn ON 'Permit usage access'.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('smart_prompt_enabled', false);
                _askDedupePreference();
              },
              child: const Text(
                "SKIP",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorPrimary,
              ),
              onPressed: () async {
                // [FIX] The flag is now safely assigned ONLY when the user clicks the button
                setState(() {
                  _waitingForUsagePermission = true;
                });
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('smart_prompt_enabled', true);
                await platform.invokeMethod('openUsageAccessSettings');
              },
              child: const Text(
                "ENABLE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Constants.colorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.difference, color: Constants.colorPrimary),
            SizedBox(width: 10),
            Text(
              "Duplicate Handling",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Banks and apps often send multiple alerts for the same transaction (e.g., an SMS and a GPay notification).\n\n"
          "Should CipherSpend automatically drop duplicates, or ask you every time one is detected?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('dedupe_rule', 'ask');
              _runInitialSync();
            },
            child: const Text("ASK ME", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.colorPrimary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('dedupe_rule', 'auto_drop');
              _runInitialSync();
            },
            child: const Text(
              "AUTO-DROP",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 5: FINAL SYNC ---
  Future<void> _runInitialSync() async {
    setState(() {
      _isSyncing = true;
    });

    await _smsService.syncHistory(
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _currentSynced = current;
            _totalToSync = total;
          });
        }
      },
    );

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
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
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

                    // Biometric Card
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
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_isBiometricRegistered)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Inputs
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "User Name",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Monthly Budget (₹)",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _salaryDateController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Salary Cycle Start Date",
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: "Day of the month (1-31)",
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Constants.colorSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_errorMessage.isNotEmpty) ...[
                      Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Constants.colorError,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 16),

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
                          "Finalize & Sync",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isSyncing)
            SyncOverlay(
              total: _totalToSync,
              current: _currentSynced,
              status: "Importing Financial History...",
            ),
        ],
      ),
    );
  }
}