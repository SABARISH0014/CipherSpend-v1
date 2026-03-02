import '../models/transaction_model.dart';
import 'ai_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ParserService {
  // --- 1. REGEX PATTERNS ---
  // Improved amount regex to handle "INR 500.00" or "Rs.500" more reliably
  static final RegExp _amountRegex = RegExp(
      r'(?:rs\.?|inr|₹|amount|debited by)\s*[:\-\s]*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
      caseSensitive: false);

  // Merchant regex: Captures the receiver name more accurately
  static final RegExp _merchantRegex = RegExp(
      r'(?:paid to|sent to|transfer to|purchase at|txn at|to vpa|for)\s+([a-zA-Z0-9\s\.\@\-\_]+)',
      caseSensitive: false);

  static final RegExp _upiRegex =
      RegExp(r'(upi|vpa|paytm|gpay|phonepe|bhim|qr)', caseSensitive: false);

  // --- 2. MAIN PARSING FUNCTION ---
  static TransactionModel? parseSMS(String sender, String body, int timestamp) {
    // 1. Basic Cleaning
    String cleanBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    String lowerBody = cleanBody.toLowerCase();

    // A. SPAM & INCOME FILTER
    // We only want debited/expense transactions for CipherSpend
    if (_isSpamOrIncome(lowerBody, sender)) return null;

    // B. AMOUNT EXTRACTION
    double amount = _extractAmount(cleanBody);
    if (amount == 0.0) return null;

    // C. MERCHANT & TYPE
    String merchant = _extractMerchant(cleanBody);
    String type = _determineType(lowerBody);

    // D. INTELLIGENCE: TFLite Classification
    // Ensure AIService is initialized before this call!
    String category = "Uncategorized";
    try {
      // Passing both merchant and body helps the AI distinguish between
      // "Amazon" (Shopping) vs "Amazon Pay" (Utility)
      category = AIService().predictCategory("$merchant $cleanBody");
    } catch (e) {
      print("AI Prediction failed in Parser: $e");
    }

    // E. HASH GENERATION (Idempotency)
    // This prevents adding the same SMS twice if the sync runs again
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

  static bool _isSpamOrIncome(String body, String sender) {
    // Filter out personal 10-digit mobile numbers
    if (RegExp(r'^\d{10}$').hasMatch(sender)) return true;

    // REJECT Income (We are an Expense Tracker)
    if (body.contains("credited") ||
        body.contains("received") ||
        body.contains("refund") ||
        body.contains("deposited")) return true;

    // General Spam Blacklist
    List<String> blacklist = [
      "win",
      "lottery",
      "prize",
      "offer",
      "discount",
      "loan",
      "otp",
      "code is",
      "verification",
      "urgent"
    ];

    for (var word in blacklist) {
      if (body.contains(word)) return true;
    }
    return false;
  }

  static double _extractAmount(String body) {
    final match = _amountRegex.firstMatch(body);
    if (match != null) {
      // Remove commas from strings like "1,250.00" before parsing
      String cleanAmount = match.group(1)!.replaceAll(',', '');
      return double.tryParse(cleanAmount) ?? 0.0;
    }
    return 0.0;
  }

  static String _extractMerchant(String body) {
    final match = _merchantRegex.firstMatch(body);
    if (match != null) {
      String name = match.group(1)!.trim();
      name = name.split(RegExp(r'\s(on|at|from|via)\s'))[0]; // Extra cleanup
      return name;
    }

    // Fallback: If it's a UPI transaction but we missed the "paid to",
    // try to find any VPA (e.g., name@upi) in the text.
    final vpaMatch = RegExp(r'([a-zA-Z0-9\.\_\-]+@[a-zA-Z]+)').firstMatch(body);
    if (vpaMatch != null) {
      return vpaMatch.group(1)!;
    }

    return "Unknown Merchant";
  }

  static String _determineType(String body) {
    if (_upiRegex.hasMatch(body)) return "UPI";
    if (body.contains("card") ||
        body.contains("visa") ||
        body.contains("mastercard")) return "Card";
    return "Bank Transfer";
  }

  static String _generateHash(String sender, String body, int timestamp) {
    var bytes = utf8.encode("$sender$body$timestamp");
    return sha256.convert(bytes).toString();
  }
}
