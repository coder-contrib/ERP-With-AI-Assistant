import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';

final expensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final repo = ref.read(expensesRepositoryProvider);
  return repo.getAll();
});

final expensesSummaryProvider = FutureProvider<ExpenseSummaryModel>((ref) async {
  final repo = ref.read(expensesRepositoryProvider);
  return repo.getSummary();
});

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategoryModel>>((ref) async {
  final repo = ref.read(expensesRepositoryProvider);
  return repo.getCategories();
});

final expensesSearchProvider = StateProvider<String>((ref) => '');
final expensesCategoryFilterProvider = StateProvider<String?>((ref) => null);
final expensesDateFilterProvider = StateProvider<String>((ref) => 'month');
