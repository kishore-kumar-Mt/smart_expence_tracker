import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const numType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
CREATE TABLE expenses (
  id $idType,
  amount $numType,
  category $textType,
  date $textType,
  note $textNullable
)
''');
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
    return await db.delete(
      'expenses',
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
