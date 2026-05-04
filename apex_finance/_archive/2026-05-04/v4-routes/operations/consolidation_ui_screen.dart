/// APEX — Multi-Entity Consolidation UI
library;

import 'dart:convert';
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class ConsolidationUiScreen extends StatefulWidget {
  const ConsolidationUiScreen({super.key});
  @override
  State<ConsolidationUiScreen> createState() => _ConsolidationUiScreenState();
}

class _ConsolidationUiScreenState extends State<ConsolidationUiScreen> {
  final _groupNameCtl = TextEditingController(text: 'مجموعة أبكس');
  final _periodCtl = TextEditingController(text: 'FY ${DateTime.now().year}');
  final _currencyCtl = TextEditingController(text: 'SAR');
  final _jsonCtl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _jsonCtl.text = _sampleJson();
  }

  @override
  void dispose() {
    _groupNameCtl.dispose(); _periodCtl.dispose(); _currencyCtl.dispose(); _jsonCtl.dispose();
    super.dispose();
  }

  String _sampleJson() => '''[
  {
    "entity_id": "e1", "entity_name": "APEX السعودية", "currency": "SAR",
    "fx_rate_closing": 1.0, "fx_rate_average": 1.0,
    "lines": [
      {"code": "1110", "name_ar": "نقد", "classification": "asset", "debit": 500000, "credit": 0},
      {"code": "3000", "name_ar": "رأس المال", "classification": "equity", "debit": 0, "credit": 500000}
    ]
  },
  {
    "entity_id": "e2", "entity_name": "APEX الإمارات", "currency": "AED",
    "fx_rate_closing": 1.02, "fx_rate_average": 1.02,
    "lines": [
      {"code": "1110", "name_ar": "نقد", "classification": "asset", "debit": 200000, "credit": 0},
      {"code": "3000", "name_ar": "رأس المال", "classification": "equity", "debit": 0, "credit": 200000}
    ]
  }
]''';

  Future<void> _consolidate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entities = jsonDecode(_jsonCtl.text) as List;
      final r = await ApiService.aiConsolidate({
        'group_name': _groupNameCtl.text.trim(),
        'period_label': _periodCtl.text.trim(),
        'functional_currency': _currencyCtl.text.trim(),
        'entities': entities,
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (r.success && r.data != null) {
          _result = (r.data['data'] as Map).cast<String, dynamic>();
        } else {
          _error = r.error;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'JSON غير صالح: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('توحيد الكيانات — Consolidation',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _f(_groupNameCtl, 'اسم المجموعة')),
                  const SizedBox(width: 8),
                  Expanded(child: _f(_periodCtl, 'الفترة')),
                  const SizedBox(width: 8),
                  SizedBox(width: 110, child: _f(_currencyCtl, 'العملة الموحّدة')),
                ],
              ),
              const SizedBox(height: 10),
              Text('موازين الكيانات (JSON) — كل كيان له fx_rate_closing / fx_rate_average + lines',
                  style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5)),
              const SizedBox(height: 6),
              TextField(
                controller: _jsonCtl,
                maxLines: 16,
                style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11),
                decoration: InputDecoration(
                  filled: true, fillColor: AC.navy3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _loading ? null : _consolidate,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('توحيد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 14),
              if (_error != null) Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_result != null) _renderResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _f(TextEditingController c, String label) => TextField(
    controller: c,
    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
    decoration: InputDecoration(
      labelText: label, labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5),
      filled: true, fillColor: AC.navy3, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    ),
  );

  Widget _renderResult() {
    final r = _result!;
    final balanced = r['is_balanced'] == true;
    final color = balanced ? AC.ok : AC.err;
    final lines = ((r['lines'] as List?) ?? []).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r['group_name']} — ${r['period_label']}',
                  style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _kpi('كيانات', '${r['entity_count']}', AC.gold),
                  _kpi('مدين', '${r['total_debit']}', AC.ok),
                  _kpi('دائن', '${r['total_credit']}', AC.err),
                  _kpi('حذف بين الشركات', '${r['eliminations_count']}', AC.info),
                  _kpi('احتياطي الترجمة', '${r['translation_reserve']}', AC.gold),
                ],
              ),
              const SizedBox(height: 6),
              Text(balanced ? '✓ الميزان متوازن' : '⚠ غير متوازن',
                  style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('أسطر الميزان الموحّد', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...lines.map((ln) => Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text('${ln['code']}',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11))),
              Expanded(child: Text('${ln['name_ar']}',
                  style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12))),
              SizedBox(width: 90, child: Text('${ln['debit']}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 11.5))),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: Text('${ln['credit']}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 11.5))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
          Text(value, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}
