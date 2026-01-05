import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/expense_service.dart';
import '../models/expense.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AnalyticsScreen(),
    const SizedBox.shrink(), // Placeholder for FAB
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) return; // Do nothing for the middle placeholder
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _onFabPressed() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      // Add logic to save expense similar to HomeScreen
      // Duplicating logic here nicely or finding a way to share it
      // Since ExpenseService is a Provider, we can just call it here.

      try {
        final typeStr = result['type'] as String? ?? 'expense';
        final type = TransactionType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => TransactionType.expense,
        );

        // Parse recurrence fields
        final frequencyStr = result['frequency'] as String?;
        final frequency = frequencyStr != null
            ? RecurrenceFrequency.values.firstWhere(
                (e) => e.name == frequencyStr,
              )
            : null;

        final recurrenceStartDate = result['recurrenceStartDate'] as DateTime?;
        final recurrenceOccurrences = result['recurrenceOccurrences'] as int?;
        final recurrenceTargetTypeStr =
            result['recurrenceTargetType'] as String?;
        final recurrenceTargetType = recurrenceTargetTypeStr != null
            ? TransactionType.values.firstWhere(
                (e) => e.name == recurrenceTargetTypeStr,
              )
            : null;

        final newExpense = Expense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: result['amount'] as double,
          category: result['category'] as String,
          date: result['date'] as DateTime,
          note: result['note'] as String?,
          type: type,
          frequency: frequency,
          recurrenceStartDate: recurrenceStartDate,
          recurrenceOccurrences: recurrenceOccurrences,
          recurrenceTargetType: recurrenceTargetType,
        );

        final expenseService = context.read<ExpenseService>();
        await expenseService.addExpense(newExpense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding expense: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use IndexedStack to preserve state of screens (like scrolling position)
    // However, analytics charts might need rebuild to animate, but standard behavior usually preserves.
    // Given "Update Records and Charts dynamically", Provider will handle data updates.

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: SizedBox(
        height: 64, // Larger FAB
        width: 64,
        child: FloatingActionButton(
          onPressed: _onFabPressed,
          elevation: 4,
          backgroundColor: Theme.of(context).primaryColor,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            padding: EdgeInsets.zero,
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildNavItem(Icons.book_outlined, Icons.book, 'Records', 0),
                  _buildNavItem(
                    Icons.bar_chart_outlined,
                    Icons.bar_chart_rounded,
                    'Charts',
                    1,
                  ),
                  const SizedBox(width: 48), // Space for FAB
                  _buildNavItem(
                    Icons.insert_chart_outlined_rounded,
                    Icons.insert_chart_rounded,
                    'Reports',
                    3,
                  ),
                  _buildNavItem(
                    Icons.settings_outlined,
                    Icons.settings,
                    'Settings',
                    4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    final color = isSelected ? theme.primaryColor : Colors.grey.shade400;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
