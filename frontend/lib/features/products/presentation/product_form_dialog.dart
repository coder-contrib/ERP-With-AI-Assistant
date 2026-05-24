import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/products_repository.dart';
import 'products_provider.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _purchaseCostController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _notesController;
  late bool _isMeterBased;
  late bool _allowPieceSale;
  late bool _activeStatus;
  bool _isLoading = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.productName ?? '');
    _purchaseCostController = TextEditingController(text: p?.purchaseCost ?? '0');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice ?? '0');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _notesController = TextEditingController();
    _isMeterBased = p?.isMeterBased ?? true;
    _allowPieceSale = p?.allowPieceSale ?? false;
    _activeStatus = p?.activeStatus ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchaseCostController.dispose();
    _sellingPriceController.dispose();
    _barcodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'product_name': _nameController.text.trim(),
      'is_meter_based': _isMeterBased,
      'allow_piece_sale': _allowPieceSale,
      'base_unit': _isMeterBased ? 'meter' : 'piece',
      'purchase_cost_per_meter': _purchaseCostController.text.trim(),
      'selling_price': _sellingPriceController.text.trim(),
      'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    if (isEditing) {
      data['active_status'] = _activeStatus;
    }

    try {
      final repo = ref.read(productsRepositoryProvider);
      if (isEditing) {
        await repo.update(widget.product!.productId, data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(productsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchaseCostController,
                        decoration: const InputDecoration(labelText: 'Purchase Cost'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        decoration: const InputDecoration(labelText: 'Selling Price'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(labelText: 'Barcode'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Meter-based measurement'),
                  subtitle: Text(_isMeterBased ? 'Measured in meters' : 'Measured in pieces'),
                  value: _isMeterBased,
                  onChanged: (v) => setState(() => _isMeterBased = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Allow piece sale'),
                  value: _allowPieceSale,
                  onChanged: (v) => setState(() => _allowPieceSale = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (isEditing)
                  SwitchListTile(
                    title: const Text('Active'),
                    value: _activeStatus,
                    onChanged: (v) => setState(() => _activeStatus = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
