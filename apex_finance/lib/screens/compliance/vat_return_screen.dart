/// APEX Platform — VAT Return Calculator
/// ═══════════════════════════════════════════════════════════════
/// Computes a VAT return (output − input) per jurisdiction rate.
/// KSA: 15%, UAE: 5%, BH: 10%, OM: 5%.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/theme.dart';

class VatReturnScreen extends StatefulWidget {
  const VatReturnScreen({super.key});
  @override
  State<VatReturnScreen> createState() => _VatReturnScreenState();
}

class _VatReturnScreenState extends State<VatReturnScreen> {
  // Sales
  final _salesStdC = TextEditingController();
  final _salesZeroC = TextEditingController();
  final _salesExemptC = TextEditingController();
  final _salesOosC = TextEditingController();
  // Purchases
  final _purStdC = TextEditingController();
  final _purZeroC = TextEditingController();
  final _purExemptC = TextEditingController();
  final _purNonReclaimC = TextEditingController();
  // Meta
  final _periodC = TextEditingController(text: '${DateTime.now().year}-Q1');
  final _priorCreditC = TextEditingController();
  String _jurisdiction = 'SA';

  static const Map<String, String> _jurisdictions = {
    'SA': 'السعودية — 15%',
    'AE': 'الإمارات — 5%',
    'BH': 'البحرين — 10%',
    'OM': 'عُمان — 5%',
  };

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_salesStdC, _salesZeroC, _salesExemptC, _salesOosC,
        _purStdC, _purZeroC, _purExemptC, _purNonReclaimC,
        _periodC, _priorCreditC]) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(TextEditingController c) => c.text.trim().isEmpty ? '0' : c.text.trim();

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'jurisdiction': _jurisdiction,
        'period_label': _periodC.text.trim().isEmpty ? 'Q1' : _periodC.text.trim(),
        'prior_period_credit': _v(_priorCreditC),
        'sales': {
          'standard_rated_net': _v(_salesStdC),
          'zero_rated_net': _v(_salesZeroC),
          'exempt_net': _v(_salesExemptC),
          'out_of_scope_net': _v(_salesOosC),
        },
        'purchases': {
          'standard_rated_net': _v(_purStdC),
          'zero_rated_net': _v(_purZeroC),
          'exempt_net': _v(_purExemptC),
          'non_reclaimable_vat': _v(_purNonReclaimC),
        },
      };
      final r = await ApiService.taxVatReturn(body);
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
      body: Column(children: [
        const ApexStickyToolbar(title: 'إقرار ضريبة القيمة المضافة'),
        Expanded(child: LayoutBuilder(builder: (ctx, cons) {
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
      })),
      ]),
    );
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('الفترة والولاية القضائية'),
    Row(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: _jurisdiction,
            decoration: _inpDec('الدولة', Icons.public),
            dropdownColor: AC.navy2,
            style: TextStyle(color: AC.tp, fontSize: 13),
            items: _jurisdictions.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) { if (v != null) setState(() => _jurisdiction = v); },
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: _numField(_periodC, 'الفترة', Icons.calendar_today)),
    ]),
    _numField(_priorCreditC, 'رصيد الفترة السابقة (اختياري)', Icons.history),
    const SizedBox(height: 12),
    _section('المبيعات (ضريبة المخرجات)'),
    _numField(_salesStdC, 'مبيعات بالسعر الأساسي', Icons.storefront),
    _numField(_salesZeroC, 'مبيعات بسعر صفر (صادرات)', Icons.flight_takeoff),
    _numField(_salesExemptC, 'مبيعات معفاة', Icons.do_not_disturb),
    _numField(_salesOosC, 'مبيعات خارج النطاق', Icons.layers_clear),
    const SizedBox(height: 12),
    _section('المشتريات (ضريبة المدخلات)'),
    _numField(_purStdC, 'مشتريات بالسعر الأساسي', Icons.shopping_cart),
    _numField(_purZeroC, 'مشتريات بسعر صفر', Icons.flight_land),
    _numField(_purExemptC, 'مشتريات معفاة', Icons.block),
    _numField(_purNonReclaimC, 'ضريبة غير قابلة للاسترداد', Icons.money_off),
    const SizedBox(height: 16),
    if (_error != null) _errorBanner(_error!),
    const SizedBox(height: 8),
    SizedBox(height: 54,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.calculate),
        label: const Text('احسب صافي الضريبة', style: TextStyle(fontSize: 16)),
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
          Icon(Icons.receipt, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('املأ البيانات ثم اضغط "احسب"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final status = (d['status'] ?? 'nil').toString();
    final netVat = (d['net_vat_due'] ?? '0').toString();
    final outVat = ((d['sales'] ?? {}) as Map)['output_vat_total']?.toString() ?? '0';
    final inVat = ((d['purchases'] ?? {}) as Map)['input_vat_reclaimable']?.toString() ?? '0';
    final ratePct = (d['standard_rate_pct'] ?? '0').toString();
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _bigResult(status, netVat, ratePct),
      const SizedBox(height: 14),
      _breakdownCard(outVat, inVat, d),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      _bucketsCard('تفصيل المبيعات', (d['sales'] as Map)['buckets'] as List),
      const SizedBox(height: 12),
      _bucketsCard('تفصيل المشتريات', (d['purchases'] as Map)['buckets'] as List),
    ]);
  }

  Widget _bigResult(String status, String netVat, String ratePct) {
    final color = status == 'payable' ? AC.warn : (status == 'refund' ? AC.info : AC.ts);
    final label = status == 'payable' ? 'مستحق الدفع'
      : (status == 'refund' ? 'استرداد متوقع' : 'رصيد صفر');
    final icon = status == 'payable' ? Icons.call_made
      : (status == 'refund' ? Icons.call_received : Icons.check_circle_outline);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color,
            fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$ratePct%',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(netVat.replaceFirst('-', ''),
          style: TextStyle(
            color: color, fontSize: 34,
            fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Text('SAR (صافي ضريبة القيمة المضافة)',
          style: TextStyle(color: AC.ts, fontSize: 11)),
      ]),
    );
  }

  Widget _breakdownCard(String outVat, String inVat, Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('ضريبة المخرجات (Output)', '$outVat SAR', vc: AC.ok),
        _kv('ضريبة المدخلات (Input)', '$inVat SAR', vc: AC.warn),
        _kv('رصيد الفترة السابقة', '${d['prior_period_credit']} SAR'),
        if ((d['non_reclaimable_vat'] ?? '0') != '0.00')
          _kv('ضريبة غير قابلة للاسترداد', '${d['non_reclaimable_vat']} SAR',
            vc: AC.td),
      ]),
    );
  }

  Widget _bucketsCard(String title, List buckets) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
        color: AC.gold, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      ...buckets.map((b) {
        final m = b as Map;
        final hasVat = (m['vat'] ?? '0.00') != '0.00';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(hasVat ? Icons.check_circle : Icons.circle_outlined,
              size: 12, color: hasVat ? AC.ok : AC.td),
            const SizedBox(width: 6),
            Expanded(child: Text(m['label_ar'].toString(),
              style: TextStyle(color: AC.tp, fontSize: 12))),
            Text('${m['net']}',
              style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            if (hasVat)
              Text('+${m['vat']}',
                style: TextStyle(color: AC.ok, fontSize: 11, fontFamily: 'monospace')),
          ]),
        );
      }),
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
        child: Text('• $w',
          style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
      )),
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

  Widget _numField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        decoration: _inpDec(label, icon).copyWith(
          hintText: '0.00',
          hintStyle: TextStyle(color: AC.td, fontFamily: 'monospace')),
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
      borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
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
