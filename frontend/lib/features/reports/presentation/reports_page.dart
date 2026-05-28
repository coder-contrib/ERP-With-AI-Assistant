import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'reports_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(reportsTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.trending_up, size: 20), text: 'Operational'),
                Tab(icon: Icon(Icons.account_balance, size: 20), text: 'Financial'),
                Tab(icon: Icon(Icons.psychology, size: 20), text: 'AI Insights'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _OperationalTab(),
                _FinancialTab(),
                _AiInsightsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: OPERATIONAL REPORTS
// ============================================================

class _OperationalTab extends ConsumerWidget {
  const _OperationalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Sales Reports', Icons.point_of_sale),
          const SizedBox(height: 12),
          _DailySalesCard(),
          const SizedBox(height: 12),
          _SalesByPeriodCard(),
          const SizedBox(height: 12),
          _TopProductsCard(),
          const SizedBox(height: 12),
          _ProductPerformanceCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Inventory Reports', Icons.inventory_2),
          const SizedBox(height: 12),
          _InventoryValuationCard(),
          const SizedBox(height: 12),
          _LowStockCard(),
          const SizedBox(height: 12),
          _StockMovementCard(),
          const SizedBox(height: 12),
          _DeadStockCard(),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: FINANCIAL REPORTS
// ============================================================

class _FinancialTab extends ConsumerWidget {
  const _FinancialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Profit & Loss', Icons.trending_up),
          const SizedBox(height: 12),
          _ProfitLossCard(),
          const SizedBox(height: 12),
          _MonthlyProfitCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Cash & Payments', Icons.payments),
          const SizedBox(height: 12),
          _CashFlowCard(),
          const SizedBox(height: 12),
          _CustomerBalancesCard(),
          const SizedBox(height: 12),
          _SupplierBalancesCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Expenses', Icons.receipt_long),
          const SizedBox(height: 12),
          _ExpenseByCategoryCard(),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 3: AI INSIGHTS REPORTS
// ============================================================

class _AiInsightsTab extends ConsumerWidget {
  const _AiInsightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Customer Intelligence', Icons.people),
          const SizedBox(height: 12),
          _CustomerSegmentationCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Risk & Anomaly Detection', Icons.warning_amber),
          const SizedBox(height: 12),
          _RiskReportCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'AI Summary', Icons.auto_awesome),
          const SizedBox(height: 12),
          _AiSummaryCard(),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED HELPERS
// ============================================================

Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Row(
    children: [
      Icon(icon, size: 22, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkText : AppColors.text,
        ),
      ),
    ],
  );
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? accentColor;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppColors.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

Widget _buildKpi(String label, String value, {Color? color}) {
  return Column(
    children: [
      Text(
        value,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color ?? AppColors.primary),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ],
  );
}

Widget _buildError(Object error) {
  return Padding(
    padding: const EdgeInsets.all(12),
    child: Text('Error: $error', style: const TextStyle(color: AppColors.error, fontSize: 12)),
  );
}

Widget _buildLoading() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: SkeletonLoader(height: 60, width: double.infinity)),
  );
}

// ============================================================
// OPERATIONAL REPORT CARDS
// ============================================================

