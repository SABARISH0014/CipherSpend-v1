import 'package:flutter/material.dart';
import '../services/parser_service.dart';
import '../services/ai_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
<<<<<<< Updated upstream
=======
import 'interactive_training_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
>>>>>>> Stashed changes

class DebugParserScreen extends StatefulWidget {
  const DebugParserScreen({super.key});

  @override
  State<DebugParserScreen> createState() => _DebugParserScreenState();
}

class _DebugParserScreenState extends State<DebugParserScreen> {
  final TextEditingController _smsController = TextEditingController();
  String _resultLog = "Waiting for input...";
  bool _isAiLoaded = false;

  @override
  void initState() {
    super.initState();
    _ensureAiLoaded();
  }

  Future<void> _ensureAiLoaded() async {
    // Ensure AI is ready for the test
    await AIService().loadModel();
    setState(() {
      _isAiLoaded = true;
    });
  }

  void _runParser() {
    String smsBody = _smsController.text.trim();
    if (smsBody.isEmpty) return;

    // Simulate a standard sender and current time
    String sender = "VM-HDFC";
    int timestamp = DateTime.now().millisecondsSinceEpoch;

    final TransactionModel? txn =
        ParserService.parseSMS(sender, smsBody, timestamp);

    setState(() {
      if (txn == null) {
        _resultLog = "❌ PARSING FAILED or IGNORED\n"
            "Reason: AI categorized as 'Spam'/'Ignore' or no amount found.";
      } else {
        _resultLog = "✅ PARSING SUCCESSFUL:\n\n"
            "💰 Amount:   ₹${txn.amount}\n"
            "🏪 Merchant: ${txn.merchant}\n"
            "🏷 Category: ${txn.category} (AI)\n"
            "💳 Type:     ${txn.type}\n"
            "🔑 Hash:     ${txn.hash.substring(0, 10)}...";
      }
    });
  }

  // Helper to paste sample messages quickly
  void _pasteSample(String text) {
    _smsController.text = text;
    _runParser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("SMS Parser Debugger"),
        backgroundColor: Constants.colorSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "AI Status: ${_isAiLoaded ? "🟢 ONLINE" : "🔴 LOADING..."}",
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Input Area
            const Text("Paste SMS Text:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _smsController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Constants.colorSurface,
                hintText: "e.g., Rs. 500 debited from a/c... for Zomato",
                hintStyle: const TextStyle(color: Colors.white24),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TapScaleWrapper(
                onTap: _runParser,
                child: Container(
                  alignment: Alignment.center,
                  decoration: Constants.glowingBorderDecoration.copyWith(
                    color: Constants.colorPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("RUN PARSER",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Result Log
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _parsingFailed
                  ? Constants.dangerGlowDecoration.copyWith(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                      color: Colors.black,
                    )
                  : Constants.glowingBorderDecoration.copyWith(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                      color: Colors.black,
                    ),
              child: Text(
                _resultLog,
                style: TextStyle(
                    color: _parsingFailed ? Colors.redAccent : Constants.colorPrimary,
                    fontFamily: 'monospace',
                ),
              ),
            ).animate(target: _resultLog == "Waiting for input..." ? 0 : 1).fade(duration: 300.ms),

<<<<<<< Updated upstream
=======
            if (_parsingFailed)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TapScaleWrapper(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InteractiveTrainingScreen(
                            smsBody: _lastSmsBody,
                            sender: _lastSender,
                          ),
                        ),
                      );

                      if (result == true) {
                        _runParser();
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: Constants.glassDecoration.copyWith(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.model_training, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text(
                            "Train Manually",
                            style: TextStyle(
                                color: Colors.blueAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

>>>>>>> Stashed changes
            const SizedBox(height: 30),
            const Divider(color: Colors.white24),
            const Text("Quick Samples (Tap to Test):",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),

            _buildSampleTile("Sent Rs. 350 to Zomato via UPI"),
            _buildSampleTile("INR 1,200 debited for Uber Trip on 12-March"),
            _buildSampleTile("Acct XX123 credited with Rs. 50,000 (Salary)"),
            _buildSampleTile("Your OTP is 445566. Do not share."),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleTile(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TapScaleWrapper(
        onTap: () => _pasteSample(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: Constants.glassDecoration.copyWith(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}
