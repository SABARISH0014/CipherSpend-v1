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
    final List<Map<String, dynamic>> ignoredData = await db.query(
      'ignored_hashes',
    );
    return ignoredData.map((e) => e['hash'] as String).toSet();
  }

  // --- [UPDATED] ULTIMATE DUPLICATE CHECK ---
  Future<bool> existsSimilarTransaction(TransactionModel txn) async {
    final db = await DBService().database;

    // 1. EXACT Body Match within 3 Days (Fixes delayed network duplicates)
    int dayBuffer = 259200000; // 3 days in ms
    int startDay = txn.timestamp - dayBuffer;
    int endDay = txn.timestamp + dayBuffer;

    var exactBodyResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count 
      FROM ${Constants.tableTransactions} 
      WHERE body = ? AND timestamp >= ? AND timestamp <= ?
    ''',
      [txn.body, startDay, endDay],
    );

    if ((Sqflite.firstIntValue(exactBodyResult) ?? 0) > 0) return true;

    // 2. SAME AMOUNT & MERCHANT within 3 Days (Fixes SMS vs App Notif overlap)
    if (txn.merchant != "Unknown" && txn.merchant != "Unknown Merchant") {
      var sameMerchantResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM ${Constants.tableTransactions} 
        WHERE amount = ? AND merchant = ? 
        AND timestamp >= ? AND timestamp <= ?
      ''',
        [txn.amount, txn.merchant, startDay, endDay],
      );

      if ((Sqflite.firstIntValue(sameMerchantResult) ?? 0) > 0) return true;
    }

    // 3. FUZZY Match (Just Amount) within 60 minutes
    int timeBuffer = 3600000; // 60 minutes
    int start = txn.timestamp - timeBuffer;
    int end = txn.timestamp + timeBuffer;

    final fuzzyResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count 
      FROM ${Constants.tableTransactions} 
      WHERE amount = ? 
      AND timestamp >= ? AND timestamp <= ?
    ''',
      [txn.amount, start, end],
    );

    int count = Sqflite.firstIntValue(fuzzyResult) ?? 0;
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

  // --- SMART PROMPT HELPER ---
  // Checks if the background engine already caught a transaction in the last X minutes
  Future<bool> hasRecentTransaction(int minutes) async {
    final db = await DBService().database;
    int threshold =
        DateTime.now().millisecondsSinceEpoch - (minutes * 60 * 1000);
    var result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${Constants.tableTransactions} WHERE timestamp > ?',
      [threshold],
    );
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  // --- SILENT BACKGROUND SYNC ---
  Future<void> silentBackgroundSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int lastSync =
          prefs.getInt('last_sync_timestamp') ??
          DateTime.now()
              .subtract(const Duration(days: 180))
              .millisecondsSinceEpoch;

      final List<dynamic> messages = await _bridge.readSmsHistory(
        since: lastSync,
      );
      final String? cachedJson = await _bridge.getAndClearBackgroundCache();

      if (cachedJson != null && cachedJson != "[]") {
        try {
          List<dynamic> cachedMsgs = jsonDecode(cachedJson);
          messages.addAll(cachedMsgs);
        } catch (e) {
          print("Error decoding cache: $e");
        }
      }

      if (messages.isEmpty) return;

      await AIService().loadModel();
      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db);

      int highestTimestamp = lastSync;
      List<Map<String, dynamic>> sessionCache = [];

      for (var msg in messages) {
        int timestamp = msg['timestamp'] ?? 0;
        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = await ParserService.parseSMS(
          msg['sender'] ?? '',
          msg['body'] ?? '',
          timestamp,
        );

        if (txn != null && !blacklist.contains(txn.hash)) {
          bool isDuplicateInDb = await existsSimilarTransaction(txn);
          bool isDuplicateInSession = false;

          for (var cached in sessionCache) {
            bool sameBody = cached['body'] == txn.body;
            bool sameMerchant =
                (cached['amount'] == txn.amount) &&
                (cached['merchant'] == txn.merchant) &&
                (txn.merchant != 'Unknown' &&
                    txn.merchant != 'Unknown Merchant') &&
                ((cached['timestamp'] - txn.timestamp).abs() <
                    259200000); // 3 days
            bool sameAmountCloseTime =
                (cached['amount'] == txn.amount) &&
                ((cached['timestamp'] - txn.timestamp).abs() <
                    3600000); // 60 mins

            if (sameBody || sameMerchant || sameAmountCloseTime) {
              isDuplicateInSession = true;
              break;
            }
          }

          if (!isDuplicateInDb && !isDuplicateInSession) {
            await db.insert(
              Constants.tableTransactions,
              txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            // [FIX] Added merchant to session cache memory
            sessionCache.add({
              'body': txn.body,
              'amount': txn.amount,
              'merchant': txn.merchant,
              'timestamp': txn.timestamp,
            });
          }
        }
      }

      await prefs.setInt('last_sync_timestamp', highestTimestamp);
    } catch (e) {
      print("❌ Silent Sync Error: $e");
    }
  }

  // --- MANUAL SYNC ---
  Future<int> syncHistory({
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final List<dynamic> messages = await _bridge.readSmsHistory();
      if (messages.isEmpty) return 0;

      await AIService().loadModel();
      final db = await DBService().database;
      Set<String> blacklist = await _getBlacklist(db);

      int addedCount = 0;
      int highestTimestamp = 0;
      List<Map<String, dynamic>> sessionCache = [];

      for (int i = 0; i < messages.length; i++) {
        var msg = messages[i];
        int timestamp = msg['timestamp'] ?? 0;
        if (timestamp > highestTimestamp) highestTimestamp = timestamp;

        var txn = await ParserService.parseSMS(
          msg['sender'] ?? '',
          msg['body'] ?? '',
          timestamp,
        );

        if (txn != null && !blacklist.contains(txn.hash)) {
          bool isDuplicateInDb = await existsSimilarTransaction(txn);
          bool isDuplicateInSession = false;

          for (var cached in sessionCache) {
            bool sameBody = cached['body'] == txn.body;
            bool sameMerchant =
                (cached['amount'] == txn.amount) &&
                (cached['merchant'] == txn.merchant) &&
                (txn.merchant != 'Unknown' &&
                    txn.merchant != 'Unknown Merchant') &&
                ((cached['timestamp'] - txn.timestamp).abs() < 259200000);
            bool sameAmountCloseTime =
                (cached['amount'] == txn.amount) &&
                ((cached['timestamp'] - txn.timestamp).abs() < 3600000);

            if (sameBody || sameMerchant || sameAmountCloseTime) {
              isDuplicateInSession = true;
              break;
            }
          }

          if (!isDuplicateInDb && !isDuplicateInSession) {
            await db.insert(
              Constants.tableTransactions,
              txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            // [FIX] Added merchant to session cache memory
            sessionCache.add({
              'body': txn.body,
              'amount': txn.amount,
              'merchant': txn.merchant,
              'timestamp': txn.timestamp,
            });
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
      orderBy: "timestamp DESC",
    );

    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  Stream<TransactionModel?> get liveTransactionStream {
    return _bridge.smsStream.asyncMap((event) async {
      try {
        return await ParserService.parseSMS(
          event['sender'] ?? '',
          event['body'] ?? '',
          event['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        );
      } catch (e) {
        return null;
      }
    });
  }
}
