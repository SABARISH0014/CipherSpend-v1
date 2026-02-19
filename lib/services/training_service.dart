import 'dart:convert';
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

    // Week 3 "Pro" Tip: In a production app, you would also save this
    // to a separate 'training_data.csv' file locally so you can
    // re-train your TFLite model later with actual user data.
    print("AI Feedback Received: Transaction $hash is now $newCategory");
  }
}
