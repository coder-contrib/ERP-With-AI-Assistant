import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_provider.dart';
import 'widgets/revenue_chart.dart';
import 'widgets/profit_chart.dart';
import 'widgets/cash_flow_chart.dart';
import 'widgets/top_products_chart.dart';
import 'widgets/ai_insights_widget.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardProvider);
    final salesAsync = ref.watch(dailySalesProvider);
    final profitAsync = ref.watch(monthlyProfitProvider);
    final cashFlowAsync = ref.watch(cashFlowProvider);
    final topProductsAsync = ref.watch(topProductsProvider);
    final insightsAsync = ref.watch(aiInsightsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Welcome back. Here\'s your business overview.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          // KPI Cards
          summaryAsync.when(
            loading: () => GridView.count(
              crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6,
              children: List.generate(5, (_) => const CardSkeletonLoader()),
            ),
            error: (err, _) => Text('Error: $err'),
            data: (s) => GridView.count(
              crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6,
              children: [
                KPICard(title: 'Today\'s Sales', value: '\$${s.todaySales}', icon: Icons.trending_up, color: AppColors.success),
                KPICard(title: 'Monthly Profit', value: '\$${s.monthlyProfit}', icon: Icons.bar_chart, color: AppColors.primary),
                KPICard(title: 'Low Stock', value: '${s.lowStockProducts}', icon: Icons.warning_rounded, color: AppColors.warning),
                KPICard(title: 'Pending Payments', value: '${s.pendingPayments}', icon: Icons.schedule, color: AppColors.error),
                KPICard(title: 'Cash Balance', value: '\$${s.cashBalance}', icon: Icons.account_balance_wallet, color: AppColors.info),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Revenue Chart + AI Insights
          SizedBox(
            height: 320,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: salesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (data) => RevenueChart(data: data),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: insightsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const AIInsightsWidget(insights: []),
                      data: (insights) => AIInsightsWidget(insights: insights),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Profit Chart + Top Products
          SizedBox(
            height: 300,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: profitAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (data) => ProfitChart(data: data),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: topProductsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (data) => TopProductsChart(data: data),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cash Flow
          SizedBox(
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: cashFlowAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (data) => CashFlowChart(data: data),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
