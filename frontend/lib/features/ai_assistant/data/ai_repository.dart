import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepository(ref.read(dioProvider));
});

class AIMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final List<String>? toolCalls;
  final bool isStreaming;

  AIMessage({required this.role, required this.content, DateTime? timestamp, this.toolCalls, this.isStreaming = false})
      : timestamp = timestamp ?? DateTime.now();

  AIMessage copyWith({String? content, bool? isStreaming, List<String>? toolCalls}) {
    return AIMessage(
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class AIRepository {
  final Dio _dio;
  AIRepository(this._dio);

  Future<String> chat(String sessionId, String message) async {
    final response = await _dio.post('/ai/chat', data: {
      'session_id': sessionId,
      'message': message,
    });
    return response.data['response'] ?? '';
  }

  Stream<Map<String, dynamic>> chatStream(String sessionId, String message) async* {
    final response = await _dio.post(
      '/ai/chat/stream',
      data: {'session_id': sessionId, 'message': message},
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (line.isNotEmpty) {
          try {
            yield jsonDecode(line) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    }
  }

  Future<void> clearConversation(String sessionId) async {
    await _dio.delete('/ai/conversation/$sessionId');
  }
}
