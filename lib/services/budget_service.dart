import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetStatus {
  final double budget;
  final double spent;
  final double remaining;
  final double percentageUsed;
  final bool isNearLimit; // > 80%
  final bool isExceeded; // > 100%

  BudgetStatus({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percentageUsed,
    required this.isNearLimit,
    required this.isExceeded,
  });
}

class BudgetService extends ChangeNotifier {
  static final BudgetService instance = BudgetService._init();
  static const String _budgetKey = 'monthly_budget';
  static const double _defaultBudget = 5000.0;

  double _currentBudget = _defaultBudget;

  BudgetService._init() {
    _loadBudget();
  }

  // Public getter for current budget
  double get currentBudget => _currentBudget;

  // Load budget from SharedPreferences
  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    _currentBudget = prefs.getDouble(_budgetKey) ?? _defaultBudget;
    notifyListeners();
  }

  Future<void> setBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, amount);
    _currentBudget = amount;
    notifyListeners();
  }

  Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? _defaultBudget;
  }

  BudgetStatus getStatus(double totalExpenses, double budgetLimit) {
    final remaining = budgetLimit - totalExpenses;
    final percentage = budgetLimit > 0 ? (totalExpenses / budgetLimit) : 0.0;

    return BudgetStatus(
      budget: budgetLimit,
      spent: totalExpenses,
      remaining: remaining,
      percentageUsed: percentage,
      isNearLimit: percentage >= 0.8 && percentage < 1.0,
      isExceeded: percentage >= 1.0,
    );
  }
}
