import 'package:fl_chart/fl_chart.dart';
import '../utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/expense_service.dart';
import '../models/expense.dart';
import 'add_expense_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int touchedIndex = -1;
  int _selectedIndex = 0; // 0: Expense, 1: Income, 2: Combined

  @override
  Widget build(BuildContext context) {
    final expenseService = context.watch<ExpenseService>();
    final expenses = expenseService.expenses;

    // Determine data based on selection
    Map<String, double> categoryData = {};
    Map<int, double> dailyData = {};
    Map<String, Map<String, double>> comparisonData = {};

    if (_selectedIndex == 0) {
      categoryData = expenseService.getCategoryTotals(
        type: TransactionType.expense,
      );
      dailyData = expenseService.getDailyTotalsForMonth(
        type: TransactionType.expense,
      );
    } else if (_selectedIndex == 1) {
      categoryData = expenseService.getCategoryTotals(
        type: TransactionType.income,
      );
      dailyData = expenseService.getDailyTotalsForMonth(
        type: TransactionType.income,
      );
    } else {
      comparisonData = expenseService.getWeeklyComparison();
    }

    final totalSpent = expenseService.totalSpent;
    final totalIncome = expenseService.totalIncome;

    // Top Category Logic (re-calculated below based on current view data)

    // Re-calculating top category based on current categoryData
    String? currentTopCategory;
    if (categoryData.isNotEmpty) {
      currentTopCategory = categoryData.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Analytics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: expenses.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              children: [
                // Toggle Switch
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleOption('Expense', 0),
                        _buildToggleOption('Income', 1),
                        _buildToggleOption('Combined', 2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Smart Insights Section
                if (_selectedIndex != 2) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _InsightCard(
                          label: _selectedIndex == 0
                              ? 'Total Spent'
                              : 'Total Income',
                          value: CurrencyFormatter.formatCompact(
                            _selectedIndex == 0 ? totalSpent : totalIncome,
                          ),
                          icon: _selectedIndex == 0
                              ? Icons.account_balance_wallet
                              : Icons.monetization_on,
                          color: _selectedIndex == 0
                              ? Colors.red
                              : Colors.green,
                          isPrimary: true,
                        ),
                      ),
                      if (categoryData.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InsightCard(
                            label: 'Top Category',
                            value: currentTopCategory ?? '-',
                            subValue: currentTopCategory != null
                                ? CurrencyFormatter.formatCompact(
                                    categoryData[currentTopCategory]!,
                                  )
                                : null,
                            icon: Icons.trending_up,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Charts Section
                if (_selectedIndex == 2) ...[
                  // Legend for Comparison Chart
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem('Income', Colors.green),
                        const SizedBox(width: 24),
                        _buildLegendItem('Expense', Colors.red),
                      ],
                    ),
                  ),

                  _AnalyticsCard(
                    title: 'Last 7 Days Comparison',
                    icon: Icons.compare_arrows,
                    child: SizedBox(
                      height: 250, // Reduced fixed height
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _calculateComparisonMaxY(comparisonData),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.blueGrey,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                String type = rodIndex == 0
                                    ? 'Income'
                                    : 'Expense';
                                return BarTooltipItem(
                                  '$type\n${CurrencyFormatter.formatCompact(rod.toY)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) =>
                                    _bottomTitlesComparison(
                                      val,
                                      meta,
                                      comparisonData,
                                    ),
                                reservedSize: 30,
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval:
                                _calculateComparisonMaxY(comparisonData) > 0
                                ? _calculateComparisonMaxY(comparisonData) / 5
                                : 100,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                            ),
                          ),
                          barGroups: _buildComparisonBarGroups(comparisonData),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Category Breakdown Section
                  _AnalyticsCard(
                    title: 'Category Breakdown',
                    icon: Icons.pie_chart_outline,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 300, // Increased height for larger chart
                          child: categoryData.isEmpty
                              ? _buildSectionEmptyState(
                                  'No category data',
                                  Icons.pie_chart_outline,
                                )
                              : PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback:
                                          (
                                            FlTouchEvent event,
                                            pieTouchResponse,
                                          ) {
                                            setState(() {
                                              if (!event
                                                      .isInterestedForInteractions ||
                                                  pieTouchResponse == null ||
                                                  pieTouchResponse
                                                          .touchedSection ==
                                                      null) {
                                                touchedIndex = -1;
                                                return;
                                              }
                                              touchedIndex = pieTouchResponse
                                                  .touchedSection!
                                                  .touchedSectionIndex;
                                            });
                                          },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 2, // Added small space
                                    centerSpaceRadius: 40,
                                    sections: _buildPieSections(categoryData),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        _buildDynamicIndicators(categoryData),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Daily Trends Section
                  _AnalyticsCard(
                    title: 'Daily Trends',
                    icon: Icons.bar_chart,
                    child: SizedBox(
                      height: 220, // Reduced height
                      child: dailyData.isEmpty
                          ? _buildSectionEmptyState(
                              'No data this month',
                              Icons.bar_chart,
                            )
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _calculateMaxY(dailyData),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBgColor: Colors.blueGrey,
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            CurrencyFormatter.formatCompact(
                                              rod.toY,
                                            ),
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) =>
                                          _bottomTitles(value, meta, dailyData),
                                      reservedSize: 30, // Reduced reserved size
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: _buildBarGroups(dailyData),
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildToggleOption(String text, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  double _calculateComparisonMaxY(Map<String, Map<String, double>> data) {
    double max = 0;
    for (var entry in data.values) {
      if (entry['income']! > max) max = entry['income']!;
      if (entry['expense']! > max) max = entry['expense']!;
    }
    return (max * 1.1).ceilToDouble();
  }

  Widget _bottomTitlesComparison(
    double value,
    TitleMeta meta,
    Map<String, Map<String, double>> data,
  ) {
    final keys = data.keys
        .toList(); // Mon, Tue... (stored in reverse order in service?)
    // Service returns map. Insertion order usually preserved.
    // If index out of bounds, return empty.
    if (value.toInt() < 0 || value.toInt() >= keys.length)
      return const SizedBox();

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        keys[value.toInt()],
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<BarChartGroupData> _buildComparisonBarGroups(
    Map<String, Map<String, double>> data,
  ) {
    int x = 0;
    return data.entries.map((entry) {
      final income = entry.value['income']!;
      final expense = entry.value['expense']!;

      return BarChartGroupData(
        x: x++,
        barRods: [
          BarChartRodData(
            toY: income,
            color: Colors.green,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
          BarChartRodData(
            toY: expense,
            color: Colors.red,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
        barsSpace: 4,
      );
    }).toList();
  }

  // Comprehensive empty state when no expenses at all
  Future<void> _navigateToAddExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
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

  // Comprehensive empty state when no expenses at all
  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Analytics Available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Add your first expense to unlock insightful charts and spending trends.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _navigateToAddExpense,
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Expense'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // Add spacing at bottom to avoid FAB overlap if any
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // Section-specific empty state
  Widget _buildSectionEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Helper for feature list items

  // Build dynamic pie chart sections from live category data
  List<PieChartSectionData> _buildPieSections(
    Map<String, double> categoryData,
  ) {
    if (categoryData.isEmpty) return [];

    // Filter out zero or negative values
    final validData = Map.fromEntries(
      categoryData.entries.where((e) => e.value > 0),
    );
    if (validData.isEmpty) return [];

    final total = validData.values.fold(0.0, (sum, value) => sum + value);

    // Group small slices (< 5%) into "Others"
    final Map<String, double> groupedData = {};
    double othersTotal = 0;

    for (var entry in validData.entries) {
      final percentage = entry.value / total;
      if (percentage < 0.05) {
        othersTotal += entry.value;
      } else {
        groupedData[entry.key] = entry.value;
      }
    }

    if (othersTotal > 0) {
      groupedData['Others'] = othersTotal;
    }

    // Sort by value descending
    final sortedEntries = groupedData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int index = 0;
    return sortedEntries.map((entry) {
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 110.0 : 100.0; // Increased radius
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      final color = _getCategoryColor(entry.key);

      final section = PieChartSectionData(
        color: color,
        value: entry.value,
        title: '$percentage%', // Show percentage
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white, // Ensure high contrast
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
        titlePositionPercentageOffset: 0.6, // Inside centered
        badgeWidget: _Badge(entry.key, size: 40, borderColor: color),
        badgePositionPercentageOffset:
            1.3, // Outside label for category name? Or just use legend?
        // Let's stick to percentage inside and Legend below for clean look.
        // User asked for "Percentage values clearly outside or inside". Inside is cleaner for Donut.
        // Actually, user asked "Display percentage values clearly outside or inside slices".
      );

      index++;
      return section;
    }).toList();
  }

  Color _getCategoryColor(String category) {
    // Distinct, high-contrast colors
    const colors = {
      'Food': Color(0xFFFF5722), // Deep Orange
      'Travel': Color(0xFF2196F3), // Blue
      'Shopping': Color(0xFFE91E63), // Pink
      'Entertainment': Color(0xFF9C27B0), // Purple
      'Health': Color(0xFF009688), // Teal
      'Bills': Color(0xFF4CAF50), // Green
      'Transport': Color(0xFF3F51B5), // Indigo
      'Education': Color(0xFFFFC107), // Amber
      'Rent': Color(0xFF795548), // Brown
      'Salary': Color(0xFF43A047), // Green 600
      'Bonus': Color(0xFFFFD54F), // Amber 300
      'Investment': Color(0xFF1976D2), // Blue 700
      'Others': Color(0xFF9E9E9E), // Grey
    };
    return colors[category] ??
        Colors.primaries[category.hashCode % Colors.primaries.length];
  }

  // Build dynamic indicators from live category data
  Widget _buildDynamicIndicators(Map<String, double> categoryData) {
    if (categoryData.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: categoryData.keys.map((category) {
        return _Indicator(
          color: _getCategoryColor(category),
          text: category,
          isSquare: false,
        );
      }).toList(),
    );
  }

  // Build dynamic bar groups from daily data
  List<BarChartGroupData> _buildBarGroups(Map<int, double> dailyData) {
    final sortedDays = dailyData.keys.toList()..sort();

    return sortedDays.take(10).map((day) {
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: dailyData[day]!,
            color: Theme.of(context).primaryColor,
            width: 14, // Slightly thinner for better spacing
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _calculateMaxY(dailyData),
              color: Colors.grey[100], // Subtle background for bar track
            ),
          ),
        ],
      );
    }).toList();
  }

  // Calculate max Y value for bar chart
  double _calculateMaxY(Map<int, double> dailyData) {
    if (dailyData.isEmpty) return 100;
    final maxValue = dailyData.values.reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.1).ceilToDouble(); // Reduced padding to 1.1x
  }

  // Category color mapping

  // Bar Chart Helper Methods

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _bottomTitles(
    double value,
    TitleMeta meta,
    Map<int, double> dailyData,
  ) {
    const style = TextStyle(
      color: Colors.grey,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text('${value.toInt()}', style: style),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color color;
  final bool isPrimary;

  const _InsightCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subValue,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isPrimary ? 24 : 18,
              color: Colors.black87,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(
              subValue!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _AnalyticsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final double size;
  final Color borderColor;

  const _Badge(this.text, {required this.size, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(2, 2),
            blurRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.15),
      child: Center(
        child: FittedBox(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
  });

  final Color color;
  final String text;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
            borderRadius: isSquare ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
