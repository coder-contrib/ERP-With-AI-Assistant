import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
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
  final bool isStreaming;
  final bool shouldStopAudio;

  VoiceChatState({
    this.voiceState = VoiceState.idle,
    this.messages = const [],
    this.currentTool,
    this.partialTranscription,
    this.currentAiText,
    this.sessionId = '',
    this.isConnected = false,
    this.errorMessage,
    this.isStreaming = false,
    this.shouldStopAudio = false,
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
    bool? isStreaming,
    bool? shouldStopAudio,
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
      isStreaming: isStreaming ?? this.isStreaming,
      shouldStopAudio: shouldStopAudio ?? this.shouldStopAudio,
    );
  }
}

final voiceChatProvider = StateNotifierProvider<VoiceChatNotifier, VoiceChatState>((ref) {
  return VoiceChatNotifier(ref.read(voiceServiceProvider));
});

class VoiceChatNotifier extends StateNotifier<VoiceChatState> {
  final VoiceService _voiceService;
  StreamSubscription? _eventSub;
  StreamSubscription? _audioStreamSub;
  final AudioRecorder _recorder = AudioRecorder();

  VoiceChatNotifier(this._voiceService) : super(VoiceChatState(
    sessionId: 'voice-${DateTime.now().millisecondsSinceEpoch}',
    messages: [
      AIMessage(
        role: 'assistant',
        content: 'أهلاً! أنا مساعدك الصوتي. اضغط على الميكروفون واتكلم عادي.\n\n'
            'ممكن تسألني:\n'
            '• "كام في الخزنة؟"\n'
            '• "المبيعات عاملة ايه النهارده؟"\n'
            '• "بيع ٥ متر سيراميك لأحمد"',
      ),
    ],
  ));

  /// Barge-in: interrupt AI while speaking and immediately start listening
  Future<void> bargeIn() async {
    state = state.copyWith(
      shouldStopAudio: true,
      voiceState: VoiceState.idle,
      isStreaming: false,
      partialTranscription: null,
    );

    _voiceService.sendJsonViaWs({'type': 'barge_in'});

    await Future.delayed(const Duration(milliseconds: 50));
    state = state.copyWith(shouldStopAudio: false);

    await startStreaming();
  }

  /// Start live streaming mode: audio is streamed in real-time for transcription
  Future<void> startStreaming() async {
    if (!state.isConnected) {
      await _voiceService.connectWebSocket(state.sessionId);
      _eventSub = _voiceService.events.listen(_handleEvent);
    }

    _voiceService.sendJsonViaWs({'type': 'stream_start', 'language': 'ar'});

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioStreamSub = stream.listen((chunk) {
      final b64 = base64Encode(chunk);
      _voiceService.sendJsonViaWs({'type': 'stream_audio', 'data': b64});
    });

    state = state.copyWith(
      voiceState: VoiceState.listening,
      isStreaming: true,
      isConnected: true,
    );
  }

  /// Stop live streaming and trigger AI processing
  Future<void> stopStreaming() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    _voiceService.sendJsonViaWs({'type': 'stream_stop'});

    state = state.copyWith(
      voiceState: VoiceState.processing,
      isStreaming: false,
    );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'stream_started':
        state = state.copyWith(voiceState: VoiceState.listening, isStreaming: true);
        break;

      case 'transcription_partial':
        state = state.copyWith(partialTranscription: data['text']);
        break;

      case 'transcription_complete':
        final text = data['text'] ?? '';
        _addMessage(AIMessage(role: 'user', content: text));
        state = state.copyWith(voiceState: VoiceState.processing, partialTranscription: null);
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

