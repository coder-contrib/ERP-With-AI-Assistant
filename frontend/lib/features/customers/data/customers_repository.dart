import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.read(dioProvider));
});

class CustomerModel {
  final int customerId;
  final String customerName;
  final String? phoneNumber;
  final String? address;
  final String currentBalance;
  final String creditLimit;
  final int paymentTerms;
  final String? notes;
  final String? createdDate;

  CustomerModel({
    required this.customerId,
    required this.customerName,
    this.phoneNumber,
    this.address,
    required this.currentBalance,
    required this.creditLimit,
    required this.paymentTerms,
    this.notes,
    this.createdDate,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      customerId: json['customer_id'],
      customerName: json['customer_name'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      currentBalance: json['current_balance']?.toString() ?? '0',
      creditLimit: json['credit_limit']?.toString() ?? '0',
      paymentTerms: json['payment_terms'] ?? 0,
      notes: json['notes'],
      createdDate: json['created_date'],
    );
  }
}

class CustomersRepository {
  final Dio _dio;
  CustomersRepository(this._dio);

  Future<List<CustomerModel>> getAll() async {
    final response = await _dio.get('/customers');
    return (response.data as List).map((e) => CustomerModel.fromJson(e)).toList();
  }

  Future<CustomerModel> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/customers', data: data);
    return CustomerModel.fromJson(response.data);
  }

  Future<CustomerModel> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/customers/$id', data: data);
    return CustomerModel.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/customers/$id');
  }
}
