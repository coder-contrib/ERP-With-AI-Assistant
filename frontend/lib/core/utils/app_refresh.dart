import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/presentation/dashboard_provider.dart';
import '../../features/sales/presentation/sales_provider.dart' show salesProvider, productsListProvider;
import '../../features/expenses/presentation/expenses_provider.dart';
import '../../features/products/presentation/products_provider.dart';
import '../../features/purchases/presentation/purchases_provider.dart';
import '../../features/inventory/presentation/inventory_provider.dart';
import '../../features/inventory/data/inventory_repository.dart';
import '../../features/customers/presentation/customers_provider.dart';
import '../../features/suppliers/presentation/suppliers_provider.dart';
import '../../features/reports/presentation/reports_provider.dart';

void invalidateDashboard(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(dailySalesProvider);
  ref.invalidate(monthlyProfitProvider);
  ref.invalidate(cashFlowProvider);
  ref.invalidate(topProductsProvider);
}

void invalidateAfterSale(WidgetRef ref) {
  ref.invalidate(salesProvider);
  invalidateDashboard(ref);
  ref.invalidate(inventoryDataProvider);
  ref.invalidate(reportsDailySalesProvider);
  ref.invalidate(reportsMonthlyProfitProvider);
  ref.invalidate(reportsTopProductsProvider);
  ref.invalidate(reportsCustomerBalancesProvider);
  ref.invalidate(reportsCashFlowProvider);
}

void invalidateAfterExpense(WidgetRef ref) {
  ref.invalidate(expensesProvider);
  ref.invalidate(expensesSummaryProvider);
  invalidateDashboard(ref);
  ref.invalidate(reportsCashFlowProvider);
  ref.invalidate(reportsMonthlyProfitProvider);
}

void invalidateAfterPurchase(WidgetRef ref) {
  ref.invalidate(purchasesProvider);
  ref.invalidate(productsProvider);
  ref.invalidate(productsListProvider);
  invalidateDashboard(ref);
  ref.invalidate(inventoryDataProvider);
  ref.invalidate(reportsCashFlowProvider);
  ref.invalidate(reportsSupplierBalancesProvider);
}

void invalidateAfterInventoryChange(WidgetRef ref) {
  ref.invalidate(inventoryDataProvider);
  invalidateDashboard(ref);
  ref.invalidate(reportsInventoryProvider);
}

Future<void> refreshInventory(WidgetRef ref) async {
  final repo = ref.read(inventoryRepositoryProvider);
  await repo.refreshCache();
  invalidateAfterInventoryChange(ref);
}

void invalidateAfterProductChange(WidgetRef ref) {
  ref.invalidate(productsProvider);
  ref.invalidate(productsListProvider);
  invalidateDashboard(ref);
  ref.invalidate(reportsTopProductsProvider);
  ref.invalidate(reportsInventoryProvider);
}

void invalidateAfterPayment(WidgetRef ref) {
  ref.invalidate(salesProvider);
  invalidateDashboard(ref);
  ref.invalidate(reportsCashFlowProvider);
  ref.invalidate(reportsCustomerBalancesProvider);
}

void invalidateAfterCustomerChange(WidgetRef ref) {
  ref.invalidate(customersProvider);
  ref.invalidate(reportsCustomerBalancesProvider);
}

void invalidateAfterSupplierChange(WidgetRef ref) {
  ref.invalidate(suppliersProvider);
  ref.invalidate(reportsSupplierBalancesProvider);
}
