import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kpi_card.dart';
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(reportsDailySalesProvider);
    ref.invalidate(reportsMonthlyProfitProvider);
    ref.invalidate(reportsTopProductsProvider);
    ref.invalidate(reportsInventoryProvider);
    ref.invalidate(reportsCustomerBalancesProvider);
    ref.invalidate(reportsSupplierBalancesProvider);
    ref.invalidate(reportsCashFlowProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profitAsync = ref.watch(reportsMonthlyProfitProvider);
    final cashFlowAsync = ref.watch(reportsCashFlowProvider);
    final customersAsync = ref.watch(reportsCustomerBalancesProvider);
    final suppliersAsync = ref.watch(reportsSupplierBalancesProvider);

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text('Reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildKPIRow(profitAsync, cashFlowAsync, customersAsync, suppliersAsync),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Sales', icon: Icon(Icons.receipt_long, size: 16)),
                Tab(text: 'Financial', icon: Icon(Icons.account_balance, size: 16)),
                Tab(text: 'Inventory', icon: Icon(Icons.warehouse, size: 16)),
                Tab(text: 'Customers', icon: Icon(Icons.people, size: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SalesReportTab(),
                _FinancialReportTab(),
                _InventoryReportTab(),
                _CustomerReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIRow(
    AsyncValue<Map<String, dynamic>> profitAsync,
    AsyncValue<Map<String, dynamic>> cashFlowAsync,
    AsyncValue<Map<String, dynamic>> customersAsync,
    AsyncValue<Map<String, dynamic>> suppliersAsync,
  ) {
    return Row(
      children: [
        Expanded(child: profitAsync.when(
          data: (data) {
            final months = data['data'] as List? ?? [];
            final revenue = months.isNotEmpty ? _parseNum(months.last['revenue']) : 0.0;
            return KPICard(title: 'Monthly Revenue', value: '${_formatNum(revenue)} IQD', icon: Icons.trending_up, color: AppColors.success);
          },
          loading: () => const KPICard(title: 'Monthly Revenue', value: '...', icon: Icons.trending_up, color: AppColors.success),
          error: (_, __) => const KPICard(title: 'Monthly Revenue', value: 'N/A', icon: Icons.trending_up, color: AppColors.success),
        )),
        const SizedBox(width: 12),
        Expanded(child: cashFlowAsync.when(
          data: (data) {
            final netFlow = _parseNum(data['data']?['net_flow']);
            return KPICard(title: 'Cash Balance', value: '${_formatNum(netFlow)} IQD', icon: Icons.account_balance_wallet, color: AppColors.info);
          },
          loading: () => const KPICard(title: 'Cash Balance', value: '...', icon: Icons.account_balance_wallet, color: AppColors.info),
          error: (_, __) => const KPICard(title: 'Cash Balance', value: 'N/A', icon: Icons.account_balance_wallet, color: AppColors.info),
        )),
        const SizedBox(width: 12),
        Expanded(child: customersAsync.when(
          data: (data) => KPICard(title: 'Receivables', value: '${_formatNum(_parseNum(data['total_receivable']))} IQD', icon: Icons.people, color: AppColors.warning),
          loading: () => const KPICard(title: 'Receivables', value: '...', icon: Icons.people, color: AppColors.warning),
          error: (_, __) => const KPICard(title: 'Receivables', value: 'N/A', icon: Icons.people, color: AppColors.warning),
        )),
        const SizedBox(width: 12),
        Expanded(child: suppliersAsync.when(
          data: (data) => KPICard(title: 'Payables', value: '${_formatNum(_parseNum(data['total_payable']))} IQD', icon: Icons.local_shipping, color: AppColors.error),
          loading: () => const KPICard(title: 'Payables', value: '...', icon: Icons.local_shipping, color: AppColors.error),
          error: (_, __) => const KPICard(title: 'Payables', value: 'N/A', icon: Icons.local_shipping, color: AppColors.error),
        )),
      ],
    );
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is String) return double.tryParse(v) ?? 0;
    return v.toDouble();
  }

  String _formatNum(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }
}

// ─── Sales Report Tab ────────────────────────────────────────────────────────
class _SalesReportTab extends ConsumerWidget {
  const _SalesReportTab();

  void _print(Map<String, dynamic> salesData, Map<String, dynamic> topData) {
    final days = (salesData['data'] as List?) ?? [];
    final products = (topData['data'] as List?) ?? [];

    var tableHtml = buildTableHtml(
      sectionTitle: 'Daily Sales (Last 30 Days)',
      headers: ['Date', 'Invoices', 'Total Sales', 'Cash Collected', 'Credit Sales'],
      rows: days.map<List<String>>((d) => [
        d['date'] ?? '', '${d['invoice_count']}',
        '${_fmtAmount(d['total_sales'])} IQD', '${_fmtAmount(d['cash_collected'])} IQD', '${_fmtAmount(d['credit_sales'])} IQD',
      ]).toList(),
    );

    tableHtml += buildTableHtml(
      sectionTitle: 'Top Selling Products',
      headers: ['#', 'Product', 'Qty Sold', 'Revenue'],
      rows: products.asMap().entries.map<List<String>>((e) => [
        '${e.key + 1}', e.value['product_name'] ?? '',
        '${e.value['total_quantity']}', '${_fmtAmount(e.value['total_revenue'])} IQD',
      ]).toList(),
    );

    printReportHtml(title: 'Sales Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(reportsDailySalesProvider);
    final topAsync = ref.watch(reportsTopProductsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reportHeader('Sales Report', () {
            final sales = salesAsync.valueOrNull ?? {};
            final top = topAsync.valueOrNull ?? {};
            _print(sales, top);
          }),
          const SizedBox(height: 16),
          _sectionTitle('Daily Sales (Last 30 Days)'),
          const SizedBox(height: 12),
          salesAsync.when(
            data: (data) {
              final days = (data['data'] as List?) ?? [];
              if (days.isEmpty) return const Text('No sales data available');
              return _buildContainer(isDark, child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                columns: const [
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Invoices', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Cash Collected', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Credit Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                ],
                rows: days.map<DataRow>((d) => DataRow(cells: [
                  DataCell(Text(d['date'] ?? '', style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${d['invoice_count']}', style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(d['total_sales']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DataCell(Text(_fmtAmount(d['cash_collected']), style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(d['credit_sales']), style: const TextStyle(fontSize: 13))),
                ])).toList(),
              ));
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Top Selling Products'),
          const SizedBox(height: 12),
          topAsync.when(
            data: (data) {
              final products = (data['data'] as List?) ?? [];
              if (products.isEmpty) return const Text('No product data');
              return _buildContainer(isDark, child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Qty Sold', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                ],
                rows: products.asMap().entries.map<DataRow>((e) => DataRow(cells: [
                  DataCell(Text('${e.key + 1}', style: const TextStyle(fontSize: 13))),
                  DataCell(Text(e.value['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${e.value['total_quantity']}', style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(e.value['total_revenue']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ])).toList(),
              ));
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ─── Financial Report Tab ────────────────────────────────────────────────────
class _FinancialReportTab extends ConsumerWidget {
  const _FinancialReportTab();

  void _print(Map<String, dynamic> profitData, Map<String, dynamic> cashData) {
    final months = (profitData['data'] as List?) ?? [];
    final flowData = cashData['data'] as Map<String, dynamic>? ?? {};
    final days = (flowData['days'] as List?) ?? [];

    var tableHtml = buildTableHtml(
      sectionTitle: 'Monthly Profit & Loss',
      headers: ['Month', 'Revenue', 'COGS', 'Gross Profit', 'Expenses', 'Net Profit', 'Margin'],
      rows: months.map<List<String>>((m) => [
        m['month'] ?? '', '${_fmtAmount(m['revenue'])} IQD', '${_fmtAmount(m['cogs'])} IQD',
        '${_fmtAmount(m['gross_profit'])} IQD', '${_fmtAmount(m['expenses'])} IQD',
        '${_fmtAmount(m['net_profit'])} IQD', '${m['gross_margin']}%',
      ]).toList(),
    );

    tableHtml += '<br><p style="font-size:14px;margin:10px 0;"><strong>Summary:</strong> Total In: ${_fmtAmount(flowData['total_in'])} IQD | Total Out: ${_fmtAmount(flowData['total_out'])} IQD | Net: ${_fmtAmount(flowData['net_flow'])} IQD</p>';

    tableHtml += buildTableHtml(
      sectionTitle: 'Cash Flow (Last 30 Days)',
      headers: ['Date', 'Cash In', 'Cash Out', 'Net'],
      rows: days.map<List<String>>((d) => [
        d['date'] ?? '', '${_fmtAmount(d['cash_in'])} IQD',
        '${_fmtAmount(d['cash_out'])} IQD', '${_fmtAmount(d['net'])} IQD',
      ]).toList(),
    );

    printReportHtml(title: 'Financial Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitAsync = ref.watch(reportsMonthlyProfitProvider);
    final cashFlowAsync = ref.watch(reportsCashFlowProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reportHeader('Financial Report', () {
            final profit = profitAsync.valueOrNull ?? {};
            final cash = cashFlowAsync.valueOrNull ?? {};
            _print(profit, cash);
          }),
          const SizedBox(height: 16),
          _sectionTitle('Monthly P&L'),
          const SizedBox(height: 12),
          profitAsync.when(
            data: (data) {
              final months = (data['data'] as List?) ?? [];
              if (months.isEmpty) return const Text('No profit data');
              return _buildContainer(isDark, child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                columns: const [
                  DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('COGS', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Gross Profit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Net Profit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Margin', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                ],
                rows: months.map<DataRow>((m) => DataRow(cells: [
                  DataCell(Text(m['month'] ?? '', style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(m['revenue']), style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(m['cogs']), style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(m['gross_profit']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success))),
                  DataCell(Text(_fmtAmount(m['expenses']), style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_fmtAmount(m['net_profit']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(m['net_profit'])))),
                  DataCell(Text('${m['gross_margin']}%', style: const TextStyle(fontSize: 13))),
                ])).toList(),
              ));
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Cash Flow (Last 30 Days)'),
          const SizedBox(height: 12),
          cashFlowAsync.when(
            data: (data) {
              final flowData = data['data'] as Map<String, dynamic>? ?? {};
              final days = (flowData['days'] as List?) ?? [];
              if (days.isEmpty) return const Text('No cash flow data');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _statBadge('Total In', flowData['total_in'], AppColors.success),
                    const SizedBox(width: 12),
                    _statBadge('Total Out', flowData['total_out'], AppColors.error),
                    const SizedBox(width: 12),
                    _statBadge('Net Flow', flowData['net_flow'], AppColors.info),
                  ]),
                  const SizedBox(height: 16),
                  _buildContainer(isDark, child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                    columns: const [
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Cash In', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Cash Out', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Net', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ],
                    rows: days.map<DataRow>((d) => DataRow(cells: [
                      DataCell(Text(d['date'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(_fmtAmount(d['cash_in']), style: const TextStyle(fontSize: 13, color: AppColors.success))),
                      DataCell(Text(_fmtAmount(d['cash_out']), style: const TextStyle(fontSize: 13, color: AppColors.error))),
                      DataCell(Text(_fmtAmount(d['net']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(d['net'])))),
                    ])).toList(),
                  )),
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

// ─── Inventory Report Tab ────────────────────────────────────────────────────
class _InventoryReportTab extends ConsumerWidget {
  const _InventoryReportTab();

  void _print(Map<String, dynamic> data) {
    final valuation = data['data'] as Map<String, dynamic>? ?? {};
    final warehouses = (valuation['warehouses'] as List?) ?? [];

    var tableHtml = '<p style="font-size:16px;font-weight:bold;margin-bottom:15px;">Total Inventory Value: ${_fmtAmount(valuation['grand_total_value'])} IQD</p>';
    tableHtml += buildTableHtml(
      sectionTitle: 'Inventory Valuation by Warehouse',
      headers: ['Warehouse', 'Products', 'Total Qty', 'Value (IQD)'],
      rows: warehouses.map<List<String>>((w) => [
        w['warehouse_name'] ?? '', '${w['product_count']}',
        '${w['total_quantity']}', '${_fmtAmount(w['total_value'])} IQD',
      ]).toList(),
    );

    printReportHtml(title: 'Inventory Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(reportsInventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reportHeader('Inventory Report', () {
            final data = inventoryAsync.valueOrNull ?? {};
            _print(data);
          }),
          const SizedBox(height: 16),
          _sectionTitle('Inventory Valuation'),
          const SizedBox(height: 12),
          inventoryAsync.when(
            data: (data) {
              final valuation = data['data'] as Map<String, dynamic>? ?? {};
              final warehouses = (valuation['warehouses'] as List?) ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inventory, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text('Total Inventory Value: ${_fmtAmount(valuation['grand_total_value'])} IQD',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _buildContainer(isDark, child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                    columns: const [
                      DataColumn(label: Text('Warehouse', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Products', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ],
                    rows: warehouses.map<DataRow>((w) => DataRow(cells: [
                      DataCell(Text(w['warehouse_name'] ?? '', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${w['product_count']}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${w['total_quantity']}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${_fmtAmount(w['total_value'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    ])).toList(),
                  )),
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

// ─── Customer Report Tab ─────────────────────────────────────────────────────
class _CustomerReportTab extends ConsumerWidget {
  const _CustomerReportTab();

  void _print(Map<String, dynamic> custData, Map<String, dynamic> suppData) {
    final customers = (custData['data'] as List?) ?? [];
    final suppliers = (suppData['data'] as List?) ?? [];

    var tableHtml = '<p style="font-size:14px;margin-bottom:10px;"><strong>Total Receivables: ${_fmtAmount(custData['total_receivable'])} IQD</strong></p>';
    tableHtml += buildTableHtml(
      sectionTitle: 'Customer Receivables',
      headers: ['Customer', 'Balance (IQD)', 'Credit Limit (IQD)', 'Status'],
      rows: customers.map<List<String>>((c) => [
        c['customer_name'] ?? '', '${_fmtAmount(c['current_balance'])} IQD',
        '${_fmtAmount(c['credit_limit'])} IQD', c['over_limit'] == true ? 'OVER LIMIT' : 'OK',
      ]).toList(),
    );

    tableHtml += '<br><p style="font-size:14px;margin-bottom:10px;"><strong>Total Payables: ${_fmtAmount(suppData['total_payable'])} IQD</strong></p>';
    tableHtml += buildTableHtml(
      sectionTitle: 'Supplier Payables',
      headers: ['Supplier', 'Balance (IQD)', 'Payment Terms (days)'],
      rows: suppliers.map<List<String>>((s) => [
        s['supplier_name'] ?? '', '${_fmtAmount(s['current_balance'])} IQD', '${s['payment_terms']}',
      ]).toList(),
    );

    printReportHtml(title: 'Customer & Supplier Report', tableHtml: tableHtml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(reportsCustomerBalancesProvider);
    final suppliersAsync = ref.watch(reportsSupplierBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reportHeader('Customer & Supplier Report', () {
            final cust = customersAsync.valueOrNull ?? {};
            final supp = suppliersAsync.valueOrNull ?? {};
            _print(cust, supp);
          }),
          const SizedBox(height: 16),
          _sectionTitle('Customer Receivables'),
          const SizedBox(height: 12),
          customersAsync.when(
            data: (data) {
              final customers = (data['data'] as List?) ?? [];
              if (customers.isEmpty) return const Text('No receivables');
              return _buildContainer(isDark, child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                columns: const [
                  DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Credit Limit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: customers.map<DataRow>((c) => DataRow(cells: [
                  DataCell(Text(c['customer_name'] ?? '', style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${_fmtAmount(c['current_balance'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DataCell(Text('${_fmtAmount(c['credit_limit'])} IQD', style: const TextStyle(fontSize: 13))),
                  DataCell(c['over_limit'] == true
                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Over Limit', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)))
                    : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('OK', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)))),
                ])).toList(),
              ));
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Supplier Payables'),
          const SizedBox(height: 12),
          suppliersAsync.when(
            data: (data) {
              final suppliers = (data['data'] as List?) ?? [];
              if (suppliers.isEmpty) return const Text('No payables');
              return _buildContainer(isDark, child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkBackground : AppColors.background),
                columns: const [
                  DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Terms (days)', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                ],
                rows: suppliers.map<DataRow>((s) => DataRow(cells: [
                  DataCell(Text(s['supplier_name'] ?? '', style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${_fmtAmount(s['current_balance'])} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DataCell(Text('${s['payment_terms']}', style: const TextStyle(fontSize: 13))),
                ])).toList(),
              ));
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
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
          label: const Text('Print Report'),
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

Widget _sectionTitle(String title) {
  return Row(children: [
    Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  ]);
}

Widget _buildContainer(bool isDark, {required Widget child}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child)),
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
