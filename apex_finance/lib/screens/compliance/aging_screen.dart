/// APEX Platform — AR/AP Aging Report
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class _Inv {
  final cpC = TextEditingController();
  final invC = TextEditingController();
  final invDateC = TextEditingController();
  final dueC = TextEditingController();
  final balC = TextEditingController();
  void dispose() { cpC.dispose(); invC.dispose(); invDateC.dispose(); dueC.dispose(); balC.dispose(); }
}

class AgingScreen extends StatefulWidget {
  const AgingScreen({super.key});
  @override
  State<AgingScreen> createState() => _AgingScreenState();
}

class _AgingScreenState extends State<AgingScreen> {
  String _kind = 'ar';
  final _asOfC = TextEditingController();
  final List<_Inv> _invs = [_Inv()];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _asOfC.dispose();
    for (final i in _invs) { i.dispose(); }
    super.dispose();
  }

  void _addInv() => setState(() => _invs.add(_Inv()));
  void _removeInv(int i) {
    if (_invs.length <= 1) return;
    _invs[i].dispose();
    setState(() => _invs.removeAt(i));
  }

  Future<void> _compute() async {
    final valid = _invs.where((i) => i.cpC.text.trim().isNotEmpty &&
        i.balC.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) { setState(() => _error = 'أضف فاتورة واحدة على الأقل'); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'kind': _kind,
        if (_asOfC.text.trim().isNotEmpty) 'as_of_date': _asOfC.text.trim(),
        'invoices': valid.map((i) => {
          'counterparty': i.cpC.text.trim(),
          'invoice_number': i.invC.text.trim().isEmpty ? 'INV' : i.invC.text.trim(),
          'invoice_date': i.invDateC.text.trim().isEmpty ? '2026-01-01' : i.invDateC.text.trim(),
          'due_date': i.dueC.text.trim().isEmpty ? '2026-02-01' : i.dueC.text.trim(),
          'balance': i.balC.text.trim(),
        }).toList(),
      };
      final r = await ApiService.agingReport(body);
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
    appBar: AppBar(title: Text('تقرير الأعمار (AR/AP)', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _form(),
        const SizedBox(height: 16),
        if (_result != null) _results(),
      ])),
  );

  Widget _form() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ar', label: Text('ذمم مدينة (AR)')),
            ButtonSegment(value: 'ap', label: Text('ذمم دائنة (AP)')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        )),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: _asOfC,
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: 'حتى تاريخ (YYYY-MM-DD) — فارغ = اليوم',
          prefixIcon: Icon(Icons.calendar_today, color: AC.goldText, size: 18),
          filled: true, fillColor: AC.navy3,
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text('الفواتير (${_invs.length})',
          style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(onPressed: _addInv,
          icon: const Icon(Icons.add, size: 16), label: const Text('إضافة فاتورة')),
      ]),
      ..._invs.asMap().entries.map((e) => _invRow(e.key, e.value)),
      const SizedBox(height: 10),
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
          : const Icon(Icons.bar_chart),
        label: const Text('ابنِ التقرير'))),
    ]),
  );

  Widget _invRow(int idx, _Inv inv) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Row(children: [
        Expanded(flex: 3, child: _mini(inv.cpC, _kind == 'ar' ? 'العميل' : 'المورّد')),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _mini(inv.invC, 'رقم الفاتورة')),
        if (_invs.length > 1)
          IconButton(icon: Icon(Icons.close, color: AC.err, size: 16),
            onPressed: () => _removeInv(idx), padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: _mini(inv.invDateC, 'تاريخ الفاتورة', monospace: true)),
        const SizedBox(width: 6),
        Expanded(child: _mini(inv.dueC, 'تاريخ الاستحقاق', monospace: true)),
        const SizedBox(width: 6),
        Expanded(child: _mini(inv.balC, 'الرصيد', monospace: true,
          keyboard: const TextInputType.numberWithOptions(decimal: true))),
      ]),
    ]),
  );

  Widget _mini(TextEditingController c, String hint,
      {bool monospace = false, TextInputType? keyboard}) =>
    TextField(
      controller: c,
      keyboardType: keyboard,
      style: TextStyle(color: AC.tp, fontSize: 11,
        fontFamily: monospace ? 'monospace' : null),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: AC.td, fontSize: 10),
        isDense: true, filled: true, fillColor: AC.navy2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AC.bdr)),
      ),
    );

  Widget _results() {
    final d = _result!;
    final buckets = (d['buckets'] ?? []) as List;
    final byCp = (d['by_counterparty'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;
    final isAr = d['kind'] == 'ar';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('إجمالي ${isAr ? "الذمم المدينة" : "الذمم الدائنة"}',
            style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_outstanding']} SAR',
            style: TextStyle(color: AC.gold, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text('حتى: ${d['as_of_date']}', style: TextStyle(color: AC.ts, fontSize: 11)),
          if (isAr) ...[
            Divider(color: AC.bdr, height: 16),
            _kv('مخصص الخسائر الائتمانية المتوقعة (ECL)',
              '${d['total_ecl']} SAR', vc: AC.err, bold: true),
          ],
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.warn.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map<Widget>((w) => Text('• $w',
              style: TextStyle(color: AC.tp, fontSize: 11))).toList()),
        ),
      ],
      const SizedBox(height: 14),
      _bucketsCard(buckets, isAr),
      const SizedBox(height: 12),
      _cpCard(byCp),
    ]);
  }

  Widget _bucketsCard(List buckets, bool isAr) => Container(
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Text('توزيع الأعمار',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13))),
      ...buckets.asMap().entries.map((e) {
        final b = e.value as Map;
        final pct = double.tryParse((b['percentage'] ?? '0').toString()) ?? 0;
        final isLast = e.key == buckets.length - 1;
        final color = b['code'] == 'current' ? AC.ok
          : (b['code'] == 'd1_30' ? AC.info
          : (b['code'] == 'd31_60' ? AC.warn
          : (b['code'] == 'd61_90' ? AC.warn : AC.err)));
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(b['label']?.toString() ?? '',
                  style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w600))),
                Text('${b['count']} فاتورة',
                  style: TextStyle(color: AC.ts, fontSize: 10)),
                const SizedBox(width: 8),
                Text('${b['total']} SAR',
                  style: TextStyle(color: color, fontSize: 12,
                    fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0, 1).toDouble(),
                  minHeight: 4,
                  backgroundColor: AC.navy3,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Text('${b['percentage']}% من الإجمالي',
                  style: TextStyle(color: AC.ts, fontSize: 10)),
                if (isAr) ...[
                  const Spacer(),
                  Text('ECL ${b['ecl_rate_pct']}% = ${b['ecl_amount']}',
                    style: TextStyle(color: AC.err, fontSize: 10, fontFamily: 'monospace')),
                ],
              ]),
            ]),
          ),
          if (!isLast) Divider(color: AC.bdr, height: 1),
        ]);
      }),
    ]),
  );

  Widget _cpCard(List cps) => Container(
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Text('حسب الطرف',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13))),
      ...cps.asMap().entries.map((e) {
        final cp = e.value as Map;
        final isLast = e.key == cps.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(child: Text(cp['counterparty']?.toString() ?? '',
                style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w600))),
              Text('${cp['total']} SAR',
                style: TextStyle(color: AC.gold, fontSize: 12,
                  fontFamily: 'monospace', fontWeight: FontWeight.w700)),
            ]),
          ),
          if (!isLast) Divider(color: AC.bdr, height: 1),
        ]);
      }),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
