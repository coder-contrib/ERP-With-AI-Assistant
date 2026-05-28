import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_audit_repository.dart';
import 'ai_audit_provider.dart';

class AIAnalyticsPage extends ConsumerStatefulWidget {
  const AIAnalyticsPage({super.key});

  @override
  ConsumerState<AIAnalyticsPage> createState() => _AIAnalyticsPageState();
}

class _AIAnalyticsPageState extends ConsumerState<AIAnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _hours = 24;
  String? _channelFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  AnalyticsParams get _params => AnalyticsParams(hours: _hours, channel: _channelFilter);

  void _refresh() {
    ref.invalidate(latencyAnalyticsProvider(_params));
    ref.invalidate(successRatesProvider(_params));
    ref.invalidate(roleUsageProvider(_hours));
    ref.invalidate(channelComparisonProvider(_hours));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحليلات الذكاء الاصطناعي'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'زمن الاستجابة', icon: Icon(Icons.timer)),
              Tab(text: 'معدلات النجاح', icon: Icon(Icons.pie_chart)),
              Tab(text: 'استخدام الأدوار', icon: Icon(Icons.people)),
              Tab(text: 'صوت vs نص', icon: Icon(Icons.compare_arrows)),
            ],
          ),
          actions: [
            _buildTimeRangeDropdown(),
            const SizedBox(width: 8),
            _buildChannelDropdown(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _LatencyTab(params: _params),
            _SuccessRatesTab(params: _params),
            _RoleUsageTab(hours: _hours),
            _ChannelComparisonTab(hours: _hours),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeDropdown() {
    return DropdownButton<int>(
      value: _hours,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 1, child: Text('ساعة')),
        DropdownMenuItem(value: 6, child: Text('6 ساعات')),
        DropdownMenuItem(value: 24, child: Text('24 ساعة')),
        DropdownMenuItem(value: 72, child: Text('3 أيام')),
        DropdownMenuItem(value: 168, child: Text('أسبوع')),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _hours = v);
      },
    );
  }

  Widget _buildChannelDropdown() {
    return DropdownButton<String?>(
      value: _channelFilter,
      underline: const SizedBox(),
      hint: const Text('القناة'),
      items: const [
        DropdownMenuItem(value: null, child: Text('كل القنوات')),
        DropdownMenuItem(value: 'voice_ws', child: Text('صوت')),
        DropdownMenuItem(value: 'chat', child: Text('محادثة')),
        DropdownMenuItem(value: 'chat_stream', child: Text('بث مباشر')),
      ],
      onChanged: (v) => setState(() => _channelFilter = v),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Tab 1: Latency
// ═════════════════════════════════════════════════════════════════

class _LatencyTab extends ConsumerWidget {
  final AnalyticsParams params;
  const _LatencyTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(latencyAnalyticsProvider(params));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlobalLatencyCards(data: data),
            const SizedBox(height: 24),
            Text('تفاصيل زمن الاستجابة لكل أداة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...data.tools.map((t) => _LatencyToolCard(metric: t)),
          ],
        ),
      ),
    );
  }
}

class _GlobalLatencyCards extends StatelessWidget {
  final LatencyAnalytics data;
  const _GlobalLatencyCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _MetricCard(label: 'إجمالي الطلبات', value: '${data.totalExecutions}', color: Colors.blue),
        _MetricCard(label: 'متوسط', value: '${data.globalAvgMs.toStringAsFixed(0)} ms', color: Colors.teal),
        _MetricCard(label: 'P50', value: '${data.globalP50Ms.toStringAsFixed(0)} ms', color: Colors.green),
        _MetricCard(label: 'P95', value: '${data.globalP95Ms.toStringAsFixed(0)} ms', color: Colors.orange),
      ],
    );
  }
}

