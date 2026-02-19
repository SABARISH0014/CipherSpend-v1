import '../models/transaction_model.dart';
import 'ai_service.dart'; // Import the TFLite Service
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ParserService {
  // --- 1. REGEX PATTERNS ---
  static final RegExp _amountRegex = RegExp(
      r'(?:rs\.?|inr|₹|amount)\s*[:\-\s]*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
      caseSensitive: false);

  static final RegExp _merchantRegex = RegExp(
      r'(?:paid\s+to|sent\s+to|transfer\s+to|purchase\s+at|txn\s+at)\s+([a-zA-Z0-9\s\.]+)',
      caseSensitive: false);

  static final RegExp _upiRegex =
      RegExp(r'(upi|vpa|paytm|gpay|phonepe|bhim|qr)', caseSensitive: false);

  // --- 2. MAIN PARSING FUNCTION ---
  static TransactionModel? parseSMS(String sender, String body, int timestamp) {
    String cleanBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    String lowerBody = cleanBody.toLowerCase();

    // A. SPAM FILTER
    if (_isSpam(lowerBody, sender)) return null;

    // B. AMOUNT EXTRACTION
    double amount = _extractAmount(cleanBody);
    if (amount == 0.0) return null;

    // C. MERCHANT & TYPE
    String merchant = _extractMerchant(cleanBody);
    String type = _determineType(lowerBody);

    // D. INTELLIGENCE: TFLite Classification (Replaces Keyword Scoring)
    // We pass the merchant + body for maximum context
    String category = AIService().predictCategory("$merchant $cleanBody");

    // E. HASH GENERATION
    String hash = _generateHash(sender, cleanBody, timestamp);

    return TransactionModel(
      hash: hash,
      sender: sender,
      body: cleanBody,
      amount: amount,
      category: category,
      type: type,
      timestamp: timestamp,
      merchant: merchant,
    );
  }

  // --- 3. HELPER LOGIC ---

  static bool _isSpam(String body, String sender) {
    if (RegExp(r'^\d{10}$').hasMatch(sender)) return true;

    // Reject Income (Credits/Received)
    if (body.contains("credited") || body.contains("received")) return true;

    List<String> blacklist = [
      "win",
      "lottery",
      "prize",
      "offer",
      "discount",
      "loan",
      "otp",
      "code is"
    ];

    for (var word in blacklist) {
      if (body.contains(word)) return true;
    }
    return false;
  }

  static double _extractAmount(String body) {
    final match = _amountRegex.firstMatch(body);
    if (match != null) {
      String cleanAmount = match.group(1)!.replaceAll(',', '');
      return double.tryParse(cleanAmount) ?? 0.0;
    }
    return 0.0;
  }

  static String _extractMerchant(String body) {
    final match = _merchantRegex.firstMatch(body);
    return match != null ? match.group(1)!.trim() : "Unknown Merchant";
  }

  static String _determineType(String body) {
    if (_upiRegex.hasMatch(body)) return "UPI";
    if (body.contains("card")) return "Card";
    return "Bank Transfer";
  }

  static String _generateHash(String sender, String body, int timestamp) {
    var bytes = utf8.encode("$sender$body$timestamp");
    return sha256.convert(bytes).toString();
  }
}
