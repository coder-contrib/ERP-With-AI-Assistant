import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Welcome back. Here\'s your business overview.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          dashboardAsync.when(
            loading: () => GridView.count(
              crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6,
              children: List.generate(5, (_) => const CardSkeletonLoader()),
            ),
            error: (err, _) => Center(child: Text('Error loading dashboard: $err')),
            data: (summary) => GridView.count(
              crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6,
              children: [
                KPICard(title: 'Today\'s Sales', value: '\$${summary.todaySales}', icon: Icons.trending_up, color: AppColors.success),
                KPICard(title: 'Monthly Profit', value: '\$${summary.monthlyProfit}', icon: Icons.bar_chart, color: AppColors.primary),
                KPICard(title: 'Low Stock Items', value: '${summary.lowStockProducts}', icon: Icons.warning_rounded, color: AppColors.warning),
                KPICard(title: 'Pending Payments', value: '${summary.pendingPayments}', icon: Icons.schedule, color: AppColors.error),
                KPICard(title: 'Cash Balance', value: '\$${summary.cashBalance}', icon: Icons.account_balance_wallet, color: AppColors.info),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const Center(child: Text('Revenue Chart')),
          ),
        ],
      ),
    );
  }
}
