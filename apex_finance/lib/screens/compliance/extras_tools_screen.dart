/// APEX Platform — Extras Tools Suite
/// IFRS 2/40/41 + RETT + Pillar Two + VAT Group + Job Costing
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class ExtrasToolsScreen extends StatefulWidget {
  const ExtrasToolsScreen({super.key});
  @override
  State<ExtrasToolsScreen> createState() => _ExtrasToolsScreenState();
}

class _ExtrasToolsScreenState extends State<ExtrasToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 7, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: ApexAppBar(
      title: 'الأدوات المتقدمة',
      bottom: TabBar(
        controller: _tab,
        isScrollable: true,
        indicatorColor: AC.gold,
        labelColor: AC.gold,
        unselectedLabelColor: AC.ts,
        tabs: const [
          Tab(icon: Icon(Icons.stacked_bar_chart), text: 'أسهم (2)'),
          Tab(icon: Icon(Icons.apartment), text: 'عقار (40)'),
          Tab(icon: Icon(Icons.agriculture), text: 'زراعة (41)'),
          Tab(icon: Icon(Icons.home_work), text: 'RETT'),
          Tab(icon: Icon(Icons.public), text: 'P2'),
          Tab(icon: Icon(Icons.group_work), text: 'VAT-G'),
          Tab(icon: Icon(Icons.engineering), text: 'مشاريع'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: const [
      _SbpTab(), _InvPropertyTab(), _AgricultureTab(),
      _RettTab(), _PillarTwoTab(), _VatGroupTab(), _JobTab(),
    ]),
  );
}

// ── Shared helpers
Widget _nf(TextEditingController c, String l, IconData i) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: TextStyle(color: AC.tp, fontSize: 13, fontFamily: 'monospace'),
    decoration: InputDecoration(
      labelText: l, prefixIcon: Icon(i, color: AC.goldText, size: 18),
      filled: true, fillColor: AC.navy3, isDense: true,
      labelStyle: TextStyle(color: AC.ts, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none))));

Widget _sf(TextEditingController c, String l, IconData i) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(controller: c,
    style: TextStyle(color: AC.tp, fontSize: 13),
    decoration: InputDecoration(
      labelText: l, prefixIcon: Icon(i, color: AC.goldText, size: 18),
      filled: true, fillColor: AC.navy3, isDense: true,
      labelStyle: TextStyle(color: AC.ts, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none))));

Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
    Text(v, style: TextStyle(color: vc ?? AC.tp,
      fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      fontFamily: 'monospace')),
  ]));

Widget _warnings(List ws) {
  if (ws.isEmpty) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
      border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: ws.map((w) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('• $w', style: TextStyle(color: AC.warn, fontSize: 11)),
      )).toList()));
}

Widget _hero(String title, String value, String currency, Color color) =>
  Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color.withValues(alpha: 0.14), AC.navy3],
        begin: Alignment.topRight, end: Alignment.bottomLeft),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Text(title, style: TextStyle(color: AC.ts, fontSize: 11)),
      Text('$value $currency', style: TextStyle(color: color, fontSize: 22,
        fontWeight: FontWeight.w900, fontFamily: 'monospace')),
    ]));

