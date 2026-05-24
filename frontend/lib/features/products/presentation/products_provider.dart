import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/products_repository.dart';

final productsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getAll();
});

final stockProvider = FutureProvider<List<StockInfo>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getAllStock();
});

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getCategories();
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<int?>((ref) => null);
final stockFilterProvider = StateProvider<StockFilter>((ref) => StockFilter.all);

enum StockFilter { all, inStock, lowStock, outOfStock }

final filteredProductsProvider = Provider<AsyncValue<List<ProductModel>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final category = ref.watch(selectedCategoryProvider);
  final stockFilter = ref.watch(stockFilterProvider);
  final stockAsync = ref.watch(stockProvider);

  return productsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (products) {
      var filtered = products.where((p) {
        if (query.isNotEmpty) {
          final matchesName = p.productName.toLowerCase().contains(query);
          final matchesBarcode = p.barcode?.toLowerCase().contains(query) ?? false;
          if (!matchesName && !matchesBarcode) return false;
        }
        if (category != null && p.categoryId != category) return false;
        return true;
      }).toList();

      if (stockFilter != StockFilter.all && stockAsync is AsyncData<List<StockInfo>>) {
        final stockData = stockAsync.value!;
        filtered = filtered.where((p) {
          final totalStock = stockData
              .where((s) => s.productId == p.productId)
              .fold<double>(0, (sum, s) => sum + s.quantity);
          switch (stockFilter) {
            case StockFilter.inStock:
              return totalStock > 10;
            case StockFilter.lowStock:
              return totalStock > 0 && totalStock <= 10;
            case StockFilter.outOfStock:
              return totalStock <= 0;
            case StockFilter.all:
              return true;
          }
        }).toList();
      }

      return AsyncValue.data(filtered);
    },
  );
});

final productKpisProvider = Provider<Map<String, int>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final stockAsync = ref.watch(stockProvider);

  if (productsAsync is! AsyncData<List<ProductModel>>) {
    return {'total': 0, 'active': 0, 'lowStock': 0, 'outOfStock': 0};
  }

  final products = productsAsync.value!;
  final total = products.length;
  final active = products.where((p) => p.activeStatus).length;

  int lowStock = 0;
  int outOfStock = 0;

  if (stockAsync is AsyncData<List<StockInfo>>) {
    final stockData = stockAsync.value!;
    for (final p in products) {
      final totalQty = stockData
          .where((s) => s.productId == p.productId)
          .fold<double>(0, (sum, s) => sum + s.quantity);
      if (totalQty <= 0) {
        outOfStock++;
      } else if (totalQty <= 10) {
        lowStock++;
      }
    }
  }

  return {'total': total, 'active': active, 'lowStock': lowStock, 'outOfStock': outOfStock};
});
