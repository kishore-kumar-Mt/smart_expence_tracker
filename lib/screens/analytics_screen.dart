import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final expenseService = context.watch<ExpenseService>();
    final categoryData = expenseService.getCategoryTotals();
    final dailyData = expenseService.getDailyTotalsForMonth();
    final expenses = expenseService.expenses;
    final totalSpent = expenseService.getTotalSpent();
    final topCategory = expenseService.getTopSpendingCategory();
    final mostFrequentCategory = expenseService.getMostFrequentCategory();

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for contrast
      appBar: AppBar(
        title: const Text('Analytics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: expenses.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Smart Insights Section
                _AnalyticsCard(
                  title: 'Smart Insights',
                  icon: Icons.lightbulb_outline,
                  child: Column(
                    children: [
                      _InsightRow(
                        label: 'Total Spent',
                        value: NumberFormat.currency(
                          symbol: '\$',
                        ).format(totalSpent),
                        isHighlight: true,
                      ),
                      const Divider(height: 24),
                      _InsightRow(
                        label: 'Top Category',
                        value: topCategory != null
                            ? '$topCategory (${NumberFormat.currency(symbol: '\$').format(categoryData[topCategory])})'
                            : '-',
                      ),
                      const SizedBox(height: 12),
                      _InsightRow(
                        label: 'Most Frequent',
                        value: mostFrequentCategory ?? '-',
                      ),
                      const SizedBox(height: 12),
                      _InsightRow(
                        label: 'Total Transactions',
                        value: '${expenses.length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Category Breakdown Section
                _AnalyticsCard(
                  title: 'Category Breakdown',
                  icon: Icons.pie_chart_outline,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 250,
                        child: categoryData.isEmpty
                            ? _buildSectionEmptyState(
                                'No category data',
                                Icons.pie_chart_outline,
                              )
                            : PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback:
                                        (FlTouchEvent event, pieTouchResponse) {
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
                                  sectionsSpace: 0,
                                  centerSpaceRadius: 40,
                                  sections: _buildPieSections(categoryData),
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                      _buildDynamicIndicators(categoryData),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Daily Expenses Section
                _AnalyticsCard(
                  title: 'Daily Trends',
                  icon: Icons.bar_chart,
                  child: SizedBox(
                    height: 250,
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
                                  tooltipPadding: const EdgeInsets.all(8),
                                  tooltipMargin: 8,
                                  getTooltipItem:
                                      (
                                        BarChartGroupData group,
                                        int groupIndex,
                                        BarChartRodData rod,
                                        int rodIndex,
                                      ) {
                                        return BarTooltipItem(
                                          '\$${rod.toY.round()}',
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
                                    reservedSize: 42,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: _leftTitles,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey[200],
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: _buildBarGroups(dailyData),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // Comprehensive empty state when no expenses at all
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 120,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Analytics Available',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Start tracking your expenses to see\ninsightful analytics and spending patterns',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Expense'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'What you\'ll see here:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    context,
                    Icons.pie_chart,
                    'Category breakdown with visual charts',
                  ),
                  _buildFeatureItem(
                    context,
                    Icons.bar_chart,
                    'Daily spending trends',
                  ),
                  _buildFeatureItem(
                    context,
                    Icons.insights,
                    'Smart insights and spending patterns',
                  ),
                ],
              ),
            ),
          ],
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
  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // Build dynamic pie chart sections from live category data
  // Build dynamic pie chart sections from live category data
  List<PieChartSectionData> _buildPieSections(
    Map<String, double> categoryData,
  ) {
    if (categoryData.isEmpty) return [];

    final total = categoryData.values.fold(0.0, (sum, value) => sum + value);
    final colors = _getCategoryColors();

    int index = 0;
    return categoryData.entries.map((entry) {
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;
      final percentage = (entry.value / total * 100).toStringAsFixed(1);

      final section = PieChartSectionData(
        color: colors[entry.key] ?? Colors.grey,
        value: entry.value,
        title: '$percentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
        badgePositionPercentageOffset: .98,
      );

      index++;
      return section;
    }).toList();
  }

  // Build dynamic indicators from live category data
  Widget _buildDynamicIndicators(Map<String, double> categoryData) {
    if (categoryData.isEmpty) return const SizedBox.shrink();

    final colors = _getCategoryColors();

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: categoryData.keys.map((category) {
        return _Indicator(
          color: colors[category] ?? Colors.grey,
          text: category,
          isSquare: false, // Changed to circle for refined look
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
  Map<String, Color> _getCategoryColors() {
    return {
      'Food': Colors.orange,
      'Travel': Colors.blue,
      'Shopping': Colors.purple,
      'Entertainment': Colors.red,
      'Health': Colors.teal,
      'Bills': Colors.green,
      'Transport': Colors.indigo,
      'Education': Colors.amber,
      'Other': Colors.grey,
    };
  }

  // Bar Chart Helper Methods
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

  Widget _leftTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff7589a2),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    if (value == 0) {
      return Container();
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text('\$${value.toInt()}', style: style),
    );
  }

  Widget _InsightRow({
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isHighlight
              ? Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600])
              : Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: isHighlight
              ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                )
              : Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
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
