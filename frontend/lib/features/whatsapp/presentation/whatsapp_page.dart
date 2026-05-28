import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/whatsapp_repository.dart';
import 'whatsapp_provider.dart';

class WhatsAppPage extends ConsumerStatefulWidget {
  const WhatsAppPage({super.key});

  @override
  ConsumerState<WhatsAppPage> createState() => _WhatsAppPageState();
}

class _WhatsAppPageState extends ConsumerState<WhatsAppPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF25D366),
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              indicatorColor: const Color(0xFF25D366),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.send, size: 20), text: 'Send Message'),
                Tab(icon: Icon(Icons.notification_important, size: 20), text: 'Reminders'),
                Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SendMessageTab(),
                _RemindersTab(),
                _SettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendMessageTab extends ConsumerStatefulWidget {
  const _SendMessageTab();

  @override
  ConsumerState<_SendMessageTab> createState() => _SendMessageTabState();
}

class _SendMessageTabState extends ConsumerState<_SendMessageTab> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) return;
    setState(() { _sending = true; _lastResult = null; });
    try {
      final repo = ref.read(whatsappRepositoryProvider);
      final result = await repo.sendMessage(to: _phoneController.text.trim(), message: _messageController.text.trim());
      setState(() { _lastResult = result; _sending = false; });
      if (result['status'] == 'sent') _messageController.clear();
    } catch (e) {
      setState(() { _lastResult = {'error': e.toString()}; _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
                    SizedBox(width: 12),
                    Text('Send WhatsApp Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '201234567890 (international format)',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Type your message...',
                    prefixIcon: const Icon(Icons.message),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                    label: Text(_sending ? 'Sending...' : 'Send via WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lastResult!.containsKey('error')
                    ? AppColors.error.withOpacity(0.05)
                    : AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _lastResult!.containsKey('error') ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastResult!.containsKey('error') ? Icons.error : Icons.check_circle,
                    color: _lastResult!.containsKey('error') ? AppColors.error : AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lastResult!.containsKey('error')
                          ? 'Error: ${_lastResult!['error']}'
                          : 'Message sent successfully! ID: ${_lastResult!['message_id'] ?? 'N/A'}',
                      style: TextStyle(color: _lastResult!.containsKey('error') ? AppColors.error : AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFF25D366), size: 20),
                    SizedBox(width: 10),
                    Text('Send Daily Sales Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Send today\'s sales summary to a phone number via WhatsApp.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                _DailyReportSender(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyReportSender extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DailyReportSender> createState() => _DailyReportSenderState();
}

class _DailyReportSenderState extends ConsumerState<_DailyReportSender> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.isEmpty) return;
    setState(() { _sending = true; _status = null; });
    try {
      final repo = ref.read(whatsappRepositoryProvider);
      final result = await repo.sendDailyReport(to: _controller.text.trim());
      setState(() {
        _sending = false;
        _status = result.containsKey('error') ? 'Error: ${result['error']}' : 'Report sent successfully!';
      });
    } catch (e) {
      setState(() { _sending = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Phone number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          child: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send Report'),
        ),
        if (_status != null) ...[
          const SizedBox(width: 12),
          Icon(_status!.startsWith('Error') ? Icons.error : Icons.check_circle, size: 20, color: _status!.startsWith('Error') ? AppColors.error : AppColors.success),
        ],
      ],
    );
  }
}

class _RemindersTab extends ConsumerStatefulWidget {
  const _RemindersTab();

  @override
  ConsumerState<_RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends ConsumerState<_RemindersTab> {
  bool _sending = false;
  Map<String, dynamic>? _result;

  Future<void> _sendReminders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Send'),
        content: const Text('This will send WhatsApp reminders to ALL customers with overdue payments (7+ days). Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            child: const Text('Send Reminders'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _sending = true; _result = null; });
    try {
      final repo = ref.read(whatsappRepositoryProvider);
      final result = await repo.sendOverdueReminders();
      setState(() { _result = result; _sending = false; });
    } catch (e) {
      setState(() { _result = {'error': e.toString()}; _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notification_important, color: AppColors.warning, size: 24),
                    SizedBox(width: 12),
                    Text('Overdue Payment Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Send automated WhatsApp reminders to all customers who have unpaid invoices older than 7 days. '
                  'Messages are sent in Arabic with the customer\'s name and total due amount.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Message Preview:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text(
                        'السلام عليكم {اسم العميل}،\n'
                        'نذكركم برصيد مستحق بقيمة {المبلغ} جنيه ({عدد} فاتورة).\n'
                        'نرجو التواصل لترتيب السداد. شكراً لكم.',
                        style: TextStyle(fontSize: 13),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendReminders,
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Sending Reminders...' : 'Send Overdue Reminders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: _result!.containsKey('error')
                  ? Row(
                      children: [
                        const Icon(Icons.error, color: AppColors.error),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Error: ${_result!['error']}', style: const TextStyle(color: AppColors.error))),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 12),
                            Text('Reminders Sent', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.success)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _resultBadge('Sent', '${_result!['sent_count'] ?? 0}', AppColors.success),
                            const SizedBox(width: 12),
                            _resultBadge('Failed', '${_result!['failed_count'] ?? 0}', AppColors.error),
                          ],
                        ),
                        if ((_result!['sent'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          const Text('Successfully notified:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          ...(_result!['sent'] as List).take(10).map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('✓ ${s['name']} - ${s['amount_due']?.toStringAsFixed(0) ?? 0} IQD', style: const TextStyle(fontSize: 13, color: AppColors.success)),
                          )),
                        ],
                        if ((_result!['failed'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          const Text('Failed:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                          const SizedBox(height: 4),
                          ...(_result!['failed'] as List).take(5).map((f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('✗ ${f['name']} - ${f['error']}', style: const TextStyle(fontSize: 13, color: AppColors.error)),
                          )),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  final _tokenController = TextEditingController();
  final _phoneIdController = TextEditingController();
  bool _canSend = false;
  bool _canBulk = false;
  bool _saving = false;
  String? _status;

  @override
  void dispose() {
    _tokenController.dispose();
    _phoneIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _status = null; });
    try {
      final repo = ref.read(whatsappRepositoryProvider);
      final data = <String, dynamic>{
        'whatsapp_can_send': _canSend,
        'whatsapp_can_bulk_message': _canBulk,
      };
      if (_tokenController.text.isNotEmpty) data['whatsapp_api_token'] = _tokenController.text.trim();
      if (_phoneIdController.text.isNotEmpty) data['whatsapp_phone_number_id'] = _phoneIdController.text.trim();

      await repo.updateSettings(data);
      ref.invalidate(whatsappSettingsProvider);
      setState(() { _saving = false; _status = 'Settings saved successfully!'; });
      _tokenController.clear();
      _phoneIdController.clear();
    } catch (e) {
      setState(() { _saving = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(whatsappSettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading settings: $e', style: const TextStyle(color: AppColors.error)),
            data: (settings) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: settings['configured'] == true
                          ? AppColors.success.withOpacity(0.05)
                          : AppColors.warning.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: settings['configured'] == true
                            ? AppColors.success.withOpacity(0.3)
                            : AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          settings['configured'] == true ? Icons.check_circle : Icons.warning,
                          color: settings['configured'] == true ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings['configured'] == true ? 'WhatsApp API Configured' : 'WhatsApp Not Configured',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: settings['configured'] == true ? AppColors.success : AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sending: ${settings['can_send'] == true ? "Enabled" : "Disabled"} | '
                                'Bulk: ${settings['can_bulk_message'] == true ? "Enabled" : "Disabled"} | '
                                'Max/request: ${settings['max_messages_per_request'] ?? 50}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WhatsApp API Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Configure your Meta Cloud API credentials for WhatsApp Business.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _tokenController,
                          decoration: InputDecoration(
                            labelText: 'API Token',
                            hintText: settings['api_token_set'] == true ? '(already set - enter new to change)' : 'Enter Meta API token',
                            prefixIcon: const Icon(Icons.key),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phoneIdController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number ID',
                            hintText: settings['phone_number_id']?.toString().isNotEmpty == true ? 'Current: ${settings['phone_number_id']}' : 'Enter Phone Number ID',
                            prefixIcon: const Icon(Icons.phone_android),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text('Enable Sending'),
                          subtitle: const Text('Allow sending WhatsApp messages'),
                          value: _canSend || (settings['can_send'] == true),
                          onChanged: (v) => setState(() => _canSend = v),
                          activeColor: const Color(0xFF25D366),
                        ),
                        SwitchListTile(
                          title: const Text('Enable Bulk Messaging'),
                          subtitle: const Text('Allow sending bulk overdue reminders'),
                          value: _canBulk || (settings['can_bulk_message'] == true),
                          onChanged: (v) => setState(() => _canBulk = v),
                          activeColor: const Color(0xFF25D366),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving...' : 'Save Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_status != null) ...[
                          const SizedBox(height: 12),
                          Text(_status!, style: TextStyle(color: _status!.startsWith('Error') ? AppColors.error : AppColors.success)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