      case 'stop_audio':
        state = state.copyWith(
          shouldStopAudio: true,
          voiceState: VoiceState.idle,
        );
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            state = state.copyWith(shouldStopAudio: false);
          }
        });
        break;

      case 'barge_in_ack':
        break;

      case 'error':
        state = state.copyWith(
          voiceState: VoiceState.idle,
          errorMessage: data['message'],
          isStreaming: false,
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
      // Sales (Read)
      'get_today_sales': 'بجيب مبيعات النهارده',
      'get_customer_info': 'بشوف بيانات العميل',
      'get_customer_history': 'بجيب سجل العميل',
      'get_top_selling_products': 'بشوف الأكتر مبيعاً',
      'get_unpaid_invoices': 'بدور على المتأخرات',
      // Inventory (Read)
      'get_stock_level': 'براجع المخزون',
      'get_low_stock_items': 'بشوف الأصناف الناقصة',
      'get_stock_movement_history': 'بتابع حركة المخزون',
      'get_warehouse_summary': 'بجيب ملخص المخزن',
      'get_dead_stock': 'بشوف البضاعة الراكدة',
      'get_stock_valuation': 'بحسب قيمة المخزون',
      // Finance (Read)
      'get_profit_and_loss': 'بحلل الأرباح',
      'get_cash_balance': 'بحسب الكاش',
      'get_receivables_summary': 'بجيب المديونيات',
      'get_payables_summary': 'بجيب المستحقات',
      'get_expense_breakdown': 'بفصّل المصروفات',
      'get_daily_revenue': 'بجيب الإيراد اليومي',
      'demand_forecast': 'بتوقع الطلب',
      // Search
      'search_products': 'بدور على منتج',
      'search_customers': 'بدور على عميل',
      'search_suppliers': 'بدور على مورد',
      // Sales (Write)
      'create_invoice': 'بعمل فاتورة',
      'cancel_invoice': 'بلغي الفاتورة',
      'apply_discount': 'بطبق الخصم',
      // Payments
      'record_payment': 'بسجل دفعة',
      'refund_payment': 'برد المبلغ',
      // Inventory (Write)
      'update_stock': 'بحدّث المخزون',
      'transfer_stock': 'بنقل بضاعة',
      'adjust_stock': 'بعدّل المخزون',
      // CRM
      'create_customer': 'بسجل عميل جديد',
      'update_customer': 'بعدّل بيانات العميل',
      // Opening Balances
      'set_customer_opening_balance': 'بسجل رصيد أول المدة للعميل',
      'set_supplier_opening_balance': 'بسجل رصيد أول المدة للمورد',
      'set_cash_opening_balance': 'بسجل رصيد الصندوق',
      'set_opening_inventory': 'بسجل جرد أول المدة',
      'get_opening_balances': 'بجيب الأرصدة الافتتاحية',
      // Expenses
      'create_expense': 'بسجل مصروف',
      'list_expenses': 'بجيب المصروفات',
      'get_expense_summary': 'بلخص المصروفات',
      // Sales Invoices
      'list_sales_invoices': 'بجيب فواتير المبيعات',
      'get_sales_invoice': 'بفتح الفاتورة',
      'get_invoice_items': 'بشوف أصناف الفاتورة',
      'create_sales_return': 'بعمل مرتجع مبيعات',
      // Purchases
      'list_purchase_invoices': 'بجيب فواتير المشتريات',
      'get_purchase_invoice': 'بفتح فاتورة المشتريات',
      'get_purchase_items': 'بشوف أصناف المشتريات',
      'create_purchase_invoice': 'بعمل فاتورة مشتريات',
      'create_purchase_return': 'بعمل مرتجع مشتريات',
      // Suppliers
      'create_supplier': 'بسجل مورد جديد',
      'update_supplier': 'بعدّل بيانات المورد',
      // Products
      'create_product': 'بضيف منتج جديد',
      'update_product': 'بعدّل بيانات المنتج',
      'get_product': 'بجيب تفاصيل المنتج',
      // Categories
      'list_categories': 'بجيب التصنيفات',
      'create_category': 'بعمل تصنيف جديد',
      'update_category': 'بعدّل التصنيف',
      'delete_category': 'بحذف التصنيف',
      // Reports
      'get_monthly_profit': 'بحسب الأرباح الشهرية',
      'get_cash_flow': 'بحلل التدفق النقدي',
      'get_waste_report': 'بجيب تقرير الهالك',
      // Notifications
      'get_notifications': 'بجيب الإشعارات',
      'mark_notification_read': 'بعلّم الإشعار مقروء',
      'mark_all_notifications_read': 'بعلّم الكل مقروء',
      // Alerts
      'check_low_stock_alerts': 'بفحص تنبيهات المخزون',
      'check_credit_limit_alerts': 'بفحص تجاوز الائتمان',
      'check_overdue_supplier_alerts': 'بفحص المدفوعات المتأخرة',
      // Anomaly Detection
      'scan_anomalies': 'بفحص الانحرافات',
      'detect_revenue_anomaly': 'بكشف انحراف الإيرادات',
      'detect_expense_anomaly': 'بكشف انحراف المصروفات',
      // Business Insights
      'get_business_insights': 'بحلل رؤى الأعمال',
      'why_profit_dropped': 'بحلل سبب انخفاض الربح',
      'get_top_risks': 'بجيب أهم المخاطر',
      // Dashboard
      'get_dashboard_summary': 'بجيب ملخص لوحة التحكم',
      // Accounting Tasks
      'refresh_daily_summary': 'بحدّث الملخص اليومي',
      'refresh_summary_range': 'بحدّث ملخص الفترة',
      // User Management
      'list_users': 'بجيب المستخدمين',
      'create_user': 'بعمل مستخدم جديد',
      'deactivate_user': 'بعطّل المستخدم',
      'activate_user': 'بفعّل المستخدم',
      'reset_user_password': 'بغيّر كلمة السر',
      // Ledger
      'get_ledger_entries': 'بجيب القيود المحاسبية',
      'get_account_balance': 'بحسب رصيد الحساب',
      'get_trial_balance': 'بجيب ميزان المراجعة',
      // Safety
      'confirm_transaction': 'بأكد العملية',
    };
    return names[tool] ?? 'بشتغل...';
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _audioStreamSub?.cancel();
    _recorder.dispose();
    _voiceService.disconnectWebSocket();
    super.dispose();
  }
}
