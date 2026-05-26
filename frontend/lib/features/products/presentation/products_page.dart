import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/products_repository.dart';
import 'products_provider.dart';
import 'product_form_dialog.dart';
import 'product_detail_drawer.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  ProductModel? _selectedProduct;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => const ProductFormDialog());
  }

  void _showEditDialog(ProductModel product) {
    showDialog(context: context, builder: (_) => ProductFormDialog(product: product));
  }

  void _openDetail(ProductModel product) {
    setState(() => _selectedProduct = product);
  }

  void _closeDetail() {
    setState(() => _selectedProduct = null);
  }

  void _showAiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AiQueryDialog(ref: ref),
    );
  }

  void _showLowStockAlerts() {
    final stockAsync = ref.read(stockProvider);
    final productsAsync = ref.read(filteredProductsProvider);

    final lowStockItems = <Map<String, dynamic>>[];
    if (stockAsync is AsyncData<List<StockInfo>> && productsAsync is AsyncData<List<ProductModel>>) {
      final products = productsAsync.value!;
      final stocks = stockAsync.value!;

      for (final product in products) {
        final productStocks = stocks.where((s) => s.productId == product.productId).toList();
        final totalQty = productStocks.fold<double>(0, (sum, s) => sum + s.quantity);
        if (totalQty <= 10) {
          lowStockItems.add({'product': product, 'quantity': totalQty});
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            Text('Low Stock Alerts (${lowStockItems.length})'),
          ],
        ),
        content: SizedBox(
          width: 420,
          height: 400,
          child: lowStockItems.isEmpty
              ? const Center(child: Text('All products are well stocked!', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  itemCount: lowStockItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = lowStockItems[i];
                    final product = item['product'] as ProductModel;
                    final qty = item['quantity'] as double;
                    final isOut = qty <= 0;
                    return ListTile(
                      leading: Icon(
                        isOut ? Icons.error : Icons.warning_amber,
                        color: isOut ? AppColors.error : AppColors.warning,
                      ),
                      title: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(
                        isOut ? 'OUT OF STOCK' : '${qty.toStringAsFixed(1)} ${product.baseUnit} remaining',
                        style: TextStyle(fontSize: 12, color: isOut ? AppColors.error : AppColors.warning),
                      ),
                      trailing: Text('EGP ${product.sellingPrice}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpis = ref.watch(productKpisProvider);
    final filteredAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final stockAsync = ref.watch(stockProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final stockFilter = ref.watch(stockFilterProvider);

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: Search + Actions
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, code, or barcode...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Product'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showAiDialog,
                      icon: const Icon(Icons.smart_toy),
                      tooltip: 'Ask AI',
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showLowStockAlerts(),
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Low stock alerts',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // KPI Row
                Row(
                  children: [
                    _KpiChip(icon: Icons.inventory_2, label: '${kpis['total']} Products', color: AppColors.primary),
                    const SizedBox(width: 12),
                    _KpiChip(icon: Icons.check_circle, label: '${kpis['active']} Active', color: AppColors.success),
                    const SizedBox(width: 12),
                    _KpiChip(icon: Icons.warning_amber, label: '${kpis['lowStock']} Low Stock', color: AppColors.warning),
                    const SizedBox(width: 12),
                    _KpiChip(icon: Icons.error_outline, label: '${kpis['outOfStock']} Out of Stock', color: AppColors.error),
                  ],
                ),
                const SizedBox(height: 20),

                // Filters Row
                Row(
                  children: [
                    // Category dropdown
                    SizedBox(
                      width: 180,
                      child: categoriesAsync.when(
                        loading: () => const SkeletonLoader(height: 40),
                        error: (_, __) => const SizedBox(),
                        data: (categories) => DropdownButtonFormField<int?>(
                          value: selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All')),
                            ...categories.map((c) => DropdownMenuItem(value: c.categoryId, child: Text(c.categoryName))),
                          ],
                          onChanged: (v) => ref.read(selectedCategoryProvider.notifier).state = v,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stock filter chips
                    _FilterChip(label: 'All', selected: stockFilter == StockFilter.all, onTap: () => ref.read(stockFilterProvider.notifier).state = StockFilter.all),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'In Stock', selected: stockFilter == StockFilter.inStock, color: AppColors.success, onTap: () => ref.read(stockFilterProvider.notifier).state = StockFilter.inStock),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Low Stock', selected: stockFilter == StockFilter.lowStock, color: AppColors.warning, onTap: () => ref.read(stockFilterProvider.notifier).state = StockFilter.lowStock),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Out of Stock', selected: stockFilter == StockFilter.outOfStock, color: AppColors.error, onTap: () => ref.read(stockFilterProvider.notifier).state = StockFilter.outOfStock),
                  ],
                ),
                const SizedBox(height: 20),

                // Products List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: filteredAsync.when(
                      loading: () => ListView.builder(
                        itemCount: 6,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonLoader(height: 72)),
                      ),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (products) {
                        if (products.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2, size: 64, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
                                const SizedBox(height: 16),
                                Text('No products found', style: TextStyle(fontSize: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final p = products[i];
                            final stockData = stockAsync is AsyncData<List<StockInfo>>
                                ? stockAsync.value!.where((s) => s.productId == p.productId).toList()
                                : <StockInfo>[];
                            final totalStock = stockData.fold<double>(0, (sum, s) => sum + s.quantity);
                            return _ProductCard(
                              product: p,
                              totalStock: totalStock,
                              isSelected: _selectedProduct?.productId == p.productId,
                              isDark: isDark,
                              onTap: () => _openDetail(p),
                              onEdit: () => _showEditDialog(p),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Detail Drawer
        if (_selectedProduct != null)
          ProductDetailDrawer(
            product: _selectedProduct!,
            onClose: _closeDetail,
            onEdit: () => _showEditDialog(_selectedProduct!),
          ),
      ],
    );
  }
}

// --- KPI Chip ---
class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _KpiChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

// --- Filter Chip ---
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? (color ?? AppColors.primary).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? (color ?? AppColors.primary) : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? (color ?? AppColors.primary) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// --- Product Card ---
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final double totalStock;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProductCard({required this.product, required this.totalStock, required this.isSelected, required this.isDark, required this.onTap, required this.onEdit});

  Color get _stockColor {
    if (totalStock <= 0) return AppColors.error;
    if (totalStock <= 10) return AppColors.warning;
    return AppColors.success;
  }

  String get _stockLabel {
    if (totalStock <= 0) return 'Out of Stock';
    if (totalStock <= 10) return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Product icon/image placeholder
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            // Name + unit
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${product.baseUnit}${product.barcode != null ? ' | ${product.barcode}' : ''}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Stock
            SizedBox(
              width: 100,
              child: Column(
                children: [
                  Text('${totalStock.toStringAsFixed(1)} ${product.baseUnit == 'meter' ? 'm' : 'pcs'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _stockColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_stockLabel, style: TextStyle(fontSize: 11, color: _stockColor, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Pricing
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${product.sellingPrice}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Cost: \$${product.purchaseCost} | ${product.profitMargin.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Actions
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit, tooltip: 'Edit'),
          ],
        ),
      ),
    );
  }
}

// --- AI Query Dialog ---
class _AiQueryDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AiQueryDialog({required this.ref});

  @override
  State<_AiQueryDialog> createState() => _AiQueryDialogState();
}

class _AiQueryDialogState extends State<_AiQueryDialog> {
  final _controller = TextEditingController();
  String? _response;
  bool _loading = false;

  final _suggestions = [
    'Best-selling products?',
    'Which products have low stock?',
    'What products have the highest profit margin?',
    'Compare tile categories performance',
  ];

  Future<void> _ask(String question) async {
    setState(() { _loading = true; _response = null; });
    try {
      final repo = widget.ref.read(productsRepositoryProvider);
      final result = await repo.aiChat(question);
      setState(() => _response = result['response']?.toString() ?? 'No response');
    } catch (e) {
      setState(() => _response = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [Icon(Icons.smart_toy, color: AppColors.primary), SizedBox(width: 8), Text('AI Assistant')]),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick questions:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _suggestions.map((q) => ActionChip(
                label: Text(q, style: const TextStyle(fontSize: 12)),
                onPressed: () { _controller.text = q; _ask(q); },
              )).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Ask about products...', border: OutlineInputBorder()),
                    onSubmitted: _ask,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: () => _ask(_controller.text), icon: const Icon(Icons.send, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _response != null
                      ? SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                            child: SelectableText(_response!, style: const TextStyle(fontSize: 13, height: 1.5)),
                          ),
                        )
                      : Center(child: Text('Ask me anything about your products!', style: TextStyle(color: AppColors.textSecondary))),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
