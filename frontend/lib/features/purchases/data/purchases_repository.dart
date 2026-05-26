import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.read(dioProvider));
});

class PurchaseInvoiceModel {
  final int purchaseInvoiceId;
  final int supplierId;
  final String invoiceNumber;
  final String? purchaseDate;
  final String totalAmount;
  final String paidAmount;
  final String remainingAmount;
  final String paymentStatus;

  PurchaseInvoiceModel({
    required this.purchaseInvoiceId,
    required this.supplierId,
    required this.invoiceNumber,
    this.purchaseDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentStatus,
  });

  factory PurchaseInvoiceModel.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceModel(
      purchaseInvoiceId: json['purchase_invoice_id'],
      supplierId: json['supplier_id'],
      invoiceNumber: json['invoice_number'] ?? '',
      purchaseDate: json['purchase_date'],
      totalAmount: json['total_amount']?.toString() ?? '0',
      paidAmount: json['paid_amount']?.toString() ?? '0',
      remainingAmount: json['remaining_amount']?.toString() ?? '0',
      paymentStatus: json['payment_status'] ?? 'unpaid',
    );
  }

  double get total => double.tryParse(totalAmount) ?? 0;
  double get paid => double.tryParse(paidAmount) ?? 0;
  double get remaining => double.tryParse(remainingAmount) ?? 0;
  bool get isPaid => paymentStatus == 'paid';
  bool get isPartial => paymentStatus == 'partial';
  bool get isUnpaid => paymentStatus == 'unpaid';
}

class PurchaseItemModel {
  final int productId;
  final double purchasedQuantity;
  final double purchasePrice;
  final double totalCost;

  PurchaseItemModel({
    required this.productId,
    required this.purchasedQuantity,
    required this.purchasePrice,
    required this.totalCost,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseItemModel(
      productId: json['product_id'],
      purchasedQuantity: double.tryParse(json['purchased_quantity']?.toString() ?? '0') ?? 0,
      purchasePrice: double.tryParse(json['purchase_price']?.toString() ?? '0') ?? 0,
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0,
    );
  }
}

class PurchaseItemDetailModel {
  final int itemId;
  final int productId;
  final String productName;
  final double purchasedQuantity;
  final double purchasePrice;
  final double totalCost;
  final double returnedQuantity;

  PurchaseItemDetailModel({
    required this.itemId,
    required this.productId,
    required this.productName,
    required this.purchasedQuantity,
    required this.purchasePrice,
    required this.totalCost,
    required this.returnedQuantity,
  });

  double get returnableQuantity => purchasedQuantity - returnedQuantity;

  factory PurchaseItemDetailModel.fromJson(Map<String, dynamic> json) {
    return PurchaseItemDetailModel(
      itemId: json['item_id'],
      productId: json['product_id'],
      productName: json['product_name'] ?? 'Unknown',
      purchasedQuantity: double.tryParse(json['purchased_quantity']?.toString() ?? '0') ?? 0,
      purchasePrice: double.tryParse(json['purchase_price']?.toString() ?? '0') ?? 0,
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0,
      returnedQuantity: double.tryParse(json['returned_quantity']?.toString() ?? '0') ?? 0,
    );
  }
}

class PurchaseReturnModel {
  final int returnId;
  final int originalPurchaseInvoiceId;
  final int supplierId;
  final double returnedAmount;
  final String? returnDate;
  final String? notes;

  PurchaseReturnModel({
    required this.returnId,
    required this.originalPurchaseInvoiceId,
    required this.supplierId,
    required this.returnedAmount,
    this.returnDate,
    this.notes,
  });

  factory PurchaseReturnModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReturnModel(
      returnId: json['return_id'],
      originalPurchaseInvoiceId: json['original_purchase_invoice_id'],
      supplierId: json['supplier_id'],
      returnedAmount: double.tryParse(json['returned_amount']?.toString() ?? '0') ?? 0,
      returnDate: json['return_date'],
      notes: json['notes'],
    );
  }
}

class PurchasePaymentModel {
  final int paymentId;
  final double amount;
  final String? paymentDate;
  final String? notes;

  PurchasePaymentModel({
    required this.paymentId,
    required this.amount,
    this.paymentDate,
    this.notes,
  });

  factory PurchasePaymentModel.fromJson(Map<String, dynamic> json) {
    return PurchasePaymentModel(
      paymentId: json['payment_id'],
      amount: double.tryParse(json['payment_amount']?.toString() ?? '0') ?? 0,
      paymentDate: json['payment_date'],
      notes: json['notes'],
    );
  }
}

class PurchasesRepository {
  final Dio _dio;
  PurchasesRepository(this._dio);

  Future<List<PurchaseInvoiceModel>> getAll() async {
    final response = await _dio.get('/purchases');
    return (response.data as List).map((e) => PurchaseInvoiceModel.fromJson(e)).toList();
  }

  Future<PurchaseInvoiceModel> getById(int id) async {
    final response = await _dio.get('/purchases/$id');
    return PurchaseInvoiceModel.fromJson(response.data);
  }

  Future<PurchaseInvoiceModel> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchases', data: data);
    return PurchaseInvoiceModel.fromJson(response.data);
  }

  Future<void> recordPayment(int supplierId, Map<String, dynamic> data) async {
    await _dio.post('/payments/suppliers', data: {
      'supplier_id': supplierId,
      ...data,
    });
  }

  Future<List<PurchaseItemDetailModel>> getItems(int purchaseInvoiceId) async {
    final response = await _dio.get('/purchases/$purchaseInvoiceId/items');
    return (response.data as List).map((e) => PurchaseItemDetailModel.fromJson(e)).toList();
  }

  Future<List<PurchasePaymentModel>> getPayments(int purchaseInvoiceId) async {
    final response = await _dio.get('/purchases/$purchaseInvoiceId/payments');
    return (response.data as List).map((e) => PurchasePaymentModel.fromJson(e)).toList();
  }

  Future<List<PurchaseReturnModel>> getReturns(int purchaseInvoiceId) async {
    final response = await _dio.get('/purchases/$purchaseInvoiceId/returns');
    return (response.data as List).map((e) => PurchaseReturnModel.fromJson(e)).toList();
  }

  Future<PurchaseReturnModel> createReturn(
    int purchaseInvoiceId, {
    required List<Map<String, dynamic>> items,
    double refundAmount = 0,
    String? notes,
    int warehouseId = 1,
  }) async {
    final response = await _dio.post('/purchases/$purchaseInvoiceId/returns', data: {
      'items': items,
      'refund_amount': refundAmount,
      'warehouse_id': warehouseId,
      'notes': notes,
    });
    return PurchaseReturnModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> aiChat(String message) async {
    final response = await _dio.post('/ai/chat', data: {
      'session_id': 'purchases_page',
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }
}
