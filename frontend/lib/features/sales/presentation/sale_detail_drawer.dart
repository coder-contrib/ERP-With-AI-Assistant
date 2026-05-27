import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/print_helper.dart';
import '../../../core/widgets/validation_error_banner.dart';
import '../data/sales_repository.dart';

class SaleDetailDrawer extends ConsumerStatefulWidget {
  final SalesInvoiceModel invoice;
  final String customerName;
  final VoidCallback onClose;
  final VoidCallback onPaymentRecorded;

  const SaleDetailDrawer({
    super.key,
    required this.invoice,
    required this.customerName,
    required this.onClose,
    required this.onPaymentRecorded,
  });

  @override
  ConsumerState<SaleDetailDrawer> createState() => _SaleDetailDrawerState();
}

class _SaleDetailDrawerState extends ConsumerState<SaleDetailDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _aiResponse;
  bool _aiLoading = false;
  List<InvoicePaymentModel> _payments = [];
  bool _paymentsLoading = false;
  List<InvoiceItemModel> _items = [];
  bool _itemsLoading = false;
  List<SalesReturnModel> _returns = [];

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
  void didUpdateWidget(covariant SaleDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoice.invoiceId != widget.invoice.invoiceId ||
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
    final repo = ref.read(salesRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.getInvoicePayments(widget.invoice.invoiceId),
        repo.getInvoiceItems(widget.invoice.invoiceId),
        repo.getReturns(widget.invoice.invoiceId),
      ]);
      if (mounted) {
        setState(() {
          _payments = results[0] as List<InvoicePaymentModel>;
          _items = results[1] as List<InvoiceItemModel>;
          _returns = results[2] as List<SalesReturnModel>;
        });
      }
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
                      Text(widget.customerName, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
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

  Widget _buildOverview(bool isDark, SalesInvoiceModel inv, Color statusColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Invoice Details'),
          const SizedBox(height: 8),
          _infoRow('Type', inv.invoiceType.toUpperCase(), isDark),
          _infoRow('Warehouse', 'Warehouse ${inv.warehouseId}', isDark),
          if (inv.invoiceDate != null) _infoRow('Date', _formatDate(inv.invoiceDate!), isDark),
          _infoRow('Invoice ID', '#${inv.invoiceId}', isDark),
          const SizedBox(height: 16),
          _buildProductsList(isDark),
          const SizedBox(height: 16),
          _sectionTitle('Financial Summary'),
          const SizedBox(height: 8),
          _infoRow('Total Amount', '${inv.total.toStringAsFixed(2)} EGP', isDark),
          _infoRow('Discount', '${inv.discount.toStringAsFixed(2)} EGP', isDark),
          _infoRow('Paid', '${inv.paid.toStringAsFixed(2)} EGP', isDark),
          _infoRow('Remaining', '${inv.remaining.toStringAsFixed(2)} EGP', isDark, valueColor: inv.remaining > 0 ? AppColors.error : AppColors.success),
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
                      '${item.soldQuantity % 1 == 0 ? item.soldQuantity.toInt() : item.soldQuantity.toStringAsFixed(2)} ${item.unitType} × ${item.unitPrice.toStringAsFixed(2)} EGP',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.totalPrice.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (item.discount > 0)
                    Text(
                      '-${item.discount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                ],
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
                      '${p.amount.toStringAsFixed(2)} EGP',
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

  Widget _buildAiInsights(bool isDark, SalesInvoiceModel inv) {
    final questions = [
      'Why is this invoice ${inv.paymentStatus}?',
      'Should I follow up with ${widget.customerName}?',
      'What is the payment history for this customer?',
      'Is this invoice amount normal for this customer?',
      'Recommend a collection strategy',
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

  Widget _buildActions(bool isDark, SalesInvoiceModel inv) {
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
          _actionTile(Icons.edit, 'Edit Invoice', 'Modify invoice details', AppColors.warning, () => _editInvoice(inv)),
          _actionTile(Icons.assignment_return, 'Return Items', 'Return specific products from this invoice', AppColors.warning, () => _returnItems(inv)),
          _actionTile(Icons.cancel, 'Cancel Invoice', 'Cancel entire invoice', AppColors.error, () => _cancelInvoice(inv)),
          const Divider(height: 32),
          _sectionTitle('AI Actions'),
          const SizedBox(height: 12),
          _actionTile(Icons.smart_toy, 'Explain Invoice', 'AI breakdown of this sale', AppColors.primary, () => _askAi('Explain invoice ${inv.invoiceNumber}: Total ${inv.totalAmount}, Customer: ${widget.customerName}, Status: ${inv.paymentStatus}')),
          _actionTile(Icons.trending_up, 'Sales Analysis', 'AI analysis of this customer\'s sales pattern', AppColors.primary, () => _askAi('Analyze sales pattern for customer ${widget.customerName}')),
          _actionTile(Icons.lightbulb, 'Recommendations', 'Get AI recommendations', AppColors.primary, () => _askAi('What recommendations do you have for invoice ${inv.invoiceNumber}?')),
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

  void _printInvoice(SalesInvoiceModel inv) {
    final dateStr = inv.invoiceDate != null ? _formatDate(inv.invoiceDate!) : 'N/A';

    var tableHtml = '''
<div style="margin-bottom: 20px; padding: 16px; background: #f8f9fa; border-radius: 8px;">
  <table style="width: 100%; border: none;">
    <tr><td style="border: none; padding: 4px 0;"><strong>Invoice Number:</strong></td><td style="border: none; padding: 4px 0;">${inv.invoiceNumber}</td></tr>
    <tr><td style="border: none; padding: 4px 0;"><strong>Customer:</strong></td><td style="border: none; padding: 4px 0;">${widget.customerName}</td></tr>
    <tr><td style="border: none; padding: 4px 0;"><strong>Date:</strong></td><td style="border: none; padding: 4px 0;">$dateStr</td></tr>
    <tr><td style="border: none; padding: 4px 0;"><strong>Type:</strong></td><td style="border: none; padding: 4px 0;">${inv.invoiceType.toUpperCase()}</td></tr>
    <tr><td style="border: none; padding: 4px 0;"><strong>Warehouse:</strong></td><td style="border: none; padding: 4px 0;">Warehouse ${inv.warehouseId}</td></tr>
  </table>
</div>
''';

    if (_items.isNotEmpty) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Products',
        headers: ['#', 'Product', 'Qty', 'Unit', 'Price', 'Discount', 'Returned', 'Total'],
        rows: _items.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final item = entry.value;
          final qty = item.soldQuantity % 1 == 0 ? '${item.soldQuantity.toInt()}' : item.soldQuantity.toStringAsFixed(2);
          final retQty = item.returnedQuantity > 0
              ? (item.returnedQuantity % 1 == 0 ? '${item.returnedQuantity.toInt()}' : item.returnedQuantity.toStringAsFixed(2))
              : '—';
          return [
            '$i',
            item.productName,
            qty,
            item.unitType,
            item.unitPrice.toStringAsFixed(2),
            item.discount.toStringAsFixed(2),
            retQty,
            item.totalPrice.toStringAsFixed(2),
          ];
        }).toList(),
      );
    }

    tableHtml += buildTableHtml(
      sectionTitle: 'Payment Summary',
      headers: ['Description', 'Amount (EGP)'],
      rows: [
        ['Total Amount', inv.total.toStringAsFixed(2)],
        ['Discount', inv.discount.toStringAsFixed(2)],
        ['Paid Amount', inv.paid.toStringAsFixed(2)],
        ['Remaining', inv.remaining.toStringAsFixed(2)],
      ],
    );

    if (_payments.isNotEmpty) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Payment History',
        headers: ['#', 'Amount (EGP)', 'Date', 'Notes'],
        rows: _payments.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final p = entry.value;
          final pDate = p.paymentDate != null ? _formatDate(p.paymentDate!) : 'N/A';
          return ['$i', p.amount.toStringAsFixed(2), pDate, p.notes ?? '—'];
        }).toList(),
      );
    }

    if (_returns.isNotEmpty) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Return Operations',
        headers: ['#', 'Date', 'Returned Amount (EGP)', 'Refund (EGP)', 'Notes'],
        rows: _returns.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final r = entry.value;
          final rDate = r.returnDate != null ? _formatDate(r.returnDate!) : 'N/A';
          return [
            '$i',
            rDate,
            r.returnedAmount.toStringAsFixed(2),
            r.refundAmount.toStringAsFixed(2),
            r.notes ?? '—',
          ];
        }).toList(),
      );
    }

    // Operations Timeline
    final operations = <Map<String, String>>[];
    operations.add({'type': 'Invoice Created', 'date': inv.invoiceDate != null ? _formatDate(inv.invoiceDate!) : 'N/A', 'details': 'Total: ${inv.total.toStringAsFixed(2)} EGP — ${inv.invoiceType.toUpperCase()}'});
    for (final p in _payments) {
      operations.add({'type': 'Payment Received', 'date': p.paymentDate != null ? _formatDate(p.paymentDate!) : 'N/A', 'details': '${p.amount.toStringAsFixed(2)} EGP${p.notes != null && p.notes!.isNotEmpty ? " — ${p.notes}" : ""}'});
    }
    for (final r in _returns) {
      operations.add({'type': 'Return Processed', 'date': r.returnDate != null ? _formatDate(r.returnDate!) : 'N/A', 'details': 'Returned: ${r.returnedAmount.toStringAsFixed(2)} EGP, Refund: ${r.refundAmount.toStringAsFixed(2)} EGP${r.notes != null && r.notes!.isNotEmpty ? " — ${r.notes}" : ""}'});
    }

    if (operations.length > 1) {
      tableHtml += buildTableHtml(
        sectionTitle: 'Operations History',
        headers: ['#', 'Operation', 'Date', 'Details'],
        rows: operations.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final op = entry.value;
          return ['$i', op['type']!, op['date']!, op['details']!];
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

    printReportHtml(title: 'Invoice ${inv.invoiceNumber}', tableHtml: tableHtml);
  }

  void _editInvoice(SalesInvoiceModel inv) {
    final discountController = TextEditingController(text: inv.discount.toStringAsFixed(2));
    final paidController = TextEditingController(text: inv.paid.toStringAsFixed(2));
    String invoiceType = inv.invoiceType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final newDiscount = double.tryParse(discountController.text) ?? 0;
          final newPaid = double.tryParse(paidController.text) ?? 0;
          final newTotal = inv.total + inv.discount - newDiscount;
          final newRemaining = (newTotal - newPaid).clamp(0.0, double.infinity);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: AppColors.warning, size: 22),
                const SizedBox(width: 8),
                Text('Edit ${inv.invoiceNumber}'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Original Total: ${inv.total.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Invoice Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Cash')),
                      ButtonSegment(value: 'credit', label: Text('Credit')),
                      ButtonSegment(value: 'mixed', label: Text('Mixed')),
                    ],
                    selected: {invoiceType},
                    onSelectionChanged: (v) => setDialogState(() => invoiceType = v.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Discount Amount', prefixText: 'EGP '),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Paid Amount', prefixText: 'EGP '),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _editSummaryRow('New Total', '${newTotal.toStringAsFixed(2)} EGP'),
                        _editSummaryRow('New Remaining', '${newRemaining.toStringAsFixed(2)} EGP'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final repo = ref.read(salesRepositoryProvider);
                    await repo.update(inv.invoiceId, {
                      'invoice_type': invoiceType,
                      'discount_amount': newDiscount,
                      'paid_amount': newPaid,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    widget.onPaymentRecorded();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice updated successfully')));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _returnItems(SalesInvoiceModel inv) {
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
      builder: (ctx) => _ReturnItemsDialog(
        items: returnableItems,
        invoice: inv,
        onSubmit: (returnItems, refundAmount, notes) async {
          try {
            final repo = ref.read(salesRepositoryProvider);
            await repo.createReturn(
              inv.invoiceId,
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

  void _cancelInvoice(SalesInvoiceModel inv) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            const Text('Cancel Invoice'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(child: Text('This action will cancel the invoice and reverse any associated inventory and ledger entries. This cannot be undone.', style: TextStyle(fontSize: 12, color: AppColors.error))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Invoice: ${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Customer: ${widget.customerName}', style: const TextStyle(fontSize: 13)),
            Text('Amount: ${inv.total.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'e.g., Customer returned items, wrong order...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Invoice')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide a reason for cancellation')));
                return;
              }
              try {
                final repo = ref.read(salesRepositoryProvider);
                await repo.cancelInvoice(inv.invoiceId, reason: reason);
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onPaymentRecorded();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice ${inv.invoiceNumber} cancelled')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }

  Future<void> _askAi(String question) async {
    setState(() { _aiLoading = true; _aiResponse = null; });
    _tabController.animateTo(1);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final resp = await repo.aiChat(question);
      setState(() => _aiResponse = resp);
    } catch (e) {
      setState(() => _aiResponse = 'Error: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
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
            Text('Remaining: ${invoice.remaining.toStringAsFixed(2)} EGP'),
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
                widget.onPaymentRecorded();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ${amount.toStringAsFixed(2)} EGP recorded successfully'),
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

  Widget _editSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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


class _ReturnItemsDialog extends StatefulWidget {
  final List<InvoiceItemModel> items;
  final SalesInvoiceModel invoice;
  final Future<void> Function(List<Map<String, dynamic>> returnItems, double refundAmount, String? notes) onSubmit;

  const _ReturnItemsDialog({required this.items, required this.invoice, required this.onSubmit});

  @override
  State<_ReturnItemsDialog> createState() => _ReturnItemsDialogState();
}

class _ReturnItemsDialogState extends State<_ReturnItemsDialog> {
  late final List<TextEditingController> _qtyControllers;
  late final List<bool> _selected;
  final _notesController = TextEditingController();
  bool _refundCash = true;
  bool _isLoading = false;
  String? _errorMessage;

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

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  double get _returnTotal {
    double total = 0;
    for (int i = 0; i < widget.items.length; i++) {
      if (_selected[i]) {
        final qty = double.tryParse(_qtyControllers[i].text) ?? 0;
        total += qty * widget.items[i].unitPrice;
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
        final maxQty = widget.items[i].returnableQuantity % 1 == 0
            ? widget.items[i].returnableQuantity.toInt().toString()
            : widget.items[i].returnableQuantity.toStringAsFixed(2);
        final reqQty = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
        setState(() {
          _errorMessage = "Cannot return $reqQty of '${widget.items[i].productName}' — only $maxQty available for return.";
        });
        return;
      }
      final total = qty * widget.items[i].unitPrice;
      returnItems.add({
        'product_id': widget.items[i].productId,
        'returned_quantity': qty,
        'unit_price': widget.items[i].unitPrice,
        'total': total,
      });
    }

    if (returnItems.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one item to return.';
      });
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
                        const Text('Return Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                    ValidationErrorBanner(
                      message: _errorMessage,
                      onDismiss: _clearError,
                    ),
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
                              onChanged: (v) {
                                setState(() => _selected[i] = v ?? false);
                                _clearError();
                              },
                              activeColor: AppColors.warning,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                  Text('Returnable: ${item.returnableQuantity % 1 == 0 ? item.returnableQuantity.toInt() : item.returnableQuantity.toStringAsFixed(2)} ${item.unitType} @ ${item.unitPrice.toStringAsFixed(0)} EGP', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                                  decoration: InputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    suffixText: item.unitType,
                                  ),
                                  onChanged: (_) {
                                    setState(() {});
                                    _clearError();
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Refund cash to customer', style: TextStyle(fontSize: 14)),
                      subtitle: Text(_refundCash ? 'Cash refund: ${_returnTotal.toStringAsFixed(0)} EGP' : 'Credit balance adjustment only'),
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
                          Text('${_returnTotal.toStringAsFixed(0)} EGP', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
