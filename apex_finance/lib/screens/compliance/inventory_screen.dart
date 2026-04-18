/// APEX Platform — Inventory Valuation (FIFO/LIFO/WAC)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';

class _Txn {
  String kind = 'purchase';
  final qtyC = TextEditingController();
  final costC = TextEditingController();
  final priceC = TextEditingController();
  void dispose() { qtyC.dispose(); costC.dispose(); priceC.dispose(); }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _method = 'fifo';
  final List<_Txn> _txns = [_Txn()..kind = 'purchase'];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final t in _txns) { t.dispose(); }
    super.dispose();
  }

  void _add(String kind) => setState(() => _txns.add(_Txn()..kind = kind));
  void _remove(int i) {
    if (_txns.length <= 1) return;
    _txns[i].dispose();
    setState(() => _txns.removeAt(i));
  }

  Future<void> _compute() async {
    final valid = _txns.where((t) => t.qtyC.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) { setState(() => _error = 'أضف معاملة واحدة على الأقل'); return; }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'method': _method,
        'transactions': valid.map((t) => {
          'kind': t.kind,
          'quantity': t.qtyC.text.trim(),
          'unit_cost': t.costC.text.trim().isEmpty ? '0' : t.costC.text.trim(),
          if (t.kind == 'sale' && t.priceC.text.trim().isNotEmpty)
            'unit_price': t.priceC.text.trim(),
        }).toList(),
      };
      final r = await ApiService.inventoryValuate(body);
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
    appBar: ApexAppBar(title: 'تقييم المخزون (FIFO/LIFO/WAC)'),
    body: LayoutBuilder(builder: (ctx, cons) {
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
    }),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'fifo', label: Text('FIFO')),
        ButtonSegment(value: 'lifo', label: Text('LIFO')),
        ButtonSegment(value: 'wac',  label: Text('WAC')),
      ],
      selected: {_method},
      onSelectionChanged: (s) => setState(() => _method = s.first),
    ),
    const SizedBox(height: 14),
    Row(children: [
      Text('المعاملات (${_txns.length})',
        style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700)),
      const Spacer(),
      TextButton.icon(onPressed: () => _add('purchase'),
        icon: Icon(Icons.add, color: AC.ok, size: 16),
        label: Text('شراء', style: TextStyle(color: AC.ok))),
      const SizedBox(width: 4),
      TextButton.icon(onPressed: () => _add('sale'),
        icon: Icon(Icons.add, color: AC.warn, size: 16),
        label: Text('بيع', style: TextStyle(color: AC.warn))),
    ]),
    ..._txns.asMap().entries.map((e) => _txnRow(e.key, e.value)),
    const SizedBox(height: 10),
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
        : const Icon(Icons.calculate),
      label: const Text('احسب التقييم'))),
  ]);

  Widget _txnRow(int idx, _Txn t) {
    final color = t.kind == 'purchase' ? AC.ok : AC.warn;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4)),
            child: Text(t.kind == 'purchase' ? 'شراء' : 'بيع',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          Expanded(child: TextField(
            controller: t.qtyC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
            decoration: _compactInput('الكمية'),
          )),
          const SizedBox(width: 6),
          Expanded(child: TextField(
            controller: t.costC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
            decoration: _compactInput(t.kind == 'purchase' ? 'تكلفة/وحدة' : '—',
              enabled: t.kind == 'purchase'),
          )),
          if (t.kind == 'sale') ...[
            const SizedBox(width: 6),
            Expanded(child: TextField(
              controller: t.priceC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: _compactInput('سعر/وحدة'),
            )),
          ],
          if (_txns.length > 1)
            IconButton(icon: Icon(Icons.close, color: AC.err, size: 16),
              onPressed: () => _remove(idx), padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
        ]),
      ]),
    );
  }

  InputDecoration _compactInput(String hint, {bool enabled = true}) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: AC.td, fontSize: 10),
    isDense: true, filled: true, fillColor: enabled ? AC.navy2 : AC.navy3.withValues(alpha: 0.4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(color: AC.bdr)),
  );

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أضف المعاملات لحساب التقييم', style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final trace = (d['trace'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _kv('الطريقة', (d['method'] as String).toUpperCase(),
            vc: AC.gold, bold: true),
          Divider(color: AC.bdr),
          _kv('الكمية النهائية', '${d['ending_qty']}'),
          _kv('قيمة المخزون النهائي', '${d['ending_value']} SAR',
            vc: AC.ok, bold: true),
          _kv('تكلفة الوحدة (متوسط)', '${d['ending_unit_cost']} SAR'),
          Divider(color: AC.bdr),
          _kv('إجمالي المشتريات', '${d['total_purchases_value']} SAR'),
          _kv('إجمالي COGS', '${d['total_cogs']} SAR', vc: AC.warn),
          _kv('إجمالي الإيرادات', '${d['total_revenue']} SAR'),
          _kv('الربح الإجمالي', '${d['gross_profit']} SAR',
            vc: AC.gold, bold: true),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.warn.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map<Widget>((w) => Text('• $w',
              style: TextStyle(color: AC.tp, fontSize: 11))).toList()),
        ),
      ],
      const SizedBox(height: 12),
      _traceTable(trace),
    ]);
  }

  Widget _traceTable(List trace) => Container(
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Text('تتبع المعاملات',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13))),
      ...trace.asMap().entries.map((e) {
        final t = e.value as Map;
        final isPurchase = t['kind'] == 'purchase';
        final color = isPurchase ? AC.ok : AC.warn;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            SizedBox(width: 20, child: Text('${t['seq']}',
              style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700))),
            Icon(isPurchase ? Icons.arrow_downward : Icons.arrow_upward,
              color: color, size: 12),
            const SizedBox(width: 4),
            Expanded(child: Text('${t['quantity']} × ${t['unit_cost']}',
              style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'))),
            Expanded(child: Text('بعد: ${t['running_qty']}',
              style: TextStyle(color: AC.ts, fontSize: 10, fontFamily: 'monospace'),
              textAlign: TextAlign.end)),
          ]),
        );
      }),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: vc ?? AC.tp,
        fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontFamily: 'monospace')),
    ]),
  );
}
