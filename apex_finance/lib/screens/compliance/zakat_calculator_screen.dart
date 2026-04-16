/// APEX Platform — Zakat Calculator
/// ═══════════════════════════════════════════════════════════════
/// KSA Zakat computation per ZATCA guidelines:
///   Zakat base = max(adjusted net profit,  additions − deductions)
///   Zakat due  = base × 2.5%
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class ZakatCalculatorScreen extends StatefulWidget {
  const ZakatCalculatorScreen({super.key});
  @override
  State<ZakatCalculatorScreen> createState() => _ZakatCalculatorScreenState();
}

class _ZakatCalculatorScreenState extends State<ZakatCalculatorScreen> {
  // Additions
  final _capitalC = TextEditingController();
  final _retainedC = TextEditingController();
  final _statReserveC = TextEditingController();
  final _otherReservesC = TextEditingController();
  final _provisionsC = TextEditingController();
  final _ltLiabilitiesC = TextEditingController();
  final _shareholderLoansC = TextEditingController();
  final _adjNetProfitC = TextEditingController();
  // Deductions
  final _fixedAssetsC = TextEditingController();
  final _intangiblesC = TextEditingController();
  final _ltInvestmentsC = TextEditingController();
  final _accumLossesC = TextEditingController();
  final _deferredTaxC = TextEditingController();
  final _cwipC = TextEditingController();
  // Meta
  final _periodC = TextEditingController(text: '${DateTime.now().year}-FY');
  String _rateLabel = '2.5% (جريجوري)';
  static const Map<String, String> _rates = {
    '2.5% (جريجوري)': '0.025',
    '2.577% (هجري)': '0.02577',
  };

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [
      _capitalC, _retainedC, _statReserveC, _otherReservesC,
      _provisionsC, _ltLiabilitiesC, _shareholderLoansC, _adjNetProfitC,
      _fixedAssetsC, _intangiblesC, _ltInvestmentsC, _accumLossesC,
      _deferredTaxC, _cwipC, _periodC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? '0' : t;
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'period_label': _periodC.text.trim().isEmpty ? 'FY' : _periodC.text.trim(),
        'rate': _rates[_rateLabel],
        'capital': _v(_capitalC),
        'retained_earnings': _v(_retainedC),
        'statutory_reserve': _v(_statReserveC),
        'other_reserves': _v(_otherReservesC),
        'provisions': _v(_provisionsC),
        'long_term_liabilities': _v(_ltLiabilitiesC),
        'shareholder_loans': _v(_shareholderLoansC),
        'adjusted_net_profit': _v(_adjNetProfitC),
        'net_fixed_assets': _v(_fixedAssetsC),
        'intangible_assets': _v(_intangiblesC),
        'long_term_investments': _v(_ltInvestmentsC),
        'accumulated_losses': _v(_accumLossesC),
        'deferred_tax_assets': _v(_deferredTaxC),
        'capital_work_in_progress': _v(_cwipC),
      };
      final r = await ApiService.taxZakatCompute(body);
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
        title: Text('حاسبة الزكاة (ZATCA)', style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
      ),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 960;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [_form(), const SizedBox(height: 16), _results()]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5,
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _form())),
          Container(width: 1, color: AC.bdr),
          Expanded(flex: 5,
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _results())),
        ]);
      }),
    );
  }

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section('الفترة والمعدل'),
      Row(children: [
        Expanded(
          child: _field(_periodC, 'مسمى الفترة', Icons.calendar_today)),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _rateLabel,
              decoration: _inpDec('معدل الزكاة', Icons.percent),
              dropdownColor: AC.navy2,
              style: TextStyle(color: AC.tp, fontSize: 13),
              items: _rates.keys.map((k) =>
                DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) { if (v != null) setState(() => _rateLabel = v); },
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _section('الإضافات (قاعدة حقوق الملكية)'),
      _numField(_capitalC, 'رأس المال', Icons.savings),
      _numField(_retainedC, 'الأرباح المرحلة', Icons.trending_up),
      _numField(_statReserveC, 'الاحتياطي النظامي', Icons.account_balance),
      _numField(_otherReservesC, 'احتياطيات أخرى', Icons.shield),
      _numField(_provisionsC, 'المخصصات', Icons.inventory),
      _numField(_ltLiabilitiesC, 'الالتزامات طويلة الأجل', Icons.receipt_long),
      _numField(_shareholderLoansC, 'قروض المساهمين', Icons.group),
      _numField(_adjNetProfitC, 'صافي الربح المعدّل (قاعدة الحد الأدنى)', Icons.summarize),
      const SizedBox(height: 12),
      _section('الخصومات (أصول غير خاضعة للزكاة)'),
      _numField(_fixedAssetsC, 'الأصول الثابتة (صافي)', Icons.apartment),
      _numField(_intangiblesC, 'الأصول غير الملموسة', Icons.auto_awesome),
      _numField(_ltInvestmentsC, 'استثمارات طويلة الأجل', Icons.analytics),
      _numField(_accumLossesC, 'الخسائر المتراكمة', Icons.trending_down),
      _numField(_deferredTaxC, 'الأصول الضريبية المؤجلة', Icons.hourglass_bottom),
      _numField(_cwipC, 'مشاريع تحت الإنشاء', Icons.construction),
      const SizedBox(height: 16),
      if (_error != null) _errorBanner(_error!),
      const SizedBox(height: 8),
      SizedBox(
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _compute,
          icon: _loading
            ? const SizedBox(height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.calculate),
          label: const Text('احسب الزكاة', style: TextStyle(fontSize: 16)),
        ),
      ),
    ],
  );

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
          Icon(Icons.savings, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('املأ البيانات ثم اضغط "احسب"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
          const SizedBox(height: 6),
          Text('النتائج التفصيلية تظهر هنا',
            style: TextStyle(color: AC.td, fontSize: 12)),
        ]),
      );
    }
    final d = _result!;
    final base = (d['zakat_base'] ?? '0').toString();
    final due = (d['zakat_due'] ?? '0').toString();
    final ratePct = (d['rate_pct'] ?? '').toString();
    final addTotal = (d['additions_total'] ?? '0').toString();
    final dedTotal = (d['deductions_total'] ?? '0').toString();
    final usedFloor = d['used_floor'] == true;
    final warnings = (d['warnings'] ?? []) as List;
    final lines = (d['lines'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _bigResult(base, due, ratePct),
      if (usedFloor) ...[
        const SizedBox(height: 12),
        _floorBanner(),
      ],
      const SizedBox(height: 14),
      _summaryCard(addTotal, dedTotal),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      _trailCard(lines),
    ]);
  }

  Widget _bigResult(String base, String due, String ratePct) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AC.gold.withValues(alpha: 0.12), AC.gold.withValues(alpha: 0.04)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      border: Border.all(color: AC.gold.withValues(alpha: 0.4), width: 1.5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('قاعدة الزكاة', style: TextStyle(color: AC.ts, fontSize: 13)),
      const SizedBox(height: 4),
      Text('$base SAR',
        style: TextStyle(color: AC.tp, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      Divider(color: AC.gold.withValues(alpha: 0.3), height: 28),
      Text('الزكاة المستحقة بنسبة $ratePct%',
        style: TextStyle(color: AC.ts, fontSize: 13)),
      const SizedBox(height: 4),
      Row(children: [
        Text('$due SAR',
          style: TextStyle(color: AC.gold, fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.copy, color: AC.goldText, size: 18),
          tooltip: 'نسخ',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: due));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('تم النسخ'), backgroundColor: AC.ok));
          },
        ),
      ]),
    ]),
  );

  Widget _floorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.info.withValues(alpha: 0.10),
      border: Border.all(color: AC.info.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, color: AC.info, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'تم اعتماد صافي الربح المعدّل كقاعدة (الصيغة أ) لأنه أعلى من الصيغة (ب).',
        style: TextStyle(color: AC.tp, fontSize: 12))),
    ]),
  );

  Widget _summaryCard(String add, String ded) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr)),
    child: Column(children: [
      _kv('إجمالي الإضافات', '$add SAR', vc: AC.ok),
      _kv('إجمالي الخصومات', '$ded SAR', vc: AC.warn),
    ]),
  );

  Widget _warnCard(List warnings) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.warn.withValues(alpha: 0.08),
      border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: AC.warn, size: 16),
        const SizedBox(width: 6),
        Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ...warnings.map((w) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('• $w', style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
      )),
    ]),
  );

  Widget _trailCard(List lines) => ExpansionTile(
    backgroundColor: AC.navy2,
    collapsedBackgroundColor: AC.navy2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AC.bdr)),
    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AC.bdr)),
    leading: Icon(Icons.list_alt, color: AC.gold),
    title: Text('سجل التفصيل (${lines.length})',
      style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
    children: lines.map<Widget>((l) {
      final m = l as Map;
      final isAdd = m['kind'] == 'add';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Icon(isAdd ? Icons.add_circle : Icons.remove_circle,
            color: isAdd ? AC.ok : AC.warn, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text('${m['label_ar']}',
            style: TextStyle(color: AC.tp, fontSize: 12))),
          Text('${m['amount']}',
            style: TextStyle(
              color: isAdd ? AC.ok : AC.warn,
              fontSize: 12,
              fontFamily: 'monospace')),
        ]),
      );
    }).toList(),
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

  Widget _field(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: TextStyle(color: AC.tp),
        decoration: _inpDec(label, icon),
      ),
    );

  Widget _numField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        decoration: _inpDec(label, icon).copyWith(
          hintText: '0.00',
          hintStyle: TextStyle(color: AC.td, fontFamily: 'monospace'),
        ),
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AC.goldText),
    ),
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

  Widget _kv(String k, String v, {Color? vc}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp, fontSize: 13, fontFamily: 'monospace',
        fontWeight: FontWeight.w600)),
    ]),
  );
}
