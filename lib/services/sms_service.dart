import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_service.dart';
import 'parser_service.dart';
import 'ai_service.dart';
import 'sms_bridge.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class SmsService {
  final SmsBridge _bridge = SmsBridge();

  Future<Set<String>> _getBlacklist(Database db) async {
    final List<Map<String, dynamic>> ignoredData =
        await db.query('ignored_hashes');
    return ignoredData.map((e) => e['hash'] as String).toSet();
  }

  // --- [UPDATED] CROSS-SOURCE DUPLICATE CHECK ---
  Future<bool> existsSimilarTransaction(TransactionModel txn) async {
    final db = await DBService().database;

    // 5 minutes buffer (300,000 milliseconds)
    // Shortened from 15 mins to prevent false positives (e.g., buying two ₹50 coffees back-to-back)
    int timeBuffer = 300000;
    int start = txn.timestamp - timeBuffer;
    int end = txn.timestamp + timeBuffer;

    // Notice we REMOVED the "sender = ?" check.
    // Now, if GPay reports ₹500 and HDFC reports ₹500 within 5 mins, it flags as duplicate.
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${Constants.tableTransactions} 
      WHERE amount = ? 
      AND timestamp >= ? AND timestamp <= ?
    ''', [txn.amount, start, end]);

    int count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  // --- 1. SAVE TRANSACTION (Modified for direct calls) ---
  Future<void> saveTransaction(TransactionModel txn) async {
    try {
      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db);

      if (blacklist.contains(txn.hash)) return;

      // Note: We do NOT check existsSimilarTransaction here.
      // We let the UI decide for live messages, or the sync loop decide for background.

      await db.insert(
        Constants.tableTransactions,
        txn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print("❌ Error saving transaction: $e");
    }
  }

  // --- 2. SILENT BACKGROUND SYNC (Updated) ---
  Future<void> silentBackgroundSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int lastSync = prefs.getInt('last_sync_timestamp') ??
          DateTime.now()
              .subtract(const Duration(days: 180))
              .millisecondsSinceEpoch;

      final List<dynamic> messages =
          await _bridge.readSmsHistory(since: lastSync);
      if (messages.isEmpty) return;

      await AIService().loadModel();
      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db);

      Batch batch = db.batch();
      int highestTimestamp = lastSync;

      for (var msg in messages) {
        int timestamp = msg['timestamp'] ?? 0;
        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = ParserService.parseSMS(
            msg['sender'] ?? '', msg['body'] ?? '', timestamp);

        if (txn != null && !blacklist.contains(txn.hash)) {
          // [NEW] Check for fuzzy duplicates before adding to batch
          bool isDuplicate = await existsSimilarTransaction(txn);
          if (!isDuplicate) {
            batch.insert(Constants.tableTransactions, txn.toMap(),
                conflictAlgorithm: ConflictAlgorithm.ignore);
          } else {
            print("🚫 Skipped duplicate in background: ${txn.body}");
          }
        }
      }

      await batch.commit(noResult: true);
      await prefs.setInt('last_sync_timestamp', highestTimestamp);
      print("⚡ Silent Sync Complete.");
    } catch (e) {
      print("❌ Silent Sync Error: $e");
    }
  }

  // --- 3. MANUAL SYNC (Updated) ---
  Future<int> syncHistory(
      {Function(int current, int total)? onProgress}) async {
    try {
      final List<dynamic> messages = await _bridge.readSmsHistory();
      if (messages.isEmpty) return 0;

      await AIService().loadModel();

      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db);

      int addedCount = 0;
      int highestTimestamp = 0;
      // We cannot use Batch here effectively because we need to await existsSimilarTransaction inside the loop
      // or we accept that bulk sync might be slower. For accuracy, we check one by one or trust Hash.
      // Let's rely on Hash for bulk history to keep it fast, but apply fuzzy check for recent ones.

      for (int i = 0; i < messages.length; i++) {
        var msg = messages[i];
        int timestamp = msg['timestamp'] ?? 0;
        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = ParserService.parseSMS(
            msg['sender'] ?? '', msg['body'] ?? '', timestamp);

        if (txn != null && !blacklist.contains(txn.hash)) {
          // Check duplicate
          bool isDuplicate = await existsSimilarTransaction(txn);

          if (!isDuplicate) {
            await db.insert(Constants.tableTransactions, txn.toMap(),
                conflictAlgorithm: ConflictAlgorithm.ignore);
            addedCount++;
          }
        }

        if (onProgress != null && i % 5 == 0) {
          onProgress(i + 1, messages.length);
        }
      }

      if (highestTimestamp > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_sync_timestamp', highestTimestamp);
      }

      if (onProgress != null) onProgress(messages.length, messages.length);
      return addedCount;
    } catch (e) {
      print("❌ Sync History Error: $e");
      return 0;
    }
  }

  // ... (Keep getTransactionsByMonth and liveTransactionStream as is) ...
  Future<List<TransactionModel>> getTransactionsByMonth(DateTime month) async {
    final db = await DBService().database;
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
        Constants.tableTransactions,
        where: 'timestamp >= ? AND timestamp < ?',
        whereArgs: [start, end],
        orderBy: "timestamp DESC");

    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  Stream<TransactionModel?> get liveTransactionStream {
    return _bridge.smsStream.map((event) {
      try {
        return ParserService.parseSMS(
            event['sender'] ?? '',
            event['body'] ?? '',
            event['timestamp'] ?? DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        return null;
      }
    });
  }
}
