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
        content: 'أهلاً! أنا مساعدك الذكي في نظام ERP. أقدر أساعدك في:\n\n'
            '• **المبيعات** — فواتير، مدفوعات، عملاء، مرتجعات\n'
            '• **المخزون** — أرصدة، تنبيهات النقص، نقل بضاعة\n'
            '• **المالية** — أرباح، تدفق نقدي، مصروفات، ميزان مراجعة\n'
            '• **التحليلات** — انحرافات، مخاطر، رؤى الأعمال\n'
            '• **الإدارة** — مستخدمين، تصنيفات، إشعارات\n\n'
            'اكتب طلبك وأنا هنفذهلك فوراً.',
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
        _updateLastMessage('حصل مشكلة في المعالجة. جرب تاني.', false, tools);
      }
    } catch (e) {
      _updateLastMessage('حصل خطأ: ${e.toString().substring(0, 100)}', false, []);
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
        AIMessage(role: 'assistant', content: 'تم مسح المحادثة. إزاي أقدر أساعدك؟'),
      ],
    );
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
    _streamSub?.cancel();
    super.dispose();
  }
}
