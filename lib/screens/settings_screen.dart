import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/budget_service.dart';
import '../services/expense_service.dart';
import '../services/notification_service.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable dark theme'),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (bool value) {
                  settings.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
              const Divider(),

              // Notifications Section
              _buildSectionHeader(context, 'Notifications'),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Allow system notifications'),
                secondary: const Icon(Icons.notifications_active_outlined),
                value: settings.notificationsEnabled,
                onChanged: (bool value) => settings.toggleNotifications(value),
              ),
              if (settings.notificationsEnabled) ...[
                SwitchListTile(
                  title: const Text('Budget Alerts'),
                  subtitle: const Text(
                    'Get notified when nearing budget limit',
                  ),
                  secondary: const Icon(Icons.warning_amber_rounded),
                  value: settings.budgetAlertsEnabled,
                  onChanged: (bool value) => settings.toggleBudgetAlerts(value),
                ),
                SwitchListTile(
                  title: const Text('Income Added'),
                  subtitle: const Text('Get notified on income entries'),
                  secondary: const Icon(Icons.attach_money_rounded),
                  value: settings.incomeAlertsEnabled,
                  onChanged: (bool value) => settings.toggleIncomeAlerts(value),
                ),
                SwitchListTile(
                  title: const Text('Scheduled Payments'),
                  subtitle: const Text('Reminders for recurring expenses'),
                  secondary: const Icon(Icons.calendar_today_rounded),
                  value: settings.scheduledAlertsEnabled,
                  onChanged: (bool value) =>
                      settings.toggleScheduledAlerts(value),
                ),
              ],
              const Divider(),

              // Security Section
              _buildSectionHeader(context, 'Security'),
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('Biometrics & PIN'),
                subtitle: Text(
                  AuthService.instance.authMethod == AuthMethod.none
                      ? 'Not configured'
                      : 'Configured (${AuthService.instance.authMethod.name})',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to security setup or just show info dialog for MVP
                  // For now, let's allow "Reset Security" if configured, or "Setup" if not
                  if (AuthService.instance.authMethod == AuthMethod.none) {
                    // Actually navigating to AuthScreen/Setup might be recursive if not careful.
                    // Let's simplified navigation reset flow.
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    );
                  } else {
                    _showSecurityDialog(context);
                  }
                },
              ),
              const Divider(),

              // Budget Section
              _buildSectionHeader(context, 'Budget'),
              ListTile(
                leading: const Icon(Icons.wallet_outlined),
                title: const Text('Monthly Budget'),
                subtitle: Consumer<BudgetService>(
                  builder: (context, budgetService, _) => Text(
                    CurrencyFormatter.format(budgetService.currentBudget),
                  ),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _showEditBudgetDialog(context),
              ),
              const Divider(),

              // Data Management
              _buildSectionHeader(context, 'Data Management'),
              ListTile(
                leading: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.orange,
                ),
                title: const Text('Clear Notifications'),
                onTap: () => _confirmAction(
                  context,
                  title: 'Clear Notifications',
                  content: 'Are you sure you want to delete all notifications?',
                  onConfirm: () {
                    NotificationService.instance.clearAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications cleared')),
                    );
                  },
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red,
                ),
                title: const Text('Clear All Transactions'),
                subtitle: const Text('This action cannot be undone'),
                onTap: () => _confirmAction(
                  context,
                  title: 'Clear All Data',
                  content:
                      'Are you sure you want to delete ALL expenses and income records? This cannot be undone.',
                  onConfirm: () {
                    ExpenseService.instance
                        .clearAllExpenses(); // Need to implement this if missing
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All transactions deleted')),
                    );
                  },
                ),
              ),
              const Divider(),

              // App Info
              _buildSectionHeader(context, 'About'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Smart Expense Tracker'),
                subtitle: const Text('Version 1.0.0'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Smart Expense Tracker',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Copyright © 2026',
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Empowering you to take control of your finances.',
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                context.read<BudgetService>().setBudget(amount);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Reset Security'),
              leading: const Icon(Icons.lock_reset),
              onTap: () {
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupScreen()),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
