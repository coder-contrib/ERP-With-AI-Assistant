import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/print_helper.dart';
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
// MAIN TABS
// ============================================================

class _OperationalTab extends StatefulWidget {
  const _OperationalTab();
  @override
  State<_OperationalTab> createState() => _OperationalTabState();
}

class _OperationalTabState extends State<_OperationalTab> with SingleTickerProviderStateMixin {
  late TabController _sub;
  @override
  void initState() { super.initState(); _sub = TabController(length: 8, vsync: this); }
  @override
  void dispose() { _sub.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: TabBar(
            controller: _sub,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Daily Sales'), Tab(text: 'By Period'), Tab(text: 'Top Products'),
              Tab(text: 'Performance'), Tab(text: 'Inventory'), Tab(text: 'Low Stock'),
              Tab(text: 'Stock Movement'), Tab(text: 'Dead Stock'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: const [
              _DailySalesReport(), _SalesByPeriodReport(), _TopProductsReport(),
              _ProductPerformanceReport(), _InventoryReport(), _LowStockReport(),
              _StockMovementReport(), _DeadStockReport(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinancialTab extends StatefulWidget {
  const _FinancialTab();
  @override
  State<_FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<_FinancialTab> with SingleTickerProviderStateMixin {
  late TabController _sub;
  @override
  void initState() { super.initState(); _sub = TabController(length: 6, vsync: this); }
  @override
  void dispose() { _sub.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: TabBar(
            controller: _sub,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Profit & Loss'), Tab(text: 'Monthly Profit'), Tab(text: 'Cash Flow'),
              Tab(text: 'Customer Balances'), Tab(text: 'Supplier Balances'), Tab(text: 'Expenses'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: const [
              _ProfitLossReport(), _MonthlyProfitReport(), _CashFlowReport(),
              _CustomerBalancesReport(), _SupplierBalancesReport(), _ExpensesReport(),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiInsightsTab extends StatefulWidget {
  const _AiInsightsTab();
  @override
  State<_AiInsightsTab> createState() => _AiInsightsTabState();
}

class _AiInsightsTabState extends State<_AiInsightsTab> with SingleTickerProviderStateMixin {
  late TabController _sub;
  @override
  void initState() { super.initState(); _sub = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _sub.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: TabBar(
            controller: _sub,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Customer Segmentation'),
              Tab(text: 'Risk Assessment'),
              Tab(text: 'AI Summary'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: const [
              _CustomerSegmentationReport(),
              _RiskAssessmentReport(),
              _AiSummaryReport(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SHARED HELPERS
// ============================================================

Widget _reportHeader(String title, VoidCallback onPrint) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.03),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
    ),
    child: Row(
      children: [
        const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: onPrint,
          icon: const Icon(Icons.print, size: 16),
          label: const Text('Print'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTable(bool isDark, {required List<DataColumn> columns, required List<DataRow> rows}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
          columnSpacing: 24,
          horizontalMargin: 16,
          columns: columns,
          rows: rows,
        ),
      ),
    ),
  );
}

Widget _statBadge(String label, dynamic value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: color)),
      const SizedBox(height: 2),
      Text('${_fmtAmount(value)} IQD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

String _fmtAmount(dynamic v) {
  if (v == null) return '0';
  final num = double.tryParse(v.toString()) ?? 0;
  if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
  if (num >= 1000) return '${(num / 1000).toStringAsFixed(0)}K';
  return num.toStringAsFixed(0);
}

Color _profitColor(dynamic v) {
  final num = double.tryParse(v?.toString() ?? '0') ?? 0;
  return num >= 0 ? AppColors.success : AppColors.error;
}
