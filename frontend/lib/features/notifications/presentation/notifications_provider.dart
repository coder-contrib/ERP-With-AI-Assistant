import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notifications_repository.dart';

final _demoNotifications = [
  NotificationModel(notificationId: 1, notificationType: 'low_stock', severity: 'warning', title: 'Low Stock Alert', message: 'Product "Ceramic Tile 60x60 White" has fallen below minimum stock level (3 units remaining)', isRead: false, createdDate: DateTime.now().subtract(const Duration(minutes: 12))),
  NotificationModel(notificationId: 2, notificationType: 'credit_limit', severity: 'critical', title: 'Credit Limit Exceeded', message: 'Customer "Al-Noor Trading" has exceeded their credit limit by EGP 15,200', isRead: false, createdDate: DateTime.now().subtract(const Duration(hours: 2))),
  NotificationModel(notificationId: 3, notificationType: 'overdue_payment', severity: 'warning', title: 'Overdue Supplier Payment', message: 'Payment to "Delta Ceramics Factory" is 7 days overdue (Invoice #PO-2024-089)', isRead: false, createdDate: DateTime.now().subtract(const Duration(hours: 5))),
  NotificationModel(notificationId: 4, notificationType: 'low_stock', severity: 'critical', title: 'Out of Stock', message: 'Product "Marble Border 10x30 Gold" is completely out of stock across all warehouses', isRead: false, createdDate: DateTime.now().subtract(const Duration(hours: 8))),
  NotificationModel(notificationId: 5, notificationType: 'daily_reminder', severity: 'info', title: 'Daily Closing Reminder', message: 'Remember to review today\'s sales and close the register before end of shift', isRead: true, createdDate: DateTime.now().subtract(const Duration(days: 1))),
  NotificationModel(notificationId: 6, notificationType: 'credit_limit', severity: 'warning', title: 'Credit Limit Warning', message: 'Customer "Pyramid Interiors" is at 85% of their credit limit (EGP 42,500 / EGP 50,000)', isRead: true, createdDate: DateTime.now().subtract(const Duration(days: 1, hours: 3))),
  NotificationModel(notificationId: 7, notificationType: 'low_stock', severity: 'info', title: 'Stock Replenished', message: 'Product "Porcelain Floor Tile 80x80 Grey" stock has been replenished to 150 units', isRead: true, createdDate: DateTime.now().subtract(const Duration(days: 2))),
];

final notificationsProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final repo = ref.read(notificationsRepositoryProvider);
  try {
    return await repo.getAll();
  } on DioException {
    return _demoNotifications;
  }
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(notificationsRepositoryProvider);
  try {
    return await repo.getUnreadCount();
  } on DioException {
    return _demoNotifications.where((n) => !n.isRead).length;
  }
});

final notificationFilterProvider = StateProvider<NotificationFilter>((ref) => NotificationFilter.all);
final severityFilterProvider = StateProvider<String?>((ref) => null);

enum NotificationFilter { all, unread, read }

final filteredNotificationsProvider = Provider.autoDispose<AsyncValue<List<NotificationModel>>>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  final filter = ref.watch(notificationFilterProvider);
  final severity = ref.watch(severityFilterProvider);

  return notificationsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (notifications) {
      var filtered = notifications.where((n) {
        if (filter == NotificationFilter.unread && n.isRead) return false;
        if (filter == NotificationFilter.read && !n.isRead) return false;
        if (severity != null && n.severity != severity) return false;
        return true;
      }).toList();
      return AsyncValue.data(filtered);
    },
  );
});
