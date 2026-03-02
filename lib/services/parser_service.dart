import '../models/transaction_model.dart';
import 'ai_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ParserService {
  // --- 1. REGEX PATTERNS ---
  // Added "refund of" to capture refund amounts
  static final RegExp _amountRegex = RegExp(
      r'(?:rs\.?|inr|₹|amount|debited by|refund of)\s*[:\-\s]*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
      caseSensitive: false);

  // Added "from" and "in" to capture merchants better
  static final RegExp _merchantRegex = RegExp(
      r'(?:paid to|sent to|transfer to|purchase at|txn at|to vpa|for|from|in)\s+([a-zA-Z0-9\s\.\@\-\_]+)',
      caseSensitive: false);

  static final RegExp _upiRegex =
      RegExp(r'(upi|vpa|paytm|gpay|phonepe|bhim|qr)', caseSensitive: false);

  // --- 2. MAIN PARSING FUNCTION ---
  static TransactionModel? parseSMS(String sender, String body, int timestamp) {
    String cleanBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    String lowerBody = cleanBody.toLowerCase();

    // A. AI INTELLIGENCE: Get Category First
    String category = "Uncategorized";
    try {
      category = AIService().predictCategory(cleanBody);
    } catch (e) {
      print("AI Prediction failed: $e");
    }

    // B. THE GATEKEEPER (Replaces the old hardcoded blacklist)
    // If the AI explicitly says to ignore this (e.g. OTPs, delivery updates) or it's Spam, drop it!
    if (category == "Ignore" || category == "Spam") {
      print("🚫 Dropped SMS (AI flagged as $category): $cleanBody");
      return null;
    }

    // Drop 10-digit personal numbers unless the AI strongly categorizes it
    if (RegExp(r'^\d{10}$').hasMatch(sender) && category == "Uncategorized") {
      return null;
    }

    // C. AMOUNT EXTRACTION
    double amount = _extractAmount(cleanBody);
    if (amount == 0.0) {
      print("🚫 Dropped SMS (No amount found): $cleanBody");
      return null;
    }

    // D. MERCHANT & TYPE
    String merchant = _extractMerchant(cleanBody);
    String type = _determineType(lowerBody);

    // E. HASH GENERATION (Idempotency)
    String hash = _generateHash(sender, cleanBody, timestamp);

    return TransactionModel(
      hash: hash,
      sender: sender,
      body: cleanBody,
      amount: amount,
      category: category, // Save the AI Category
      type: type,
      timestamp: timestamp,
      merchant: merchant,
    );
  }

  // --- 3. HELPER LOGIC ---
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
    if (match != null) {
      String name = match.group(1)!.trim();
      // Clean up common trailing words
      name = name.split(RegExp(r'\s(on|at|from|via|successful)\s'))[0];
      return name;
    }

    // Fallback: Check for VPAs (UPI IDs)
    final vpaMatch = RegExp(r'([a-zA-Z0-9\.\_\-]+@[a-zA-Z]+)').firstMatch(body);
    if (vpaMatch != null) return vpaMatch.group(1)!;

    // Fallback: Check for ATM withdrawals
    if (body.toLowerCase().contains('atm')) return "ATM";

    return "Unknown Merchant";
  }

  static String _determineType(String body) {
    if (_upiRegex.hasMatch(body)) return "UPI";
    if (body.contains("card") ||
        body.contains("visa") ||
        body.contains("mastercard")) return "Card";
    if (body.contains("atm") || body.contains("cash")) return "Cash";
    return "Bank Transfer";
  }

  static String _generateHash(String sender, String body, int timestamp) {
    var bytes = utf8.encode("$sender$body$timestamp");
    return sha256.convert(bytes).toString();
  }
}
