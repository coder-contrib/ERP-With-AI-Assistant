import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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
  late final TextEditingController _imageUrlController;
  late bool _isMeterBased;
  late bool _allowPieceSale;
  late bool _allowCartonDisplay;
  late bool _activeStatus;
  late String _baseUnit;
  int? _selectedCategoryId;
  bool _isLoading = false;

  final List<_ConversionEntry> _conversions = [];

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.productName ?? '');
    _purchaseCostController = TextEditingController(text: p?.purchaseCost ?? '0');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice ?? '0');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
    _imageUrlController = TextEditingController(text: p?.productImage ?? '');
    _isMeterBased = p?.isMeterBased ?? true;
    _allowPieceSale = p?.allowPieceSale ?? false;
    _allowCartonDisplay = p?.allowCartonDisplay ?? true;
    _activeStatus = p?.activeStatus ?? true;
    _baseUnit = p?.baseUnit ?? 'meter';
    _selectedCategoryId = p?.categoryId;

    if (isEditing) {
      _loadConversions();
    }
  }

  Future<void> _loadConversions() async {
    try {
      final repo = ref.read(productsRepositoryProvider);
      final conversions = await repo.getConversions(widget.product!.productId);
      setState(() {
        _conversions.clear();
        for (final c in conversions) {
          _conversions.add(_ConversionEntry(
            id: c.conversionId,
            fromUnit: c.fromUnit,
            toUnit: c.toUnit,
            factorController: TextEditingController(text: c.factor.toString()),
          ));
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchaseCostController.dispose();
    _sellingPriceController.dispose();
    _barcodeController.dispose();
    _notesController.dispose();
    _imageUrlController.dispose();
    for (final c in _conversions) {
      c.factorController.dispose();
    }
    super.dispose();
  }

  void _addConversion() {
    setState(() {
      _conversions.add(_ConversionEntry(
        fromUnit: 'meter',
        toUnit: 'piece',
        factorController: TextEditingController(),
      ));
    });
  }

  void _removeConversion(int index) {
    setState(() {
      _conversions[index].factorController.dispose();
      _conversions.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'product_name': _nameController.text.trim(),
      'category_id': _selectedCategoryId,
      'is_meter_based': _isMeterBased,
      'allow_piece_sale': _allowPieceSale,
      'allow_carton_display': _allowCartonDisplay,
      'base_unit': _baseUnit,
      'purchase_cost_per_meter': _purchaseCostController.text.trim(),
      'selling_price': _sellingPriceController.text.trim(),
      'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      'product_image': _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      'active_status': _activeStatus,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    try {
      final repo = ref.read(productsRepositoryProvider);
      ProductModel result;
      if (isEditing) {
        result = await repo.update(widget.product!.productId, data);
      } else {
        result = await repo.create(data);
      }

      // Save unit conversions
      for (final conv in _conversions) {
        if (conv.id == null && conv.factorController.text.isNotEmpty) {
          await repo.addConversion(result.productId, {
            'from_unit': conv.fromUnit,
            'to_unit': conv.toUnit,
            'factor': conv.factorController.text.trim(),
          });
        }
      }

      ref.invalidate(productsProvider);
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
    final categories = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                  Icon(isEditing ? Icons.edit : Icons.add_circle, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Product' : 'Add New Product',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
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
                      // Section: Basic Information
                      _sectionHeader('Basic Information', Icons.info_outline),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'Enter product name',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: categories.when(
                              data: (cats) => DropdownButtonFormField<int?>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('No Category')),
                                  ...cats.map((c) => DropdownMenuItem(
                                    value: c.categoryId,
                                    child: Text(c.categoryName),
                                  )),
                                ],
                                onChanged: (v) => setState(() => _selectedCategoryId = v),
                              ),
                              loading: () => const TextField(
                                enabled: false,
                                decoration: InputDecoration(labelText: 'Loading categories...'),
                              ),
                              error: (_, __) => const TextField(
                                enabled: false,
                                decoration: InputDecoration(labelText: 'Error loading categories'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode',
                                hintText: 'Scan or enter barcode',
                                prefixIcon: Icon(Icons.qr_code),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section: Unit & Measurement
                      _sectionHeader('Unit & Measurement', Icons.straighten),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _baseUnit,
                              decoration: const InputDecoration(
                                labelText: 'Base Unit *',
                                prefixIcon: Icon(Icons.square_foot),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'meter', child: Text('Meter')),
                                DropdownMenuItem(value: 'piece', child: Text('Piece')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _baseUnit = v;
                                    _isMeterBased = v == 'meter';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Meter-based measurement'),
                              subtitle: Text(_isMeterBased ? 'Product is measured in meters' : 'Product is measured in pieces'),
                              value: _isMeterBased,
                              onChanged: (v) => setState(() {
                                _isMeterBased = v;
                                _baseUnit = v ? 'meter' : 'piece';
                              }),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('Allow piece sale'),
                              subtitle: const Text('Enable selling by individual piece'),
                              value: _allowPieceSale,
                              onChanged: (v) => setState(() => _allowPieceSale = v),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text('Allow carton display'),
                              subtitle: const Text('Show carton as a display option'),
                              value: _allowCartonDisplay,
                              onChanged: (v) => setState(() => _allowCartonDisplay = v),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section: Pricing
                      _sectionHeader('Pricing', Icons.attach_money),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchaseCostController,
                              decoration: const InputDecoration(
                                labelText: 'Purchase Cost *',
                                hintText: '0.00',
                                prefixIcon: Icon(Icons.shopping_cart_outlined),
                                suffixText: '/ unit',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Selling Price *',
                                hintText: '0.00',
                                prefixIcon: Icon(Icons.sell_outlined),
                                suffixText: '/ unit',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_purchaseCostController.text.isNotEmpty && _sellingPriceController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final cost = double.tryParse(_purchaseCostController.text) ?? 0;
                          final price = double.tryParse(_sellingPriceController.text) ?? 0;
                          final margin = price > 0 ? ((price - cost) / price * 100) : 0.0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: margin > 0 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  margin > 0 ? Icons.trending_up : Icons.trending_down,
                                  size: 16,
                                  color: margin > 0 ? AppColors.success : AppColors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Profit Margin: ${margin.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: margin > 0 ? AppColors.success : AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 24),

                      // Section: Unit Conversions
                      _sectionHeader('Unit Conversions', Icons.swap_horiz),
                      const SizedBox(height: 8),
                      Text(
                        'Define how this product converts between units (e.g., 1 carton = 12 pieces)',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ..._conversions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final conv = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: conv.fromUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'From',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'meter', child: Text('Meter')),
                                    DropdownMenuItem(value: 'piece', child: Text('Piece')),
                                    DropdownMenuItem(value: 'carton', child: Text('Carton')),
                                  ],
                                  onChanged: conv.id != null ? null : (v) {
                                    if (v != null) setState(() => conv.fromUnit = v);
                                  },
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward, size: 18),
                              ),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: conv.toUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'To',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'meter', child: Text('Meter')),
                                    DropdownMenuItem(value: 'piece', child: Text('Piece')),
                                    DropdownMenuItem(value: 'carton', child: Text('Carton')),
                                  ],
                                  onChanged: conv.id != null ? null : (v) {
                                    if (v != null) setState(() => conv.toUnit = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: conv.factorController,
                                  decoration: const InputDecoration(
                                    labelText: 'Factor',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  enabled: conv.id == null,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final num = double.tryParse(v.trim());
                                    if (num == null || num <= 0) return '> 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _removeConversion(idx),
                                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                iconSize: 20,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: _addConversion,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Conversion Rule'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section: Additional Info
                      _sectionHeader('Additional Information', Icons.more_horiz),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Product Image URL',
                          hintText: 'https://example.com/image.png',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Additional notes about this product...',
                          prefixIcon: Icon(Icons.notes),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Active Status'),
                        subtitle: Text(_activeStatus ? 'Product is active and visible' : 'Product is inactive and hidden'),
                        value: _activeStatus,
                        onChanged: (v) => setState(() => _activeStatus = v),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
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
                        : Icon(isEditing ? Icons.save : Icons.add),
                    label: Text(isEditing ? 'Update Product' : 'Create Product'),
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
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ConversionEntry {
  final int? id;
  String fromUnit;
  String toUnit;
  final TextEditingController factorController;

  _ConversionEntry({
    this.id,
    required this.fromUnit,
    required this.toUnit,
    required this.factorController,
  });
}
