import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dashboard_repository.dart';

class CashFlowChart extends StatelessWidget {
  final List<CashFlowData> data;
  const CashFlowChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No cash flow data'));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Cash Flow (14 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              _legend('In', AppColors.success),
              const SizedBox(width: 12),
              _legend('Out', AppColors.error),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) => Text('\$${(v / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= data.length) return const SizedBox();
                    return Text(data[i].date.substring(8), style: TextStyle(fontSize: 10, color: AppColors.textSecondary));
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value.cashIn, color: AppColors.success, width: 6, borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(toY: e.value.cashOut, color: AppColors.error, width: 6, borderRadius: BorderRadius.circular(3)),
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
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}
