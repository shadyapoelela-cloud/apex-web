/// APEX Platform — Full Cash Flow Statement (IAS 7)
/// ═══════════════════════════════════════════════════════════════
/// Takes two comparative trial balances (opening + closing) plus
/// net income, and produces CFO / CFI / CFF with reconciliation.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class CashflowStatementScreen extends StatefulWidget {
  const CashflowStatementScreen({super.key});
  @override
  State<CashflowStatementScreen> createState() => _CashflowStatementScreenState();
}

class _CFSRow {
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController opening;
  final TextEditingController closing;
  final TextEditingController explicitFlow;
  String cls;
  _CFSRow({String c = '', String n = '', String o = '0', String cl = '0',
    String ef = '', this.cls = 'cash'})
    : code = TextEditingController(text: c),
      name = TextEditingController(text: n),
      opening = TextEditingController(text: o),
      closing = TextEditingController(text: cl),
      explicitFlow = TextEditingController(text: ef);
  void dispose() {
    code.dispose(); name.dispose();
    opening.dispose(); closing.dispose(); explicitFlow.dispose();
  }
}

class _CashflowStatementScreenState extends State<CashflowStatementScreen> {
  final _entity = TextEditingController(text: 'شركة تجريبية');
  final _period = TextEditingController(text: 'FY 2026');
  final _ni = TextEditingController(text: '1000');
  final List<_CFSRow> _rows = [];
  final _classes = const [
    'cash', 'op_addback', 'op_wc_asset', 'op_wc_liability',
    'investing', 'financing',
  ];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    // A balanced sample
    _rows.addAll([
      _CFSRow(c: '1100', n: 'النقد', o: '100', cl: '850', cls: 'cash'),
      _CFSRow(c: '1510', n: 'مجمع الإهلاك', o: '1000', cl: '1200', cls: 'op_addback'),
      _CFSRow(c: '1200', n: 'ذمم مدينة', o: '400', cl: '700', cls: 'op_wc_asset'),
      _CFSRow(c: '2100', n: 'ذمم دائنة', o: '200', cl: '350', cls: 'op_wc_liability'),
      _CFSRow(c: '1500', n: 'أصول ثابتة', o: '5000', cl: '5500', cls: 'investing'),
      _CFSRow(c: '2500', n: 'قروض طويلة', o: '2000', cl: '2400', cls: 'financing'),
      _CFSRow(c: '3300', n: 'توزيعات الأرباح', o: '0', cl: '0',
        ef: '-200', cls: 'financing'),
    ]);
  }

  @override
  void dispose() {
    _entity.dispose(); _period.dispose(); _ni.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _build() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'entity_name': _entity.text.trim().isEmpty ? 'Co' : _entity.text.trim(),
        'period_label': _period.text.trim().isEmpty ? 'P' : _period.text.trim(),
        'currency': 'SAR',
        'net_income': _ni.text.trim().isEmpty ? '0' : _ni.text.trim(),
        'lines': _rows.map((r) {
          final m = <String, dynamic>{
            'account_code': r.code.text.trim().isEmpty ? '0' : r.code.text.trim(),
            'account_name': r.name.text.trim().isEmpty ? '-' : r.name.text.trim(),
            'cfs_class': r.cls,
            'opening_balance': r.opening.text.trim().isEmpty ? '0' : r.opening.text.trim(),
            'closing_balance': r.closing.text.trim().isEmpty ? '0' : r.closing.text.trim(),
          };
          final ef = r.explicitFlow.text.trim();
          if (ef.isNotEmpty) m['explicit_flow'] = ef;
          return m;
        }).toList(),
      };
      final r = await ApiService.cfsBuild(body);
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
    appBar: ApexAppBar(title: 'قائمة التدفقات النقدية (IAS 7)'),
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
    _section('المنشأة والفترة'),
    Row(children: [
      Expanded(child: _strField(_entity, 'اسم المنشأة', Icons.business)),
      const SizedBox(width: 8),
      Expanded(child: _strField(_period, 'الفترة', Icons.date_range)),
    ]),
    _numField(_ni, 'صافي الدخل (من قائمة الدخل)', Icons.trending_up),
    _section('ميزان المراجعة المقارن (افتتاحي / ختامي)'),
    ..._rows.asMap().entries.map((e) => _cfsRow(e.key, e.value)),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      icon: Icon(Icons.add, color: AC.gold),
      label: Text('إضافة بند', style: TextStyle(color: AC.gold)),
      onPressed: () => setState(() => _rows.add(_CFSRow())),
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
      onPressed: _loading ? null : _build,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.water_drop),
      label: const Text('ابنِ قائمة التدفقات'))),
  ]);

  Widget _cfsRow(int i, _CFSRow r) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Row(children: [
        SizedBox(width: 60, child: TextField(
          controller: r.code,
          style: TextStyle(color: AC.gold, fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'كود', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Expanded(child: TextField(
          controller: r.name,
          style: TextStyle(color: AC.tp, fontSize: 11),
          decoration: InputDecoration(hintText: 'الاسم', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        SizedBox(width: 130, child: DropdownButton<String>(
          value: r.cls,
          isDense: true,
          isExpanded: true,
          dropdownColor: AC.navy2,
          underline: const SizedBox(),
          style: TextStyle(color: AC.info, fontSize: 10, fontWeight: FontWeight.w700),
          items: _classes.map((c) =>
            DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => r.cls = v!),
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
          controller: r.opening,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'افتتاحي', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Container(width: 1, height: 14, color: AC.bdr),
        Expanded(child: TextField(
          controller: r.closing,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'ختامي', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Container(width: 1, height: 14, color: AC.bdr),
        Expanded(child: TextField(
          controller: r.explicitFlow,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: TextStyle(color: AC.purple, fontSize: 11, fontFamily: 'monospace'),
          textAlign: TextAlign.right,
          decoration: InputDecoration(hintText: 'تدفق فعلي', isDense: true,
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
        Icon(Icons.water_drop, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('اضغط "ابنِ قائمة التدفقات" لعرض النتيجة',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final reconciles = d['reconciles'] == true;
    final color = reconciles ? AC.ok : AC.err;
    final net = _parseDec(d['net_change_in_cash']);
    final netColor = net >= 0 ? AC.ok : AC.err;
    final ops = (d['operating_lines'] ?? []) as List;
    final inv = (d['investing_lines'] ?? []) as List;
    final fin = (d['financing_lines'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(reconciles ? Icons.verified : Icons.warning_amber_rounded,
            color: color, size: 30),
          const SizedBox(height: 6),
          Text(reconciles ? 'التدفق النقدي متطابق ✓' : 'عدم تطابق',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('صافي التغيّر في النقد',
            style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['net_change_in_cash']} ${d['currency']}',
            style: TextStyle(color: netColor, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 14),
      _sectionSummary('التشغيلية', '${d['cash_from_operating']}', ops, AC.ok),
      const SizedBox(height: 10),
      _sectionSummary('الاستثمارية', '${d['cash_from_investing']}', inv, AC.info),
      const SizedBox(height: 10),
      _sectionSummary('التمويلية', '${d['cash_from_financing']}', fin, AC.purple),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('النقد الافتتاحي', '${d['opening_cash']} ${d['currency']}'),
          _kv('صافي التدفقات', '${d['net_change_in_cash']} ${d['currency']}', vc: netColor),
          Divider(color: AC.bdr),
          _kv('النقد الختامي', '${d['closing_cash']} ${d['currency']}',
            vc: AC.gold, bold: true),
          if (!reconciles) _kv('الفرق', '${d['cash_check']}', vc: AC.err),
        ]),
      ),
    ]);
  }

  Widget _sectionSummary(String title, String total, List lines, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('الأنشطة $title',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800))),
          Text('$total', style: TextStyle(color: color, fontSize: 15,
            fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 8),
        ...lines.map((ln) {
          final amt = _parseDec(ln['amount']);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text(ln['account_name'] ?? '',
                style: TextStyle(color: AC.tp, fontSize: 11))),
              Text('${ln['amount']}',
                style: TextStyle(color: amt >= 0 ? AC.ok : AC.err,
                  fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
            ]),
          );
        }),
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
