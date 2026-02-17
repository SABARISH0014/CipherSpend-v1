import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sms_bridge.dart';
import '../utils/constants.dart';
import 'mpin_setup_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _status = "Waiting for input...";
  String? _challengeCode;
  bool _isVerifying = false;

  void _startVerification() async {
    // 1. Request Permissions
    if (await Permission.sms.request().isGranted) {
      setState(() {
        _status = "Generating Challenge...";
        _isVerifying = true;
      });

      // 2. Generate Random Code
      _challengeCode = "#CS-${Random().nextInt(9000) + 1000}";

      // 3. Start Listening BEFORE sending
      SMSBridge.smsStream.listen((event) {
        final body = event['body'] as String;
        // Check if the incoming SMS contains our specific challenge code
        if (body.contains(_challengeCode!)) {
          // SUCCESS: Identity Verified
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MPINSetupScreen()),
            );
          }
        }
      });

      // 4. Send Loopback SMS
      await SMSBridge.sendLoopback(_phoneController.text, _challengeCode!);
      setState(() => _status = "Verifying Loopback Signal...");
    } else {
      setState(() {
        _status = "SMS Permission Denied";
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Air-Gapped Identity"),
        backgroundColor: Constants.colorSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Constants.colorPrimary),
            const SizedBox(height: 20),
            const Text("Verify SIM Ownership", style: Constants.headerStyle),
            const SizedBox(height: 10),
            const Text(
              "We will send an SMS to your own number to verify identity without internet.",
              textAlign: TextAlign.center,
              style: Constants.subHeaderStyle,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Enter Your Phone Number",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Constants.colorPrimary),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),
            _isVerifying
                ? const CircularProgressIndicator(color: Constants.colorPrimary)
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.colorPrimary,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _startVerification,
                      child: const Text("Verify Identity",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
