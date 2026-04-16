/// APEX Platform — Bank Reconciliation
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class _RecItem {
  final descC = TextEditingController();
  final amtC = TextEditingController();
  String side = 'book';
  String kind = 'add';
  void dispose() { descC.dispose(); amtC.dispose(); }
}

class BankRecScreen extends StatefulWidget {
  const BankRecScreen({super.key});
  @override
  State<BankRecScreen> createState() => _BankRecScreenState();
}

class _BankRecScreenState extends State<BankRecScreen> {
  final _periodC = TextEditingController(text: '${DateTime.now().year}-Q1');
  final _bookC = TextEditingController();
  final _bankC = TextEditingController();
  final List<_RecItem> _items = [];

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _periodC.dispose();
    _bookC.dispose();
    _bankC.dispose();
    for (final i in _items) { i.dispose(); }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_RecItem()));
  void _removeItem(int i) { _items[i].dispose(); setState(() => _items.removeAt(i)); }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'period_label': _periodC.text.trim(),
        'book_balance': _bookC.text.trim().isEmpty ? '0' : _bookC.text.trim(),
        'bank_balance': _bankC.text.trim().isEmpty ? '0' : _bankC.text.trim(),
        'items': _items.where((i) => i.descC.text.trim().isNotEmpty &&
            i.amtC.text.trim().isNotEmpty).map((i) => {
          'description': i.descC.text.trim(),
          'amount': i.amtC.text.trim(),
          'side': i.side,
          'kind': i.kind,
        }).toList(),
      };
      final r = await ApiService.bankRecCompute(body);
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
    appBar: AppBar(title: Text('التسوية البنكية', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _form(),
        const SizedBox(height: 16),
        if (_result != null) _results(),
      ])),
  );

  Widget _form() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _field(_periodC, 'الفترة', Icons.calendar_today, isText: true)),
      ]),
      Row(children: [
        Expanded(child: _field(_bookC, 'الرصيد الدفتري', Icons.book)),
        const SizedBox(width: 10),
        Expanded(child: _field(_bankC, 'رصيد كشف البنك', Icons.account_balance)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text('عناصر التسوية', style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(onPressed: _addItem,
          icon: const Icon(Icons.add, size: 16), label: const Text('إضافة')),
      ]),
      ..._items.asMap().entries.map((e) => _itemRow(e.key, e.value)),
      if (_items.isEmpty) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('لا توجد تسويات — أضف عناصر إذا كان الرصيدان مختلفان',
          style: TextStyle(color: AC.ts, fontSize: 11, fontStyle: FontStyle.italic)),
      ),
      const SizedBox(height: 12),
      if (_error != null) Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6)),
        child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
      ),
      const SizedBox(height: 8),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.balance),
        label: const Text('سوّي الحسابين'))),
    ]),
  );

  Widget _itemRow(int idx, _RecItem item) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Row(children: [
        Expanded(flex: 3, child: TextField(
          controller: item.descC,
          style: TextStyle(color: AC.tp, fontSize: 12),
          decoration: InputDecoration(hintText: 'الوصف',
            hintStyle: TextStyle(color: AC.td, fontSize: 11),
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AC.bdr))))),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: TextField(
          controller: item.amtC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'المبلغ',
            hintStyle: TextStyle(color: AC.td, fontSize: 11),
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AC.bdr))))),
        IconButton(icon: Icon(Icons.close, color: AC.err, size: 16),
          onPressed: () => _removeItem(idx),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'book', label: Text('دفاتر', style: TextStyle(fontSize: 10))),
            ButtonSegment(value: 'bank', label: Text('بنك', style: TextStyle(fontSize: 10))),
          ],
          selected: {item.side},
          onSelectionChanged: (s) => setState(() => item.side = s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        )),
        const SizedBox(width: 6),
        Expanded(child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'add', label: Text('+', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 'subtract', label: Text('−', style: TextStyle(fontSize: 12))),
          ],
          selected: {item.kind},
          onSelectionChanged: (s) => setState(() => item.kind = s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        )),
      ]),
    ]),
  );

  Widget _results() {
    final d = _result!;
    final reconciled = d['reconciled'] == true;
    final color = reconciled ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(reconciled ? Icons.verified : Icons.warning_amber_rounded,
            color: color, size: 28),
          const SizedBox(width: 8),
          Text(reconciled ? 'تمّت التسوية ✓' : 'لا تتطابق',
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        _kv('الرصيد الدفتري', '${d['book_balance']} SAR'),
        _kv('الرصيد الدفتري المعدَّل', '${d['adjusted_book']} SAR', vc: AC.info, bold: true),
        Divider(color: AC.bdr),
        _kv('رصيد البنك', '${d['bank_balance']} SAR'),
        _kv('رصيد البنك المعدَّل', '${d['adjusted_bank']} SAR', vc: AC.info, bold: true),
        Divider(color: AC.bdr),
        _kv('الفرق', '${d['difference']} SAR',
          vc: reconciled ? AC.ok : AC.err, bold: true),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool isText = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: isText ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AC.tp, fontFamily: isText ? null : 'monospace'),
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

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
