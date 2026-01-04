import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_expense_tracker/services/notification_service.dart';
import 'package:smart_expense_tracker/services/expense_service.dart';
import 'package:smart_expense_tracker/services/budget_service.dart';
import 'theme/app_theme.dart';

import 'screens/auth_screen.dart';
import 'package:smart_expense_tracker/services/auth_service.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await AuthService.instance.initialize();

  // Initialize ExpenseService and load expenses
  await ExpenseService.instance.loadExpenses();

  runApp(const SmartExpenseTrackerApp());
}

class SmartExpenseTrackerApp extends StatelessWidget {
  const SmartExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ExpenseService.instance),
        ChangeNotifierProvider.value(value: BudgetService.instance),
      ],
      child: MaterialApp(
        title: 'Smart Expense Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: AuthService.instance.isSetupComplete
            ? const AuthScreen()
            : const SetupScreen(),
      ),
    );
  }
}
