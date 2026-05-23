import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ceramic_erp/core/theme/app_theme.dart';
import '../../data/dashboard_repository.dart';

class RevenueChart extends StatelessWidget {
  final List<DailySalesData> data;
  const RevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No sales data'));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Trend (30 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _maxValue() / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text(_formatValue(v), style: TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (data.length / 5).ceilToDouble(), getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= data.length) return const SizedBox();
                    return Text(data[i].date.substring(5), style: TextStyle(fontSize: 10, color: AppColors.textSecondary));
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.totalSales)).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.08)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _maxValue() {
    if (data.isEmpty) return 100;
    return data.map((e) => e.totalSales).reduce((a, b) => a > b ? a : b) * 1.1;
  }

  String _formatValue(double v) {
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}
