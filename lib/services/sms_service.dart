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

  /// Helper to grab the Blacklist instantly
  Future<Set<String>> _getBlacklist(Database db) async {
    final List<Map<String, dynamic>> ignoredData =
        await db.query('ignored_hashes');
    return ignoredData.map((e) => e['hash'] as String).toSet();
  }

  /// 1. Save a Single Transaction (From Live Stream)
  Future<void> saveTransaction(TransactionModel txn) async {
    try {
      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db);

      // Stop if it's blacklisted
      if (blacklist.contains(txn.hash)) return;

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
      final List<dynamic> messages = await _bridge.readSmsHistory();
      if (messages.isEmpty) return 0;

      await AIService().loadModel();

      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db); // [NEW] Get Blacklist

      int addedCount = 0;
      int highestTimestamp = 0;
      Batch batch = db.batch();

      for (int i = 0; i < messages.length; i++) {
        var msg = messages[i];
        String sender = msg['sender'] ?? '';
        String body = msg['body'] ?? '';
        int timestamp = msg['timestamp'] ?? 0;

        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = ParserService.parseSMS(sender, body, timestamp);

        // [NEW] Check Blacklist before saving
        if (txn != null && !blacklist.contains(txn.hash)) {
          batch.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          addedCount++;
        }

        if (onProgress != null && i % 5 == 0)
          onProgress(i + 1, messages.length);
      }

      await batch.commit(noResult: true);

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
      int lastSync = prefs.getInt('last_sync_timestamp') ??
          DateTime.now()
              .subtract(const Duration(days: 180))
              .millisecondsSinceEpoch;

      final List<dynamic> messages =
          await _bridge.readSmsHistory(since: lastSync);
      if (messages.isEmpty) return;

      await AIService().loadModel();
      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db); // [NEW] Get Blacklist

      Batch batch = db.batch();
      int highestTimestamp = lastSync;

      for (var msg in messages) {
        int timestamp = msg['timestamp'] ?? 0;
        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = ParserService.parseSMS(
            msg['sender'] ?? '', msg['body'] ?? '', timestamp);

        // [NEW] Check Blacklist before saving
        if (txn != null && !blacklist.contains(txn.hash)) {
          batch.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await batch.commit(noResult: true);
      await prefs.setInt('last_sync_timestamp', highestTimestamp);
      print("⚡ Silent Sync: Added new background messages.");
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
      Set<String> blacklist = await _getBlacklist(db); // [NEW] Get Blacklist

      Batch batch = db.batch();

      for (var msg in cachedMessages) {
        var txn = ParserService.parseSMS(
            msg['sender'] ?? '', msg['body'] ?? '', msg['timestamp'] ?? 0);

        // [NEW] Check Blacklist before saving
        if (txn != null && !blacklist.contains(txn.hash)) {
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
