import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';

final inventoryDataProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final repo = ref.read(inventoryRepositoryProvider);
  final stockData = await repo.getAllStock();
  final productsData = await repo.getAllProducts();

  final stockByProduct = <int, List<WarehouseStock>>{};
  for (final s in stockData) {
    final pid = s['product_id'] as int;
    stockByProduct.putIfAbsent(pid, () => []);
    stockByProduct[pid]!.add(WarehouseStock.fromJson(s));
  }

  return productsData.map((p) {
    final pid = p['product_id'] as int;
    return InventoryItem(
      productId: pid,
      productName: p['product_name'] ?? '',
      barcode: p['barcode'],
      baseUnit: p['base_unit'] ?? 'meter',
      categoryId: p['category_id'],
      purchaseCost: p['purchase_cost_per_meter']?.toString() ?? '0',
      sellingPrice: p['selling_price']?.toString() ?? '0',
      activeStatus: p['active_status'] ?? true,
      warehouseStocks: stockByProduct[pid] ?? [],
    );
  }).toList();
});

final inventorySearchProvider = StateProvider<String>((ref) => '');
final selectedWarehouseProvider = StateProvider<int?>((ref) => null);
final inventoryStatusFilterProvider = StateProvider<StockStatus?>((ref) => null);

final filteredInventoryProvider = Provider<AsyncValue<List<InventoryItem>>>((ref) {
  final dataAsync = ref.watch(inventoryDataProvider);
  final search = ref.watch(inventorySearchProvider).toLowerCase();
  final warehouse = ref.watch(selectedWarehouseProvider);
  final statusFilter = ref.watch(inventoryStatusFilterProvider);

  return dataAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (items) {
      var filtered = items.where((item) {
        if (search.isNotEmpty) {
          final matchesName = item.productName.toLowerCase().contains(search);
          final matchesBarcode = item.barcode?.toLowerCase().contains(search) ?? false;
          if (!matchesName && !matchesBarcode) return false;
        }
        if (warehouse != null) {
          final hasStock = item.warehouseStocks.any((w) => w.warehouseId == warehouse && w.quantity > 0);
          if (!hasStock) return false;
        }
        if (statusFilter != null && item.status != statusFilter) return false;
        return true;
      }).toList();

      filtered.sort((a, b) {
        final aOrder = a.status == StockStatus.outOfStock ? 0 : a.status == StockStatus.low ? 1 : 2;
        final bOrder = b.status == StockStatus.outOfStock ? 0 : b.status == StockStatus.low ? 1 : 2;
        return aOrder.compareTo(bOrder);
      });

      return AsyncValue.data(filtered);
    },
  );
});

final inventoryKpisProvider = Provider<Map<String, dynamic>>((ref) {
  final dataAsync = ref.watch(inventoryDataProvider);
  if (dataAsync is! AsyncData<List<InventoryItem>>) {
    return {'totalValue': 0.0, 'inStock': 0, 'lowStock': 0, 'outOfStock': 0, 'totalItems': 0};
  }
  final items = dataAsync.value!;
  final totalValue = items.fold<double>(0, (sum, i) => sum + i.totalValue);
  final inStock = items.where((i) => i.status == StockStatus.normal || i.status == StockStatus.overstock).length;
  final lowStock = items.where((i) => i.status == StockStatus.low).length;
  final outOfStock = items.where((i) => i.status == StockStatus.outOfStock).length;

  return {
    'totalValue': totalValue,
    'inStock': inStock,
    'lowStock': lowStock,
    'outOfStock': outOfStock,
    'totalItems': items.length,
  };
});

final warehouseListProvider = Provider<List<WarehouseModel>>((ref) {
  final dataAsync = ref.watch(inventoryDataProvider);
  if (dataAsync is! AsyncData<List<InventoryItem>>) return [];
  final items = dataAsync.value!;
  final ids = <int>{};
  for (final item in items) {
    for (final ws in item.warehouseStocks) {
      ids.add(ws.warehouseId);
    }
  }
  return ids.map((id) => WarehouseModel(
    warehouseId: id,
    warehouseName: 'Warehouse #$id',
    location: null,
  )).toList();
});
