import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final openingBalanceRepositoryProvider = Provider<OpeningBalanceRepository>((ref) {
  return OpeningBalanceRepository(ref.read(dioProvider));
});

class OpeningBalanceRepository {
  final Dio _dio;
  OpeningBalanceRepository(this._dio);

  Future<Map<String, dynamic>> createCustomerBalance({
    required int customerId,
    required double amount,
    required String balanceType,
    String? notes,
  }) async {
    final response = await _dio.post('/opening-balances/customer', data: {
      'customer_id': customerId,
      'amount': amount,
      'balance_type': balanceType,
      'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSupplierBalance({
    required int supplierId,
    required double amount,
    required String balanceType,
    String? notes,
  }) async {
    final response = await _dio.post('/opening-balances/supplier', data: {
      'supplier_id': supplierId,
      'amount': amount,
      'balance_type': balanceType,
      'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCashBalance({
    required double amount,
    required String accountName,
    String? notes,
  }) async {
    final response = await _dio.post('/opening-balances/cash', data: {
      'account_name': accountName,
      'amount': amount,
      'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOpeningBalances({String? entityType}) async {
    final params = <String, dynamic>{};
    if (entityType != null) params['entity_type'] = entityType;
    final response = await _dio.get('/opening-balances', queryParameters: params);
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
