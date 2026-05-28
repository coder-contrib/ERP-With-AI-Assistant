import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.read(dioProvider));
});

class InventoryItem {
  final int productId;
  final String productName;
  final String? barcode;
  final String baseUnit;
  final int? categoryId;
  final String purchaseCost;
  final String sellingPrice;
  final bool activeStatus;
  final List<WarehouseStock> warehouseStocks;

  InventoryItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.baseUnit,
    this.categoryId,
    required this.purchaseCost,
    required this.sellingPrice,
    required this.activeStatus,
    required this.warehouseStocks,
  });

  double get totalStock => warehouseStocks.fold(0, (sum, w) => sum + w.quantity);
  double get totalValue => warehouseStocks.fold(0, (sum, w) => sum + (w.quantity * w.avgCost));

  StockStatus get status {
    if (totalStock <= 0) return StockStatus.outOfStock;
    if (totalStock <= 10) return StockStatus.low;
    if (totalStock > 100) return StockStatus.overstock;
    return StockStatus.normal;
  }
}

class WarehouseStock {
  final int warehouseId;
  final double quantity;
  final double avgCost;

  WarehouseStock({required this.warehouseId, required this.quantity, required this.avgCost});

  factory WarehouseStock.fromJson(Map<String, dynamic> json) {
    return WarehouseStock(
      warehouseId: json['warehouse_id'],
      quantity: double.tryParse(json['cached_quantity']?.toString() ?? '0') ?? 0,
      avgCost: double.tryParse(json['cached_avg_cost']?.toString() ?? '0') ?? 0,
    );
  }
}

class WarehouseModel {
  final int warehouseId;
  final String warehouseName;
  final String? location;

  WarehouseModel({required this.warehouseId, required this.warehouseName, this.location});
}

enum StockStatus { normal, low, outOfStock, overstock }

class InventoryRepository {
  final Dio _dio;
  InventoryRepository(this._dio);

  Future<List<Map<String, dynamic>>> getAllStock({int? warehouseId}) async {
    final params = <String, dynamic>{};
    if (warehouseId != null) params['warehouse_id'] = warehouseId;
    final response = await _dio.get('/inventory/stock', queryParameters: params);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getProductStock(int productId) async {
    final response = await _dio.get('/inventory/stock/$productId');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final response = await _dio.get('/products', queryParameters: {'active_only': false});
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOpeningStock({
    required int productId,
    required int warehouseId,
    required double quantity,
    required String unitType,
    required double costPerUnit,
    String? notes,
  }) async {
    final response = await _dio.post('/inventory/opening-stock', data: {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'transaction_type': 'opening_stock',
      'direction': 'in',
      'quantity': quantity,
      'unit_type': unitType,
      'cost_per_unit': costPerUnit,
      'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction({
    required int productId,
    required int warehouseId,
    required String transactionType,
    required String direction,
    required double quantity,
    required String unitType,
    double costPerUnit = 0,
    String? notes,
  }) async {
    final response = await _dio.post('/inventory/transactions', data: {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'transaction_type': transactionType,
      'direction': direction,
      'quantity': quantity,
      'unit_type': unitType,
      'cost_per_unit': costPerUnit,
      'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adjustStock({
    required int productId,
    required int warehouseId,
    required double quantity,
    required String direction,
    required String unitType,
    double costPerUnit = 0,
    String? reason,
  }) async {
    final txType = direction == 'in' ? 'purchase' : 'waste';
    final response = await _dio.post('/inventory/transactions', data: {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'transaction_type': txType,
      'direction': direction,
      'quantity': quantity,
      'unit_type': unitType,
      'cost_per_unit': costPerUnit,
      'notes': reason,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLowStockPrediction({int daysAhead = 7}) async {
    final response = await _dio.get('/ai/predict/low-stock', queryParameters: {'days_ahead': daysAhead});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiChat(String message) async {
    final response = await _dio.post('/ai/chat', data: {
      'session_id': 'inventory_page',
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getNotifications({bool unreadOnly = false}) async {
    final response = await _dio.get('/notifications', queryParameters: {'unread_only': unreadOnly});
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<String> getStockHistory(int productId, String productName) async {
    final response = await _dio.post('/ai/chat', data: {
      'session_id': 'inventory_history_$productId',
      'message': 'Show me the recent stock movement history for product "$productName" (product ID: $productId). Include dates, quantities, and types.',
    });
    return response.data['response']?.toString() ?? 'No history available';
  }

  Future<void> refreshCache() async {
    await _dio.post('/inventory/refresh-cache');
  }

  Future<void> createTransfer({
    required int fromWarehouseId,
    required int toWarehouseId,
    required int productId,
    required double quantity,
    required String unitType,
    String? notes,
  }) async {
    await _dio.post('/transfers', data: {
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'product_id': productId,
      'quantity': quantity,
      'unit_type': unitType,
      'notes': notes,
    });
  }
}
