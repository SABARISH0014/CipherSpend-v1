import 'package:flutter/services.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'; // Corrected import
import 'db_service.dart';
import 'parser_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class SmsService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.cipherspend/native');
  static const EventChannel _eventChannel =
      EventChannel('com.cipherspend/sms_stream');

  /// [NEW] 1. Save a Single Transaction
  /// Required for live SMS updates on the Dashboard
  Future<void> saveTransaction(TransactionModel txn) async {
    try {
      final db = await DBService().database;
      await db.insert(
        Constants.tableTransactions,
        txn.toMap(),
        conflictAlgorithm:
            ConflictAlgorithm.ignore, // Prevents duplicate entries
      );
    } catch (e) {
      print("Error saving live transaction: $e");
    }
  }

  /// 2. Sync Historical Data (Enhanced for Week 3 Progress Tracking)
  Future<int> syncHistory(
      {Function(int current, int total)? onProgress}) async {
    try {
      // Fetch raw messages from Native Bridge (MainActivity.kt)
      final List<dynamic> messages =
          await _methodChannel.invokeMethod('readSmsHistory');

      if (messages.isEmpty) return 0;

      int addedCount = 0;
      final db = await DBService().database;

      // Use a Batch for speed during historical sync
      Batch batch = db.batch();

      for (int i = 0; i < messages.length; i++) {
        var msg = messages[i];
        String sender = msg['sender'] ?? '';
        String body = msg['body'] ?? '';
        int timestamp = msg['timestamp'] ?? 0;

        // Run AI Categorization & Extraction
        var txn = ParserService.parseSMS(sender, body, timestamp);

        if (txn != null) {
          batch.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
          addedCount++;
        }

        // Update the UI Overlay every 5 messages to avoid lag
        if (onProgress != null && i % 5 == 0) {
          onProgress(i + 1, messages.length);
        }
      }

      // Commit all categorized transactions to the encrypted vault at once
      await batch.commit(noResult: true);

      // Final progress update
      if (onProgress != null) onProgress(messages.length, messages.length);

      return addedCount;
    } catch (e) {
      print("Week 3 Sync Error: $e");
      return 0;
    }
  }

  /// 3. Get Transactions for a specific Month
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

  /// 4. Live Stream (Native Event Channel listener)
  Stream<TransactionModel?> get liveTransactionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
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