Widget _button(bool loading, VoidCallback onPressed, IconData icon, String label) =>
  SizedBox(height: 48, child: ElevatedButton.icon(
    onPressed: loading ? null : onPressed,
    icon: loading ? const SizedBox(height: 18, width: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      : Icon(icon),
    label: Text(label)));

// ═══════════════════════════════════════════════════════════════
// Tab 1 — Share-Based Payments (IFRS 2)
// ═══════════════════════════════════════════════════════════════

class _SbpTab extends StatefulWidget {
  const _SbpTab();
  @override
  State<_SbpTab> createState() => _SbpTabState();
}

class _SbpTabState extends State<_SbpTab> {
  final _plan = TextEditingController(text: 'خطة المدراء 2026');
  final _fv = TextEditingController(text: '100');
  final _units = TextEditingController(text: '10000');
  final _years = TextEditingController(text: '4');
  final _elapsed = TextEditingController(text: '2');
  final _forfeit = TextEditingController(text: '5');
  String _instrument = 'stock_option';
  String _pattern = 'cliff';
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() { _plan.dispose(); _fv.dispose(); _units.dispose();
    _years.dispose(); _elapsed.dispose(); _forfeit.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.sbpCompute({
        'plan_name': _plan.text.trim(),
        'instrument_type': _instrument,
        'grant_date': '2026-01-01',
        'grant_date_fair_value_per_unit': _fv.text.trim(),
        'units_granted': int.tryParse(_units.text.trim()) ?? 1,
        'vesting_period_years': int.tryParse(_years.text.trim()) ?? 4,
        'vesting_pattern': _pattern,
        'forfeiture_rate_pct': _forfeit.text.trim(),
        'years_elapsed': int.tryParse(_elapsed.text.trim()) ?? 0,
      });
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sf(_plan, 'اسم الخطة', Icons.stacked_bar_chart),
      DropdownButtonFormField<String>(
        value: _instrument,
        dropdownColor: AC.navy2, style: TextStyle(color: AC.tp),
        decoration: InputDecoration(labelText: 'الأداة',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none)),
        items: const [
          DropdownMenuItem(value: 'stock_option', child: Text('Stock Options')),
          DropdownMenuItem(value: 'rsu', child: Text('RSU')),
          DropdownMenuItem(value: 'phantom_stock', child: Text('Phantom Stock')),
          DropdownMenuItem(value: 'sar', child: Text('SAR')),
        ],
        onChanged: (v) => setState(() => _instrument = v!)),
      const SizedBox(height: 10),
      _nf(_fv, 'FV لكل وحدة عند المنح', Icons.price_change),
      _nf(_units, 'عدد الوحدات الممنوحة', Icons.numbers),
      _nf(_years, 'فترة الاستحقاق (سنة)', Icons.schedule),
      _nf(_elapsed, 'السنوات المنقضية', Icons.timelapse),
      _nf(_forfeit, 'معدل السقوط %', Icons.trending_down),
      DropdownButtonFormField<String>(
        value: _pattern,
        dropdownColor: AC.navy2, style: TextStyle(color: AC.tp),
        decoration: InputDecoration(labelText: 'نمط الاستحقاق',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none)),
        items: const [
          DropdownMenuItem(value: 'cliff', child: Text('Cliff')),
          DropdownMenuItem(value: 'graded', child: Text('Graded')),
        ],
        onChanged: (v) => setState(() => _pattern = v!)),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'احسب مصروف الخطة'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) => [
    const SizedBox(height: 14),
    _hero('مصروف تراكمي حتى الآن', '${d['expense_to_date']}', d['currency'], AC.purple),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('FV الإجمالي عند المنح', '${d['total_grant_date_fair_value']}'),
        _kv('الوحدات المتوقع استحقاقها', '${d['expected_vesting_units']}'),
        _kv('السقوط المتوقع', '${d['expected_forfeitures']}'),
        _kv('مصروف الفترة الحالية', '${d['expense_current_period']}', vc: AC.info),
        _kv('المصروف المتبقي', '${d['remaining_expense']}', vc: AC.warn),
        _kv('التقدم', '${d['vesting_progress_pct']}%', bold: true),
      ])),
    _warnings((d['warnings'] ?? []) as List),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Tab 2 — Investment Property (IAS 40)
// ═══════════════════════════════════════════════════════════════

class _InvPropertyTab extends StatefulWidget {
  const _InvPropertyTab();
  @override
  State<_InvPropertyTab> createState() => _InvPropertyTabState();
}

