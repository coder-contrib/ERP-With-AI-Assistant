import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/print_helper.dart';
import '../../whatsapp/data/whatsapp_repository.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _sendReportToOwner(context),
        backgroundColor: const Color(0xFF25D366),
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text('Send Report', style: TextStyle(color: Colors.white)),
      ),
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
  void _sendReportToOwner(BuildContext context) async {
    final reportType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Row(
          children: [
            const Icon(Icons.chat, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            const Text('Send Report via WhatsApp'),
          ],
        ),
        children: [
          _reportOption(ctx, 'daily_sales', 'Daily Sales', Icons.today),
          _reportOption(ctx, 'monthly_profit', 'Monthly Profit', Icons.calendar_month),
          _reportOption(ctx, 'profit_loss', 'Profit & Loss', Icons.account_balance),
          _reportOption(ctx, 'cash_flow', 'Cash Flow', Icons.monetization_on),
          _reportOption(ctx, 'top_products', 'Top Products', Icons.star),
          _reportOption(ctx, 'inventory_valuation', 'Inventory Valuation', Icons.warehouse),
          _reportOption(ctx, 'low_stock', 'Low Stock Alert', Icons.warning_amber),
          _reportOption(ctx, 'dead_stock', 'Dead Stock', Icons.block),
          _reportOption(ctx, 'stock_movement', 'Stock Movement', Icons.swap_vert),
          _reportOption(ctx, 'customer_balances', 'Customer Balances', Icons.people),
          _reportOption(ctx, 'supplier_balances', 'Supplier Balances', Icons.local_shipping),
          _reportOption(ctx, 'expense_by_category', 'Expenses by Category', Icons.pie_chart),
        ],
      ),
    );
    if (reportType == null || !mounted) return;
    try {
      final repo = ref.read(whatsappRepositoryProvider);
      final result = await repo.sendReportToOwner(reportType: reportType);
      if (result.containsKey('error')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report sent to your WhatsApp!'), backgroundColor: Color(0xFF25D366)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _reportOption(BuildContext ctx, String type, String label, IconData icon) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, type),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF25D366)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: OPERATIONAL — Sub-tabs
// ============================================================

class _OperationalTab extends StatefulWidget {
  const _OperationalTab();

  @override
  State<_OperationalTab> createState() => _OperationalTabState();
}

class _OperationalTabState extends State<_OperationalTab> with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface.withOpacity(0.5) : AppColors.background,
          child: TabBar(
            controller: _subTabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Daily Sales'),
              Tab(text: 'Sales by Period'),
              Tab(text: 'Top Products'),
              Tab(text: 'Product Performance'),
              Tab(text: 'Inventory Valuation'),
              Tab(text: 'Low Stock'),
              Tab(text: 'Stock Movement'),
              Tab(text: 'Dead Stock'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: const [
              _DailySalesReport(),
              _SalesByPeriodReport(),
              _TopProductsReport(),
              _ProductPerformanceReport(),
              _InventoryValuationReport(),
              _LowStockReport(),
              _StockMovementReport(),
              _DeadStockReport(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 2: FINANCIAL — Sub-tabs
// ============================================================

class _FinancialTab extends StatefulWidget {
  const _FinancialTab();

  @override
  State<_FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<_FinancialTab> with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface.withOpacity(0.5) : AppColors.background,
          child: TabBar(
            controller: _subTabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Profit & Loss'),
              Tab(text: 'Monthly Profit'),
              Tab(text: 'Cash Flow'),
              Tab(text: 'Customer Balances'),
              Tab(text: 'Supplier Balances'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: const [
              _ProfitLossReport(),
              _MonthlyProfitReport(),
              _CashFlowReport(),
              _CustomerBalancesReport(),
              _SupplierBalancesReport(),
              _ExpenseByCategoryReport(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 3: AI INSIGHTS — Sub-tabs
// ============================================================

class _AiInsightsTab extends StatefulWidget {
  const _AiInsightsTab();

  @override
  State<_AiInsightsTab> createState() => _AiInsightsTabState();
}

class _AiInsightsTabState extends State<_AiInsightsTab> with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkSurface.withOpacity(0.5) : AppColors.background,
          child: TabBar(
            controller: _subTabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Customer Segmentation'),
              Tab(text: 'Risk Assessment'),
              Tab(text: 'AI Summary'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
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

// ============================================================
// OPERATIONAL REPORTS
// ============================================================

class _DailySalesReport extends ConsumerWidget {
  const _DailySalesReport();

  void _print(Map<String, dynamic> data) {
    final days = (data['data'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Daily Sales (Last 30 Days)',
      headers: ['Date', 'Invoices', 'Total Sales', 'Cash Collected', 'Credit Sales'],
      rows: days.map<List<String>>((d) => [
        d['date'] ?? '', '${d['invoice_count']}',
        '${_fmtAmount(d['total_sales'])} IQD', '${_fmtAmount(d['cash_collected'])} IQD', '${_fmtAmount(d['credit_sales'])} IQD',
      ]).toList(),
    );
    printReportHtml(title: 'Daily Sales Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(reportsDailySalesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Daily Sales Report', () => _print(salesAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          salesAsync.when(
            data: (data) {
              final days = (data['data'] as List?) ?? [];
              if (days.isEmpty) return const Text('No sales data available');
              return _buildTable(isDark, columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Invoices', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Cash Collected', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Credit Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: days.map<DataRow>((d) => DataRow(cells: [
                DataCell(Text(d['date'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${d['invoice_count']}', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(d['total_sales'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                DataCell(Text('${_fmtAmount(d['cash_collected'])} IQD', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(d['credit_sales'])} IQD', style: const TextStyle(fontSize: 13))),
              ])).toList());
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _SalesByPeriodReport extends ConsumerWidget {
  const _SalesByPeriodReport();

  void _print(Map<String, dynamic> data) {
    final reportData = data['data'] as Map<String, dynamic>? ?? {};
    final periods = (reportData['periods'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Sales by Period (Monthly)',
      headers: ['Period', 'Invoices', 'Total Sales', 'Growth %'],
      rows: periods.map<List<String>>((p) => [
        p['period_start'] ?? '', '${p['invoice_count'] ?? 0}',
        '${_fmtAmount(p['total_sales'])} IQD', '${p['growth_pct'] ?? 0}%',
      ]).toList(),
    );
    printReportHtml(title: 'Sales by Period Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsSalesByPeriodProvider('month'));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Sales by Period', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final reportData = data['data'] as Map<String, dynamic>? ?? {};
              final periods = (reportData['periods'] as List?) ?? [];
              if (periods.isEmpty) return const Text('No data');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Total Sales', reportData['total_sales'], AppColors.primary),
                    const SizedBox(width: 12),
                    _statBadge('Total Invoices', reportData['total_invoices'], AppColors.info),
                  ]),
                  const SizedBox(height: 16),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Invoices', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Growth', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: periods.map<DataRow>((p) {
                    final growth = double.parse(p['growth_pct']?.toString() ?? '0');
                    return DataRow(cells: [
                      DataCell(Text(p['period_start'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${p['invoice_count'] ?? 0}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(p['total_sales'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      DataCell(Text('${growth >= 0 ? "+" : ""}${growth.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: growth >= 0 ? AppColors.success : AppColors.error))),
                    ]);
                  }).toList()),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _TopProductsReport extends ConsumerWidget {
  const _TopProductsReport();

  void _print(Map<String, dynamic> data) {
    final products = (data['data'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Top Selling Products',
      headers: ['#', 'Product', 'Qty Sold', 'Revenue'],
      rows: products.asMap().entries.map<List<String>>((e) => [
        '${e.key + 1}', e.value['product_name'] ?? '',
        '${e.value['total_quantity']}', '${_fmtAmount(e.value['total_revenue'])} IQD',
      ]).toList(),
    );
    printReportHtml(title: 'Top Products Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsTopProductsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Top Selling Products', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final products = (data['data'] as List?) ?? [];
              if (products.isEmpty) return const Text('No product data');
              return _buildTable(isDark, columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Qty Sold', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: products.asMap().entries.map<DataRow>((e) => DataRow(cells: [
                DataCell(Text('${e.key + 1}', style: const TextStyle(fontSize: 13))),
                DataCell(Text(e.value['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${e.value['total_quantity']}', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(e.value['total_revenue'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ])).toList());
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _ProductPerformanceReport extends ConsumerWidget {
  const _ProductPerformanceReport();

  void _print(Map<String, dynamic> data) {
    final reportData = data['data'] as Map<String, dynamic>? ?? {};
    final products = (reportData['products'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Product Performance (Profitability)',
      headers: ['Product', 'Revenue', 'Cost', 'Profit', 'Margin %'],
      rows: products.map<List<String>>((p) => [
        p['product_name'] ?? '', '${_fmtAmount(p['revenue'])} IQD',
        '${_fmtAmount(p['cost'])} IQD', '${_fmtAmount(p['profit'])} IQD', '${p['margin_pct'] ?? 0}%',
      ]).toList(),
    );
    printReportHtml(title: 'Product Performance Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsProductPerformanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Product Performance', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final reportData = data['data'] as Map<String, dynamic>? ?? {};
              final products = (reportData['products'] as List?) ?? [];
              if (products.isEmpty) return const Text('No data');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Total Revenue', reportData['total_revenue'], AppColors.primary),
                    const SizedBox(width: 12),
                    _statBadge('Total Profit', reportData['total_profit'], AppColors.success),
                  ]),
                  const SizedBox(height: 16),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Profit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Margin', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: products.map<DataRow>((p) {
                    final margin = double.parse(p['margin_pct']?.toString() ?? '0');
                    return DataRow(cells: [
                      DataCell(Text(p['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(p['revenue'])} IQD', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(p['profit'])} IQD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: margin >= 0 ? AppColors.success : AppColors.error))),
                      DataCell(Text('${margin.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, color: margin >= 20 ? AppColors.success : AppColors.warning))),
                    ]);
                  }).toList()),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _InventoryValuationReport extends ConsumerWidget {
  const _InventoryValuationReport();

  void _print(Map<String, dynamic> data) {
    final valuation = data['data'] as Map<String, dynamic>? ?? {};
    final warehouses = (valuation['warehouses'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Inventory Valuation by Warehouse',
      headers: ['Warehouse', 'Products', 'Total Qty', 'Value (IQD)'],
      rows: warehouses.map<List<String>>((w) => [
        w['warehouse_name'] ?? '', '${w['product_count']}',
        '${w['total_quantity']}', '${_fmtAmount(w['total_value'])} IQD',
      ]).toList(),
    );
    printReportHtml(title: 'Inventory Valuation Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsInventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Inventory Valuation', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final valuation = data['data'] as Map<String, dynamic>? ?? {};
              final warehouses = (valuation['warehouses'] as List?) ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statBadge('Total Inventory Value', valuation['grand_total_value'], AppColors.info),
                  const SizedBox(height: 16),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Warehouse', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Products', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: warehouses.map<DataRow>((w) => DataRow(cells: [
                    DataCell(Text(w['warehouse_name'] ?? '', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${w['product_count']}', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${w['total_quantity']}', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${_fmtAmount(w['total_value'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  ])).toList()),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _LowStockReport extends ConsumerWidget {
  const _LowStockReport();

  void _print(Map<String, dynamic> data) {
    final reportData = data['data'] as Map<String, dynamic>? ?? {};
    final items = (reportData['low_stock'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Low Stock Alert',
      headers: ['Product', 'Current Qty', 'Min Level', 'Reorder Suggestion'],
      rows: items.map<List<String>>((i) => [
        i['product_name'] ?? '', '${i['current_quantity']}',
        '${i['min_level'] ?? '-'}', '${i['reorder_suggestion'] ?? '-'}',
      ]).toList(),
    );
    printReportHtml(title: 'Low Stock Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsLowStockProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Low Stock Alert', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final reportData = data['data'] as Map<String, dynamic>? ?? {};
              final lowStock = (reportData['low_stock'] as List?) ?? [];
              final outOfStock = (reportData['out_of_stock'] as List?) ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Low Stock', '${reportData['low_stock_count'] ?? 0}', AppColors.warning),
                    const SizedBox(width: 12),
                    _statBadge('Out of Stock', '${reportData['out_of_stock_count'] ?? 0}', AppColors.error),
                  ]),
                  const SizedBox(height: 16),
                  if (lowStock.isNotEmpty)
                    _buildTable(isDark, columns: const [
                      DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Current Qty', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Reorder', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ], rows: lowStock.map<DataRow>((i) => DataRow(cells: [
                      DataCell(Text(i['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${i['current_quantity']}', style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600))),
                      DataCell(Text('${_fmtAmount(i['reorder_suggestion'])}', style: const TextStyle(fontSize: 13))),
                    ])).toList()),
                  if (outOfStock.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Out of Stock Items:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                    const SizedBox(height: 8),
                    ...outOfStock.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('- ${i['product_name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _StockMovementReport extends ConsumerWidget {
  const _StockMovementReport();

  void _print(Map<String, dynamic> data) {
    final reportData = data['data'] as Map<String, dynamic>? ?? {};
    final products = (reportData['products'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Stock Movement (Last 30 Days)',
      headers: ['Product', 'Total In', 'Total Out'],
      rows: products.map<List<String>>((p) => [
        p['product_name'] ?? '', '${_fmtAmount(p['total_in'])}', '${_fmtAmount(p['total_out'])}',
      ]).toList(),
    );
    printReportHtml(title: 'Stock Movement Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsStockMovementProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Stock Movement (30 Days)', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final reportData = data['data'] as Map<String, dynamic>? ?? {};
              final products = (reportData['products'] as List?) ?? [];
              if (products.isEmpty) return const Text('No movements');
              return _buildTable(isDark, columns: const [
                DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Total In', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Total Out', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: products.map<DataRow>((p) => DataRow(cells: [
                DataCell(Text(p['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(p['total_in'])}', style: const TextStyle(fontSize: 13, color: AppColors.success))),
                DataCell(Text('${_fmtAmount(p['total_out'])}', style: const TextStyle(fontSize: 13, color: AppColors.error))),
              ])).toList());
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _DeadStockReport extends ConsumerWidget {
  const _DeadStockReport();

  void _print(Map<String, dynamic> data) {
    final reportData = data['data'] as Map<String, dynamic>? ?? {};
    final items = (reportData['items'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Dead Stock (No Movement 30+ Days)',
      headers: ['Product', 'Quantity', 'Value', 'Last Movement'],
      rows: items.map<List<String>>((i) => [
        i['product_name'] ?? '', '${i['quantity'] ?? 0}',
        '${_fmtAmount(i['total_value'])} IQD', i['last_movement'] ?? 'Never',
      ]).toList(),
    );
    printReportHtml(title: 'Dead Stock Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsDeadStockProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Dead Stock', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final reportData = data['data'] as Map<String, dynamic>? ?? {};
              final items = (reportData['items'] as List?) ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Dead Items', '${reportData['dead_stock_count'] ?? 0}', AppColors.error),
                    const SizedBox(width: 12),
                    _statBadge('Capital Locked', reportData['total_capital_locked'], AppColors.error),
                  ]),
                  const SizedBox(height: 16),
                  if (items.isNotEmpty)
                    _buildTable(isDark, columns: const [
                      DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Last Move', style: TextStyle(fontWeight: FontWeight.w600))),
                    ], rows: items.map<DataRow>((i) => DataRow(cells: [
                      DataCell(Text(i['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${i['quantity'] ?? 0}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(i['total_value'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      DataCell(Text(i['last_movement'] ?? 'Never', style: const TextStyle(fontSize: 13))),
                    ])).toList())
                  else
                    const Text('No dead stock found', style: TextStyle(color: AppColors.success)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FINANCIAL REPORTS
// ============================================================

class _ProfitLossReport extends ConsumerWidget {
  const _ProfitLossReport();

  void _print(Map<String, dynamic> data) {
    final d = data['data'] as Map<String, dynamic>? ?? {};
    final tableHtml = buildTableHtml(
      sectionTitle: 'Profit & Loss Statement (Last 30 Days)',
      headers: ['Item', 'Amount (IQD)'],
      rows: [
        ['Revenue', '${_fmtAmount(d['revenue'])}'],
        ['Cost of Goods Sold', '(${_fmtAmount(d['cogs'])})'],
        ['Gross Profit', '${_fmtAmount(d['gross_profit'])}'],
        ['Total Expenses', '(${_fmtAmount(d['total_expenses'])})'],
        ['Net Profit', '${_fmtAmount(d['net_profit'])}'],
        ['Net Margin', '${d['net_margin_pct'] ?? 0}%'],
      ],
    );
    printReportHtml(title: 'Profit & Loss Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsProfitLossProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Profit & Loss (30 Days)', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final d = data['data'] as Map<String, dynamic>? ?? {};
              final revenue = double.parse(d['revenue']?.toString() ?? '0');
              final cogs = double.parse(d['cogs']?.toString() ?? '0');
              final grossProfit = double.parse(d['gross_profit']?.toString() ?? '0');
              final expenses = double.parse(d['total_expenses']?.toString() ?? '0');
              final netProfit = double.parse(d['net_profit']?.toString() ?? '0');
              final netMargin = double.parse(d['net_margin_pct']?.toString() ?? '0');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Revenue', d['revenue'], AppColors.primary),
                    const SizedBox(width: 12),
                    _statBadge('Net Profit', d['net_profit'], netProfit >= 0 ? AppColors.success : AppColors.error),
                    const SizedBox(width: 12),
                    _statBadge('Margin', '${netMargin.toStringAsFixed(1)}%', netProfit >= 0 ? AppColors.success : AppColors.error),
                  ]),
                  const SizedBox(height: 24),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Amount (IQD)', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: [
                    DataRow(cells: [const DataCell(Text('Revenue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))), DataCell(Text('${revenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))]),
                    DataRow(cells: [const DataCell(Text('Cost of Goods Sold', style: TextStyle(fontSize: 13))), DataCell(Text('(${cogs.toStringAsFixed(0)})', style: const TextStyle(fontSize: 13, color: AppColors.error)))]),
                    DataRow(cells: [const DataCell(Text('Gross Profit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))), DataCell(Text('${grossProfit.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(grossProfit))))]),
                    DataRow(cells: [const DataCell(Text('Expenses', style: TextStyle(fontSize: 13))), DataCell(Text('(${expenses.toStringAsFixed(0)})', style: const TextStyle(fontSize: 13, color: AppColors.error)))]),
                    DataRow(cells: [const DataCell(Text('Net Profit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))), DataCell(Text('${netProfit.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _profitColor(netProfit))))]),
                  ]),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _MonthlyProfitReport extends ConsumerWidget {
  const _MonthlyProfitReport();

  void _print(Map<String, dynamic> data) {
    final months = (data['data'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Monthly Profit & Loss',
      headers: ['Month', 'Revenue', 'COGS', 'Gross Profit', 'Expenses', 'Net Profit', 'Margin'],
      rows: months.map<List<String>>((m) => [
        m['month'] ?? '', '${_fmtAmount(m['revenue'])} IQD', '${_fmtAmount(m['cogs'])} IQD',
        '${_fmtAmount(m['gross_profit'])} IQD', '${_fmtAmount(m['expenses'])} IQD',
        '${_fmtAmount(m['net_profit'])} IQD', '${m['gross_margin']}%',
      ]).toList(),
    );
    printReportHtml(title: 'Monthly Profit Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsMonthlyProfitProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Monthly Profit & Loss', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final months = (data['data'] as List?) ?? [];
              if (months.isEmpty) return const Text('No profit data');
              return _buildTable(isDark, columns: const [
                DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('COGS', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Net Profit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Margin', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: months.map<DataRow>((m) => DataRow(cells: [
                DataCell(Text(m['month'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(m['revenue'])} IQD', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(m['cogs'])} IQD', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${_fmtAmount(m['net_profit'])} IQD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(m['net_profit'])))),
                DataCell(Text('${m['gross_margin']}%', style: const TextStyle(fontSize: 13))),
              ])).toList());
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _CashFlowReport extends ConsumerWidget {
  const _CashFlowReport();

  void _print(Map<String, dynamic> data) {
    final flowData = data['data'] as Map<String, dynamic>? ?? {};
    final days = (flowData['days'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Cash Flow (Last 30 Days)',
      headers: ['Date', 'Cash In', 'Cash Out', 'Net'],
      rows: days.map<List<String>>((d) => [
        d['date'] ?? '', '${_fmtAmount(d['cash_in'])} IQD',
        '${_fmtAmount(d['cash_out'])} IQD', '${_fmtAmount(d['net'])} IQD',
      ]).toList(),
    );
    printReportHtml(title: 'Cash Flow Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsCashFlowProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Cash Flow Report', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final flowData = data['data'] as Map<String, dynamic>? ?? {};
              final days = (flowData['days'] as List?) ?? [];
              if (days.isEmpty) return const Text('No cash flow data');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Total In', flowData['total_in'], AppColors.success),
                    const SizedBox(width: 12),
                    _statBadge('Total Out', flowData['total_out'], AppColors.error),
                    const SizedBox(width: 12),
                    _statBadge('Net Flow', flowData['net_flow'], AppColors.info),
                  ]),
                  const SizedBox(height: 16),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Cash In', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Cash Out', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Net', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: days.map<DataRow>((d) => DataRow(cells: [
                    DataCell(Text(d['date'] ?? '', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${_fmtAmount(d['cash_in'])} IQD', style: const TextStyle(fontSize: 13, color: AppColors.success))),
                    DataCell(Text('${_fmtAmount(d['cash_out'])} IQD', style: const TextStyle(fontSize: 13, color: AppColors.error))),
                    DataCell(Text('${_fmtAmount(d['net'])} IQD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(d['net'])))),
                  ])).toList()),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _CustomerBalancesReport extends ConsumerWidget {
  const _CustomerBalancesReport();

  void _print(Map<String, dynamic> data) {
    final customers = (data['data'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Customer Receivables',
      headers: ['Customer', 'Balance (IQD)', 'Credit Limit (IQD)', 'Status'],
      rows: customers.map<List<String>>((c) => [
        c['customer_name'] ?? '', '${_fmtAmount(c['current_balance'])} IQD',
        '${_fmtAmount(c['credit_limit'])} IQD', c['over_limit'] == true ? 'OVER LIMIT' : 'OK',
      ]).toList(),
    );
    printReportHtml(title: 'Customer Balances Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsCustomerBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Customer Balances', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final customers = (data['data'] as List?) ?? [];
              if (customers.isEmpty) return const Text('No receivables');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statBadge('Total Receivables', data['total_receivable'], AppColors.warning),
                  const SizedBox(height: 16),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Credit Limit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                  ], rows: customers.map<DataRow>((c) => DataRow(cells: [
                    DataCell(Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${_fmtAmount(c['current_balance'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(Text('${_fmtAmount(c['credit_limit'])} IQD', style: const TextStyle(fontSize: 13))),
                    DataCell(c['over_limit'] == true
                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('Over Limit', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)))
                      : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('OK', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)))),
                  ])).toList()),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _SupplierBalancesReport extends ConsumerWidget {
  const _SupplierBalancesReport();

  void _print(Map<String, dynamic> data) {
    final suppliers = (data['data'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Supplier Payables',
      headers: ['Supplier', 'Balance (IQD)', 'Payment Terms (days)'],
      rows: suppliers.map<List<String>>((s) => [
        s['supplier_name'] ?? '', '${_fmtAmount(s['current_balance'])} IQD', '${s['payment_terms']}',
      ]).toList(),
    );
    printReportHtml(title: 'Supplier Balances Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsSupplierBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Supplier Balances', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final suppliers = (data['data'] as List?) ?? [];
              if (suppliers.isEmpty) return const Text('No payables');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statBadge('Total Payables', data['total_payable'], AppColors.error),
                  const SizedBox(height: 16),
                  _buildTable(isDark, columns: const [
                    DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Terms (days)', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: suppliers.map<DataRow>((s) => DataRow(cells: [
                    DataCell(Text(s['supplier_name'] ?? '', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${_fmtAmount(s['current_balance'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(Text('${s['payment_terms']}', style: const TextStyle(fontSize: 13))),
                  ])).toList()),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseByCategoryReport extends ConsumerWidget {
  const _ExpenseByCategoryReport();

  void _print(Map<String, dynamic> data) {
    final d = data['data'] as Map<String, dynamic>? ?? {};
    final categories = (d['categories'] as List?) ?? [];
    final tableHtml = buildTableHtml(
      sectionTitle: 'Expenses by Category',
      headers: ['Category', 'Amount (IQD)', 'Percentage'],
      rows: categories.map<List<String>>((c) => [
        c['category'] ?? '', '${_fmtAmount(c['total_amount'])} IQD', '${c['percentage'] ?? 0}%',
      ]).toList(),
    );
    printReportHtml(title: 'Expense by Category Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsExpenseByCategoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Expenses by Category', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final d = data['data'] as Map<String, dynamic>? ?? {};
              final categories = (d['categories'] as List?) ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statBadge('Total Expenses', d['grand_total'], AppColors.error),
                  const SizedBox(height: 16),
                  if (categories.isNotEmpty)
                    _buildTable(isDark, columns: const [
                      DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ], rows: categories.map<DataRow>((c) => DataRow(cells: [
                      DataCell(Text(c['category'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(c['total_amount'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      DataCell(Text('${c['percentage'] ?? 0}%', style: const TextStyle(fontSize: 13))),
                    ])).toList())
                  else
                    const Text('No expense data'),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AI INSIGHTS REPORTS
// ============================================================

class _CustomerSegmentationReport extends ConsumerWidget {
  const _CustomerSegmentationReport();

  void _print(Map<String, dynamic> data) {
    final d = data['data'] as Map<String, dynamic>? ?? {};
    final vip = d['vip_customers'] as Map<String, dynamic>? ?? {};
    final active = d['active_customers'] as Map<String, dynamic>? ?? {};
    final inactive = d['inactive_customers'] as Map<String, dynamic>? ?? {};
    final highDebt = d['high_debt_customers'] as Map<String, dynamic>? ?? {};

    var tableHtml = '<p><strong>Total Customers: ${d['total_customers'] ?? 0}</strong> | VIP: ${vip['count'] ?? 0} | Active: ${active['count'] ?? 0} | Inactive: ${inactive['count'] ?? 0} | High Debt: ${highDebt['count'] ?? 0}</p>';

    final vipList = (vip['customers'] as List?) ?? [];
    if (vipList.isNotEmpty) {
      tableHtml += buildTableHtml(sectionTitle: 'VIP Customers (Top Spenders)', headers: ['Customer', 'Total Purchases'], rows: vipList.map<List<String>>((c) => [c['customer_name'] ?? '', '${_fmtAmount(c['total_purchases'])} IQD']).toList());
    }
    final debtList = (highDebt['customers'] as List?) ?? [];
    if (debtList.isNotEmpty) {
      tableHtml += buildTableHtml(sectionTitle: 'High Debt Customers', headers: ['Customer', 'Balance', 'Credit Limit'], rows: debtList.map<List<String>>((c) => [c['customer_name'] ?? '', '${_fmtAmount(c['current_balance'])} IQD', '${_fmtAmount(c['credit_limit'])} IQD']).toList());
    }
    printReportHtml(title: 'Customer Segmentation Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsCustomerSegmentationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Customer Segmentation', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final d = data['data'] as Map<String, dynamic>? ?? {};
              final vip = d['vip_customers'] as Map<String, dynamic>? ?? {};
              final active = d['active_customers'] as Map<String, dynamic>? ?? {};
              final inactive = d['inactive_customers'] as Map<String, dynamic>? ?? {};
              final highDebt = d['high_debt_customers'] as Map<String, dynamic>? ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _statBadge('Total', '${d['total_customers'] ?? 0}', AppColors.primary),
                    const SizedBox(width: 8),
                    _statBadge('VIP', '${vip['count'] ?? 0}', AppColors.warning),
                    const SizedBox(width: 8),
                    _statBadge('Active', '${active['count'] ?? 0}', AppColors.success),
                    const SizedBox(width: 8),
                    _statBadge('Inactive', '${inactive['count'] ?? 0}', AppColors.textSecondary),
                  ]),
                  const SizedBox(height: 20),
                  if ((vip['customers'] as List? ?? []).isNotEmpty) ...[
                    const Text('VIP Customers (Top Spenders)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildTable(isDark, columns: const [
                      DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Total Purchases', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ], rows: (vip['customers'] as List).map<DataRow>((c) => DataRow(cells: [
                      DataCell(Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(c['total_purchases'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning))),
                    ])).toList()),
                    const SizedBox(height: 20),
                  ],
                  if ((highDebt['count'] ?? 0) > 0) ...[
                    const Text('High Debt Customers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                    const SizedBox(height: 8),
                    _buildTable(isDark, columns: const [
                      DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Limit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ], rows: ((highDebt['customers'] as List?) ?? []).map<DataRow>((c) => DataRow(cells: [
                      DataCell(Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(c['current_balance'])} IQD', style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600))),
                      DataCell(Text('${_fmtAmount(c['credit_limit'])} IQD', style: const TextStyle(fontSize: 13))),
                    ])).toList()),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _RiskAssessmentReport extends ConsumerWidget {
  const _RiskAssessmentReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskAsync = ref.watch(reportsAiRiskAssessmentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          riskAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('Error loading AI risk data: $e', style: const TextStyle(color: AppColors.error))),
            data: (report) {
              final data = report['data'] as Map<String, dynamic>? ?? {};
              final risks = (data['risks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reportHeader('AI Risk Assessment', () {
                    final tableHtml = buildTableHtml(
                      sectionTitle: 'AI Risk Assessment Report',
                      headers: ['Risk Type', 'Severity', 'Title', 'Details', 'Method'],
                      rows: risks.map<List<String>>((r) => [
                        r['type']?.toString() ?? '',
                        r['severity']?.toString() ?? '',
                        r['title']?.toString() ?? '',
                        r['detail']?.toString() ?? '',
                        r['detection_method']?.toString() ?? '',
                      ]).toList(),
                    );
                    printReportHtml(title: 'AI Risk Assessment Report', tableHtml: tableHtml);
                  }),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _statBadge('Total Risks', '${data['total_risks'] ?? 0}', AppColors.warning),
                      _statBadge('High', '${data['high_severity_count'] ?? 0}', AppColors.error),
                      _statBadge('Medium', '${data['medium_severity_count'] ?? 0}', Colors.orange),
                      _statBadge('Anomalies', '${data['anomalies_detected'] ?? 0}', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (risks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 24),
                          SizedBox(width: 12),
                          Text('No significant risks detected', style: TextStyle(fontSize: 16, color: AppColors.success, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  else
                    ...risks.map((r) {
                      final isHigh = r['severity'] == 'HIGH';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isHigh ? AppColors.error : AppColors.warning).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (isHigh ? AppColors.error : AppColors.warning).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(isHigh ? Icons.error : Icons.warning, size: 24, color: isHigh ? AppColors.error : AppColors.warning),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['title']?.toString() ?? r['type']?.toString() ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isHigh ? AppColors.error : AppColors.warning)),
                                  const SizedBox(height: 4),
                                  Text(r['detail']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('Detection: ${r['detection_method']?.toString().replaceAll('_', ' ') ?? 'ai'}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isHigh ? AppColors.error : AppColors.warning).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(r['severity']?.toString() ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isHigh ? AppColors.error : AppColors.warning)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiSummaryReport extends ConsumerWidget {
  const _AiSummaryReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportsAiDailySummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summaryAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('Error loading AI summary: $e', style: const TextStyle(color: AppColors.error))),
            data: (report) {
              final data = report['data'] as Map<String, dynamic>? ?? {};
              final insights = (data['insights'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reportHeader('AI Daily Summary', () {
                    final insightText = insights.map((i) => '<p><b>${i['category']}:</b> ${i['text']}</p>').join('\n');
                    printReportHtml(title: 'AI Daily Summary', tableHtml: '<div style="font-size:14px;line-height:2;">$insightText</div>');
                  }),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _statBadge('Revenue Today', metrics['revenue_today']?.toString() ?? '0', AppColors.primary),
                      _statBadge('Avg 30d', metrics['revenue_avg_30d']?.toString() ?? '0', AppColors.info),
                      _statBadge('Net Margin', '${metrics['net_margin'] ?? 0}%', AppColors.success),
                      _statBadge('Stock at Risk', metrics['stock_at_risk']?.toString() ?? '0', AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 20, color: Colors.purple),
                            SizedBox(width: 10),
                            Text('AI Generated Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (insights.isEmpty)
                          const Text('No insights available at this time.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))
                        else
                          ...insights.map((insight) {
                            final sentiment = insight['sentiment']?.toString() ?? 'neutral';
                            final color = sentiment == 'positive' ? AppColors.success : (sentiment == 'negative' ? AppColors.error : (sentiment == 'warning' ? AppColors.warning : AppColors.textSecondary));
                            final icon = _getInsightIcon(insight['icon']?.toString() ?? 'info');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color.withOpacity(0.15)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(icon, size: 20, color: color),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(insight['category']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                                        const SizedBox(height: 4),
                                        Text(insight['text']?.toString() ?? '', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkText : AppColors.text)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getInsightIcon(String name) {
    switch (name) {
      case 'trending_up': return Icons.trending_up;
      case 'trending_down': return Icons.trending_down;
      case 'warning': return Icons.warning;
      case 'error': return Icons.error;
      case 'check_circle': return Icons.check_circle;
      case 'star': return Icons.star;
      case 'inventory': return Icons.inventory;
      case 'info': return Icons.info;
      case 'compare_arrows': return Icons.compare_arrows;
      default: return Icons.auto_awesome;
    }
  }
}
