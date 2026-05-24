import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.read(dioProvider));
});

class SupplierModel {
  final int supplierId;
  final String supplierName;
  final String? phoneNumber;
  final String? address;
  final String currentBalance;
  final int paymentTerms;
  final String? lastPaymentDate;
  final String? notes;

  SupplierModel({
    required this.supplierId,
    required this.supplierName,
    this.phoneNumber,
    this.address,
    required this.currentBalance,
    required this.paymentTerms,
    this.lastPaymentDate,
    this.notes,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      currentBalance: json['current_balance']?.toString() ?? '0',
      paymentTerms: json['payment_terms'] ?? 0,
      lastPaymentDate: json['last_payment_date'],
      notes: json['notes'],
    );
  }
}

class SuppliersRepository {
  final Dio _dio;
  SuppliersRepository(this._dio);

  Future<List<SupplierModel>> getAll() async {
    final response = await _dio.get('/suppliers');
    return (response.data as List).map((e) => SupplierModel.fromJson(e)).toList();
  }

  Future<SupplierModel> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/suppliers', data: data);
    return SupplierModel.fromJson(response.data);
  }

  Future<SupplierModel> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/suppliers/$id', data: data);
    return SupplierModel.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/suppliers/$id');
  }
}