class _InvPropertyTabState extends State<_InvPropertyTab> {
  final _name = TextEditingController(text: 'مجمع مكاتب');
  final _cost = TextEditingController(text: '10000000');
  final _fv = TextEditingController(text: '12000000');
  final _rent = TextEditingController(text: '600000');
  final _opcosts = TextEditingController(text: '100000');
  final _elapsed = TextEditingController(text: '3');
  String _model = 'fair_value';
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() { _name.dispose(); _cost.dispose(); _fv.dispose();
    _rent.dispose(); _opcosts.dispose(); _elapsed.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'property_name': _name.text.trim(),
        'acquisition_cost': _cost.text.trim(),
        'useful_life_years': 40,
        'model': _model,
        'rental_income_annual': _rent.text.trim(),
        'operating_costs_annual': _opcosts.text.trim(),
        'years_elapsed': int.tryParse(_elapsed.text.trim()) ?? 0,
      };
      if (_model == 'fair_value') body['current_fair_value'] = _fv.text.trim();
      final r = await ApiService.investmentPropertyCompute(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sf(_name, 'اسم العقار', Icons.apartment),
      _nf(_cost, 'تكلفة الاقتناء', Icons.attach_money),
      _nf(_fv, 'القيمة العادلة الحالية', Icons.trending_up),
      DropdownButtonFormField<String>(
        value: _model,
        dropdownColor: AC.navy2, style: TextStyle(color: AC.tp),
        decoration: InputDecoration(labelText: 'النموذج',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none)),
        items: const [
          DropdownMenuItem(value: 'cost', child: Text('التكلفة (Cost)')),
          DropdownMenuItem(value: 'fair_value', child: Text('القيمة العادلة (FV)')),
        ],
        onChanged: (v) => setState(() => _model = v!)),
      const SizedBox(height: 10),
      _nf(_rent, 'دخل إيجاري سنوي', Icons.payments),
      _nf(_opcosts, 'تكاليف تشغيل سنوية', Icons.build),
      _nf(_elapsed, 'السنوات المنقضية', Icons.timelapse),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'احسب'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) => [
    const SizedBox(height: 14),
    _hero('القيمة الدفترية الحالية', '${d['current_carrying_amount']}',
      d['currency'], AC.info),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('النموذج', '${d['model']}'),
        _kv('التكلفة', '${d['acquisition_cost']}'),
        _kv('مجمع الإهلاك', '${d['accumulated_depreciation']}'),
        _kv('تسوية القيمة العادلة', '${d['fair_value_adjustment']}',
          vc: AC.gold),
        _kv('دخل إيجاري صافي', '${d['net_rental_income']}'),
        _kv('عائد إجمالي', '${d['gross_rental_yield_pct']}%'),
        _kv('عائد صافي', '${d['net_rental_yield_pct']}%', vc: AC.ok, bold: true),
      ])),
    _warnings((d['warnings'] ?? []) as List),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Tab 3 — Agriculture (IAS 41)
// ═══════════════════════════════════════════════════════════════

class _AgricultureTab extends StatefulWidget {
  const _AgricultureTab();
  @override
  State<_AgricultureTab> createState() => _AgricultureTabState();
}

