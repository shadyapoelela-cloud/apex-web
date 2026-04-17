/// APEX Platform — Cash Flow Statement (Indirect method)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});
  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final _fields = <String, TextEditingController>{
    'period_label': TextEditingController(text: '${DateTime.now().year}-FY'),
    'beginning_cash': TextEditingController(),
    'ending_cash_reported': TextEditingController(),
    'net_income': TextEditingController(),
    'depreciation_amortization': TextEditingController(),
    'impairment_losses': TextEditingController(),
    'loss_on_asset_sale': TextEditingController(),
    'gain_on_asset_sale': TextEditingController(),
    'increase_receivables': TextEditingController(),
    'increase_inventory': TextEditingController(),
    'increase_prepaid': TextEditingController(),
    'increase_payables': TextEditingController(),
    'increase_accrued': TextEditingController(),
    'increase_deferred_revenue': TextEditingController(),
    'capex': TextEditingController(),
    'proceeds_asset_sale': TextEditingController(),
    'purchase_investments': TextEditingController(),
    'sale_investments': TextEditingController(),
    'acquisitions': TextEditingController(),
    'loan_proceeds': TextEditingController(),
    'loan_repayments': TextEditingController(),
    'share_issuance': TextEditingController(),
    'share_buyback': TextEditingController(),
    'dividends_paid': TextEditingController(),
    'interest_paid': TextEditingController(),
  };

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{};
      _fields.forEach((k, c) {
        final val = c.text.trim();
        if (val.isNotEmpty) body[k] = val;
      });
      if (!body.containsKey('period_label')) body['period_label'] = 'FY';
      final r = await ApiService.cashflowCompute(body);
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
      appBar: ApexAppBar(title: 'قائمة التدفقات النقدية'),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 960;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [_form(), const SizedBox(height: 16), _results()]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: _form())),
          Container(width: 1, color: AC.bdr),
          Expanded(flex: 6, child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: _results())),
        ]);
      }),
    );
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('معلومات الفترة'),
    _field('period_label', 'الفترة', Icons.calendar_today, isText: true),
    _field('beginning_cash', 'الرصيد النقدي الافتتاحي', Icons.account_balance_wallet),
    _field('ending_cash_reported', 'الرصيد الختامي المُبلّغ (اختياري)', Icons.check_circle_outline),
    _section('الأنشطة التشغيلية'),
    _field('net_income', 'صافي الربح', Icons.trending_up),
    _field('depreciation_amortization', 'استهلاك وإطفاء', Icons.trending_down),
    _field('impairment_losses', 'خسائر انخفاض قيمة', Icons.remove_circle),
    _field('loss_on_asset_sale', 'خسارة بيع أصول', Icons.close),
    _field('gain_on_asset_sale', 'ربح بيع أصول (يُطرح)', Icons.check),
    _field('increase_receivables', 'الزيادة في المدينين', Icons.call_received),
    _field('increase_inventory', 'الزيادة في المخزون', Icons.inventory_2),
    _field('increase_prepaid', 'الزيادة في مصروفات مقدمة', Icons.event_available),
    _field('increase_payables', 'الزيادة في الدائنين', Icons.call_made),
    _field('increase_accrued', 'الزيادة في مصروفات مستحقة', Icons.pending_actions),
    _field('increase_deferred_revenue', 'الزيادة في إيرادات مؤجلة', Icons.schedule),
    _section('الأنشطة الاستثمارية'),
    _field('capex', 'نفقات رأسمالية (شراء معدات)', Icons.construction),
    _field('proceeds_asset_sale', 'متحصلات من بيع أصول', Icons.sell),
    _field('purchase_investments', 'شراء استثمارات', Icons.trending_flat),
    _field('sale_investments', 'بيع استثمارات', Icons.monetization_on),
    _field('acquisitions', 'استحواذات', Icons.merge_type),
    _section('الأنشطة التمويلية'),
    _field('loan_proceeds', 'قروض مستلمة', Icons.savings),
    _field('loan_repayments', 'سداد قروض', Icons.payment),
    _field('share_issuance', 'إصدار أسهم', Icons.stacked_bar_chart),
    _field('share_buyback', 'إعادة شراء أسهم', Icons.replay),
    _field('dividends_paid', 'توزيعات مدفوعة', Icons.card_giftcard),
    _field('interest_paid', 'فوائد مدفوعة', Icons.percent),
    const SizedBox(height: 12),
    if (_error != null) _errorBanner(_error!),
    const SizedBox(height: 8),
    SizedBox(height: 54, child: ElevatedButton.icon(
      onPressed: _loading ? null : _compute,
      icon: _loading
        ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.water_drop),
      label: const Text('ابنِ القائمة', style: TextStyle(fontSize: 16)),
    )),
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
          Icon(Icons.water_drop, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('أدخل ما لديك من بيانات ثم اضغط "ابنِ القائمة"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final op = (d['operating'] ?? {}) as Map;
    final inv = (d['investing'] ?? {}) as Map;
    final fin = (d['financing'] ?? {}) as Map;
    final reconciles = d['reconciles'];
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _cashHeader(d),
      if (reconciles != null) ...[
        const SizedBox(height: 10),
        _recBanner(reconciles == true, d['reconciliation_diff']),
      ],
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      _sectionCard(op, AC.ok, Icons.loop),
      const SizedBox(height: 12),
      _sectionCard(inv, AC.info, Icons.trending_up),
      const SizedBox(height: 12),
      _sectionCard(fin, AC.warn, Icons.payments),
    ]);
  }

  Widget _cashHeader(Map<String, dynamic> d) {
    final net = double.tryParse((d['net_change'] ?? '0').toString()) ?? 0;
    final color = net >= 0 ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), AC.navy3],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        _kv('الرصيد الافتتاحي', '${d['beginning_cash']} SAR'),
        _kv('صافي التغير في النقد',
          '${net >= 0 ? '+' : ''}${d['net_change']} SAR', vc: color, bold: true),
        Divider(color: color.withValues(alpha: 0.3), height: 18),
        _kv('الرصيد الختامي', '${d['ending_cash_computed']} SAR', vc: AC.gold, bold: true),
      ]),
    );
  }

  Widget _recBanner(bool ok, dynamic diff) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (ok ? AC.ok : AC.err).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: (ok ? AC.ok : AC.err).withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      Icon(ok ? Icons.verified : Icons.warning_amber_rounded,
        color: ok ? AC.ok : AC.err, size: 16),
      const SizedBox(width: 6),
      Expanded(child: Text(
        ok ? 'تطابق الرصيد مع المُبلّغ' : 'لا يتطابق — الفرق: $diff',
        style: TextStyle(color: ok ? AC.ok : AC.err, fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _sectionCard(Map s, Color color, IconData icon) {
    final lines = (s['lines'] ?? []) as List;
    final subtotal = s['subtotal']?.toString() ?? '0';
    final subVal = double.tryParse(subtotal) ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(s['name_ar']?.toString() ?? '',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${subVal >= 0 ? '+' : ''}$subtotal',
              style: TextStyle(
                color: subVal >= 0 ? AC.ok : AC.err,
                fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          ]),
        ),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('لا بنود', style: TextStyle(color: AC.ts, fontSize: 12)),
          )
        else
          ...lines.asMap().entries.map((e) {
            final ln = e.value as Map;
            final amt = double.tryParse(ln['amount'].toString()) ?? 0;
            final isLast = e.key == lines.length - 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(ln['label_ar']?.toString() ?? '',
                    style: TextStyle(color: AC.tp, fontSize: 12))),
                  Text('${amt >= 0 ? '+' : ''}${ln['amount']}',
                    style: TextStyle(
                      color: amt >= 0 ? AC.ok : AC.err,
                      fontSize: 12, fontFamily: 'monospace',
                      fontWeight: FontWeight.w600)),
                ]),
              ),
              if (!isLast) Divider(color: AC.bdr, height: 1),
            ]);
          }),
      ]),
    );
  }

  // Helpers
  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 8),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _field(String key, String label, IconData icon, {bool isText = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _fields[key],
        keyboardType: isText ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: isText ? null : 'monospace'),
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
        Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ...warnings.map((w) => Text('• $w', style: TextStyle(color: AC.tp, fontSize: 11))),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp,
        fontSize: bold ? 16 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
