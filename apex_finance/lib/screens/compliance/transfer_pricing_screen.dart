/// APEX Platform — Transfer Pricing (BEPS 13 + KSA TP Bylaws)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class TransferPricingScreen extends StatefulWidget {
  const TransferPricingScreen({super.key});
  @override
  State<TransferPricingScreen> createState() => _TransferPricingScreenState();
}

class _TxnRow {
  final TextEditingController desc;
  final TextEditingController rp;
  final TextEditingController cp;
  final TextEditingController lo;
  final TextEditingController hi;
  String type;
  String method;
  _TxnRow({String d = '', String r = '', String c = '0',
    String l = '0', String h = '0',
    this.type = 'services', this.method = 'TNMM'})
    : desc = TextEditingController(text: d),
      rp = TextEditingController(text: r),
      cp = TextEditingController(text: c),
      lo = TextEditingController(text: l),
      hi = TextEditingController(text: h);
  void dispose() { desc.dispose(); rp.dispose(); cp.dispose(); lo.dispose(); hi.dispose(); }
}

class _TransferPricingScreenState extends State<TransferPricingScreen> {
  final _group = TextEditingController(text: 'مجموعة أبيكس');
  final _local = TextEditingController(text: 'أبيكس السعودية');
  final _year = TextEditingController(text: '2026');
  final _groupRev = TextEditingController(text: '100000000');
  final _localRev = TextEditingController(text: '20000000');
  final List<_TxnRow> _rows = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _types = const ['goods', 'services', 'royalties', 'interest', 'cost_sharing'];
  final _methods = const ['CUP', 'resale_price', 'cost_plus', 'TNMM', 'profit_split'];

  @override
  void initState() {
    super.initState();
    _rows.add(_TxnRow(d: 'أتعاب إدارية إقليمية', r: 'الشركة الأم (UAE)',
      c: '5000000', l: '4500000', h: '5500000',
      type: 'services', method: 'TNMM'));
  }

  @override
  void dispose() {
    _group.dispose(); _local.dispose(); _year.dispose();
    _groupRev.dispose(); _localRev.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'group_name': _group.text.trim(),
        'local_entity_name': _local.text.trim(),
        'fiscal_year': _year.text.trim(),
        'group_consolidated_revenue': _groupRev.text.trim(),
        'local_entity_revenue': _localRev.text.trim(),
        'transactions': _rows.map((r) => {
          'description': r.desc.text.trim(),
          'transaction_type': r.type,
          'related_party_name': r.rp.text.trim(),
          'related_party_jurisdiction': 'UAE',
          'method': r.method,
          'controlled_price': r.cp.text.trim(),
          'arm_length_lower': r.lo.text.trim(),
          'arm_length_upper': r.hi.text.trim(),
          'arm_length_median': r.cp.text.trim(),
        }).toList(),
      };
      final r = await ApiService.tpAnalyse(body);
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
      title: Text('تسعير التحويل (BEPS 13)', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _sf(_group, 'المجموعة', Icons.business)),
          const SizedBox(width: 8),
          Expanded(child: _sf(_local, 'المنشأة المحلية', Icons.account_balance)),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: _sf(_year, 'السنة', Icons.date_range)),
        ]),
        Row(children: [
          Expanded(child: _nf(_groupRev, 'إيرادات المجموعة (لـ CbCR)', Icons.public)),
          const SizedBox(width: 8),
          Expanded(child: _nf(_localRev, 'إيرادات المحلية', Icons.flag)),
        ]),
        const SizedBox(height: 8),
        ..._rows.asMap().entries.map((e) => _row(e.key, e.value)),
        OutlinedButton.icon(
          icon: Icon(Icons.add, color: AC.gold),
          label: Text('إضافة معاملة', style: TextStyle(color: AC.gold)),
          onPressed: () => setState(() => _rows.add(_TxnRow())),
          style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
        ),
        const SizedBox(height: 14),
        if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
        SizedBox(height: 50, child: ElevatedButton.icon(
          onPressed: _loading ? null : _run,
          icon: _loading ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.rule),
          label: const Text('حلّل الامتثال'))),
        if (_result != null) ..._renderResult(_result!),
      ]),
    ),
  );

  Widget _row(int i, _TxnRow r) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Row(children: [
        Expanded(child: TextField(
          controller: r.desc,
          style: TextStyle(color: AC.tp, fontSize: 12),
          decoration: InputDecoration(hintText: 'الوصف', isDense: true,
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
      TextField(
        controller: r.rp,
        style: TextStyle(color: AC.info, fontSize: 11),
        decoration: InputDecoration(hintText: 'الطرف ذو العلاقة', isDense: true,
          hintStyle: TextStyle(color: AC.ts, fontSize: 11), border: InputBorder.none),
      ),
      Row(children: [
        Expanded(child: DropdownButton<String>(
          value: r.type, isDense: true, isExpanded: true,
          dropdownColor: AC.navy2, underline: const SizedBox(),
          style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700),
          items: _types.map((t) =>
            DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => r.type = v!),
        )),
        Expanded(child: DropdownButton<String>(
          value: r.method, isDense: true, isExpanded: true,
          dropdownColor: AC.navy2, underline: const SizedBox(),
          style: TextStyle(color: AC.info, fontSize: 11, fontWeight: FontWeight.w700),
          items: _methods.map((m) =>
            DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => r.method = v!),
        )),
      ]),
      Row(children: [
        Expanded(child: TextField(
          controller: r.cp,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'السعر', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Expanded(child: TextField(
          controller: r.lo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.ok, fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'أدنى', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
        Expanded(child: TextField(
          controller: r.hi,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AC.err, fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: 'أعلى', isDense: true,
            hintStyle: TextStyle(color: AC.ts, fontSize: 10), border: InputBorder.none),
        )),
      ]),
    ]),
  );

  List<Widget> _renderResult(Map d) {
    final status = d['compliance_status'] as String;
    final color = status == 'compliant' ? AC.ok : AC.err;
    return [
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(status == 'compliant' ? Icons.verified : Icons.warning,
            color: color, size: 28),
          Text(status == 'compliant' ? 'ممتثل ✓' : 'تعديلات مطلوبة',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          if (status != 'compliant') Text(
            'إجمالي تعديلات: ${d['total_adjustments']}',
            style: TextStyle(color: color, fontSize: 13, fontFamily: 'monospace'),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('إجمالي المعاملات', '${d['total_controlled_volume']}'),
          const Divider(),
          _flag('نموذج الإفصاح (> 6M)', d['disclosure_form_required'] == true),
          _flag('Local File (≥ 100M)', d['local_file_required'] == true),
          _flag('CbCR (≥ 3.2B)', d['cbcr_required'] == true),
          _flag('Master File', d['master_file_required'] == true),
        ]),
      ),
    ];
  }

  Widget _flag(String label, bool required) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(required ? Icons.check_circle : Icons.remove_circle_outline,
        color: required ? AC.err : AC.ts, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
        style: TextStyle(color: AC.tp, fontSize: 12))),
      Text(required ? 'مطلوب' : 'غير مطلوب',
        style: TextStyle(color: required ? AC.err : AC.ts,
          fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
      Text(v, style: TextStyle(color: AC.tp,
        fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    ]),
  );

  Widget _sf(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
        filled: true, fillColor: AC.navy3, isDense: true,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _nf(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AC.tp, fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AC.goldText, size: 18),
        filled: true, fillColor: AC.navy3, isDense: true,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
    ),
  );
}
