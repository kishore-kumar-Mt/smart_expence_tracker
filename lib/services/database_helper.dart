import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/notification_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const numType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intNullable = 'INTEGER';

    await db.execute('''
CREATE TABLE expenses (
  id $idType,
  amount $numType,
  category $textType,
  date $textType,
  note $textNullable,
  type $textType DEFAULT 'expense',
  frequency $textNullable,
  recurrenceStartDate $textNullable,
  recurrenceEndDate $textNullable,
  recurrenceOccurrences $intNullable,
  recurrenceTargetType $textNullable,
  lastGeneratedDate $textNullable
)
''');

    await db.execute('''
CREATE TABLE notifications (
  id $idType,
  title $textType,
  body $textType,
  timestamp $textType,
  type $textType,
  isRead INTEGER NOT NULL DEFAULT 0
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    final columns = await db.rawQuery('PRAGMA table_info(expenses)');
    final existingColumns = columns.map((c) => c['name'] as String).toList();

    if (oldVersion < 2) {
      if (!existingColumns.contains('type')) {
        await db.execute(
          "ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
        );
      }
    }
    if (oldVersion < 3) {
      final newColumns = [
        'frequency',
        'recurrenceStartDate',
        'recurrenceEndDate',
        'recurrenceOccurrences',
        'recurrenceTargetType',
        'lastGeneratedDate',
      ];

      for (var column in newColumns) {
        if (!existingColumns.contains(column)) {
          // Determine type based on your schema plan
          String type = 'TEXT';
          if (column == 'recurrenceOccurrences') type = 'INTEGER';

          await db.execute("ALTER TABLE expenses ADD COLUMN $column $type");
        }
      }
    }

    if (oldVersion < 4) {
      // Just execute create if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          type TEXT NOT NULL,
          isRead INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses() async {
    final db = await instance.database;
    final orderBy = 'date DESC';
    final result = await db.query('expenses', orderBy: orderBy);

    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpensesBefore(DateTime date) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'date < ?',
      whereArgs: [date.toIso8601String()],
    );
  }

  Future<int> deleteAllExpenses() async {
    final db = await instance.database;
    return await db.delete('expenses');
  }

  Future<int> deleteExpensesByCategory(String category) async {
    final db = await instance.database;
    return await db.delete('expenses', whereArgs: [category]);
  }

  // Notifications CRUD
  Future<int> insertNotification(NotificationItem item) async {
    final db = await instance.database;
    return await db.insert('notifications', item.toMap());
  }

  Future<List<NotificationItem>> getNotifications() async {
    final db = await instance.database;
    final result = await db.query('notifications', orderBy: 'timestamp DESC');
    return result.map((json) => NotificationItem.fromMap(json)).toList();
  }

  Future<int> deleteAllNotifications() async {
    final db = await instance.database;
    return await db.delete('notifications');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