class _LatencyToolCard extends StatelessWidget {
  final LatencyMetric metric;
  const _LatencyToolCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(metric.toolLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Text('${metric.callCount} طلب', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PercentileChip('MIN', metric.minMs, Colors.green.shade100),
                _PercentileChip('P50', metric.p50Ms, Colors.blue.shade50),
                _PercentileChip('P75', metric.p75Ms, Colors.amber.shade50),
                _PercentileChip('P95', metric.p95Ms, Colors.orange.shade50),
                _PercentileChip('P99', metric.p99Ms, Colors.red.shade50),
                _PercentileChip('MAX', metric.maxMs, Colors.red.shade100),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentileChip extends StatelessWidget {
  final String label;
  final double value;
  final Color bg;
  const _PercentileChip(this.label, this.value, this.bg);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text('${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('ms', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Tab 2: Success Rates
// ═════════════════════════════════════════════════════════════════

class _SuccessRatesTab extends ConsumerWidget {
  final AnalyticsParams params;
  const _SuccessRatesTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(successRatesProvider(params));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverallRatesCard(overall: data.overall),
            const SizedBox(height: 24),
            Text('معدلات لكل أداة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...data.perTool.map((t) => _ToolRateCard(data: t)),
          ],
        ),
      ),
    );
  }
}

class _OverallRatesCard extends StatelessWidget {
  final Map<String, dynamic> overall;
  const _OverallRatesCard({required this.overall});

