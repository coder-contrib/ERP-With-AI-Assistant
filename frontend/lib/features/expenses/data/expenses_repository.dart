import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.read(dioProvider));
});

class ExpenseModel {
  final int expenseId;
  final String expenseCategory;
  final String expenseName;
  final double amount;
  final String? paymentMethod;
  final String? paidBy;
  final String? receiptNumber;
  final String? expenseDate;
  final String? notes;

  ExpenseModel({
    required this.expenseId,
    required this.expenseCategory,
    required this.expenseName,
    required this.amount,
    this.paymentMethod,
    this.paidBy,
    this.receiptNumber,
    this.expenseDate,
    this.notes,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      expenseId: json['expense_id'] ?? 0,
      expenseCategory: json['expense_category'] ?? '',
      expenseName: json['expense_name'] ?? '',
      amount: (json['amount'] is String) ? double.parse(json['amount']) : (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'],
      paidBy: json['paid_by'],
      receiptNumber: json['receipt_number'],
      expenseDate: json['expense_date'],
      notes: json['notes'],
    );
  }
}

class ExpenseSummaryModel {
  final double totalToday;
  final double totalMonth;
  final String? highestCategory;
  final double highestCategoryAmount;
  final int expenseCount;

  ExpenseSummaryModel({
    required this.totalToday,
    required this.totalMonth,
    this.highestCategory,
    required this.highestCategoryAmount,
    required this.expenseCount,
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseSummaryModel(
      totalToday: _toDouble(json['total_today']),
      totalMonth: _toDouble(json['total_month']),
      highestCategory: json['highest_category'],
      highestCategoryAmount: _toDouble(json['highest_category_amount']),
      expenseCount: json['expense_count'] ?? 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is String) return double.tryParse(v) ?? 0;
    return v.toDouble();
  }
}

class ExpenseCategoryModel {
  final int categoryId;
  final String name;
  final String? description;

  ExpenseCategoryModel({required this.categoryId, required this.name, this.description});

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      categoryId: json['category_id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
    );
  }
}

class ExpensesRepository {
  final Dio _dio;
  ExpensesRepository(this._dio);

  Future<List<ExpenseModel>> getAll({
    String? dateFrom,
    String? dateTo,
    String? category,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (category != null) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/expenses', queryParameters: params);
    return (response.data as List).map((e) => ExpenseModel.fromJson(e)).toList();
  }

  Future<ExpenseSummaryModel> getSummary() async {
    final response = await _dio.get('/expenses/summary');
    return ExpenseSummaryModel.fromJson(response.data);
  }

  Future<List<ExpenseCategoryModel>> getCategories() async {
    final response = await _dio.get('/expenses/categories');
    return (response.data as List).map((e) => ExpenseCategoryModel.fromJson(e)).toList();
  }

  Future<ExpenseModel> create({
    required String category,
    required String name,
    required double amount,
    String paymentMethod = 'cash',
    String? paidBy,
    String? receiptNumber,
    String? notes,
  }) async {
    final response = await _dio.post('/expenses', data: {
      'expense_category': category,
      'expense_name': name,
      'amount': amount,
      'payment_method': paymentMethod,
      'paid_by': paidBy,
      'receipt_number': receiptNumber,
      'notes': notes,
    });
    return ExpenseModel.fromJson(response.data);
  }

  Future<void> delete(int expenseId) async {
    await _dio.delete('/expenses/$expenseId');
  }

  Future<ExpenseCategoryModel> createCategory({required String name, String? description}) async {
    final response = await _dio.post('/expenses/categories', data: {
      'name': name,
      'description': description,
    });
    return ExpenseCategoryModel.fromJson(response.data);
  }
}
