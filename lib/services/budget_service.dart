import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

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

  // Deduplication state
  String _lastAlertStatus = 'none'; // 'none', 'near', 'exceeded'

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
    // Reset alert status on budget change
    _lastAlertStatus = 'none';
    notifyListeners();
  }

  Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? _defaultBudget;
  }

  BudgetStatus getStatus(
    double totalExpenses,
    double budgetLimit, {
    double totalIncome = 0.0,
  }) {
    final effectiveBudget = budgetLimit + totalIncome;
    final remaining = effectiveBudget - totalExpenses;
    final percentage = effectiveBudget > 0
        ? (totalExpenses / effectiveBudget)
        : 0.0;

    final isNearLimit = percentage >= 0.8 && percentage < 1.0;
    final isExceeded = percentage >= 1.0;

    _checkAndTriggerNotifications(isNearLimit, isExceeded, effectiveBudget);

    return BudgetStatus(
      budget: budgetLimit,
      spent: totalExpenses,
      remaining: remaining,
      percentageUsed: percentage,
      isNearLimit: isNearLimit,
      isExceeded: isExceeded,
    );
  }

  void _checkAndTriggerNotifications(
    bool isNearLimit,
    bool isExceeded,
    double limit,
  ) {
    String currentStatus = 'none';
    if (isExceeded) {
      currentStatus = 'exceeded';
    } else if (isNearLimit) {
      currentStatus = 'near';
    }

    // Only trigger if status changed to a worse state or different state
    // Avoiding spam if already sent for this month/period
    // Ideally we should reset this status monthly, but budget service doesn't track time.
    // However, if user keeps spending, it stays 'exceeded'.

    if (currentStatus != _lastAlertStatus) {
      _lastAlertStatus = currentStatus;

      if (currentStatus == 'exceeded') {
        NotificationService.instance.addNotification(
          title: 'Budget Exceeded!',
          body: 'You have exceeded your budget of ₹${limit.toStringAsFixed(0)}',
          type: 'alert',
        );
      } else if (currentStatus == 'near') {
        NotificationService.instance.addNotification(
          title: 'Budget Warning',
          body: 'You have used 80% of your budget.',
          type: 'alert',
        );
      }
    }
  }

  // Method to reset alert status (e.g. called on month reset)
  void resetAlerts() {
    _lastAlertStatus = 'none';
  }
}
