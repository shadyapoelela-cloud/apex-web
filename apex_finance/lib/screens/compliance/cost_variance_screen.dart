/// APEX Platform — Cost Accounting / Variance Analysis
/// ═══════════════════════════════════════════════════════════════
/// Three-tab variance tool:
///   • Material (price + quantity)
///   • Labour (rate + efficiency)
///   • Overhead (spending + volume)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class CostVarianceScreen extends StatefulWidget {
  const CostVarianceScreen({super.key});
  @override
  State<CostVarianceScreen> createState() => _CostVarianceScreenState();
}

class _CostVarianceScreenState extends State<CostVarianceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
      title: Text('تحليل انحرافات التكاليف', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
      bottom: TabBar(
        controller: _tab,
        indicatorColor: AC.gold,
        labelColor: AC.gold,
        unselectedLabelColor: AC.ts,
        tabs: const [
          Tab(icon: Icon(Icons.inventory_2), text: 'المواد'),
          Tab(icon: Icon(Icons.badge), text: 'العمالة'),
          Tab(icon: Icon(Icons.factory), text: 'الصناعية'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: const [
      _MaterialTab(),
      _LabourTab(),
      _OverheadTab(),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════

Widget _sectionTitle(String t) => Padding(
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AC.goldText)),
    ),
  ),
);

Color _labelColor(String label) {
  if (label == 'favourable') return AC.ok;
  if (label == 'unfavourable') return AC.err;
  return AC.info;
}

String _labelAr(String label) {
  if (label == 'favourable') return 'ملائم';
  if (label == 'unfavourable') return 'غير ملائم';
  return 'متعادل';
}

Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
    Text(v, style: TextStyle(color: vc ?? AC.tp,
      fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      fontFamily: 'monospace')),
  ]),
);

Widget _varianceCard(String title, String value, String label) {
  final color = _labelColor(label);
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: AC.ts, fontSize: 11)),
      const SizedBox(height: 4),
      Row(children: [
        Text(value, style: TextStyle(color: color, fontSize: 16,
          fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4)),
          child: Text(_labelAr(label), style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]),
    ]),
  );
}

Widget _warningsCard(List warnings) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
    border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
    borderRadius: BorderRadius.circular(10)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(Icons.lightbulb_outline, color: AC.warn, size: 16),
      const SizedBox(width: 6),
      Text('ملاحظات', style: TextStyle(color: AC.warn,
        fontWeight: FontWeight.w800, fontSize: 13)),
    ]),
    const SizedBox(height: 6),
    ...warnings.map((w) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('• $w', style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5)),
    )),
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

// ═══════════════════════════════════════════════════════════════
// Material tab
// ═══════════════════════════════════════════════════════════════

class _MaterialTab extends StatefulWidget {
  const _MaterialTab();
  @override
  State<_MaterialTab> createState() => _MaterialTabState();
}

