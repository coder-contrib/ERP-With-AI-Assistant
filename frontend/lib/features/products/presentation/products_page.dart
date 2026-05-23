import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'products_provider.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Products', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: const Text('Add Product')),
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
              child: productsAsync.when(
                loading: () => ListView.builder(
                  itemCount: 8,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonLoader(height: 48),
                  ),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (products) {
                  if (products.isEmpty) {
                    return const EmptyState(icon: Icons.inventory_2, title: 'No products yet', description: 'Add your first product to get started.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return ListTile(
                        title: Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('${p.baseUnit} | Cost: \$${p.purchaseCost} | Price: \$${p.sellingPrice}'),
                        trailing: Chip(
                          label: Text(p.activeStatus ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 12)),
                          backgroundColor: p.activeStatus ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                          labelStyle: TextStyle(color: p.activeStatus ? AppColors.success : AppColors.error),
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
