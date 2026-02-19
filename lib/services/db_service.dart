import 'dart:io';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, Constants.dbName);

    // Note: In a production scenario, retrieve this from flutter_secure_storage
    const password = "SuperSecretKey123!";

    return await openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: (db, version) async {
        // 1. Transactions Table (Includes Merchant & AI Category)
        await db.execute('''
          CREATE TABLE ${Constants.tableTransactions}(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash TEXT UNIQUE,
            sender TEXT,
            body TEXT,
            amount REAL,
            category TEXT,
            type TEXT, 
            merchant TEXT,
            timestamp INTEGER
          )
        ''');

        // 2. User Config (For salary date, name, etc.)
        await db.execute('''
          CREATE TABLE ${Constants.tableUserConfig}(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        // 3. Categories (For Budget Tracking)
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            budget_limit REAL DEFAULT 0,
            color_code INTEGER
          )
        ''');

        // 4. Seed Data
        await db.transaction((txn) async {
          List<String> defaults = [
            'Food',
            'Travel',
            'Shopping',
            'Bills',
            'Entertainment',
            'Grocery',
            'Uncategorized'
          ];
          for (var cat in defaults) {
            await txn.rawInsert(
                'INSERT OR IGNORE INTO categories(name) VALUES(?)', [cat]);
          }
        });
      },
    );
  }

  // --- Week 3 Helper Methods ---

  /// Get total spend by category for a specific month (For Forecast/Charts)
  Future<List<Map<String, dynamic>>> getCategorySpending(
      int month, int year) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;

    return await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM ${Constants.tableTransactions} 
      WHERE timestamp >= ? AND timestamp < ? 
      GROUP BY category
    ''', [start, end]);
  }

  /// Get transactions for the Dashboard list
  Future<List<Map<String, dynamic>>> getTransactionsByMonth(
      int month, int year) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;

    return await db.query(Constants.tableTransactions,
        where: 'timestamp >= ? AND timestamp < ?',
        whereArgs: [start, end],
        orderBy: 'timestamp DESC');
  }

  // --- Clean Up & Security ---

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }

  Future<void> deleteDB() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, Constants.dbName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
