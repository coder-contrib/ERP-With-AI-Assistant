import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final aiAuditRepositoryProvider = Provider<AIAuditRepository>((ref) {
  return AIAuditRepository(ref.read(dioProvider));
});

class AuditFeedItem {
  final String id;
  final String timestamp;
  final String status;
  final String severity;
  final String icon;
  final String tool;
  final String toolLabel;
  final String category;
  final String role;
  final String sessionId;
  final String description;
  final int executionMs;
  final Map<String, dynamic> details;

  AuditFeedItem({
    required this.id,
    required this.timestamp,
    required this.status,
    required this.severity,
    required this.icon,
    required this.tool,
    required this.toolLabel,
    required this.category,
    required this.role,
    required this.sessionId,
    required this.description,
    required this.executionMs,
    required this.details,
  });

  factory AuditFeedItem.fromJson(Map<String, dynamic> json) {
    return AuditFeedItem(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      status: json['status'] ?? 'executed',
      severity: json['severity'] ?? 'success',
      icon: json['icon'] ?? 'executed',
      tool: json['tool'] ?? '',
      toolLabel: json['tool_label'] ?? '',
      category: json['category'] ?? '',
      role: json['role'] ?? '',
      sessionId: json['session_id'] ?? '',
      description: json['description'] ?? '',
      executionMs: json['execution_ms'] ?? 0,
      details: json['details'] ?? {},
    );
  }
}

class AuditStats {
  final Map<String, int> byStatus;
  final Map<String, int> byRole;
  final Map<String, int> byCategory;
  final Map<String, int> byTool;
  final int totalCalls;
  final double avgExecutionMs;
  final double maxExecutionMs;
  final List<Map<String, dynamic>> timeline;
  final int periodHours;

  AuditStats({
    required this.byStatus,
    required this.byRole,
    required this.byCategory,
    required this.byTool,
    required this.totalCalls,
    required this.avgExecutionMs,
    required this.maxExecutionMs,
    required this.timeline,
    required this.periodHours,
  });

  factory AuditStats.fromJson(Map<String, dynamic> json) {
    final perf = json['performance'] ?? {};
    return AuditStats(
      byStatus: Map<String, int>.from(json['by_status'] ?? {}),
      byRole: Map<String, int>.from(json['by_role'] ?? {}),
      byCategory: Map<String, int>.from(json['by_category'] ?? {}),
      byTool: Map<String, int>.from(json['by_tool'] ?? {}),
      totalCalls: perf['total_calls'] ?? 0,
      avgExecutionMs: (perf['avg_execution_ms'] ?? 0).toDouble(),
      maxExecutionMs: (perf['max_execution_ms'] ?? 0).toDouble(),
      timeline: List<Map<String, dynamic>>.from(json['timeline'] ?? []),
      periodHours: json['period_hours'] ?? 24,
    );
  }
}

class AuditSession {
  final String sessionId;
  final String role;
  final String firstSeen;
  final String lastSeen;
  final int totalActions;
  final int blockedActions;
  final List<String> toolsUsed;
  final int uniqueTools;

  AuditSession({
    required this.sessionId,
    required this.role,
    required this.firstSeen,
    required this.lastSeen,
    required this.totalActions,
    required this.blockedActions,
    required this.toolsUsed,
    required this.uniqueTools,
  });

  factory AuditSession.fromJson(Map<String, dynamic> json) {
    return AuditSession(
      sessionId: json['session_id'] ?? '',
      role: json['role'] ?? '',
      firstSeen: json['first_seen'] ?? '',
      lastSeen: json['last_seen'] ?? '',
      totalActions: json['total_actions'] ?? 0,
      blockedActions: json['blocked_actions'] ?? 0,
      toolsUsed: List<String>.from(json['tools_used'] ?? []),
      uniqueTools: json['unique_tools'] ?? 0,
    );
  }
}

class BlockedAction {
  final String id;
  final String timestamp;
  final String sessionId;
  final String role;
  final String tool;
  final String toolLabel;
  final String reason;
  final Map<String, dynamic> attemptedInput;

  BlockedAction({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    required this.role,
    required this.tool,
    required this.toolLabel,
    required this.reason,
    required this.attemptedInput,
  });

  factory BlockedAction.fromJson(Map<String, dynamic> json) {
    return BlockedAction(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      sessionId: json['session_id'] ?? '',
      role: json['role'] ?? '',
      tool: json['tool'] ?? '',
      toolLabel: json['tool_label'] ?? '',
      reason: json['reason'] ?? '',
      attemptedInput: json['attempted_input'] ?? {},
    );
  }
}

class ToolPerformance {
  final String tool;
  final String toolLabel;
  final int callCount;
  final double avgMs;
  final double p95Ms;
  final double maxMs;
  final String health;

  ToolPerformance({
    required this.tool,
    required this.toolLabel,
    required this.callCount,
    required this.avgMs,
    required this.p95Ms,
    required this.maxMs,
    required this.health,
  });

  factory ToolPerformance.fromJson(Map<String, dynamic> json) {
    return ToolPerformance(
      tool: json['tool'] ?? '',
      toolLabel: json['tool_label'] ?? '',
      callCount: json['call_count'] ?? 0,
      avgMs: (json['avg_ms'] ?? 0).toDouble(),
      p95Ms: (json['p95_ms'] ?? 0).toDouble(),
      maxMs: (json['max_ms'] ?? 0).toDouble(),
      health: json['health'] ?? 'normal',
    );
  }
}

class AIAuditRepository {
  final Dio _dio;
  AIAuditRepository(this._dio);

  Future<List<AuditFeedItem>> getFeed({
    int limit = 50,
    String? statusFilter,
    String? roleFilter,
    String? categoryFilter,
    String? sessionId,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (statusFilter != null) params['status_filter'] = statusFilter;
    if (roleFilter != null) params['role_filter'] = roleFilter;
    if (categoryFilter != null) params['category_filter'] = categoryFilter;
    if (sessionId != null) params['session_id'] = sessionId;

    final response = await _dio.get('/admin/ai-audit/feed', queryParameters: params);
    final feed = response.data['feed'] as List? ?? [];
    return feed.map((e) => AuditFeedItem.fromJson(e)).toList();
  }

  Future<AuditStats> getStats({int hours = 24}) async {
    final response = await _dio.get('/admin/ai-audit/stats', queryParameters: {'hours': hours});
    return AuditStats.fromJson(response.data);
  }

  Future<List<AuditSession>> getSessions({int limit = 20}) async {
    final response = await _dio.get('/admin/ai-audit/sessions', queryParameters: {'limit': limit});
    final sessions = response.data['sessions'] as List? ?? [];
    return sessions.map((e) => AuditSession.fromJson(e)).toList();
  }

  Future<List<BlockedAction>> getBlocked({int limit = 50}) async {
    final response = await _dio.get('/admin/ai-audit/blocked', queryParameters: {'limit': limit});
    final blocked = response.data['blocked_actions'] as List? ?? [];
    return blocked.map((e) => BlockedAction.fromJson(e)).toList();
  }

  Future<List<ToolPerformance>> getPerformance({int hours = 24}) async {
    final response = await _dio.get('/admin/ai-audit/performance', queryParameters: {'hours': hours});
    final tools = response.data['tools'] as List? ?? [];
    return tools.map((e) => ToolPerformance.fromJson(e)).toList();
  }
}
