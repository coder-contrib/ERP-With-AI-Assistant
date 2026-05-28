import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_audit_repository.dart';

final auditFeedProvider = FutureProvider.family<List<AuditFeedItem>, AuditFeedParams>((ref, params) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getFeed(
    limit: params.limit,
    statusFilter: params.statusFilter,
    roleFilter: params.roleFilter,
    categoryFilter: params.categoryFilter,
    channelFilter: params.channelFilter,
  );
});

final auditStatsProvider = FutureProvider<AuditStats>((ref) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getStats(hours: 24);
});

final auditSessionsProvider = FutureProvider<List<AuditSession>>((ref) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getSessions();
});

final auditBlockedProvider = FutureProvider<List<BlockedAction>>((ref) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getBlocked();
});

final auditPerformanceProvider = FutureProvider<List<ToolPerformance>>((ref) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getPerformance();
});

// --- Analytics Providers ---

final latencyAnalyticsProvider = FutureProvider.family<LatencyAnalytics, AnalyticsParams>((ref, params) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getLatencyAnalytics(hours: params.hours, channel: params.channel, role: params.role);
});

final successRatesProvider = FutureProvider.family<SuccessRates, AnalyticsParams>((ref, params) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getSuccessRates(hours: params.hours, channel: params.channel);
});

final roleUsageProvider = FutureProvider.family<List<RoleUsage>, int>((ref, hours) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getRoleUsage(hours: hours);
});

final channelComparisonProvider = FutureProvider.family<List<ChannelStats>, int>((ref, hours) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getChannelComparison(hours: hours);
});

class AuditFeedParams {
  final int limit;
  final String? statusFilter;
  final String? roleFilter;
  final String? categoryFilter;
  final String? channelFilter;

  const AuditFeedParams({
    this.limit = 50,
    this.statusFilter,
    this.roleFilter,
    this.categoryFilter,
    this.channelFilter,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditFeedParams &&
          limit == other.limit &&
          statusFilter == other.statusFilter &&
          roleFilter == other.roleFilter &&
          categoryFilter == other.categoryFilter &&
          channelFilter == other.channelFilter;

  @override
  int get hashCode => Object.hash(limit, statusFilter, roleFilter, categoryFilter, channelFilter);
}

class AnalyticsParams {
  final int hours;
  final String? channel;
  final String? role;

  const AnalyticsParams({this.hours = 24, this.channel, this.role});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsParams && hours == other.hours && channel == other.channel && role == other.role;

  @override
  int get hashCode => Object.hash(hours, channel, role);
}
