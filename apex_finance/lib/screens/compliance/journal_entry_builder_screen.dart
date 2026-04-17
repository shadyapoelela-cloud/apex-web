/// APEX Platform — Journal Entry Builder
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class _JELine {
  final codeC = TextEditingController();
  final nameC = TextEditingController();
  final debitC = TextEditingController();
  final creditC = TextEditingController();
  final descC = TextEditingController();
  void dispose() {
    codeC.dispose(); nameC.dispose(); debitC.dispose();
    creditC.dispose(); descC.dispose();
  }
}

class JournalEntryBuilderScreen extends StatefulWidget {
  const JournalEntryBuilderScreen({super.key});
  @override
  State<JournalEntryBuilderScreen> createState() => _JournalEntryBuilderScreenState();
}

class _JournalEntryBuilderScreenState extends State<JournalEntryBuilderScreen> {
  final _clientC = TextEditingController(text: 'demo-client');
  final _yearC = TextEditingController(text: '${DateTime.now().year}');
  final _dateC = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10));
  final _memoC = TextEditingController();
  final _refC = TextEditingController();
  String _prefix = 'JE';
  final List<_JELine> _lines = [_JELine(), _JELine()];
  bool _commit = false;      // preview by default; user must tick to post

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_clientC, _yearC, _dateC, _memoC, _refC]) { c.dispose(); }
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_JELine()));
  void _removeLine(int i) {
    if (_lines.length <= 2) return;
    _lines[i].dispose();
    setState(() => _lines.removeAt(i));
  }

  Decimal _sumDebits() {
    double total = 0;
    for (final l in _lines) {
      total += double.tryParse(l.debitC.text.trim()) ?? 0;
    }
    return Decimal(total);
  }

  Decimal _sumCredits() {
    double total = 0;
    for (final l in _lines) {
      total += double.tryParse(l.creditC.text.trim()) ?? 0;
    }
    return Decimal(total);
  }

  Future<void> _loadTemplate(String code) async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.jeGetTemplate(code);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        final t = (r.data['data'] ?? r.data) as Map<String, dynamic>;
        final tmplLines = (t['lines'] ?? []) as List;
        // Dispose existing lines, create new from template
        for (final l in _lines) { l.dispose(); }
        _lines.clear();
        for (final ln in tmplLines) {
          final m = ln as Map;
          final jl = _JELine()
            ..codeC.text = m['account_code']?.toString() ?? ''
            ..nameC.text = m['account_name']?.toString() ?? '';
          _lines.add(jl);
        }
        _memoC.text = t['name_ar']?.toString() ?? '';
        setState(() {});
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _build() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'client_id': _clientC.text.trim(),
        'fiscal_year': _yearC.text.trim(),
        'date': _dateC.text.trim(),
        'memo': _memoC.text.trim(),
        'reference': _refC.text.trim(),
        'prefix': _prefix,
        'commit': _commit,
        'lines': _lines.where((l) =>
          l.codeC.text.trim().isNotEmpty || l.debitC.text.trim().isNotEmpty ||
          l.creditC.text.trim().isNotEmpty).map((l) => {
          'account_code': l.codeC.text.trim(),
          'account_name': l.nameC.text.trim(),
          'debit': l.debitC.text.trim().isEmpty ? '0' : l.debitC.text.trim(),
          'credit': l.creditC.text.trim().isEmpty ? '0' : l.creditC.text.trim(),
          'description': l.descC.text.trim(),
        }).toList(),
      };
      final r = await ApiService.jeBuild(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل البناء');
      }
    } catch (e) { if (mounted) setState(() => _error = 'خطأ: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('بناء قيد يومية', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.auto_awesome, color: AC.gold),
          tooltip: 'قوالب',
          onSelected: _loadTemplate,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'cash_sale', child: Text('مبيعات نقدية')),
            PopupMenuItem(value: 'credit_sale', child: Text('مبيعات آجلة')),
            PopupMenuItem(value: 'cash_purchase', child: Text('مشتريات نقدية')),
            PopupMenuItem(value: 'credit_purchase', child: Text('مشتريات آجلة')),
            PopupMenuItem(value: 'payroll', child: Text('رواتب')),
            PopupMenuItem(value: 'depreciation', child: Text('إهلاك')),
            PopupMenuItem(value: 'customer_payment', child: Text('استلام دفعة')),
            PopupMenuItem(value: 'loan_payment', child: Text('سداد قرض')),
            PopupMenuItem(value: 'dividend_declared', child: Text('إعلان توزيع')),
            PopupMenuItem(value: 'rent_prepaid', child: Text('إيجار مقدّم')),
          ],
        ),
      ]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _headerCard(),
        const SizedBox(height: 12),
        _linesCard(),
        const SizedBox(height: 12),
        _totalsCard(),
        const SizedBox(height: 12),
        _buildCard(),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _resultsCard(),
        ],
      ])),
  );

  Widget _headerCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Row(children: [
        Expanded(child: _field(_clientC, 'معرّف العميل *', Icons.business)),
        const SizedBox(width: 8),
        Expanded(child: _field(_yearC, 'السنة المالية', Icons.calendar_today)),
        const SizedBox(width: 8),
        Expanded(child: _field(_dateC, 'تاريخ القيد', Icons.date_range)),
      ]),
      Row(children: [
        Expanded(flex: 2, child: _field(_memoC, 'الوصف / Memo', Icons.note)),
        const SizedBox(width: 8),
        Expanded(child: _field(_refC, 'المرجع', Icons.tag)),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(
          value: _prefix,
          decoration: _inp('البادئة', Icons.label_important),
          dropdownColor: AC.navy2, style: TextStyle(color: AC.tp, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'JE', child: Text('JE')),
            DropdownMenuItem(value: 'ADJ', child: Text('ADJ')),
            DropdownMenuItem(value: 'CLR', child: Text('CLR')),
            DropdownMenuItem(value: 'OPE', child: Text('OPE')),
            DropdownMenuItem(value: 'REV', child: Text('REV')),
          ],
          onChanged: (v) { if (v != null) setState(() => _prefix = v); },
        )),
      ]),
    ]),
  );

  Widget _linesCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('البنود', style: TextStyle(
          color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
        const Spacer(),
        TextButton.icon(onPressed: _addLine,
          icon: const Icon(Icons.add, size: 14), label: const Text('إضافة بند')),
      ]),
      const SizedBox(height: 8),
      // Header row
      Row(children: [
        SizedBox(width: 60, child: Text('رمز',
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w800))),
        const SizedBox(width: 4),
        Expanded(flex: 3, child: Text('الحساب',
          style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w800))),
        const SizedBox(width: 4),
        Expanded(flex: 2, child: Text('مدين',
          style: TextStyle(color: AC.ok, fontSize: 10, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center)),
        const SizedBox(width: 4),
        Expanded(flex: 2, child: Text('دائن',
          style: TextStyle(color: AC.warn, fontSize: 10, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center)),
        const SizedBox(width: 4),
        const SizedBox(width: 24),   // delete
      ]),
      const Divider(height: 10),
      ..._lines.asMap().entries.map((e) => _lineRow(e.key, e.value)),
    ]),
  );

  Widget _lineRow(int idx, _JELine l) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 60, child: _miniField(l.codeC, '#')),
      const SizedBox(width: 4),
      Expanded(flex: 3, child: _miniField(l.nameC, 'اسم الحساب')),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: _miniAmount(l.debitC, l.creditC, true)),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: _miniAmount(l.creditC, l.debitC, false)),
      const SizedBox(width: 4),
      if (_lines.length > 2)
        IconButton(icon: Icon(Icons.close, color: AC.err, size: 14),
          onPressed: () => _removeLine(idx), padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20))
      else
        const SizedBox(width: 24),
    ]),
  );

  Widget _miniField(TextEditingController c, String hint) => TextField(
    controller: c,
    style: TextStyle(color: AC.tp, fontSize: 11),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: AC.td, fontSize: 10),
      filled: true, fillColor: AC.navy3, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AC.bdr)),
    ),
  );

  Widget _miniAmount(TextEditingController c, TextEditingController other, bool isDebit) =>
    TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: isDebit ? AC.ok : AC.warn,
        fontSize: 11, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: '0.00', hintStyle: TextStyle(color: AC.td, fontSize: 10),
        filled: true, fillColor: AC.navy3, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AC.bdr)),
      ),
      onChanged: (v) {
        // Mutual exclusion: clear the other side if user enters here
        if (v.trim().isNotEmpty && other.text.trim().isNotEmpty) {
          other.clear();
        }
        setState(() {});
      },
    );

  Widget _totalsCard() {
    final deb = _sumDebits();
    final cred = _sumCredits();
    final bal = deb == cred && deb > Decimal(0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (bal ? AC.ok : AC.warn).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (bal ? AC.ok : AC.warn).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(children: [
        Icon(bal ? Icons.check_circle : Icons.warning_amber_rounded,
          color: bal ? AC.ok : AC.warn, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Row(children: [
          Text('مدين: ${deb.toStringAsFixed(2)}',
            style: TextStyle(color: AC.ok, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          Text('دائن: ${cred.toStringAsFixed(2)}',
            style: TextStyle(color: AC.warn, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          Text(bal ? 'متوازن ✓' : 'فرق: ${(deb - cred).toStringAsFixed(2)}',
            style: TextStyle(color: bal ? AC.ok : AC.err,
              fontWeight: FontWeight.w800, fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _buildCard() => Column(children: [
    Row(children: [
      Checkbox(value: _commit, onChanged: (v) => setState(() => _commit = v ?? false),
        activeColor: AC.gold),
      const SizedBox(width: 4),
      Expanded(child: Text(
        _commit
          ? 'سيتم ترحيل القيد وحجز رقم تسلسلي (ZATCA gap-free)'
          : 'معاينة فقط — بدون ترحيل أو حجز رقم',
        style: TextStyle(color: AC.ts, fontSize: 11),
      )),
    ]),
    const SizedBox(height: 8),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(Icons.error_outline, color: AC.err, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12))),
      ]),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _build,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(_commit ? Icons.save : Icons.preview),
      label: Text(_commit ? 'رحّل القيد (Post)' : 'معاينة',
        style: const TextStyle(fontSize: 15)),
    )),
  ]);

  Widget _resultsCard() {
    final d = _result!;
    final committed = d['committed'] == true;
    final color = committed ? AC.ok : AC.info;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), AC.navy3],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(committed ? Icons.check_circle : Icons.preview, color: color, size: 22),
          const SizedBox(width: 8),
          Text(committed ? 'تم الترحيل ✓' : 'معاينة القيد',
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        if (d['entry_number'] != null)
          _kv('رقم القيد', '${d['entry_number']}', vc: AC.gold, bold: true),
        _kv('مدين', '${d['total_debits']}', vc: AC.ok),
        _kv('دائن', '${d['total_credits']}', vc: AC.warn),
        _kv('متوازن', d['is_balanced'] == true ? 'نعم ✓' : 'لا',
          vc: d['is_balanced'] == true ? AC.ok : AC.err),
        if (d['audit_hash'] != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Audit: ${(d['audit_hash'] as String).substring(0, 24)}...',
            style: TextStyle(color: AC.td, fontSize: 10, fontFamily: 'monospace')),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, style: TextStyle(color: AC.tp),
      decoration: _inp(label, icon)),
  );

  InputDecoration _inp(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: AC.goldText, size: 18),
    filled: true, fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts, fontSize: 11),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 15 : 12,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}

/// Tiny Decimal-like helper for the UI totals only (uses double).
class Decimal {
  final double _v;
  const Decimal(this._v);
  double toDouble() => _v;
  String toStringAsFixed(int n) => _v.toStringAsFixed(n);
  bool operator <(Decimal o) => _v < o._v;
  bool operator >(Decimal o) => _v > o._v;
  @override
  bool operator ==(Object other) => other is Decimal &&
    (_v - other._v).abs() < 0.005;
  @override
  int get hashCode => _v.hashCode;
  Decimal operator -(Decimal o) => Decimal(_v - o._v);
}
