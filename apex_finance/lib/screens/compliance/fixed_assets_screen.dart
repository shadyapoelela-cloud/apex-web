/// APEX Platform — Fixed Assets Register
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class FixedAssetsScreen extends StatefulWidget {
  const FixedAssetsScreen({super.key});
  @override
  State<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenState extends State<FixedAssetsScreen> {
  final _code = TextEditingController(text: 'FA-001');
  final _name = TextEditingController(text: 'خط إنتاج رئيسي');
  final _class = TextEditingController(text: 'ppe');
  final _date = TextEditingController(text: '2026-01-01');
  final _cost = TextEditingController(text: '500000');
  final _idc = TextEditingController(text: '25000');
  final _residual = TextEditingController(text: '25000');
  final _life = TextEditingController(text: '10');
  String _method = 'straight_line';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _methods = const {
    'straight_line': 'قسط ثابت (SL)',
    'double_declining': 'تناقصي مضاعف (DDB)',
    'sum_of_years': 'مجموع أرقام السنين (SYD)',
    'units_of_production': 'وحدات الإنتاج (UOP)',
  };

  @override
  void dispose() {
    _code.dispose(); _name.dispose(); _class.dispose(); _date.dispose();
    _cost.dispose(); _idc.dispose(); _residual.dispose(); _life.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'asset_code': _code.text.trim(),
        'asset_name': _name.text.trim(),
        'asset_class': _class.text.trim(),
        'acquisition_date': _date.text.trim(),
        'acquisition_cost': _cost.text.trim(),
        'initial_direct_costs': _idc.text.trim(),
        'residual_value': _residual.text.trim(),
        'useful_life_years': int.tryParse(_life.text.trim()) ?? 10,
        'depreciation_method': _method,
      };
      final r = await ApiService.fixedAssetBuild(body);
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
      title: Text('سجل الأصول الثابتة', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
    ),
    body: LayoutBuilder(builder: (ctx, cons) {
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
    }),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      Expanded(child: _sf(_code, 'كود الأصل', Icons.qr_code)),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: _sf(_name, 'اسم الأصل', Icons.precision_manufacturing)),
    ]),
    Row(children: [
      Expanded(child: _sf(_class, 'الفئة', Icons.category)),
      const SizedBox(width: 8),
      Expanded(child: _sf(_date, 'تاريخ الاقتناء', Icons.date_range)),
    ]),
    _nf(_cost, 'تكلفة الاقتناء', Icons.attach_money),
    _nf(_idc, 'تكاليف مباشرة أولية', Icons.build),
    _nf(_residual, 'القيمة المتبقية', Icons.recycling),
    _nf(_life, 'العمر الإنتاجي (سنة)', Icons.schedule),
    DropdownButtonFormField<String>(
      value: _method,
      dropdownColor: AC.navy2,
      style: TextStyle(color: AC.tp),
      decoration: InputDecoration(
        labelText: 'طريقة الإهلاك',
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      ),
      items: _methods.entries.map((e) =>
        DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) => setState(() => _method = v!),
    ),
    const SizedBox(height: 12),
    if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _build,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.timeline),
      label: const Text('ابنِ السجل الكامل'))),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.timeline, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('أدخل بيانات الأصل لبناء السجل',
          style: TextStyle(color: AC.ts, fontSize: 14)),
      ]),
    );
    final d = _result!;
    final sch = (d['schedule'] ?? []) as List;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AC.gold.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text('التكلفة المُرسملة', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['capitalised_cost']} ${d['currency']}',
            style: TextStyle(color: AC.gold, fontSize: 24,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text('إهلاك سنوي: ${d['annual_depreciation']}',
            style: TextStyle(color: AC.ts, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('جدول الإهلاك', style: TextStyle(color: AC.tp,
            fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 40, child: Text('السنة',
              style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('افتتاحي',
              textAlign: TextAlign.right,
              style: TextStyle(color: AC.ts, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('إهلاك',
              textAlign: TextAlign.right,
              style: TextStyle(color: AC.warn, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('مجمع',
              textAlign: TextAlign.right,
              style: TextStyle(color: AC.err, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('ختامي',
              textAlign: TextAlign.right,
              style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          Divider(color: AC.bdr, height: 10),
          SizedBox(
            height: 260,
            child: ListView.builder(
              itemCount: sch.length,
              itemBuilder: (ctx, i) {
                final row = sch[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text('${row['year']}',
                      style: TextStyle(color: AC.gold, fontSize: 11, fontFamily: 'monospace'))),
                    Expanded(child: Text('${row['opening_book_value']}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AC.tp, fontSize: 10, fontFamily: 'monospace'))),
                    Expanded(child: Text('${row['depreciation_expense']}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AC.warn, fontSize: 10, fontFamily: 'monospace'))),
                    Expanded(child: Text('${row['accumulated_depreciation']}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AC.err, fontSize: 10, fontFamily: 'monospace'))),
                    Expanded(child: Text('${row['closing_book_value']}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    ]);
  }

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
