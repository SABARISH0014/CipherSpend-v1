import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class DBService {
  // Singleton Pattern
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

    // THE VAULT KEY: In production, generate this dynamically or use a user-derived key.
    // For Week 1, we hardcode a conceptual key or retrieve it from SecureStorage.
    const password = "SuperSecretKey123!";

    return await openDatabase(
      path,
      password: password, // AES-256 ENCRYPTION ENABLED
      version: 1,
      onCreate: (db, version) async {
        // 1. Transactions Table (With Hash for De-duplication)
        await db.execute('''
          CREATE TABLE ${Constants.tableTransactions}(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash TEXT UNIQUE,
            sender TEXT,
            body TEXT,
            amount REAL,
            category TEXT,
            timestamp INTEGER
          )
        ''');

        // 2. User Config Table (Settings)
        await db.execute('''
          CREATE TABLE ${Constants.tableUserConfig}(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        // 3. Categories Table (Budgeting & Classification)
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
              ['Food', 0xFF4CAF50]); // Green
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Travel', 0xFF2196F3]); // Blue
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Shopping', 0xFFFFC107]); // Amber
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Bills', 0xFFF44336]); // Red
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Entertainment', 0xFF9C27B0]); // Purple
          await txn.rawInsert(
              'INSERT OR IGNORE INTO categories(name, color_code) VALUES(?, ?)',
              ['Uncategorized', 0xFF9E9E9E]); // Grey
        });
      },
    );
  }
}
