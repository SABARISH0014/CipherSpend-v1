import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _dbStatus = "Checking Vault...";

  @override
  void initState() {
    super.initState();
    _initVault();
  }

  Future<void> _initVault() async {
    try {
      // Trigger DB init to ensure encryption key works
      await DBService().database;
      setState(() => _dbStatus = "Vault Decrypted & Active");
    } catch (e) {
      setState(() => _dbStatus = "Encryption Error: $e");
    }
  }

  Future<void> _testLock() async {
    bool authenticated = await AuthService().authenticateBiometric();
    if (authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric Unlock Successful")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Biometric Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("CipherSpend Vault"),
        backgroundColor: Constants.colorSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint),
            onPressed: _testLock,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Constants.colorPrimary),
            const SizedBox(height: 20),
            const Text("Secure Environment", style: Constants.headerStyle),
            const SizedBox(height: 10),
            Text(
              _dbStatus,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Constants.colorSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: const Column(
                children: [
                  Text("Phase 1 Complete",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white)),
                  SizedBox(height: 10),
                  Text("• Identity Verified (Loopback)",
                      style: TextStyle(color: Colors.grey)),
                  Text("• MPIN Hashed (SHA-256)",
                      style: TextStyle(color: Colors.grey)),
                  Text("• DB Encrypted (SQLCipher)",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
