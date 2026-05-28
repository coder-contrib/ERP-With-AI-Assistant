import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(dioProvider));
});

class ReportsRepository {
  final Dio _dio;
  ReportsRepository(this._dio);

  Future<Map<String, dynamic>> getDailySales({String? startDate, String? endDate}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/daily-sales', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMonthlyProfit({int? year}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    final response = await _dio.get('/reports/monthly-profit', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTopProducts({String? startDate, String? endDate, int limit = 10}) async {
    final params = <String, dynamic>{'limit': limit};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/top-products', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInventoryValuation({int? warehouseId}) async {
    final params = <String, dynamic>{};
    if (warehouseId != null) params['warehouse_id'] = warehouseId;
    final response = await _dio.get('/reports/inventory-valuation', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerBalances() async {
    final response = await _dio.get('/reports/customer-balances');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSupplierBalances() async {
    final response = await _dio.get('/reports/supplier-balances');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCashFlow({String? startDate, String? endDate}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/cash-flow', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWarehouseStock(int warehouseId) async {
    final response = await _dio.get('/reports/warehouse-stock/$warehouseId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSalesByPeriod({String period = 'day', String? startDate, String? endDate}) async {
    final params = <String, dynamic>{'period': period};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/sales-by-period', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSalesInvoices({String? startDate, String? endDate, String? status, String? paymentMethod}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (status != null) params['status'] = status;
    if (paymentMethod != null) params['payment_method'] = paymentMethod;
    final response = await _dio.get('/reports/sales-invoices', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProductPerformance({String? startDate, String? endDate}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/product-performance', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLowStock({int threshold = 10}) async {
    final response = await _dio.get('/reports/low-stock', queryParameters: {'threshold': threshold});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStockMovement({String? startDate, String? endDate}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/stock-movement', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDeadStock({int days = 30}) async {
    final response = await _dio.get('/reports/dead-stock', queryParameters: {'days': days});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfitLoss({String? startDate, String? endDate}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/profit-loss', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExpenseByCategory({String? startDate, String? endDate}) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final response = await _dio.get('/reports/expense-by-category', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerProfile(int customerId) async {
    final response = await _dio.get('/reports/customer-profile/$customerId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerActivity(int customerId, {int limit = 50}) async {
    final response = await _dio.get('/reports/customer-activity/$customerId', queryParameters: {'limit': limit});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerSegmentation() async {
    final response = await _dio.get('/reports/customer-segmentation');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAiRiskAssessment() async {
    final response = await _dio.get('/reports/ai-risk-assessment');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAiDailySummary() async {
    final response = await _dio.get('/reports/ai-daily-summary');
    return response.data as Map<String, dynamic>;
  }
}
