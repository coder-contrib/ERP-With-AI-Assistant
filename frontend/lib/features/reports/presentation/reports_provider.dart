import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reports_repository.dart';

final reportsDailySalesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getDailySales();
});

final reportsMonthlyProfitProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getMonthlyProfit();
});

final reportsTopProductsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getTopProducts();
});

final reportsInventoryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getInventoryValuation();
});

final reportsCustomerBalancesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getCustomerBalances();
});

final reportsSupplierBalancesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getSupplierBalances();
});

final reportsCashFlowProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getCashFlow();
});

final reportsTabProvider = StateProvider<int>((ref) => 0);
