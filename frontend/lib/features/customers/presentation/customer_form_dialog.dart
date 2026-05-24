import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/customers_repository.dart';
import 'customers_provider.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final CustomerModel? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _paymentTermsController;
  late final TextEditingController _notesController;
  bool _isLoading = false;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.customerName ?? '');
    _phoneController = TextEditingController(text: c?.phoneNumber ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _creditLimitController = TextEditingController(text: c?.creditLimit ?? '0');
    _paymentTermsController = TextEditingController(text: c?.paymentTerms.toString() ?? '0');
    _notesController = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'customer_name': _nameController.text.trim(),
      'phone_number': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'credit_limit': _creditLimitController.text.trim(),
      'payment_terms': int.tryParse(_paymentTermsController.text.trim()) ?? 0,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    try {
      final repo = ref.read(customersRepositoryProvider);
      if (isEditing) {
        await repo.update(widget.customer!.customerId, data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(customersProvider);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.person_add, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Customer' : 'Add New Customer',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Contact Information', Icons.person_outline),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name *',
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+964 XXX XXX XXXX',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Street, City, Region',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader('Credit & Payment Terms', Icons.account_balance_wallet_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _creditLimitController,
                              decoration: const InputDecoration(
                                labelText: 'Credit Limit *',
                                hintText: '0.00',
                                prefixIcon: Icon(Icons.credit_card),
                                suffixText: 'IQD',
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
                              controller: _paymentTermsController,
                              decoration: const InputDecoration(
                                labelText: 'Payment Terms',
                                hintText: '0',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                                suffixText: 'days',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance, size: 18, color: AppColors.info),
                              const SizedBox(width: 8),
                              Text('Current Balance: ', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                              Text(
                                '${widget.customer!.currentBalance} IQD',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionHeader('Additional Information', Icons.notes_outlined),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Any additional notes about this customer...',
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
                        : Icon(isEditing ? Icons.save : Icons.person_add),
                    label: Text(isEditing ? 'Update Customer' : 'Create Customer'),
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
