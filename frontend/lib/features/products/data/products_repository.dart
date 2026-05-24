import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(dioProvider));
});

class ProductModel {
  final int productId;
  final String productName;
  final int? categoryId;
  final bool isMeterBased;
  final bool allowPieceSale;
  final String baseUnit;
  final String purchaseCost;
  final String sellingPrice;
  final String? barcode;
  final bool activeStatus;

  ProductModel({
    required this.productId,
    required this.productName,
    this.categoryId,
    required this.isMeterBased,
    required this.allowPieceSale,
    required this.baseUnit,
    required this.purchaseCost,
    required this.sellingPrice,
    this.barcode,
    required this.activeStatus,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productId: json['product_id'],
      productName: json['product_name'],
      categoryId: json['category_id'],
      isMeterBased: json['is_meter_based'] ?? true,
      allowPieceSale: json['allow_piece_sale'] ?? false,
      baseUnit: json['base_unit'] ?? 'meter',
      purchaseCost: json['purchase_cost_per_meter']?.toString() ?? '0',
      sellingPrice: json['selling_price']?.toString() ?? '0',
      barcode: json['barcode'],
      activeStatus: json['active_status'] ?? true,
    );
  }

  double get profitMargin {
    final cost = double.tryParse(purchaseCost) ?? 0;
    final price = double.tryParse(sellingPrice) ?? 0;
    if (price == 0) return 0;
    return ((price - cost) / price * 100);
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

  Future<Map<String, dynamic>> aiChat(String message) async {
    final response = await _dio.post('/ai/chat', data: {
      'session_id': 'products_page',
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }
}
