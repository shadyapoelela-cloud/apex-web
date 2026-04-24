/// APEX — Manual Journal Entry Creator
/// ═══════════════════════════════════════════════════════════
/// Spreadsheet-style entry form with live Dr=Cr balance check.
/// Creates + posts a JE via the pilot GL endpoint.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class JeCreatorScreen extends StatefulWidget {
  const JeCreatorScreen({super.key});
  @override
  State<JeCreatorScreen> createState() => _JeCreatorScreenState();
}

class _JeLine {
  final accountCtl = TextEditingController();
  final memoCtl = TextEditingController();
  final debitCtl = TextEditingController();
  final creditCtl = TextEditingController();
  void dispose() { accountCtl.dispose(); memoCtl.dispose(); debitCtl.dispose(); creditCtl.dispose(); }
}

class _JeCreatorScreenState extends State<JeCreatorScreen> {
  final _tenantCtl = TextEditingController();
  final _entityCtl = TextEditingController();
  final _dateCtl = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
  final _memoCtl = TextEditingController();
  final _currencyCtl = TextEditingController(text: 'SAR');
  final List<_JeLine> _lines = [_JeLine(), _JeLine()];
  bool _submitting = false;
  String? _lastResult;

  double get _totalDebit => _lines.fold(0.0, (s, l) => s + (double.tryParse(l.debitCtl.text) ?? 0));
  double get _totalCredit => _lines.fold(0.0, (s, l) => s + (double.tryParse(l.creditCtl.text) ?? 0));
  double get _diff => _totalDebit - _totalCredit;
  bool get _isBalanced => _diff.abs() < 0.01 && _totalDebit > 0;

  @override
  void dispose() {
    _tenantCtl.dispose(); _entityCtl.dispose(); _dateCtl.dispose();
    _memoCtl.dispose(); _currencyCtl.dispose();
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_JeLine()));
  void _removeLine(int i) {
    if (_lines.length <= 2) return;
    _lines[i].dispose();
    setState(() => _lines.removeAt(i));
  }

  Future<void> _submit() async {
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('القيد غير متوازن — الفرق ${_diff.toStringAsFixed(2)}')),
      );
      return;
    }
    setState(() => _submitting = true);

    final payload = {
      'tenant_id': _tenantCtl.text.trim(),
      'entity_id': _entityCtl.text.trim(),
      'je_date': _dateCtl.text.trim(),
      'memo_ar': _memoCtl.text.trim(),
      'currency': _currencyCtl.text.trim(),
      'lines': _lines
          .where((l) => l.accountCtl.text.trim().isNotEmpty)
          .map((l) => {
                'account_id': l.accountCtl.text.trim(),
                'debit_amount': double.tryParse(l.debitCtl.text) ?? 0,
                'credit_amount': double.tryParse(l.creditCtl.text) ?? 0,
                'description': l.memoCtl.text.trim(),
                'currency': _currencyCtl.text.trim(),
              })
          .toList(),
    };

    final res = await ApiService.pilotCreateJournalEntry(payload);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final jeId = res.data['id'] as String?;
      if (jeId != null) {
        final post = await ApiService.pilotPostJournalEntry(jeId);
        setState(() {
          _submitting = false;
          _lastResult = post.success
              ? 'تم إنشاء وترحيل القيد — ${res.data['je_number']}'
              : 'تم إنشاؤه draft لكن الترحيل فشل: ${post.error}';
        });
      } else {
        setState(() { _submitting = false; _lastResult = 'تم إنشاء draft'; });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_lastResult!)));
    } else {
      setState(() {
        _submitting = false;
        _lastResult = 'فشل: ${res.error}';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_lastResult!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('إنشاء قيد يومية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: 'إضافة سطر',
              icon: Icon(Icons.add, color: AC.gold),
              onPressed: _addLine,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 12),
              _linesTable(),
              const SizedBox(height: 12),
              _totalsBar(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'جارٍ الحفظ...' : 'حفظ + ترحيل القيد',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: _isBalanced ? AC.gold : AC.navy3,
                  foregroundColor: _isBalanced ? AC.btnFg : AC.ts,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 8),
                Text(_lastResult!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AC.ok, fontFamily: 'Tajawal', fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _txt(_tenantCtl, 'Tenant ID')),
              const SizedBox(width: 8),
              Expanded(child: _txt(_entityCtl, 'Entity ID')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 2, child: _txt(_memoCtl, 'وصف القيد (عربي)')),
              const SizedBox(width: 8),
              Expanded(child: _txt(_dateCtl, 'التاريخ (YYYY-MM-DD)')),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: _txt(_currencyCtl, 'العملة')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linesTable() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(
            children: [
              _hd('#', 22),
              _hd('الحساب (ID)', null, flex: 3),
              _hd('وصف السطر', null, flex: 3),
              _hd('مدين', null, flex: 2),
              _hd('دائن', null, flex: 2),
              _hd('', 40),
            ],
          ),
          Divider(color: AC.gold.withValues(alpha: 0.15), height: 12),
          ..._lines.asMap().entries.map((e) {
            final i = e.key;
            final l = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 22, child: Text('${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 12))),
                  Expanded(flex: 3, child: _cell(l.accountCtl, 'account UUID')),
                  Expanded(flex: 3, child: _cell(l.memoCtl, 'وصف')),
                  Expanded(flex: 2, child: _cell(l.debitCtl, '0', isNumber: true, onChange: () => setState(() {}))),
                  Expanded(flex: 2, child: _cell(l.creditCtl, '0', isNumber: true, onChange: () => setState(() {}))),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: Icon(Icons.delete, color: AC.err, size: 16),
                      onPressed: () => _removeLine(i),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _totalsBar() {
    final bg = _isBalanced ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(_isBalanced ? Icons.check_circle : Icons.warning_amber, color: bg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isBalanced
                  ? 'القيد متوازن — جاهز للترحيل'
                  : 'الفرق ${_diff.toStringAsFixed(2)} — يجب أن يكون صفر',
              style: TextStyle(color: bg, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Text('مدين: ${_totalDebit.toStringAsFixed(2)}',
              style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Text('دائن: ${_totalCredit.toStringAsFixed(2)}',
              style: TextStyle(color: AC.err, fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _txt(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        isDense: true,
      ),
    );
  }

  Widget _cell(TextEditingController c, String hint, {bool isNumber = false, VoidCallback? onChange}) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(color: AC.tp, fontFamily: isNumber ? 'monospace' : 'Tajawal', fontSize: 12),
      onChanged: onChange != null ? (_) => onChange() : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AC.td, fontFamily: isNumber ? 'monospace' : 'Tajawal', fontSize: 11),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  Widget _hd(String text, double? width, {int flex = 1}) {
    final child = Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700));
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex, child: child);
  }
}
