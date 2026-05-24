import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import 'inventory_provider.dart';

class InventoryDetailDrawer extends ConsumerStatefulWidget {
  final InventoryItem item;
  final VoidCallback onClose;
  final VoidCallback onTransfer;

  const InventoryDetailDrawer({super.key, required this.item, required this.onClose, required this.onTransfer});

  @override
  ConsumerState<InventoryDetailDrawer> createState() => _InventoryDetailDrawerState();
}

class _InventoryDetailDrawerState extends ConsumerState<InventoryDetailDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _aiInsight;
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

  Future<void> _askAi(String question) async {
    setState(() { _aiLoading = true; _aiInsight = null; });
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final result = await repo.aiChat(question);
      setState(() => _aiInsight = result['response']?.toString());
    } catch (e) {
      setState(() => _aiInsight = 'Error: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final unit = item.baseUnit == 'meter' ? 'm²' : 'pcs';

    Color statusColor;
    String statusLabel;
    switch (item.status) {
      case StockStatus.outOfStock: statusColor = AppColors.error; statusLabel = 'Out of Stock'; break;
      case StockStatus.low: statusColor = AppColors.warning; statusLabel = 'Low Stock'; break;
      case StockStatus.overstock: statusColor = AppColors.info; statusLabel = 'Overstock'; break;
      case StockStatus.normal: statusColor = AppColors.success; statusLabel = 'Normal'; break;
    }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onClose),
                  ],
                ),
                const SizedBox(height: 8),
                // Stock summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: statusColor),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.totalStock.toStringAsFixed(1)} $unit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: statusColor)),
                          Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${item.totalValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const Text('Total Value', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Warehouses'), Tab(text: 'AI Insights'), Tab(text: 'Actions')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Warehouses Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stock by Warehouse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      if (item.warehouseStocks.isEmpty)
                        const Text('No stock data', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...item.warehouseStocks.map((ws) {
                          final pct = item.totalStock > 0 ? ws.quantity / item.totalStock : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Warehouse #${ws.warehouseId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text('${ws.quantity.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor: AppColors.border,
                                      valueColor: AlwaysStoppedAnimation(pct > 0.7 ? AppColors.success : pct > 0.3 ? AppColors.warning : AppColors.error),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Avg cost: \$${ws.avgCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text('${(pct * 100).toStringAsFixed(0)}% of total', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                // AI Insights Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ask AI about this item', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _AiChip(label: 'Days until stockout?', onTap: () => _askAi('How many days until "${item.productName}" runs out of stock? Current stock: ${item.totalStock} ${item.baseUnit}.')),
                          _AiChip(label: 'Should I reorder?', onTap: () => _askAi('Should I reorder "${item.productName}"? Stock: ${item.totalStock} ${item.baseUnit}.')),
                          _AiChip(label: 'Is it dead stock?', onTap: () => _askAi('Is "${item.productName}" dead stock? Analyze its movement pattern.')),
                          _AiChip(label: 'Optimal stock level?', onTap: () => _askAi('What is the optimal stock level for "${item.productName}"?')),
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
                              const Row(children: [Icon(Icons.smart_toy, size: 16, color: AppColors.primary), SizedBox(width: 6), Text('AI Response', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary))]),
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
                      _ActionTile(icon: Icons.add_circle, label: 'Add Stock (Purchase)', color: AppColors.success, onTap: () {}),
                      _ActionTile(icon: Icons.remove_circle, label: 'Deduct Stock (Waste/Correction)', color: AppColors.error, onTap: () {}),
                      _ActionTile(icon: Icons.swap_horiz, label: 'Transfer Between Warehouses', color: AppColors.info, onTap: widget.onTransfer),
                      _ActionTile(icon: Icons.history, label: 'View Transaction History', color: AppColors.textSecondary, onTap: () {}),
                      _ActionTile(icon: Icons.smart_toy, label: 'AI Analysis', color: AppColors.primary, onTap: () => _tabController.animateTo(1)),
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

class _AiChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      avatar: const Icon(Icons.smart_toy, size: 14, color: AppColors.primary),
      onPressed: onTap,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
        onTap: onTap,
      ),
    );
  }
}