class _MaterialTabState extends State<_MaterialTab> {
  final _name = TextEditingController(text: 'مادة خام');
  final _stdPrice = TextEditingController(text: '10');
  final _stdQty = TextEditingController(text: '2');
  final _actPrice = TextEditingController(text: '9');
  final _actQty = TextEditingController(text: '210');
  final _output = TextEditingController(text: '100');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _name.dispose(); _stdPrice.dispose(); _stdQty.dispose();
    _actPrice.dispose(); _actQty.dispose(); _output.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'item_name': _name.text.trim().isEmpty ? 'مادة' : _name.text.trim(),
        'std_price': _stdPrice.text.trim().isEmpty ? '0' : _stdPrice.text.trim(),
        'std_qty_per_output': _stdQty.text.trim().isEmpty ? '0' : _stdQty.text.trim(),
        'actual_price': _actPrice.text.trim().isEmpty ? '0' : _actPrice.text.trim(),
        'actual_qty_used': _actQty.text.trim().isEmpty ? '0' : _actQty.text.trim(),
        'output_units': _output.text.trim().isEmpty ? '0' : _output.text.trim(),
      };
      final r = await ApiService.costVarianceMaterial(body);
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
    _strField(_name, 'اسم المادة', Icons.inventory_2),
    _sectionTitle('المعياري'),
    _numField(_stdPrice, 'سعر الوحدة المعياري', Icons.price_change),
    _numField(_stdQty, 'الكمية المعيارية لكل وحدة إنتاج', Icons.straighten),
    _sectionTitle('الفعلي'),
    _numField(_actPrice, 'سعر الوحدة الفعلي', Icons.attach_money),
    _numField(_actQty, 'إجمالي الكمية المستخدمة فعلياً', Icons.local_shipping),
    _numField(_output, 'عدد وحدات الإنتاج الفعلية', Icons.widgets),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _analyze,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.analytics),
      label: const Text('حلّل انحراف المواد'))),
  ]);

  Widget _results() {
    if (_result == null) return _placeholder(Icons.inventory_2,
      'أدخل المعياري والفعلي لحساب انحراف المواد');
    final d = _result!;
    final totalLabel = d['total_label'] as String? ?? 'none';
    final color = _labelColor(totalLabel);
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
          Text('إجمالي انحراف المواد', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_variance']} ${d['currency']}',
            style: TextStyle(color: color, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(_labelAr(totalLabel), style: TextStyle(color: color,
            fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 12),
      _varianceCard('انحراف السعر', '${d['price_variance']}', d['price_label']),
      const SizedBox(height: 8),
      _varianceCard('انحراف الكمية', '${d['quantity_variance']}', d['quantity_label']),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('التكلفة المعيارية', '${d['std_cost']} ${d['currency']}'),
          _kv('التكلفة الفعلية', '${d['actual_cost']} ${d['currency']}'),
          _kv('الكمية المسموح بها', '${d['std_qty_allowed']}'),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warningsCard(warnings),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// Labour tab
// ═══════════════════════════════════════════════════════════════

class _LabourTab extends StatefulWidget {
  const _LabourTab();
  @override
  State<_LabourTab> createState() => _LabourTabState();
}

class _LabourTabState extends State<_LabourTab> {
  final _cc = TextEditingController(text: 'مركز التكلفة');
  final _stdRate = TextEditingController(text: '20');
  final _stdHours = TextEditingController(text: '2');
  final _actRate = TextEditingController(text: '22');
  final _actHours = TextEditingController(text: '220');
  final _output = TextEditingController(text: '100');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _cc.dispose(); _stdRate.dispose(); _stdHours.dispose();
    _actRate.dispose(); _actHours.dispose(); _output.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'cost_center': _cc.text.trim().isEmpty ? 'cc' : _cc.text.trim(),
        'std_rate_per_hour': _stdRate.text.trim().isEmpty ? '0' : _stdRate.text.trim(),
        'std_hours_per_output': _stdHours.text.trim().isEmpty ? '0' : _stdHours.text.trim(),
        'actual_rate_per_hour': _actRate.text.trim().isEmpty ? '0' : _actRate.text.trim(),
        'actual_hours': _actHours.text.trim().isEmpty ? '0' : _actHours.text.trim(),
        'output_units': _output.text.trim().isEmpty ? '0' : _output.text.trim(),
      };
      final r = await ApiService.costVarianceLabour(body);
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
    _strField(_cc, 'مركز التكلفة', Icons.business),
    _sectionTitle('المعياري'),
    _numField(_stdRate, 'معدّل الأجر المعياري بالساعة', Icons.attach_money),
    _numField(_stdHours, 'الساعات المعيارية لكل وحدة إنتاج', Icons.hourglass_bottom),
    _sectionTitle('الفعلي'),
    _numField(_actRate, 'معدّل الأجر الفعلي بالساعة', Icons.payments),
    _numField(_actHours, 'إجمالي الساعات الفعلية', Icons.schedule),
    _numField(_output, 'وحدات الإنتاج', Icons.widgets),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _analyze,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.analytics),
      label: const Text('حلّل انحراف العمالة'))),
  ]);

  Widget _results() {
    if (_result == null) return _placeholder(Icons.badge,
      'أدخل بيانات الأجور والساعات لحساب انحراف العمالة');
    final d = _result!;
    final totalLabel = d['total_label'] as String? ?? 'none';
    final color = _labelColor(totalLabel);
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
          Text('إجمالي انحراف العمالة', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_variance']} ${d['currency']}',
            style: TextStyle(color: color, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(_labelAr(totalLabel), style: TextStyle(color: color,
            fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 12),
      _varianceCard('انحراف المعدّل', '${d['rate_variance']}', d['rate_label']),
      const SizedBox(height: 8),
      _varianceCard('انحراف الكفاءة', '${d['efficiency_variance']}', d['efficiency_label']),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('التكلفة المعيارية', '${d['std_cost']} ${d['currency']}'),
          _kv('التكلفة الفعلية', '${d['actual_cost']} ${d['currency']}'),
          _kv('الساعات المسموح بها', '${d['std_hours_allowed']}'),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warningsCard(warnings),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// Overhead tab
// ═══════════════════════════════════════════════════════════════

class _OverheadTab extends StatefulWidget {
  const _OverheadTab();
  @override
  State<_OverheadTab> createState() => _OverheadTabState();
}

class _OverheadTabState extends State<_OverheadTab> {
  final _cc = TextEditingController(text: 'مركز التكلفة');
  final _budget = TextEditingController(text: '10000');
  final _actual = TextEditingController(text: '9500');
  final _stdRate = TextEditingController(text: '50');
  final _stdHours = TextEditingController(text: '2');
  final _actHours = TextEditingController(text: '190');
  final _output = TextEditingController(text: '100');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _cc.dispose(); _budget.dispose(); _actual.dispose();
    _stdRate.dispose(); _stdHours.dispose();
    _actHours.dispose(); _output.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'cost_center': _cc.text.trim().isEmpty ? 'cc' : _cc.text.trim(),
        'budgeted_overhead': _budget.text.trim().isEmpty ? '0' : _budget.text.trim(),
        'actual_overhead': _actual.text.trim().isEmpty ? '0' : _actual.text.trim(),
        'std_rate_per_hour': _stdRate.text.trim().isEmpty ? '0' : _stdRate.text.trim(),
        'std_hours_per_output': _stdHours.text.trim().isEmpty ? '0' : _stdHours.text.trim(),
        'actual_hours': _actHours.text.trim().isEmpty ? '0' : _actHours.text.trim(),
        'output_units': _output.text.trim().isEmpty ? '0' : _output.text.trim(),
      };
      final r = await ApiService.costVarianceOverhead(body);
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
    _strField(_cc, 'مركز التكلفة', Icons.business),
    _sectionTitle('الميزانية مقابل الفعلي'),
    _numField(_budget, 'التكلفة الصناعية المقدّرة (Budget)', Icons.account_balance_wallet),
    _numField(_actual, 'التكلفة الصناعية الفعلية', Icons.payments),
    _sectionTitle('المعدّلات'),
    _numField(_stdRate, 'معدّل التحميل المعياري بالساعة', Icons.percent),
    _numField(_stdHours, 'الساعات المعيارية لكل وحدة', Icons.hourglass_bottom),
    _numField(_actHours, 'الساعات الفعلية', Icons.schedule),
    _numField(_output, 'وحدات الإنتاج', Icons.widgets),
    if (_error != null) Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6)),
      child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
    ),
    const SizedBox(height: 8),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _analyze,
      icon: _loading ? const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.analytics),
      label: const Text('حلّل انحراف الصناعية'))),
  ]);

  Widget _results() {
    if (_result == null) return _placeholder(Icons.factory,
      'أدخل الميزانية والفعلي لحساب انحراف التكاليف الصناعية');
    final d = _result!;
    final totalLabel = d['total_label'] as String? ?? 'none';
    final color = _labelColor(totalLabel);
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
          Text('إجمالي انحراف الصناعية', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_variance']} ${d['currency']}',
            style: TextStyle(color: color, fontSize: 28,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text(_labelAr(totalLabel), style: TextStyle(color: color,
            fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 12),
      _varianceCard('انحراف الإنفاق', '${d['spending_variance']}', d['spending_label']),
      const SizedBox(height: 8),
      _varianceCard('انحراف الحجم', '${d['volume_variance']}', d['volume_label']),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('تكلفة مُحمَّلة معيارياً', '${d['applied_overhead']} ${d['currency']}'),
          _kv('الساعات المسموح بها', '${d['std_hours_allowed']}'),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _warningsCard(warnings),
      ],
    ]);
  }
}
