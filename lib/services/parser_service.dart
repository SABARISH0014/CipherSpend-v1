import '../models/transaction_model.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ParserService {
  // --- ADVANCED REGEX PATTERNS ---

  // 1. Amount: Captures "Rs. 500", "INR 500.00", "Rs.500", "INR500"
  static final RegExp _amountRegex = RegExp(
      r'(?:rs\.?|inr|₹)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
      caseSensitive: false);

  // 2. Transaction Types
  static final RegExp _upiRegex =
      RegExp(r'(upi|vpa|paytm|gpay|phonepe)', caseSensitive: false);
  static final RegExp _debitCardRegex =
      RegExp(r'(debit\s*card|dc|atm)', caseSensitive: false);
  static final RegExp _creditCardRegex =
      RegExp(r'(credit\s*card|cc)', caseSensitive: false);
  static final RegExp _netBankingRegex =
      RegExp(r'(net\s*banking|neft|rtgs|imps)', caseSensitive: false);

  // 3. Merchant/Purpose Extraction (Simple Heuristic)
  static final RegExp _merchantRegex = RegExp(
      r'(?:\sat\s|to\s|for\s)([a-zA-Z0-9\s]+?)(?:\.|with|on|through|via|using|$)',
      caseSensitive: false);

  // 4. Keyword Map (Expanded)
  static final Map<String, String> _keywordMap = {
    'zomato': 'Food',
    'swiggy': 'Food',
    'dominos': 'Food',
    'kfc': 'Food',
    'mcdonalds': 'Food',
    'uber': 'Travel',
    'ola': 'Travel',
    'rapido': 'Travel',
    'irctc': 'Travel',
    'petrol': 'Travel',
    'fuel': 'Travel',
    'shell': 'Travel',
    'netflix': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'prime': 'Entertainment',
    'spotify': 'Entertainment',
    'cinema': 'Entertainment',
    'jio': 'Bills',
    'airtel': 'Bills',
    'vi': 'Bills',
    'bescom': 'Bills',
    'electricity': 'Bills',
    'water': 'Bills',
    'gas': 'Bills',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'decathlon': 'Shopping',
    'grofers': 'Grocery',
    'bigbasket': 'Grocery',
    'blinkit': 'Grocery',
    'zepto': 'Grocery',
    'dmart': 'Grocery',
  };

  /// Main Parser Logic
  static TransactionModel? parseSMS(String sender, String body, int timestamp) {
    String cleanBody =
        body.replaceAll(RegExp(r'\s+'), ' ').trim(); // Remove extra spaces

    // A. Filter: Ignore OTPs and Credits (Income)
    if (!_isExpense(cleanBody)) return null;

    // B. Extract Amount
    double amount = _extractAmount(cleanBody);
    if (amount == 0.0) return null;

    // C. Determine Type (UPI, Card, etc.)
    String type = _determineType(cleanBody);

    // D. Determine Category
    String category = _categorize(cleanBody, sender);

    // E. Generate Unique Hash
    String hash = _generateHash(sender, cleanBody, timestamp);

    return TransactionModel(
      hash: hash,
      sender: sender,
      body: cleanBody,
      amount: amount,
      category: category,
      type: type, // [NEW] Storing the type
      timestamp: timestamp,
    );
  }

  /// Checks if the SMS is a valid expense transaction
  static bool _isExpense(String body) {
    String lower = body.toLowerCase();

    // Must contain at least one "Spent" keyword
    bool isSpent = lower.contains("debited") ||
        lower.contains("spent") ||
        lower.contains("purchase") ||
        lower.contains("sent") ||
        lower.contains("paid") ||
        lower.contains("withdrawn") ||
        lower.contains("txn");

    // Must NOT contain "Income" keywords
    bool isIncome = lower.contains("credited") ||
        lower.contains("refund") ||
        lower.contains("added"); // e.g., "Money added to wallet"

    // Must NOT be an OTP/Auth message
    // Note: We allow "otp" if it says "don't share otp", but reject "is your otp"
    bool isAuth = lower.contains("is your otp") || lower.contains("login");

    return isSpent && !isIncome && !isAuth;
  }

  static double _extractAmount(String body) {
    final match = _amountRegex.firstMatch(body);
    if (match != null) {
      String cleanAmount = match.group(1)!.replaceAll(',', '');
      return double.tryParse(cleanAmount) ?? 0.0;
    }
    return 0.0;
  }

  static String _determineType(String body) {
    if (_upiRegex.hasMatch(body)) return "UPI";
    if (_debitCardRegex.hasMatch(body)) return "Debit Card";
    if (_creditCardRegex.hasMatch(body)) return "Credit Card";
    if (_netBankingRegex.hasMatch(body)) return "Net Banking";
    return "Unknown";
  }

  static String _categorize(String body, String sender) {
    String content = "$body $sender".toLowerCase();

    // 1. Check Keywords
    for (var key in _keywordMap.keys) {
      if (content.contains(key)) {
        return _keywordMap[key]!;
      }
    }

    // 2. Fallback: Try to extract merchant name and guess
    // Example: "Paid to STARBUCKS" -> Guess "Food" (Future scope: ML Model)

    return "Uncategorized";
  }

  static String _generateHash(String sender, String body, int timestamp) {
    var bytes = utf8.encode("$sender$body$timestamp");
    return sha256.convert(bytes).toString();
  }
}
