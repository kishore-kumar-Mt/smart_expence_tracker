import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/budget_service.dart';
import '../services/notification_service.dart';
import 'add_expense_screen.dart';
import 'analytics_screen.dart';
import 'all_transactions_screen.dart';
import 'category_transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Alert State Flags
  bool _hasShownWarning = false;
  bool _hasShownExceeded = false;

  @override
  void initState() {
    super.initState();
    _checkMonthlyReset();

    // Listen to expense changes for budget alerts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final expenseService = context.read<ExpenseService>();
      expenseService.addListener(_checkBudgetStatus);
    });
  }

  @override
  void dispose() {
    final expenseService = context.read<ExpenseService>();
    expenseService.removeListener(_checkBudgetStatus);
    super.dispose();
  }

  void _checkBudgetStatus() {
    final expenseService = context.read<ExpenseService>();
    final budgetService = context.read<BudgetService>();

    final totalSpent = expenseService.totalSpent;
    final totalBudget = budgetService.currentBudget;
    final status = budgetService.getStatus(totalSpent, totalBudget);

    // Reset flags if budget status improves
    if (status.percentageUsed < 0.8) {
      _hasShownWarning = false;
      _hasShownExceeded = false;
    } else if (status.percentageUsed < 1.0) {
      _hasShownExceeded = false;
    }

    if (status.isExceeded && !_hasShownExceeded) {
      _hasShownExceeded = true;
      _triggerAlert(
        'Budget Exceeded!',
        'You have exceeded your monthly budget of \$${totalBudget.toStringAsFixed(0)}.',
      );
    } else if (status.isNearLimit && !_hasShownWarning) {
      _hasShownWarning = true;
      _triggerAlert('Budget Warning', 'You have used over 80% of your budget.');
    }
  }

  void _triggerAlert(String title, String body) {
    // 1. System Notification
    NotificationService.instance.showBudgetAlert(title, body);

    // 2. In-App Dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense(Map<String, dynamic> data) async {
    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: data['amount'] as double,
      category: data['category'] as String,
      date: data['date'] as DateTime,
      note: data['note'] as String?,
    );

    final expenseService = context.read<ExpenseService>();
    await expenseService.addExpense(newExpense);
  }

  Future<void> _checkMonthlyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMonth = prefs.getInt('last_known_month');
    final lastYear = prefs.getInt('last_known_year');
    final now = DateTime.now();

    if (lastMonth != null && lastYear != null) {
      if (lastMonth != now.month || lastYear != now.year) {
        // New month detected!
        final startOfCurrentMonth = DateTime(now.year, now.month, 1);
        final expenseService = context.read<ExpenseService>();
        await expenseService.deleteExpensesBefore(startOfCurrentMonth);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Welcome to ${DateFormat('MMMM').format(now)}! Expenses have been reset.',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }

    // Update stored month/year to current
    await prefs.setInt('last_known_month', now.month);
    await prefs.setInt('last_known_year', now.year);
  }

  void _showEditBudgetDialog() {
    final budgetService = context.read<BudgetService>();
    final TextEditingController controller = TextEditingController(
      text: budgetService.currentBudget.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Budget'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly Budget',
              prefixText: '\$ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newValue = double.tryParse(controller.text);
                if (newValue != null && newValue > 0) {
                  await budgetService.setBudget(newValue);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget updated successfully!'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid positive amount.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseService, BudgetService>(
      builder: (context, expenseService, budgetService, child) {
        final expenses = expenseService.expenses;
        final totalSpent = expenseService.totalSpent;
        final totalBudget = budgetService.currentBudget;
        final status = budgetService.getStatus(totalSpent, totalBudget);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Smart Expense'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Budget',
                onPressed: _showEditBudgetDialog,
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(
                  totalSpent: totalSpent,
                  remainingBudget: status.remaining,
                  isExceeded: status.isExceeded,
                ),
                const _CategorySection(),
                _RecentTransactionsList(expenses: expenses),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
              );

              if (result != null && result is Map<String, dynamic>) {
                await _addExpense(result);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense added successfully!'),
                    ),
                  );
                }
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalSpent;
  final double remainingBudget;
  final bool isExceeded;

  const _SummaryCard({
    required this.totalSpent,
    required this.remainingBudget,
    this.isExceeded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Container(
      margin: const EdgeInsets.all(16.0),
      width: double.infinity,
      child: Card(
        color: isExceeded ? Colors.red.shade400 : theme.colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Spent',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currencyFormat.format(totalSpent),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Remaining',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(remainingBudget),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection();

  @override
  Widget build(BuildContext context) {
    final expenseService = context.watch<ExpenseService>();
    final currencyFormat = NumberFormat.compactSimpleCurrency();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Categories',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _CategoryCard(
                  icon: Icons.restaurant,
                  label: 'Food',
                  color: Colors.orange,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Food'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.flight,
                  label: 'Travel',
                  color: Colors.blue,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Travel'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.shopping_bag,
                  label: 'Shopping',
                  color: Colors.purple,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Shopping'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.movie,
                  label: 'Entertainment',
                  color: Colors.red,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Entertainment'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.receipt,
                  label: 'Bills',
                  color: Colors.green,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Bills'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.local_hospital,
                  label: 'Health',
                  color: Colors.teal,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Health'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.category,
                  label: 'Other',
                  color: Colors.grey,
                  amount: currencyFormat.format(
                    expenseService.getCategoryTotal('Other'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String amount;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CategoryTransactionsScreen(categoryName: label),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsList extends StatelessWidget {
  final List<Expense> expenses;

  const _RecentTransactionsList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final recentExpenses = expenses.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTransactionsScreen(),
                    ),
                  );
                },
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentExpenses.isEmpty)
            const Text('No transactions yet')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentExpenses.length,
              itemBuilder: (context, index) {
                return _TransactionItem(expense: recentExpenses[index]);
              },
            ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Expense expense;
  const _TransactionItem({required this.expense});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (expense.category) {
      case 'Food':
        icon = Icons.restaurant;
        color = Colors.orange;
        break;
      case 'Travel':
        icon = Icons.flight;
        color = Colors.blue;
        break;
      case 'Shopping':
        icon = Icons.shopping_bag;
        color = Colors.purple;
        break;
      case 'Entertainment':
        icon = Icons.movie;
        color = Colors.red;
        break;
      case 'Health':
        icon = Icons.local_hospital;
        color = Colors.teal;
        break;
      case 'Bills':
        icon = Icons.receipt;
        color = Colors.green;
        break;
      default:
        icon = Icons.attach_money;
        color = Colors.grey;
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text(
              'Are you sure you want to delete this expense?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<ExpenseService>().deleteExpense(expense.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          title: Text(
            expense.note?.isNotEmpty == true ? expense.note! : expense.category,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            DateFormat('MMM d, y').format(expense.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            '-${currencyFormat.format(expense.amount)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
