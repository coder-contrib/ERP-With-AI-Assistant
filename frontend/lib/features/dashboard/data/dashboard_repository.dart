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

class DailySalesData {
  final String date;
  final int invoiceCount;
  final double totalSales;
  final double cashCollected;
  final double creditSales;

  DailySalesData({required this.date, required this.invoiceCount, required this.totalSales, required this.cashCollected, required this.creditSales});

  factory DailySalesData.fromJson(Map<String, dynamic> json) {
    return DailySalesData(
      date: json['date'] ?? '',
      invoiceCount: json['invoice_count'] ?? 0,
      totalSales: double.tryParse(json['total_sales']?.toString() ?? '0') ?? 0,
      cashCollected: double.tryParse(json['cash_collected']?.toString() ?? '0') ?? 0,
      creditSales: double.tryParse(json['credit_sales']?.toString() ?? '0') ?? 0,
    );
  }
}

class MonthlyProfitData {
  final String month;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double grossMargin;

  MonthlyProfitData({required this.month, required this.revenue, required this.cogs, required this.grossProfit, required this.expenses, required this.netProfit, required this.grossMargin});

  factory MonthlyProfitData.fromJson(Map<String, dynamic> json) {
    return MonthlyProfitData(
      month: json['month'] ?? '',
      revenue: double.tryParse(json['revenue']?.toString() ?? '0') ?? 0,
      cogs: double.tryParse(json['cogs']?.toString() ?? '0') ?? 0,
      grossProfit: double.tryParse(json['gross_profit']?.toString() ?? '0') ?? 0,
      expenses: double.tryParse(json['expenses']?.toString() ?? '0') ?? 0,
      netProfit: double.tryParse(json['net_profit']?.toString() ?? '0') ?? 0,
      grossMargin: double.tryParse(json['gross_margin']?.toString() ?? '0') ?? 0,
    );
  }
}

class CashFlowData {
  final String date;
  final double cashIn;
  final double cashOut;
  final double net;

  CashFlowData({required this.date, required this.cashIn, required this.cashOut, required this.net});

  factory CashFlowData.fromJson(Map<String, dynamic> json) {
    return CashFlowData(
      date: json['date'] ?? '',
      cashIn: double.tryParse(json['cash_in']?.toString() ?? '0') ?? 0,
      cashOut: double.tryParse(json['cash_out']?.toString() ?? '0') ?? 0,
      net: double.tryParse(json['net']?.toString() ?? '0') ?? 0,
    );
  }
}

class TopProductData {
  final int productId;
  final String productName;
  final double totalQuantity;
  final double totalRevenue;

  TopProductData({required this.productId, required this.productName, required this.totalQuantity, required this.totalRevenue});

  factory TopProductData.fromJson(Map<String, dynamic> json) {
    return TopProductData(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      totalQuantity: double.tryParse(json['total_quantity']?.toString() ?? '0') ?? 0,
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0,
    );
  }
}

class AIInsight {
  final String type;
  final String title;
  final String message;
  final String severity;

  AIInsight({required this.type, required this.title, required this.message, required this.severity});
}

class DashboardRepository {
  final Dio _dio;
  DashboardRepository(this._dio);

  Future<DashboardSummary> getSummary() async {
    final response = await _dio.get('/dashboard/summary');
    return DashboardSummary.fromJson(response.data);
  }

  Future<List<DailySalesData>> getDailySales({int days = 30}) async {
    final response = await _dio.get('/reports/daily-sales', queryParameters: {
      'start_date': DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0],
      'end_date': DateTime.now().toIso8601String().split('T')[0],
    });
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => DailySalesData.fromJson(e)).toList();
  }

  Future<List<MonthlyProfitData>> getMonthlyProfit({int? year}) async {
    final response = await _dio.get('/reports/monthly-profit', queryParameters: {
      'year': year ?? DateTime.now().year,
    });
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => MonthlyProfitData.fromJson(e)).toList();
  }

  Future<List<CashFlowData>> getCashFlow({int days = 14}) async {
    final response = await _dio.get('/reports/cash-flow', queryParameters: {
      'start_date': DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0],
      'end_date': DateTime.now().toIso8601String().split('T')[0],
    });
    final days_ = response.data['data']?['days'] as List? ?? [];
    return days_.map((e) => CashFlowData.fromJson(e)).toList();
  }

  Future<List<TopProductData>> getTopProducts({int limit = 5}) async {
    final response = await _dio.get('/reports/top-products', queryParameters: {'limit': limit});
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => TopProductData.fromJson(e)).toList();
  }

  Future<List<AIInsight>> getAIInsights() async {
    try {
      final profitResponse = await _dio.get('/ai/analyze/profit', queryParameters: {
        'start_date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0],
        'end_date': DateTime.now().toIso8601String().split('T')[0],
      });
      final issues = profitResponse.data['issues'] as List? ?? [];
      final trend = profitResponse.data['profit_trend'] ?? 'stable';

      List<AIInsight> insights = [];
      if (trend == 'decreasing') {
        insights.add(AIInsight(type: 'profit', title: 'Profit Declining', message: 'Net profit is trending downward this month.', severity: 'warning'));
      } else if (trend == 'increasing') {
        insights.add(AIInsight(type: 'profit', title: 'Profit Growing', message: 'Net profit is trending upward. Keep it up!', severity: 'success'));
      }
      for (final issue in issues) {
        insights.add(AIInsight(type: 'issue', title: 'Financial Alert', message: issue.toString(), severity: 'warning'));
      }

      final lowStockResponse = await _dio.get('/ai/predict/low-stock', queryParameters: {'days_ahead': 7});
      final atRisk = lowStockResponse.data['at_risk_count'] ?? 0;
      if (atRisk > 0) {
        insights.add(AIInsight(type: 'stock', title: 'Stock Alert', message: '$atRisk products predicted to stockout within 7 days.', severity: 'critical'));
      }

      return insights;
    } catch (_) {
      return [];
    }
  }
}