  @override
  Widget build(BuildContext context) {
    final total = overall['total_calls'] ?? 0;
    final successRate = (overall['success_rate'] ?? 0).toDouble();
    final failureRate = (overall['failure_rate'] ?? 0).toDouble();
    final blockedRate = (overall['blocked_rate'] ?? 0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('$total طلب إجمالي', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                _RateGauge(label: 'نجاح', rate: successRate, color: Colors.green),
                _RateGauge(label: 'فشل', rate: failureRate, color: Colors.red),
                _RateGauge(label: 'محظور', rate: blockedRate, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    if (successRate > 0)
                      Expanded(flex: successRate.round(), child: Container(color: Colors.green)),
                    if (failureRate > 0)
                      Expanded(flex: failureRate.round(), child: Container(color: Colors.red)),
                    if (blockedRate > 0)
                      Expanded(flex: blockedRate.round(), child: Container(color: Colors.orange)),
                    if (100 - successRate - failureRate - blockedRate > 0)
                      Expanded(flex: (100 - successRate - failureRate - blockedRate).round(), child: Container(color: Colors.blue.shade100)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateGauge extends StatelessWidget {
  final String label;
  final double rate;
  final Color color;
  const _RateGauge({required this.label, required this.rate, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ToolRateCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ToolRateCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final toolLabel = data['tool_label'] ?? data['tool'] ?? '';
    final total = data['total'] ?? 0;
    final successRate = (data['success_rate'] ?? 0).toDouble();
    final failureRate = (data['failure_rate'] ?? 0).toDouble();
    final executed = data['executed'] ?? 0;
    final failed = data['failed'] ?? 0;
    final blocked = data['blocked'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(toolLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$total طلب', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      if (executed > 0) Expanded(flex: executed, child: Container(color: Colors.green)),
                      if (failed > 0) Expanded(flex: failed, child: Container(color: Colors.red)),
                      if (blocked > 0) Expanded(flex: blocked, child: Container(color: Colors.orange)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: Text(
                '${successRate.toStringAsFixed(0)}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: successRate >= 90 ? Colors.green : (successRate >= 70 ? Colors.orange : Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Tab 3: Role Usage
// ═════════════════════════════════════════════════════════════════

class _RoleUsageTab extends ConsumerWidget {
  final int hours;
  const _RoleUsageTab({required this.hours});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(roleUsageProvider(hours));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (roles) => roles.isEmpty
          ? const Center(child: Text('لا توجد بيانات'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: roles.length,
              itemBuilder: (context, index) => _RoleCard(role: roles[index]),
            ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final RoleUsage role;
  const _RoleCard({required this.role});

  String get _roleLabel {
    switch (role.role) {
      case 'admin': return 'مدير النظام';
      case 'manager': return 'مدير';
      case 'accountant': return 'محاسب';
      case 'cashier': return 'كاشير';
      case 'warehouse_employee': return 'أمين مخزن';
      case 'ai_agent': return 'وكيل AI';
      default: return role.role;
    }
  }

  String _channelLabel(String ch) {
    switch (ch) {
      case 'voice_ws': return 'صوت';
      case 'chat_stream': return 'بث مباشر';
      case 'chat': return 'محادثة';
      default: return ch;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(Icons.person, color: Colors.indigo.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_roleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${role.totalCalls} طلب | متوسط ${role.avgLatencyMs.toStringAsFixed(0)}ms', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${role.successRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                    Text('نجاح', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('القنوات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: role.channels.entries.map((e) {
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${_channelLabel(e.key)}: ${e.value}', style: const TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أكثر الأدوات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...role.topTools.entries.take(3).map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
            if (role.blockedRate > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'معدل الحظر: ${role.blockedRate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Tab 4: Channel Comparison (Voice vs Chat)
// ═════════════════════════════════════════════════════════════════

class _ChannelComparisonTab extends ConsumerWidget {
  final int hours;
  const _ChannelComparisonTab({required this.hours});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(channelComparisonProvider(hours));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (channels) => channels.isEmpty
          ? const Center(child: Text('لا توجد بيانات'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ChannelComparisonGrid(channels: channels),
                  const SizedBox(height: 24),
                  ...channels.map((ch) => _ChannelDetailCard(channel: ch)),
                ],
              ),
            ),
    );
  }
}

class _ChannelComparisonGrid extends StatelessWidget {
  final List<ChannelStats> channels;
  const _ChannelComparisonGrid({required this.channels});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade200),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1.5),
            5: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: const [
                _TableHeader('القناة'),
                _TableHeader('الطلبات'),
                _TableHeader('نجاح %'),
                _TableHeader('متوسط ms'),
                _TableHeader('P50 ms'),
                _TableHeader('P95 ms'),
              ],
            ),
            ...channels.map((ch) => TableRow(
              children: [
                _TableCell(_channelLabel(ch.channel), bold: true),
                _TableCell('${ch.totalCalls}'),
                _TableCell('${ch.successRate.toStringAsFixed(1)}%', color: ch.successRate >= 90 ? Colors.green : Colors.orange),
                _TableCell('${ch.avgMs.toStringAsFixed(0)}'),
                _TableCell('${ch.p50Ms.toStringAsFixed(0)}'),
                _TableCell('${ch.p95Ms.toStringAsFixed(0)}', color: ch.p95Ms > 2000 ? Colors.red : null),
              ],
            )),
          ],
        ),
      ),
    );
  }

  String _channelLabel(String ch) {
    switch (ch) {
      case 'voice_ws': return 'صوت (WebSocket)';
      case 'chat_stream': return 'بث مباشر (Stream)';
      case 'chat': return 'محادثة (Chat)';
      default: return ch;
    }
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  const _TableCell(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : null, color: color),
      ),
    );
  }
}

class _ChannelDetailCard extends StatelessWidget {
  final ChannelStats channel;
  const _ChannelDetailCard({required this.channel});

  String get _label {
    switch (channel.channel) {
      case 'voice_ws': return 'صوت (WebSocket)';
      case 'chat_stream': return 'بث مباشر (Stream)';
      case 'chat': return 'محادثة (Chat)';
      default: return channel.channel;
    }
  }

  IconData get _icon {
    switch (channel.channel) {
      case 'voice_ws': return Icons.mic;
      case 'chat_stream': return Icons.stream;
      case 'chat': return Icons.chat;
      default: return Icons.device_unknown;
    }
  }

  Color get _color {
    switch (channel.channel) {
      case 'voice_ws': return Colors.purple;
      case 'chat_stream': return Colors.blue;
      case 'chat': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _color.withOpacity(0.1),
                  child: Icon(_icon, color: _color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${channel.totalCalls} طلب', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        _MiniStat('نجاح', '${channel.successRate.toStringAsFixed(0)}%', Colors.green),
                        const SizedBox(width: 8),
                        _MiniStat('فشل', '${channel.failureRate.toStringAsFixed(0)}%', Colors.red),
                        const SizedBox(width: 8),
                        _MiniStat('حظر', '${channel.blockedRate.toStringAsFixed(0)}%', Colors.orange),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الأدوات الأكثر استخداماً', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...channel.topTools.entries.take(4).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الأدوار', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...channel.roles.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11))),
                            Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Shared
// ═════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
