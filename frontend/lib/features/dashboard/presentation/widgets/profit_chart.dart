import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dashboard_repository.dart';

class ProfitChart extends StatelessWidget {
  final List<MonthlyProfitData> data;
  const ProfitChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No profit data'));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Monthly Profit & Loss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              _legend('Revenue', AppColors.primary),
              const SizedBox(width: 16),
              _legend('Net Profit', AppColors.success),
              const SizedBox(width: 16),
              _legend('Expenses', AppColors.error),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.border, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text(_formatValue(v), style: TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= data.length) return const SizedBox();
                    return Text(data[i].month.substring(5), style: TextStyle(fontSize: 10, color: AppColors.textSecondary));
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value.revenue, color: AppColors.primary, width: 8, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: e.value.netProfit, color: AppColors.success, width: 8, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: e.value.expenses, color: AppColors.error, width: 8, borderRadius: BorderRadius.circular(4)),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  String _formatValue(double v) {
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}
