import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/notifications/presentation/notifications_provider.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userRole = ref.watch(authProvider).token?.role ?? '';

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: collapsed ? 72 : 260,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(right: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.diamond, color: Colors.white, size: 20),
                      ),
                      if (!collapsed) ...[const SizedBox(width: 12), const Text('Ceramic ERP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _navItem(context, ref, '/', Icons.dashboard_rounded, 'Dashboard', collapsed),
                      _navItem(context, ref, '/products', Icons.inventory_2_rounded, 'Products', collapsed),
                      _navItem(context, ref, '/inventory', Icons.warehouse_rounded, 'Inventory', collapsed),
                      _navItem(context, ref, '/sales', Icons.receipt_long_rounded, 'Sales', collapsed),
                      _navItem(context, ref, '/purchases', Icons.shopping_cart_rounded, 'Purchases', collapsed),
                      _navItem(context, ref, '/expenses', Icons.money_off_rounded, 'Expenses', collapsed),
                      _navItem(context, ref, '/customers', Icons.people_rounded, 'Customers', collapsed),
                      _navItem(context, ref, '/suppliers', Icons.local_shipping_rounded, 'Suppliers', collapsed),
                      _navItem(context, ref, '/opening-balances', Icons.account_balance_wallet_rounded, 'Opening Balances', collapsed),
                      _navItem(context, ref, '/reports', Icons.bar_chart_rounded, 'Reports', collapsed),
                      _navItem(context, ref, '/notifications', Icons.notifications_rounded, 'Notifications', collapsed),
                      const Divider(height: 24),
                      _navItem(context, ref, '/voice-ai', Icons.record_voice_over_rounded, 'Voice AI', collapsed, highlight: true),
                      _navItem(context, ref, '/ai', Icons.smart_toy_rounded, 'AI Chat', collapsed),
                      if (userRole == 'admin') ...[                        const Divider(height: 24),
                        _navItem(context, ref, '/ai-audit', Icons.admin_panel_settings_rounded, 'AI Audit', collapsed, highlight: true),
                        _navItem(context, ref, '/ai-analytics', Icons.insights_rounded, 'AI Analytics', collapsed, highlight: true),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    onPressed: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
                    icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: isDark ? AppColors.darkBackground : AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.go('/voice-ai'),
                        icon: const Icon(Icons.record_voice_over_rounded),
                        tooltip: 'Voice AI',
                        style: IconButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                      const SizedBox(width: 4),
                      IconButton(onPressed: () => context.go('/ai'), icon: const Icon(Icons.smart_toy_rounded), tooltip: 'AI Assistant'),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => context.go('/notifications'),
                        icon: ref.watch(unreadCountProvider).when(
                          data: (count) => count > 0
                              ? Badge(label: Text('$count', style: const TextStyle(fontSize: 10)), child: const Icon(Icons.notifications_outlined))
                              : const Icon(Icons.notifications_outlined),
                          loading: () => const Icon(Icons.notifications_outlined),
                          error: (_, __) => const Icon(Icons.notifications_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final current = ref.read(themeModeProvider);
                          ref.read(themeModeProvider.notifier).state = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                        },
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      ),
                      const SizedBox(width: 16),
                      const CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Text('A', style: TextStyle(color: Colors.white, fontSize: 14))),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, String path, IconData icon, String label, bool collapsed, {bool highlight = false}) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isActive = currentPath == path;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(path),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 16 : 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isActive ? AppColors.primary : highlight ? AppColors.primary.withOpacity(0.7) : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                if (!collapsed) ...[const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.primary : highlight ? AppColors.primary.withOpacity(0.8) : null)))],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
