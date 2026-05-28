import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/inventory_repository.dart';
import 'inventory_provider.dart';
import 'inventory_detail_drawer.dart';
import 'opening_stock_dialog.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchController = TextEditingController();
  InventoryItem? _selectedItem;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetail(InventoryItem item) => setState(() => _selectedItem = item);
  void _closeDetail() => setState(() => _selectedItem = null);

  void _showAiDialog() {
    showDialog(context: context, builder: (ctx) => _InventoryAiDialog(ref: ref));
  }

  Future<void> _refreshStock() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.refreshCache();
      invalidateAfterInventoryChange(ref);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock refreshed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showTransferDialog(InventoryItem item) {
    showDialog(context: context, builder: (_) => _TransferDialog(ref: ref, item: item));
  }

  void _showAdjustStockDialog(InventoryItem item) {
    showDialog(context: context, builder: (_) => _AdjustStockDialog(ref: ref, item: item));
  }

  void _showStockHistoryDialog(InventoryItem item) {
    showDialog(context: context, builder: (_) => _StockHistoryDialog(ref: ref, item: item));
  }

  void _showAddStockDialog(InventoryItem item) {
    showDialog(context: context, builder: (_) => _AddStockDialog(ref: ref, item: item));
  }

  void _showDeductStockDialog(InventoryItem item) {
    showDialog(context: context, builder: (_) => _DeductStockDialog(ref: ref, item: item));
  }

  void _showAlertsDialog() {
    showDialog(context: context, builder: (_) => _AlertsDialog(ref: ref));
  }

  void _showOpeningStockDialog() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const OpeningStockDialog(),
    );
    if (result == true) {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.refreshCache();
      invalidateAfterInventoryChange(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = ref.watch(inventoryKpisProvider);
    final filteredAsync = ref.watch(filteredInventoryProvider);
    final warehouses = ref.watch(warehouseListProvider);
    final selectedWarehouse = ref.watch(selectedWarehouseProvider);
    final statusFilter = ref.watch(inventoryStatusFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar - Row 1: Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search product, SKU, or barcode...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (v) => ref.read(inventorySearchProvider.notifier).state = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int?>(
                        value: selectedWarehouse,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Warehouse',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ...warehouses.map((w) => DropdownMenuItem(value: w.warehouseId, child: Text(w.warehouseName))),
                        ],
                        onChanged: (v) => ref.read(selectedWarehouseProvider.notifier).state = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Top Bar - Row 2: Actions
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showOpeningStockDialog,
                      icon: const Icon(Icons.inventory_2, size: 18),
                      label: const Text('Opening Stock'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showAiDialog,
                      icon: const Icon(Icons.smart_toy, size: 18),
                      label: const Text('Ask AI'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _refreshStock,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh stock',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _showAlertsDialog,
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Alerts',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // KPI Row
                Row(
                  children: [
                    _KpiCard(icon: Icons.attach_money, label: '\$${_formatNumber(kpis['totalValue'])}', subtitle: 'Total Value', color: AppColors.primary),
                    const SizedBox(width: 12),
                    _KpiCard(icon: Icons.check_circle, label: '${kpis['inStock']}', subtitle: 'In Stock', color: AppColors.success),
                    const SizedBox(width: 12),
                    _KpiCard(icon: Icons.warning_amber, label: '${kpis['lowStock']}', subtitle: 'Low Stock', color: AppColors.warning),
                    const SizedBox(width: 12),
                    _KpiCard(icon: Icons.error_outline, label: '${kpis['outOfStock']}', subtitle: 'Out of Stock', color: AppColors.error),
                  ],
                ),
                const SizedBox(height: 16),

                // AI Insight Panel
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.05), AppColors.info.withOpacity(0.03)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.smart_toy, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          kpis['outOfStock'] > 0
                              ? '${kpis['outOfStock']} products are out of stock. ${kpis['lowStock']} items running low.'
                              : kpis['lowStock'] > 0
                                  ? '${kpis['lowStock']} products running low on stock. Consider reordering soon.'
                                  : 'All inventory levels looking healthy!',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAiDialog,
                        icon: const Icon(Icons.smart_toy, size: 16),
                        label: const Text('Ask AI', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(label: 'All', selected: statusFilter == null, onTap: () => ref.read(inventoryStatusFilterProvider.notifier).state = null),
                      const SizedBox(width: 8),
                      _StatusChip(label: 'In Stock', selected: statusFilter == StockStatus.normal, color: AppColors.success, onTap: () => ref.read(inventoryStatusFilterProvider.notifier).state = StockStatus.normal),
                      const SizedBox(width: 8),
                      _StatusChip(label: 'Low Stock', selected: statusFilter == StockStatus.low, color: AppColors.warning, onTap: () => ref.read(inventoryStatusFilterProvider.notifier).state = StockStatus.low),
                      const SizedBox(width: 8),
                      _StatusChip(label: 'Out of Stock', selected: statusFilter == StockStatus.outOfStock, color: AppColors.error, onTap: () => ref.read(inventoryStatusFilterProvider.notifier).state = StockStatus.outOfStock),
                      const SizedBox(width: 8),
                      _StatusChip(label: 'Overstock', selected: statusFilter == StockStatus.overstock, color: AppColors.info, onTap: () => ref.read(inventoryStatusFilterProvider.notifier).state = StockStatus.overstock),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Inventory List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: filteredAsync.when(
                      loading: () => ListView.builder(
                        itemCount: 6, padding: const EdgeInsets.all(16),
                        itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonLoader(height: 80)),
                      ),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (items) {
                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory, size: 64, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
                                const SizedBox(height: 16),
                                Text('No inventory items found', style: TextStyle(fontSize: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            return _InventoryCard(
                              item: item,
                              isSelected: _selectedItem?.productId == item.productId,
                              isDark: isDark,
                              onTap: () => _openDetail(item),
                              onTransfer: () => _showTransferDialog(item),
                              onAdjust: () => _showAdjustStockDialog(item),
                              onHistory: () => _showStockHistoryDialog(item),
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
        if (_selectedItem != null)
          InventoryDetailDrawer(
            item: _selectedItem!,
            onClose: _closeDetail,
            onTransfer: () => _showTransferDialog(_selectedItem!),
            onAddStock: () => _showAddStockDialog(_selectedItem!),
            onDeductStock: () => _showDeductStockDialog(_selectedItem!),
            onViewHistory: () => _showStockHistoryDialog(_selectedItem!),
          ),
      ],
    );
  }

  String _formatNumber(dynamic value) {
    final n = (value is num) ? value.toDouble() : 0.0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

// --- KPI Card ---
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  const _KpiCard({required this.icon, required this.label, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Status Chip ---
class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? c : AppColors.textSecondary)),
      ),
    );
  }
}

// --- Inventory Card ---
class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onTransfer;
  final VoidCallback onAdjust;
  final VoidCallback onHistory;
  const _InventoryCard({required this.item, required this.isSelected, required this.isDark, required this.onTap, required this.onTransfer, required this.onAdjust, required this.onHistory});

  Color get _statusColor {
    switch (item.status) {
      case StockStatus.outOfStock: return AppColors.error;
      case StockStatus.low: return AppColors.warning;
      case StockStatus.overstock: return AppColors.info;
      case StockStatus.normal: return AppColors.success;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case StockStatus.outOfStock: return 'Out of Stock';
      case StockStatus.low: return 'Low Stock';
      case StockStatus.overstock: return 'Overstock';
      case StockStatus.normal: return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = item.baseUnit == 'meter' ? 'm²' : 'pcs';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.04) : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(width: 4, height: 50, decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(item.barcode ?? 'No barcode', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${item.totalStock.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(_statusLabel, style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${item.totalValue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Value', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (action) {
                switch (action) {
                  case 'transfer': onTransfer(); break;
                  case 'adjust': onAdjust(); break;
                  case 'history': onHistory(); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'transfer', child: Row(children: [Icon(Icons.swap_horiz, size: 18), SizedBox(width: 8), Text('Transfer')])),
                const PopupMenuItem(value: 'adjust', child: Row(children: [Icon(Icons.tune, size: 18), SizedBox(width: 8), Text('Adjust Stock')])),
                const PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text('View History')])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Transfer Dialog ---
class _TransferDialog extends StatefulWidget {
  final WidgetRef ref;
  final InventoryItem item;
  const _TransferDialog({required this.ref, required this.item});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  int? _fromWarehouse;
  int? _toWarehouse;
  final _qtyController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.ref.read(warehouseListProvider);
    return AlertDialog(
      title: Text('Transfer: ${widget.item.productName}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _fromWarehouse,
              decoration: const InputDecoration(labelText: 'From Warehouse'),
              items: warehouses.map((w) => DropdownMenuItem(value: w.warehouseId, child: Text(w.warehouseName))).toList(),
              onChanged: (v) => setState(() => _fromWarehouse = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _toWarehouse,
              decoration: const InputDecoration(labelText: 'To Warehouse'),
              items: warehouses.map((w) => DropdownMenuItem(value: w.warehouseId, child: Text(w.warehouseName))).toList(),
              onChanged: (v) => setState(() => _toWarehouse = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyController,
              decoration: InputDecoration(labelText: 'Quantity (${widget.item.baseUnit})'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : () async {
            if (_fromWarehouse == null || _toWarehouse == null || _qtyController.text.isEmpty) return;
            if (_fromWarehouse == _toWarehouse) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and destination must be different'), backgroundColor: Colors.orange));
              return;
            }
            setState(() => _loading = true);
            try {
              final repo = widget.ref.read(inventoryRepositoryProvider);
              await repo.createTransfer(
                fromWarehouseId: _fromWarehouse!,
                toWarehouseId: _toWarehouse!,
                productId: widget.item.productId,
                quantity: double.parse(_qtyController.text),
                unitType: widget.item.baseUnit,
              );
              await repo.refreshCache();
              invalidateAfterInventoryChange(widget.ref);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer completed successfully'), backgroundColor: Colors.green));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Transfer'),
        ),
      ],
    );
  }
}

// --- Adjust Stock Dialog ---
class _AdjustStockDialog extends StatefulWidget {
  final WidgetRef ref;
  final InventoryItem item;
  const _AdjustStockDialog({required this.ref, required this.item});

  @override
  State<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<_AdjustStockDialog> {
  int? _warehouse;
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  String _direction = 'in';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.ref.read(warehouseListProvider);
    return AlertDialog(
      title: Text('Adjust Stock: ${widget.item.productName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'in', label: Text('Add Stock'), icon: Icon(Icons.add_circle_outline)),
                ButtonSegment(value: 'out', label: Text('Deduct Stock'), icon: Icon(Icons.remove_circle_outline)),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _warehouse,
              decoration: const InputDecoration(labelText: 'Warehouse'),
              items: warehouses.map((w) => DropdownMenuItem(value: w.warehouseId, child: Text(w.warehouseName))).toList(),
              onChanged: (v) => setState(() => _warehouse = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyController,
              decoration: InputDecoration(labelText: 'Quantity (${widget.item.baseUnit})'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason / Notes'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _direction == 'out' ? AppColors.error : AppColors.success),
          onPressed: _loading ? null : () async {
            if (_warehouse == null || _qtyController.text.isEmpty) return;
            setState(() => _loading = true);
            try {
              final repo = widget.ref.read(inventoryRepositoryProvider);
              await repo.adjustStock(
                productId: widget.item.productId,
                warehouseId: _warehouse!,
                quantity: double.parse(_qtyController.text),
                direction: _direction,
                unitType: widget.item.baseUnit,
                reason: _reasonController.text.isEmpty ? null : _reasonController.text,
              );
              await repo.refreshCache();
              invalidateAfterInventoryChange(widget.ref);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_direction == 'in' ? 'Stock added successfully' : 'Stock deducted successfully'),
                  backgroundColor: Colors.green,
                ));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_direction == 'in' ? 'Add Stock' : 'Deduct Stock'),
        ),
      ],
    );
  }
}

// --- Add Stock Dialog ---
class _AddStockDialog extends StatefulWidget {
  final WidgetRef ref;
  final InventoryItem item;
  const _AddStockDialog({required this.ref, required this.item});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  int? _warehouse;
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.ref.read(warehouseListProvider);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_circle, color: AppColors.success),
          const SizedBox(width: 8),
          Text('Add Stock: ${widget.item.productName}'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _warehouse,
              decoration: const InputDecoration(labelText: 'Warehouse *'),
              items: warehouses.map((w) => DropdownMenuItem(value: w.warehouseId, child: Text(w.warehouseName))).toList(),
              onChanged: (v) => setState(() => _warehouse = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyController,
              decoration: InputDecoration(labelText: 'Quantity (${widget.item.baseUnit}) *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costController,
              decoration: const InputDecoration(labelText: 'Cost per unit (EGP)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: _loading ? null : () async {
            if (_warehouse == null || _qtyController.text.isEmpty) return;
            setState(() => _loading = true);
            try {
              final repo = widget.ref.read(inventoryRepositoryProvider);
              await repo.adjustStock(
                productId: widget.item.productId,
                warehouseId: _warehouse!,
                quantity: double.parse(_qtyController.text),
                direction: 'in',
                unitType: widget.item.baseUnit,
                costPerUnit: double.tryParse(_costController.text) ?? 0,
                reason: _notesController.text.isEmpty ? null : _notesController.text,
              );
              await repo.refreshCache();
              invalidateAfterInventoryChange(widget.ref);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock added successfully'), backgroundColor: Colors.green));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          label: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add Stock'),
        ),
      ],
    );
  }
}

// --- Deduct Stock Dialog ---
class _DeductStockDialog extends StatefulWidget {
  final WidgetRef ref;
  final InventoryItem item;
  const _DeductStockDialog({required this.ref, required this.item});

  @override
  State<_DeductStockDialog> createState() => _DeductStockDialogState();
}

class _DeductStockDialogState extends State<_DeductStockDialog> {
  int? _warehouse;
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.ref.read(warehouseListProvider);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.remove_circle, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text('Deduct Stock: ${widget.item.productName}')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Current stock: ${widget.item.totalStock.toStringAsFixed(1)} ${widget.item.baseUnit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _warehouse,
              decoration: const InputDecoration(labelText: 'From Warehouse *'),
              items: warehouses.map((w) => DropdownMenuItem(value: w.warehouseId, child: Text(w.warehouseName))).toList(),
              onChanged: (v) => setState(() => _warehouse = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyController,
              decoration: InputDecoration(labelText: 'Quantity to deduct (${widget.item.baseUnit}) *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason (waste, damage, correction) *'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: const Icon(Icons.remove, size: 18),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _loading ? null : () async {
            if (_warehouse == null || _qtyController.text.isEmpty || _reasonController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.orange));
              return;
            }
            setState(() => _loading = true);
            try {
              final repo = widget.ref.read(inventoryRepositoryProvider);
              await repo.adjustStock(
                productId: widget.item.productId,
                warehouseId: _warehouse!,
                quantity: double.parse(_qtyController.text),
                direction: 'out',
                unitType: widget.item.baseUnit,
                reason: _reasonController.text,
              );
              await repo.refreshCache();
              invalidateAfterInventoryChange(widget.ref);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock deducted successfully'), backgroundColor: Colors.green));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          label: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Deduct Stock'),
        ),
      ],
    );
  }
}

// --- Stock History Dialog ---
class _StockHistoryDialog extends StatefulWidget {
  final WidgetRef ref;
  final InventoryItem item;
  const _StockHistoryDialog({required this.ref, required this.item});

  @override
  State<_StockHistoryDialog> createState() => _StockHistoryDialogState();
}

class _StockHistoryDialogState extends State<_StockHistoryDialog> {
  List<Map<String, dynamic>>? _transactions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final repo = widget.ref.read(inventoryRepositoryProvider);
      final result = await repo.getStockHistory(widget.item.productId);
      if (mounted) setState(() { _transactions = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error loading history: $e'; _loading = false; });
    }
  }

  Color _directionColor(String direction) {
    return direction.toUpperCase() == 'IN' ? AppColors.success : AppColors.error;
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sale': return Icons.shopping_cart;
      case 'purchase': return Icons.add_shopping_cart;
      case 'opening_stock': return Icons.inventory_2;
      case 'waste': return Icons.delete_outline;
      case 'warehouse_transfer': return Icons.swap_horiz;
      case 'sales_return': return Icons.assignment_return;
      case 'purchase_return': return Icons.assignment_return_outlined;
      default: return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('History: ${widget.item.productName}', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 550,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                : _transactions == null || _transactions!.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 48, color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text('No transaction history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(height: 4),
                            Text('Transactions will appear here once recorded', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _transactions!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final tx = _transactions![i];
                          final type = tx['transaction_type']?.toString() ?? '';
                          final direction = tx['direction']?.toString() ?? '';
                          final quantity = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0;
                          final unitType = tx['unit_type']?.toString() ?? '';
                          final costPerUnit = double.tryParse(tx['cost_per_unit']?.toString() ?? '0') ?? 0;
                          final notes = tx['notes']?.toString() ?? '';
                          final createdDate = tx['created_date']?.toString() ?? '';
                          final displayDate = createdDate.length > 16 ? createdDate.substring(0, 16).replaceFirst('T', ' ') : createdDate;

                          return ListTile(
                            leading: Icon(_typeIcon(type), color: _directionColor(direction)),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _directionColor(direction).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    direction.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _directionColor(direction)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text('${quantity.toStringAsFixed(2)} $unitType', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(displayDate, style: const TextStyle(fontSize: 11)),
                                    if (costPerUnit > 0) ...[
                                      const Spacer(),
                                      Text('@ \$${costPerUnit.toStringAsFixed(2)}/unit', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ],
                                ),
                                if (notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(notes, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                            ),
                            dense: true,
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

// --- Alerts Dialog ---
class _AlertsDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AlertsDialog({required this.ref});

  @override
  State<_AlertsDialog> createState() => _AlertsDialogState();
}

class _AlertsDialogState extends State<_AlertsDialog> {
  List<Map<String, dynamic>>? _alerts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final repo = widget.ref.read(inventoryRepositoryProvider);
      final alerts = await repo.getNotifications(unreadOnly: true);
      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _alerts = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: AppColors.warning),
          SizedBox(width: 8),
          Text('Inventory Alerts'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _alerts == null || _alerts!.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 48, color: AppColors.success),
                        SizedBox(height: 12),
                        Text('No active alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text('All inventory levels are within normal range', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _alerts!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final alert = _alerts![i];
                      final type = alert['notification_type']?.toString() ?? '';
                      final message = alert['message']?.toString() ?? '';
                      final createdAt = alert['created_at']?.toString() ?? '';

                      IconData icon;
                      Color color;
                      if (type.contains('low_stock')) {
                        icon = Icons.warning_amber;
                        color = AppColors.warning;
                      } else if (type.contains('out_of_stock')) {
                        icon = Icons.error_outline;
                        color = AppColors.error;
                      } else if (type.contains('credit')) {
                        icon = Icons.credit_card;
                        color = AppColors.info;
                      } else {
                        icon = Icons.info_outline;
                        color = AppColors.textSecondary;
                      }

                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(message, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt, style: const TextStyle(fontSize: 11)),
                        dense: true,
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

// --- AI Dialog ---
class _InventoryAiDialog extends StatefulWidget {
  final WidgetRef ref;
  const _InventoryAiDialog({required this.ref});

  @override
  State<_InventoryAiDialog> createState() => _InventoryAiDialogState();
}

class _InventoryAiDialogState extends State<_InventoryAiDialog> {
  final _controller = TextEditingController();
  String? _response;
  bool _loading = false;

  final _suggestions = [
    'Why is stock dropping fast?',
    'What should I order this week?',
    'Which products are dead stock?',
    'How many days until stockout?',
    'Which warehouse is overstocked?',
  ];

  Future<void> _ask(String q) async {
    setState(() { _loading = true; _response = null; });
    try {
      final repo = widget.ref.read(inventoryRepositoryProvider);
      final result = await repo.aiChat(q);
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
      title: const Row(children: [Icon(Icons.smart_toy, color: AppColors.primary), SizedBox(width: 8), Text('Inventory AI')]),
      content: SizedBox(
        width: 500, height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _suggestions.map((q) => ActionChip(label: Text(q, style: const TextStyle(fontSize: 12)), onPressed: () { _controller.text = q; _ask(q); })).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Ask about inventory...', border: OutlineInputBorder()), onSubmitted: _ask)),
                const SizedBox(width: 8),
                IconButton(onPressed: () => _ask(_controller.text), icon: const Icon(Icons.send, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _response != null
                      ? SingleChildScrollView(child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                          child: SelectableText(_response!, style: const TextStyle(fontSize: 13, height: 1.5)),
                        ))
                      : const Center(child: Text('Ask me anything about your inventory!', style: TextStyle(color: AppColors.textSecondary))),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
