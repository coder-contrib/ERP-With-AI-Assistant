import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kpi_card.dart';
import '../data/expenses_repository.dart';
import 'expenses_provider.dart';
import 'add_expense_dialog.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final summaryAsync = ref.watch(expensesSummaryProvider);
    final search = ref.watch(expensesSearchProvider);
    final categoryFilter = ref.watch(expensesCategoryFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expensesProvider);
          ref.invalidate(expensesSummaryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  const Text('Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showAddExpenseDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Cards
              summaryAsync.when(
                data: (summary) => _buildKPICards(summary),
                loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Filters row
              Row(
                children: [
                  // Search
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search expenses...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => ref.read(expensesSearchProvider.notifier).state = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date filter chips
                  _dateChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _dateChip('This Week', 'week'),
                  const SizedBox(width: 8),
                  _dateChip('This Month', 'month'),
                  const SizedBox(width: 12),
                  // Refresh
                  IconButton(
                    onPressed: () {
                      ref.invalidate(expensesProvider);
                      ref.invalidate(expensesSummaryProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Expenses Table
              expensesAsync.when(
                data: (expenses) {
                  final filtered = _filterExpenses(expenses, search, categoryFilter);
                  return _buildExpensesTable(filtered, isDark);
                },
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards(ExpenseSummaryModel summary) {
    return Row(
      children: [
        Expanded(child: KPICard(
          title: 'Today\'s Expenses',
          value: '${summary.totalToday.toStringAsFixed(0)} IQD',
          icon: Icons.today,
          color: AppColors.error,
        )),
        const SizedBox(width: 16),
        Expanded(child: KPICard(
          title: 'Monthly Expenses',
          value: '${summary.totalMonth.toStringAsFixed(0)} IQD',
          icon: Icons.calendar_month,
          color: AppColors.warning,
        )),
        const SizedBox(width: 16),
        Expanded(child: KPICard(
          title: 'Highest Category',
          value: summary.highestCategory ?? 'N/A',
          icon: Icons.trending_up,
          color: AppColors.info,
          trend: summary.highestCategoryAmount > 0 ? '${summary.highestCategoryAmount.toStringAsFixed(0)} IQD' : null,
        )),
        const SizedBox(width: 16),
        Expanded(child: KPICard(
          title: 'Total Entries',
          value: '${summary.expenseCount}',
          icon: Icons.receipt,
          color: AppColors.primary,
        )),
      ],
    );
  }

  Widget _dateChip(String label, String value) {
    final selected = ref.watch(expensesDateFilterProvider) == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
      selected: selected,
      onSelected: (_) {
        ref.read(expensesDateFilterProvider.notifier).state = value;
        ref.invalidate(expensesProvider);
      },
      selectedColor: AppColors.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> expenses, String search, String? category) {
    var result = expenses;
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((e) =>
        e.expenseName.toLowerCase().contains(q) ||
        e.expenseCategory.toLowerCase().contains(q) ||
        (e.notes ?? '').toLowerCase().contains(q)
      ).toList();
    }
    if (category != null && category.isNotEmpty) {
      result = result.where((e) => e.expenseCategory == category).toList();
    }
    return result;
  }

  Widget _buildExpensesTable(List<ExpenseModel> expenses, bool isDark) {
    if (expenses.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('No expenses found', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? AppColors.darkBackground : AppColors.background,
          ),
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: expenses.map((e) => DataRow(cells: [
            DataCell(Text(_formatDate(e.expenseDate), style: const TextStyle(fontSize: 13))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _categoryColor(e.expenseCategory).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(e.expenseCategory, style: TextStyle(fontSize: 12, color: _categoryColor(e.expenseCategory), fontWeight: FontWeight.w500)),
            )),
            DataCell(Text(e.expenseName, style: const TextStyle(fontSize: 13))),
            DataCell(Text(e.paymentMethod ?? 'cash', style: const TextStyle(fontSize: 13))),
            DataCell(Text('${e.amount.toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            DataCell(IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              onPressed: () => _deleteExpense(e.expenseId),
              tooltip: 'Delete',
            )),
          ])).toList(),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _categoryColor(String category) {
    final colors = {
      'Rent': AppColors.primary,
      'Salaries': AppColors.info,
      'Electricity': AppColors.warning,
      'Water': Colors.blue,
      'Internet': Colors.purple,
      'Transport': Colors.teal,
      'Maintenance': Colors.orange,
      'Marketing': Colors.pink,
      'Packaging': Colors.brown,
    };
    return colors[category] ?? AppColors.textSecondary;
  }

  Future<void> _deleteExpense(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
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
    if (confirmed == true) {
      final repo = ref.read(expensesRepositoryProvider);
      await repo.delete(id);
      ref.invalidate(expensesProvider);
      ref.invalidate(expensesSummaryProvider);
    }
  }

  void _showAddExpenseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddExpenseDialog(),
    );
    if (result == true) {
      ref.invalidate(expensesProvider);
      ref.invalidate(expensesSummaryProvider);
    }
  }
}
