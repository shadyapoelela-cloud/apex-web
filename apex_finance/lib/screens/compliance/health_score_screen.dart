/// APEX Platform — Financial Health Score (Composite)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class HealthScoreScreen extends StatefulWidget {
  const HealthScoreScreen({super.key});
  @override
  State<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends State<HealthScoreScreen> {
  final _fields = <String, TextEditingController>{
    'current_ratio': TextEditingController(),
    'quick_ratio': TextEditingController(),
    'debt_to_equity': TextEditingController(),
    'interest_coverage': TextEditingController(),
    'net_margin_pct': TextEditingController(),
    'roe_pct': TextEditingController(),
    'asset_turnover': TextEditingController(),
    'ccc_days': TextEditingController(),
    'ocf_to_ni_ratio': TextEditingController(),
    'ocf_ratio': TextEditingController(),
  };
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in _fields.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{};
      _fields.forEach((k, c) {
        final v = c.text.trim();
        if (v.isNotEmpty) body[k] = v;
      });
      final r = await ApiService.healthScoreCompute(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل');
      }
    } catch (e) { if (mounted) setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('مؤشر الصحة المالية المركّب',
      style: TextStyle(color: AC.gold)), backgroundColor: AC.navy2),
    body: LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 900;
      if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _form())),
        Container(width: 1, color: AC.bdr),
        Expanded(flex: 6, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _results())),
      ]);
    }),
  );

  Widget _form() {
    final groups = [
      ('السيولة (20%)', [
        ('current_ratio', 'نسبة التداول'),
        ('quick_ratio', 'النسبة السريعة'),
      ]),
      ('الملاءة (20%)', [
        ('debt_to_equity', 'الدين/حقوق الملكية'),
        ('interest_coverage', 'تغطية الفائدة'),
      ]),
      ('الربحية (25%)', [
        ('net_margin_pct', 'هامش صافي الربح %'),
        ('roe_pct', 'ROE %'),
      ]),
      ('الكفاءة (20%)', [
        ('asset_turnover', 'دوران الأصول'),
        ('ccc_days', 'CCC (أيام)'),
      ]),
      ('جودة النقد (15%)', [
        ('ocf_to_ni_ratio', 'OCF/صافي الربح'),
        ('ocf_ratio', 'OCF/الخصوم المتداولة'),
      ]),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.info_outline, color: AC.info, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(
            'أدخل ما لديك من مؤشرات — الحقول الفارغة ستُستبعد من الحساب',
            style: TextStyle(color: AC.tp, fontSize: 11))),
        ]),
      ),
      const SizedBox(height: 14),
      ...groups.map((g) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(g.$1, style: TextStyle(
            color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        ...g.$2.map((f) => _field(f.$1, f.$2)),
      ])),
      const SizedBox(height: 12),
      if (_error != null) Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6)),
        child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
      ),
      const SizedBox(height: 8),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.speed),
        label: const Text('احسب المؤشر'))),
    ]);
  }

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.speed, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل المؤشرات لحساب الدرجة', style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final score = d['composite_score'] as int;
    final grade = d['grade'] as String;
    final color = _gradeColor(grade);
    final dims = (d['dimensions'] ?? []) as List;
    final redFlags = (d['red_flags'] ?? []) as List;
    final strengths = (d['strengths'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Big gauge
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 150, height: 150,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 12,
                backgroundColor: AC.navy4,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$score', style: TextStyle(
                color: color, fontSize: 42, fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
              Text('/ 100', style: TextStyle(color: AC.ts, fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8)),
            child: Text('$grade · ${d['grade_label_ar']}',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      // Dimensions
      ...dims.map((dim) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _dimRow(dim as Map),
      )),
      if (redFlags.isNotEmpty) ...[
        const SizedBox(height: 12),
        _flagsCard('مناطق الخطر', redFlags, AC.err, Icons.warning_amber_rounded),
      ],
      if (strengths.isNotEmpty) ...[
        const SizedBox(height: 12),
        _flagsCard('نقاط القوة', strengths, AC.ok, Icons.check_circle),
      ],
    ]);
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A': return AC.ok;
      case 'B': return AC.info;
      case 'C': return AC.warn;
      case 'D': return AC.warn;
      default: return AC.err;
    }
  }

  Widget _dimRow(Map d) {
    final score = d['score'] as int;
    final color = score >= 70 ? AC.ok : (score >= 50 ? AC.warn : AC.err);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(d['name_ar']?.toString() ?? '',
            style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700))),
          Text('${d['weight_pct']}% وزن',
            style: TextStyle(color: AC.ts, fontSize: 10)),
          const SizedBox(width: 8),
          Text('$score',
            style: TextStyle(color: color, fontSize: 16,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: AC.navy4,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }

  Widget _flagsCard(String title, List items, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      ...items.map((it) {
        final m = it as Map;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(m['name_ar']?.toString() ?? '',
              style: TextStyle(color: AC.tp, fontSize: 12))),
            if (m['value'] != null)
              Text('${m['value']}',
                style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4)),
              child: Text('${m['score']}',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      }),
    ]),
  );

  Widget _field(String k, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: _fields[k],
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        filled: true, fillColor: AC.navy3,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AC.goldText)),
      ),
    ),
  );
}
