import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    const secureStorage = FlutterSecureStorage();
    String? password = await secureStorage.read(key: 'cipher_db_key');

    if (password == null) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(255));
      password = base64UrlEncode(values);
      await secureStorage.write(key: 'cipher_db_key', value: password);
      print("🔐 Generated and stored new secure vault key.");
    }

    // 4. Open the SQLCipher database
    return await openDatabase(
      path,
      password: password,
      version: 5,
      onOpen: (db) async {
        // [THE FIX] Bulletproof fallback: Ensures tables exist every time the app opens (useful for flutter hot reloads)
        await db.execute(
            'CREATE TABLE IF NOT EXISTS ignored_hashes(hash TEXT PRIMARY KEY)');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_notifications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            timestamp INTEGER
          )
        ''');
      },
      onCreate: (db, version) async {
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

        await db.execute('''
          CREATE TABLE ${Constants.tableUserConfig}(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            budget_limit REAL DEFAULT 0,
            color_code INTEGER
          )
        ''');

        // [NEW] Create Blacklist table for fresh installs
        await db.execute('CREATE TABLE ignored_hashes(hash TEXT PRIMARY KEY)');

        await db.execute('''
          CREATE TABLE custom_rules(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT,
            regex_pattern TEXT
          )
        ''');

        // [NEW] App Insights Notifications Hub
        await db.execute('''
          CREATE TABLE app_notifications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            timestamp INTEGER
          )
        ''');

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
      onUpgrade: (db, oldVersion, newVersion) async {
        // [NEW] Seamlessly migrates existing databases!
        if (oldVersion < 2) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS ignored_hashes(hash TEXT PRIMARY KEY)');
          print("🔄 Database upgraded to v2: Added Blacklist Table");
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS custom_rules(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sender TEXT,
              regex_pattern TEXT
            )
          ''');
          print("🔄 Database upgraded to v3: Added Custom Rules Table");
        }
        if (oldVersion < 4) {
          // Drop the old v4 raw_messages table
          await db.execute('DROP TABLE IF EXISTS raw_messages');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_notifications(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              body TEXT,
              timestamp INTEGER
            )
          ''');
          print("🔄 Database upgraded to v5: Added App Notifications Table");
        }
      },
    );
  }

  // --- Week 4 Helper Methods ---

  Future<void> saveAppNotification(String title, String body, int timestamp) async {
    final db = await database;
    await db.insert('app_notifications', {
      'title': title,
      'body': body,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getAppNotifications() async {
    final db = await database;
    return await db.query('app_notifications', orderBy: 'timestamp DESC');
  }

  Future<int> getAppNotificationsCount() async {
    final db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) as count FROM app_notifications');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteAppNotification(int id) async {
    final db = await database;
    await db.delete('app_notifications', where: 'id = ?', whereArgs: [id]);
  }

  // --- Week 3 Helper Methods ---

  /// Custom Rule Management
  Future<void> saveCustomRule(String sender, String pattern) async {
    final db = await database;
    await db.insert('custom_rules', {'sender': sender, 'regex_pattern': pattern});
  }

  Future<List<String>> getCustomRules(String sender) async {
    final db = await database;
    final List<Map<String, dynamic>> rules = await db.query(
      'custom_rules',
      columns: ['regex_pattern'],
      where: 'sender = ?',
      whereArgs: [sender],
    );
    return rules.map((r) => r['regex_pattern'] as String).toList();
  }

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
      print("🗑️ Database deleted successfully.");
    }
  }
}
