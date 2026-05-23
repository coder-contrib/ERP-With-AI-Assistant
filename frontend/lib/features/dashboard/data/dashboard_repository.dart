import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.read(dioProvider));
});

class DashboardSummary {
  final String todaySales;
  final String todayPurchases;
  final String todayExpenses;
  final String monthlyRevenue;
  final String monthlyProfit;
  final int lowStockProducts;
  final int pendingPayments;
  final String cashBalance;
  final String totalReceivables;
  final String totalPayables;

  DashboardSummary({
    required this.todaySales, required this.todayPurchases, required this.todayExpenses,
    required this.monthlyRevenue, required this.monthlyProfit,
    required this.lowStockProducts, required this.pendingPayments,
    required this.cashBalance, required this.totalReceivables, required this.totalPayables,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todaySales: json['today_sales'] ?? '0',
      todayPurchases: json['today_purchases'] ?? '0',
      todayExpenses: json['today_expenses'] ?? '0',
      monthlyRevenue: json['monthly_revenue'] ?? '0',
      monthlyProfit: json['monthly_profit'] ?? '0',
      lowStockProducts: json['low_stock_products'] ?? 0,
      pendingPayments: json['pending_payments'] ?? 0,
      cashBalance: json['cash_balance'] ?? '0',
      totalReceivables: json['total_receivables'] ?? '0',
      totalPayables: json['total_payables'] ?? '0',
    );
  }
}

class DashboardRepository {
  final Dio _dio;
  DashboardRepository(this._dio);

  Future<DashboardSummary> getSummary() async {
    final response = await _dio.get('/dashboard/summary');
    return DashboardSummary.fromJson(response.data);
  }
}
