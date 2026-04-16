/// APEX Platform — Break-even Analysis
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class BreakevenScreen extends StatefulWidget {
  const BreakevenScreen({super.key});
  @override
  State<BreakevenScreen> createState() => _BreakevenScreenState();
}

class _BreakevenScreenState extends State<BreakevenScreen> {
  final _fixedC = TextEditingController();
  final _priceC = TextEditingController();
  final _vcuC = TextEditingController();
  final _targetC = TextEditingController();
  final _actualC = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_fixedC, _priceC, _vcuC, _targetC, _actualC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'fixed_costs': _fixedC.text.trim().isEmpty ? '0' : _fixedC.text.trim(),
        'unit_price': _priceC.text.trim().isEmpty ? '0' : _priceC.text.trim(),
        'variable_cost_per_unit': _vcuC.text.trim().isEmpty ? '0' : _vcuC.text.trim(),
        'target_profit': _targetC.text.trim().isEmpty ? '0' : _targetC.text.trim(),
        if (_actualC.text.trim().isNotEmpty) 'actual_units_sold': _actualC.text.trim(),
      };
      final r = await ApiService.breakevenCompute(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل الحساب');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('تحليل نقطة التعادل', style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _inputCard(),
          const SizedBox(height: 16),
          if (_result != null) _resultsCard(),
        ]),
      ),
    );
  }

  Widget _inputCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section('بيانات التحليل'),
      _numField(_fixedC, 'التكاليف الثابتة *', Icons.account_balance),
      Row(children: [
        Expanded(child: _numField(_priceC, 'سعر البيع للوحدة *', Icons.price_change)),
        const SizedBox(width: 10),
        Expanded(child: _numField(_vcuC, 'التكلفة المتغيرة/الوحدة *', Icons.remove_circle)),
      ]),
      _section('تحليل مستهدف (اختياري)'),
      Row(children: [
        Expanded(child: _numField(_targetC, 'الربح المستهدف', Icons.flag)),
        const SizedBox(width: 10),
        Expanded(child: _numField(_actualC, 'المبيعات الفعلية (وحدات)', Icons.show_chart)),
      ]),
      const SizedBox(height: 12),
      if (_error != null) Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.err.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AC.err.withValues(alpha: 0.35)),
        ),
        child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
      ),
      SizedBox(height: 54, child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.balance),
        label: const Text('احسب نقطة التعادل', style: TextStyle(fontSize: 16)),
      )),
    ]),
  );

  Widget _resultsCard() {
    final d = _result!;
    final beUnits = d['break_even_units'];
    final beRev = d['break_even_revenue']?.toString() ?? '—';
    final targetUnits = d['target_units'];
    final targetRev = d['target_revenue']?.toString() ?? '—';
    final cmPerUnit = d['contribution_margin_per_unit']?.toString() ?? '—';
    final cmRatio = d['contribution_margin_ratio_pct']?.toString() ?? '—';
    final mosUnits = d['margin_of_safety_units'];
    final mosPct = d['margin_of_safety_pct']?.toString() ?? '—';
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heroCard(beUnits, beRev, cmRatio),
      const SizedBox(height: 12),
      _cmCard(cmPerUnit, cmRatio),
      if (targetUnits != null) ...[
        const SizedBox(height: 12),
        _targetCard(targetUnits, targetRev, d['target_profit']),
      ],
      if (mosUnits != null) ...[
        const SizedBox(height: 12),
        _mosCard(mosUnits, mosPct),
      ],
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warnCard(warnings),
      ],
    ]);
  }

  Widget _heroCard(dynamic units, String rev, String cmRatio) {
    final hasResult = units != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AC.gold.withValues(alpha: 0.14), AC.navy3],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.balance, color: AC.gold, size: 24),
          const SizedBox(width: 8),
          Text('نقطة التعادل',
            style: TextStyle(color: AC.gold, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        if (hasResult) ...[
          Text('$units وحدة',
            style: TextStyle(color: AC.tp, fontSize: 32,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text('تعادل $rev SAR من الإيرادات',
            style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w600)),
        ] else
          Text('لا توجد نقطة تعادل — راجع هامش المساهمة',
            style: TextStyle(color: AC.err, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AC.info.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('نسبة هامش المساهمة: $cmRatio%',
            style: TextStyle(color: AC.info, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _cmCard(String cmPer, String cmRatio) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('تحليل هامش المساهمة',
        style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 8),
      _kv('هامش المساهمة للوحدة', '$cmPer SAR'),
      _kv('نسبة هامش المساهمة', '$cmRatio%', vc: AC.info),
      const SizedBox(height: 6),
      Text('كل وحدة مبيعة تساهم بهذا المبلغ في تغطية التكاليف الثابتة والربح.',
        style: TextStyle(color: AC.ts, fontSize: 11, height: 1.5)),
    ]),
  );

  Widget _targetCard(dynamic units, String rev, dynamic target) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.ok.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.ok.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Row(children: [
        Icon(Icons.flag, color: AC.ok, size: 18),
        const SizedBox(width: 6),
        Text('هدف ربح $target SAR',
          style: TextStyle(color: AC.ok, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      _kv('الوحدات المطلوبة', '$units'),
      _kv('الإيرادات المطلوبة', '$rev SAR', vc: AC.ok, bold: true),
    ]),
  );

  Widget _mosCard(dynamic units, String pct) {
    final p = double.tryParse(pct) ?? 0;
    final color = p >= 20 ? AC.ok : (p >= 10 ? AC.warn : AC.err);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.security, color: color, size: 18),
          const SizedBox(width: 6),
          Text('هامش الأمان',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        _kv('الوحدات فوق نقطة التعادل', '$units'),
        _kv('نسبة هامش الأمان', '$pct%', vc: color, bold: true),
        const SizedBox(height: 4),
        Text(
          p >= 20 ? 'ممتاز — وضعك المالي آمن'
            : (p >= 10 ? 'مقبول — يمكن تحسينه' : 'خطر — قريب من نقطة التعادل'),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  Widget _warnCard(List warnings) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AC.warn.withValues(alpha: 0.08),
      border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: AC.warn, size: 14),
        const SizedBox(width: 6),
        Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ...warnings.map((w) => Text('• $w', style: TextStyle(color: AC.tp, fontSize: 11))),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _numField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AC.goldText, size: 18),
          filled: true,
          fillColor: AC.navy3,
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AC.goldText)),
        ),
      ),
    );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp,
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