class _AgricultureTabState extends State<_AgricultureTab> {
  final _name = TextEditingController(text: 'قطعان الأبقار');
  final _units = TextEditingController(text: '100');
  final _fvB = TextEditingController(text: '5000');
  final _fvE = TextEditingController(text: '6000');
  final _cts = TextEditingController(text: '3');
  final _new = TextEditingController(text: '10');
  final _harv = TextEditingController(text: '5');
  String _type = 'livestock';
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() { _name.dispose(); _units.dispose(); _fvB.dispose();
    _fvE.dispose(); _cts.dispose(); _new.dispose(); _harv.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.agricultureCompute({
        'asset_name': _name.text.trim(),
        'biological_type': _type,
        'units': _units.text.trim(),
        'fair_value_per_unit_beginning': _fvB.text.trim(),
        'fair_value_per_unit_end': _fvE.text.trim(),
        'costs_to_sell_pct': _cts.text.trim(),
        'new_units_born_or_planted': _new.text.trim(),
        'units_harvested_or_sold': _harv.text.trim(),
      });
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sf(_name, 'الأصل', Icons.agriculture),
      DropdownButtonFormField<String>(
        value: _type,
        dropdownColor: AC.navy2, style: TextStyle(color: AC.tp),
        decoration: InputDecoration(labelText: 'النوع',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none)),
        items: const [
          DropdownMenuItem(value: 'livestock', child: Text('ماشية')),
          DropdownMenuItem(value: 'crops', child: Text('محاصيل')),
          DropdownMenuItem(value: 'trees', child: Text('أشجار')),
          DropdownMenuItem(value: 'fish', child: Text('أسماك')),
          DropdownMenuItem(value: 'other', child: Text('أخرى')),
        ],
        onChanged: (v) => setState(() => _type = v!)),
      const SizedBox(height: 10),
      _nf(_units, 'عدد الوحدات', Icons.numbers),
      _nf(_fvB, 'FV/وحدة بداية المدة', Icons.start),
      _nf(_fvE, 'FV/وحدة نهاية المدة', Icons.stop_circle),
      _nf(_cts, 'تكاليف البيع %', Icons.percent),
      _nf(_new, 'مواليد/مزروع جديد', Icons.add_circle),
      _nf(_harv, 'محصود/مباع', Icons.remove_circle),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'احسب'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) => [
    const SizedBox(height: 14),
    _hero('القيمة العادلة النهائية', '${d['fair_value_end']}', d['currency'], AC.ok),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('FV بداية المدة', '${d['fair_value_beginning']}'),
        _kv('تغير من السعر', '${d['change_from_price']}'),
        _kv('تغير مادي (نمو/مواليد)', '${d['change_from_physical']}'),
        _kv('إجمالي الربح/الخسارة', '${d['total_gain_loss']}',
          vc: AC.gold, bold: true),
      ])),
    _warnings((d['warnings'] ?? []) as List),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Tab 4 — RETT
// ═══════════════════════════════════════════════════════════════

class _RettTab extends StatefulWidget {
  const _RettTab();
  @override
  State<_RettTab> createState() => _RettTabState();
}

class _RettTabState extends State<_RettTab> {
  final _value = TextEditingController(text: '5000000');
  String _propType = 'residential';
  bool _firstHome = false;
  bool _family = false;
  bool _saudi = true;
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() { _value.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.rettCompute({
        'property_type': _propType,
        'transaction_mode': 'sale',
        'sale_value': _value.text.trim(),
        'sale_date': '2026-01-01',
        'is_first_home': _firstHome,
        'is_family_transfer': _family,
        'buyer_is_saudi_citizen': _saudi,
      });
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _nf(_value, 'قيمة البيع', Icons.attach_money),
      DropdownButtonFormField<String>(
        value: _propType,
        dropdownColor: AC.navy2, style: TextStyle(color: AC.tp),
        decoration: InputDecoration(labelText: 'نوع العقار',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none)),
        items: const [
          DropdownMenuItem(value: 'residential', child: Text('سكني')),
          DropdownMenuItem(value: 'commercial', child: Text('تجاري')),
          DropdownMenuItem(value: 'industrial', child: Text('صناعي')),
          DropdownMenuItem(value: 'agricultural', child: Text('زراعي')),
          DropdownMenuItem(value: 'land', child: Text('أرض')),
        ],
        onChanged: (v) => setState(() => _propType = v!)),
      const SizedBox(height: 12),
      CheckboxListTile(
        title: Text('مسكن العمر الأول', style: TextStyle(color: AC.tp, fontSize: 13)),
        value: _firstHome,
        activeColor: AC.gold,
        onChanged: (v) => setState(() => _firstHome = v!)),
      CheckboxListTile(
        title: Text('نقل بين أقارب', style: TextStyle(color: AC.tp, fontSize: 13)),
        value: _family,
        activeColor: AC.gold,
        onChanged: (v) => setState(() => _family = v!)),
      CheckboxListTile(
        title: Text('المشتري مواطن سعودي', style: TextStyle(color: AC.tp, fontSize: 13)),
        value: _saudi,
        activeColor: AC.gold,
        onChanged: (v) => setState(() => _saudi = v!)),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'احسب RETT'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) => [
    const SizedBox(height: 14),
    _hero('ضريبة RETT', '${d['rett_amount']}', d['currency'], AC.err),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('قيمة البيع', '${d['sale_value']}'),
        _kv('المعدل المُطبَّق', '${d['rett_rate_pct']}%'),
        _kv('الإعفاء', '${d['exemption_applied']}'),
        _kv('القيمة الخاضعة', '${d['taxable_value']}'),
        if (d['vat_applicable'] == true)
          _kv('VAT (15%)', '${d['vat_amount']}', vc: AC.warn),
      ])),
    _warnings((d['warnings'] ?? []) as List),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Tab 5 — Pillar Two
