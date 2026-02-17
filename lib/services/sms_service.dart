import 'package:flutter/services.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'db_service.dart';
import 'parser_service.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class SmsService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.cipherspend/native');
  static const EventChannel _eventChannel =
      EventChannel('com.cipherspend/sms_stream');

  /// 1. Sync Historical Data (Last 90 days from Inbox)
  /// Returns the number of *new* transactions added to the DB.
  Future<int> syncHistory() async {
    try {
      // Invoke the Native Kotlin function
      final List<dynamic> messages =
          await _methodChannel.invokeMethod('readSmsHistory');

      int addedCount = 0;
      final db = await DBService().database;

      for (var msg in messages) {
        String sender = msg['sender'] ?? '';
        String body = msg['body'] ?? '';
        int timestamp = msg['timestamp'] ?? 0;

        // Parse: Extract amount and category
        var txn = ParserService.parseSMS(sender, body, timestamp);

        if (txn != null) {
          // Insert into Encrypted DB
          // ConflictAlgorithm.ignore ensures we don't duplicate data if hash exists
          int id = await db.insert(Constants.tableTransactions, txn.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);

          if (id > 0) addedCount++;
        }
      }
      return addedCount;
    } catch (e) {
      print("History Sync Error: $e");
      return 0;
    }
  }

  /// 2. Listen for Live SMS (Real-time PDU Stream)
  Stream<TransactionModel?> get liveTransactionStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      try {
        String sender = event['sender'] ?? '';
        String body = event['body'] ?? '';
        int timestamp =
            event['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

        // [WEEK 2 REQ] SIM Filtering Hook
        // int subId = event['subscription_id'] ?? -1;
        // In a future update, we can compare `subId` with the user's verified SIM.
        // For now, we process all incoming SMS as per Phase 2 MVP.

        return ParserService.parseSMS(sender, body, timestamp);
      } catch (e) {
        print("Live Stream Parse Error: $e");
        return null;
      }
    });
  }

  /// 3. Save Live Transaction to DB
  Future<void> saveTransaction(TransactionModel txn) async {
    final db = await DBService().database;
    await db.insert(Constants.tableTransactions, txn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 4. Fetch All Transactions for Dashboard UI
  Future<List<TransactionModel>> getTransactions() async {
    final db = await DBService().database;
    final List<Map<String, dynamic>> maps =
        await db.query(Constants.tableTransactions, orderBy: "timestamp DESC");
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }
}
