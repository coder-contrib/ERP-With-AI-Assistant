import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/products_repository.dart';
import 'products_provider.dart';

class ProductDetailDrawer extends ConsumerStatefulWidget {
  final ProductModel product;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const ProductDetailDrawer({super.key, required this.product, required this.onClose, required this.onEdit});

  @override
  ConsumerState<ProductDetailDrawer> createState() => _ProductDetailDrawerState();
}

class _ProductDetailDrawerState extends ConsumerState<ProductDetailDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _aiInsight;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _askAi(String question) async {
    setState(() { _aiLoading = true; _aiInsight = null; });
    try {
      final repo = ref.read(productsRepositoryProvider);
      final result = await repo.aiChat(question);
      setState(() => _aiInsight = result['response']?.toString() ?? 'No insight available');
    } catch (e) {
      setState(() => _aiInsight = 'Error: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;
    final stockAsync = ref.watch(stockProvider);
    final stockData = stockAsync is AsyncData<List<StockInfo>>
        ? stockAsync.value!.where((s) => s.productId == p.productId).toList()
        : <StockInfo>[];
    final totalStock = stockData.fold<double>(0, (sum, s) => sum + s.quantity);

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(left: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border))),
            child: Row(
              children: [
                Expanded(child: Text(p.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: widget.onEdit, tooltip: 'Edit'),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onClose),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Stock'),
              Tab(text: 'AI Insights'),
              Tab(text: 'Actions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Overview Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Product ID', value: '#${p.productId}'),
                      _InfoRow(label: 'Base Unit', value: p.baseUnit),
                      _InfoRow(label: 'Barcode', value: p.barcode ?? 'N/A'),
                      _InfoRow(label: 'Meter-based', value: p.isMeterBased ? 'Yes' : 'No'),
                      _InfoRow(label: 'Piece sale allowed', value: p.allowPieceSale ? 'Yes' : 'No'),
                      const Divider(height: 24),
                      const Text('Pricing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _InfoRow(label: 'Purchase Cost', value: '\$${p.purchaseCost}'),
                      _InfoRow(label: 'Selling Price', value: '\$${p.sellingPrice}'),
                      _InfoRow(label: 'Profit Margin', value: '${p.profitMargin.toStringAsFixed(1)}%'),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.activeStatus ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              p.activeStatus ? 'Active' : 'Inactive',
                              style: TextStyle(color: p.activeStatus ? AppColors.success : AppColors.error, fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stock Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (totalStock <= 0 ? AppColors.error : totalStock <= 10 ? AppColors.warning : AppColors.success).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2, color: totalStock <= 0 ? AppColors.error : totalStock <= 10 ? AppColors.warning : AppColors.success),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Stock', style: TextStyle(fontSize: 12)),
                                Text('${totalStock.toStringAsFixed(1)} ${p.baseUnit == 'meter' ? 'm²' : 'pcs'}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('By Warehouse', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (stockData.isEmpty)
                        const Text('No stock data available', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...stockData.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Warehouse #${s.warehouseId}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${s.quantity.toStringAsFixed(1)} ${p.baseUnit == 'meter' ? 'm²' : 'pcs'}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        )),
                    ],
                  ),
                ),
                // AI Insights Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ask AI about this product', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _AiChip(label: 'Should I order this?', onTap: () => _askAi('Should I reorder product "${p.productName}"? Current stock is $totalStock ${p.baseUnit}.')),
                          _AiChip(label: 'Why is demand dropping?', onTap: () => _askAi('Why might demand be dropping for "${p.productName}"?')),
                          _AiChip(label: 'Best price?', onTap: () => _askAi('What price should I set for "${p.productName}"? Current selling price is \$${p.sellingPrice}, cost is \$${p.purchaseCost}.')),
                          _AiChip(label: 'Compare similar', onTap: () => _askAi('Compare "${p.productName}" with similar products in the same category.')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_aiLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_aiInsight != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.smart_toy, size: 16, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text('AI Response', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(_aiInsight!, style: const TextStyle(fontSize: 13, height: 1.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Actions Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ActionButton(icon: Icons.edit, label: 'Edit Product', onTap: widget.onEdit),
                      _ActionButton(icon: Icons.inventory, label: 'Adjust Stock', onTap: () {}),
                      _ActionButton(icon: Icons.swap_horiz, label: 'Transfer to Warehouse', onTap: () {}),
                      _ActionButton(icon: Icons.attach_money, label: 'Update Price', onTap: () {}),
                      _ActionButton(icon: Icons.analytics, label: 'View Analytics', onTap: () {}),
                      _ActionButton(icon: Icons.smart_toy, label: 'Ask AI about this product', onTap: () {
                        _tabController.animateTo(2);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.smart_toy, size: 14, color: AppColors.primary),
      onPressed: onTap,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
        onTap: onTap,
      ),
    );
  }
}
