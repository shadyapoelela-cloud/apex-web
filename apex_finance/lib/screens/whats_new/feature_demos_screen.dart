/// Bundled interactive demos for the smaller backend features.
/// Contains: Payments, AP Pipeline, Bank OCR, GOSI, WPS, EOSB, WhatsApp,
/// ZATCA, Open Banking.
///
/// Each demo is a standalone StatefulWidget that mirrors the Python
/// calculation client-side for instant feedback.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/apex_form_field.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/validators_ui.dart';

// ═════════════════════════════════════════════════════════════
// Payments Playground
// ═════════════════════════════════════════════════════════════

class PaymentsPlaygroundScreen extends StatefulWidget {
  const PaymentsPlaygroundScreen({super.key});
  @override
  State<PaymentsPlaygroundScreen> createState() => _PaymentsPlaygroundScreenState();
}

class _PaymentsPlaygroundScreenState extends State<PaymentsPlaygroundScreen> {
  String _provider = 'mada';
  final _amountCtrl = TextEditingController(text: '150.00');
  final _refCtrl = TextEditingController(text: 'INV-2026-001');
  final _phoneCtrl = TextEditingController(text: '+966501234567');
  Map<String, dynamic>? _result;

  static const providers = [
    ('mada', 'Mada via HyperPay', Icons.credit_card, 'KSA'),
    ('stc_pay', 'STC Pay', Icons.smartphone, 'KSA'),
    ('apple_pay', 'Apple Pay', Icons.apple, 'KSA + UAE'),
    ('tabby', 'Tabby BNPL', Icons.splitscreen, 'KSA + UAE'),
    ('tamara', 'Tamara BNPL', Icons.splitscreen, 'KSA'),
    ('benefit', 'Benefit', Icons.account_balance, 'BH'),
    ('stripe', 'Stripe', Icons.payment, 'Global'),
    ('mock', 'Mock (dev)', Icons.build, 'Dev'),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _simulate() {
    // Mirror the Python factory's response shape — mock always succeeds,
    // others return a "not configured" error unless credentials exist.
    final amount = _amountCtrl.text;
    final ref = _refCtrl.text;
    setState(() {
      if (_provider == 'mock') {
        _result = {
          'success': true,
          'provider': 'mock',
          'pay_url': 'https://apex-app.com/mock-pay/$ref',
          'reference': ref,
          'raw': {'amount': amount},
        };
      } else {
        _result = {
          'success': false,
          'provider': _provider,
          'error': '${_provider.toUpperCase()} credentials not configured '
              '(هذا متوقع في بيئة التطوير — يعمل تلقائياً عند ضبط env vars)',
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'GCC Payments Playground'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اختر المزوّد:',
                      style: TextStyle(color: AC.tp, fontSize: AppFontSize.lg)),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: providers.map((p) {
                      final (id, name, icon, region) = p;
                      final selected = _provider == id;
                      return InkWell(
                        onTap: () => setState(() => _provider = id),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 180,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: selected
                                ? AC.gold.withValues(alpha: 0.15)
                                : AC.navy2,
                            border: Border.all(
                                color: selected ? AC.gold : AC.navy4),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(icon,
                                  color: selected ? AC.gold : AC.ts, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                            color: AC.tp,
                                            fontWeight: FontWeight.w600)),
                                    Text(region,
                                        style: TextStyle(
                                            color: AC.td,
                                            fontSize: AppFontSize.xs)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ApexFormField(
                      label: 'المبلغ',
                      controller: _amountCtrl,
                      validator: validateSarAmount),
                  const SizedBox(height: AppSpacing.md),
                  ApexFormField(
                      label: 'مرجع الفاتورة', controller: _refCtrl),
                  const SizedBox(height: AppSpacing.md),
                  ApexFormField(
                      label: 'جوال العميل (لـ STC Pay)',
                      controller: _phoneCtrl,
                      validator: validateSaudiMobile),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('إنشاء رابط الدفع'),
                    onPressed: _simulate,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_result != null) _resultCard(_result!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final ok = r['success'] == true;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: (ok ? AC.ok : AC.warn).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.warning_amber,
                  color: ok ? AC.ok : AC.warn),
              const SizedBox(width: AppSpacing.sm),
              Text('نتيجة PaymentFactory',
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            const JsonEncoder.withIndent('  ').convert(r),
            style: TextStyle(
                color: AC.tp,
                fontFamily: 'monospace',
                fontSize: AppFontSize.md),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// AP Pipeline Simulator
// ═════════════════════════════════════════════════════════════

class ApPipelineScreen extends StatefulWidget {
  const ApPipelineScreen({super.key});
  @override
  State<ApPipelineScreen> createState() => _ApPipelineScreenState();
}

class _ApPipelineScreenState extends State<ApPipelineScreen> {
  final _vendorCtrl = TextEditingController(text: 'STC Business');
  final _totalCtrl = TextEditingController(text: '500');
  List<Map<String, dynamic>> _trace = [];

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  void _run() {
    final total = _d(_totalCtrl);
    final List<Map<String, dynamic>> trace = [];

    // processor_ocr
    trace.add({
      'step': 'OCR',
      'status': 'ocr_done',
      'note': 'OCR placeholder (Claude Vision hook)',
    });
    // processor_gl_coding
    trace.add({
      'step': 'GL Coding',
      'status': 'coded',
      'note': 'COA Engine v4.3 suggests account',
    });
    // processor_approval_routing
    final policy = total <= 1000
        ? 'auto_under_threshold'
        : total <= 10000
            ? 'manager'
            : 'cfo';
    final nextStatus = policy == 'auto_under_threshold'
        ? 'approved'
        : 'awaiting_approval';
    trace.add({
      'step': 'Approval Routing',
      'status': nextStatus,
      'policy': policy,
      'note': nextStatus == 'approved'
          ? 'اعتماد تلقائي (تحت الحد الأدنى)'
          : 'يحتاج اعتماد $policy',
    });
    if (nextStatus == 'approved') {
      trace.add({
        'step': 'Schedule Payment',
        'status': 'scheduled',
        'note': 'جدولة حسب due_date + cash-flow buffer',
      });
    }

    setState(() => _trace = trace);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'Autonomous AP Agent — Pipeline'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: ApexFormField(label: 'اسم المورد', controller: _vendorCtrl)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                          child: ApexFormField(
                              label: 'المبلغ',
                              controller: _totalCtrl,
                              validator: validateSarAmount,
                              keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('تشغيل Pipeline'),
                    onPressed: _run,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ..._trace.asMap().entries.map((e) => _step(e.key, e.value)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int i, Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AC.ok.withValues(alpha: 0.2),
            child: Text('${i + 1}',
                style: TextStyle(color: AC.ok, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(s['step'],
                      style: TextStyle(
                          color: AC.tp, fontWeight: FontWeight.w600)),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(s['status'],
                        style: TextStyle(
                            color: AC.cyan, fontSize: AppFontSize.xs)),
                  ),
                ]),
                Text(s['note'], style: TextStyle(color: AC.td)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Bank OCR Demo
// ═════════════════════════════════════════════════════════════

class BankOcrDemoScreen extends StatefulWidget {
  const BankOcrDemoScreen({super.key});
  @override
  State<BankOcrDemoScreen> createState() => _BankOcrDemoScreenState();
}

class _BankOcrDemoScreenState extends State<BankOcrDemoScreen> {
  final _csvCtrl = TextEditingController(
    text: '''Date,Description,Debit,Credit,Balance
2026-04-01,رصيد افتتاحي,,10000,10000
2026-04-02,اشتراك STC,150.00,,9850
2026-04-03,راتب مبيعات,,4500,14350
2026-04-05,فاتورة كهرباء,320.50,,14029.50
2026-04-07,مشتريات مكتب,875,,13154.50''',
  );
  List<_Txn> _parsed = [];

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    final lines = _csvCtrl.text.split('\n');
    if (lines.isEmpty) return;
    final headers = lines[0]
        .split(',')
        .map((h) => h.trim().toLowerCase())
        .toList();
    final dateI = headers.indexWhere((h) => h.contains('date') || h.contains('تاريخ'));
    final descI = headers.indexWhere((h) => h.contains('desc') || h.contains('بيان'));
    final debitI = headers.indexWhere((h) => h.contains('debit') || h.contains('مدين'));
    final creditI = headers.indexWhere((h) => h.contains('credit') || h.contains('دائن'));
    final balI = headers.indexWhere((h) => h.contains('balance') || h.contains('رصيد'));

    final out = <_Txn>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length < headers.length) continue;
      final debit = double.tryParse(cols[debitI].trim()) ?? 0;
      final credit = double.tryParse(cols[creditI].trim()) ?? 0;
      out.add(_Txn(
        date: cols[dateI].trim(),
        desc: cols[descI].trim(),
        amount: debit > 0 ? debit : credit,
        direction: debit > 0 ? 'debit' : 'credit',
        balance: double.tryParse(cols[balI].trim()) ?? 0,
      ));
    }
    setState(() => _parsed = out);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'Bank Statement OCR — CSV Demo'),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الصق CSV من كشف بنك:',
                            style: TextStyle(
                                color: AC.gold, fontSize: AppFontSize.lg)),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: _csvCtrl,
                            maxLines: null,
                            expands: true,
                            style: TextStyle(
                                color: AC.tp,
                                fontFamily: 'monospace',
                                fontSize: AppFontSize.md),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AC.navy2,
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm)),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('تحليل'),
                          onPressed: _parse,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('معاملات مستخرجة (${_parsed.length})',
                            style: TextStyle(
                                color: AC.gold, fontSize: AppFontSize.lg)),
                        const SizedBox(height: AppSpacing.md),
                        ..._parsed.map(_row),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_Txn t) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.navy4),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(t.date,
                  style: TextStyle(
                      color: AC.ts,
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.sm))),
          Expanded(child: Text(t.desc, style: TextStyle(color: AC.tp))),
          SizedBox(
            width: 100,
            child: Text(
              '${t.direction == 'debit' ? '-' : '+'}${formatSarAmount(t.amount)}',
              style: TextStyle(
                color: t.direction == 'debit' ? AC.err : AC.ok,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Txn {
  final String date;
  final String desc;
  final double amount;
  final String direction;
  final double balance;
  _Txn({
    required this.date,
    required this.desc,
    required this.amount,
    required this.direction,
    required this.balance,
  });
}

// ═════════════════════════════════════════════════════════════
// GOSI / GPSSA Calculator
// ═════════════════════════════════════════════════════════════

class GosiCalcScreen extends StatefulWidget {
  const GosiCalcScreen({super.key});
  @override
  State<GosiCalcScreen> createState() => _GosiCalcScreenState();
}

class _GosiCalcScreenState extends State<GosiCalcScreen> {
  final _basicCtrl = TextEditingController(text: '8000');
  final _housingCtrl = TextEditingController(text: '2000');
  String _country = 'ksa';
  bool _isNational = true;

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  void dispose() {
    _basicCtrl.dispose();
    _housingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final basic = _d(_basicCtrl);
    final housing = _d(_housingCtrl);
    final base = _country == 'ksa'
        ? math.min(basic + housing, 45000)
        : math.min(basic + housing, 50000);
    final empRate = _country == 'ksa' ? 0.10 : 0.05;
    final erRate = _country == 'ksa' ? 0.12 : 0.125;
    final applicable = _isNational;
    final emp = applicable ? base * empRate : 0;
    final er = applicable ? base * erRate : 0;

    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'حاسبة GOSI / GPSSA'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ksa', label: Text('السعودية (GOSI)')),
                      ButtonSegment(value: 'uae', label: Text('الإمارات (GPSSA)')),
                    ],
                    selected: {_country},
                    onSelectionChanged: (s) =>
                        setState(() => _country = s.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SwitchListTile(
                    activeColor: AC.gold,
                    title: Text(_country == 'ksa'
                        ? 'موظف سعودي'
                        : 'مواطن UAE/GCC'),
                    value: _isNational,
                    onChanged: (v) => setState(() => _isNational = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ApexFormField(
                      label: 'الراتب الأساسي',
                      controller: _basicCtrl,
                      validator: validateSarAmount,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: AppSpacing.md),
                  ApexFormField(
                      label: 'بدل السكن',
                      controller: _housingCtrl,
                      validator: validateSarAmount,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AC.navy2,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        _kv('الأساس المحسوب (بعد السقف)', base.toDouble()),
                        _kv('مساهمة الموظف (${(empRate * 100).toStringAsFixed(1)}%)',
                            emp.toDouble(), AC.err),
                        _kv('مساهمة صاحب العمل (${(erRate * 100).toStringAsFixed(1)}%)',
                            er.toDouble(), AC.ok),
                        if (!applicable) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text('غير مطبّق — يعتمد على EOSB بدلاً منه',
                              style: TextStyle(color: AC.warn)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, double value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AC.ts)),
          Text(
            formatSarAmount(value),
            style: TextStyle(
              color: color ?? AC.tp,
              fontFamily: 'monospace',
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// EOSB Calculator
// ═════════════════════════════════════════════════════════════

class EosbCalcScreen extends StatefulWidget {
  const EosbCalcScreen({super.key});
  @override
  State<EosbCalcScreen> createState() => _EosbCalcScreenState();
}

class _EosbCalcScreenState extends State<EosbCalcScreen> {
  final _wageCtrl = TextEditingController(text: '10000');
  final _yearsCtrl = TextEditingController(text: '6');
  String _country = 'ksa';
  bool _resigned = false;

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  void dispose() {
    _wageCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wage = _d(_wageCtrl);
    final years = _d(_yearsCtrl);
    double full, payable;
    String note;

    if (_country == 'ksa') {
      final firstYears = math.min(years, 5);
      final secondYears = math.max(years - 5, 0);
      full = wage * firstYears * 0.5 + wage * secondYears;
      if (!_resigned) {
        payable = full;
        note = 'إنهاء خدمة — المكافأة الكاملة (المادة 84).';
      } else if (years < 2) {
        payable = 0;
        note = 'استقالة < ٢ سنة — لا مكافأة (المادة 85).';
      } else if (years < 5) {
        payable = full / 3;
        note = 'استقالة ٢-٥ سنوات — ثلث المكافأة.';
      } else if (years < 10) {
        payable = full * 2 / 3;
        note = 'استقالة ٥-١٠ سنوات — ثلثا المكافأة.';
      } else {
        payable = full;
        note = 'استقالة ≥١٠ سنوات — المكافأة الكاملة.';
      }
    } else {
      final firstYears = math.min(years, 5);
      final secondYears = math.max(years - 5, 0);
      full = wage * firstYears * 21 / 30 + wage * secondYears;
      final cap = wage * 24;
      if (full > cap) {
        full = cap;
        note = 'محددة بسقف سنتين من الراتب (المادة 51).';
      } else {
        note = 'وفق المادة ٥١ من قانون العمل الاتحادي.';
      }
      payable = full;
    }

    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'حاسبة مكافأة نهاية الخدمة'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ksa', label: Text('السعودية')),
                      ButtonSegment(value: 'uae', label: Text('الإمارات')),
                    ],
                    selected: {_country},
                    onSelectionChanged: (s) =>
                        setState(() => _country = s.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_country == 'ksa')
                    SwitchListTile(
                      activeColor: AC.gold,
                      title: const Text('استقالة (بدلاً من إنهاء خدمة)'),
                      value: _resigned,
                      onChanged: (v) => setState(() => _resigned = v),
                    ),
                  ApexFormField(
                      label: _country == 'ksa'
                          ? 'الأجر الشهري الأخير (أساسي + بدلات ثابتة)'
                          : 'الراتب الأساسي الشهري',
                      controller: _wageCtrl,
                      validator: validateSarAmount,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: AppSpacing.md),
                  ApexFormField(
                      label: 'سنوات الخدمة',
                      controller: _yearsCtrl,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AC.navy2,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('المكافأة الكاملة', full, AC.cyan),
                        const Divider(),
                        _kv('المستحق الفعلي', payable, AC.ok),
                        const SizedBox(height: AppSpacing.md),
                        Text(note,
                            style: TextStyle(color: AC.ts, fontSize: AppFontSize.md)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, double value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AC.ts)),
          Text(
            formatSarAmount(value),
            style: TextStyle(
              color: color ?? AC.tp,
              fontFamily: 'monospace',
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// WhatsApp Templates Preview
// ═════════════════════════════════════════════════════════════

class WhatsAppDemoScreen extends StatelessWidget {
  const WhatsAppDemoScreen({super.key});

  static const templates = [
    (
      'apex_invoice_issued_ar',
      'إصدار فاتورة',
      'مرحباً أحمد،\nتم إصدار فاتورة جديدة بقيمة 1,500 ريال.\nرقم الفاتورة: INV-001\nتاريخ الاستحقاق: 2026-04-30'
    ),
    (
      'apex_payment_reminder_ar',
      'تذكير دفع',
      'تذكير ودّي من APEX: فاتورتك رقم INV-001 بقيمة 1,500 ريال مستحقة خلال 3 أيام. شكراً لتعاونك.'
    ),
    (
      'apex_payment_overdue_ar',
      'تأخر دفع',
      'عزيزي أحمد، فاتورتك رقم INV-001 بقيمة 1,500 ريال متأخرة عن السداد بـ 7 يوماً.'
    ),
    (
      'apex_payment_received_ar',
      'استلام دفعة',
      'شكراً لك أحمد! تم استلام دفعة بمبلغ 1,500 ريال لفاتورة رقم INV-001 بتاريخ 2026-04-20.'
    ),
    (
      'apex_expense_approval_ar',
      'اعتماد مصروف',
      'طلب اعتماد مصروف:\nالموظف: محمد\nالمبلغ: 850 ريال\nالفئة: سفر\nالرجاء الرد بـ "موافق" أو "رفض".'
    ),
    (
      'apex_payslip_notice_ar',
      'كشف راتب',
      'تم إصدار كشف راتبك لشهر أبريل ٢٠٢٦.\nصافي الراتب: 8,200 ريال'
    ),
    (
      'apex_budget_alert_ar',
      'تنبيه ميزانية',
      'تنبيه: بند الميزانية "تسويق رقمي" تجاوز 85% من المخصص (42,500 من أصل 50,000 ريال).'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'WhatsApp — قوالب عربية معتمدة'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: templates.map((t) {
                final (id, title, body) = t;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AC.navy2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AC.navy4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.md),
                            topRight: Radius.circular(AppRadius.md),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.chat, color: const Color(0xFF25D366)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: TextStyle(
                                          color: AC.tp,
                                          fontWeight: FontWeight.w700)),
                                  Text(id,
                                      style: TextStyle(
                                          color: AC.td,
                                          fontSize: AppFontSize.sm,
                                          fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(body,
                            style: TextStyle(
                                color: AC.tp,
                                fontSize: AppFontSize.md,
                                height: 1.6)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
