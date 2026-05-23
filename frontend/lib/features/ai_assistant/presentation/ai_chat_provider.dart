import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_repository.dart';

final aiChatProvider = StateNotifierProvider<AIChatNotifier, AIChatState>((ref) {
  return AIChatNotifier(ref.read(aiRepositoryProvider));
});

class AIChatState {
  final List<AIMessage> messages;
  final bool isLoading;
  final String? currentTool;
  final String sessionId;

  AIChatState({this.messages = const [], this.isLoading = false, this.currentTool, this.sessionId = ''});

  AIChatState copyWith({List<AIMessage>? messages, bool? isLoading, String? currentTool, String? sessionId}) {
    return AIChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentTool: currentTool,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class AIChatNotifier extends StateNotifier<AIChatState> {
  final AIRepository _repo;
  StreamSubscription? _streamSub;

  AIChatNotifier(this._repo) : super(AIChatState(
    sessionId: 'session-${DateTime.now().millisecondsSinceEpoch}',
    messages: [
      AIMessage(
        role: 'assistant',
        content: 'Hello! I\'m your ERP AI Assistant powered by Claude. I can help you with:\n\n'
            '• **Sales** — today\'s sales, customer balances, unpaid invoices\n'
            '• **Inventory** — stock levels, low stock alerts, demand forecasts\n'
            '• **Finance** — profit & loss, cash balance, expenses\n\n'
            'What would you like to know?',
      ),
    ],
  ));

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = AIMessage(role: 'user', content: text);
    final assistantMsg = AIMessage(role: 'assistant', content: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isLoading: true,
      currentTool: null,
    );

    try {
      String fullText = '';
      List<String> tools = [];

      await for (final event in _repo.chatStream(state.sessionId, text)) {
        final type = event['type'];

        if (type == 'tool_call') {
          final toolName = event['tool'] ?? 'unknown';
          tools.add(toolName);
          state = state.copyWith(currentTool: _formatToolName(toolName));
        } else if (type == 'token') {
          fullText += event['text'] ?? '';
          _updateLastMessage(fullText, true, tools);
        } else if (type == 'done') {
          fullText = event['full_text'] ?? fullText;
          _updateLastMessage(fullText, false, tools);
        }
      }

      if (fullText.isEmpty) {
        _updateLastMessage('I couldn\'t process that request. Please try again.', false, tools);
      }
    } catch (e) {
      _updateLastMessage('Sorry, an error occurred: ${e.toString().substring(0, 100)}', false, []);
    }

    state = state.copyWith(isLoading: false, currentTool: null);
  }

  void _updateLastMessage(String content, bool isStreaming, List<String> tools) {
    final messages = [...state.messages];
    if (messages.isNotEmpty && messages.last.role == 'assistant') {
      messages[messages.length - 1] = messages.last.copyWith(
        content: content,
        isStreaming: isStreaming,
        toolCalls: tools.isNotEmpty ? tools : null,
      );
    }
    state = state.copyWith(messages: messages);
  }

  Future<void> clearChat() async {
    await _repo.clearConversation(state.sessionId);
    state = AIChatState(
      sessionId: 'session-${DateTime.now().millisecondsSinceEpoch}',
      messages: [
        AIMessage(role: 'assistant', content: 'Conversation cleared. How can I help you?'),
      ],
    );
  }

  String _formatToolName(String tool) {
    final names = {
      'get_today_sales': 'Checking today\'s sales',
      'get_customer_info': 'Looking up customer',
      'get_customer_history': 'Fetching purchase history',
      'get_stock_level': 'Checking stock levels',
      'get_low_stock_items': 'Scanning low stock',
      'get_top_selling_products': 'Analyzing top products',
      'get_profit_and_loss': 'Calculating P&L',
      'get_cash_balance': 'Checking cash balance',
      'get_unpaid_invoices': 'Finding unpaid invoices',
      'get_receivables_summary': 'Reviewing receivables',
      'get_payables_summary': 'Reviewing payables',
      'get_expense_breakdown': 'Analyzing expenses',
      'demand_forecast': 'Forecasting demand',
      'search_products': 'Searching products',
      'search_customers': 'Searching customers',
    };
    return names[tool] ?? 'Processing';
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
