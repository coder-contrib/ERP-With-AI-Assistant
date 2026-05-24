import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/suppliers_repository.dart';
import 'suppliers_provider.dart';
import 'supplier_form_dialog.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const SupplierFormDialog());
  }

  void _showEditDialog(BuildContext context, SupplierModel supplier) {
    showDialog(context: context, builder: (_) => SupplierFormDialog(supplier: supplier));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Suppliers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: suppliersAsync.when(
                loading: () => ListView.builder(
                  itemCount: 8, padding: const EdgeInsets.all(16),
                  itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonLoader(height: 48)),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (suppliers) {
                  if (suppliers.isEmpty) {
                    return const EmptyState(icon: Icons.local_shipping, title: 'No suppliers yet');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: suppliers.length,
                    separatorBuilder: (_, __) => Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                    itemBuilder: (_, i) {
                      final s = suppliers[i];
                      return ListTile(
                        title: Text(s.supplierName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(s.phoneNumber ?? 'No phone'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${s.currentBalance}', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: double.tryParse(s.currentBalance) != null && double.parse(s.currentBalance) > 0 ? AppColors.error : AppColors.success,
                            )),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditDialog(context, s),
                              tooltip: 'Edit',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
