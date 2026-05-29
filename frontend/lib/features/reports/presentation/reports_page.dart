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
          _reportOption(ctx, 'daily_operations', 'Daily Operations (Full)', Icons.summarize),
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
    _subTabController = TabController(length: 9, vsync: this);
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
              Tab(text: 'Daily Operations'),
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
              _DailyOperationsReport(),
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

// ============================================================
// DAILY OPERATIONS REPORT (comprehensive daily summary)
// ============================================================

class _DailyOperationsReport extends ConsumerWidget {
  const _DailyOperationsReport();

  void _print(Map<String, dynamic> data) {
    final sales = data['sales'] as Map<String, dynamic>? ?? {};
    final purchases = data['purchases'] as Map<String, dynamic>? ?? {};
    final expenses = data['expenses'] as Map<String, dynamic>? ?? {};
    final returns = data['returns'] as Map<String, dynamic>? ?? {};
    final payments = data['payments'] as Map<String, dynamic>? ?? {};
    final cashPosition = data['cash_position'] as Map<String, dynamic>? ?? {};
    final topProducts = (data['top_products'] as List?) ?? [];

    final buffer = StringBuffer();
    buffer.write('<p class="section-title">Sales</p>');
    buffer.write(buildTableHtml(headers: ['Metric', 'Value'], rows: [
      ['Invoices', '${sales['count'] ?? 0}'],
      ['Total', '${_fmtAmount(sales['total'])} IQD'],
      ['Cash', '${_fmtAmount(sales['cash'])} IQD'],
      ['Credit', '${_fmtAmount(sales['credit'])} IQD'],
      ['Items Sold', '${sales['items_sold'] ?? 0}'],
    ]));
    buffer.write('<p class="section-title">Purchases</p>');
    buffer.write(buildTableHtml(headers: ['Metric', 'Value'], rows: [
      ['Orders', '${purchases['count'] ?? 0}'],
      ['Total', '${_fmtAmount(purchases['total'])} IQD'],
      ['Paid', '${_fmtAmount(purchases['paid'])} IQD'],
    ]));
    buffer.write('<p class="section-title">Expenses</p>');
    buffer.write(buildTableHtml(headers: ['Metric', 'Value'], rows: [
      ['Count', '${expenses['count'] ?? 0}'],
      ['Total', '${_fmtAmount(expenses['total'])} IQD'],
    ]));
    buffer.write('<p class="section-title">Returns</p>');
    buffer.write(buildTableHtml(headers: ['Metric', 'Value'], rows: [
      ['Count', '${returns['count'] ?? 0}'],
      ['Total', '${_fmtAmount(returns['total'])} IQD'],
    ]));
    buffer.write('<p class="section-title">Payments</p>');
    buffer.write(buildTableHtml(headers: ['Metric', 'Value'], rows: [
      ['Received', '${_fmtAmount(payments['received'])} IQD'],
      ['Made', '${_fmtAmount(payments['made'])} IQD'],
    ]));
    buffer.write('<p class="section-title">Cash Position</p>');
    buffer.write(buildTableHtml(headers: ['Metric', 'Value'], rows: [
      ['Total In', '${_fmtAmount(cashPosition['total_in'])} IQD'],
      ['Total Out', '${_fmtAmount(cashPosition['total_out'])} IQD'],
      [cashPosition['label'] ?? 'Net', '${_fmtAmount(cashPosition['net'])} IQD'],
    ]));
    if (topProducts.isNotEmpty) {
      buffer.write('<p class="section-title">Top Products</p>');
      buffer.write(buildTableHtml(headers: ['Product', 'Qty', 'Revenue'], rows: topProducts.map<List<String>>((p) => [
        p['name'] ?? '', '${p['quantity'] ?? 0}', '${_fmtAmount(p['revenue'])} IQD',
      ]).toList()));
    }
    printReportHtml(title: 'Daily Operations Report - ${data['report_date'] ?? 'Today'}', tableHtml: buffer.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsDailyOperationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Daily Operations Summary', () => _print(dataAsync.valueOrNull ?? {})),
          const SizedBox(height: 16),
          dataAsync.when(
            data: (data) {
              final sales = data['sales'] as Map<String, dynamic>? ?? {};
              final purchases = data['purchases'] as Map<String, dynamic>? ?? {};
              final expenses = data['expenses'] as Map<String, dynamic>? ?? {};
              final returns = data['returns'] as Map<String, dynamic>? ?? {};
              final payments = data['payments'] as Map<String, dynamic>? ?? {};
              final cashPosition = data['cash_position'] as Map<String, dynamic>? ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Report Date: ${data['report_date'] ?? 'Today'}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Cash Position Summary (top)
                  _sectionTitle('Cash Position'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statBadge('Total In', cashPosition['total_in'], AppColors.success),
                      _statBadge('Total Out', cashPosition['total_out'], AppColors.error),
                      _statBadge(cashPosition['label'] ?? 'Net', cashPosition['net'], _profitColor(cashPosition['net'])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sales Section
                  _sectionTitle('Sales'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _opsBadge('Invoices', '${sales['count'] ?? 0}', Icons.receipt, Colors.blue),
                      _statBadge('Total', sales['total'], Colors.blue),
                      _statBadge('Cash', sales['cash'], AppColors.success),
                      _statBadge('Credit', sales['credit'], Colors.orange),
                      _opsBadge('Items Sold', '${sales['items_sold'] ?? 0}', Icons.inventory_2, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Purchases Section
                  _sectionTitle('Purchases'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _opsBadge('Orders', '${purchases['count'] ?? 0}', Icons.shopping_cart, Colors.indigo),
                      _statBadge('Total', purchases['total'], Colors.indigo),
                      _statBadge('Paid', purchases['paid'], AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Expenses Section
                  _sectionTitle('Expenses'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _opsBadge('Count', '${expenses['count'] ?? 0}', Icons.money_off, Colors.red),
                      _statBadge('Total', expenses['total'], Colors.red),
                    ],
                  ),
                  if ((expenses['categories'] as List?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    ...((expenses['categories'] as List?) ?? []).map<Widget>((c) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text('• ${c['category']}: ${_fmtAmount(c['amount'])} IQD',
                        style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  const SizedBox(height: 24),

                  // Returns Section
                  _sectionTitle('Returns'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _opsBadge('Count', '${returns['count'] ?? 0}', Icons.undo, Colors.amber),
                      _statBadge('Total', returns['total'], Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Payments Section
                  _sectionTitle('Payments'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statBadge('Received', payments['received'], AppColors.success),
                      _statBadge('Made', payments['made'], Colors.red),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // New Customers
                  _opsBadge('New Customers', '${data['new_customers'] ?? 0}', Icons.person_add, Colors.teal),
                  const SizedBox(height: 24),

                  // Top Products
                  if ((data['top_products'] as List?)?.isNotEmpty ?? false) ...[
                    _sectionTitle('Top Products Today'),
                    const SizedBox(height: 8),
                    _buildTable(isDark, columns: const [
                      DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ], rows: ((data['top_products'] as List?) ?? []).map<DataRow>((p) => DataRow(cells: [
                      DataCell(Text(p['name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${p['quantity'] ?? 0}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(p['revenue'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
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

Widget _sectionTitle(String title) {
  return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
}

Widget _opsBadge(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ],
    ),
  );
}
