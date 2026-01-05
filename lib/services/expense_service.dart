import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import '../utils/currency_formatter.dart';

class ExpenseService extends ChangeNotifier {
  static final ExpenseService _instance = ExpenseService._internal();
  static ExpenseService get instance => _instance;

  ExpenseService._internal();

  List<Expense> _expenses = [];

  // Public getter for expenses (only actual transactions)
  List<Expense> get expenses => List.unmodifiable(
    _expenses.where((e) => e.type != TransactionType.repeated),
  );

  // Public getter for recurring templates
  List<Expense> get recurringExpenses => List.unmodifiable(
    _expenses.where((e) => e.type == TransactionType.repeated),
  );

  // Computed property: Total amount spent (Expenses only)
  double get totalSpent {
    return _expenses
        .where((e) => e.type == TransactionType.expense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Computed property: Total income
  double get totalIncome {
    return _expenses
        .where((e) => e.type == TransactionType.income)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Computed property: Category-wise totals
  Map<String, double> get categoryWiseTotals {
    final Map<String, double> totals = {};
    for (var expense in _expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  // Computed property: Monthly expense totals (grouped by month-year)
  Map<String, double> get monthlyExpenseTotals {
    final Map<String, double> totals = {};
    for (var expense in _expenses) {
      // Format: "YYYY-MM"
      final monthKey =
          '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      totals[monthKey] = (totals[monthKey] ?? 0) + expense.amount;
    }
    return totals;
  }

  // Load expenses from database
  Future<void> loadExpenses() async {
    _expenses = await DatabaseHelper.instance.getExpenses();
    await _processRecurringTransactions();
    notifyListeners();
  }

  Future<void> _processRecurringTransactions() async {
    final recurringTemplates = _expenses
        .where((e) => e.type == TransactionType.repeated)
        .toList();
    bool changesMade = false;

    for (var template in recurringTemplates) {
      if (template.recurrenceStartDate == null || template.frequency == null)
        continue;

      // Determine where to start checking from
      DateTime checkDate =
          template.lastGeneratedDate ?? template.recurrenceStartDate!;
      // If we already generated for start date, move to next interval, otherwise start from start date
      if (template.lastGeneratedDate != null) {
        checkDate = _getNextDate(checkDate, template.frequency!);
      }

      final now = DateTime.now();
      // Only generate up to today (inclusive)
      while (checkDate.isBefore(now) || isSameDay(checkDate, now)) {
        // Create the new transaction instance
        final newTransaction = Expense(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              '_' +
              checkDate.millisecondsSinceEpoch.toString(), // Unique ID
          amount: template.amount,
          category: template.category,
          date: checkDate,
          note: template.note,
          type: template.recurrenceTargetType ?? TransactionType.expense,
        );

        await DatabaseHelper.instance.insertExpense(newTransaction);
        _expenses.add(newTransaction);

        // Notify user about scheduled payment
        NotificationService.instance.addNotification(
          title: 'Scheduled Payment',
          body:
              'Automatically recorded ${CurrencyFormatter.format(newTransaction.amount)} for ${newTransaction.category}',
          type: 'info',
        );

        changesMade = true;

        // Update the template's lastGeneratedDate
        // We need to update the template object and DB
        // For simplicity in this loop, we update DB at end or one by one.
        // Let's create a new template object with updated lastGeneratedDate
        final updatedTemplate = Expense(
          id: template.id,
          amount: template.amount,
          category: template.category,
          date: template.date,
          note: template.note,
          type: template.type,
          frequency: template.frequency,
          recurrenceStartDate: template.recurrenceStartDate,
          recurrenceEndDate: template.recurrenceEndDate,
          recurrenceOccurrences: template.recurrenceOccurrences,
          recurrenceTargetType: template.recurrenceTargetType,
          lastGeneratedDate: checkDate,
        );

        await DatabaseHelper.instance.updateExpense(updatedTemplate);
        // Update local list reference
        final index = _expenses.indexWhere((e) => e.id == template.id);
        if (index != -1) {
          _expenses[index] = updatedTemplate;
        }

        // Prepare for next iteration
        checkDate = _getNextDate(checkDate, template.frequency!);

        // Safety break if unlimited loop potential (though dates should advance)
        if (checkDate.year > 2050) break;
      }
    }

    if (changesMade) {
      // Re-sort expenses? Current getter is generic list.
      // Usually sort by date DESC.
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    }
  }

  DateTime _getNextDate(DateTime current, RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return current.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return current.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        // Handle month wrapping logic simply for now
        return DateTime(current.year, current.month + 1, current.day);
      case RecurrenceFrequency.yearly:
        return DateTime(current.year + 1, current.month, current.day);
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Add a new expense
  Future<void> addExpense(Expense expense) async {
    await DatabaseHelper.instance.insertExpense(expense);
    _expenses.add(expense);
    notifyListeners();

    // Trigger notification if income
    if (expense.type == TransactionType.income) {
      NotificationService.instance.addNotification(
        title: 'Income Added',
        body:
            'Received ${CurrencyFormatter.format(expense.amount)} from ${expense.category}',
        type: 'success',
      );
    }
  }

  // Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    await DatabaseHelper.instance.updateExpense(expense);
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      notifyListeners();
    }
  }

  Future<void> clearAllExpenses() async {
    // We need to add deleteAllExpenses to DatabaseHelper first if not exist
    // Implementation:
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'expenses',
    ); // Direct delete using DB instance access via DatabaseHelper
    _expenses.clear();
    notifyListeners();
  }

  // Delete an expense
  Future<void> deleteExpense(String id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // Clear all expenses (useful for monthly reset)
  Future<void> clearExpenses() async {
    await DatabaseHelper.instance.deleteAllExpenses();
    _expenses.clear();
    notifyListeners();
  }

  // Delete expenses before a specific date
  Future<void> deleteExpensesBefore(DateTime date) async {
    await DatabaseHelper.instance.deleteExpensesBefore(date);
    _expenses.removeWhere((e) => e.date.isBefore(date));
    notifyListeners();
  }

  // Get expenses for a specific category
  List<Expense> getExpensesByCategory(String category) {
    return _expenses.where((e) => e.category == category).toList();
  }

  // Delete all expenses for a specific category
  Future<void> deleteExpensesByCategory(String category) async {
    await DatabaseHelper.instance.deleteExpensesByCategory(category);
    _expenses.removeWhere((e) => e.category == category);
    notifyListeners();
  }

  // Get expenses for a specific date range
  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    return _expenses.where((e) {
      return e.date.isAfter(start.subtract(const Duration(days: 1))) &&
          e.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // ==================== ANALYTICS METHODS ====================

  /// Get category-wise totals dynamically calculated from expense list
  Map<String, double> getCategoryTotals({TransactionType? type}) {
    final Map<String, double> totals = {};
    for (var expense in _expenses) {
      if (type != null && expense.type != type) continue;

      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  /// Get daily totals for the current month
  /// Returns a map where key is the day of month (1-31) and value is total spent
  Map<int, double> getDailyTotalsForMonth({
    DateTime? month,
    TransactionType? type,
  }) {
    final targetMonth = month ?? DateTime.now();
    final Map<int, double> dailyTotals = {};

    for (var expense in _expenses) {
      // Only include expenses from the target month and year
      if (expense.date.year == targetMonth.year &&
          expense.date.month == targetMonth.month) {
        if (type != null && expense.type != type) continue;

        final day = expense.date.day;
        dailyTotals[day] = (dailyTotals[day] ?? 0) + expense.amount;
      }
    }

    return dailyTotals;
  }

  /// Get comparison data for last 7 days (Income vs Expense)
  Map<String, Map<String, double>> getWeeklyComparison() {
    final now = DateTime.now();
    final Map<String, Map<String, double>> data = {};

    // valid last 7 days including today
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('E').format(date); // Mon, Tue...
      data[dayKey] = {'income': 0.0, 'expense': 0.0};

      // Aggregate
      for (var t in _expenses) {
        // Check if same day
        if (t.date.year == date.year &&
            t.date.month == date.month &&
            t.date.day == date.day) {
          if (t.type == TransactionType.income) {
            data[dayKey]!['income'] = (data[dayKey]!['income'] ?? 0) + t.amount;
          } else if (t.type == TransactionType.expense) {
            data[dayKey]!['expense'] =
                (data[dayKey]!['expense'] ?? 0) + t.amount;
          }
        }
      }
    }
    return data;
  }

  /// Get total amount spent across all expenses
  double getTotalSpent() {
    return _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get total spent for a specific category
  double getCategoryTotal(String category) {
    return _expenses
        .where((e) => e.category == category)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get total spent for a specific month
  double getMonthlyTotal([DateTime? month]) {
    final targetMonth = month ?? DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.date.year == targetMonth.year &&
              e.date.month == targetMonth.month,
        )
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Get the most expensive category
  String? getTopSpendingCategory() {
    final categoryTotals = getCategoryTotals();
    if (categoryTotals.isEmpty) return null;

    return categoryTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get expense count by category
  Map<String, int> getCategoryFrequency() {
    final Map<String, int> frequency = {};
    for (var expense in _expenses) {
      frequency[expense.category] = (frequency[expense.category] ?? 0) + 1;
    }
    return frequency;
  }

  /// Get the most frequent category
  String? getMostFrequentCategory() {
    final frequency = getCategoryFrequency();
    if (frequency.isEmpty) return null;

    return frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
