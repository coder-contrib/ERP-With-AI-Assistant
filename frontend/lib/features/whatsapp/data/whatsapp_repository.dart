import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final whatsappRepositoryProvider = Provider<WhatsAppRepository>((ref) {
  return WhatsAppRepository(ref.read(dioProvider));
});

class WhatsAppRepository {
  final Dio _dio;
  WhatsAppRepository(this._dio);

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _dio.get('/whatsapp/settings');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final response = await _dio.post('/whatsapp/settings', data: settings);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage({required String to, required String message}) async {
    final response = await _dio.post('/whatsapp/send', data: {'to': to, 'message': message});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendOverdueReminders() async {
    final response = await _dio.post('/whatsapp/send-overdue-reminders');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendDailyReport({required String to}) async {
    final response = await _dio.post('/whatsapp/send-daily-report', data: {'to': to});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendReportToOwner({String reportType = 'daily_sales'}) async {
    final response = await _dio.post('/whatsapp/send-report-to-owner', data: {'report_type': reportType});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendInvoice(int invoiceId) async {
    final response = await _dio.post('/whatsapp/send-invoice/$invoiceId');
    return response.data as Map<String, dynamic>;
  }
}
