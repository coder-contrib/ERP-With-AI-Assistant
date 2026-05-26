import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../core/utils/print_helper.dart';
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
          TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Stock'), Tab(text: 'AI Insights'), Tab(text: 'Actions')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: p.activeStatus ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(p.activeStatus ? 'Active' : 'Inactive', style: TextStyle(color: p.activeStatus ? AppColors.success : AppColors.error, fontWeight: FontWeight.w500, fontSize: 12)))]),
                  ]),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: (totalStock <= 0 ? AppColors.error : totalStock <= 10 ? AppColors.warning : AppColors.success).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.inventory_2, color: totalStock <= 0 ? AppColors.error : totalStock <= 10 ? AppColors.warning : AppColors.success),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Stock', style: TextStyle(fontSize: 12)), Text('${totalStock.toStringAsFixed(1)} ${p.baseUnit == 'meter' ? 'm' : 'pcs'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    const Text('By Warehouse', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (stockData.isEmpty) const Text('No stock data available', style: TextStyle(color: AppColors.textSecondary))
                    else ...stockData.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Warehouse #${s.warehouseId}', style: const TextStyle(fontWeight: FontWeight.w500)), Text('${s.quantity.toStringAsFixed(1)} ${p.baseUnit == 'meter' ? 'm' : 'pcs'}', style: const TextStyle(fontWeight: FontWeight.w600))]),
                      ),
                    )),
                  ]),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ask AI about this product', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _AiChip(label: 'Should I order this?', onTap: () => _askAi('Should I reorder product "${p.productName}"? Current stock is $totalStock ${p.baseUnit}.')),
                      _AiChip(label: 'Why is demand dropping?', onTap: () => _askAi('Why might demand be dropping for "${p.productName}"?')),
                      _AiChip(label: 'Best price?', onTap: () => _askAi('What price should I set for "${p.productName}"? Current selling price is \$${p.sellingPrice}, cost is \$${p.purchaseCost}.')),
                      _AiChip(label: 'Compare similar', onTap: () => _askAi('Compare "${p.productName}" with similar products in the same category.')),
                    ]),
                    const SizedBox(height: 16),
                    if (_aiLoading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_aiInsight != null) Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.15))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [Icon(Icons.smart_toy, size: 16, color: AppColors.primary), SizedBox(width: 6), Text('AI Response', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary))]),
                        const SizedBox(height: 8),
                        SelectableText(_aiInsight!, style: const TextStyle(fontSize: 13, height: 1.5)),
                      ]),
                    ),
                  ]),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _ActionButton(icon: Icons.edit, label: 'Edit Product', onTap: widget.onEdit),
                    _ActionButton(icon: Icons.inventory, label: 'Adjust Stock', onTap: () => _adjustStock(p, stockData)),
                    _ActionButton(icon: Icons.swap_horiz, label: 'Transfer to Warehouse', onTap: () => _transferStock(p, stockData)),
                    _ActionButton(icon: Icons.attach_money, label: 'Update Price', onTap: () => _updatePrice(p)),
                    _ActionButton(icon: Icons.analytics, label: 'View Analytics', onTap: () => _viewAnalytics(p)),
                    _ActionButton(
                      icon: p.activeStatus ? Icons.visibility_off : Icons.visibility,
                      label: p.activeStatus ? 'Deactivate Product' : 'Activate Product',
                      onTap: () => _toggleStatus(p),
                    ),
                    _ActionButton(icon: Icons.print, label: 'Print Barcode Label', onTap: () => _printBarcode(p)),
                    _ActionButton(icon: Icons.smart_toy, label: 'Ask AI about this product', onTap: () { _tabController.animateTo(2); }),
                    const SizedBox(height: 16),
                    _ActionButton(icon: Icons.delete, label: 'Delete Product', onTap: () => _deleteProduct(p), color: AppColors.error),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(ProductModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.activeStatus ? 'Deactivate Product?' : 'Activate Product?'),
        content: Text(p.activeStatus
            ? 'This will hide "${p.productName}" from active listings. It can be reactivated later.'
            : 'This will make "${p.productName}" visible in active listings again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: p.activeStatus ? AppColors.warning : AppColors.success),
            child: Text(p.activeStatus ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final repo = ref.read(productsRepositoryProvider);
      await repo.toggleStatus(p.productId);
      invalidateAfterProductChange(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product ${p.activeStatus ? "deactivated" : "activated"} successfully')));
        widget.onClose();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _deleteProduct(ProductModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${p.productName}"? The product will be deactivated and hidden from all listings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final repo = ref.read(productsRepositoryProvider);
      await repo.delete(p.productId);
      invalidateAfterProductChange(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted successfully')));
        widget.onClose();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _printBarcode(ProductModel p) {
    final barcodeValue = p.barcode ?? 'PRD-${p.productId}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.print, color: AppColors.primary, size: 22), SizedBox(width: 8), Text('Print Barcode Label')]),
        content: SizedBox(
          width: 350,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    '||||| $barcodeValue |||||',
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(barcodeValue, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 8),
                Text('Price: \$${p.sellingPrice}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('Click Print to generate a printable label', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              PrintHelper.printBarcode(
                productName: p.productName,
                barcode: barcodeValue,
                price: p.sellingPrice,
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barcode label sent to printer')));
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }

  void _adjustStock(ProductModel p, List<StockInfo> stockData) {
    final qtyController = TextEditingController();
    final costController = TextEditingController(text: p.purchaseCost);
    int warehouseId = stockData.isNotEmpty ? stockData.first.warehouseId : 1;
    String direction = 'IN';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Row(children: [Icon(Icons.inventory, color: AppColors.primary, size: 22), SizedBox(width: 8), Text('Adjust Stock')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'IN', label: Text('Add Stock')), ButtonSegment(value: 'OUT', label: Text('Remove Stock'))], selected: {direction}, onSelectionChanged: (v) => setDialogState(() => direction = v.first)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(value: warehouseId, decoration: const InputDecoration(labelText: 'Warehouse'), items: [1, 2, 3].map((id) => DropdownMenuItem(value: id, child: Text('Warehouse #$id'))).toList(), onChanged: (v) => setDialogState(() => warehouseId = v ?? 1)),
        const SizedBox(height: 12),
        TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity', suffixText: p.baseUnit)),
        const SizedBox(height: 12),
        TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost per unit', prefixText: 'EGP ')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final qty = double.tryParse(qtyController.text); final cost = double.tryParse(costController.text) ?? 0;
          if (qty == null || qty <= 0) return;
          try {
            final repo = ref.read(productsRepositoryProvider);
            await repo.adjustStock(productId: p.productId, warehouseId: warehouseId, quantity: qty, unitType: p.baseUnit, costPerUnit: cost, transactionType: direction == 'IN' ? 'opening_stock' : 'waste');
            if (ctx.mounted) Navigator.pop(ctx);
            ref.invalidate(stockProvider);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock ${direction == "IN" ? "added" : "removed"} successfully')));
          } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'))); }
        }, child: const Text('Confirm')),
      ],
    )));
  }

  void _transferStock(ProductModel p, List<StockInfo> stockData) {
    final qtyController = TextEditingController();
    const warehouses = [1, 2, 3];
    int fromWarehouse = stockData.isNotEmpty ? stockData.first.warehouseId : 1;
    int toWarehouse = warehouses.firstWhere((id) => id != fromWarehouse, orElse: () => 1);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final fromStock = stockData.where((s) => s.warehouseId == fromWarehouse).fold<double>(0, (sum, s) => sum + s.quantity);
      final availableTo = warehouses.where((id) => id != fromWarehouse).toList();
      if (!availableTo.contains(toWarehouse)) {
        toWarehouse = availableTo.first;
      }
      return AlertDialog(
        title: const Row(children: [Icon(Icons.swap_horiz, color: AppColors.primary, size: 22), SizedBox(width: 8), Text('Transfer Stock')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: fromWarehouse,
            decoration: InputDecoration(labelText: 'From Warehouse', helperText: 'Available: ${fromStock.toStringAsFixed(1)} ${p.baseUnit}'),
            items: warehouses.map((id) => DropdownMenuItem(value: id, child: Text('Warehouse #$id'))).toList(),
            onChanged: (v) => setDialogState(() {
              fromWarehouse = v ?? 1;
              if (toWarehouse == fromWarehouse) {
                toWarehouse = warehouses.firstWhere((id) => id != fromWarehouse, orElse: () => 1);
              }
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('to_$fromWarehouse'),
            value: toWarehouse,
            decoration: const InputDecoration(labelText: 'To Warehouse'),
            items: availableTo.map((id) => DropdownMenuItem(value: id, child: Text('Warehouse #$id'))).toList(),
            onChanged: (v) => setDialogState(() => toWarehouse = v ?? availableTo.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity to transfer', suffixText: p.baseUnit)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final qty = double.tryParse(qtyController.text);
            if (qty == null || qty <= 0) return;
            if (qty > fromStock) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Insufficient stock in source warehouse'))); return; }
            if (fromWarehouse == toWarehouse) return;
            final cost = stockData.where((s) => s.warehouseId == fromWarehouse).fold<double>(0, (_, s) => s.avgCost);
            try {
              final repo = ref.read(productsRepositoryProvider);
              await repo.adjustStock(productId: p.productId, warehouseId: fromWarehouse, quantity: qty, unitType: p.baseUnit, costPerUnit: cost, transactionType: 'waste');
              await repo.adjustStock(productId: p.productId, warehouseId: toWarehouse, quantity: qty, unitType: p.baseUnit, costPerUnit: cost, transactionType: 'opening_stock');
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(stockProvider);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transferred ${qty.toStringAsFixed(1)} ${p.baseUnit} from WH#$fromWarehouse to WH#$toWarehouse')));
            } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'))); }
          }, child: const Text('Transfer')),
        ],
      );
    }));
  }

  void _updatePrice(ProductModel p) {
    final sellingController = TextEditingController(text: p.sellingPrice);
    final costController = TextEditingController(text: p.purchaseCost);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final newPrice = double.tryParse(sellingController.text) ?? 0;
      final newCost = double.tryParse(costController.text) ?? 0;
      final margin = newPrice > 0 ? ((newPrice - newCost) / newPrice * 100) : 0.0;
      return AlertDialog(
        title: const Row(children: [Icon(Icons.attach_money, color: AppColors.primary, size: 22), SizedBox(width: 8), Text('Update Price')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase Cost', prefixText: 'EGP '), onChanged: (_) => setDialogState(() {})),
          const SizedBox(height: 12),
          TextField(controller: sellingController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price', prefixText: 'EGP '), onChanged: (_) => setDialogState(() {})),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (margin >= 20 ? AppColors.success : margin >= 10 ? AppColors.warning : AppColors.error).withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Profit Margin:', style: TextStyle(fontSize: 13)), Text('${margin.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w700, color: margin >= 20 ? AppColors.success : margin >= 10 ? AppColors.warning : AppColors.error))])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            try {
              final repo = ref.read(productsRepositoryProvider);
              await repo.update(p.productId, {'selling_price': newPrice, 'purchase_cost_per_meter': newCost});
              if (ctx.mounted) Navigator.pop(ctx);
              invalidateAfterProductChange(ref);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price updated successfully')));
            } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'))); }
          }, child: const Text('Save')),
        ],
      );
    }));
  }

  void _viewAnalytics(ProductModel p) {
    showDialog(context: context, builder: (ctx) => _AnalyticsDialog(product: p, ref: ref));
  }
}

