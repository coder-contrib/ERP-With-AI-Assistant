import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ceramic_erp/core/theme/app_theme.dart';
import '../../data/dashboard_repository.dart';

class TopProductsChart extends StatelessWidget {
  final List<TopProductData> data;
  const TopProductsChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No product data'));
    final total = data.fold(0.0, (sum, e) => sum + e.totalRevenue);
    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info, AppColors.error];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Products by Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.asMap().entries.map((e) {
                        final pct = (e.value.totalRevenue / total * 100);
                        return PieChartSectionData(
                          value: e.value.totalRevenue,
                          color: colors[e.key % colors.length],
                          radius: 50,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key % colors.length], borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.value.productName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            Text('\$${e.value.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
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
