import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/purchases_repository.dart';
import '../../suppliers/data/suppliers_repository.dart';
import 'purchases_provider.dart';
import 'create_purchase_dialog.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPurchases = ref.watch(filteredPurchasesProvider);
    final kpis = ref.watch(purchaseKpisProvider);
    final statusFilter = ref.watch(purchasesStatusFilterProvider);
    final suppliersAsync = ref.watch(purchasesSuppliersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final supplierMap = <int, String>{};
    if (suppliersAsync is AsyncData<List<SupplierModel>>) {
      for (final s in suppliersAsync.value!) {
        supplierMap[s.supplierId] = s.supplierName;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('Purchases', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (_) => const CreatePurchaseDialog(),
                  );
                  if (result == true) ref.invalidate(purchasesProvider);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Purchase'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPIs
          Row(
            children: [
              _KpiCard(title: 'Total Purchases', value: '${(kpis['totalPurchases'] as double).toStringAsFixed(0)} IQD', icon: Icons.receipt_long, color: AppColors.primary),
              const SizedBox(width: 12),
              _KpiCard(title: 'Total Paid', value: '${(kpis['totalPaid'] as double).toStringAsFixed(0)} IQD', icon: Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: 12),
              _KpiCard(title: 'Total Unpaid', value: '${(kpis['totalUnpaid'] as double).toStringAsFixed(0)} IQD', icon: Icons.warning_amber, color: AppColors.error),
              const SizedBox(width: 12),
              _KpiCard(title: 'Invoices', value: '${kpis['invoiceCount']}', icon: Icons.description_outlined, color: AppColors.info),
            ],
          ),
          const SizedBox(height: 20),

          // Search & Filters
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by invoice number or supplier...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(purchasesSearchProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => ref.read(purchasesSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 16),
              _FilterChip(
                label: 'All',
                selected: statusFilter == PurchaseStatusFilter.all,
                onTap: () => ref.read(purchasesStatusFilterProvider.notifier).state = PurchaseStatusFilter.all,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Paid',
                selected: statusFilter == PurchaseStatusFilter.paid,
                color: AppColors.success,
                onTap: () => ref.read(purchasesStatusFilterProvider.notifier).state = PurchaseStatusFilter.paid,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Partial',
                selected: statusFilter == PurchaseStatusFilter.partial,
                color: AppColors.warning,
                onTap: () => ref.read(purchasesStatusFilterProvider.notifier).state = PurchaseStatusFilter.partial,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Unpaid',
                selected: statusFilter == PurchaseStatusFilter.unpaid,
                color: AppColors.error,
                onTap: () => ref.read(purchasesStatusFilterProvider.notifier).state = PurchaseStatusFilter.unpaid,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Invoice List
          Expanded(
            child: filteredPurchases.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (purchases) {
                if (purchases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text('No purchase invoices found', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: purchases.length,
                  itemBuilder: (context, index) {
                    final invoice = purchases[index];
                    final supplierName = supplierMap[invoice.supplierId] ?? 'Unknown Supplier';
                    return _InvoiceCard(
                      invoice: invoice,
                      supplierName: supplierName,
                      isDark: isDark,
                      onRecordPayment: () => _showPaymentDialog(invoice),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(PurchaseInvoiceModel invoice) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice: ${invoice.invoiceNumber}'),
              Text('Remaining: ${invoice.remainingAmount} IQD'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: 'IQD',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = amountController.text.trim();
              if (amount.isEmpty) return;
              try {
                final repo = ref.read(purchasesRepositoryProvider);
                await repo.recordPayment(invoice.supplierId, {
                  'related_invoice_id': invoice.purchaseInvoiceId,
                  'payment_amount': amount,
                });
                ref.invalidate(purchasesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? chipColor : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? chipColor : null,
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final PurchaseInvoiceModel invoice;
  final String supplierName;
  final bool isDark;
  final VoidCallback onRecordPayment;

  const _InvoiceCard({required this.invoice, required this.supplierName, required this.isDark, required this.onRecordPayment});

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.isPaid ? AppColors.success : invoice.isPartial ? AppColors.warning : AppColors.error;
    final statusLabel = invoice.isPaid ? 'Paid' : invoice.isPartial ? 'Partial' : 'Unpaid';
    final progress = invoice.total > 0 ? invoice.paid / invoice.total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(supplierName, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${invoice.totalAmount} IQD', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: statusColor.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    if (!invoice.isPaid)
                      IconButton(
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.payments_outlined, size: 20),
                        tooltip: 'Record Payment',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
