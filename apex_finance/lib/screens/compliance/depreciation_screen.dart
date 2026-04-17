/// APEX Platform — Depreciation Calculator
/// ═══════════════════════════════════════════════════════════════
/// Computes a per-year depreciation schedule under three methods:
///   • Straight-Line (SL)
///   • Declining Balance (DDB)
///   • Sum-of-Years-Digits (SYD)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class DepreciationScreen extends StatefulWidget {
  const DepreciationScreen({super.key});
  @override
  State<DepreciationScreen> createState() => _DepreciationScreenState();
}

class _DepreciationScreenState extends State<DepreciationScreen> {
  final _assetNameC = TextEditingController();
  final _costC = TextEditingController();
  final _salvageC = TextEditingController(text: '0');
  final _lifeC = TextEditingController(text: '5');
  String _method = 'straight_line';
  int _firstYearMonths = 12;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  static const Map<String, Map<String, String>> _methods = {
    'straight_line': {
      'ar': 'الطريقة الثابتة (SL)',
      'desc': '(التكلفة − الخردة) ÷ العمر',
    },
    'declining_balance': {
      'ar': 'الرصيد المتناقص (DDB)',
      'desc': '2× معدل SL على القيمة الدفترية',
    },
    'sum_of_years_digits': {
      'ar': 'مجموع سنوات العمر (SYD)',
      'desc': 'متسارع — أعباء أكبر في البداية',
    },
  };