// ═══════════════════════════════════════════════════════════════

class _PillarTwoTab extends StatefulWidget {
  const _PillarTwoTab();
  @override
  State<_PillarTwoTab> createState() => _PillarTwoTabState();
}

class _PillarTwoTabState extends State<_PillarTwoTab> {
  final _group = TextEditingController(text: 'مجموعة متعددة الجنسيات');
  final _year = TextEditingController(text: '2026');
  final _rev = TextEditingController(text: '5000000000');
  final _ksaIncome = TextEditingController(text: '50000000');
  final _ksaTaxes = TextEditingController(text: '10000000');
  final _uaeIncome = TextEditingController(text: '20000000');
  final _uaeTaxes = TextEditingController(text: '0');
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() { _group.dispose(); _year.dispose(); _rev.dispose();
    _ksaIncome.dispose(); _ksaTaxes.dispose();
    _uaeIncome.dispose(); _uaeTaxes.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.pillarTwoCompute({
        'group_name': _group.text.trim(),
        'fiscal_year': _year.text.trim(),
        'group_consolidated_revenue': _rev.text.trim(),
        'jurisdictions': [
          {'jurisdiction': 'KSA', 'gloBE_income': _ksaIncome.text.trim(),
           'covered_taxes': _ksaTaxes.text.trim(), 'payroll': '0', 'tangible_assets': '0'},
          {'jurisdiction': 'UAE', 'gloBE_income': _uaeIncome.text.trim(),
           'covered_taxes': _uaeTaxes.text.trim(), 'payroll': '0', 'tangible_assets': '0'},
        ],
      });
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sf(_group, 'المجموعة', Icons.public),
      _sf(_year, 'السنة', Icons.date_range),
      _nf(_rev, 'إيرادات المجموعة (للحد)', Icons.trending_up),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          Text('السعودية', style: TextStyle(color: AC.gold)),
          _nf(_ksaIncome, 'دخل GloBE', Icons.business_center),
          _nf(_ksaTaxes, 'ضرائب مدفوعة', Icons.money),
        ])),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          Text('الإمارات', style: TextStyle(color: AC.gold)),
          _nf(_uaeIncome, 'دخل GloBE', Icons.business_center),
          _nf(_uaeTaxes, 'ضرائب مدفوعة', Icons.money),
        ])),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'احسب الحد الأدنى'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) {
    final jurs = (d['jurisdictions'] ?? []) as List;
    return [
      const SizedBox(height: 14),
      _hero('ضريبة تكميلية إجمالية', '${d['total_top_up_tax']}', 'SAR', AC.err),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('حد Pillar Two (3.2B)', d['threshold_met'] == true ? 'تم تجاوزه ✓' : 'لم يُتجاوز'),
          const Divider(),
          ...jurs.map<Widget>((j) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${j['jurisdiction']} — ETR ${j['effective_tax_rate_pct']}%',
                style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
              Text(' → ${j['status']}', style: TextStyle(color:
                j['status'] == 'above_minimum' ? AC.ok : AC.err, fontSize: 11)),
              Text(' → ضريبة تكميلية: ${j['top_up_tax']}',
                style: TextStyle(color: AC.tp, fontSize: 11)),
            ]),
          )),
        ])),
      _warnings((d['warnings'] ?? []) as List),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 6 — VAT Group
