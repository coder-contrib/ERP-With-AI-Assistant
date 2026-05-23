import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getSummary();
});

final dailySalesProvider = FutureProvider<List<DailySalesData>>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getDailySales();
});

final monthlyProfitProvider = FutureProvider<List<MonthlyProfitData>>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getMonthlyProfit();
});

final cashFlowProvider = FutureProvider<List<CashFlowData>>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getCashFlow();
});

final topProductsProvider = FutureProvider<List<TopProductData>>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getTopProducts();
});

final aiInsightsProvider = FutureProvider<List<AIInsight>>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getAIInsights();
});
