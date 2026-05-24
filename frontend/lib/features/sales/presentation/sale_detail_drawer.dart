import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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
          _actionTile(Icons.print, 'Print Invoice', 'Generate PDF invoice', AppColors.info, () {}),
          _actionTile(Icons.edit, 'Edit Invoice', 'Modify invoice details', AppColors.warning, () {}),
          _actionTile(Icons.undo, 'Return / Cancel', 'Process return or cancel invoice', AppColors.error, () {}),
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

  Future<void> _askAi(String question) async {
    setState(() { _aiLoading = true; _aiResponse = null; });
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
