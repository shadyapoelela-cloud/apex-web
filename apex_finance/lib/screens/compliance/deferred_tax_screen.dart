/// APEX Platform — Deferred Tax (IAS 12)
/// ═══════════════════════════════════════════════════════════════
/// DTA / DTL calculation from temporary differences.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class _TDRow {
  final TextEditingController desc;
  final TextEditingController ca;
  final TextEditingController tb;
  String category;
  _TDRow({String d = '', String c = '0', String t = '0',
    this.category = 'asset_td'})
    : desc = TextEditingController(text: d),
      ca = TextEditingController(text: c),
      tb = TextEditingController(text: t);
  void dispose() { desc.dispose(); ca.dispose(); tb.dispose(); }
}

class DeferredTaxScreen extends StatefulWidget {
  const DeferredTaxScreen({super.key});
  @override
  State<DeferredTaxScreen> createState() => _DeferredTaxScreenState();
}

class _DeferredTaxScreenState extends State<DeferredTaxScreen> {
  final _entity = TextEditingController(text: 'شركة تجريبية');
  final _period = TextEditingController(text: 'FY 2026');
  final _rate = TextEditingController(text: '20');
  final _futureProfit = TextEditingController(text: '500000');
  final _openDta = TextEditingController(text: '0');
  final _openDtl = TextEditingController(text: '0');
  final List<_TDRow> _rows = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _categories = const ['asset_td', 'liability_td', 'loss_carry_forward'];
  final _categoryAr = const {
    'asset_td': 'فرق أصل',
    'liability_td': 'فرق خصم',
    'loss_carry_forward': 'خسارة مرحلة',
  };

  @override
  void initState() {
    super.initState();
    _rows.addAll([
      _TDRow(d: 'مجمع إهلاك آلات (فرق ضريبي)', c: '1000', t: '800', category: 'asset_td'),
      _TDRow(d: 'مخصص ضمان منتجات', c: '500', t: '0', category: 'liability_td'),
      _TDRow(d: 'خسائر 2024 مرحّلة', c: '300', t: '0', category: 'loss_carry_forward'),
    ]);
  }

