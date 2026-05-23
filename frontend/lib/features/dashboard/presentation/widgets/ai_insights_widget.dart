import 'package:flutter/material.dart';
import 'package:ceramic_erp/core/theme/app_theme.dart';
import '../../data/dashboard_repository.dart';

class AIInsightsWidget extends StatelessWidget {
  final List<AIInsight> insights;
  const AIInsightsWidget({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('AI Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            Expanded(child: Center(child: Text('No insights available', style: TextStyle(color: AppColors.textSecondary))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: insights.length,
                itemBuilder: (_, i) {
                  final insight = insights[i];
                  final color = _severityColor(insight.severity);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_severityIcon(insight.severity), size: 16, color: color),
                            const SizedBox(width: 6),
                            Text(insight.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(insight.message, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
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
      case 'success': return Icons.check_circle_rounded;
      default: return Icons.info_rounded;
    }
  }
}
