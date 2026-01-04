import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import 'database_helper.dart';

class ExpenseService extends ChangeNotifier {
  static final ExpenseService _instance = ExpenseService._internal();
  static ExpenseService get instance => _instance;

  ExpenseService._internal();

  List<Expense> _expenses = [];

  // Public getter for expenses
  List<Expense> get expenses => List.unmodifiable(_expenses);

  // Computed property: Total amount spent
  double get totalSpent {
    return _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
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
    notifyListeners();
  }

  // Add a new expense
  Future<void> addExpense(Expense expense) async {
    await DatabaseHelper.instance.insertExpense(expense);
    _expenses.add(expense);
    notifyListeners();
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
  Map<String, double> getCategoryTotals() {
    final Map<String, double> totals = {};
    for (var expense in _expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  /// Get daily totals for the current month
  /// Returns a map where key is the day of month (1-31) and value is total spent
  Map<int, double> getDailyTotalsForMonth([DateTime? month]) {
    final targetMonth = month ?? DateTime.now();
    final Map<int, double> dailyTotals = {};

    for (var expense in _expenses) {
      // Only include expenses from the target month and year
      if (expense.date.year == targetMonth.year &&
          expense.date.month == targetMonth.month) {
        final day = expense.date.day;
        dailyTotals[day] = (dailyTotals[day] ?? 0) + expense.amount;
      }
    }

    return dailyTotals;
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
