import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class RoadmapScreen extends StatefulWidget {
  final String uploadId;
  final String clientId;
  final String clientName;

  const RoadmapScreen({
    super.key,
    required this.uploadId,
    this.clientId = '',
    this.clientName = '',
  });

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getRoadmap(widget.uploadId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        final d = res.data;
        if (d is List) {
          _items = d.cast<Map<String, dynamic>>();
        } else if (d is Map) {
          _items = ((d['data'] ?? d['items'] ?? []) as List).cast<Map<String, dynamic>>();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('خارطة الإصلاح', style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700, fontSize: 18)),
            if (widget.clientName.isNotEmpty) Text(widget.clientName, style: TextStyle(color: AC.ts, fontSize: 12)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(height: 2, color: AC.gold.withValues(alpha: 0.3))),
          iconTheme: IconThemeData(color: AC.tp),
          actions: [
            IconButton(icon: Icon(Icons.refresh_rounded, color: AC.gold), onPressed: () { setState(() => _loading = true); _load(); }),
          ],
        ),
        body: _loading ? _buildLoading() : _items.isEmpty ? _buildEmpty() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: List.generate(5, (_) => apexShimmerCard(height: 80))),
  );

  Widget _buildEmpty() => apexEmptyState(
    icon: Icons.map_rounded,
    title: 'لا توجد إصلاحات مطلوبة',
    subtitle: 'شجرة الحسابات مكتملة ولا تحتاج إلى تعديلات',
  );

  Widget _buildContent() {
    final totalMinutes = _items.fold<int>(0, (sum, i) => sum + ((i['estimated_minutes'] ?? 0) as int));
    final categories = <String, int>{};
    for (final item in _items) {
      final cat = item['category'] ?? 'other';
      categories[cat] = (categories[cat] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ApexStaggeredList(children: [
        _buildSummaryBar(totalMinutes, categories),
        const SizedBox(height: 12),
        apexSectionHeader('خطة العمل المرتبة بالأولوية', subtitle: '${_items.length} إجراء'),
        ..._items.map((item) => _buildActionCard(item)),
      ]),
    );
  }

  Widget _buildSummaryBar(int totalMinutes, Map<String, int> categories) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final timeLabel = hours > 0 ? '$hours ساعة ${mins > 0 ? 'و $mins دقيقة' : ''}' : '$mins دقيقة';

    return apexSoftCard(children: [
      Row(children: [
        Expanded(child: _summaryItem(Icons.format_list_numbered_rounded, '${_items.length}', 'إجراء', AC.info)),
        Expanded(child: _summaryItem(Icons.timer_rounded, timeLabel, 'الوقت المقدر', AC.warn)),
        Expanded(child: _summaryItem(Icons.category_rounded, '${categories.length}', 'فئة', AC.purple)),
      ]),
      if (categories.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 6, children: categories.entries.map((e) =>
          apexPill('${_categoryLabel(e.key)} (${e.value})', color: _categoryColor(e.key)),
        ).toList()),
      ],
    ]);
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: AC.td, fontSize: 11)),
    ]);
  }

  Widget _buildActionCard(Map<String, dynamic> item) {
    final rank = item['rank'] ?? 0;
    final category = item['category'] ?? '';
    final effort = item['effort'] ?? '';
    final color = _categoryColor(category);

    return ApexHoverCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('$rank', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['action_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            apexPill(_categoryLabel(category), color: color),
            apexPill(effort, color: _effortColor(effort)),
            if (item['score_impact'] != null) apexPill(item['score_impact'], color: AC.ok),
            if (item['estimated_minutes'] != null) apexPill('${item['estimated_minutes']} دقيقة', color: AC.td),
          ]),
          if (item['compliance_ref'] != null && item['compliance_ref'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('المرجع: ${item['compliance_ref']}', style: TextStyle(color: AC.td, fontSize: 11)),
          ],
        ])),
      ]),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'structural': return 'هيكلي';
      case 'manual_medium': return 'يدوي متوسط';
      case 'auto_fix': return 'إصلاح تلقائي';
      case 'manual_simple': return 'يدوي بسيط';
      default: return cat;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'structural': return AC.purple;
      case 'manual_medium': return AC.warn;
      case 'auto_fix': return AC.ok;
      case 'manual_simple': return AC.info;
      default: return AC.ts;
    }
  }

  Color _effortColor(String effort) {
    if (effort.contains('سهل')) return AC.ok;
    if (effort.contains('متوسط')) return AC.warn;
    if (effort.contains('صعب')) return AC.err;
    return AC.ts;
  }
}
