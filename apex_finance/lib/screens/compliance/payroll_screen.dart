/// APEX Platform — Payroll Calculator (GOSI-aware)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _nameC = TextEditingController();
  final _periodC = TextEditingController(
    text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
  String _nationality = 'SA';

  final _basicC = TextEditingController();
  final _housingC = TextEditingController();
  final _transportC = TextEditingController();
  final _otherEarnC = TextEditingController();
  final _overtimeC = TextEditingController();
  final _bonusC = TextEditingController();
  final _absenceC = TextEditingController();
  final _loanC = TextEditingController();
  final _otherDedC = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_nameC, _periodC, _basicC, _housingC, _transportC,
        _otherEarnC, _overtimeC, _bonusC, _absenceC, _loanC, _otherDedC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _compute() async {
    final basic = double.tryParse(_basicC.text.trim()) ?? 0;
    if (basic <= 0) { setState(() => _error = 'الراتب الأساسي مطلوب'); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'employee_name': _nameC.text.trim(),
        'nationality': _nationality,
        'period_label': _periodC.text.trim(),
        'basic_salary': _basicC.text.trim(),
        'housing_allowance': _housingC.text.trim().isEmpty ? '0' : _housingC.text.trim(),
        'transport_allowance': _transportC.text.trim().isEmpty ? '0' : _transportC.text.trim(),
        'other_allowances': _otherEarnC.text.trim().isEmpty ? '0' : _otherEarnC.text.trim(),
        'overtime': _overtimeC.text.trim().isEmpty ? '0' : _overtimeC.text.trim(),
        'bonus': _bonusC.text.trim().isEmpty ? '0' : _bonusC.text.trim(),
        'absence_deduction': _absenceC.text.trim().isEmpty ? '0' : _absenceC.text.trim(),
        'loan_deduction': _loanC.text.trim().isEmpty ? '0' : _loanC.text.trim(),
        'other_deductions': _otherDedC.text.trim().isEmpty ? '0' : _otherDedC.text.trim(),
      };
      final r = await ApiService.payrollCompute(body);
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
      appBar: ApexAppBar(title: 'حاسبة الرواتب + التأمينات'),
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
    _section('بيانات الموظف'),
    _textField(_nameC, 'اسم الموظف', Icons.person),
    Row(children: [
      Expanded(child: _textField(_periodC, 'الفترة (YYYY-MM)', Icons.calendar_today)),
      const SizedBox(width: 10),
      Expanded(child: DropdownButtonFormField<String>(
        value: _nationality,
        decoration: _inpDec('الجنسية', Icons.flag),
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp, fontSize: 13),
        items: const [
          DropdownMenuItem(value: 'SA', child: Text('سعودي')),
          DropdownMenuItem(value: 'EG', child: Text('وافد (مصر)')),
          DropdownMenuItem(value: 'IN', child: Text('وافد (الهند)')),
          DropdownMenuItem(value: 'PK', child: Text('وافد (باكستان)')),
          DropdownMenuItem(value: 'PH', child: Text('وافد (الفلبين)')),
          DropdownMenuItem(value: 'OTHER', child: Text('وافد آخر')),
        ],
        onChanged: (v) { if (v != null) setState(() => _nationality = v); },
      )),
    ]),
    const SizedBox(height: 10),
    _section('الاستحقاقات'),
    _numField(_basicC, 'الراتب الأساسي *', Icons.monetization_on),
    _numField(_housingC, 'بدل السكن', Icons.home),
    _numField(_transportC, 'بدل النقل', Icons.directions_car),
    _numField(_otherEarnC, 'بدلات أخرى', Icons.add_circle),
    _numField(_overtimeC, 'الساعات الإضافية', Icons.schedule),
    _numField(_bonusC, 'مكافآت', Icons.card_giftcard),
    _section('الخصومات'),
    _numField(_absenceC, 'خصم الغياب', Icons.event_busy),
    _numField(_loanC, 'خصم السلفة', Icons.savings),
    _numField(_otherDedC, 'خصومات أخرى', Icons.remove_circle),
    const SizedBox(height: 12),
    if (_error != null) _errorBanner(_error!),
    const SizedBox(height: 8),
    SizedBox(height: 54, child: ElevatedButton.icon(
      onPressed: _loading ? null : _compute,
      icon: _loading
        ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.badge),
      label: const Text('احسب الراتب', style: TextStyle(fontSize: 16)),
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
          Icon(Icons.badge, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('أدخل بيانات الراتب واضغط "احسب"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
        ]),
      );
    }
    final d = _result!;
    final gosi = (d['gosi'] ?? {}) as Map;
    final warnings = (d['warnings'] ?? []) as List;
    final earnings = (d['earning_lines'] ?? []) as List;
    final deductions = (d['deduction_lines'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _bigResult(d),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      _gosiCard(gosi),
      const SizedBox(height: 12),
      _linesCard('الاستحقاقات', earnings, AC.ok, d['gross_earnings']),
      const SizedBox(height: 12),
      _linesCard('الخصومات', deductions, AC.warn, d['total_deductions']),
    ]);
  }

  Widget _bigResult(Map<String, dynamic> d) {
    final net = d['net_pay']?.toString() ?? '0';
    final netVal = double.tryParse(net) ?? 0;
    final color = netVal >= 0 ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.14), AC.navy3],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.payments, color: color, size: 22),
          const SizedBox(width: 8),
          Text('صافي الراتب',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text('$net ${d['currency']}',
          style: TextStyle(color: color, fontSize: 32,
            fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Divider(color: AC.bdr, height: 18),
        _kv('إجمالي الاستحقاقات', '${d['gross_earnings']} SAR', vc: AC.ok),
        _kv('إجمالي الخصومات', '${d['total_deductions']} SAR', vc: AC.warn),
        _kv('التكلفة الإجمالية على صاحب العمل',
          '${d['total_cost_to_employer']} SAR',
          vc: AC.gold, bold: true),
      ]),
    );
  }

  Widget _gosiCard(Map gosi) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.info.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.info.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.shield, color: AC.info, size: 18),
        const SizedBox(width: 6),
        Text('التأمينات الاجتماعية (GOSI)',
          style: TextStyle(color: AC.info, fontWeight: FontWeight.w800, fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      _kv('قاعدة الاشتراك', '${gosi['base']} SAR'),
      _kv('حصة الموظف (${gosi['employee_rate_pct']}%)',
        '${gosi['employee_share']} SAR', vc: AC.warn),
      _kv('حصة صاحب العمل (${gosi['employer_rate_pct']}%)',
        '${gosi['employer_share']} SAR', vc: AC.info),
    ]),
  );

  Widget _linesCard(String title, List lines, Color color, dynamic total) {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Text(title, style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 14)),
            const Spacer(),
            Text('$total', style: TextStyle(
              color: color, fontFamily: 'monospace',
              fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
        ...lines.where((l) {
          final amt = double.tryParse((l as Map)['amount'].toString()) ?? 0;
          return amt != 0;
        }).map((l) {
          final m = l as Map;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(child: Text(m['label_ar']?.toString() ?? '',
                style: TextStyle(color: AC.tp, fontSize: 12))),
              Text('${m['amount']}',
                style: TextStyle(color: color.withValues(alpha: 0.9),
                  fontSize: 12, fontFamily: 'monospace')),
            ]),
          );
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

  Widget _textField(TextEditingController c, String label, IconData icon) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c, style: TextStyle(color: AC.tp),
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
        Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ...warnings.map((w) => Text('• $w',
        style: TextStyle(color: AC.tp, fontSize: 11, height: 1.5))),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(
        color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
