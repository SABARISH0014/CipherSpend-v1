import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';
import 'verification_screen.dart';
import 'debug_parser_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();

  // State for preferences
  bool _autoDropDuplicates = false;
  bool _smartPromptEnabled = false; // [NEW] Smart Prompt State

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load preferences on screen start
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoDropDuplicates = (prefs.getString('dedupe_rule') == 'auto_drop');
      _smartPromptEnabled =
          prefs.getBool('smart_prompt_enabled') ?? false; // [NEW] Load state
    });
  }

  // Save Dedupe preference when toggled
  Future<void> _toggleDedupe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dedupe_rule', value ? 'auto_drop' : 'ask');
    setState(() {
      _autoDropDuplicates = value;
    });
  }

  // --- LOGOUT LOGIC ---
  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
      (route) => false,
    );
  }

  // --- KILL SWITCH LOGIC ---
  Future<void> _triggerKillSwitch() async {
    bool auth = await _auth.authenticateBiometric();
    if (!auth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Auth Failed. Cannot Wipe Data.")),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    try {
      await DBService().deleteDB();
      await _auth.nuclearWipe();
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerificationScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("♻ System Reset Complete")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Wipe Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Security Settings"),
        backgroundColor: Constants.colorSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. LOGOUT TILE
            ListTile(
              tileColor: Constants.colorSurface,
              leading: const Icon(Icons.lock, color: Colors.white),
              title: const Text(
                "Logout (Lock Vault)",
                style: TextStyle(color: Colors.white),
              ),
              onTap: _logout,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 20),

            // 2. DEBUG PARSER TILE
            ListTile(
              tileColor: Constants.colorSurface,
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text(
                "Debug SMS Parser",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Test AI & Extraction logic",
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugParserScreen()),
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 20),

            // 3. AUTO-DROP TOGGLE
            SwitchListTile(
              activeColor: Constants.colorPrimary,
              tileColor: Constants.colorSurface,
              title: const Text(
                "Auto-Drop Duplicates",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Silently ignore duplicate SMS/Notifications",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              value: _autoDropDuplicates,
              onChanged: _toggleDedupe,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 20),

            // 4. [NEW] SMART PROMPTS TOGGLE
            SwitchListTile(
              activeColor: Constants.colorPrimary,
              tileColor: Constants.colorSurface,
              title: const Text(
                "Smart Prompts",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Ask to log expense after using GPay/PhonePe",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              value: _smartPromptEnabled,
              onChanged: (value) async {
                if (value) {
                  // Ask for Android Usage Access Permission
                  try {
                    bool hasAccess = await const MethodChannel(
                      'com.example.cipherspend/sms',
                    ).invokeMethod('hasUsageAccess');
                    if (!hasAccess) {
                      await const MethodChannel(
                        'com.example.cipherspend/sms',
                      ).invokeMethod('openUsageAccessSettings');
                    }
                  } catch (e) {
                    print("Failed to invoke native usage methods: $e");
                  }
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('smart_prompt_enabled', value);
                setState(() => _smartPromptEnabled = value);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 40),

            // 5. DANGER ZONE
            const Text(
              "DANGER ZONE",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            // 6. KILL SWITCH
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.withOpacity(0.1),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 30,
                ),
                title: const Text(
                  "KILL SWITCH",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  "Factory Reset: Wipes DB & Profile.",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Constants.colorSurface,
                      title: const Text(
                        "⚠ NUCLEAR WARNING",
                        style: TextStyle(color: Colors.red),
                      ),
                      content: const Text(
                        "This will PERMANENTLY DELETE:\n1. All Transaction History\n2. User Profile\n3. MPIN & Keys\n\nThe app will reset to Factory Settings.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          child: const Text("CANCEL"),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        TextButton(
                          child: const Text(
                            "WIPE EVERYTHING",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _triggerKillSwitch();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
