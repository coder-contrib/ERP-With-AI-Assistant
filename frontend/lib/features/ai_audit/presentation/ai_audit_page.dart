import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_audit_repository.dart';
import 'ai_audit_provider.dart';

class AIAuditPage extends ConsumerStatefulWidget {
  const AIAuditPage({super.key});

  @override
  ConsumerState<AIAuditPage> createState() => _AIAuditPageState();
}

class _AIAuditPageState extends ConsumerState<AIAuditPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _statusFilter;
  String? _categoryFilter;

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

  AuditFeedParams get _feedParams => AuditFeedParams(
        statusFilter: _statusFilter,
        categoryFilter: _categoryFilter,
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة مراقبة الذكاء الاصطناعي'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'النشاط', icon: Icon(Icons.timeline)),
              Tab(text: 'الإحصائيات', icon: Icon(Icons.bar_chart)),
              Tab(text: 'المحظورات', icon: Icon(Icons.block)),
              Tab(text: 'الأداء', icon: Icon(Icons.speed)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(auditFeedProvider(_feedParams));
                ref.invalidate(auditStatsProvider);
                ref.invalidate(auditBlockedProvider);
                ref.invalidate(auditPerformanceProvider);
              },
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFeedTab(),
            _buildStatsTab(),
            _buildBlockedTab(),
            _buildPerformanceTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedTab() {
    final feedAsync = ref.watch(auditFeedProvider(_feedParams));

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: feedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (items) => items.isEmpty
                ? const Center(child: Text('لا يوجد نشاط بعد', style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _FeedItemCard(item: items[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('الكل', null, _statusFilter, (v) => setState(() => _statusFilter = v)),
          const SizedBox(width: 6),
          _buildFilterChip('تم التنفيذ', 'executed', _statusFilter, (v) => setState(() => _statusFilter = v)),
          const SizedBox(width: 6),
          _buildFilterChip('محظور', 'blocked', _statusFilter, (v) => setState(() => _statusFilter = v)),
          const SizedBox(width: 6),
          _buildFilterChip('فشل', 'failed', _statusFilter, (v) => setState(() => _statusFilter = v)),
          const SizedBox(width: 6),
          _buildFilterChip('بانتظار', 'pending_confirmation', _statusFilter, (v) => setState(() => _statusFilter = v)),
          const Spacer(),
          DropdownButton<String?>(
            value: _categoryFilter,
            hint: const Text('الفئة'),
            items: const [
              DropdownMenuItem(value: null, child: Text('كل الفئات')),
              DropdownMenuItem(value: 'مبيعات', child: Text('مبيعات')),
              DropdownMenuItem(value: 'مالية', child: Text('مالية')),
              DropdownMenuItem(value: 'مخزون', child: Text('مخزون')),
              DropdownMenuItem(value: 'عملاء', child: Text('عملاء')),
              DropdownMenuItem(value: 'فواتير', child: Text('فواتير')),
              DropdownMenuItem(value: 'بحث', child: Text('بحث')),
            ],
            onChanged: (v) => setState(() => _categoryFilter = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, String? current, Function(String?) onTap) {
    final isSelected = current == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (_) => onTap(value),
    );
  }

  Widget _buildStatsTab() {
    final statsAsync = ref.watch(auditStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSummaryCards(stats),
            const SizedBox(height: 24),
            const Text('حسب الحالة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatusBars(stats),
            const SizedBox(height: 24),
            const Text('حسب الفئة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildCategoryChips(stats),
            const SizedBox(height: 24),
            const Text('أكثر الأدوات استخداماً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToolUsageList(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummaryCards(AuditStats stats) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          title: 'إجمالي الطلبات',
          value: '${stats.totalCalls}',
          icon: Icons.analytics,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'تم التنفيذ',
          value: '${stats.byStatus['executed'] ?? 0}',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _StatCard(
          title: 'محظور',
          value: '${stats.byStatus['blocked'] ?? 0}',
          icon: Icons.block,
          color: Colors.red,
        ),
        _StatCard(
          title: 'متوسط الاستجابة',
          value: '${stats.avgExecutionMs.toStringAsFixed(0)} ms',
          icon: Icons.timer,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatusBars(AuditStats stats) {
    final total = stats.totalCalls > 0 ? stats.totalCalls : 1;
    return Column(
      children: [
        _ProgressRow(label: 'تم التنفيذ', value: stats.byStatus['executed'] ?? 0, total: total, color: Colors.green),
        _ProgressRow(label: 'محظور', value: stats.byStatus['blocked'] ?? 0, total: total, color: Colors.red),
        _ProgressRow(label: 'فشل', value: stats.byStatus['failed'] ?? 0, total: total, color: Colors.amber),
        _ProgressRow(label: 'بانتظار التأكيد', value: stats.byStatus['pending_confirmation'] ?? 0, total: total, color: Colors.blue),
      ],
    );
  }

  Widget _buildCategoryChips(AuditStats stats) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.byCategory.entries.map((e) {
        return Chip(
          label: Text('${e.key}: ${e.value}'),
          backgroundColor: Colors.grey.shade100,
        );
      }).toList(),
    );
  }

  Widget _buildToolUsageList(AuditStats stats) {
    return Column(
      children: stats.byTool.entries.map((e) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.build, size: 18),
          title: Text(e.key),
          trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      }).toList(),
    );
  }

  Widget _buildBlockedTab() {
    final blockedAsync = ref.watch(auditBlockedProvider);

    return blockedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (items) => items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('لا توجد محاولات محظورة', style: TextStyle(fontSize: 18)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) => _BlockedItemCard(item: items[index]),
            ),
    );
  }

  Widget _buildPerformanceTab() {
    final perfAsync = ref.watch(auditPerformanceProvider);

    return perfAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (tools) => tools.isEmpty
          ? const Center(child: Text('لا توجد بيانات أداء بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tools.length,
              itemBuilder: (context, index) => _PerformanceCard(tool: tools[index]),
            ),
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  final AuditFeedItem item;
  const _FeedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withOpacity(0.15),
          child: Icon(_statusIcon, color: _statusColor, size: 20),
        ),
        title: Text(item.toolLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                _badge(item.category, Colors.grey.shade200),
                const SizedBox(width: 6),
                _badge(item.role, Colors.blue.shade50),
                const Spacer(),
                Text(
                  _formatTime(item.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (item.executionMs > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${item.executionMs}ms',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _badge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }

  Color get _statusColor {
    switch (item.status) {
      case 'executed': return Colors.green;
      case 'blocked': return Colors.red;
      case 'failed': return Colors.amber.shade700;
      case 'pending_confirmation': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case 'executed': return Icons.check_circle_outline;
      case 'blocked': return Icons.block;
      case 'failed': return Icons.warning_amber_rounded;
      case 'pending_confirmation': return Icons.hourglass_top;
      default: return Icons.circle_outlined;
    }
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp.length > 16 ? timestamp.substring(11, 16) : timestamp;
    }
  }
}

class _BlockedItemCard extends StatelessWidget {
  final BlockedAction item;
  const _BlockedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.red.shade50,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.block, color: Colors.white, size: 20),
        ),
        title: Text(item.toolLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.reason, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('الدور: ${item.role}', style: const TextStyle(fontSize: 11)),
                const Spacer(),
                Text(
                  item.timestamp.length > 16 ? item.timestamp.substring(0, 16) : item.timestamp,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final ToolPerformance tool;
  const _PerformanceCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _healthColor.withOpacity(0.15),
              child: Icon(Icons.speed, color: _healthColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.toolLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${tool.callCount} طلب', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('AVG ${tool.avgMs.toStringAsFixed(0)}ms', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('P95 ${tool.p95Ms.toStringAsFixed(0)}ms', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _healthColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _healthLabel,
                style: TextStyle(fontSize: 11, color: _healthColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _healthColor {
    switch (tool.health) {
      case 'fast': return Colors.green;
      case 'slow': return Colors.red;
      default: return Colors.orange;
    }
  }

  String get _healthLabel {
    switch (tool.health) {
      case 'fast': return 'سريع';
      case 'slow': return 'بطيء';
      default: return 'عادي';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressRow({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / total,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
