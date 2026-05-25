import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_refresh.dart';
import '../data/purchases_repository.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../../products/data/products_repository.dart';
import 'purchases_provider.dart';

class CreatePurchaseDialog extends ConsumerStatefulWidget {
  const CreatePurchaseDialog({super.key});

  @override
  ConsumerState<CreatePurchaseDialog> createState() => _CreatePurchaseDialogState();
}

class _CreatePurchaseDialogState extends ConsumerState<CreatePurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  int? _selectedSupplierId;
  int _selectedWarehouseId = 1;
  String _unitType = 'meter';
  bool _isLoading = false;

  final List<_PurchaseLineItem> _items = [];

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_PurchaseLineItem());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _totalAmount {
    double total = 0;
    for (final item in _items) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.priceController.text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    final itemsData = _items.map((item) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.priceController.text) ?? 0;
      return {
        'product_id': item.selectedProductId,
        'purchased_quantity': qty,
        'purchase_price': price,
        'total_cost': qty * price,
      };
    }).toList();

    final data = {
      'supplier_id': _selectedSupplierId,
      'invoice_number': _invoiceNumberController.text.trim(),
      'warehouse_id': _selectedWarehouseId,
      'unit_type': _unitType,
      'paid_amount': _paidAmountController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'items': itemsData,
    };

    try {
      final repo = ref.read(purchasesRepositoryProvider);
      await repo.create(data);
      invalidateAfterPurchase(ref);
      if (mounted) Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(purchasesSuppliersProvider);
    final productsAsync = ref.watch(purchasesProductsProvider);
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
                  const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text('Create Purchase Invoice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
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
                      // Section: Invoice Details
                      _sectionHeader('Invoice Details', Icons.receipt_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: suppliersAsync.when(
                              data: (suppliers) => DropdownButtonFormField<int?>(
                                value: _selectedSupplierId,
                                decoration: const InputDecoration(
                                  labelText: 'Supplier *',
                                  prefixIcon: Icon(Icons.local_shipping_outlined),
                                ),
                                items: suppliers.map((s) => DropdownMenuItem(
                                  value: s.supplierId,
                                  child: Text(s.supplierName),
                                )).toList(),
                                onChanged: (v) => setState(() => _selectedSupplierId = v),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                              loading: () => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Loading...')),
                              error: (_, __) => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Error')),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _invoiceNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Number *',
                                prefixIcon: Icon(Icons.numbers),
                                hintText: 'e.g. PUR-001',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedWarehouseId,
                              decoration: const InputDecoration(
                                labelText: 'Warehouse *',
                                prefixIcon: Icon(Icons.warehouse_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Main Warehouse')),
                                DropdownMenuItem(value: 2, child: Text('Secondary Warehouse')),
                              ],
                              onChanged: (v) => setState(() => _selectedWarehouseId = v ?? 1),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _unitType,
                              decoration: const InputDecoration(
                                labelText: 'Unit Type',
                                prefixIcon: Icon(Icons.straighten),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'meter', child: Text('Meter')),
                                DropdownMenuItem(value: 'piece', child: Text('Piece')),
                                DropdownMenuItem(value: 'carton', child: Text('Carton')),
                              ],
                              onChanged: (v) => setState(() => _unitType = v ?? 'meter'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section: Items
                      _sectionHeader('Purchase Items', Icons.list_alt),
                      const SizedBox(height: 12),
                      ..._items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: productsAsync.when(
                                      data: (products) => DropdownButtonFormField<int?>(
                                        value: item.selectedProductId,
                                        decoration: const InputDecoration(
                                          labelText: 'Product',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: products.map((p) => DropdownMenuItem(
                                          value: p.productId,
                                          child: Text(p.productName, overflow: TextOverflow.ellipsis),
                                        )).toList(),
                                        onChanged: (v) => setState(() => item.selectedProductId = v),
                                        validator: (v) => v == null ? 'Required' : null,
                                      ),
                                      loading: () => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Loading...')),
                                      error: (_, __) => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Error')),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.quantityController,
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.priceController,
                                      decoration: const InputDecoration(
                                        labelText: 'Price/Unit',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${((double.tryParse(item.quantityController.text) ?? 0) * (double.tryParse(item.priceController.text) ?? 0)).toStringAsFixed(0)} IQD',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeItem(idx),
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section: Payment
                      _sectionHeader('Payment', Icons.payments_outlined),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text('Total: ', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text('${_totalAmount.toStringAsFixed(2)} IQD', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paidAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Paid Amount',
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'IQD',
                          hintText: '0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),

                      const SizedBox(height: 24),

                      // Section: Notes
                      _sectionHeader('Additional Information', Icons.notes_outlined),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Any additional notes...',
                          prefixIcon: Icon(Icons.note_outlined),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
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
                    label: const Text('Create Purchase'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PurchaseLineItem {
  int? selectedProductId;
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
  }
}