// ═══════════════════════════════════════════════════════════════

class _VatGroupTab extends StatefulWidget {
  const _VatGroupTab();
  @override
  State<_VatGroupTab> createState() => _VatGroupTabState();
}

class _VatGroupTabState extends State<_VatGroupTab> {
  final _group = TextEditingController(text: 'مجموعة VAT');
  final _period = TextEditingController(text: 'Q1 2026');
  final _memA_sup = TextEditingController(text: '5000000');
  final _memA_coll = TextEditingController(text: '750000');
  final _memA_paid = TextEditingController(text: '300000');
  final _memB_sup = TextEditingController(text: '2000000');
  final _memB_coll = TextEditingController(text: '300000');
  final _memB_paid = TextEditingController(text: '150000');
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() {
    _group.dispose(); _period.dispose();
    _memA_sup.dispose(); _memA_coll.dispose(); _memA_paid.dispose();
    _memB_sup.dispose(); _memB_coll.dispose(); _memB_paid.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.vatGroupCompute({
        'group_name': _group.text.trim(),
        'fiscal_period': _period.text.trim(),
        'representative_member': 'عضو أ',
        'members': [
          {'entity_name': 'عضو أ', 'vat_registration': '',
           'annual_taxable_supplies': _memA_sup.text.trim(),
           'vat_collected': _memA_coll.text.trim(),
           'vat_paid': _memA_paid.text.trim()},
          {'entity_name': 'عضو ب', 'vat_registration': '',
           'annual_taxable_supplies': _memB_sup.text.trim(),
           'vat_collected': _memB_coll.text.trim(),
           'vat_paid': _memB_paid.text.trim()},
        ],
      });
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sf(_group, 'المجموعة', Icons.group_work),
      _sf(_period, 'الفترة', Icons.date_range),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          Text('عضو أ', style: TextStyle(color: AC.gold)),
          _nf(_memA_sup, 'توريدات خاضعة', Icons.sell),
          _nf(_memA_coll, 'VAT مُحصَّل', Icons.add_box),
          _nf(_memA_paid, 'VAT مدفوع', Icons.remove_circle),
        ])),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          Text('عضو ب', style: TextStyle(color: AC.gold)),
          _nf(_memB_sup, 'توريدات خاضعة', Icons.sell),
          _nf(_memB_coll, 'VAT مُحصَّل', Icons.add_box),
          _nf(_memB_paid, 'VAT مدفوع', Icons.remove_circle),
        ])),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'احسب VAT المُجمَّع'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) => [
    const SizedBox(height: 14),
    _hero('صافي VAT المستحق', '${d['net_vat_payable']}', 'SAR', AC.warn),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('إجمالي التوريدات', '${d['total_taxable_supplies']}'),
        _kv('إجمالي VAT مُحصَّل', '${d['total_vat_collected']}', vc: AC.ok),
        _kv('إجمالي VAT مدفوع', '${d['total_vat_paid']}', vc: AC.info),
        _kv('معاملات داخلية مُلغاة', '${d['intra_group_eliminated']}'),
        _kv('عدد الأعضاء', '${d['members_count']}'),
        _kv('فوق حد التسجيل', d['is_above_threshold'] == true ? 'نعم' : 'لا',
          vc: d['is_above_threshold'] == true ? AC.err : AC.ok),
      ])),
    _warnings((d['warnings'] ?? []) as List),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Tab 7 — Job Costing
// ═══════════════════════════════════════════════════════════════

class _JobTab extends StatefulWidget {
  const _JobTab();
  @override
  State<_JobTab> createState() => _JobTabState();
}

