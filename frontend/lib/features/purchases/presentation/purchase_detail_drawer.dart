import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/print_helper.dart';
import '../data/purchases_repository.dart';

class PurchaseDetailDrawer extends ConsumerStatefulWidget {
  final PurchaseInvoiceModel invoice;
  final String supplierName;
  final VoidCallback onClose;
  final VoidCallback onPaymentRecorded;

  const PurchaseDetailDrawer({
    super.key,
    required this.invoice,
    required this.supplierName,
    required this.onClose,
    required this.onPaymentRecorded,
  });

  @override
  ConsumerState<PurchaseDetailDrawer> createState() => _PurchaseDetailDrawerState();
}

class _PurchaseDetailDrawerState extends ConsumerState<PurchaseDetailDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _aiResponse;
  bool _aiLoading = false;
  List<PurchasePaymentModel> _payments = [];
  bool _paymentsLoading = false;
  List<PurchaseItemDetailModel> _items = [];
  bool _itemsLoading = false;
  List<PurchaseReturnModel> _returns = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PurchaseDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoice.purchaseInvoiceId != widget.invoice.purchaseInvoiceId ||
        oldWidget.invoice.totalAmount != widget.invoice.totalAmount ||
        oldWidget.invoice.paymentStatus != widget.invoice.paymentStatus) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _paymentsLoading = true;
      _itemsLoading = true;
    });
    final repo = ref.read(purchasesRepositoryProvider);

    // Load each independently so one failure doesn't block the others
    try {
      final items = await repo.getItems(widget.invoice.purchaseInvoiceId);
      if (mounted) setState(() => _items = items);
    } catch (_) {}

    try {
      final payments = await repo.getPayments(widget.invoice.purchaseInvoiceId);
      if (mounted) setState(() => _payments = payments);
    } catch (_) {}

    try {
      final returns = await repo.getReturns(widget.invoice.purchaseInvoiceId);
      if (mounted) setState(() => _returns = returns);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _paymentsLoading = false;
        _itemsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = widget.invoice;
    final statusColor = inv.isPaid ? AppColors.success : inv.isPartial ? AppColors.warning : AppColors.error;
    final statusLabel = inv.isPaid ? 'Paid' : inv.isPartial ? 'Partial' : 'Unpaid';

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(left: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.receipt_long, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(widget.supplierName, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, size: 20)),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'AI Insights'),
              Tab(text: 'Actions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(isDark, inv, statusColor),
                _buildAiInsights(isDark, inv),
                _buildActions(isDark, inv),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(bool isDark, PurchaseInvoiceModel inv, Color statusColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Invoice Details'),
          const SizedBox(height: 8),
          if (inv.purchaseDate != null) _infoRow('Date', _formatDate(inv.purchaseDate!), isDark),
          _infoRow('Invoice ID', '#${inv.purchaseInvoiceId}', isDark),
          _infoRow('Invoice Number', inv.invoiceNumber, isDark),
          const SizedBox(height: 16),
          _buildProductsList(isDark),
          const SizedBox(height: 16),
          _sectionTitle('Financial Summary'),
          const SizedBox(height: 8),
          _infoRow('Total Amount', '${inv.total.toStringAsFixed(2)} IQD', isDark),
          _infoRow('Paid', '${inv.paid.toStringAsFixed(2)} IQD', isDark),
          _infoRow('Remaining', '${inv.remaining.toStringAsFixed(2)} IQD', isDark, valueColor: inv.remaining > 0 ? AppColors.error : AppColors.success),
          const SizedBox(height: 16),
          if (!inv.isPaid) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: inv.total > 0 ? (inv.paid / inv.total).clamp(0.0, 1.0) : 0,
                backgroundColor: Colors.grey.withOpacity(0.15),
                color: statusColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(inv.paid / (inv.total > 0 ? inv.total : 1) * 100).toStringAsFixed(0)}% paid', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            const SizedBox(height: 16),
          ],
          _buildPaymentHistory(isDark),
          const SizedBox(height: 16),
          _buildReturnsHistory(isDark),
        ],
      ),
    );
  }

  Widget _buildProductsList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('Products'),
            const SizedBox(width: 6),
            if (!_itemsLoading && _items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('${_items.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            const Spacer(),
            if (_itemsLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty && !_itemsLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Text(
              'No items found',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ..._items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.purchasedQuantity % 1 == 0 ? item.purchasedQuantity.toInt() : item.purchasedQuantity.toStringAsFixed(2)} x ${item.purchasePrice.toStringAsFixed(2)} IQD',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                    if (item.returnedQuantity > 0)
                      Text(
                        'Returned: ${item.returnedQuantity % 1 == 0 ? item.returnedQuantity.toInt() : item.returnedQuantity.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.warning),
                      ),
                  ],
                ),
              ),
              Text(
                '${item.totalCost.toStringAsFixed(2)} IQD',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildPaymentHistory(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('Payment History'),
            const Spacer(),
            if (_paymentsLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        if (_payments.isEmpty && !_paymentsLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Text(
              'No payments recorded yet',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ..._payments.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.amount.toStringAsFixed(2)} IQD',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (p.paymentDate != null)
                      Text(
                        _formatDate(p.paymentDate!),
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (p.notes != null && p.notes!.isNotEmpty)
                Tooltip(
                  message: p.notes!,
                  child: Icon(Icons.note, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildReturnsHistory(bool isDark) {
    if (_returns.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Return History'),
        const SizedBox(height: 8),
        ..._returns.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.assignment_return, color: AppColors.warning, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.returnedAmount.toStringAsFixed(2)} IQD',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (r.returnDate != null)
                      Text(
                        _formatDate(r.returnDate!),
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    if (r.notes != null && r.notes!.isNotEmpty)
                      Text(r.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAiInsights(bool isDark, PurchaseInvoiceModel inv) {
    final questions = [
      'Why is this purchase invoice ${inv.paymentStatus}?',
      'Should I follow up with ${widget.supplierName}?',
      'What is the payment history for this supplier?',
      'Is this invoice amount normal for this supplier?',
      'Recommend a payment strategy',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Ask AI about this invoice'),
          const SizedBox(height: 12),
          ...questions.map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _askAi(q),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(q, style: const TextStyle(fontSize: 13))),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          )),
          if (_aiLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_aiResponse != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('AI Response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_aiResponse!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark, PurchaseInvoiceModel inv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          if (!inv.isPaid)
            _actionTile(Icons.payment, 'Record Payment', 'Add a payment to this invoice', AppColors.success, () => _recordPayment(inv)),
          _actionTile(Icons.print, 'Print Invoice', 'Generate PDF invoice', AppColors.info, () => _printInvoice(inv)),
          _actionTile(Icons.assignment_return, 'Return Items', 'Return specific products to supplier', AppColors.warning, () => _returnItems(inv)),
          const Divider(height: 32),
          _sectionTitle('AI Actions'),
          const SizedBox(height: 12),
          _actionTile(Icons.smart_toy, 'Explain Invoice', 'AI breakdown of this purchase', AppColors.primary, () => _askAi('Explain purchase invoice ${inv.invoiceNumber}: Total ${inv.totalAmount}, Supplier: ${widget.supplierName}, Status: ${inv.paymentStatus}')),
          _actionTile(Icons.trending_up, 'Purchase Analysis', 'AI analysis of this supplier\'s purchase pattern', AppColors.primary, () => _askAi('Analyze purchase pattern for supplier ${widget.supplierName}')),
          _actionTile(Icons.lightbulb, 'Recommendations', 'Get AI recommendations', AppColors.primary, () => _askAi('What recommendations do you have for purchase invoice ${inv.invoiceNumber}?')),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
  }

  Widget _infoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  void _printInvoice(PurchaseInvoiceModel inv) {
    final dateStr = inv.purchaseDate != null ? _formatDate(inv.purchaseDate!) : 'N/A';

    var tableHtml = '''
<div style="margin-bottom: 20px; padding: 16px; background: #f8f9fa; border-radius: 8px;">
  <table style="width: 100%; border: none;">
    <tr><td style="border: none; padding: 4px 0;"><strong>Invoice Number:</strong></td><td style="border: none; padding: 4px 0;">${inv.invoiceNumber}</td></tr>
    <tr><td style="border: none; padding: 4px 0;"><strong>Supplier:</strong></td><td style="border: none; padding: 4px 0;">${widget.supplierName}</td></tr>
    <tr><td style="border: none; padding: 4px 0;"><strong>Date:</strong></td><td style="border: none; padding: 4px 0;">$dateStr</td></tr>
  </table>
</div>
''';

    if (_items.isNotEmpty) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Products',
        headers: ['#', 'Product', 'Qty', 'Price', 'Returned', 'Total'],
        rows: _items.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final item = entry.value;
          final qty = item.purchasedQuantity % 1 == 0 ? '${item.purchasedQuantity.toInt()}' : item.purchasedQuantity.toStringAsFixed(2);
          final retQty = item.returnedQuantity > 0
              ? (item.returnedQuantity % 1 == 0 ? '${item.returnedQuantity.toInt()}' : item.returnedQuantity.toStringAsFixed(2))
              : '-';
          return [
            '$i',
            item.productName,
            qty,
            item.purchasePrice.toStringAsFixed(2),
            retQty,
            item.totalCost.toStringAsFixed(2),
          ];
        }).toList(),
      );
    }

    tableHtml += buildTableHtml(
      sectionTitle: 'Payment Summary',
      headers: ['Description', 'Amount (IQD)'],
      rows: [
        ['Total Amount', inv.total.toStringAsFixed(2)],
        ['Paid Amount', inv.paid.toStringAsFixed(2)],
        ['Remaining', inv.remaining.toStringAsFixed(2)],
      ],
    );

    if (_payments.isNotEmpty) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Payment History',
        headers: ['#', 'Amount (IQD)', 'Date', 'Notes'],
        rows: _payments.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final p = entry.value;
          final pDate = p.paymentDate != null ? _formatDate(p.paymentDate!) : 'N/A';
          return ['$i', p.amount.toStringAsFixed(2), pDate, p.notes ?? '-'];
        }).toList(),
      );
    }

    if (_returns.isNotEmpty) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Return Operations',
        headers: ['#', 'Date', 'Returned Amount (IQD)', 'Notes'],
        rows: _returns.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final r = entry.value;
          final rDate = r.returnDate != null ? _formatDate(r.returnDate!) : 'N/A';
          return [
            '$i',
            rDate,
            r.returnedAmount.toStringAsFixed(2),
            r.notes ?? '-',
          ];
        }).toList(),
      );
    }

    tableHtml += '''
<div style="margin-top: 20px; padding: 12px; border: 2px solid ${inv.isPaid ? '#1e8e3e' : '#d93025'}; border-radius: 8px; text-align: center;">
  <strong style="color: ${inv.isPaid ? '#1e8e3e' : '#d93025'}; font-size: 16px;">
    Payment Status: ${inv.paymentStatus.toUpperCase()}
  </strong>
</div>
''';

    printReportHtml(title: 'Purchase Invoice ${inv.invoiceNumber}', tableHtml: tableHtml);
  }

  void _returnItems(PurchaseInvoiceModel inv) {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items loaded yet. Please wait.')));
      return;
    }

    final returnableItems = _items.where((item) => item.returnableQuantity > 0).toList();
    if (returnableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All items have already been returned')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PurchaseReturnItemsDialog(
        items: returnableItems,
        invoice: inv,
        onSubmit: (returnItems, refundAmount, notes) async {
          try {
            final repo = ref.read(purchasesRepositoryProvider);
            await repo.createReturn(
              inv.purchaseInvoiceId,
              items: returnItems,
              refundAmount: refundAmount,
              notes: notes,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            widget.onPaymentRecorded();
            _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Return processed successfully')),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  Future<void> _askAi(String question) async {
    setState(() { _aiLoading = true; _aiResponse = null; });
    _tabController.animateTo(1);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final resp = await repo.aiChat(question);
      setState(() => _aiResponse = resp['response'] as String?);
    } catch (e) {
      setState(() => _aiResponse = 'Error: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _recordPayment(PurchaseInvoiceModel invoice) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment - ${invoice.invoiceNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining: ${invoice.remaining.toStringAsFixed(2)} IQD'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Payment Amount', suffixText: 'IQD'),
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
                final repo = ref.read(purchasesRepositoryProvider);
                await repo.recordPayment(invoice.supplierId, {
                  'related_invoice_id': invoice.purchaseInvoiceId,
                  'payment_amount': amount,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onPaymentRecorded();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ${amount.toStringAsFixed(2)} IQD recorded successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
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

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}


class _PurchaseReturnItemsDialog extends StatefulWidget {
  final List<PurchaseItemDetailModel> items;
  final PurchaseInvoiceModel invoice;
  final Future<void> Function(List<Map<String, dynamic>> returnItems, double refundAmount, String? notes) onSubmit;

  const _PurchaseReturnItemsDialog({required this.items, required this.invoice, required this.onSubmit});

  @override
  State<_PurchaseReturnItemsDialog> createState() => _PurchaseReturnItemsDialogState();
}

class _PurchaseReturnItemsDialogState extends State<_PurchaseReturnItemsDialog> {
  late final List<TextEditingController> _qtyControllers;
  late final List<bool> _selected;
  final _notesController = TextEditingController();
  bool _refundCash = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _qtyControllers = widget.items.map((item) => TextEditingController(text: '0')).toList();
    _selected = List.filled(widget.items.length, false);
  }

  @override
  void dispose() {
    for (final c in _qtyControllers) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  double get _returnTotal {
    double total = 0;
    for (int i = 0; i < widget.items.length; i++) {
      if (_selected[i]) {
        final qty = double.tryParse(_qtyControllers[i].text) ?? 0;
        total += qty * widget.items[i].purchasePrice;
      }
    }
    return total;
  }

  Future<void> _submit() async {
    final returnItems = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.items.length; i++) {
      if (!_selected[i]) continue;
      final qty = double.tryParse(_qtyControllers[i].text) ?? 0;
      if (qty <= 0) continue;
      if (qty > widget.items[i].returnableQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.items[i].productName}: return qty exceeds returnable qty (${widget.items[i].returnableQuantity})')),
        );
        return;
      }
      final total = qty * widget.items[i].purchasePrice;
      returnItems.add({
        'product_id': widget.items[i].productId,
        'returned_quantity': qty,
        'unit_cost': widget.items[i].purchasePrice,
        'total': total,
      });
    }

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to return')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final refund = _refundCash ? _returnTotal : 0.0;
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    await widget.onSubmit(returnItems, refund, notes);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_return, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Return Items to Supplier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text(widget.invoice.invoiceNumber, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select items to return:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...widget.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: _selected[i] ? AppColors.warning : Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                          color: _selected[i] ? AppColors.warning.withOpacity(0.03) : null,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _selected[i],
                              onChanged: (v) => setState(() => _selected[i] = v ?? false),
                              activeColor: AppColors.warning,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                  Text('Returnable: ${item.returnableQuantity % 1 == 0 ? item.returnableQuantity.toInt() : item.returnableQuantity.toStringAsFixed(2)} @ ${item.purchasePrice.toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  if (item.returnedQuantity > 0)
                                    Text('Already returned: ${item.returnedQuantity % 1 == 0 ? item.returnedQuantity.toInt() : item.returnedQuantity.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
                                ],
                              ),
                            ),
                            if (_selected[i])
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _qtyControllers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Request cash refund from supplier', style: TextStyle(fontSize: 14)),
                      subtitle: Text(_refundCash ? 'Cash refund: ${_returnTotal.toStringAsFixed(0)} IQD' : 'Credit balance adjustment only'),
                      value: _refundCash,
                      onChanged: (v) => setState(() => _refundCash = v),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Reason for return...',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Return Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('${_returnTotal.toStringAsFixed(0)} IQD', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.assignment_return),
                    label: const Text('Process Return'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
