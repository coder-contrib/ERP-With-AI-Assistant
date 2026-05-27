import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/network/api_client.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService(ref.read(dioProvider));
});

class VoiceTranscription {
  final String text;
  final String languageDetected;
  final double confidence;
  final double durationSeconds;

  VoiceTranscription({
    required this.text,
    required this.languageDetected,
    required this.confidence,
    required this.durationSeconds,
  });

  factory VoiceTranscription.fromJson(Map<String, dynamic> json) {
    return VoiceTranscription(
      text: json['text'] ?? '',
      languageDetected: json['language_detected'] ?? 'ar',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VoiceResponse {
  final String transcript;
  final String? audioBase64;
  final List<String> toolsUsed;
  final String language;
  final String sessionId;

  VoiceResponse({
    required this.transcript,
    this.audioBase64,
    required this.toolsUsed,
    required this.language,
    required this.sessionId,
  });

  factory VoiceResponse.fromJson(Map<String, dynamic> json) {
    return VoiceResponse(
      transcript: json['text'] ?? json['transcript'] ?? '',
      audioBase64: json['audio'],
      toolsUsed: (json['tools_used'] as List?)?.cast<String>() ?? [],
      language: json['language'] ?? 'ar',
      sessionId: json['session_id'] ?? '',
    );
  }
}

class VoiceService {
  final Dio _dio;
  WebSocketChannel? _wsChannel;
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();

  VoiceService(this._dio);

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<VoiceTranscription> transcribe(Uint8List audioData, {String language = 'auto'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioData, filename: 'audio.wav'),
      'language': language,
    });

    final response = await _dio.post('/ai/voice/transcribe', data: formData,
      options: Options(contentType: 'multipart/form-data'));
    return VoiceTranscription.fromJson(response.data);
  }

  Future<VoiceResponse> voiceChat(Uint8List audioData, {String sessionId = 'voice-default', String language = 'auto'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioData, filename: 'audio.wav'),
      'session_id': sessionId,
      'language': language,
    });

    final response = await _dio.post('/ai/voice/respond', data: formData,
      options: Options(contentType: 'multipart/form-data'));
    return VoiceResponse.fromJson(response.data);
  }

  Future<VoiceResponse> voiceChatWithAudio(Uint8List audioData, {String sessionId = 'voice-default', String language = 'auto'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioData, filename: 'audio.wav'),
      'session_id': sessionId,
      'language': language,
    });

    final response = await _dio.post('/ai/voice/chat', data: formData,
      options: Options(contentType: 'multipart/form-data'));
    return VoiceResponse.fromJson(response.data);
  }

  Future<VoiceResponse> textToVoiceChat(String text, {String sessionId = 'voice-default'}) async {
    final response = await _dio.post('/ai/voice/chat', data: {
      'text': text,
      'session_id': sessionId,
    });
    return VoiceResponse.fromJson(response.data);
  }

  Future<Uint8List> textToSpeech(String text) async {
    final formData = FormData.fromMap({'text': text});
    final response = await _dio.post('/ai/voice/tts',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  void connectWebSocket(String sessionId) {
    final baseUrl = _dio.options.baseUrl.replaceFirst('http', 'ws');
    _wsChannel = WebSocketChannel.connect(Uri.parse('$baseUrl/ai/voice/ws/$sessionId'));
    _wsChannel!.stream.listen(
      (data) {
        if (data is String) {
          try {
            _eventController.add(jsonDecode(data));
          } catch (_) {}
        } else if (data is List<int>) {
          _eventController.add({'type': 'audio_chunk', 'data': {'bytes': data}});
        }
      },
      onError: (e) => _eventController.add({'type': 'error', 'data': {'message': e.toString()}}),
      onDone: () => _eventController.add({'type': 'disconnected', 'data': {}}),
    );
  }

  /// Send structured JSON message via WebSocket
  void sendJsonViaWs(Map<String, dynamic> message) {
    if (_wsChannel == null) return;
    _wsChannel!.sink.add(jsonEncode(message));
  }

  void sendAudioViaWs(Uint8List audioData) {
    if (_wsChannel == null) return;
    final b64 = base64Encode(audioData);
    _wsChannel!.sink.add(jsonEncode({'type': 'stream_audio', 'data': b64}));
  }

  void sendTextViaWs(String text) {
    if (_wsChannel == null) return;
    _wsChannel!.sink.add(jsonEncode({'type': 'text', 'data': {'message': text}}));
  }

  void disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void dispose() {
    disconnectWebSocket();
    _eventController.close();
  }
}
