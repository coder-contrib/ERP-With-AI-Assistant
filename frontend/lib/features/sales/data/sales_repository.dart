import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.read(dioProvider));
});

class SalesInvoiceModel {
  final int invoiceId;
  final int? customerId;
  final String invoiceNumber;
  final String invoiceType;
  final String? invoiceDate;
  final String totalAmount;
  final String discountAmount;
  final String paidAmount;
  final String remainingAmount;
  final String paymentStatus;
  final int warehouseId;

  SalesInvoiceModel({
    required this.invoiceId,
    this.customerId,
    required this.invoiceNumber,
    required this.invoiceType,
    this.invoiceDate,
    required this.totalAmount,
    required this.discountAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentStatus,
    required this.warehouseId,
  });

  factory SalesInvoiceModel.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceModel(
      invoiceId: json['invoice_id'],
      customerId: json['customer_id'],
      invoiceNumber: json['invoice_number'] ?? '',
      invoiceType: json['invoice_type'] ?? 'cash',
      invoiceDate: json['invoice_date'],
      totalAmount: json['total_amount']?.toString() ?? '0',
      discountAmount: json['discount_amount']?.toString() ?? '0',
      paidAmount: json['paid_amount']?.toString() ?? '0',
      remainingAmount: json['remaining_amount']?.toString() ?? '0',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      warehouseId: json['warehouse_id'] ?? 1,
    );
  }

  double get total => double.tryParse(totalAmount) ?? 0;
  double get paid => double.tryParse(paidAmount) ?? 0;
  double get remaining => double.tryParse(remainingAmount) ?? 0;
  double get discount => double.tryParse(discountAmount) ?? 0;

  bool get isPaid => paymentStatus == 'paid';
  bool get isPartial => paymentStatus == 'partial';
  bool get isUnpaid => paymentStatus == 'unpaid';
  bool get isCash => invoiceType == 'cash';
  bool get isCredit => invoiceType == 'credit';
}

class SalesItemModel {
  final int itemId;
  final int productId;
  final String soldQuantity;
  final String unitType;
  final String unitPrice;
  final String costAtSale;
  final String discount;
  final String totalPrice;

  SalesItemModel({
    required this.itemId,
    required this.productId,
    required this.soldQuantity,
    required this.unitType,
    required this.unitPrice,
    required this.costAtSale,
    required this.discount,
    required this.totalPrice,
  });

  factory SalesItemModel.fromJson(Map<String, dynamic> json) {
    return SalesItemModel(
      itemId: json['item_id'] ?? 0,
      productId: json['product_id'],
      soldQuantity: json['sold_quantity']?.toString() ?? '0',
      unitType: json['unit_type'] ?? 'meter',
      unitPrice: json['unit_price']?.toString() ?? '0',
      costAtSale: json['cost_at_sale']?.toString() ?? '0',
      discount: json['discount']?.toString() ?? '0',
      totalPrice: json['total_price']?.toString() ?? '0',
    );
  }
}

class SalesRepository {
  final Dio _dio;
  SalesRepository(this._dio);

  Future<List<SalesInvoiceModel>> getAll() async {
    final response = await _dio.get('/sales');
    return (response.data as List).map((e) => SalesInvoiceModel.fromJson(e)).toList();
  }

  Future<SalesInvoiceModel> getById(int id) async {
    final response = await _dio.get('/sales/$id');
    return SalesInvoiceModel.fromJson(response.data);
  }

  Future<SalesInvoiceModel> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales', data: data);
    return SalesInvoiceModel.fromJson(response.data);
  }

  Future<void> recordPayment({required int customerId, int? invoiceId, required double amount, String? notes}) async {
    await _dio.post('/payments/customers', data: {
      'customer_id': customerId,
      'related_invoice_id': invoiceId,
      'payment_amount': amount,
      'notes': notes,
    });
  }

  Future<String> aiChat(String message) async {
    final response = await _dio.post('/ai/chat', data: {'message': message});
    return response.data['response'] ?? response.data['message'] ?? 'No response';
  }
}
