/// APEX Platform — Saudi Withholding Tax (WHT)
/// ═══════════════════════════════════════════════════════════════
/// Two tabs:
///   • Single: one payment, choose category, optional DTT override
///   • Batch: many payments → totals + by-category breakdown
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class WhtScreen extends StatefulWidget {
  const WhtScreen({super.key});
  @override
  State<WhtScreen> createState() => _WhtScreenState();
}

class _WhtScreenState extends State<WhtScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<String> _categories = const [
    'management_fees', 'royalties', 'international_telecom',
    'technical_services', 'rent_movable', 'dividends',
    'interest', 'insurance_reinsurance', 'air_freight', 'other_services',
  ];
  Map<String, String> _defaultRates = const {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final cats = await ApiService.whtCategories();
    if (!mounted) return;
    if (cats.success && cats.data is Map) {
      final d = cats.data['data'];
      if (d is List) setState(() => _categories = d.map((e) => e.toString()).toList());
    }
    final rates = await ApiService.whtRates();
    if (!mounted) return;
    if (rates.success && rates.data is Map) {
      final d = rates.data['data'];
      if (d is Map) {
        setState(() => _defaultRates = {
          for (final e in d.entries) e.key.toString(): e.value.toString(),
        });
      }
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('ضريبة الاستقطاع (WHT)', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
      bottom: TabBar(
        controller: _tab,
        indicatorColor: AC.gold,
        labelColor: AC.gold,
        unselectedLabelColor: AC.ts,
        tabs: const [
          Tab(icon: Icon(Icons.payment), text: 'دفعة مفردة'),
          Tab(icon: Icon(Icons.playlist_add_check), text: 'دفعات متعددة'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: [
      _SingleTab(categories: _categories, defaultRates: _defaultRates),
      _BatchTab(categories: _categories),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// Helpers shared
// ═══════════════════════════════════════════════════════════════

const Map<String, String> _categoryAr = {
  'management_fees': 'أتعاب إدارية',
  'royalties': 'إتاوات',
  'international_telecom': 'اتصالات دولية',
  'technical_services': 'خدمات فنية/استشارية',
  'rent_movable': 'إيجار منقولات',
  'dividends': 'توزيعات أرباح',
  'interest': 'فوائد / تمويل',
  'insurance_reinsurance': 'تأمين/إعادة تأمين',
  'air_freight': 'تذاكر طيران/شحن',
  'other_services': 'خدمات أخرى',
};

String _labelAr(String cat) => _categoryAr[cat] ?? cat;

Widget _numField(TextEditingController c, String label, IconData icon,
    {bool signed = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AC.goldText)),
    ),
  ),
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

Widget _section(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 8, top: 6),
  child: Row(children: [
    Container(width: 3, height: 18, decoration: BoxDecoration(
      color: AC.gold, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
  ]),
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

// ═══════════════════════════════════════════════════════════════
// Tab 1 — Single
// ═══════════════════════════════════════════════════════════════

class _SingleTab extends StatefulWidget {
  final List<String> categories;
  final Map<String, String> defaultRates;
  const _SingleTab({required this.categories, required this.defaultRates});
  @override
  State<_SingleTab> createState() => _SingleTabState();
}

class _SingleTabState extends State<_SingleTab> {
  String _category = 'royalties';
  bool _isGross = true;
  final _amount = TextEditingController(text: '10000');
  final _treaty = TextEditingController();
  final _vendor = TextEditingController(text: 'مورد أجنبي');
  final _ref = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _amount.dispose(); _treaty.dispose();
    _vendor.dispose(); _ref.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{
        'payment_category': _category,
        'amount': _amount.text.trim().isEmpty ? '0' : _amount.text.trim(),
        'is_gross': _isGross,
        'currency': 'SAR',
        'vendor_name': _vendor.text.trim(),
        'reference': _ref.text.trim(),
      };
      final t = _treaty.text.trim();
      if (t.isNotEmpty) body['treaty_rate_pct'] = t;
      final r = await ApiService.whtCompute(body);
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
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cons) {
    final wide = cons.maxWidth > 900;
    if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 4, child: SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: _form())),
      Container(width: 1, color: AC.bdr),
      Expanded(flex: 6, child: SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: _results())),
    ]);
  });

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('نوع الدفعة'),
    DropdownButtonFormField<String>(
      value: _category,
      dropdownColor: AC.navy2,
      style: TextStyle(color: AC.tp),
      decoration: InputDecoration(
        labelText: 'الفئة',
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
      items: widget.categories.map((c) {
        final rate = widget.defaultRates[c] ?? '?';
        return DropdownMenuItem(value: c,
          child: Text('${_labelAr(c)} ($rate%)'));
      }).toList(),
      onChanged: (v) => setState(() => _category = v!),
    ),
    const SizedBox(height: 12),
    _section('المبلغ'),
    _numField(_amount, 'المبلغ', Icons.attach_money),
    SwitchListTile(
      title: Text(_isGross ? 'المبلغ شامل قبل الضريبة' : 'المبلغ صافي (بعد الضريبة)',
        style: TextStyle(color: AC.tp, fontSize: 13)),
      subtitle: Text(_isGross ? 'سنستقطع الضريبة من هذا المبلغ' : 'سنحسب الأساس بحيث يصل المورد لهذا المبلغ',
        style: TextStyle(color: AC.ts, fontSize: 11)),
      value: _isGross,
      activeColor: AC.gold,
      onChanged: (v) => setState(() => _isGross = v),
    ),
    const SizedBox(height: 6),
    _section('اختياري'),
    _numField(_treaty, 'معدل اتفاقية DTT % (اترك فارغاً للافتراضي)', Icons.handshake),
    _strField(_vendor, 'اسم المورد', Icons.business_center),
    _strField(_ref, 'المرجع / رقم الفاتورة', Icons.receipt),
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
      label: const Text('احسب الضريبة'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.payment, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('اختر الفئة وأدخل المبلغ للحساب',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final warnings = (d['warnings'] ?? []) as List;
    final source = d['rate_source'] as String? ?? 'default';
    final sourceColor = source == 'treaty' ? AC.info
      : (source == 'override' ? AC.warn : AC.purple);
    final sourceLabel = source == 'treaty' ? 'معاهدة DTT'
      : (source == 'override' ? 'تجاوز يدوي'
      : (source == 'custom' ? 'معدل مخصص' : 'افتراضي KSA'));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AC.err.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.err.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('ضريبة مقتطعة ${d['rate_applied_pct']}%',
              style: TextStyle(color: AC.ts, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sourceColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: Text(sourceLabel, style: TextStyle(color: sourceColor,
                fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${d['tax_withheld']} ${d['currency']}',
            style: TextStyle(color: AC.err, fontSize: 30,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('الأساس قبل الضريبة', '${d['base_gross']} ${d['currency']}'),
          _kv('ضريبة الاستقطاع', '${d['tax_withheld']} ${d['currency']}', vc: AC.err),
          Divider(color: AC.bdr),
          _kv('صافي المدفوع للمورد', '${d['net_to_pay']} ${d['currency']}',
            vc: AC.ok, bold: true),
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
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: AC.warn, size: 16),
              const SizedBox(width: 6),
              Text('تنبيهات الامتثال', style: TextStyle(color: AC.warn,
                fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('• $w', style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
            )),
          ]),
        ),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 2 — Batch
// ═══════════════════════════════════════════════════════════════

class _BatchRow {
  final TextEditingController vendor;
  final TextEditingController amount;
  String category;
  _BatchRow({String v = '', String a = '0', this.category = 'royalties'})
    : vendor = TextEditingController(text: v),
      amount = TextEditingController(text: a);
  void dispose() { vendor.dispose(); amount.dispose(); }
}

class _BatchTab extends StatefulWidget {
  final List<String> categories;
  const _BatchTab({required this.categories});
  @override
  State<_BatchTab> createState() => _BatchTabState();
}

class _BatchTabState extends State<_BatchTab> {
  final _period = TextEditingController(text: 'Q1 2026');
  final List<_BatchRow> _rows = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _rows.addAll([
      _BatchRow(v: 'مورد A', a: '10000', category: 'royalties'),
      _BatchRow(v: 'مورد B', a: '20000', category: 'dividends'),
      _BatchRow(v: 'مورد C', a: '5000', category: 'technical_services'),
    ]);
  }

  @override
  void dispose() {
    _period.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'period_label': _period.text.trim(),
        'currency': 'SAR',
        'items': _rows.map((r) => {
          'payment_category': r.category,
          'amount': r.amount.text.trim().isEmpty ? '0' : r.amount.text.trim(),
          'vendor_name': r.vendor.text.trim(),
          'is_gross': true,
        }).toList(),
      };
      final r = await ApiService.whtBatch(body);
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
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cons) {
    final wide = cons.maxWidth > 900;
    if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 5, child: SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: _form())),
      Container(width: 1, color: AC.bdr),
      Expanded(flex: 5, child: SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: _results())),
    ]);
  });

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _strField(_period, 'الفترة (مثلاً Q1 2026)', Icons.date_range),
    const SizedBox(height: 8),
    ..._rows.asMap().entries.map((e) => _rowCard(e.key, e.value)),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      icon: Icon(Icons.add, color: AC.gold),
      label: Text('إضافة دفعة', style: TextStyle(color: AC.gold)),
      onPressed: () => setState(() => _rows.add(_BatchRow())),
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
        : const Icon(Icons.summarize),
      label: const Text('احسب الإجماليات'))),
  ]);

  Widget _rowCard(int i, _BatchRow r) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.bdr)),
    child: Row(children: [
      Expanded(flex: 3, child: TextField(
        controller: r.vendor,
        style: TextStyle(color: AC.tp, fontSize: 12),
        decoration: InputDecoration(hintText: 'المورد', isDense: true,
          hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
      )),
      SizedBox(width: 140, child: DropdownButton<String>(
        value: r.category,
        isDense: true,
        isExpanded: true,
        dropdownColor: AC.navy2,
        underline: const SizedBox(),
        style: TextStyle(color: AC.info, fontSize: 11, fontWeight: FontWeight.w700),
        items: widget.categories.map((c) =>
          DropdownMenuItem(value: c, child: Text(_labelAr(c),
            overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => r.category = v!),
      )),
      SizedBox(width: 100, child: TextField(
        controller: r.amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
        textAlign: TextAlign.right,
        decoration: InputDecoration(hintText: '0.00', isDense: true,
          hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
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
  );

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.summarize, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل الدفعات لاحتساب إجماليات الضريبة',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final byCat = (d['by_category'] ?? {}) as Map;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AC.err.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.err.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Text('إجمالي ضريبة الاستقطاع', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_tax']} ${d['currency']}',
            style: TextStyle(color: AC.err, fontSize: 30,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('إجمالي الأساس', '${d['total_base']} ${d['currency']}'),
          _kv('إجمالي الصافي للموردين', '${d['total_net']} ${d['currency']}',
            vc: AC.ok, bold: true),
        ]),
      ),
      if (byCat.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.purple.withValues(alpha: 0.08),
            border: Border.all(color: AC.purple.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('توزيع حسب الفئة', style: TextStyle(color: AC.purple,
              fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            ...byCat.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_labelAr(e.key.toString()),
                  style: TextStyle(color: AC.tp, fontSize: 12)),
                Text('${e.value}', style: TextStyle(color: AC.purple,
                  fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ]),
            )),
          ]),
        ),
      ],
    ]);
  }
}
