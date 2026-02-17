import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, Constants.dbName);

    // PRODUCTION NOTE: In a real app, use a secure key generation strategy.
    const password = "SuperSecretKey123!";

    return await openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: (db, version) async {
        // 1. Transactions Table (Updated with 'type' column)
        await db.execute('''
          CREATE TABLE ${Constants.tableTransactions}(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash TEXT UNIQUE,
            sender TEXT,
            body TEXT,
            amount REAL,
            category TEXT,
            type TEXT, 
            timestamp INTEGER
          )
        ''');

        // 2. User Config Table
        await db.execute('''
          CREATE TABLE ${Constants.tableUserConfig}(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        // 3. Categories Table
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            budget_limit REAL DEFAULT 0,
            color_code INTEGER
          )
        ''');

        // 4. Seed Default Categories
        await db.transaction((txn) async {
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Food', 0xFF4CAF50]);
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Travel', 0xFF2196F3]);
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Shopping', 0xFFFFC107]);
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Bills', 0xFFF44336]);
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Entertainment', 0xFF9C27B0]);
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Grocery', 0xFF009688]); // Added Grocery
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Uncategorized', 0xFF9E9E9E]);
        });
      },
    );
  }
}
