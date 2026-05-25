import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_refresh.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/presentation/customers_provider.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../../suppliers/presentation/suppliers_provider.dart';
import '../data/opening_balance_repository.dart';
import 'opening_balances_provider.dart';

class OpeningBalancesPage extends ConsumerStatefulWidget {
  const OpeningBalancesPage({super.key});

  @override
  ConsumerState<OpeningBalancesPage> createState() => _OpeningBalancesPageState();
}

class _OpeningBalancesPageState extends ConsumerState<OpeningBalancesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text('Opening Balances', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: AppColors.warning),
                      SizedBox(width: 6),
                      Text('Lock after go-live', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Customers', icon: Icon(Icons.people_outline, size: 18)),
                Tab(text: 'Suppliers', icon: Icon(Icons.local_shipping_outlined, size: 18)),
                Tab(text: 'Cash / Bank', icon: Icon(Icons.account_balance_outlined, size: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CustomerOpeningBalanceTab(),
                _SupplierOpeningBalanceTab(),
                _CashOpeningBalanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer Tab ─────────────────────────────────────────────────────────────
class _CustomerOpeningBalanceTab extends ConsumerStatefulWidget {
  const _CustomerOpeningBalanceTab();

  @override
  ConsumerState<_CustomerOpeningBalanceTab> createState() => _CustomerOpeningBalanceTabState();
}

class _CustomerOpeningBalanceTabState extends ConsumerState<_CustomerOpeningBalanceTab> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedCustomerId;
  String _balanceType = 'receivable';
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(openingBalanceRepositoryProvider);
      await repo.createCustomerBalance(
        customerId: _selectedCustomerId!,
        amount: double.parse(_amountController.text.trim()),
        balanceType: _balanceType,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      ref.invalidate(openingBalancesProvider);
      invalidateDashboard(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer opening balance saved'), backgroundColor: AppColors.success),
        );
        _amountController.clear();
        _notesController.clear();
        setState(() => _selectedCustomerId = null);
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
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Customer Opening Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 24),

              // Customer dropdown
              customersAsync.when(
                data: (customers) => DropdownButtonFormField<int?>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Customer *',
                    prefixIcon: Icon(Icons.people_outline),
                  ),
                  items: customers.map((c) => DropdownMenuItem(
                    value: c.customerId,
                    child: Text(c.customerName),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCustomerId = v),
                  validator: (v) => v == null ? 'Select a customer' : null,
                ),
                loading: () => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Loading customers...')),
                error: (_, __) => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Error loading customers')),
              ),
              const SizedBox(height: 20),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance *',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: 'IQD',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Type radio buttons
              const Text('Type:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Receivable', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Customer owes us', style: TextStyle(fontSize: 11)),
                      value: 'receivable',
                      groupValue: _balanceType,
                      onChanged: (v) => setState(() => _balanceType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Advance', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('We owe customer', style: TextStyle(fontSize: 11)),
                      value: 'advance',
                      groupValue: _balanceType,
                      onChanged: (v) => setState(() => _balanceType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note_outlined),
                  hintText: 'Optional notes...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Save Opening Balance'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Supplier Tab ─────────────────────────────────────────────────────────────
class _SupplierOpeningBalanceTab extends ConsumerStatefulWidget {
  const _SupplierOpeningBalanceTab();

  @override
  ConsumerState<_SupplierOpeningBalanceTab> createState() => _SupplierOpeningBalanceTabState();
}

class _SupplierOpeningBalanceTabState extends ConsumerState<_SupplierOpeningBalanceTab> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedSupplierId;
  String _balanceType = 'payable';
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(openingBalanceRepositoryProvider);
      await repo.createSupplierBalance(
        supplierId: _selectedSupplierId!,
        amount: double.parse(_amountController.text.trim()),
        balanceType: _balanceType,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      ref.invalidate(openingBalancesProvider);
      invalidateDashboard(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier opening balance saved'), backgroundColor: AppColors.success),
        );
        _amountController.clear();
        _notesController.clear();
        setState(() => _selectedSupplierId = null);
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
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Supplier Opening Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 24),

              suppliersAsync.when(
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
                  validator: (v) => v == null ? 'Select a supplier' : null,
                ),
                loading: () => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Loading suppliers...')),
                error: (_, __) => const TextField(enabled: false, decoration: InputDecoration(labelText: 'Error loading suppliers')),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance *',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: 'IQD',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text('Type:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Payable', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('We owe supplier', style: TextStyle(fontSize: 11)),
                      value: 'payable',
                      groupValue: _balanceType,
                      onChanged: (v) => setState(() => _balanceType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Advance', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Supplier owes us', style: TextStyle(fontSize: 11)),
                      value: 'advance',
                      groupValue: _balanceType,
                      onChanged: (v) => setState(() => _balanceType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note_outlined),
                  hintText: 'Optional notes...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Save Opening Balance'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cash / Bank Tab ──────────────────────────────────────────────────────────
class _CashOpeningBalanceTab extends ConsumerStatefulWidget {
  const _CashOpeningBalanceTab();

  @override
  ConsumerState<_CashOpeningBalanceTab> createState() => _CashOpeningBalanceTabState();
}

class _CashOpeningBalanceTabState extends ConsumerState<_CashOpeningBalanceTab> {
  final _formKey = GlobalKey<FormState>();
  String _accountName = 'cash';
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(openingBalanceRepositoryProvider);
      await repo.createCashBalance(
        amount: double.parse(_amountController.text.trim()),
        accountName: _accountName,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      ref.invalidate(openingBalancesProvider);
      invalidateDashboard(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash/Bank opening balance saved'), backgroundColor: AppColors.success),
        );
        _amountController.clear();
        _notesController.clear();
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
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Cash / Bank Opening Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 24),

              // Account selection
              DropdownButtonFormField<String>(
                value: _accountName,
                decoration: const InputDecoration(
                  labelText: 'Account *',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash in Hand')),
                  DropdownMenuItem(value: 'bank_main', child: Text('Main Bank Account')),
                  DropdownMenuItem(value: 'bank_secondary', child: Text('Secondary Bank Account')),
                ],
                onChanged: (v) => setState(() => _accountName = v ?? 'cash'),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance *',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: 'IQD',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note_outlined),
                  hintText: 'Optional notes...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Save Opening Balance'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
