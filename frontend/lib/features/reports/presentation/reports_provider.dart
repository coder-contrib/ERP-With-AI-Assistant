import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reports_repository.dart';

// === Tab state ===
final reportsTabProvider = StateProvider<int>((ref) => 0);

// === OPERATIONAL REPORTS (Tab 0) ===

final reportsDailySalesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getDailySales();
});

final reportsSalesByPeriodProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getSalesByPeriod(period: period);
});

final reportsSalesInvoicesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getSalesInvoices();
});

final reportsTopProductsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getTopProducts();
});

final reportsProductPerformanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getProductPerformance();
});

final reportsInventoryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getInventoryValuation();
});

final reportsLowStockProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getLowStock();
});

final reportsStockMovementProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getStockMovement();
});

final reportsDeadStockProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getDeadStock();
});

// === FINANCIAL REPORTS (Tab 1) ===

final reportsMonthlyProfitProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getMonthlyProfit();
});

final reportsProfitLossProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getProfitLoss();
});

final reportsCashFlowProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getCashFlow();
});

final reportsCustomerBalancesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getCustomerBalances();
});

final reportsSupplierBalancesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getSupplierBalances();
});

final reportsExpenseByCategoryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getExpenseByCategory();
});

// === AI INSIGHTS REPORTS (Tab 2) ===

final reportsCustomerSegmentationProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getCustomerSegmentation();
});

final reportsAiRiskAssessmentProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getAiRiskAssessment();
});

final reportsAiDailySummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(reportsRepositoryProvider);
  return repo.getAiDailySummary();
});
