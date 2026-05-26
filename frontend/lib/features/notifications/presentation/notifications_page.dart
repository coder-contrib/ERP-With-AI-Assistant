import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/notifications_repository.dart';
import 'notifications_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredNotificationsProvider);
    final filter = ref.watch(notificationFilterProvider);
    final severity = ref.watch(severityFilterProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  unreadAsync.when(
                    data: (count) => Text('$count unread notification${count == 1 ? '' : 's'}', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 14)),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _runChecks(context, ref),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check Alerts'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _markAllRead(context, ref),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark All Read'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters
          Row(
            children: [
              _FilterChip(label: 'All', selected: filter == NotificationFilter.all, onTap: () => ref.read(notificationFilterProvider.notifier).state = NotificationFilter.all),
              const SizedBox(width: 8),
              _FilterChip(label: 'Unread', selected: filter == NotificationFilter.unread, onTap: () => ref.read(notificationFilterProvider.notifier).state = NotificationFilter.unread),
              const SizedBox(width: 8),
              _FilterChip(label: 'Read', selected: filter == NotificationFilter.read, onTap: () => ref.read(notificationFilterProvider.notifier).state = NotificationFilter.read),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: isDark ? AppColors.darkBorder : AppColors.border),
              const SizedBox(width: 16),
              _FilterChip(label: 'Critical', selected: severity == 'critical', color: AppColors.error, onTap: () => ref.read(severityFilterProvider.notifier).state = severity == 'critical' ? null : 'critical'),
              const SizedBox(width: 8),
              _FilterChip(label: 'Warning', selected: severity == 'warning', color: AppColors.warning, onTap: () => ref.read(severityFilterProvider.notifier).state = severity == 'warning' ? null : 'warning'),
              const SizedBox(width: 8),
              _FilterChip(label: 'Info', selected: severity == 'info', color: AppColors.info, onTap: () => ref.read(severityFilterProvider.notifier).state = severity == 'info' ? null : 'info'),
            ],
          ),
          const SizedBox(height: 20),

          // Notifications List
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(error: e.toString(), onRetry: () => ref.invalidate(notificationsProvider)),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return _EmptyState(filter: filter);
                }
                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _NotificationCard(
                    notification: notifications[index],
                    onMarkRead: () => _markRead(ref, notifications[index].notificationId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markRead(WidgetRef ref, int notificationId) async {
    final repo = ref.read(notificationsRepositoryProvider);
    await repo.markAsRead(notificationId);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notificationsRepositoryProvider);
    await repo.markAllAsRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read'), duration: Duration(seconds: 2)));
    }
  }

  Future<void> _runChecks(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notificationsRepositoryProvider);
    try {
      final result = await repo.runChecks();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      if (context.mounted) {
        final newAlerts = result['new_notifications'] as Map<String, dynamic>? ?? {};
        final total = (newAlerts['low_stock_alerts'] as int? ?? 0) + (newAlerts['credit_limit_exceeded'] as int? ?? 0) + (newAlerts['overdue_supplier_payments'] as int? ?? 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check complete: $total new alert${total == 1 ? '' : 's'} found'), duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? activeColor : (isDark ? AppColors.darkBorder : AppColors.border)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? activeColor : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onMarkRead;

  const _NotificationCard({required this.notification, required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: notification.isRead
            ? (isDark ? AppColors.darkSurface : AppColors.surface)
            : (isDark ? AppColors.primary.withOpacity(0.05) : AppColors.primary.withOpacity(0.02)),
        border: Border.all(color: notification.isRead ? (isDark ? AppColors.darkBorder : AppColors.border) : AppColors.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: notification.isRead ? null : onMarkRead,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Severity icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_severityIcon, color: _severityColor, size: 20),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!notification.isRead)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                          Expanded(
                            child: Text(notification.title, style: TextStyle(fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600, fontSize: 14)),
                          ),
                          _SeverityBadge(severity: notification.severity),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(notification.message, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(_formatDate(notification.createdDate), style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary)),
                          const SizedBox(width: 12),
                          _TypeBadge(type: notification.notificationType),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onMarkRead,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    tooltip: 'Mark as read',
                    style: IconButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _severityColor {
    switch (notification.severity) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  IconData get _severityIcon {
    switch (notification.severity) {
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = severity == 'critical' ? AppColors.error : severity == 'warning' ? AppColors.warning : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = type.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBorder.withOpacity(0.5) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final NotificationFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String message;
    IconData icon;
    switch (filter) {
      case NotificationFilter.unread:
        message = 'No unread notifications';
        icon = Icons.mark_email_read_rounded;
        break;
      case NotificationFilter.read:
        message = 'No read notifications';
        icon = Icons.notifications_none_rounded;
        break;
      default:
        message = 'No notifications yet';
        icon = Icons.notifications_off_rounded;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Run "Check Alerts" to scan for low stock, credit limits, and overdue payments', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load notifications', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
        ],
      ),
    );
  }
}
