/// APEX Platform — Working Capital + Cash Conversion Cycle
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class WorkingCapitalScreen extends StatefulWidget {
  const WorkingCapitalScreen({super.key});
  @override
  State<WorkingCapitalScreen> createState() => _WorkingCapitalScreenState();
}

class _WorkingCapitalScreenState extends State<WorkingCapitalScreen> {
  final _fields = <String, TextEditingController>{
    'revenue': TextEditingController(),
    'cogs': TextEditingController(),
    'accounts_receivable': TextEditingController(),
    'inventory': TextEditingController(),
    'accounts_payable': TextEditingController(),
    'current_assets': TextEditingController(),
    'current_liabilities': TextEditingController(),
    'cash': TextEditingController(),
  };
  final _periodC = TextEditingController(text: '${DateTime.now().year}-FY');
  int _periodDays = 365;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in _fields.values) { c.dispose(); }
    _periodC.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{
        'period_label': _periodC.text.trim(),
        'period_days': _periodDays,
      };
      _fields.forEach((k, c) {
        body[k] = c.text.trim().isEmpty ? '0' : c.text.trim();
      });
      final r = await ApiService.workingCapitalAnalyze(body);
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
    appBar: AppBar(title: Text('رأس المال العامل + CCC', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2),
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

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('قائمة الدخل'),
    _field('revenue', 'الإيرادات', Icons.trending_up),
    _field('cogs', 'تكلفة البضاعة المباعة', Icons.shopping_cart),
    _section('رأس المال العامل'),
    _field('accounts_receivable', 'المدينون (AR)', Icons.call_received),
    _field('inventory', 'المخزون', Icons.inventory_2),
    _field('accounts_payable', 'الدائنون (AP)', Icons.call_made),
    _field('cash', 'النقد', Icons.account_balance_wallet),
    _section('الميزانية'),
    _field('current_assets', 'إجمالي الأصول المتداولة', Icons.account_balance),
    _field('current_liabilities', 'إجمالي الخصوم المتداولة', Icons.payments),
    const SizedBox(height: 12),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _analyze,
      icon: _loading
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.sync),
      label: const Text('حلّل رأس المال العامل'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.sync, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل البيانات ثم اضغط "حلّل"', style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final health = d['health'] as String? ?? 'watch';
    final healthColor = health == 'healthy' ? AC.ok
      : (health == 'risk' ? AC.err : AC.warn);
    final healthLabel = health == 'healthy' ? 'ممتاز'
      : (health == 'risk' ? 'خطر' : 'مقبول');
    final recs = (d['recommendations'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // CCC hero
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [healthColor.withValues(alpha: 0.12), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: healthColor.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.sync, color: healthColor, size: 22),
            const SizedBox(width: 8),
            Text('دورة التحويل النقدي',
              style: TextStyle(color: healthColor, fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: healthColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6)),
              child: Text(healthLabel, style: TextStyle(
                color: healthColor, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(d['ccc'] == null ? '—' : '${d['ccc']} يوم',
            style: TextStyle(color: healthColor, fontSize: 30,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      // DSO/DIO/DPO cards
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1,
        children: [
          _cycleCard('DSO', d['dso'], 'التحصيل', AC.info, Icons.call_received),
          _cycleCard('DIO', d['dio'], 'المخزون', AC.warn, Icons.inventory),
          _cycleCard('DPO', d['dpo'], 'السداد', AC.ok, Icons.call_made),
        ],
      ),
      const SizedBox(height: 12),
      _balancesCard(d),
      if (recs.isNotEmpty) ...[
        const SizedBox(height: 12),
        _recsCard(recs),
      ],
    ]);
  }

  Widget _cycleCard(String label, dynamic value, String desc, Color color, IconData icon) =>
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const Spacer(),
        Text(label, style: TextStyle(color: AC.ts, fontSize: 10)),
        Text(value == null ? '—' : '$value',
          style: TextStyle(color: color, fontSize: 18,
            fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Text(desc, style: TextStyle(color: AC.td, fontSize: 10)),
      ]),
    );

  Widget _balancesCard(Map d) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الأرصدة', style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 8),
      _kv('رأس المال العامل', '${d['working_capital']} SAR', vc: AC.info),
      _kv('رأس المال العامل التشغيلي (دون نقد)', '${d['net_working_capital']} SAR'),
      if (d['current_ratio'] != null) _kv('نسبة التداول', '${d['current_ratio']}'),
      if (d['quick_ratio'] != null) _kv('النسبة السريعة', '${d['quick_ratio']}'),
    ]),
  );

  Widget _recsCard(List recs) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.gold.withValues(alpha: 0.08),
      border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.lightbulb, color: AC.gold, size: 16),
        const SizedBox(width: 6),
        Text('توصيات للتحسين',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      ...recs.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('• $r', style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
      )),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 6),
    child: Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _field(String k, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: _fields[k],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
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

  Widget _kv(String k, String v, {Color? vc}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 12,
        fontFamily: 'monospace', fontWeight: FontWeight.w600)),
    ]),
  );
}
