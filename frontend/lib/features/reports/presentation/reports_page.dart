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
    _tabController = TabController(length: 7, vsync: this);
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
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(text: 'Daily Sales', icon: Icon(Icons.receipt_long, size: 16)),
                Tab(text: 'Profit', icon: Icon(Icons.trending_up, size: 16)),
                Tab(text: 'Top Products', icon: Icon(Icons.star, size: 16)),
                Tab(text: 'Inventory', icon: Icon(Icons.warehouse, size: 16)),
                Tab(text: 'Customers', icon: Icon(Icons.people, size: 16)),
                Tab(text: 'Suppliers', icon: Icon(Icons.local_shipping, size: 16)),
                Tab(text: 'Cash Flow', icon: Icon(Icons.account_balance_wallet, size: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _DailySalesTab(),
                _MonthlyProfitTab(),
                _TopProductsTab(),
                _InventoryTab(),
                _CustomerBalancesTab(),
                _SupplierBalancesTab(),
                _CashFlowTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Sales Tab ─────────────────────────────────────────────────────────
class _DailySalesTab extends ConsumerWidget {
  const _DailySalesTab();

  void _print(Map<String, dynamic> salesData) {
    final days = (salesData['data'] as List?) ?? [];
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
          _reportHeader('Daily Sales Report', () {
            final sales = salesAsync.valueOrNull ?? {};
            _print(sales);
          }),
          const SizedBox(height: 16),
          salesAsync.when(
            data: (data) {
              final days = (data['data'] as List?) ?? [];
              if (days.isEmpty) return const Text('No sales data available');
              return _buildFullWidthTable(isDark, columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Invoices', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Cash Collected', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Credit Sales', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: days.map<DataRow>((d) => DataRow(cells: [
                DataCell(Text(d['date'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${d['invoice_count']}', style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(d['total_sales']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                DataCell(Text(_fmtAmount(d['cash_collected']), style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(d['credit_sales']), style: const TextStyle(fontSize: 13))),
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

// ─── Monthly Profit Tab ──────────────────────────────────────────────────────
class _MonthlyProfitTab extends ConsumerWidget {
  const _MonthlyProfitTab();

  void _print(Map<String, dynamic> profitData) {
    final months = (profitData['data'] as List?) ?? [];
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
    final profitAsync = ref.watch(reportsMonthlyProfitProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Monthly Profit & Loss', () {
            final profit = profitAsync.valueOrNull ?? {};
            _print(profit);
          }),
          const SizedBox(height: 16),
          profitAsync.when(
            data: (data) {
              final months = (data['data'] as List?) ?? [];
              if (months.isEmpty) return const Text('No profit data');
              return _buildFullWidthTable(isDark, columns: const [
                DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('COGS', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Gross Profit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Net Profit', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Margin', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: months.map<DataRow>((m) => DataRow(cells: [
                DataCell(Text(m['month'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(m['revenue']), style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(m['cogs']), style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(m['gross_profit']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success))),
                DataCell(Text(_fmtAmount(m['expenses']), style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(m['net_profit']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(m['net_profit'])))),
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

// ─── Top Products Tab ────────────────────────────────────────────────────────
class _TopProductsTab extends ConsumerWidget {
  const _TopProductsTab();

  void _print(Map<String, dynamic> topData) {
    final products = (topData['data'] as List?) ?? [];
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
    final topAsync = ref.watch(reportsTopProductsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Top Selling Products', () {
            final top = topAsync.valueOrNull ?? {};
            _print(top);
          }),
          const SizedBox(height: 16),
          topAsync.when(
            data: (data) {
              final products = (data['data'] as List?) ?? [];
              if (products.isEmpty) return const Text('No product data');
              return _buildFullWidthTable(isDark, columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Qty Sold', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              ], rows: products.asMap().entries.map<DataRow>((e) => DataRow(cells: [
                DataCell(Text('${e.key + 1}', style: const TextStyle(fontSize: 13))),
                DataCell(Text(e.value['product_name'] ?? '', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${e.value['total_quantity']}', style: const TextStyle(fontSize: 13))),
                DataCell(Text(_fmtAmount(e.value['total_revenue']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
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

// ─── Inventory Tab ───────────────────────────────────────────────────────────
class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Inventory Valuation', () {
            final data = inventoryAsync.valueOrNull ?? {};
            _print(data);
          }),
          const SizedBox(height: 16),
          inventoryAsync.when(
            data: (data) {
              final valuation = data['data'] as Map<String, dynamic>? ?? {};
              final warehouses = (valuation['warehouses'] as List?) ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  _buildFullWidthTable(isDark, columns: const [
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

// ─── Customer Balances Tab ───────────────────────────────────────────────────
class _CustomerBalancesTab extends ConsumerWidget {
  const _CustomerBalancesTab();

  void _print(Map<String, dynamic> custData) {
    final customers = (custData['data'] as List?) ?? [];
    var tableHtml = '<p style="font-size:14px;margin-bottom:10px;"><strong>Total Receivables: ${_fmtAmount(custData['total_receivable'])} IQD</strong></p>';
    tableHtml += buildTableHtml(
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
    final customersAsync = ref.watch(reportsCustomerBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Customer Balances', () {
            final cust = customersAsync.valueOrNull ?? {};
            _print(cust);
          }),
          const SizedBox(height: 16),
          customersAsync.when(
            data: (data) {
              final customers = (data['data'] as List?) ?? [];
              if (customers.isEmpty) return const Text('No receivables');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statBadge('Total Receivables', data['total_receivable'], AppColors.warning),
                  const SizedBox(height: 16),
                  _buildFullWidthTable(isDark, columns: const [
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

// ─── Supplier Balances Tab ───────────────────────────────────────────────────
class _SupplierBalancesTab extends ConsumerWidget {
  const _SupplierBalancesTab();

  void _print(Map<String, dynamic> suppData) {
    final suppliers = (suppData['data'] as List?) ?? [];
    var tableHtml = '<p style="font-size:14px;margin-bottom:10px;"><strong>Total Payables: ${_fmtAmount(suppData['total_payable'])} IQD</strong></p>';
    tableHtml += buildTableHtml(
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
    final suppliersAsync = ref.watch(reportsSupplierBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Supplier Balances', () {
            final supp = suppliersAsync.valueOrNull ?? {};
            _print(supp);
          }),
          const SizedBox(height: 16),
          suppliersAsync.when(
            data: (data) {
              final suppliers = (data['data'] as List?) ?? [];
              if (suppliers.isEmpty) return const Text('No payables');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statBadge('Total Payables', data['total_payable'], AppColors.error),
                  const SizedBox(height: 16),
                  _buildFullWidthTable(isDark, columns: const [
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

// ─── Cash Flow Tab ───────────────────────────────────────────────────────────
class _CashFlowTab extends ConsumerWidget {
  const _CashFlowTab();

  void _print(Map<String, dynamic> cashData) {
    final flowData = cashData['data'] as Map<String, dynamic>? ?? {};
    final days = (flowData['days'] as List?) ?? [];

    var tableHtml = '<p style="font-size:14px;margin:10px 0;"><strong>Summary:</strong> Total In: ${_fmtAmount(flowData['total_in'])} IQD | Total Out: ${_fmtAmount(flowData['total_out'])} IQD | Net: ${_fmtAmount(flowData['net_flow'])} IQD</p>';
    tableHtml += buildTableHtml(
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
    final cashFlowAsync = ref.watch(reportsCashFlowProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeader('Cash Flow Report', () {
            final cash = cashFlowAsync.valueOrNull ?? {};
            _print(cash);
          }),
          const SizedBox(height: 16),
          cashFlowAsync.when(
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
                  _buildFullWidthTable(isDark, columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Cash In', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Cash Out', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    DataColumn(label: Text('Net', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  ], rows: days.map<DataRow>((d) => DataRow(cells: [
                    DataCell(Text(d['date'] ?? '', style: const TextStyle(fontSize: 13))),
                    DataCell(Text(_fmtAmount(d['cash_in']), style: const TextStyle(fontSize: 13, color: AppColors.success))),
                    DataCell(Text(_fmtAmount(d['cash_out']), style: const TextStyle(fontSize: 13, color: AppColors.error))),
                    DataCell(Text(_fmtAmount(d['net']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _profitColor(d['net'])))),
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

Widget _buildFullWidthTable(bool isDark, {required List<DataColumn> columns, required List<DataRow> rows}) {
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
