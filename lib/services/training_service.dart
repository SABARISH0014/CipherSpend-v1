import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'db_service.dart';
import '../utils/constants.dart';

class TrainingService {
  final DBService _db = DBService();

  /// Load categories directly from your AI assets to keep UI & AI in sync
  Future<List<String>> getCategories() async {
    try {
      final String response = await rootBundle.loadString('assets/labels.json');
      final Map<String, dynamic> data = json.decode(response);

      // Convert map values (Category Names) to a sorted list
      List<String> categories = data.values.map((e) => e.toString()).toList();
      categories.sort();
      return categories;
    } catch (e) {
      // Fallback categories if JSON fails
      return ["Food", "Travel", "Shopping", "Entertainment", "Bills", "Others"];
    }
  }

  /// Update the transaction in the DB with the user's manual correction
  Future<void> trainTransaction(String hash, String newCategory) async {
    final db = await _db.database;

    await db.update(
      Constants.tableTransactions,
      {'category': newCategory},
      where: 'hash = ?',
      whereArgs: [hash],
    );

    debugPrint("AI Feedback Received: Transaction $hash is now $newCategory");
  }

  /// [NEW] Update the merchant name (TARGET_NODE) in the DB
  Future<void> updateMerchantName(String hash, String newMerchant) async {
    final db = await _db.database;

    await db.update(
      Constants.tableTransactions,
      {'merchant': newMerchant},
      where: 'hash = ?',
      whereArgs: [hash],
    );

    debugPrint("Manual Override: Merchant updated to $newMerchant");
  }
}