class _JobTabState extends State<_JobTab> {
  final _name = TextEditingController(text: 'مشروع مبنى سكني');
  final _code = TextEditingController(text: 'PRJ-2026-001');
  final _value = TextEditingController(text: '5000000');
  final _eac = TextEditingController(text: '500000');
  final _labB = TextEditingController(text: '2000000');
  final _labA = TextEditingController(text: '1900000');
  final _matB = TextEditingController(text: '1500000');
  final _matA = TextEditingController(text: '1550000');
  final _ohB = TextEditingController(text: '500000');
  final _ohA = TextEditingController(text: '480000');
  bool _loading = false; String? _error; Map<String, dynamic>? _result;

  @override
  void dispose() {
    _name.dispose(); _code.dispose(); _value.dispose(); _eac.dispose();
    _labB.dispose(); _labA.dispose(); _matB.dispose(); _matA.dispose();
    _ohB.dispose(); _ohA.dispose(); super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.jobAnalyse({
        'project_name': _name.text.trim(),
        'project_code': _code.text.trim(),
        'contract_value': _value.text.trim(),
        'contract_start_date': '2026-01-01',
        'estimated_end_date': '2026-12-31',
        'additional_eac': _eac.text.trim(),
        'costs': [
          {'category': 'labour', 'description': 'عمالة',
           'budgeted': _labB.text.trim(), 'actual': _labA.text.trim()},
          {'category': 'material', 'description': 'مواد',
           'budgeted': _matB.text.trim(), 'actual': _matA.text.trim()},
          {'category': 'overhead', 'description': 'صناعية غير مباشرة',
           'budgeted': _ohB.text.trim(), 'actual': _ohA.text.trim()},
        ],
      });
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else setState(() => _error = r.error);
    } catch (e) { setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sf(_name, 'اسم المشروع', Icons.engineering),
      _sf(_code, 'كود المشروع', Icons.qr_code),
      _nf(_value, 'قيمة العقد', Icons.attach_money),
      _nf(_eac, 'تكلفة متبقية متوقعة (EAC)', Icons.schedule),
      Row(children: [Expanded(child: _nf(_labB, 'عمالة (ميزانية)', Icons.badge)),
        const SizedBox(width: 8),
        Expanded(child: _nf(_labA, 'عمالة (فعلي)', Icons.payments))]),
      Row(children: [Expanded(child: _nf(_matB, 'مواد (ميزانية)', Icons.inventory_2)),
        const SizedBox(width: 8),
        Expanded(child: _nf(_matA, 'مواد (فعلي)', Icons.shopping_cart))]),
      Row(children: [Expanded(child: _nf(_ohB, 'صناعية (ميزانية)', Icons.factory)),
        const SizedBox(width: 8),
        Expanded(child: _nf(_ohA, 'صناعية (فعلي)', Icons.settings_input_component))]),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      _button(_loading, _run, Icons.calculate, 'حلّل المشروع'),
      if (_result != null) ..._render(_result!),
    ]),
  );

  List<Widget> _render(Map d) {
    final status = d['status'] as String;
    final color = status == 'over_budget' ? AC.err
      : (status == 'under_budget' ? AC.ok : AC.info);
    return [
      const SizedBox(height: 14),
      _hero('ربح/خسارة متوقعة عند الإنجاز',
        '${d['estimated_profit_at_completion']}', d['currency'],
        _parseDec(d['estimated_profit_at_completion']) >= 0 ? AC.ok : AC.err),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          _kv('حالة المشروع', status, vc: color, bold: true),
          _kv('قيمة العقد', '${d['contract_value']}'),
          _kv('إجمالي ميزانية', '${d['total_budgeted']}'),
          _kv('إجمالي فعلي', '${d['total_actual']}'),
          _kv('انحراف', '${d['total_variance']}', vc: color),
          _kv('% إنجاز (على أساس التكلفة)',
            '${d['percent_complete_cost_basis']}%', bold: true),
          _kv('تكلفة متوقعة عند الإنجاز', '${d['estimated_at_completion_cost']}'),
        ])),
      _warnings((d['warnings'] ?? []) as List),
    ];
  }

  double _parseDec(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
}
