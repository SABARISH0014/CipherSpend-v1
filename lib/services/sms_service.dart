import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_service.dart';
import 'parser_service.dart';
import 'ai_service.dart';
import 'sms_bridge.dart'; // Make sure this path matches where you saved SmsBridge
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class SmsService {
  // Use the dedicated bridge instead of hardcoding MethodChannels here
  final SmsBridge _bridge = SmsBridge();

  /// 1. Save a Single Transaction (From Live Stream)
  Future<void> saveTransaction(TransactionModel txn) async {
    try {
      final db = await DBService().database;
      await db.insert(
        Constants.tableTransactions,
        txn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print("❌ Error saving live transaction: $e");
    }
  }

  /// 2. Manual UI Sync (Scans history, shows progress)
  Future<int> syncHistory(
      {Function(int current, int total)? onProgress}) async {
    try {
      // Fetch raw messages via the bridge (no 'since' implies full 180-day scan)
      final List<dynamic> messages = await _bridge.readSmsHistory();

      if (messages.isEmpty) return 0;

      await AIService().loadModel(); // Ensure AI is awake

      int addedCount = 0;
      int highestTimestamp = 0;
      final db = await DBService().database;
      Batch batch = db.batch();

      for (int i = 0; i < messages.length; i++) {
        var msg = messages[i];
        String sender = msg['sender'] ?? '';
        String body = msg['body'] ?? '';
        int timestamp = msg['timestamp'] ?? 0;

        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = ParserService.parseSMS(sender, body, timestamp);

        if (txn != null) {
          batch.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          addedCount++;
        }

        // Update UI every 5 messages
        if (onProgress != null && i % 5 == 0) {
          onProgress(i + 1, messages.length);
        }
      }

      await batch.commit(noResult: true);

      // Save the timestamp so silent sync knows where to start next time
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

  /// 3. Silent Delta Sync (Runs instantly in background)
  Future<void> silentBackgroundSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to 180 days ago if never synced
      int lastSync = prefs.getInt('last_sync_timestamp') ??
          DateTime.now()
              .subtract(const Duration(days: 180))
              .millisecondsSinceEpoch;

      // Ask bridge ONLY for messages newer than lastSync
      final List<dynamic> messages =
          await _bridge.readSmsHistory(since: lastSync);

      if (messages.isEmpty) return;

      await AIService().loadModel();
      final db = await DBService().database;
      Batch batch = db.batch();
      int highestTimestamp = lastSync;

      for (var msg in messages) {
        int timestamp = msg['timestamp'] ?? 0;
        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = ParserService.parseSMS(
            msg['sender'] ?? '', msg['body'] ?? '', timestamp);
        if (txn != null) {
          batch.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await batch.commit(noResult: true);
      await prefs.setInt('last_sync_timestamp', highestTimestamp);
      print("⚡ Silent Sync: Added ${messages.length} new background messages.");
    } catch (e) {
      print("❌ Silent Sync Error: $e");
    }
  }

  /// 4. Process the Native Intercept Cache (From BroadcastReceiver)
  Future<void> processBackgroundCache() async {
    try {
      final String? jsonString = await _bridge.getAndClearBackgroundCache();

      if (jsonString == null || jsonString == "[]") return;

      List<dynamic> cachedMessages = jsonDecode(jsonString);
      if (cachedMessages.isEmpty) return;

      await AIService().loadModel();
      final db = await DBService().database;
      Batch batch = db.batch();

      for (var msg in cachedMessages) {
        var txn = ParserService.parseSMS(
            msg['sender'] ?? '', msg['body'] ?? '', msg['timestamp'] ?? 0);
        if (txn != null) {
          batch.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await batch.commit(noResult: true);
      print(
          "✅ Processed ${cachedMessages.length} intercepted messages from native cache.");
    } catch (e) {
      print("❌ Cache Process Error: $e");
    }
  }

  /// 5. Get Transactions for a specific Month
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

  /// 6. Live Stream (Native Event Channel listener)
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
