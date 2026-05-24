import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../customers/data/customers_repository.dart';
import '../../products/data/products_repository.dart';
import '../data/sales_repository.dart';

final salesProvider = FutureProvider<List<SalesInvoiceModel>>((ref) async {
  final repo = ref.read(salesRepositoryProvider);
  return repo.getAll();
});

final salesSearchProvider = StateProvider<String>((ref) => '');
final salesStatusFilterProvider = StateProvider<PaymentStatusFilter>((ref) => PaymentStatusFilter.all);
final salesTypeFilterProvider = StateProvider<InvoiceTypeFilter>((ref) => InvoiceTypeFilter.all);

enum PaymentStatusFilter { all, paid, partial, unpaid }
enum InvoiceTypeFilter { all, cash, credit }

final filteredSalesProvider = Provider<AsyncValue<List<SalesInvoiceModel>>>((ref) {
  final salesAsync = ref.watch(salesProvider);
  final search = ref.watch(salesSearchProvider).toLowerCase();
  final statusFilter = ref.watch(salesStatusFilterProvider);
  final typeFilter = ref.watch(salesTypeFilterProvider);
  final customersAsync = ref.watch(customersProvider);

  return salesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (invoices) {
      final customerMap = <int, String>{};
      customersAsync.whenData((customers) {
        for (final c in customers) {
          customerMap[c.customerId] = c.customerName;
        }
      });

      var filtered = invoices.where((inv) {
        if (search.isNotEmpty) {
          final customerName = customerMap[inv.customerId]?.toLowerCase() ?? '';
          if (!inv.invoiceNumber.toLowerCase().contains(search) &&
              !customerName.contains(search)) {
            return false;
          }
        }
        if (statusFilter != PaymentStatusFilter.all) {
          if (statusFilter == PaymentStatusFilter.paid && !inv.isPaid) return false;
          if (statusFilter == PaymentStatusFilter.partial && !inv.isPartial) return false;
          if (statusFilter == PaymentStatusFilter.unpaid && !inv.isUnpaid) return false;
        }
        if (typeFilter != InvoiceTypeFilter.all) {
          if (typeFilter == InvoiceTypeFilter.cash && !inv.isCash) return false;
          if (typeFilter == InvoiceTypeFilter.credit && !inv.isCredit) return false;
        }
        return true;
      }).toList();

      filtered.sort((a, b) {
        if (a.invoiceDate != null && b.invoiceDate != null) {
          return b.invoiceDate!.compareTo(a.invoiceDate!);
        }
        return b.invoiceId.compareTo(a.invoiceId);
      });

      return AsyncValue.data(filtered);
    },
  );
});

final salesKpisProvider = Provider<SalesKpis>((ref) {
  final salesAsync = ref.watch(salesProvider);
  return salesAsync.when(
    loading: () => SalesKpis.empty(),
    error: (_, __) => SalesKpis.empty(),
    data: (invoices) {
      double totalSales = 0;
      double totalPaid = 0;
      double totalUnpaid = 0;
      int cashCount = 0;
      int creditCount = 0;

      for (final inv in invoices) {
        totalSales += inv.total;
        totalPaid += inv.paid;
        totalUnpaid += inv.remaining;
        if (inv.isCash) cashCount++;
        if (inv.isCredit) creditCount++;
      }

      final total = invoices.length;
      final cashPct = total > 0 ? (cashCount / total * 100) : 0.0;
      final creditPct = total > 0 ? (creditCount / total * 100) : 0.0;

      return SalesKpis(
        totalSales: totalSales,
        totalPaid: totalPaid,
        totalUnpaid: totalUnpaid,
        invoiceCount: total,
        cashPercentage: cashPct,
        creditPercentage: creditPct,
        paidCount: invoices.where((i) => i.isPaid).length,
        partialCount: invoices.where((i) => i.isPartial).length,
        unpaidCount: invoices.where((i) => i.isUnpaid).length,
      );
    },
  );
});

class SalesKpis {
  final double totalSales;
  final double totalPaid;
  final double totalUnpaid;
  final int invoiceCount;
  final double cashPercentage;
  final double creditPercentage;
  final int paidCount;
  final int partialCount;
  final int unpaidCount;

  SalesKpis({
    required this.totalSales,
    required this.totalPaid,
    required this.totalUnpaid,
    required this.invoiceCount,
    required this.cashPercentage,
    required this.creditPercentage,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
  });

  factory SalesKpis.empty() => SalesKpis(
    totalSales: 0, totalPaid: 0, totalUnpaid: 0,
    invoiceCount: 0, cashPercentage: 0, creditPercentage: 0,
    paidCount: 0, partialCount: 0, unpaidCount: 0,
  );
}

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final repo = ref.read(customersRepositoryProvider);
  return repo.getAll();
});

final productsListProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.getAll();
});
