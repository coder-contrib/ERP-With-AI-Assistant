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
}