  @override
  void dispose() {
    _entity.dispose(); _period.dispose(); _rate.dispose();
    _futureProfit.dispose(); _openDta.dispose(); _openDtl.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{
        'entity_name': _entity.text.trim().isEmpty ? 'Co' : _entity.text.trim(),
        'period_label': _period.text.trim().isEmpty ? 'P' : _period.text.trim(),
        'tax_rate_pct': _rate.text.trim().isEmpty ? '20' : _rate.text.trim(),
        'currency': 'SAR',
        'opening_dta': _openDta.text.trim().isEmpty ? '0' : _openDta.text.trim(),
        'opening_dtl': _openDtl.text.trim().isEmpty ? '0' : _openDtl.text.trim(),
        'items': _rows.map((r) => {
          'description': r.desc.text.trim().isEmpty ? '-' : r.desc.text.trim(),
          'category': r.category,
          'carrying_amount': r.ca.text.trim().isEmpty ? '0' : r.ca.text.trim(),
          'tax_base': r.tb.text.trim().isEmpty ? '0' : r.tb.text.trim(),
        }).toList(),
      };
      final fp = _futureProfit.text.trim();
      if (fp.isNotEmpty) body['expected_future_profit'] = fp;
      final r = await ApiService.deferredTaxCompute(body);
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
    appBar: ApexAppBar(title: 'الضرائب المؤجّلة (IAS 12)'),
    body: LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 1000;
      if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _form())),
        Container(width: 1, color: AC.bdr),
        Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _results())),
      ]);
    }),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('المنشأة والمعدل'),
    Row(children: [
      Expanded(child: _strField(_entity, 'الاسم', Icons.business)),
      const SizedBox(width: 8),
      Expanded(child: _strField(_period, 'الفترة', Icons.date_range)),
    ]),
    Row(children: [
      Expanded(child: _numField(_rate, 'معدّل الضريبة %', Icons.percent)),
      const SizedBox(width: 8),
      Expanded(child: _numField(_futureProfit, 'أرباح مستقبلية متوقعة', Icons.trending_up)),
    ]),
    _section('أرصدة افتتاحية'),
    Row(children: [
      Expanded(child: _numField(_openDta, 'افتتاحي DTA', Icons.account_balance)),
      const SizedBox(width: 8),
      Expanded(child: _numField(_openDtl, 'افتتاحي DTL', Icons.account_balance_wallet)),
    ]),
    _section('الفروق المؤقتة'),
    ..._rows.asMap().entries.map((e) => _row(e.key, e.value)),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      icon: Icon(Icons.add, color: AC.gold),
      label: Text('إضافة فرق', style: TextStyle(color: AC.gold)),
      onPressed: () => setState(() => _rows.add(_TDRow())),
      style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
    ),
    const SizedBox(height: 14),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _compute,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.calculate),
      label: const Text('احسب الضرائب المؤجّلة'))),
  ]);

  Widget _row(int i, _TDRow r) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Row(children: [
        Expanded(child: TextField(
          controller: r.desc,
          style: TextStyle(color: AC.tp, fontSize: 12),
          decoration: InputDecoration(hintText: 'الوصف', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
        )),
        SizedBox(width: 130, child: DropdownButton<String>(
          value: r.category,
          isDense: true,
          isExpanded: true,
          dropdownColor: AC.navy2,
          underline: const SizedBox(),
          style: TextStyle(color: AC.info, fontSize: 11, fontWeight: FontWeight.w700),
          items: _categories.map((c) =>
            DropdownMenuItem(value: c,
              child: Text(_categoryAr[c] ?? c, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => r.category = v!),
        )),
        IconButton(
          icon: Icon(Icons.close, color: AC.err, size: 14),
          onPressed: _rows.length > 1 ? () {
            setState(() { r.dispose(); _rows.removeAt(i); });
          } : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
      Row(children: [
        Expanded(child: TextField(
          controller: r.ca,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'القيمة الدفترية', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Container(width: 1, height: 14, color: AC.bdr),
        Expanded(child: TextField(
          controller: r.tb,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'الوعاء الضريبي', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
      ]),
    ]),
  );

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل الفروق المؤقتة للحساب',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final net = _parseDec(d['net_deferred_tax']);
    final netColor = net >= 0 ? AC.ok : AC.err;
    final items = (d['items'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            netColor.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: netColor.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Text('صافي الضريبة المؤجّلة',
            style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['net_deferred_tax']} ${d['currency']}',
            style: TextStyle(color: netColor, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(net >= 0 ? 'أصل ضريبي (DTA)' : 'التزام ضريبي (DTL)',
            style: TextStyle(color: netColor, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('إجمالي DTA (إجمالي)', '${d['total_dta_gross']}'),
          _kv('DTA المعترف بها', '${d['total_dta_recognised']}', vc: AC.ok),
          _kv('DTA غير المعترف بها', '${d['total_dta_unrecognised']}', vc: AC.warn),
          Divider(color: AC.bdr),
          _kv('إجمالي DTL', '${d['total_dtl']}', vc: AC.err),
          Divider(color: AC.bdr),
          _kv('حركة DTA', '${d['movement_dta']}', vc: AC.info),
          _kv('حركة DTL', '${d['movement_dtl']}', vc: AC.info),
          _kv('مصروف الضريبة المؤجّلة (P&L)',
            '${d['deferred_tax_expense']}', vc: AC.purple, bold: true),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('تفصيل البنود',
            style: TextStyle(color: AC.tp, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 8),
          ...items.map((it) => _itemRow(it)),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
            border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('• $w', style: TextStyle(color: AC.warn, fontSize: 12, height: 1.5)),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _itemRow(Map it) {
    final type = it['td_type'] as String;
    final typeColor = type == 'taxable' ? AC.err
      : (type == 'deductible' ? AC.ok : AC.ts);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 4, child: Text('${it['description']}',
          style: TextStyle(color: AC.tp, fontSize: 11),
          overflow: TextOverflow.ellipsis)),
        SizedBox(width: 65, child: Text('${it['temporary_difference']}',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.tp, fontSize: 10, fontFamily: 'monospace'))),
        SizedBox(width: 55, child: Text('${it['dta_amount']}',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ok, fontSize: 10, fontFamily: 'monospace'))),
        SizedBox(width: 55, child: Text('${it['dtl_amount']}',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.err, fontSize: 10, fontFamily: 'monospace'))),
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
      ]),
    );
  }

  double _parseDec(dynamic v) {
    if (v == null) return 0.0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _strField(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      style: TextStyle(color: AC.tp),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
        filled: true, fillColor: AC.navy3,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _numField(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
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
      ),
    ),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
