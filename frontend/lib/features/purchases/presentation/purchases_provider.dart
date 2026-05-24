import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/purchases_repository.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../../products/data/products_repository.dart';

final purchasesProvider = FutureProvider<List<PurchaseInvoiceModel>>((ref) async {
  final repo = ref.read(purchasesRepositoryProvider);
  return repo.getAll();
});

final purchasesSearchProvider = StateProvider<String>((ref) => '');

enum PurchaseStatusFilter { all, paid, partial, unpaid }

final purchasesStatusFilterProvider = StateProvider<PurchaseStatusFilter>((ref) => PurchaseStatusFilter.all);

final purchasesSuppliersProvider = FutureProvider<List<SupplierModel>>((ref) async {
  final repo = ref.read(suppliersRepositoryProvider);
  return repo.getAll();
});

final purchasesProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getAll();
});

final filteredPurchasesProvider = Provider<AsyncValue<List<PurchaseInvoiceModel>>>((ref) {
  final purchasesAsync = ref.watch(purchasesProvider);
  final search = ref.watch(purchasesSearchProvider).toLowerCase();
  final statusFilter = ref.watch(purchasesStatusFilterProvider);
  final suppliersAsync = ref.watch(purchasesSuppliersProvider);

  return purchasesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (purchases) {
      final supplierMap = <int, String>{};
      if (suppliersAsync is AsyncData<List<SupplierModel>>) {
        for (final s in suppliersAsync.value!) {
          supplierMap[s.supplierId] = s.supplierName;
        }
      }

      var filtered = purchases.where((p) {
        if (search.isNotEmpty) {
          final supplierName = supplierMap[p.supplierId]?.toLowerCase() ?? '';
          final matchesInvoice = p.invoiceNumber.toLowerCase().contains(search);
          final matchesSupplier = supplierName.contains(search);
          if (!matchesInvoice && !matchesSupplier) return false;
        }
        switch (statusFilter) {
          case PurchaseStatusFilter.paid:
            return p.isPaid;
          case PurchaseStatusFilter.partial:
            return p.isPartial;
          case PurchaseStatusFilter.unpaid:
            return p.isUnpaid;
          case PurchaseStatusFilter.all:
            return true;
        }
      }).toList();

      return AsyncValue.data(filtered);
    },
  );
});

final purchaseKpisProvider = Provider<Map<String, dynamic>>((ref) {
  final purchasesAsync = ref.watch(purchasesProvider);

  if (purchasesAsync is! AsyncData<List<PurchaseInvoiceModel>>) {
    return {'totalPurchases': 0.0, 'totalPaid': 0.0, 'totalUnpaid': 0.0, 'invoiceCount': 0, 'paidCount': 0, 'unpaidCount': 0};
  }

  final purchases = purchasesAsync.value!;
  double totalPurchases = 0;
  double totalPaid = 0;
  double totalUnpaid = 0;
  int paidCount = 0;
  int unpaidCount = 0;

  for (final p in purchases) {
    totalPurchases += p.total;
    totalPaid += p.paid;
    totalUnpaid += p.remaining;
    if (p.isPaid) paidCount++;
    if (p.isUnpaid) unpaidCount++;
  }

  return {
    'totalPurchases': totalPurchases,
    'totalPaid': totalPaid,
    'totalUnpaid': totalUnpaid,
    'invoiceCount': purchases.length,
    'paidCount': paidCount,
    'unpaidCount': unpaidCount,
  };
});
