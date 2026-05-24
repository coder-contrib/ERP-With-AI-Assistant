import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/expenses_repository.dart';
import 'expenses_provider.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  String _paymentMethod = 'cash';
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _paidByController = TextEditingController();
  final _receiptController = TextEditingController();
  final _newCategoryController = TextEditingController();
  bool _isLoading = false;
  bool _showNewCategory = false;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    _paidByController.dispose();
    _receiptController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null && !_showNewCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(expensesRepositoryProvider);

      String category = _selectedCategory ?? '';
      if (_showNewCategory && _newCategoryController.text.trim().isNotEmpty) {
        final newCat = await repo.createCategory(name: _newCategoryController.text.trim());
        category = newCat.name;
        ref.invalidate(expenseCategoriesProvider);
      }

      await repo.create(
        category: category,
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        paymentMethod: _paymentMethod,
        paidBy: _paidByController.text.trim().isEmpty ? null : _paidByController.text.trim(),
        receiptNumber: _receiptController.text.trim().isEmpty ? null : _receiptController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added successfully'), backgroundColor: AppColors.success),
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
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
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
                  const Icon(Icons.receipt_long, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text('Add Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Basic Info
                      _sectionHeader(Icons.info_outline, 'Basic Info'),
                      const SizedBox(height: 16),

                      // Category
                      if (!_showNewCategory)
                        categoriesAsync.when(
                          data: (categories) {
                            final items = categories.map((c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            )).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category *',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: items,
                                  onChanged: (v) => setState(() => _selectedCategory = v),
                                  validator: (v) => v == null ? 'Select a category' : null,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => setState(() => _showNewCategory = true),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('New Category', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            );
                          },
                          loading: () => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Loading categories...')),
                          error: (_, __) => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Error')),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _newCategoryController,
                              decoration: const InputDecoration(
                                labelText: 'New Category Name *',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _showNewCategory = false;
                                _newCategoryController.clear();
                              }),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Use Existing', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Description / Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          prefixIcon: Icon(Icons.description_outlined),
                          hintText: 'e.g., Monthly electricity bill',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'IQD',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null) return 'Invalid';
                          if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Section: Payment
                      _sectionHeader(Icons.payment_outlined, 'Payment'),
                      const SizedBox(height: 16),

                      // Payment method
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method *',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                        ],
                        onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
                      ),
                      const SizedBox(height: 16),

                      // Paid by
                      TextFormField(
                        controller: _paidByController,
                        decoration: const InputDecoration(
                          labelText: 'Paid By',
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: 'Who paid?',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Receipt number
                      TextFormField(
                        controller: _receiptController,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Number',
                          prefixIcon: Icon(Icons.receipt_outlined),
                          hintText: 'Optional receipt #',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section: Additional
                      _sectionHeader(Icons.note_outlined, 'Additional Info'),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.note_outlined),
                          hintText: 'Optional notes...',
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
                children: [
                  // Accounting info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.info),
                        SizedBox(width: 6),
                        Text('Auto: Ledger + Cash + AI', style: TextStyle(fontSize: 11, color: AppColors.info)),
                      ],
                    ),
                  ),
                  const Spacer(),
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
                    label: const Text('Save Expense'),
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

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ],
    );
  }
}
