import 'package:flutter/material.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: const [
              KPICard(title: 'Today\'s Sales', value: '\$15,000', icon: Icons.trending_up, color: AppColors.success, trend: '+12% from yesterday'),
              KPICard(title: 'Monthly Profit', value: '\$52,000', icon: Icons.bar_chart, color: AppColors.primary),
              KPICard(title: 'Low Stock Items', value: '12', icon: Icons.warning_rounded, color: AppColors.warning),
              KPICard(title: 'Pending Payments', value: '7', icon: Icons.schedule, color: AppColors.error),
              KPICard(title: 'Cash Balance', value: '\$30,000', icon: Icons.account_balance_wallet, color: AppColors.info),
            ],
          ),
          const SizedBox(height: 24),
          // Charts placeholder
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
