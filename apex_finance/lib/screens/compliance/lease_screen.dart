/// APEX Platform — Lease Accounting (IFRS 16)
/// ═══════════════════════════════════════════════════════════════
/// ROU asset + Lease liability schedule.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class LeaseScreen extends StatefulWidget {
  const LeaseScreen({super.key});
  @override
  State<LeaseScreen> createState() => _LeaseScreenState();
}

class _LeaseScreenState extends State<LeaseScreen> {
  final _name = TextEditingController(text: 'عقد إيجار مكتب');
  final _start = TextEditingController(text: '2026-01-01');
  final _term = TextEditingController(text: '60');
  final _payment = TextEditingController(text: '10000');
  final _ibr = TextEditingController(text: '5');
  final _idc = TextEditingController(text: '0');
  final _prepaid = TextEditingController(text: '0');
  final _incent = TextEditingController(text: '0');
  final _residual = TextEditingController(text: '0');
  String _freq = 'monthly';
  String _timing = 'end';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _name.dispose(); _start.dispose(); _term.dispose();
    _payment.dispose(); _ibr.dispose(); _idc.dispose();
    _prepaid.dispose(); _incent.dispose(); _residual.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'lease_name': _name.text.trim().isEmpty ? 'Lease' : _name.text.trim(),
        'start_date': _start.text.trim(),
        'term_months': int.tryParse(_term.text.trim()) ?? 60,
        'payment_amount': _payment.text.trim().isEmpty ? '0' : _payment.text.trim(),
        'payment_frequency': _freq,
        'annual_ibr_pct': _ibr.text.trim().isEmpty ? '5' : _ibr.text.trim(),
        'payment_timing': _timing,
        'initial_direct_costs': _idc.text.trim().isEmpty ? '0' : _idc.text.trim(),
        'prepaid_lease_payments': _prepaid.text.trim().isEmpty ? '0' : _prepaid.text.trim(),
        'lease_incentives': _incent.text.trim().isEmpty ? '0' : _incent.text.trim(),
        'residual_value': _residual.text.trim().isEmpty ? '0' : _residual.text.trim(),
        'currency': 'SAR',
      };
      final r = await ApiService.leaseBuild(body);
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
    appBar: AppBar(
      title: Text('محاسبة الإيجار (IFRS 16)', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
    ),
    body: LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 1000;
      if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _form())),
        Container(width: 1, color: AC.bdr),
        Expanded(flex: 6, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _results())),
      ]);
    }),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('بيانات العقد'),
    _strField(_name, 'اسم العقد', Icons.article),
    _strField(_start, 'تاريخ البداية YYYY-MM-DD', Icons.calendar_today),
    _numField(_term, 'المدة (شهر)', Icons.schedule),
    _section('الدفعات'),
    _numField(_payment, 'الدفعة الدورية', Icons.payments),
    DropdownButtonFormField<String>(
      value: _freq,
      dropdownColor: AC.navy2,
      style: TextStyle(color: AC.tp),
      decoration: InputDecoration(
        labelText: 'تكرار الدفعة',
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
      items: const [
        DropdownMenuItem(value: 'monthly', child: Text('شهري')),
        DropdownMenuItem(value: 'quarterly', child: Text('ربع سنوي')),
        DropdownMenuItem(value: 'annual', child: Text('سنوي')),
      ],
      onChanged: (v) => setState(() => _freq = v!),
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      value: _timing,
      dropdownColor: AC.navy2,
      style: TextStyle(color: AC.tp),
      decoration: InputDecoration(
        labelText: 'توقيت الدفع',
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
      items: const [
        DropdownMenuItem(value: 'end', child: Text('نهاية الفترة')),
        DropdownMenuItem(value: 'begin', child: Text('بداية الفترة')),
      ],
      onChanged: (v) => setState(() => _timing = v!),
    ),
    const SizedBox(height: 10),
    _numField(_ibr, 'معدّل الاقتراض التزايدي % سنوي', Icons.percent),
    _section('تعديلات ROU'),
    _numField(_idc, 'تكاليف مباشرة أولية', Icons.build),
    _numField(_prepaid, 'دفعات مدفوعة مقدماً', Icons.savings),
    _numField(_incent, 'حوافز مستلمة', Icons.card_giftcard),
    _numField(_residual, 'القيمة المتبقية', Icons.receipt_long),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 10),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _build,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.timeline),
      label: const Text('ابنِ جدول الإطفاء'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.timeline, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل بيانات العقد لعرض جدول الإطفاء',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final schedule = (d['schedule'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Hero cards
      Row(children: [
        Expanded(child: _heroCard('التزام الإيجار', '${d['lease_liability_initial']}',
          d['currency'], AC.err)),
        const SizedBox(width: 8),
        Expanded(child: _heroCard('أصل حق الاستخدام ROU', '${d['rou_asset_initial']}',
          d['currency'], AC.ok)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('عدد الفترات', '${d['periods']}'),
          _kv('المعدل الدوري', '${d['periodic_rate']}'),
          _kv('إجمالي الدفعات غير المخصومة', '${d['total_payments']} ${d['currency']}'),
          _kv('إجمالي الفوائد', '${d['total_interest']} ${d['currency']}', vc: AC.warn),
          Divider(color: AC.bdr),
          _kv('استهلاك دوري (قسط ثابت)', '${d['periodic_depreciation']}', vc: AC.info),
          _kv('إجمالي الاستهلاك', '${d['total_depreciation']}', vc: AC.info),
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
      const SizedBox(height: 12),
      _sectionHead('جدول الإطفاء'),
      _scheduleTable(schedule),
    ]);
  }

  Widget _heroCard(String title, String value, dynamic currency, Color color) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.14), AC.navy3],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: TextStyle(color: AC.ts, fontSize: 11)),
        const SizedBox(height: 4),
        Text('$value $currency',
          style: TextStyle(color: color, fontSize: 20,
            fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      ]),
    );

  Widget _scheduleTable(List schedule) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        SizedBox(width: 50, child: Text('#',
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(child: Text('افتتاحي',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(child: Text('دفعة',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(child: Text('فائدة',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.warn, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(child: Text('أصل',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.ok, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(child: Text('ختامي',
          textAlign: TextAlign.right,
          style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
      Divider(color: AC.bdr, height: 10),
      SizedBox(
        height: 380,
        child: ListView.builder(
          itemCount: schedule.length,
          itemBuilder: (ctx, i) {
            final row = schedule[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 50, child: Text('${row['period']}',
                  style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace'))),
                Expanded(child: Text('${row['opening_liability']}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AC.tp, fontSize: 10, fontFamily: 'monospace'))),
                Expanded(child: Text('${row['payment']}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AC.tp, fontSize: 10, fontFamily: 'monospace'))),
                Expanded(child: Text('${row['interest']}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AC.warn, fontSize: 10, fontFamily: 'monospace'))),
                Expanded(child: Text('${row['principal']}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AC.ok, fontSize: 10, fontFamily: 'monospace'))),
                Expanded(child: Text('${row['closing_liability']}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
              ]),
            );
          },
        ),
      ),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _sectionHead(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w800)),
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
