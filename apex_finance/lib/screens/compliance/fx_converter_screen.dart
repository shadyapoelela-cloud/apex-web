/// APEX Platform — Multi-currency FX Converter
/// ═══════════════════════════════════════════════════════════════
/// Three tools in one screen:
///   • Convert single amount X → Y (direct rate OR via base)
///   • Batch convert many items → target currency
///   • Revalue foreign-currency balance (IAS 21 period-end)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class FxConverterScreen extends StatefulWidget {
  const FxConverterScreen({super.key});
  @override
  State<FxConverterScreen> createState() => _FxConverterScreenState();
}

class _FxConverterScreenState extends State<FxConverterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<String> _currencies = const [
    'SAR', 'USD', 'EUR', 'AED', 'KWD', 'BHD', 'QAR', 'OMR', 'EGP', 'GBP',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final r = await ApiService.fxCurrencies();
    if (!mounted) return;
    if (r.success && r.data is Map) {
      final d = r.data['data'];
      if (d is List) {
        setState(() => _currencies = d.map((e) => e.toString()).toList());
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
      title: Text('محوّل العملات — FX', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
      bottom: TabBar(
        controller: _tab,
        indicatorColor: AC.gold,
        labelColor: AC.gold,
        unselectedLabelColor: AC.ts,
        tabs: const [
          Tab(icon: Icon(Icons.swap_horiz), text: 'تحويل'),
          Tab(icon: Icon(Icons.list_alt), text: 'دفعة'),
          Tab(icon: Icon(Icons.sync_alt), text: 'إعادة تقييم'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: [
      _ConvertTab(currencies: _currencies),
      _BatchTab(currencies: _currencies),
      _RevalueTab(currencies: _currencies),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// Tab 1 — Single convert
// ═══════════════════════════════════════════════════════════════

class _ConvertTab extends StatefulWidget {
  final List<String> currencies;
  const _ConvertTab({required this.currencies});
  @override
  State<_ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends State<_ConvertTab> {
  final _amount = TextEditingController(text: '100');
  final _directRate = TextEditingController();
  String _from = 'USD';
  String _to = 'SAR';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _amount.dispose();
    _directRate.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{
        'amount': _amount.text.trim().isEmpty ? '0' : _amount.text.trim(),
        'from_currency': _from,
        'to_currency': _to,
      };
      final dr = _directRate.text.trim();
      if (dr.isNotEmpty) body['direct_rate'] = dr;
      final r = await ApiService.fxConvert(body);
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
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(16), child: _form());
    final res = SingleChildScrollView(
      padding: const EdgeInsets.all(16), child: _results());
    if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Column(children: [_form(), const SizedBox(height: 16), _results()]));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 4, child: form),
      Container(width: 1, color: AC.bdr),
      Expanded(flex: 6, child: res),
    ]);
  });

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('المبلغ والعملتين'),
    _numField(_amount, 'المبلغ', Icons.attach_money),
    Row(children: [
      Expanded(child: _ccyDropdown('من', _from, (v) => setState(() => _from = v!))),
      const SizedBox(width: 8),
      Icon(Icons.arrow_forward, color: AC.gold),
      const SizedBox(width: 8),
      Expanded(child: _ccyDropdown('إلى', _to, (v) => setState(() => _to = v!))),
    ]),
    const SizedBox(height: 10),
    _section('سعر الصرف (اختياري)'),
    _numField(_directRate, 'سعر مباشر X→Y (اتركه فارغاً لاستخدام الأسعار الافتراضية)', Icons.price_change),
    Text('إذا لم تُدخل سعراً، سيُحسب عبر الريال السعودي كعملة أساس.',
      style: TextStyle(color: AC.ts, fontSize: 11)),
    const SizedBox(height: 10),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _convert,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.swap_horiz),
      label: const Text('حوّل'))),
  ]);

  Widget _results() {
    if (_result == null) return _placeholder(Icons.swap_horiz, 'أدخل المبلغ والعملتين للتحويل');
    final d = _result!;
    final warnings = (d['warnings'] ?? []) as List;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${d['amount_from']} ${d['from_currency']}',
            style: TextStyle(color: AC.ts, fontSize: 14, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Icon(Icons.arrow_downward, color: AC.gold, size: 20),
          const SizedBox(height: 4),
          Text('${d['amount_to']} ${d['to_currency']}',
            style: TextStyle(color: AC.gold, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('سعر الصرف المُطبَّق', '${d['rate_applied']}'),
          _kv('عبر عملة أساس', d['via_base'] == true ? 'نعم (${d['base_currency']})' : 'لا'),
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
              child: Text('• $w', style: TextStyle(color: AC.tp, fontSize: 12)),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _ccyDropdown(String label, String value, ValueChanged<String?> onChanged) =>
    InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700),
        items: widget.currencies.map((c) =>
          DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: onChanged,
      )),
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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AC.goldText)),
      ),
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: AC.tp, fontWeight: FontWeight.w600,
        fontSize: 12, fontFamily: 'monospace')),
    ]),
  );

  Widget _placeholder(IconData icon, String msg) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: AC.ts, size: 64),
      const SizedBox(height: 14),
      Text(msg, style: TextStyle(color: AC.ts, fontSize: 14)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// Tab 2 — Batch convert
// ═══════════════════════════════════════════════════════════════

class _BatchItemRow {
  final TextEditingController label;
  final TextEditingController amount;
  String currency;
  _BatchItemRow({String l = '', String a = '', this.currency = 'USD'})
    : label = TextEditingController(text: l),
      amount = TextEditingController(text: a);
  void dispose() { label.dispose(); amount.dispose(); }
}

class _BatchTab extends StatefulWidget {
  final List<String> currencies;
  const _BatchTab({required this.currencies});
  @override
  State<_BatchTab> createState() => _BatchTabState();
}

class _BatchTabState extends State<_BatchTab> {
  String _target = 'SAR';
  final List<_BatchItemRow> _items = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _items.add(_BatchItemRow(l: 'فاتورة USD', a: '100', currency: 'USD'));
    _items.add(_BatchItemRow(l: 'فاتورة EUR', a: '50', currency: 'EUR'));
  }

  @override
  void dispose() {
    for (final it in _items) { it.dispose(); }
    super.dispose();
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'target_currency': _target,
        'items': _items.map((it) => {
          'label': it.label.text.trim().isEmpty ? 'بند' : it.label.text.trim(),
          'amount': it.amount.text.trim().isEmpty ? '0' : it.amount.text.trim(),
          'from_currency': it.currency,
        }).toList(),
      };
      final r = await ApiService.fxBatch(body);
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
    Row(children: [
      Expanded(child: Text('العملة الهدف',
        style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700))),
      const SizedBox(width: 10),
      SizedBox(width: 120, child: DropdownButtonFormField<String>(
        value: _target,
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        ),
        items: widget.currencies.map((c) =>
          DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _target = v!),
      )),
    ]),
    const SizedBox(height: 12),
    ..._items.asMap().entries.map((e) => _itemRow(e.key, e.value)),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      icon: Icon(Icons.add, color: AC.gold),
      label: Text('إضافة بند', style: TextStyle(color: AC.gold)),
      onPressed: () => setState(() => _items.add(_BatchItemRow())),
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
        : const Icon(Icons.calculate),
      label: const Text('احسب الإجمالي'))),
  ]);

  Widget _itemRow(int i, _BatchItemRow row) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
    child: Row(children: [
      Expanded(flex: 3, child: TextField(
        controller: row.label,
        style: TextStyle(color: AC.tp, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'الوصف', isDense: true,
          hintStyle: TextStyle(color: AC.ts, fontSize: 11),
          border: InputBorder.none,
        ),
      )),
      SizedBox(width: 80, child: TextField(
        controller: row.amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: '0.00', isDense: true,
          hintStyle: TextStyle(color: AC.ts, fontSize: 11),
          border: InputBorder.none,
        ),
      )),
      const SizedBox(width: 6),
      SizedBox(width: 70, child: DropdownButton<String>(
        value: row.currency,
        isDense: true,
        isExpanded: true,
        dropdownColor: AC.navy2,
        underline: const SizedBox(),
        style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700),
        items: widget.currencies.map((c) =>
          DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => row.currency = v!),
      )),
      IconButton(
        icon: Icon(Icons.close, color: AC.err, size: 16),
        onPressed: _items.length > 1 ? () {
          setState(() { row.dispose(); _items.removeAt(i); });
        } : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    ]),
  );

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.list_alt, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل البنود لاحتساب الإجمالي',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final items = (d['items'] ?? []) as List;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.ok.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.ok.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الإجمالي بعد التحويل',
            style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_converted']} ${d['target_currency']}',
            style: TextStyle(color: AC.ok, fontSize: 26,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: items.map((it) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border(
            bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.3)))),
          child: Row(children: [
            Expanded(flex: 3, child: Text(it['label'] ?? '',
              style: TextStyle(color: AC.tp, fontSize: 12))),
            Text('${it['original_amount']} ${it['original_currency']}',
              style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: AC.ts, size: 12),
            const SizedBox(width: 8),
            Text('${it['converted_amount']}',
              style: TextStyle(color: AC.gold, fontSize: 12,
                fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ]),
        )).toList()),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 3 — Revalue (IAS 21)
