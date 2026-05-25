import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/print_helper.dart';
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
          _sectionTitle('Invoice Details'),
          const SizedBox(height: 8),
          _infoRow('Type', inv.invoiceType.toUpperCase(), isDark),
          _infoRow('Warehouse', 'Warehouse ${inv.warehouseId}', isDark),
          if (inv.invoiceDate != null) _infoRow('Date', _formatDate(inv.invoiceDate!), isDark),
          _infoRow('Invoice ID', '#${inv.invoiceId}', isDark),
        ],
      ),
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
          _actionTile(Icons.undo, 'Return / Cancel', 'Process return or cancel invoice', AppColors.error, () => _cancelInvoice(inv)),
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