  @override
  void dispose() {
    _assetNameC.dispose();
    _costC.dispose();
    _salvageC.dispose();
    _lifeC.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_costC.text.trim().isEmpty) return 'التكلفة مطلوبة';
    final cost = double.tryParse(_costC.text.trim()) ?? 0;
    final salvage = double.tryParse(_salvageC.text.trim()) ?? 0;
    final life = int.tryParse(_lifeC.text.trim()) ?? 0;
    if (cost <= 0) return 'التكلفة يجب أن تكون أكبر من صفر';
    if (life <= 0) return 'العمر الإنتاجي يجب أن يكون أكبر من صفر';
    if (salvage >= cost) return 'قيمة الخردة يجب أن تقل عن التكلفة';
    return null;
  }

  Future<void> _compute() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'cost': _costC.text.trim(),
        'salvage_value': _salvageC.text.trim().isEmpty ? '0' : _salvageC.text.trim(),
        'useful_life_years': int.parse(_lifeC.text.trim()),
        'method': _method,
        'asset_name': _assetNameC.text.trim(),
        'first_year_months': _firstYearMonths,
      };
      final r = await ApiService.depreciationCompute(body);
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
      appBar: ApexAppBar(title: 'حاسبة الإهلاك'),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 900;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [_form(), const SizedBox(height: 16), _results()]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4,
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _form())),
          Container(width: 1, color: AC.bdr),
          Expanded(flex: 6,
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _results())),
        ]);
      }),
    );
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('بيانات الأصل'),
    _textField(_assetNameC, 'اسم الأصل', Icons.label),
    _numField(_costC, 'التكلفة *', Icons.attach_money),
    _numField(_salvageC, 'قيمة الخردة', Icons.recycling),
    _numField(_lifeC, 'العمر الإنتاجي (سنوات) *', Icons.timelapse, isInt: true),
    const SizedBox(height: 12),
    _section('طريقة الإهلاك'),
    Column(children: _methods.entries.map((e) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _method = e.key),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _method == e.key ? AC.gold.withValues(alpha: 0.08) : AC.navy3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _method == e.key ? AC.gold : AC.bdr,
                width: _method == e.key ? 1.5 : 1),
            ),
            child: Row(children: [
              Icon(
                _method == e.key ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _method == e.key ? AC.gold : AC.ts,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.value['ar']!, style: TextStyle(
                  color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(e.value['desc']!, style: TextStyle(color: AC.ts, fontSize: 11)),
              ])),
            ]),
          ),
        ),
      )).toList()),
    const SizedBox(height: 12),
    _section('السنة الأولى (Proration اختياري)'),
    Row(children: [
      Text('أشهر الخدمة:', style: TextStyle(color: AC.ts, fontSize: 12)),
      const SizedBox(width: 10),
      Expanded(
        child: Slider(
          value: _firstYearMonths.toDouble(),
          min: 1, max: 12, divisions: 11,
          activeColor: AC.gold,
          label: '$_firstYearMonths',
          onChanged: (v) => setState(() => _firstYearMonths = v.round()),
        ),
      ),
      Text('$_firstYearMonths',
        style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 8),
    if (_error != null) _errorBanner(_error!),
    const SizedBox(height: 12),
    SizedBox(height: 54,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.calculate),
        label: const Text('احسب الجدول', style: TextStyle(fontSize: 16)),
      ),
    ),
  ]);

  Widget _results() {
    if (_result == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AC.navy2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_graph, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('املأ بيانات الأصل واختر الطريقة',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final schedule = (d['schedule'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;
    final cost = d['cost'] ?? '0';
    final salvage = d['salvage_value'] ?? '0';
    final base = d['depreciable_base'] ?? '0';
    final total = d['total_depreciation'] ?? '0';
    final rate = d['annual_rate_pct'] ?? '0';
    final method = (d['method'] ?? '').toString();
    final methodAr = _methods[method]?['ar'] ?? method;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _summary(cost, salvage, base, total, rate, methodAr),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      _scheduleTable(schedule, double.tryParse(base.toString()) ?? 0),
    ]);
  }

  Widget _summary(String cost, String salvage, String base, String total,
                  String rate, String methodAr) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
        begin: Alignment.topRight, end: Alignment.bottomLeft),
      border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.insights, color: AC.gold, size: 22),
        const SizedBox(width: 8),
        Text(methodAr, style: TextStyle(
          color: AC.gold, fontSize: 15, fontWeight: FontWeight.w800)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AC.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$rate%/سنة',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
      Divider(color: AC.gold.withValues(alpha: 0.3), height: 20),
      _kv('التكلفة الأصلية', '$cost SAR'),
      _kv('قيمة الخردة', '$salvage SAR'),
      _kv('القاعدة القابلة للإهلاك', '$base SAR', vc: AC.info),
      const SizedBox(height: 4),
      _kv('إجمالي الإهلاك', '$total SAR', vc: AC.gold, bold: true),
    ]),
  );

  Widget _scheduleTable(List schedule, double base) => Container(
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(children: [
          SizedBox(width: 30, child: Text('السنة',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('قيمة البداية',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('الإهلاك',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('المتراكم',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)),
          Expanded(child: Text('قيمة النهاية',
            style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.end)),
        ]),
      ),
      ...schedule.asMap().entries.map((e) {
        final y = e.value as Map;
        final isLast = e.key == schedule.length - 1;
        final dep = double.tryParse(y['depreciation'].toString()) ?? 0;
        final pct = base > 0 ? (dep / base).clamp(0, 1) : 0.0;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(children: [
              Row(children: [
                SizedBox(width: 30, child: Text('${y['year']}',
                  style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(child: Text('${y['opening_book_value']}',
                  style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
                  textAlign: TextAlign.center)),
                Expanded(child: Text('${y['depreciation']}',
                  style: TextStyle(color: AC.warn, fontSize: 11,
                    fontFamily: 'monospace', fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center)),
                Expanded(child: Text('${y['accumulated']}',
                  style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace'),
                  textAlign: TextAlign.center)),
                Expanded(child: Text('${y['closing_book_value']}',
                  style: TextStyle(color: AC.ok, fontSize: 11, fontFamily: 'monospace'),
                  textAlign: TextAlign.end)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.toDouble(),
                  minHeight: 4,
                  backgroundColor: AC.navy3,
                  valueColor: AlwaysStoppedAnimation(AC.warn.withValues(alpha: 0.6)),
                ),
              ),
            ]),
          ),
          if (!isLast) Divider(color: AC.bdr, height: 1),
        ]);
      }),
    ]),
  );

  // Helpers
  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _textField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: TextStyle(color: AC.tp),
        decoration: _inpDec(label, icon),
      ),
    );

  Widget _numField(TextEditingController c, String label, IconData icon, {bool isInt = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: isInt ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        decoration: _inpDec(label, icon),
      ),
    );

  InputDecoration _inpDec(String label, IconData icon) => InputDecoration(
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
  );

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AC.err.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AC.err.withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      Icon(Icons.error_outline, color: AC.err, size: 16),
      const SizedBox(width: 6),
      Expanded(child: Text(msg, style: TextStyle(color: AC.err, fontSize: 12))),
    ]),
  );

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
        Text('ملاحظات',
          style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ...warnings.map((w) => Text('• $w',
        style: TextStyle(color: AC.tp, fontSize: 11, height: 1.5))),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp,
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
