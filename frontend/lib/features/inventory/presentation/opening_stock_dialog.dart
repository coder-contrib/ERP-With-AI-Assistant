import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/data/products_repository.dart';
import '../../products/presentation/products_provider.dart';
import '../data/inventory_repository.dart';
import 'inventory_provider.dart';

class OpeningStockDialog extends ConsumerStatefulWidget {
  const OpeningStockDialog({super.key});

  @override
  ConsumerState<OpeningStockDialog> createState() => _OpeningStockDialogState();
}

class _OpeningStockDialogState extends ConsumerState<OpeningStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_StockLineItem> _lines = [_StockLineItem()];
  bool _isLoading = false;

  void _addLine() {
    setState(() => _lines.add(_StockLineItem()));
  }

  void _removeLine(int index) {
    if (_lines.length > 1) {
      setState(() {
        _lines[index].dispose();
        _lines.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    for (final line in _lines) {
      if (line.selectedProductId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a product for all lines'), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      for (final line in _lines) {
        await repo.createOpeningStock(
          productId: line.selectedProductId!,
          warehouseId: line.selectedWarehouseId,
          quantity: double.tryParse(line.quantityController.text) ?? 0,
          unitType: line.unitType,
          costPerUnit: double.tryParse(line.costController.text) ?? 0,
          notes: line.notesController.text.trim().isEmpty ? null : line.notesController.text.trim(),
        );
      }
      ref.invalidate(inventoryDataProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening stock saved for ${_lines.length} item(s)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text('Opening Stock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_lines.length} line(s)', style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),

            // Info banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.info),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'After saving: inventory increases, cache updates, ledger entries generate, AI is notified, and dashboard refreshes.',
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._lines.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final line = entry.value;
                        return _buildLineItem(idx, line, productsAsync, isDark);
                      }),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Line'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: const Text('Save Opening Stock'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(int index, _StockLineItem line, AsyncValue<List<ProductModel>> productsAsync, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Line ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  onPressed: () => _removeLine(index),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Remove line',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Product & Warehouse
          Row(
            children: [
              Expanded(
                flex: 3,
                child: productsAsync.when(
                  data: (products) => DropdownButtonFormField<int?>(
                    value: line.selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Product *',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      isDense: true,
                    ),
                    items: products.map((p) => DropdownMenuItem(
                      value: p.productId,
                      child: Text(p.productName, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => line.selectedProductId = v),
                    validator: (v) => v == null ? 'Select a product' : null,
                  ),
                  loading: () => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Loading products...')),
                  error: (_, __) => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Error loading products')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: line.selectedWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse *',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Main Warehouse')),
                    DropdownMenuItem(value: 2, child: Text('Secondary Warehouse')),
                  ],
                  onChanged: (v) => setState(() => line.selectedWarehouseId = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity, Unit Type, Cost Price
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    prefixIcon: Icon(Icons.numbers),
                    hintText: '0',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final num = double.tryParse(v.trim());
                    if (num == null || num <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.unitType,
                  decoration: const InputDecoration(
                    labelText: 'Unit Type *',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'meter', child: Text('Meter (m)')),
                    DropdownMenuItem(value: 'piece', child: Text('Piece')),
                    DropdownMenuItem(value: 'carton', child: Text('Carton')),
                  ],
                  onChanged: (v) => setState(() => line.unitType = v ?? 'meter'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: line.costController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price *',
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: '/unit',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: line.notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.note_outlined),
              hintText: 'Optional notes for this line...',
              isDense: true,
            ),
            maxLines: 1,
          ),

          // Total display
          if (line.quantityController.text.isNotEmpty && line.costController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final qty = double.tryParse(line.quantityController.text) ?? 0;
              final cost = double.tryParse(line.costController.text) ?? 0;
              final total = qty * cost;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calculate_outlined, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      'Total Value: ${total.toStringAsFixed(2)} IQD',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StockLineItem {
  int? selectedProductId;
  int selectedWarehouseId = 1;
  String unitType = 'meter';
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    costController.dispose();
    notesController.dispose();
  }
}