class _AnalyticsDialog extends StatefulWidget {
  final ProductModel product;
  final WidgetRef ref;
  const _AnalyticsDialog({required this.product, required this.ref});
  @override
  State<_AnalyticsDialog> createState() => _AnalyticsDialogState();
}

class _AnalyticsDialogState extends State<_AnalyticsDialog> {
  bool _loading = true;
  Map<String, dynamic>? _forecast;
  String? _error;

  @override
  void initState() { super.initState(); _loadForecast(); }

  Future<void> _loadForecast() async {
    try {
      final repo = widget.ref.read(productsRepositoryProvider);
      final data = await repo.getDemandForecast(widget.product.productId);
      if (mounted) setState(() { _forecast = data; _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [const Icon(Icons.analytics, color: AppColors.primary, size: 22), const SizedBox(width: 8), Expanded(child: Text('Analytics - ${widget.product.productName}', overflow: TextOverflow.ellipsis))]),
      content: SizedBox(width: 400, child: _loading ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())) : _error != null ? Text('Unable to load forecast: $_error', style: const TextStyle(color: AppColors.error)) : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('AI Demand Forecast', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 12),
        if (_forecast != null) ...[
          if (_forecast!['predicted_demand'] != null) _forecastRow('Predicted Demand', '${_forecast!['predicted_demand']} units'),
          if (_forecast!['confidence'] != null) _forecastRow('Confidence', '${((_forecast!['confidence'] as num) * 100).toStringAsFixed(0)}%'),
          if (_forecast!['trend'] != null) _forecastRow('Trend', _forecast!['trend'].toString()),
          if (_forecast!['recommendation'] != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.lightbulb, size: 16, color: AppColors.primary), SizedBox(width: 6), Text('Recommendation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary))]), const SizedBox(height: 6), Text(_forecast!['recommendation'].toString(), style: const TextStyle(fontSize: 13))])),
          ],
          if (_forecast!['response'] != null && _forecast!['predicted_demand'] == null) Text(_forecast!['response'].toString(), style: const TextStyle(fontSize: 13)),
        ],
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  Widget _forecastRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]));
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))]));
  }
}

class _AiChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) { return ActionChip(label: Text(label, style: const TextStyle(fontSize: 12)), avatar: const Icon(Icons.smart_toy, size: 14, color: AppColors.primary), onPressed: onTap); }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(icon, color: c), title: Text(label, style: TextStyle(fontSize: 14, color: color != null ? color : null)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color != null ? color!.withOpacity(0.3) : AppColors.border)), onTap: onTap));
  }
}
