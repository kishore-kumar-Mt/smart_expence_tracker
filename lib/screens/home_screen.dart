import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/currency_formatter.dart'; // Add import at the top

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/budget_service.dart';
import '../services/notification_service.dart';
import 'all_transactions_screen.dart';
import 'notifications_screen.dart';
import 'category_transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkMonthlyReset();
  }

  @override
  void dispose() {
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseService, BudgetService>(
      builder: (context, expenseService, budgetService, child) {
        final expenses = expenseService.expenses;
        final totalSpent = expenseService.totalSpent;
        final totalIncome = expenseService.totalIncome;
        final totalBudget = budgetService.currentBudget;
        final status = budgetService.getStatus(
          totalSpent,
          totalBudget,
          totalIncome: totalIncome,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Smart Expense'),
            actions: [
              Consumer<NotificationService>(
                builder: (context, notificationService, _) {
                  return IconButton(
                    icon: Badge(
                      isLabelVisible: notificationService.unreadCount > 0,
                      label: Text('${notificationService.unreadCount}'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  );
                },
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
    // final currencyFormat = NumberFormat.currency(symbol: '\$'); // Removed unused formatter

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
                CurrencyFormatter.format(totalSpent),
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
                        CurrencyFormatter.format(remainingBudget),
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
                  amount: CurrencyFormatter.formatCompact(
                    expenseService.getCategoryTotal('Food'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.flight,
                  label: 'Travel',
                  color: Colors.blue,
                  amount: CurrencyFormatter.formatCompact(
                    expenseService.getCategoryTotal('Travel'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.shopping_bag,
                  label: 'Shopping',
                  color: Colors.purple,
                  amount: CurrencyFormatter.formatCompact(
                    expenseService.getCategoryTotal('Shopping'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.movie,
                  label: 'Entertainment',
                  color: Colors.red,
                  amount: CurrencyFormatter.formatCompact(
                    expenseService.getCategoryTotal('Entertainment'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.receipt,
                  label: 'Bills',
                  color: Colors.green,
                  amount: CurrencyFormatter.formatCompact(
                    expenseService.getCategoryTotal('Bills'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.local_hospital,
                  label: 'Health',
                  color: Colors.teal,
                  amount: CurrencyFormatter.formatCompact(
                    expenseService.getCategoryTotal('Health'),
                  ),
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  icon: Icons.category,
                  label: 'Other',
                  color: Colors.grey,
                  amount: CurrencyFormatter.formatCompact(
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

    // Determine color and icon based on type
    if (expense.type == TransactionType.income) {
      color = Colors.green;
      icon = Icons.monetization_on;

      // Override specific income category icons if we had them mapped
      if (expense.category == 'Salary') icon = Icons.work;
      if (expense.category == 'Bonus') icon = Icons.star;
      if (expense.category == 'Investment') icon = Icons.trending_up;
    } else {
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
          color = Colors
              .green; // Expense 'Bills' also green? Maybe choose different shade or keep as is.
          // Requirement says "Red for Expense, Green for Income".
          // If we strictly follow "Red for Expense", all expense categories become red?
          // Usually category colors differ. "Color coding" likely refers to the AMOUNT text.
          break;
        default:
          icon = Icons.attach_money;
          color = Colors.grey;
      }
    }

    // final currencyFormat = NumberFormat.currency(symbol: '\$'); // Removed unused formatter
    final isIncome = expense.type == TransactionType.income;
    final amountColor = isIncome ? Colors.green : Colors.red;
    final prefix = isIncome ? '+' : '-';

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
              'Are you sure you want to delete this transaction?',
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
        elevation: 0, // Cleaner look
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          title: Text(
            expense.note?.isNotEmpty == true ? expense.note! : expense.category,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            DateFormat('MMM d, y').format(expense.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            '$prefix${CurrencyFormatter.format(expense.amount)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
