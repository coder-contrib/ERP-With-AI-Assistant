import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

final insightsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/insights/');
  return response.data['insights'] as List? ?? [];
});

class DashboardInsightsWidget extends ConsumerWidget {
  const DashboardInsightsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('AI Business Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: () => ref.invalidate(insightsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: insightsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.error))),
              data: (insights) {
                if (insights.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 40, color: AppColors.success),
                        const SizedBox(height: 8),
                        const Text('All clear!', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('No issues detected', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: insights.length,
                  itemBuilder: (_, i) {
                    final insight = insights[i] as Map<String, dynamic>;
                    return _InsightCard(insight: insight, isDark: isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  final bool isDark;

  const _InsightCard({required this.insight, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final severity = insight['severity'] ?? 'info';
    final color = _severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Icon(_severityIcon(severity), size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight['title'] ?? '',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insight['message'] ?? '',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'success': return AppColors.success;
      default: return AppColors.info;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical': return Icons.error_rounded;
      case 'warning': return Icons.warning_rounded;
      case 'success': return Icons.trending_up_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }
}
