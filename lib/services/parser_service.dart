import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import 'ai_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ParserService {
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|₹|amount|debited by|refund of|txn of)\s*[:\-\s]*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _notifAmountRegex = RegExp(
    r'(?:₹|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Added '|to' to catch "Paid ... to Starbucks"
  static final RegExp _merchantRegex = RegExp(
    r'(?:paid to|sent to|transfer to|purchase at|txn at|to vpa|for|from|in|to)\s+([a-zA-Z0-9\s\.\@\-\_]+)',
    caseSensitive: false,
  );

  static final RegExp _upiRegex = RegExp(
    r'(upi|vpa|paytm|gpay|phonepe|bhim|qr)',
    caseSensitive: false,
  );

  static final List<RegExp> _ignorePatterns = [
    RegExp(
      r'(?:data|internet).*(?:consumed|used|exhausted|left|remaining)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:recharge|plan|pack|offer|validity|expired|quota|benefit)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:get|claim).*(?:gb|mb).*(?:at|@)\s*(?:rs|₹)',
      caseSensitive: false,
    ),
    RegExp(r'(?:otp|verification code|auth code|login)', caseSensitive: false),
    RegExp(r'(?:http|www|bit\.ly|goo\.gl|\.in/|\.com/)', caseSensitive: false),
    RegExp(
      r'(?:congratulations|winner|lucky|prize|reward)',
      caseSensitive: false,
    ),
    RegExp(r'(?:loan|pre-approved|limit increase)', caseSensitive: false),
  ];

  @visibleForTesting
  static bool isSpam(String cleanBody) {
    for (var pattern in _ignorePatterns) {
      if (pattern.hasMatch(cleanBody)) return true;
    }
    return false;
  }

  static TransactionModel? parseSMS(String sender, String body, int timestamp) {
    String cleanBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    String lowerBody = cleanBody.toLowerCase();

    bool isNotification = [
      "GPay",
      "PhonePe",
      "Paytm",
      "BHIM",
      "AmazonPay",
      "Freecharge",
    ].contains(sender);

    if (isNotification) {
      // 1. Broadened keywords to catch all payment app variations
      bool isExpense = RegExp(
        r'(paid|sent|debited|payment|to vpa|successful)',
        caseSensitive: false,
      ).hasMatch(lowerBody);
      bool isIncomeOrPromo = RegExp(
        r'(received|credited|cashback|won|reward|offer)',
        caseSensitive: false,
      ).hasMatch(lowerBody);

      if (!isExpense || isIncomeOrPromo) {
        return null; // Safely drop incoming money or cashback promos
      }
    } else if (isSpam(cleanBody)) {
      return null;
    }

    String category = "Uncategorized";
    try {
      category = AIService().predictCategory(cleanBody);
    } catch (e) {
      print("AI Prediction failed: $e");
    }

    String lowerCat = category.toLowerCase();

    // 2. PROTECT NOTIFICATIONS FROM AI SPAM FILTER
    // Since we already verified it's a valid expense above, we override the AI.
    if (isNotification &&
        (lowerCat == "ignore" ||
            lowerCat == "spam" ||
            lowerCat == "uncategorized")) {
      category = "Transaction"; // Safe default for UPI
    } else if (!isNotification &&
        (lowerCat == "ignore" || lowerCat == "spam")) {
      return null; // Drop standard SMS spam
    }

    double amount = 0.0;
    String merchant = "Unknown";
    String type = "Bank Transfer";

    if (isNotification) {
      amount = extractAmount(cleanBody, isNotif: true);
      merchant = extractMerchant(cleanBody);
      type = "UPI";
    } else {
      amount = extractAmount(cleanBody, isNotif: false);
      if (amount == 0.0) return null;
      merchant = extractMerchant(cleanBody);
      type = determineType(lowerBody);
    }

    if (amount == 0.0) return null;
    String hash = generateHash(sender, cleanBody, timestamp);

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

  @visibleForTesting
  static double extractAmount(String body, {bool isNotif = false}) {
    var match = _amountRegex.firstMatch(body);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0.0;
    }
    if (isNotif) {
      match = _notifAmountRegex.firstMatch(body);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
    }
    return 0.0;
  }

  @visibleForTesting
  static String extractMerchant(String body) {
    final match = _merchantRegex.firstMatch(body);
    if (match != null) {
      String name = match.group(1)!.trim();

      // [FIXED] Regex now allows End of String ($) or Space (\s+) as a delimiter.
      // Used non-capturing group (?:...) to ensure split doesn't return the delimiter.
      name = name.split(
        RegExp(
          r'\s+(?:on|at|from|via|successful|ref|txn)(?:\s+|$)',
          caseSensitive: false,
        ),
      )[0];

      name = name.replaceAll(RegExp(r'[.\-_]+$'), '');
      return name.trim();
    }
    final vpaMatch = RegExp(r'([a-zA-Z0-9\.\_\-]+@[a-zA-Z]+)').firstMatch(body);
    if (vpaMatch != null) return vpaMatch.group(1)!;

    if (body.toLowerCase().contains('atm')) return "ATM";
    return "Unknown Merchant";
  }

  @visibleForTesting
  static String determineType(String body) {
    if (_upiRegex.hasMatch(body)) return "UPI";
    if (body.contains("card") ||
        body.contains("visa") ||
        body.contains("mastercard"))
      return "Card";
    if (body.contains("atm") || body.contains("cash")) return "Cash";
    return "Bank Transfer";
  }

  @visibleForTesting
  static String generateHash(String sender, String body, int timestamp) {
    String cleanContent = body.trim().replaceAll(RegExp(r'\s+'), '');
    var bytes = utf8.encode("$sender$cleanContent$timestamp");
    return sha256.convert(bytes).toString();
  }
}
