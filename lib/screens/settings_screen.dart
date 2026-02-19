import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';
import 'verification_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();

  // --- LOGOUT LOGIC ---
  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
      (route) => false,
    );
  }

  // --- KILL SWITCH LOGIC (The Fix) ---
  Future<void> _triggerKillSwitch() async {
    // 1. Authenticate (Safety Check)
    bool auth = await _auth.authenticateBiometric();
    if (!auth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Auth Failed. Cannot Wipe Data.")));
      }
      return;
    }

    // 2. Show "Wiping..." Dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    try {
      // 3. NUCLEAR WIPE
      // Close & Delete Database
      await DBService().deleteDB();

      // Delete Profile, Keys, and Settings
      await _auth.nuclearWipe();

      // Artificial delay to ensure disk operations finish
      await Future.delayed(const Duration(seconds: 2));

      // 4. RESET APP (Don't close it, just restart navigation)
      if (mounted) {
        // Remove loading dialog
        Navigator.of(context).pop();

        // Navigate to Start (Verification Screen)
        // Since data is gone, this screen will now show "Setup Vault"
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerificationScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("♻ System Reset Complete")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Wipe Failed: $e")));
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ListTile(
              tileColor: Constants.colorSurface,
              leading: const Icon(Icons.lock, color: Colors.white),
              title: const Text("Logout (Lock Vault)",
                  style: TextStyle(color: Colors.white)),
              onTap: _logout,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 40),
            const Text("DANGER ZONE",
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.withOpacity(0.1),
              ),
              child: ListTile(
                leading: const Icon(Icons.delete_forever,
                    color: Colors.red, size: 30),
                title: const Text("KILL SWITCH",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("Factory Reset: Wipes DB & Profile.",
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            backgroundColor: Constants.colorSurface,
                            title: const Text("⚠ NUCLEAR WARNING",
                                style: TextStyle(color: Colors.red)),
                            content: const Text(
                                "This will PERMANENTLY DELETE:\n1. All Transaction History\n2. User Profile\n3. MPIN & Keys\n\nThe app will reset to Factory Settings.",
                                style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                  child: const Text("CANCEL"),
                                  onPressed: () => Navigator.pop(ctx)),
                              TextButton(
                                  child: const Text("WIPE EVERYTHING",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _triggerKillSwitch();
                                  }),
                            ],
                          ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
