import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../customers/data/customers_repository.dart';
import '../../products/data/products_repository.dart';
import '../data/sales_repository.dart';
import 'sales_provider.dart';

class CreateSaleDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const CreateSaleDialog({super.key, required this.onCreated});

  @override
  ConsumerState<CreateSaleDialog> createState() => _CreateSaleDialogState();
}

class _CreateSaleDialogState extends ConsumerState<CreateSaleDialog> {
  int _step = 0;
  int? _selectedCustomerId;
  bool _isWalkIn = false;
  String _invoiceType = 'cash';
  int _warehouseId = 1;
  final List<_SaleLineItem> _items = [];
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get _discountTotal => double.tryParse(_discountController.text) ?? 0;
  double get _total => _subtotal - _discountTotal;

  @override
  void dispose() {
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildStepIndicator(),
            const SizedBox(height: 20),
            Flexible(child: _buildCurrentStep()),
            const SizedBox(height: 16),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.point_of_sale, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text('Create New Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Customer', 'Products', 'Payment', 'Confirm'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _step;
        final isDone = i < _step;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.success : isActive ? AppColors.primary : Colors.grey.withOpacity(0.3),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${i + 1}', style: TextStyle(fontSize: 12, color: isActive ? Colors.white : null, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 4),
              Text(steps[i], style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.primary : null)),
              if (i < steps.length - 1) Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDone ? AppColors.success : Colors.grey.withOpacity(0.3))),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0: return _buildCustomerStep();
      case 1: return _buildProductsStep();
      case 2: return _buildPaymentStep();
      case 3: return _buildConfirmStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildCustomerStep() {
    final customersAsync = ref.watch(customersProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Customer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Walk-in Customer'),
            subtitle: const Text('No specific customer account'),
            value: _isWalkIn,
            onChanged: (v) => setState(() { _isWalkIn = v ?? false; if (_isWalkIn) _selectedCustomerId = null; }),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!_isWalkIn) ...[
            const SizedBox(height: 12),
            customersAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (customers) => DropdownButtonFormField<int>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(labelText: 'Customer', hintText: 'Select a customer'),
                items: customers.map((c) => DropdownMenuItem(value: c.customerId, child: Text(c.customerName))).toList(),
                onChanged: (v) => setState(() => _selectedCustomerId = v),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Warehouse', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _warehouseId,
            decoration: const InputDecoration(labelText: 'Warehouse'),
            items: List.generate(3, (i) => DropdownMenuItem(value: i + 1, child: Text('Warehouse ${i + 1}'))),
            onChanged: (v) => setState(() => _warehouseId = v ?? 1),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsStep() {
    final productsAsync = ref.watch(productsListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Invoice Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addItem(productsAsync),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No items added yet. Click "Add Item" to begin.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text('${item.quantity} ${item.unitType} x ${item.unitPrice.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  if (item.discount > 0) Text('Discount: ${item.discount.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 12, color: AppColors.warning)),
                                ],
                              ),
                            ),
                            Text('${item.lineTotal.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              onPressed: () => setState(() => _items.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Subtotal: ${_subtotal.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal', '${_subtotal.toStringAsFixed(2)} EGP'),
                const SizedBox(height: 6),
                _summaryRow('Discount', '${_discountTotal.toStringAsFixed(2)} EGP'),
                const Divider(),
                _summaryRow('Total', '${_total.toStringAsFixed(2)} EGP', bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _discountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Discount Amount', prefixText: 'EGP '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Invoice Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money)),
              ButtonSegment(value: 'credit', label: Text('Credit'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: 'mixed', label: Text('Mixed'), icon: Icon(Icons.swap_horiz)),
            ],
            selected: {_invoiceType},
            onSelectionChanged: (v) => setState(() {
              _invoiceType = v.first;
              if (_invoiceType == 'cash') _paidController.text = _total.toStringAsFixed(2);
            }),
          ),
          const SizedBox(height: 16),
          if (_invoiceType != 'credit')
            TextField(
              controller: _paidController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Paid Amount', prefixText: 'EGP ', hintText: _total.toStringAsFixed(2)),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final paidAmount = double.tryParse(_paidController.text) ?? (_invoiceType == 'cash' ? _total : 0);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review & Confirm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _confirmRow('Customer', _isWalkIn ? 'Walk-in Customer' : 'Customer #${_selectedCustomerId ?? "N/A"}'),
          _confirmRow('Warehouse', 'Warehouse $_warehouseId'),
          _confirmRow('Items', '${_items.length} products'),
          _confirmRow('Subtotal', '${_subtotal.toStringAsFixed(2)} EGP'),
          _confirmRow('Discount', '${_discountTotal.toStringAsFixed(2)} EGP'),
          _confirmRow('Total', '${_total.toStringAsFixed(2)} EGP'),
          _confirmRow('Payment Type', _invoiceType.toUpperCase()),
          _confirmRow('Paid Amount', '${paidAmount.toStringAsFixed(2)} EGP'),
          _confirmRow('Remaining', '${(_total - paidAmount).clamp(0, double.infinity).toStringAsFixed(2)} EGP'),
          if (_notesController.text.isNotEmpty) _confirmRow('Notes', _notesController.text),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(child: Text('Creating this invoice will automatically deduct stock and create ledger entries.', style: TextStyle(fontSize: 12, color: AppColors.info))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          TextButton(onPressed: () => setState(() => _step--), child: const Text('Back'))
        else
          const SizedBox.shrink(),
        Row(
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            if (_step < 3)
              ElevatedButton(
                onPressed: _canProceed() ? () => setState(() => _step++) : null,
                child: const Text('Next'),
              )
            else
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Invoice'),
              ),
          ],
        ),
      ],
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0: return _isWalkIn || _selectedCustomerId != null;
      case 1: return _items.isNotEmpty;
      case 2: return true;
      default: return true;
    }
  }

  void _addItem(AsyncValue<List<ProductModel>> productsAsync) {
    productsAsync.whenData((products) {
      ProductModel? selected;
      final qtyController = TextEditingController(text: '1');
      final priceController = TextEditingController();
      final discountController = TextEditingController(text: '0');
      String unitType = 'meter';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Add Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ProductModel>(
                    decoration: const InputDecoration(labelText: 'Product'),
                    items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.productName))).toList(),
                    onChanged: (p) {
                      setDialogState(() {
                        selected = p;
                        priceController.text = p?.sellingPrice ?? '';
                        unitType = p?.baseUnit ?? 'meter';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unitType,
                    decoration: const InputDecoration(labelText: 'Unit Type'),
                    items: const [
                      DropdownMenuItem(value: 'meter', child: Text('Meter (m²)')),
                      DropdownMenuItem(value: 'piece', child: Text('Piece')),
                      DropdownMenuItem(value: 'carton', child: Text('Carton')),
                    ],
                    onChanged: (v) => setDialogState(() => unitType = v ?? 'meter'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit Price', prefixText: 'EGP ')),
                  const SizedBox(height: 12),
                  TextField(controller: discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount', prefixText: 'EGP ')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (selected == null) return;
                  final qty = double.tryParse(qtyController.text) ?? 0;
                  final price = double.tryParse(priceController.text) ?? 0;
                  final disc = double.tryParse(discountController.text) ?? 0;
                  if (qty <= 0 || price <= 0) return;
                  setState(() {
                    _items.add(_SaleLineItem(
                      productId: selected!.productId,
                      productName: selected!.productName,
                      quantity: qty,
                      unitType: unitType,
                      unitPrice: price,
                      costAtSale: double.tryParse(selected!.purchaseCost) ?? 0,
                      discount: disc,
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final paidAmount = double.tryParse(_paidController.text) ?? (_invoiceType == 'cash' ? _total : 0);
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final repo = ref.read(salesRepositoryProvider);
      await repo.create({
        'customer_id': _isWalkIn ? null : _selectedCustomerId,
        'invoice_number': invoiceNumber,
        'invoice_type': _invoiceType,
        'warehouse_id': _warehouseId,
        'discount_amount': _discountTotal,
        'paid_amount': paidAmount,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'items': _items.map((item) => {
          'product_id': item.productId,
          'sold_quantity': item.quantity,
          'unit_type': item.unitType,
          'unit_price': item.unitPrice,
          'cost_at_sale': item.costAtSale,
          'discount': item.discount,
          'total_price': item.lineTotal,
        }).toList(),
      });
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice $invoiceNumber created successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating invoice: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _SaleLineItem {
  final int productId;
  final String productName;
  final double quantity;
  final String unitType;
  final double unitPrice;
  final double costAtSale;
  final double discount;

  _SaleLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitType,
    required this.unitPrice,
    required this.costAtSale,
    required this.discount,
  });

  double get lineTotal => (quantity * unitPrice) - discount;
}
