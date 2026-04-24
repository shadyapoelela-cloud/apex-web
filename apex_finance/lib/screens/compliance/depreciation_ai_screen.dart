/// APEX — AI-assisted Depreciation (IAS 16)
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class DepreciationAiScreen extends StatefulWidget {
  const DepreciationAiScreen({super.key});
  @override
  State<DepreciationAiScreen> createState() => _DepreciationAiScreenState();
}

class _DepreciationAiScreenState extends State<DepreciationAiScreen> {
  final _cost = TextEditingController(text: '100000');
  final _salvage = TextEditingController(text: '10000');
  final _life = TextEditingController(text: '5');
  String _method = 'straight_line';
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _run() async {
    setState(() => _loading = true);
    final res = await ApiService.aiDepreciationSchedule({
      'method': _method,
      'cost': double.tryParse(_cost.text) ?? 0,
      'salvage': double.tryParse(_salvage.text) ?? 0,
      'useful_life_periods': int.tryParse(_life.text) ?? 1,
    });
    if (!mounted) return;
    setState(() {
      _result = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      _loading = false;
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
          title: const Text('جدول إهلاك الأصول الثابتة (IAS 16)',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputs(),
              const SizedBox(height: 14),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_result != null) ..._renderResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputs() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _num(_cost, 'التكلفة الأصلية')),
              const SizedBox(width: 8),
              Expanded(child: _num(_salvage, 'قيمة السكراب')),
              const SizedBox(width: 8),
              Expanded(child: _num(_life, 'العمر الإنتاجي (فترات)')),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _method,
            dropdownColor: AC.navy2,
            style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
            decoration: InputDecoration(
              labelText: 'طريقة الإهلاك',
              labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
              filled: true, fillColor: AC.navy3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'straight_line', child: Text('خط مستقيم (Straight Line)', style: TextStyle(fontFamily: 'Tajawal'))),
              DropdownMenuItem(value: 'declining_balance', child: Text('رصيد متناقص', style: TextStyle(fontFamily: 'Tajawal'))),
              DropdownMenuItem(value: 'double_declining', child: Text('رصيد متناقص مُضاعف', style: TextStyle(fontFamily: 'Tajawal'))),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'straight_line'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.calculate),
            label: const Text('احسب الجدول', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
    decoration: InputDecoration(
      labelText: label, labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
      filled: true, fillColor: AC.navy3,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    ),
  );

  List<Widget> _renderResult() {
    final sched = (_result!['schedule'] as List?) ?? [];
    final total = _result!['total_depreciation'];
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(Icons.show_chart, color: AC.gold),
            const SizedBox(width: 10),
            Text('إجمالي الإهلاك: $total',
                style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ...sched.map((e) => _scheduleRow(e as Map)),
    ];
  }

  Widget _scheduleRow(Map e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#${e['seq']}',
              style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('رصيد افتتاح: ${e['opening_nbv']}',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5))),
          Text('إهلاك: ${e['depreciation']}',
              style: TextStyle(color: AC.err, fontFamily: 'Tajawal', fontSize: 11.5)),
          const SizedBox(width: 12),
          Text('رصيد إقفال: ${e['closing_nbv']}',
              style: TextStyle(color: AC.ok, fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
