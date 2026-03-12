import 'package:flutter_test/flutter_test.dart';
import 'package:cipherspend/services/parser_service.dart';

void main() {
  group('ParserService - Amount Extraction', () {
    test('Extracts standard Bank SMS amount', () {
      expect(
          ParserService.extractAmount("Rs. 500 debited from a/c X123"), 500.0);
      expect(
          ParserService.extractAmount("INR 1,250.50 spent on card"), 1250.50);
      expect(ParserService.extractAmount("₹999 was transferred"), 999.0);
    });

    test('Extracts UPI Notification amount', () {
      // isNotif = true allows the simpler regex
      expect(ParserService.extractAmount("Paid ₹350 to Uber", isNotif: true),
          350.0);
      expect(ParserService.extractAmount("Sent Rs.1500 to John", isNotif: true),
          1500.0);
    });

    test('Returns 0.0 if no amount is found', () {
      expect(ParserService.extractAmount("Your OTP is 123456"), 0.0);
      expect(ParserService.extractAmount("Welcome to HDFC Bank"), 0.0);
    });
  });

  group('ParserService - Merchant Extraction', () {
    test('Extracts standard Merchants and cleans trailing words', () {
      // Should remove " on "
      expect(ParserService.extractAmount("..."), 0.0); // Dummy
      expect(
          ParserService.extractMerchant("Rs 500 debited for Zomato on 12-Mar"),
          "Zomato");
      // Should remove " via "
      expect(ParserService.extractMerchant("Paid ₹100 to Starbucks via UPI"),
          "Starbucks");
      // Should remove " at "
      expect(
          ParserService.extractMerchant("Purchase at Amazon Store successful"),
          "Amazon Store");
    });

    test('Extracts VPA / UPI IDs as fallback', () {
      expect(
          ParserService.extractMerchant("Sent Rs 500 to swiggy@axis via app"),
          "swiggy@axis");
    });

    test('Identifies ATM withdrawals', () {
      expect(
          ParserService.extractMerchant("Rs 1000 withdrawn at SBI ATM"), "ATM");
    });
  });

  group('ParserService - Payment Type Identification', () {
    test('Identifies UPI', () {
      expect(ParserService.determineType("txn via upi successful"), "UPI");
      expect(ParserService.determineType("sent to vpa ramesh@okicici"), "UPI");
      expect(ParserService.determineType("paid via phonepe"), "UPI");
    });

    test('Identifies Card', () {
      expect(
          ParserService.determineType("txn on your visa card ends with 1234"),
          "Card");
    });

    test('Identifies Cash/ATM', () {
      expect(ParserService.determineType("cash withdrawn at atm"), "Cash");
    });
  });

  group('ParserService - Spam & Junk Filtering', () {
    test('Blocks Telecom Data/Recharge Alerts', () {
      expect(
          ParserService.isSpam(
              "Alert!! 50% of daily high speed data is consumed."),
          true);
      expect(
          ParserService.isSpam("Get 3GB per day for 3 days at Rs. 39"), true);
      expect(ParserService.isSpam("Your plan validity has expired"), true);
    });

    test('Blocks URLs & Phishing Links', () {
      expect(
          ParserService.isSpam("Claim your reward at http://fake.com"), true);
      expect(
          ParserService.isSpam("Update KYC immediately at bit.ly/kyc"), true);
    });

    test('Blocks OTPs and Auth Codes', () {
      expect(ParserService.isSpam("Your OTP for login is 556677"), true);
      expect(ParserService.isSpam("Verification code: 112233"), true);
    });

    test('Allows genuine transactions to pass', () {
      expect(ParserService.isSpam("Rs 500 debited from a/c X123 for Zomato"),
          false);
      expect(ParserService.isSpam("Paid ₹350 to Uber Rides"), false);
    });
  });

  group('ParserService - Hash Deduplication', () {
    test('Identical messages generate identical hashes', () {
      String msg1 = "Rs 500 debited for Zomato";
      String msg2 = "Rs 500 debited for Zomato";

      String hash1 = ParserService.generateHash("VM-HDFC", msg1, 1610000000);
      String hash2 = ParserService.generateHash("VM-HDFC", msg2, 1610000000);

      expect(hash1, equals(hash2));
    });

    test('Different timestamps generate different hashes', () {
      String msg = "Rs 500 debited for Zomato";

      String hash1 = ParserService.generateHash("VM-HDFC", msg, 1610000000);
      String hash2 = ParserService.generateHash(
          "VM-HDFC", msg, 1610000001); // 1 ms difference

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('Interactive Tap-to-Train Regex System Validation', () {
    test('Generated regex successfully captures amount and merchant', () {
      // Simulate raw SMS list split by space
      List<String> words = ["Alert:", "Debited", "rs", "400.50", "at", "Amazon", "store"];
      
      // Simulate user tagging 400.50 (index 3) as Amount, and Amazon (index 5) as Merchant
      int amountIndex = 3;
      int merchantIndex = 5;
      
      // Generation logic exactly as in interactive_training_screen.dart
      List<String> regexParts = [];
      for (int i = 0; i < words.length; i++) {
        if (i == amountIndex) {
          regexParts.add(r'(?<amount>\d+(?:,\d+)*(?:\.\d+)?)');
        } else if (i == merchantIndex) {
          regexParts.add(r'(?<merchant>.+?)');
        } else {
          regexParts.add(RegExp.escape(words[i]));
        }
      }
      String finalRegex = regexParts.join(r'\s+');
      
      // Verify regex construction
      expect(
        finalRegex, 
        r'Alert:\s+Debited\s+rs\s+(?<amount>\d+(?:,\d+)*(?:\.\d+)?)\s+at\s+(?<merchant>.+?)\s+store'
      );
      
      // Verify the generated regex works on the string
      String rawSMS = "Alert: Debited rs 400.50 at Amazon store";
      final regExp = RegExp(finalRegex, caseSensitive: false);
      final match = regExp.firstMatch(rawSMS);
      
      expect(match, isNotNull);
      expect(match!.namedGroup('amount'), "400.50");
      expect(match.namedGroup('merchant'), "Amazon");
    });
  });
}
