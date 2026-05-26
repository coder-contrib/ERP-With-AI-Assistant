import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(dioProvider));
});

class NotificationModel {
  final int notificationId;
  final int? userId;
  final String notificationType;
  final String severity;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdDate;

  NotificationModel({
    required this.notificationId,
    this.userId,
    required this.notificationType,
    required this.severity,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdDate,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'],
      userId: json['user_id'],
      notificationType: json['notification_type'] ?? '',
      severity: json['severity'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdDate: json['created_date'] != null ? DateTime.tryParse(json['created_date']) : null,
    );
  }
}

class NotificationsRepository {
  final Dio _dio;
  NotificationsRepository(this._dio);

  Future<List<NotificationModel>> getAll({int limit = 50}) async {
    final response = await _dio.get('/notifications', queryParameters: {'limit': limit});
    return (response.data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<List<NotificationModel>> getUnread() async {
    final response = await _dio.get('/notifications/unread');
    return (response.data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get('/notifications/unread/count');
    return response.data['unread_count'] ?? 0;
  }

  Future<void> markAsRead(int notificationId) async {
    await _dio.put('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.put('/notifications/read-all');
  }

  Future<Map<String, dynamic>> runChecks() async {
    final response = await _dio.post('/notifications/check');
    return response.data as Map<String, dynamic>;
  }
}
