import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../customers/data/customers_repository.dart';
import '../../whatsapp/data/whatsapp_repository.dart';
import '../data/sales_repository.dart';
import 'sales_provider.dart';
import 'create_sale_dialog.dart';
import 'sale_detail_drawer.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final _searchController = TextEditingController();
  SalesInvoiceModel? _selectedInvoice;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAfterOperation() {
    invalidateAfterSale(ref);
    if (_selectedInvoice != null) {
      final repo = ref.read(salesRepositoryProvider);
      repo.getById(_selectedInvoice!.invoiceId).then((updated) {
        if (mounted) setState(() => _selectedInvoice = updated);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredAsync = ref.watch(filteredSalesProvider);
    final kpis = ref.watch(salesKpisProvider);
    final statusFilter = ref.watch(salesStatusFilterProvider);
    final typeFilter = ref.watch(salesTypeFilterProvider);
    final customersAsync = ref.watch(customersProvider);

    final customerMap = <int, String>{};
    customersAsync.whenData((customers) {
      for (final c in customers) {
        customerMap[c.customerId] = c.customerName;
      }
    });

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(isDark),
                const SizedBox(height: 20),
                _buildKpiRow(kpis, isDark),
                const SizedBox(height: 16),
                _buildAiInsightPanel(isDark),
                const SizedBox(height: 16),
                _buildFilters(statusFilter, typeFilter, isDark),
                const SizedBox(height: 16),
                Expanded(child: _buildInvoiceList(filteredAsync, customerMap, isDark)),
              ],
            ),
          ),
        ),
        if (_selectedInvoice != null)
          SaleDetailDrawer(
            key: ValueKey(_selectedInvoice!.invoiceId),
            invoice: _selectedInvoice!,
            customerName: customerMap[_selectedInvoice!.customerId] ?? 'Walk-in',
            onClose: () => setState(() => _selectedInvoice = null),
            onPaymentRecorded: _refreshAfterOperation,
          ),
      ],
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => ref.read(salesSearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search invoice / customer...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _openCreateSale,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Sale'),
        ),
        IconButton(
          onPressed: _openAiDialog,
          icon: const Icon(Icons.smart_toy_outlined),
          tooltip: 'AI Sales Assistant',
          style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1)),
        ),
        IconButton(
          onPressed: () => ref.invalidate(salesProvider),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: _showAlerts,
          icon: Badge(
            label: Text('${ref.watch(salesKpisProvider).unpaidCount}'),
            isLabelVisible: ref.watch(salesKpisProvider).unpaidCount > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: 'Alerts',
        ),
      ],
    );
  }

  Widget _buildKpiRow(SalesKpis kpis, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _KpiCard(icon: Icons.payments, label: 'Total Sales', value: _formatCurrency(kpis.totalSales), color: AppColors.primary, isDark: isDark),
          const SizedBox(width: 12),
          _KpiCard(icon: Icons.receipt_long, label: 'Invoices', value: '${kpis.invoiceCount}', color: AppColors.info, isDark: isDark),
          const SizedBox(width: 12),
          _KpiCard(icon: Icons.money, label: 'Cash', value: '${kpis.cashPercentage.toStringAsFixed(0)}%', color: AppColors.success, isDark: isDark),
          const SizedBox(width: 12),
          _KpiCard(icon: Icons.credit_card, label: 'Credit', value: '${kpis.creditPercentage.toStringAsFixed(0)}%', color: AppColors.warning, isDark: isDark),
          const SizedBox(width: 12),
          _KpiCard(icon: Icons.warning_amber, label: 'Unpaid', value: _formatCurrency(kpis.totalUnpaid), color: AppColors.error, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildAiInsightPanel(bool isDark) {
    final kpis = ref.watch(salesKpisProvider);
    final insights = <String>[];
    if (kpis.unpaidCount > 0) insights.add('${kpis.unpaidCount} unpaid invoices (${_formatCurrency(kpis.totalUnpaid)})');
    if (kpis.creditPercentage > 50) insights.add('Credit sales above 50% — monitor exposure');
    if (kpis.invoiceCount > 0 && kpis.totalSales > 0) insights.add('Average invoice: ${_formatCurrency(kpis.totalSales / kpis.invoiceCount)}');

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.05), AppColors.info.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Insights', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                ...insights.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(i, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                )),
              ],
            ),
          ),
          TextButton(onPressed: _openAiDialog, child: const Text('Ask AI', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFilters(PaymentStatusFilter statusFilter, InvoiceTypeFilter typeFilter, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(label: 'All', selected: statusFilter == PaymentStatusFilter.all, onTap: () => ref.read(salesStatusFilterProvider.notifier).state = PaymentStatusFilter.all),
        _FilterChip(label: 'Paid', selected: statusFilter == PaymentStatusFilter.paid, color: AppColors.success, onTap: () => ref.read(salesStatusFilterProvider.notifier).state = PaymentStatusFilter.paid),
        _FilterChip(label: 'Partial', selected: statusFilter == PaymentStatusFilter.partial, color: AppColors.warning, onTap: () => ref.read(salesStatusFilterProvider.notifier).state = PaymentStatusFilter.partial),
        _FilterChip(label: 'Unpaid', selected: statusFilter == PaymentStatusFilter.unpaid, color: AppColors.error, onTap: () => ref.read(salesStatusFilterProvider.notifier).state = PaymentStatusFilter.unpaid),
        const SizedBox(width: 16),
        _FilterChip(label: 'All Types', selected: typeFilter == InvoiceTypeFilter.all, onTap: () => ref.read(salesTypeFilterProvider.notifier).state = InvoiceTypeFilter.all),
        _FilterChip(label: 'Cash', selected: typeFilter == InvoiceTypeFilter.cash, color: AppColors.success, onTap: () => ref.read(salesTypeFilterProvider.notifier).state = InvoiceTypeFilter.cash),
        _FilterChip(label: 'Credit', selected: typeFilter == InvoiceTypeFilter.credit, color: AppColors.warning, onTap: () => ref.read(salesTypeFilterProvider.notifier).state = InvoiceTypeFilter.credit),
      ],
    );
  }

  Widget _buildInvoiceList(AsyncValue<List<SalesInvoiceModel>> filteredAsync, Map<int, String> customerMap, bool isDark) {
    return filteredAsync.when(
      loading: () => ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.all(0),
        itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonLoader(height: 100)),
      ),
      error: (err, _) => Center(child: Text('Error loading sales: $err')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const EmptyState(icon: Icons.receipt_long, title: 'No invoices found', description: 'Create your first sale to get started.');
        }
        return ListView.builder(
          itemCount: invoices.length,
          itemBuilder: (_, i) {
            final inv = invoices[i];
            final customerName = customerMap[inv.customerId] ?? 'Walk-in Customer';
            return _InvoiceCard(
              invoice: inv,
              customerName: customerName,
              isDark: isDark,
              isSelected: _selectedInvoice?.invoiceId == inv.invoiceId,
              onTap: () => setState(() => _selectedInvoice = inv),
              onRecordPayment: () => _recordPayment(inv),
              onAskAi: () => _askAiAboutInvoice(inv, customerName),
              onSendWhatsApp: () => _sendWhatsApp(inv),
            );
          },
        );
      },
    );
  }

  void _openCreateSale() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateSaleDialog(
        onCreated: () => invalidateAfterSale(ref),
      ),
    );
  }

  void _openAiDialog() {
    showDialog(context: context, builder: (_) => _SalesAiDialog(ref: ref));
  }

  void _showAlerts() {
    final kpis = ref.read(salesKpisProvider);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sales Alerts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kpis.unpaidCount > 0)
              ListTile(leading: const Icon(Icons.error, color: AppColors.error), title: Text('${kpis.unpaidCount} unpaid invoices'), subtitle: Text(_formatCurrency(kpis.totalUnpaid))),
            if (kpis.partialCount > 0)
              ListTile(leading: const Icon(Icons.warning, color: AppColors.warning), title: Text('${kpis.partialCount} partially paid')),
            if (kpis.creditPercentage > 50)
              ListTile(leading: const Icon(Icons.credit_card, color: AppColors.warning), title: const Text('High credit exposure'), subtitle: Text('${kpis.creditPercentage.toStringAsFixed(0)}% of sales are on credit')),
            if (kpis.unpaidCount == 0 && kpis.partialCount == 0)
              const ListTile(leading: Icon(Icons.check_circle, color: AppColors.success), title: Text('All invoices are paid!')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _recordPayment(SalesInvoiceModel invoice) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment — ${invoice.invoiceNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining: ${_formatCurrency(invoice.remaining)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Payment Amount', prefixText: 'EGP '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              try {
                final repo = ref.read(salesRepositoryProvider);
                await repo.recordPayment(
                  customerId: invoice.customerId ?? 0,
                  invoiceId: invoice.invoiceId,
                  amount: amount,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _refreshAfterOperation();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _sendWhatsApp(SalesInvoiceModel invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.chat, color: const Color(0xFF25D366)),
            const SizedBox(width: 8),
            const Text('Send via WhatsApp'),
          ],
        ),
        content: Text('Send invoice ${invoice.invoiceNumber} details to the customer via WhatsApp?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repo = ref.read(whatsappRepositoryProvider);
      await repo.sendInvoice(invoice.invoiceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice sent via WhatsApp'), backgroundColor: Color(0xFF25D366)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp error: $e')));
      }
    }
  }

  void _askAiAboutInvoice(SalesInvoiceModel invoice, String customerName) {
    showDialog(
      context: context,
      builder: (_) => _SalesAiDialog(
        ref: ref,
        initialQuery: 'Tell me about invoice ${invoice.invoiceNumber} for customer $customerName. Total: ${invoice.totalAmount}, Status: ${invoice.paymentStatus}',
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M EGP';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K EGP';
    return '${value.toStringAsFixed(0)} EGP';
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _KpiCard({required this.icon, required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? chipColor : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? chipColor : null)),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final SalesInvoiceModel invoice;
  final String customerName;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRecordPayment;
  final VoidCallback onAskAi;
  final VoidCallback onSendWhatsApp;

  const _InvoiceCard({
    required this.invoice,
    required this.customerName,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
    required this.onRecordPayment,
    required this.onAskAi,
    required this.onSendWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.isPaid ? AppColors.success : invoice.isPartial ? AppColors.warning : AppColors.error;
    final statusLabel = invoice.isPaid ? 'Paid' : invoice.isPartial ? 'Partial' : 'Unpaid';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.4) : (isDark ? AppColors.darkBorder : AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(invoice.invoiceType.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(customerName, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${double.tryParse(invoice.totalAmount)?.toStringAsFixed(0) ?? '0'} EGP', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (invoice.invoiceDate != null)
                      Text(_formatDate(invoice.invoiceDate!), style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            if (!invoice.isPaid) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: invoice.total > 0 ? (invoice.paid / invoice.total).clamp(0.0, 1.0) : 0,
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        color: statusColor,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${invoice.paid.toStringAsFixed(0)} / ${invoice.total.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 16),
                _ActionBtn(icon: Icons.visibility, label: 'View', onTap: onTap),
                const SizedBox(width: 8),
                if (!invoice.isPaid) _ActionBtn(icon: Icons.payment, label: 'Pay', onTap: onRecordPayment),
                if (!invoice.isPaid) const SizedBox(width: 8),
                _ActionBtn(icon: Icons.smart_toy_outlined, label: 'AI', onTap: onAskAi),
                const SizedBox(width: 8),
                _ActionBtn(icon: Icons.chat, label: 'WhatsApp', onTap: onSendWhatsApp, color: const Color(0xFF25D366)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: btnColor.withOpacity(0.4))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: btnColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: btnColor)),
          ],
        ),
      ),
    );
  }
}

class _SalesAiDialog extends StatefulWidget {
  final WidgetRef ref;
  final String? initialQuery;

  const _SalesAiDialog({required this.ref, this.initialQuery});

  @override
  State<_SalesAiDialog> createState() => _SalesAiDialogState();
}

class _SalesAiDialogState extends State<_SalesAiDialog> {
  final _controller = TextEditingController();
  String? _response;
  bool _loading = false;

  final _suggestions = [
    'Why are sales down this week?',
    'Which customers delay payments?',
    'What are top selling products today?',
    'Should I give discounts to increase sales?',
    'Forecast next week sales',
    'Which invoices are overdue?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _send();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() { _loading = true; _response = null; });
    try {
      final repo = widget.ref.read(salesRepositoryProvider);
      final resp = await repo.aiChat(query);
      setState(() => _response = resp);
    } catch (e) {
      setState(() => _response = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('AI Sales Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask about sales...',
                suffixIcon: IconButton(onPressed: _loading ? null : _send, icon: const Icon(Icons.send)),
              ),
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestions.map((s) => ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                onPressed: () { _controller.text = s; _send(); },
              )).toList(),
            ),
            if (_loading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_response != null) ...[
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(child: SelectableText(_response!, style: const TextStyle(fontSize: 13))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
