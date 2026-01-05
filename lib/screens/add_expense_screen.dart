import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/budget_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  // Maintaining class name 'AddExpenseScreen' for navigation compatibility,
  // but logically this is now AddTransactionScreen.

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController =
      TextEditingController(); // Name for Income, Note for Expense

  TransactionType _selectedType = TransactionType.expense;
  bool _isRepeated = false; // Tab state

  String? _selectedCategory;
  DateTime? _selectedDate;

  // Recurrence fields
  RecurrenceFrequency _selectedFrequency = RecurrenceFrequency.daily;
  TextEditingController _occurrencesController = TextEditingController();
  bool _isUnlimited = true;

  final List<String> _expenseCategories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Other',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Bonus',
    'Investment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateFormState);
    _noteController.addListener(_updateFormState);
    _occurrencesController.addListener(_updateFormState);
  }

  void _updateFormState() {
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateFormState);
    _noteController.removeListener(_updateFormState);
    _occurrencesController.removeListener(_updateFormState);
    _amountController.dispose();
    _noteController.dispose();
    _occurrencesController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final amount = double.tryParse(_amountController.text);
    final hasAmount = amount != null && amount > 0;
    final hasCategory = _selectedCategory != null;
    final hasDate = _selectedDate != null;

    if (!hasAmount || !hasCategory || !hasDate) return false;

    if (_selectedType == TransactionType.income) {
      if (_noteController.text.trim().isEmpty) return false;
    }

    if (_isRepeated && !_isUnlimited) {
      final occurrences = int.tryParse(_occurrencesController.text);
      if (occurrences == null || occurrences <= 0) return false;
    }

    return true;
  }

  void _showSetBudgetDialog() {
    final budgetService = context.read<BudgetService>();
    final controller = TextEditingController(
      text: budgetService.currentBudget.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set Monthly Budget'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text);
                if (amount != null && amount > 0) {
                  await budgetService.setBudget(amount);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget updated successfully!'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _presentDatePicker() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: firstDate,
      lastDate: now,
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _updateFormState(); // Trigger validation
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a date')));
        return;
      }

      final transactionData = {
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory,
        'date': _selectedDate,
        'note': _noteController.text,
        'type': _isRepeated ? 'repeated' : _selectedType.name,

        // Recurrence fields
        'frequency': _isRepeated ? _selectedFrequency.name : null,
        'recurrenceStartDate': _isRepeated ? _selectedDate : null,
        'recurrenceOccurrences': (_isRepeated && !_isUnlimited)
            ? int.tryParse(_occurrencesController.text)
            : null,
        'recurrenceTargetType': _isRepeated ? _selectedType.name : null,
      };

      Navigator.of(context).pop(transactionData);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current categories based on selected type
    final currentCategories = _selectedType == TransactionType.income
        ? _incomeCategories
        : _expenseCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Set Budget',
            onPressed: _showSetBudgetDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Segmented Control / Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab('Expense', TransactionType.expense, false),
                  _buildTab('Income', TransactionType.income, false),
                  _buildRepeatedTab(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Shared Amount Input
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: _isRepeated
                          ? 'Amount per Occurence'
                          : (_selectedType == TransactionType.income
                                ? 'Income Amount'
                                : 'Expense Amount'),
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter an amount';
                      if (double.tryParse(value) == null)
                        return 'Invalid number';
                      if (double.parse(value) <= 0)
                        return 'Amount must be positive';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        _selectedType == TransactionType.income
                            ? Icons.monetization_on
                            : Icons.category,
                      ),
                    ),
                    items: currentCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      _updateFormState(); // Trigger validation check
                    },
                    validator: (value) =>
                        value == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 16),

                  if (_isRepeated) ...[
                    // ... (Frequency Dropdown kept mostly same, adding updateFormState just in case)
                    DropdownButtonFormField<RecurrenceFrequency>(
                      value: _selectedFrequency,
                      decoration: InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.update),
                      ),
                      items: RecurrenceFrequency.values.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(f.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedFrequency = val!);
                        _updateFormState();
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: _isUnlimited,
                          onChanged: (val) {
                            setState(() => _isUnlimited = val!);
                            _updateFormState();
                          },
                        ),
                        const Text('Unlimited Occurrences'),
                      ],
                    ),
                    if (!_isUnlimited)
                      TextFormField(
                        controller: _occurrencesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Number of times',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) {
                          if (!_isUnlimited &&
                              (val == null ||
                                  val.isEmpty ||
                                  int.tryParse(val) == null)) {
                            return 'Please enter valid number';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Date Selection
                  InkWell(
                    onTap: () async {
                      await _presentDatePicker();
                      _updateFormState();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: _isRepeated ? 'Start Date' : 'Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(
                          color: _selectedDate == null
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note / Name Input
                  TextFormField(
                    controller: _noteController,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText:
                          (_selectedType == TransactionType.income ||
                              _isRepeated)
                          ? 'Name/Note'
                          : 'Note (Optional)',
                      hintText: 'e.g. Salary, Subscription',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    validator: (value) {
                      if (_selectedType == TransactionType.income &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter a name for income';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isFormValid ? _submitData : null,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: _isRepeated
                            ? Colors.purple
                            : (_selectedType == TransactionType.income
                                  ? Colors.green
                                  : Theme.of(context).primaryColor),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                      ),
                      child: Text(
                        _isRepeated
                            ? 'Schedule Payment'
                            : (_selectedType == TransactionType.income
                                  ? 'Save Income'
                                  : 'Save Expense'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, TransactionType type, bool isRepeatedTab) {
    bool isSelected = !_isRepeated && _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isRepeated = false;
            _selectedType = type;
            _selectedCategory = null; // Reset category on type switch
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatedTab() {
    bool isSelected = _isRepeated;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isRepeated = true;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            'Repeated',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
