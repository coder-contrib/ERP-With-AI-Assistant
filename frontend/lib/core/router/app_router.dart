import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/suppliers/presentation/suppliers_page.dart';
import '../../features/sales/presentation/sales_page.dart';
import '../../features/purchases/presentation/purchases_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/ai_assistant/presentation/ai_assistant_page.dart';
import '../../shared/layouts/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsPage()),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersPage()),
          GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersPage()),
          GoRoute(path: '/sales', builder: (_, __) => const SalesPage()),
          GoRoute(path: '/purchases', builder: (_, __) => const PurchasesPage()),
          GoRoute(path: '/inventory', builder: (_, __) => const InventoryPage()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
          GoRoute(path: '/ai', builder: (_, __) => const AIAssistantPage()),
        ],
      ),
    ],
  );
});
