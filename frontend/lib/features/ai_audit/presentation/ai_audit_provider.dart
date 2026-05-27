import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_audit_repository.dart';

final auditFeedProvider = FutureProvider.family<List<AuditFeedItem>, AuditFeedParams>((ref, params) async {
  final repo = ref.read(aiAuditRepositoryProvider);
  return repo.getFeed(
    limit: params.limit,
    statusFilter: params.statusFilter,
    roleFilter: params.roleFilter,
    categoryFilter: params.categoryFilter,
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

class AuditFeedParams {
  final int limit;
  final String? statusFilter;
  final String? roleFilter;
  final String? categoryFilter;

  const AuditFeedParams({
    this.limit = 50,
    this.statusFilter,
    this.roleFilter,
    this.categoryFilter,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditFeedParams &&
          limit == other.limit &&
          statusFilter == other.statusFilter &&
          roleFilter == other.roleFilter &&
          categoryFilter == other.categoryFilter;

  @override
  int get hashCode => Object.hash(limit, statusFilter, roleFilter, categoryFilter);
}
