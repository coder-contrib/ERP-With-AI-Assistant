import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/customers_repository.dart';
import 'customers_provider.dart';
import 'customer_form_dialog.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const CustomerFormDialog());
  }

  void _showEditDialog(BuildContext context, CustomerModel customer) {
    showDialog(context: context, builder: (_) => CustomerFormDialog(customer: customer));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Customer'),
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
              child: customersAsync.when(
                loading: () => ListView.builder(
                  itemCount: 8, padding: const EdgeInsets.all(16),
                  itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonLoader(height: 48)),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (customers) {
                  if (customers.isEmpty) {
                    return const EmptyState(icon: Icons.people, title: 'No customers yet');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                    itemBuilder: (_, i) {
                      final c = customers[i];
                      return ListTile(
                        title: Text(c.customerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(c.phoneNumber ?? 'No phone'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${c.currentBalance}', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: double.tryParse(c.currentBalance) != null && double.parse(c.currentBalance) > 0 ? AppColors.warning : AppColors.success,
                            )),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditDialog(context, c),
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