class _DailySalesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsDailySalesProvider);
    return _ReportCard(
      title: 'Daily Sales',
      icon: Icons.today,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final items = (report['data'] as List?) ?? [];
          if (items.isEmpty) return const Text('No sales data available');
          final totalSales = items.fold<double>(0, (sum, i) => sum + double.parse(i['total_sales'] ?? '0'));
          final totalInvoices = items.fold<int>(0, (sum, i) => sum + (i['invoice_count'] as int? ?? 0));
          final avgInvoice = totalInvoices > 0 ? totalSales / totalInvoices : 0;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Total Sales', '${totalSales.toStringAsFixed(0)} IQD'),
                  _buildKpi('Invoices', '$totalInvoices'),
                  _buildKpi('Avg Invoice', '${avgInvoice.toStringAsFixed(0)} IQD'),
                ],
              ),
              const SizedBox(height: 12),
              if (items.length > 1)
                SizedBox(
                  height: 40,
                  child: Row(
                    children: items.take(14).map((i) {
                      final sales = double.parse(i['total_sales'] ?? '0');
                      final maxSales = items.fold<double>(0, (m, x) {
                        final v = double.parse(x['total_sales'] ?? '0');
                        return v > m ? v : m;
                      });
                      final height = maxSales > 0 ? (sales / maxSales * 36) : 0.0;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SalesByPeriodCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsSalesByPeriodProvider('month'));
    return _ReportCard(
      title: 'Sales by Month (Growth %)',
      icon: Icons.calendar_month,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final reportData = report['data'] as Map<String, dynamic>? ?? {};
          final periods = (reportData['periods'] as List?) ?? [];
          if (periods.isEmpty) return const Text('No data');
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Total', '${double.parse(reportData['total_sales'] ?? '0').toStringAsFixed(0)} IQD'),
                  _buildKpi('Invoices', '${reportData['total_invoices'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 12),
              ...periods.take(6).map((p) {
                final growth = double.parse(p['growth_pct'] ?? '0');
                final isPositive = growth >= 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(p['period_start'] ?? '', style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: Text(
                          '${double.parse(p['total_sales'] ?? '0').toStringAsFixed(0)} IQD',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isPositive ? AppColors.success : AppColors.error).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isPositive ? "+" : ""}${growth.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _TopProductsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsTopProductsProvider);
    return _ReportCard(
      title: 'Top Selling Products',
      icon: Icons.star,
      accentColor: AppColors.warning,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final items = (report['data'] as List?) ?? [];
          if (items.isEmpty) return const Text('No data');
          return Column(
            children: items.take(5).map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(p['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                    Text('${double.parse(p['total_revenue'] ?? '0').toStringAsFixed(0)} IQD',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ProductPerformanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsProductPerformanceProvider);
    return _ReportCard(
      title: 'Product Performance (Profitability)',
      icon: Icons.analytics,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final reportData = report['data'] as Map<String, dynamic>? ?? {};
          final products = (reportData['products'] as List?) ?? [];
          if (products.isEmpty) return const Text('No data');
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Revenue', '${double.parse(reportData['total_revenue'] ?? '0').toStringAsFixed(0)} IQD'),
                  _buildKpi('Profit', '${double.parse(reportData['total_profit'] ?? '0').toStringAsFixed(0)} IQD', color: AppColors.success),
                ],
              ),
              const SizedBox(height: 12),
              ...products.take(5).map((p) {
                final margin = double.parse(p['margin_pct'] ?? '0');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(p['product_name'] ?? '', style: const TextStyle(fontSize: 12))),
                      SizedBox(
                        width: 70,
                        child: Text('${double.parse(p['profit'] ?? '0').toStringAsFixed(0)} IQD',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: (margin >= 20 ? AppColors.success : AppColors.warning).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${margin.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 10, color: margin >= 20 ? AppColors.success : AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryValuationCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsInventoryProvider);
    return _ReportCard(
      title: 'Inventory Valuation',
      icon: Icons.warehouse,
      accentColor: AppColors.info,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final reportData = report['data'] as Map<String, dynamic>? ?? {};
          final warehouses = (reportData['warehouses'] as List?) ?? [];
          return Column(
            children: [
              _buildKpi('Total Capital', '${double.parse(reportData['grand_total_value'] ?? '0').toStringAsFixed(0)} IQD', color: AppColors.info),
              const SizedBox(height: 12),
              ...warehouses.map((w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w['warehouse_name'] ?? '', style: const TextStyle(fontSize: 13))),
                    Text('${w['product_count']} items', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Text('${double.parse(w['total_value'] ?? '0').toStringAsFixed(0)} IQD',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}

class _LowStockCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsLowStockProvider);
    return _ReportCard(
      title: 'Low Stock Alert',
      icon: Icons.warning_amber,
      accentColor: AppColors.error,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final reportData = report['data'] as Map<String, dynamic>? ?? {};
          final lowStock = (reportData['low_stock'] as List?) ?? [];
          final outOfStock = (reportData['out_of_stock'] as List?) ?? [];
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Low Stock', '${reportData['low_stock_count'] ?? 0}', color: AppColors.warning),
                  _buildKpi('Out of Stock', '${reportData['out_of_stock_count'] ?? 0}', color: AppColors.error),
                ],
              ),
              if (lowStock.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...lowStock.take(5).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item['product_name'] ?? '', style: const TextStyle(fontSize: 12))),
                      Text('Qty: ${item['current_quantity']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('Reorder: ${double.parse(item['reorder_suggestion'] ?? '0').toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StockMovementCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsStockMovementProvider);
    return _ReportCard(
      title: 'Stock Movement (30 days)',
      icon: Icons.swap_vert,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final reportData = report['data'] as Map<String, dynamic>? ?? {};
          final products = (reportData['products'] as List?) ?? [];
          if (products.isEmpty) return const Text('No movements');
          return Column(
            children: products.take(8).map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(p['product_name'] ?? '', style: const TextStyle(fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                      child: Text('IN: ${double.parse(p['total_in'] ?? '0').toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.success)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                      child: Text('OUT: ${double.parse(p['total_out'] ?? '0').toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.error)),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DeadStockCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsDeadStockProvider);
    return _ReportCard(
      title: 'Dead Stock (No Movement 30+ days)',
      icon: Icons.block,
      accentColor: AppColors.error,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final reportData = report['data'] as Map<String, dynamic>? ?? {};
          final items = (reportData['items'] as List?) ?? [];
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Dead Items', '${reportData['dead_stock_count'] ?? 0}', color: AppColors.error),
                  _buildKpi('Capital Locked', '${double.parse(reportData['total_capital_locked'] ?? '0').toStringAsFixed(0)} IQD', color: AppColors.error),
                ],
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...items.take(5).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item['product_name'] ?? '', style: const TextStyle(fontSize: 12))),
                      Text('${double.parse(item['total_value'] ?? '0').toStringAsFixed(0)} IQD',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('Last: ${_formatDate(item['last_movement'] ?? '')}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// FINANCIAL REPORT CARDS
// ============================================================

class _ProfitLossCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsProfitLossProvider);
    return _ReportCard(
      title: 'Profit & Loss (Last 30 Days)',
      icon: Icons.trending_up,
      accentColor: AppColors.success,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final revenue = double.parse(d['revenue'] ?? '0');
          final cogs = double.parse(d['cogs'] ?? '0');
          final grossProfit = double.parse(d['gross_profit'] ?? '0');
          final expenses = double.parse(d['total_expenses'] ?? '0');
          final netProfit = double.parse(d['net_profit'] ?? '0');
          final netMargin = double.parse(d['net_margin_pct'] ?? '0');
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Revenue', '${revenue.toStringAsFixed(0)} IQD'),
                  _buildKpi('Net Profit', '${netProfit.toStringAsFixed(0)} IQD', color: netProfit >= 0 ? AppColors.success : AppColors.error),
                  _buildKpi('Margin', '${netMargin.toStringAsFixed(1)}%', color: netProfit >= 0 ? AppColors.success : AppColors.error),
                ],
              ),
              const SizedBox(height: 16),
              _PnlRow(label: 'Revenue', value: revenue, isTotal: true),
              _PnlRow(label: 'Cost of Goods', value: -cogs),
              _PnlRow(label: 'Gross Profit', value: grossProfit, isSubtotal: true),
              _PnlRow(label: 'Expenses', value: -expenses),
              const Divider(height: 8),
              _PnlRow(label: 'Net Profit', value: netProfit, isTotal: true),
            ],
          );
        },
      ),
    );
  }
}

class _PnlRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;
  final bool isSubtotal;

  const _PnlRow({required this.label, required this.value, this.isTotal = false, this.isSubtotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal || isSubtotal ? FontWeight.w600 : FontWeight.normal,
          ))),
          Text(
            '${value >= 0 ? '' : '-'}${value.abs().toStringAsFixed(0)} IQD',
            style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal || isSubtotal ? FontWeight.w700 : FontWeight.normal,
              color: value >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyProfitCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsMonthlyProfitProvider);
    return _ReportCard(
      title: 'Monthly Profit Trend',
      icon: Icons.bar_chart,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final items = (report['data'] as List?) ?? [];
          if (items.isEmpty) return const Text('No data');
          return Column(
            children: items.take(6).map((m) {
              final netProfit = double.parse(m['net_profit'] ?? '0');
              final margin = m['gross_margin'] ?? '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(m['month'] ?? '', style: const TextStyle(fontSize: 12))),
                    Expanded(
                      child: Text('${double.parse(m['revenue'] ?? '0').toStringAsFixed(0)} IQD',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Text(
                      '${netProfit.toStringAsFixed(0)} IQD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: netProfit >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CashFlowCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsCashFlowProvider);
    return _ReportCard(
      title: 'Cash Flow (30 Days)',
      icon: Icons.account_balance_wallet,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final totalIn = double.parse(d['total_in'] ?? '0');
          final totalOut = double.parse(d['total_out'] ?? '0');
          final net = double.parse(d['net_flow'] ?? '0');
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKpi('Cash In', '${totalIn.toStringAsFixed(0)} IQD', color: AppColors.success),
              _buildKpi('Cash Out', '${totalOut.toStringAsFixed(0)} IQD', color: AppColors.error),
              _buildKpi('Net Flow', '${net.toStringAsFixed(0)} IQD', color: net >= 0 ? AppColors.success : AppColors.error),
            ],
          );
        },
      ),
    );
  }
}

class _CustomerBalancesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsCustomerBalancesProvider);
    return _ReportCard(
      title: 'Receivables (Customer Debts)',
      icon: Icons.people,
      accentColor: AppColors.warning,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final items = (report['data'] as List?) ?? [];
          final total = report['total_receivable'] ?? '0';
          return Column(
            children: [
              _buildKpi('Total Receivable', '${double.parse(total).toStringAsFixed(0)} IQD', color: AppColors.warning),
              const SizedBox(height: 12),
              ...items.take(5).map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 12))),
                    Text('${double.parse(c['current_balance'] ?? '0').toStringAsFixed(0)} IQD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c['over_limit'] == true ? AppColors.error : AppColors.warning,
                        )),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}

class _SupplierBalancesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsSupplierBalancesProvider);
    return _ReportCard(
      title: 'Payables (Supplier Debts)',
      icon: Icons.local_shipping,
      accentColor: AppColors.info,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final items = (report['data'] as List?) ?? [];
          final total = report['total_payable'] ?? '0';
          return Column(
            children: [
              _buildKpi('Total Payable', '${double.parse(total).toStringAsFixed(0)} IQD', color: AppColors.info),
              const SizedBox(height: 12),
              ...items.take(5).map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(s['supplier_name'] ?? '', style: const TextStyle(fontSize: 12))),
                    Text('${double.parse(s['current_balance'] ?? '0').toStringAsFixed(0)} IQD',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseByCategoryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsExpenseByCategoryProvider);
    return _ReportCard(
      title: 'Expenses by Category',
      icon: Icons.receipt_long,
      accentColor: AppColors.error,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final categories = (d['categories'] as List?) ?? [];
          final grandTotal = double.parse(d['grand_total'] ?? '0');
          return Column(
            children: [
              _buildKpi('Total Expenses', '${grandTotal.toStringAsFixed(0)} IQD', color: AppColors.error),
              const SizedBox(height: 12),
              ...categories.take(6).map((cat) {
                final pct = double.parse(cat['percentage'] ?? '0');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(cat['category'] ?? '', style: const TextStyle(fontSize: 12))),
                          Text('${double.parse(cat['total_amount'] ?? '0').toStringAsFixed(0)} IQD',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 4,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// AI INSIGHTS REPORT CARDS
// ============================================================

class _CustomerSegmentationCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsCustomerSegmentationProvider);
    return _ReportCard(
      title: 'Customer Segmentation',
      icon: Icons.group_work,
      accentColor: AppColors.primary,
      child: data.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final vip = d['vip_customers'] as Map<String, dynamic>? ?? {};
          final active = d['active_customers'] as Map<String, dynamic>? ?? {};
          final inactive = d['inactive_customers'] as Map<String, dynamic>? ?? {};
          final highDebt = d['high_debt_customers'] as Map<String, dynamic>? ?? {};

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKpi('Total', '${d['total_customers'] ?? 0}'),
                  _buildKpi('VIP', '${vip['count'] ?? 0}', color: AppColors.warning),
                  _buildKpi('Active', '${active['count'] ?? 0}', color: AppColors.success),
                  _buildKpi('Inactive', '${inactive['count'] ?? 0}', color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 16),
              if ((highDebt['count'] ?? 0) > 0) ...[
                Row(
                  children: [
                    const Icon(Icons.warning, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text('${highDebt['count']} high-debt customers',
                        style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ...(highDebt['customers'] as List? ?? []).take(3).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(child: Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 12))),
                      Text('${double.parse(c['current_balance'] ?? '0').toStringAsFixed(0)} IQD',
                          style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
              if ((vip['customers'] as List? ?? []).isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Text('VIP Customers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ...(vip['customers'] as List? ?? []).take(3).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(child: Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 12))),
                      Text('${double.parse(c['total_purchases'] ?? '0').toStringAsFixed(0)} IQD',
                          style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RiskReportCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadStock = ref.watch(reportsDeadStockProvider);
    final lowStock = ref.watch(reportsLowStockProvider);
    final customerBalances = ref.watch(reportsCustomerBalancesProvider);

    return _ReportCard(
      title: 'Risk Assessment',
      icon: Icons.shield,
      accentColor: AppColors.error,
      child: Builder(builder: (_) {
        final risks = <Map<String, dynamic>>[];

        deadStock.whenData((report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final count = d['dead_stock_count'] ?? 0;
          final value = double.parse(d['total_capital_locked'] ?? '0');
          if (count > 0) {
            risks.add({
              'type': 'Dead Stock',
              'severity': value > 50000 ? 'high' : 'medium',
              'detail': '$count products, ${value.toStringAsFixed(0)} IQD locked',
            });
          }
        });

        lowStock.whenData((report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final oos = d['out_of_stock_count'] ?? 0;
          if (oos > 0) {
            risks.add({
              'type': 'Out of Stock',
              'severity': oos > 5 ? 'high' : 'medium',
              'detail': '$oos products out of stock',
            });
          }
        });

        customerBalances.whenData((report) {
          final items = (report['data'] as List?) ?? [];
          final overLimit = items.where((c) => c['over_limit'] == true).length;
          if (overLimit > 0) {
            risks.add({
              'type': 'Credit Risk',
              'severity': 'high',
              'detail': '$overLimit customers over credit limit',
            });
          }
        });

        if (risks.isEmpty) {
          return const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('No significant risks detected', style: TextStyle(fontSize: 13, color: AppColors.success)),
            ],
          );
        }

        return Column(
          children: risks.map((r) {
            final isHigh = r['severity'] == 'high';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isHigh ? AppColors.error : AppColors.warning).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isHigh ? AppColors.error : AppColors.warning).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isHigh ? Icons.error : Icons.warning,
                    size: 16,
                    color: isHigh ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['type'], style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isHigh ? AppColors.error : AppColors.warning,
                        )),
                        Text(r['detail'], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isHigh ? AppColors.error : AppColors.warning).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isHigh ? 'HIGH' : 'MEDIUM',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isHigh ? AppColors.error : AppColors.warning),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }),
    );
  }
}

class _AiSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySales = ref.watch(reportsDailySalesProvider);
    final profitLoss = ref.watch(reportsProfitLossProvider);

    return _ReportCard(
      title: 'AI Daily Summary',
      icon: Icons.auto_awesome,
      accentColor: Colors.purple,
      child: Builder(builder: (_) {
        String summary = '';

        dailySales.whenData((report) {
          final items = (report['data'] as List?) ?? [];
          if (items.length >= 2) {
            final today = double.parse(items.last['total_sales'] ?? '0');
            final yesterday = double.parse(items[items.length - 2]['total_sales'] ?? '0');
            final change = yesterday > 0 ? ((today - yesterday) / yesterday * 100) : 0;
            if (change > 0) {
              summary += 'Sales increased by ${change.toStringAsFixed(1)}% compared to yesterday. ';
            } else if (change < 0) {
              summary += 'Sales decreased by ${change.abs().toStringAsFixed(1)}% compared to yesterday. ';
            }
            summary += 'Today: ${items.last['invoice_count']} invoices totaling ${today.toStringAsFixed(0)} IQD. ';
          }
        });

        profitLoss.whenData((report) {
          final d = report['data'] as Map<String, dynamic>? ?? {};
          final margin = double.parse(d['net_margin_pct'] ?? '0');
          final netProfit = double.parse(d['net_profit'] ?? '0');
          if (margin < 10 && netProfit > 0) {
            summary += 'Profit margin is low (${margin.toStringAsFixed(1)}%) - consider reducing discounts or expenses.';
          } else if (netProfit < 0) {
            summary += 'WARNING: Operating at a loss. Review expenses and pricing urgently.';
          } else if (margin > 20) {
            summary += 'Healthy profit margin of ${margin.toStringAsFixed(1)}%.';
          }
        });

        if (summary.isEmpty) {
          summary = 'Loading insights...';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(summary, style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================================
// UTILITIES
// ============================================================

String _formatDate(String dateStr) {
  if (dateStr.isEmpty || dateStr == 'Never') return dateStr;
  try {
    final dt = DateTime.parse(dateStr);
    return '${dt.day}/${dt.month}';
  } catch (_) {
    return dateStr;
  }
}
