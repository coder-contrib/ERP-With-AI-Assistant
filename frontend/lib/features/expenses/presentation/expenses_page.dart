import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_refresh.dart';
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.error, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('Track and manage all business expenses', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(expensesProvider);
                  ref.invalidate(expensesSummaryProvider);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddExpenseDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Expense'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Cards
          summaryAsync.when(
            data: (summary) => _buildKPICards(summary, isDark),
            loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Filters row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, category, or notes...',
                      hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, size: 20, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      filled: true,
                      fillColor: isDark ? AppColors.darkBackground : AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => ref.read(expensesSearchProvider.notifier).state = v,
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : AppColors.border),
                const SizedBox(width: 16),
                _dateChip('Today', 'today'),
                const SizedBox(width: 8),
                _dateChip('This Week', 'week'),
                const SizedBox(width: 8),
                _dateChip('This Month', 'month'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Expenses Table - fills remaining space
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                final filtered = _filterExpenses(expenses, search, categoryFilter);
                return _buildExpensesTable(filtered, isDark);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load expenses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('$e', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(expensesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards(ExpenseSummaryModel summary, bool isDark) {
    return Row(
      children: [
        Expanded(child: _KPITile(
          title: "Today's Expenses",
          value: '${summary.totalToday.toStringAsFixed(0)} IQD',
          icon: Icons.today_rounded,
          color: AppColors.error,
          isDark: isDark,
        )),
        const SizedBox(width: 14),
        Expanded(child: _KPITile(
          title: 'Monthly Expenses',
          value: '${summary.totalMonth.toStringAsFixed(0)} IQD',
          icon: Icons.calendar_month_rounded,
          color: AppColors.warning,
          isDark: isDark,
        )),
        const SizedBox(width: 14),
        Expanded(child: _KPITile(
          title: 'Top Category',
          value: summary.highestCategory ?? 'N/A',
          icon: Icons.category_rounded,
          color: AppColors.info,
          subtitle: summary.highestCategoryAmount > 0 ? '${summary.highestCategoryAmount.toStringAsFixed(0)} IQD' : null,
          isDark: isDark,
        )),
        const SizedBox(width: 14),
        Expanded(child: _KPITile(
          title: 'Total Entries',
          value: '${summary.expenseCount}',
          icon: Icons.receipt_rounded,
          color: AppColors.primary,
          isDark: isDark,
        )),
      ],
    );
  }

  Widget _dateChip(String label, String value) {
    final selected = ref.watch(expensesDateFilterProvider) == value;
    return GestureDetector(
      onTap: () {
        ref.read(expensesDateFilterProvider.notifier).state = value;
        ref.invalidate(expensesProvider);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
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
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 56, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 14),
              Text('No expenses found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text('Add an expense or adjust filters', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.7))),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Row(
              children: [
                _headerCell('Date', flex: 2),
                _headerCell('Category', flex: 2),
                _headerCell('Description', flex: 3),
                _headerCell('Payment', flex: 2),
                _headerCell('Amount', flex: 2, align: TextAlign.right),
                _headerCell('', flex: 1),
              ],
            ),
          ),
          // Table body - scrollable
          Expanded(
            child: ListView.separated(
              itemCount: expenses.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
              itemBuilder: (context, index) {
                final e = expenses[index];
                return _buildRow(e, isDark, index);
              },
            ),
          ),
          // Table footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.background,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  '${expenses.length} expense${expenses.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  'Total: ${expenses.fold<double>(0, (sum, e) => sum + e.amount).toStringAsFixed(0)} IQD',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildRow(ExpenseModel e, bool isDark, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Date
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(_formatDate(e.expenseDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // Category
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _categoryColor(e.expenseCategory).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        e.expenseCategory,
                        style: TextStyle(fontSize: 12, color: _categoryColor(e.expenseCategory), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Description
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.expenseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    if (e.notes != null && e.notes!.isNotEmpty)
                      Text(e.notes!, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Payment method
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      (e.paymentMethod ?? 'cash') == 'cash' ? Icons.payments_outlined : Icons.credit_card_outlined,
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (e.paymentMethod ?? 'cash').replaceAll('_', ' '),
                      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Amount
              Expanded(
                flex: 2,
                child: Text(
                  '${e.amount.toStringAsFixed(0)} IQD',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              // Actions
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error.withOpacity(0.7)),
                      onPressed: () => _deleteExpense(e.expenseId),
                      tooltip: 'Delete',
                      splashRadius: 18,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _categoryColor(String category) {
    final colors = {
      'Rent': AppColors.primary,
      'Salaries': const Color(0xFF6366F1),
      'Electricity': AppColors.warning,
      'Water': const Color(0xFF06B6D4),
      'Internet': const Color(0xFF8B5CF6),
      'Transport': const Color(0xFF14B8A6),
      'Maintenance': const Color(0xFFF97316),
      'Marketing': const Color(0xFFEC4899),
      'Packaging': const Color(0xFF78716C),
      'Office Supplies': const Color(0xFF84CC16),
      'Food': const Color(0xFFEAB308),
    };
    return colors[category] ?? AppColors.primary;
  }

  Future<void> _deleteExpense(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(expensesRepositoryProvider);
      await repo.delete(id);
      invalidateAfterExpense(ref);
    }
  }

  void _showAddExpenseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddExpenseDialog(),
    );
    if (result == true) {
      invalidateAfterExpense(ref);
    }
  }
}

class _KPITile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isDark;

  const _KPITile({required this.title, required this.value, required this.icon, required this.color, this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
