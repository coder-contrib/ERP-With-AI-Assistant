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
    required this.productId, required this.productName, this.categoryId,
    required this.isMeterBased, required this.allowPieceSale,
    required this.baseUnit, required this.purchaseCost,
    required this.sellingPrice, this.barcode, required this.activeStatus,
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
}

class ProductsRepository {
  final Dio _dio;
  ProductsRepository(this._dio);

  Future<List<ProductModel>> getAll({bool activeOnly = true}) async {
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
}