// ═══════════════════════════════════════════════════════════════

class _RevalueTab extends StatefulWidget {
  final List<String> currencies;
  const _RevalueTab({required this.currencies});
  @override
  State<_RevalueTab> createState() => _RevalueTabState();
}

class _RevalueTabState extends State<_RevalueTab> {
  final _amount = TextEditingController(text: '1000');
  final _histRate = TextEditingController(text: '3.70');
  final _currRate = TextEditingController(text: '3.80');
  String _foreign = 'USD';
  String _reporting = 'SAR';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _amount.dispose();
    _histRate.dispose();
    _currRate.dispose();
    super.dispose();
  }

  Future<void> _revalue() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'amount_foreign': _amount.text.trim().isEmpty ? '0' : _amount.text.trim(),
        'foreign_currency': _foreign,
        'reporting_currency': _reporting,
        'historical_rate': _histRate.text.trim().isEmpty ? '0' : _histRate.text.trim(),
        'current_rate': _currRate.text.trim().isEmpty ? '0' : _currRate.text.trim(),
      };
      final r = await ApiService.fxRevalue(body);
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
    Row(children: [
      Expanded(child: DropdownButtonFormField<String>(
        value: _foreign,
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp),
        decoration: InputDecoration(
          labelText: 'العملة الأجنبية',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        ),
        items: widget.currencies.map((c) =>
          DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _foreign = v!),
      )),
      const SizedBox(width: 8),
      Expanded(child: DropdownButtonFormField<String>(
        value: _reporting,
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp),
        decoration: InputDecoration(
          labelText: 'عملة التقرير',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        ),
        items: widget.currencies.map((c) =>
          DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _reporting = v!),
      )),
    ]),
    const SizedBox(height: 10),
    _numField(_amount, 'الرصيد بالعملة الأجنبية', Icons.account_balance_wallet),
    _numField(_histRate, 'السعر التاريخي (عند الإثبات الأولي)', Icons.history),
    _numField(_currRate, 'السعر الحالي (نهاية الفترة)', Icons.today),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _revalue,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.sync_alt),
      label: const Text('أعد التقييم (IAS 21)'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.sync_alt, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل الأسعار لاحتساب أثر فروق الصرف',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final label = d['gain_or_loss'] as String? ?? 'none';
    final color = label == 'gain' ? AC.ok : (label == 'loss' ? AC.err : AC.info);
    final icon = label == 'gain' ? Icons.trending_up
      : (label == 'loss' ? Icons.trending_down : Icons.trending_flat);
    final heroLabel = label == 'gain' ? 'ربح غير محقق'
      : (label == 'loss' ? 'خسارة غير محققة' : 'لا تغيير');
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Text(heroLabel, style: TextStyle(color: color, fontSize: 18,
              fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Text('${d['unrealised_gain_loss']} ${d['reporting_currency']}',
            style: TextStyle(color: color, fontSize: 32,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('الرصيد الأجنبي', '${d['amount_foreign']} ${d['foreign_currency']}'),
          _kv('قيمة تاريخية', '${d['historical_value']} ${d['reporting_currency']}'),
          _kv('قيمة حالية', '${d['current_value']} ${d['reporting_currency']}'),
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
              Icon(Icons.info_outline, color: AC.warn, size: 16),
              const SizedBox(width: 6),
              Text('ملاحظات محاسبية', style: TextStyle(color: AC.warn,
                fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('• $w', style: TextStyle(color: AC.tp, fontSize: 12)),
            )),
          ]),
        ),
      ],
    ]);
  }

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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AC.goldText)),
      ),
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: AC.tp, fontWeight: FontWeight.w600,
        fontSize: 12, fontFamily: 'monospace')),
    ]),
  );
}
