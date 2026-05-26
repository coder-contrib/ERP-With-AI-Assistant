import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/voice_service.dart';
import '../data/ai_repository.dart';

enum VoiceState { idle, listening, processing, toolExecution, speaking }

class VoiceChatState {
  final VoiceState voiceState;
  final List<AIMessage> messages;
  final String? currentTool;
  final String? partialTranscription;
  final String? currentAiText;
  final String sessionId;
  final bool isConnected;
  final String? errorMessage;

  VoiceChatState({
    this.voiceState = VoiceState.idle,
    this.messages = const [],
    this.currentTool,
    this.partialTranscription,
    this.currentAiText,
    this.sessionId = '',
    this.isConnected = false,
    this.errorMessage,
  });

  VoiceChatState copyWith({
    VoiceState? voiceState,
    List<AIMessage>? messages,
    String? currentTool,
    String? partialTranscription,
    String? currentAiText,
    String? sessionId,
    bool? isConnected,
    String? errorMessage,
  }) {
    return VoiceChatState(
      voiceState: voiceState ?? this.voiceState,
      messages: messages ?? this.messages,
      currentTool: currentTool,
      partialTranscription: partialTranscription,
      currentAiText: currentAiText ?? this.currentAiText,
      sessionId: sessionId ?? this.sessionId,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: errorMessage,
    );
  }
}

final voiceChatProvider = StateNotifierProvider<VoiceChatNotifier, VoiceChatState>((ref) {
  return VoiceChatNotifier(ref.read(voiceServiceProvider));
});

class VoiceChatNotifier extends StateNotifier<VoiceChatState> {
  final VoiceService _voiceService;
  StreamSubscription? _eventSub;

  VoiceChatNotifier(this._voiceService) : super(VoiceChatState(
    sessionId: 'voice-${DateTime.now().millisecondsSinceEpoch}',
    messages: [
      AIMessage(
        role: 'assistant',
        content: 'أهلاً! أنا مساعدك الصوتي. اضغط على الميكروفون واتكلم عادي.\n\n'
            'ممكن تسألني:\n'
            '• "كام في الخزنة؟"\n'
            '• "المبيعات عاملة ايه النهارده؟"\n'
            '• "العميل أحمد مديون بكام؟"',
      ),
    ],
  ));

  void connectWebSocket() {
    _voiceService.connectWebSocket(state.sessionId);
    _eventSub = _voiceService.events.listen(_handleEvent);
    state = state.copyWith(isConnected: true);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'transcription_complete':
        final text = data['text'] ?? '';
        _addMessage(AIMessage(role: 'user', content: text));
        state = state.copyWith(voiceState: VoiceState.processing, partialTranscription: null);
        break;

      case 'transcription_partial':
        state = state.copyWith(partialTranscription: data['text']);
        break;

      case 'tool_call_started':
        state = state.copyWith(
          voiceState: VoiceState.toolExecution,
          currentTool: _formatToolName(data['tool'] ?? ''),
        );
        break;

      case 'tool_call_finished':
        state = state.copyWith(currentTool: null);
        break;

      case 'ai_response_complete':
        final text = data['text'] ?? '';
        _addMessage(AIMessage(
          role: 'assistant',
          content: text,
          toolCalls: (data['tools_used'] as List?)?.cast<String>(),
        ));
        state = state.copyWith(currentAiText: text);
        break;

      case 'ai_speaking':
        state = state.copyWith(voiceState: VoiceState.speaking);
        break;

      case 'ai_finished':
        state = state.copyWith(voiceState: VoiceState.idle);
        break;

      case 'audio_chunk':
        // Audio chunks handled by audio player at UI level
        break;

      case 'error':
        state = state.copyWith(
          voiceState: VoiceState.idle,
          errorMessage: data['message'],
        );
        break;
    }
  }

  void startListening() {
    state = state.copyWith(voiceState: VoiceState.listening);
  }

  void stopListening() {
    state = state.copyWith(voiceState: VoiceState.processing);
  }

  Future<void> processAudio(Uint8List audioData) async {
    state = state.copyWith(voiceState: VoiceState.processing);

    try {
      // Use REST endpoint for reliability
      final transcription = await _voiceService.transcribe(audioData);
      _addMessage(AIMessage(role: 'user', content: transcription.text));

      final response = await _voiceService.textToVoiceChat(
        transcription.text,
        sessionId: state.sessionId,
      );

      _addMessage(AIMessage(
        role: 'assistant',
        content: response.transcript,
        toolCalls: response.toolsUsed.isNotEmpty ? response.toolsUsed : null,
      ));

      state = state.copyWith(
        voiceState: response.audioBase64 != null ? VoiceState.speaking : VoiceState.idle,
        currentAiText: response.transcript,
      );

      // Audio playback handled at UI level via response.audioBase64
    } catch (e) {
      state = state.copyWith(
        voiceState: VoiceState.idle,
        errorMessage: 'Error: ${e.toString().substring(0, 80)}',
      );
    }
  }

  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    _addMessage(AIMessage(role: 'user', content: text));
    state = state.copyWith(voiceState: VoiceState.processing);

    try {
      final response = await _voiceService.textToVoiceChat(
        text,
        sessionId: state.sessionId,
      );

      _addMessage(AIMessage(
        role: 'assistant',
        content: response.transcript,
        toolCalls: response.toolsUsed.isNotEmpty ? response.toolsUsed : null,
      ));

      state = state.copyWith(
        voiceState: response.audioBase64 != null ? VoiceState.speaking : VoiceState.idle,
        currentAiText: response.transcript,
      );
    } catch (e) {
      _addMessage(AIMessage(role: 'assistant', content: 'حصل مشكلة، جرب تاني.'));
      state = state.copyWith(voiceState: VoiceState.idle);
    }
  }

  void onSpeakingDone() {
    state = state.copyWith(voiceState: VoiceState.idle);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void _addMessage(AIMessage msg) {
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  String _formatToolName(String tool) {
    const names = {
      'get_today_sales': 'بجيب مبيعات النهارده',
      'get_customer_info': 'بشوف بيانات العميل',
      'get_stock_level': 'براجع المخزون',
      'get_cash_balance': 'بحسب الكاش',
      'get_profit_and_loss': 'بحلل الأرباح',
      'get_top_selling_products': 'بشوف الأكتر مبيعاً',
      'get_unpaid_invoices': 'بدور على المتأخرات',
      'search_products': 'بدور على منتج',
      'search_customers': 'بدور على عميل',
    };
    return names[tool] ?? 'بشتغل...';
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _voiceService.disconnectWebSocket();
    super.dispose();
  }
}
