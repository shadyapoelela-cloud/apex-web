/// APEX — Audit Workflow (Benford + JE Sample + Workpapers)
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class AiAuditWorkflowScreen extends StatefulWidget {
  const AiAuditWorkflowScreen({super.key});
  @override
  State<AiAuditWorkflowScreen> createState() => _AiAuditWorkflowScreenState();
}

class _AiAuditWorkflowScreenState extends State<AiAuditWorkflowScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('ورشة المراجعة',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.ts,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'قانون بنفورد', icon: Icon(Icons.show_chart, size: 16)),
              Tab(text: 'عينة قيود', icon: Icon(Icons.casino_outlined, size: 16)),
              Tab(text: 'أوراق العمل', icon: Icon(Icons.folder_open, size: 16)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [_BenfordTab(), _JeSampleTab(), _WorkpapersTab()],
        ),
      ),
    );
  }
}

// ── Benford ──────────────────────────────────────────────

class _BenfordTab extends StatefulWidget {
  const _BenfordTab();
  @override
  State<_BenfordTab> createState() => _BenfordTabState();
}

class _BenfordTabState extends State<_BenfordTab> {
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _run() async {
    setState(() => _loading = true);
    final res = await ApiService.aiBenford();
    if (!mounted) return;
    setState(() {
      _result = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'توزيع الرقم الأول لمبالغ القيود — يُفيد في كشف التلاعب أو جودة البيانات.',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.play_arrow),
            label: const Text('شغّل الاختبار', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
          const SizedBox(height: 16),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loading && _result != null) Expanded(child: _renderResult()),
        ],
      ),
    );
  }

  Widget _renderResult() {
    final rows = (_result!['rows'] as List?) ?? [];
    final n = _result!['sample_size'];
    final passes = _result!['passes_95'] == true;
    final flagged = (_result!['flagged_digits'] as List?)?.join('، ') ?? '';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (passes ? AC.ok : AC.err).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passes ? '✓ النتيجة متسقة مع بنفورد' : '⚠ النتيجة لا تتسق مع بنفورد',
                  style: TextStyle(
                    color: passes ? AC.ok : AC.err,
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('حجم العينة: $n', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5)),
                if (flagged.isNotEmpty)
                  Text('أرقام ملفتة للانتباه: $flagged',
                      style: TextStyle(color: AC.err, fontFamily: 'Tajawal', fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map((r) => _digitBar(r as Map)),
        ],
      ),
    );
  }

  Widget _digitBar(Map r) {
    final exp = (r['expected_pct'] ?? 0) as num;
    final obs = (r['observed_pct'] ?? 0) as num;
    final dev = (r['deviation_pct'] ?? 0) as num;
    final color = dev.abs() > 2 ? AC.err : AC.ok;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${r['digit']}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: AC.navy3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (obs / 40).clamp(0, 1).toDouble(),
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    'متوقع ${exp.toStringAsFixed(1)}% / فعلي ${obs.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text('${dev >= 0 ? '+' : ''}${dev.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── JE Sample ────────────────────────────────────────────

class _JeSampleTab extends StatefulWidget {
  const _JeSampleTab();
  @override
  State<_JeSampleTab> createState() => _JeSampleTabState();
}

class _JeSampleTabState extends State<_JeSampleTab> {
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  final _sizeCtl = TextEditingController(text: '25');
  final _thresholdCtl = TextEditingController(text: '10000');

  Future<void> _run() async {
    setState(() => _loading = true);
    final res = await ApiService.aiJeSample(
      sampleSize: int.tryParse(_sizeCtl.text) ?? 25,
      thresholdAmount: double.tryParse(_thresholdCtl.text) ?? 10000,
    );
    if (!mounted) return;
    final list = ((res.data?['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    setState(() {
      _rows = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'عيّنة حتمية للاختبار (SOX / ISA 240) — كل القيود فوق حد المادية + عشوائي Seeded تحتها.',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _input(_sizeCtl, 'حجم العينة')),
              const SizedBox(width: 8),
              Expanded(child: _input(_thresholdCtl, 'حد المادية (ريال)')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _run,
                icon: const Icon(Icons.refresh),
                label: const Text('اسحب عيّنة', style: TextStyle(fontFamily: 'Tajawal')),
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loading) Expanded(child: _table()),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _table() {
    if (_rows.isEmpty) {
      return Center(child: Text('لا توجد قيود — شغّل السحب', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')));
    }
    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = _rows[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['je_number']} — ${r['memo']}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${r['je_date']}'.split('T').first,
                        style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5)),
                  ],
                ),
              ),
              Text('${r['total']} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

// ── Workpapers ───────────────────────────────────────────

class _WorkpapersTab extends StatefulWidget {
  const _WorkpapersTab();
  @override
  State<_WorkpapersTab> createState() => _WorkpapersTabState();
}

class _WorkpapersTabState extends State<_WorkpapersTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.aiListWorkpapers();
    if (!mounted) return;
    setState(() {
      _list = ((res.data?['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _open(String id) async {
    final res = await ApiService.aiGetWorkpaper(id);
    if (!mounted) return;
    setState(() => _selected = (res.data?['data'] as Map?)?.cast<String, dynamic>());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: _list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final r = _list[i];
              final selected = _selected?['id'] == r['id'];
              return InkWell(
                onTap: () => _open(r['id'] as String),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected ? AC.gold.withValues(alpha: 0.15) : AC.navy2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? AC.gold : AC.gold.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['name_ar']}',
                          style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${r['objective_ar']}',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(child: _selected == null ? const Center(child: Text('اختر ورقة عمل')) : _renderWorkpaper()),
      ],
    );
  }

  Widget _renderWorkpaper() {
    final risks = (_selected!['risks_ar'] as List?)?.cast<String>() ?? const [];
    final proc = (_selected!['procedures_ar'] as List?)?.cast<String>() ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_selected!['name_ar']}',
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _section('الهدف', [_selected!['objective_ar'] as String]),
          _section('المخاطر', risks),
          _section('الإجراءات', proc),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...items.map((it) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal')),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(it, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5, height: 1.5)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
