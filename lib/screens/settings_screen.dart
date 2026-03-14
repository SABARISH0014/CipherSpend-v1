import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
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
  static const platform = MethodChannel('com.example.cipherspend/sms');

  // State for preferences
  bool _autoDropDuplicates = false;
  bool _smartPromptEnabled = false;
  bool _storagePermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load preferences on screen start
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool storageGranted = await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted;

    setState(() {
      _autoDropDuplicates = (prefs.getString('dedupe_rule') == 'auto_drop');
      _smartPromptEnabled = prefs.getBool('smart_prompt_enabled') ?? false;
      _storagePermissionGranted = storageGranted;
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
          SnackBar(
            content: Text("Auth Failed. Cannot Wipe Data.", style: Constants.fontRegular.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Constants.colorError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BackdropFilter(
          filter: Constants.glassBlur,
          child: const Center(
            child: CircularProgressIndicator(color: Constants.colorError),
          ),
        ),
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
          SnackBar(
            content: Text("♻ System Reset Complete", style: Constants.fontRegular.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Constants.colorPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Wipe Failed: $e", style: const TextStyle(color: Colors.white)),
            backgroundColor: Constants.colorError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- UI HELPER: High-Tech Micro Headers ---
  Widget _buildSectionHeader(IconData icon, String title, {Color color = Constants.colorAccent}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color == Constants.colorAccent ? Colors.white.withValues(alpha: 0.5) : color,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- UI HELPER: Glowing Cyber-Node Tiles ---
  Widget _buildGlassTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    Color color = Colors.white70,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.03),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Constants.colorSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Glowing Neon Strip
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 8, spreadRadius: 1)
                    ]
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      title,
                      style: Constants.fontRegular.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(subtitle, style: Constants.fontRegular.copyWith(fontSize: 11, color: Colors.white54)),
                    ),
                    trailing: trailing,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            "SYSTEM CONFIG", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // 1. SECURITY SECTION
            _buildSectionHeader(Icons.security_rounded, "SYSTEM ACCESS").animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),
            
            _buildGlassTile(
              icon: Icons.lock_outline_rounded,
              title: "Lock Vault",
              subtitle: "Securely encrypt and logout",
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
              onTap: _logout,
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic),

            const SizedBox(height: 32),

            // 2. PERMISSIONS & AUTOMATION SECTION
            _buildSectionHeader(Icons.memory_rounded, "AUTOMATION & PERMISSIONS").animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),

            _buildGlassTile(
              icon: Icons.folder_shared_rounded,
              title: "Storage Access",
              subtitle: "Required to export visual reports",
              trailing: Switch(
                activeThumbColor: Constants.colorPrimary,
                activeTrackColor: Constants.colorPrimary.withValues(alpha: 0.3),
                inactiveTrackColor: Colors.black45,
                inactiveThumbColor: Colors.white54,
                value: _storagePermissionGranted,
                onChanged: (value) async {
                  if (value) {
                    await [
                      Permission.storage,
                      Permission.manageExternalStorage,
                    ].request();
                    bool granted = await Permission.storage.isGranted ||
                        await Permission.manageExternalStorage.isGranted;
                    setState(() => _storagePermissionGranted = granted);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Permissions cannot be disabled in-app. Please revoke it from Android Settings.",
                          style: Constants.fontRegular.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.orangeAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    openAppSettings();
                  }
                },
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic),

            _buildGlassTile(
              icon: Icons.difference_rounded,
              title: "Auto-Drop Duplicates",
              subtitle: "Silently ignore overlapping UPI/SMS alerts",
              trailing: Switch(
                activeThumbColor: Constants.colorPrimary,
                activeTrackColor: Constants.colorPrimary.withValues(alpha: 0.3),
                inactiveTrackColor: Colors.black45,
                inactiveThumbColor: Colors.white54,
                value: _autoDropDuplicates,
                onChanged: _toggleDedupe,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic),

            _buildGlassTile(
              icon: Icons.auto_awesome_rounded,
              title: "Smart Prompts",
              subtitle: "Ask to log expense after using GPay/PhonePe",
              trailing: Switch(
                activeThumbColor: Constants.colorPrimary,
                activeTrackColor: Constants.colorPrimary.withValues(alpha: 0.3),
                inactiveTrackColor: Colors.black45,
                inactiveThumbColor: Colors.white54,
                value: _smartPromptEnabled,
                onChanged: (value) async {
                  if (value) {
                    try {
                      bool hasAccess = await platform.invokeMethod('hasUsageAccess');
                      if (!hasAccess) {
                        await platform.invokeMethod('openUsageAccessSettings');
                      }
                    } catch (e) {
                      debugPrint("Failed to invoke native usage methods: $e");
                    }
                  }
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('smart_prompt_enabled', value);
                  setState(() => _smartPromptEnabled = value);
                },
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideX(begin: -0.05, curve: Curves.easeOutCubic),

            const SizedBox(height: 40),

            // 3. DANGER ZONE
            _buildSectionHeader(Icons.warning_rounded, "DANGER ZONE", color: Constants.colorError).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),

            // NUCLEAR WIPE (Glowing Red Tile)
            _buildGlassTile(
              icon: Icons.delete_forever_rounded,
              title: "NUCLEAR WIPE",
              subtitle: "Factory Reset: Permanently deletes all encrypted ledgers.",
              color: Constants.colorError,
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Constants.colorError, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => BackdropFilter(
                    filter: Constants.glassBlur,
                    child: Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: Constants.glassDecoration.copyWith(
                          border: Border.all(color: Constants.colorError.withValues(alpha: 0.8), width: 2),
                          boxShadow: [
                            BoxShadow(color: Constants.colorError.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5)
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Constants.colorError, size: 60)
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(begin: const Offset(1,1), end: const Offset(1.1,1.1), duration: 1.seconds),
                            const SizedBox(height: 16),
                            Text(
                              "CRITICAL WARNING",
                              style: Constants.headerStyle.copyWith(color: Constants.colorError, fontSize: 22, letterSpacing: 1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "This action cannot be undone. All offline data will be permanently wiped.\n\nThe system will return to Factory Settings.",
                              textAlign: TextAlign.center,
                              style: Constants.fontRegular.copyWith(height: 1.5, color: Colors.white70),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    child: Text("CANCEL", style: Constants.fontRegular.copyWith(letterSpacing: 1)),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      backgroundColor: Constants.colorError,
                                      foregroundColor: Colors.white,
                                      elevation: 8,
                                      shadowColor: Constants.colorError.withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      "ERASE VAULT",
                                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _triggerKillSwitch();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                  ),
                );
              },
            ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}