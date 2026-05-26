import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(dioProvider));
});

final productsListProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getAll(activeOnly: true);
});

class ProductModel {
  final int productId;
  final String productName;
  final int? categoryId;
  final bool isMeterBased;
  final bool allowPieceSale;
  final bool allowCartonDisplay;
  final String baseUnit;
  final String purchaseCost;
  final String sellingPrice;
  final String? barcode;
  final String? productImage;
  final bool activeStatus;
  final String? createdDate;
  final String? notes;

  ProductModel({
    required this.productId,
    required this.productName,
    this.categoryId,
    required this.isMeterBased,
    required this.allowPieceSale,
    required this.allowCartonDisplay,
    required this.baseUnit,
    required this.purchaseCost,
    required this.sellingPrice,
    this.barcode,
    this.productImage,
    required this.activeStatus,
    this.createdDate,
    this.notes,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productId: json['product_id'],
      productName: json['product_name'],
      categoryId: json['category_id'],
      isMeterBased: json['is_meter_based'] ?? true,
      allowPieceSale: json['allow_piece_sale'] ?? false,
      allowCartonDisplay: json['allow_carton_display'] ?? true,
      baseUnit: json['base_unit'] ?? 'meter',
      purchaseCost: json['purchase_cost_per_meter']?.toString() ?? '0',
      sellingPrice: json['selling_price']?.toString() ?? '0',
      barcode: json['barcode'],
      productImage: json['product_image'],
      activeStatus: json['active_status'] ?? true,
      createdDate: json['created_date'],
      notes: json['notes'],
    );
  }

  double get profitMargin {
    final cost = double.tryParse(purchaseCost) ?? 0;
    final price = double.tryParse(sellingPrice) ?? 0;
    if (price == 0) return 0;
    return ((price - cost) / price * 100);
  }
}

class UnitConversionModel {
  final int conversionId;
  final int productId;
  final String fromUnit;
  final String toUnit;
  final double factor;

  UnitConversionModel({
    required this.conversionId,
    required this.productId,
    required this.fromUnit,
    required this.toUnit,
    required this.factor,
  });

  factory UnitConversionModel.fromJson(Map<String, dynamic> json) {
    return UnitConversionModel(
      conversionId: json['conversion_id'],
      productId: json['product_id'],
      fromUnit: json['from_unit'],
      toUnit: json['to_unit'],
      factor: double.tryParse(json['factor']?.toString() ?? '0') ?? 0,
    );
  }
}

class StockInfo {
  final int productId;
  final int warehouseId;
  final double quantity;
  final double avgCost;

  StockInfo({required this.productId, required this.warehouseId, required this.quantity, required this.avgCost});

  factory StockInfo.fromJson(Map<String, dynamic> json) {
    return StockInfo(
      productId: json['product_id'],
      warehouseId: json['warehouse_id'],
      quantity: double.tryParse(json['cached_quantity']?.toString() ?? '0') ?? 0,
      avgCost: double.tryParse(json['cached_avg_cost']?.toString() ?? '0') ?? 0,
    );
  }
}

class CategoryModel {
  final int categoryId;
  final String categoryName;
  final String? description;

  CategoryModel({required this.categoryId, required this.categoryName, this.description});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      description: json['description'],
    );
  }
}

class ProductsRepository {
  final Dio _dio;
  ProductsRepository(this._dio);

  Future<List<ProductModel>> getAll({bool activeOnly = false}) async {
    final response = await _dio.get('/products', queryParameters: {'active_only': activeOnly});
    return (response.data as List).map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<ProductModel> getById(int id) async {
    final response = await _dio.get('/products/$id');
    return ProductModel.fromJson(response.data);
  }

  Future<ProductModel> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/products', data: data);
    return ProductModel.fromJson(response.data);
  }

  Future<ProductModel> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/products/$id', data: data);
    return ProductModel.fromJson(response.data);
  }

  Future<List<UnitConversionModel>> getConversions(int productId) async {
    final response = await _dio.get('/products/$productId/conversions');
    return (response.data as List).map((e) => UnitConversionModel.fromJson(e)).toList();
  }

  Future<UnitConversionModel> addConversion(int productId, Map<String, dynamic> data) async {
    final response = await _dio.post('/products/$productId/conversions', data: data);
    return UnitConversionModel.fromJson(response.data);
  }

  Future<void> deleteConversion(int productId, int conversionId) async {
    await _dio.delete('/products/$productId/conversions/$conversionId');
  }

  Future<List<StockInfo>> getAllStock() async {
    final response = await _dio.get('/inventory/stock');
    return (response.data as List).map((e) => StockInfo.fromJson(e)).toList();
  }

  Future<List<StockInfo>> getProductStock(int productId) async {
    final response = await _dio.get('/inventory/stock/$productId');
    return (response.data as List).map((e) => StockInfo.fromJson(e)).toList();
  }

  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get('/categories');
    return (response.data as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getDemandForecast(int productId) async {
    final response = await _dio.get('/ai/predict/demand/$productId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> adjustStock({
    required int productId,
    required int warehouseId,
    required double quantity,
    required String unitType,
    required double costPerUnit,
    required String transactionType,
  }) async {
    await _dio.post('/inventory/transactions', data: {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
      'unit_type': unitType,
      'cost_per_unit': costPerUnit,
      'transaction_type': transactionType,
    });
  }

  Future<Map<String, dynamic>> aiChat(String message) async {
    final response = await _dio.post('/ai/chat', data: {
      'session_id': 'products_page',
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }
}
