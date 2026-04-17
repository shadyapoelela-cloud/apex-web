/// APEX Platform — IFRS Tools Suite
/// ═══════════════════════════════════════════════════════════════
/// 5 IFRS tools in one screen:
///   • Revenue (IFRS 15)
///   • EOSB (IAS 19)
///   • Impairment (IAS 36)
///   • ECL (IFRS 9)
///   • Provisions (IAS 37)
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class IfrsToolsScreen extends StatefulWidget {
  const IfrsToolsScreen({super.key});
  @override
  State<IfrsToolsScreen> createState() => _IfrsToolsScreenState();
}

class _IfrsToolsScreenState extends State<IfrsToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
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
      title: Text('أدوات IFRS', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2,
      bottom: TabBar(
        controller: _tab,
        isScrollable: true,
        indicatorColor: AC.gold,
        labelColor: AC.gold,
        unselectedLabelColor: AC.ts,
        tabs: const [
          Tab(icon: Icon(Icons.point_of_sale), text: 'الإيرادات (15)'),
          Tab(icon: Icon(Icons.badge_outlined), text: 'نهاية الخدمة (19)'),
          Tab(icon: Icon(Icons.heart_broken), text: 'الانخفاض (36)'),
          Tab(icon: Icon(Icons.credit_score), text: 'ECL (9)'),
          Tab(icon: Icon(Icons.gavel_outlined), text: 'المخصصات (37)'),
        ],
      ),
    ),
    body: TabBarView(controller: _tab, children: const [
      _RevenueTab(),
      _EosbTab(),
      _ImpairmentTab(),
      _EclTab(),
      _ProvisionsTab(),
    ]),
  );
}

// Shared helpers
Widget _numField(TextEditingController c, String label, IconData icon) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
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

Widget _strField(TextEditingController c, String label, IconData icon) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(
    controller: c,
    style: TextStyle(color: AC.tp),
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

Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: TextStyle(color: AC.ts, fontSize: 12)),
    Text(v, style: TextStyle(color: vc ?? AC.tp,
      fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      fontFamily: 'monospace')),
  ]),
);

Widget _warnings(List ws) {
  if (ws.isEmpty) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
      border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: ws.map((w) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text('• $w', style: TextStyle(color: AC.warn, fontSize: 12, height: 1.5)),
      )).toList(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// Tab 1 — Revenue
// ═══════════════════════════════════════════════════════════════

class _RevenueTab extends StatefulWidget {
  const _RevenueTab();
  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  final _contract = TextEditingController(text: 'C-2026-001');
  final _customer = TextEditingController(text: 'شركة ألفا');
  final _price = TextEditingController(text: '10000');
  final _variable = TextEditingController(text: '0');
  final _months = TextEditingController(text: '6');
  final _ssp1 = TextEditingController(text: '6000');
  final _ssp2 = TextEditingController(text: '4000');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _contract.dispose(); _customer.dispose();
    _price.dispose(); _variable.dispose(); _months.dispose();
    _ssp1.dispose(); _ssp2.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'contract_id': _contract.text.trim(),
        'customer': _customer.text.trim(),
        'contract_date': '2026-01-01',
        'transaction_price': _price.text.trim(),
        'variable_consideration': _variable.text.trim(),
        'months_elapsed': int.tryParse(_months.text.trim()) ?? 0,
        'obligations': [
          {
            'description': 'منتج (تسليم فوري)',
            'standalone_selling_price': _ssp1.text.trim(),
            'recognition_pattern': 'point_in_time',
            'satisfied': true,
          },
          {
            'description': 'خدمة صيانة 12 شهر',
            'standalone_selling_price': _ssp2.text.trim(),
            'recognition_pattern': 'over_time',
            'period_months': 12,
          },
        ],
      };
      final r = await ApiService.revenueRecognise(body);
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _strField(_contract, 'رقم العقد', Icons.description),
      _strField(_customer, 'العميل', Icons.person),
      _numField(_price, 'قيمة المعاملة', Icons.attach_money),
      _numField(_variable, 'اعتبار متغير (خصم/حوافز)', Icons.trending_down),
      _numField(_months, 'الأشهر المنقضية', Icons.schedule),
      _numField(_ssp1, 'SSP التزام 1 (منتج)', Icons.shopping_bag),
      _numField(_ssp2, 'SSP التزام 2 (خدمة 12ش)', Icons.build),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome),
        label: const Text('احسب الاعتراف بالإيراد'))),
      if (_result != null) ..._renderResult(_result!),
    ]),
  );

  List<Widget> _renderResult(Map d) {
    final obs = (d['obligations'] ?? []) as List;
    return [
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AC.ok.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text('الإيراد المعترف به', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_revenue_recognised']} ${d['currency']}',
            style: TextStyle(color: AC.ok, fontSize: 26,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text('مؤجل: ${d['total_deferred_revenue']}',
            style: TextStyle(color: AC.warn, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(children: obs.map((o) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${o['description']}', style: TextStyle(color: AC.tp,
              fontSize: 12, fontWeight: FontWeight.w700)),
            _kv('المخصص', '${o['allocated_price']}'),
            _kv('التقدم', '${o['progress_pct']}%'),
            _kv('معترف به', '${o['revenue_recognised']}', vc: AC.ok),
          ]),
        )).toList()),
      ),
      _warnings((d['warnings'] ?? []) as List),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 2 — EOSB
// ═══════════════════════════════════════════════════════════════

class _EosbTab extends StatefulWidget {
  const _EosbTab();
  @override
  State<_EosbTab> createState() => _EosbTabState();
}

class _EosbTabState extends State<_EosbTab> {
  final _name = TextEditingController(text: 'محمد أحمد');
  final _id = TextEditingController(text: 'EMP-001');
  final _basic = TextEditingController(text: '10000');
  final _allow = TextEditingController(text: '2000');
  final _years = TextEditingController(text: '7');
  String _reason = 'employer_terminated';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _reasons = const {
    'employer_terminated': 'فصل من صاحب العمل',
    'resignation': 'استقالة',
    'retirement': 'تقاعد',
    'death_disability': 'وفاة/عجز',
    'contract_end': 'انتهاء عقد',
  };

  @override
  void dispose() {
    _name.dispose(); _id.dispose();
    _basic.dispose(); _allow.dispose(); _years.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'employee_name': _name.text.trim(),
        'employee_id': _id.text.trim(),
        'monthly_basic_salary': _basic.text.trim(),
        'monthly_allowances': _allow.text.trim(),
        'years_of_service': _years.text.trim(),
        'termination_reason': _reason,
      };
      final r = await ApiService.eosbCompute(body);
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _strField(_name, 'اسم الموظف', Icons.person),
      _strField(_id, 'الرقم الوظيفي', Icons.badge),
      _numField(_basic, 'الراتب الأساسي', Icons.attach_money),
      _numField(_allow, 'البدلات', Icons.card_giftcard),
      _numField(_years, 'سنوات الخدمة', Icons.schedule),
      DropdownButtonFormField<String>(
        value: _reason,
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp),
        decoration: InputDecoration(
          labelText: 'سبب انتهاء العلاقة',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        ),
        items: _reasons.entries.map((e) =>
          DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => _reason = v!),
      ),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.calculate),
        label: const Text('احسب مكافأة نهاية الخدمة'))),
      if (_result != null) ..._renderResult(_result!),
    ]),
  );

  List<Widget> _renderResult(Map d) => [
    const SizedBox(height: 14),
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
        Text('صافي المكافأة المستحقة', style: TextStyle(color: AC.ts, fontSize: 12)),
        Text('${d['net_gratuity']} ${d['currency']}',
          style: TextStyle(color: AC.gold, fontSize: 26,
            fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Text('${d['termination_factor_pct']}% من المكافأة الخام',
          style: TextStyle(color: AC.ts, fontSize: 11)),
      ]),
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
      child: Column(children: [
        _kv('الأجر الشهري للحساب', '${d['monthly_wage_for_calc']}'),
        _kv('سنوات الخدمة', '${d['years_of_service']}'),
        _kv('أول 5 سنوات', '${d['first_5_years_portion']}'),
        _kv('بعد 5 سنوات', '${d['after_5_years_portion']}'),
        _kv('المكافأة الخام', '${d['raw_gratuity']}', bold: true),
      ]),
    ),
    _warnings((d['warnings'] ?? []) as List),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Tab 3 — Impairment
// ═══════════════════════════════════════════════════════════════

class _ImpairmentTab extends StatefulWidget {
  const _ImpairmentTab();
  @override
  State<_ImpairmentTab> createState() => _ImpairmentTabState();
}

class _ImpairmentTabState extends State<_ImpairmentTab> {
  final _name = TextEditingController(text: 'خط إنتاج');
  String _class = 'ppe';
  final _ca = TextEditingController(text: '1000000');
  final _fv = TextEditingController(text: '700000');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() { _name.dispose(); _ca.dispose(); _fv.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'asset_name': _name.text.trim(),
        'asset_class': _class,
        'carrying_amount': _ca.text.trim(),
        'fair_value_less_costs_to_sell': _fv.text.trim(),
      };
      final r = await ApiService.impairmentTest(body);
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _strField(_name, 'اسم الأصل', Icons.precision_manufacturing),
      DropdownButtonFormField<String>(
        value: _class,
        dropdownColor: AC.navy2,
        style: TextStyle(color: AC.tp),
        decoration: InputDecoration(
          labelText: 'فئة الأصل',
          labelStyle: TextStyle(color: AC.ts, fontSize: 12),
          filled: true, fillColor: AC.navy3, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        ),
        items: const [
          DropdownMenuItem(value: 'ppe', child: Text('ممتلكات ومعدات')),
          DropdownMenuItem(value: 'intangible', child: Text('أصول غير ملموسة')),
          DropdownMenuItem(value: 'goodwill', child: Text('شهرة')),
          DropdownMenuItem(value: 'cgu', child: Text('وحدة توليد نقدية')),
        ],
        onChanged: (v) => setState(() => _class = v!),
      ),
      const SizedBox(height: 12),
      _numField(_ca, 'القيمة الدفترية', Icons.account_balance_wallet),
      _numField(_fv, 'القيمة العادلة ناقصاً تكاليف البيع', Icons.sell),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.heart_broken),
        label: const Text('اختبر انخفاض القيمة'))),
      if (_result != null) ..._renderResult(_result!),
    ]),
  );

  List<Widget> _renderResult(Map d) {
    final impaired = d['is_impaired'] == true;
    final color = impaired ? AC.err : AC.ok;
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
          Icon(impaired ? Icons.warning : Icons.verified, color: color, size: 28),
          const SizedBox(height: 4),
          Text(impaired ? 'يوجد انخفاض في القيمة' : 'لا انخفاض',
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          if (impaired) Text('${d['impairment_loss']} ${d['currency']}',
            style: TextStyle(color: color, fontSize: 22,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(children: [
          _kv('القيمة الدفترية', '${d['carrying_amount']}'),
          _kv('القيمة العادلة', '${d['fair_value_less_costs']}'),
          _kv('القيمة من الاستخدام', '${d['value_in_use']}'),
          _kv('قيمة الاسترداد', '${d['recoverable_amount']}', bold: true),
          _kv('القيمة الدفترية بعد الانخفاض', '${d['post_impairment_ca']}'),
        ]),
      ),
      _warnings((d['warnings'] ?? []) as List),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 4 — ECL
// ═══════════════════════════════════════════════════════════════

class _EclTab extends StatefulWidget {
  const _EclTab();
  @override
  State<_EclTab> createState() => _EclTabState();
}

class _EclTabState extends State<_EclTab> {
  final _entity = TextEditingController(text: 'شركة');
  final _period = TextEditingController(text: 'Q1 2026');
  final _current = TextEditingController(text: '500000');
  final _30_60 = TextEditingController(text: '200000');
  final _60_90 = TextEditingController(text: '100000');
  final _90_180 = TextEditingController(text: '50000');
  final _180_365 = TextEditingController(text: '30000');
  final _over_365 = TextEditingController(text: '20000');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _entity.dispose(); _period.dispose();
    _current.dispose(); _30_60.dispose(); _60_90.dispose();
    _90_180.dispose(); _180_365.dispose(); _over_365.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'entity_name': _entity.text.trim(),
        'period_label': _period.text.trim(),
        'buckets': [
          {'bucket': 'current',  'exposure': _current.text.trim()},
          {'bucket': '30_60',    'exposure': _30_60.text.trim()},
          {'bucket': '61_90',    'exposure': _60_90.text.trim()},
          {'bucket': '91_180',   'exposure': _90_180.text.trim()},
          {'bucket': '181_365',  'exposure': _180_365.text.trim()},
          {'bucket': 'over_365', 'exposure': _over_365.text.trim()},
        ],
      };
      final r = await ApiService.eclCompute(body);
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _strField(_entity, 'المنشأة', Icons.business)),
        const SizedBox(width: 8),
        Expanded(child: _strField(_period, 'الفترة', Icons.date_range)),
      ]),
      _numField(_current, 'جارية (0-30 يوم)', Icons.check_circle),
      _numField(_30_60, '31-60 يوم', Icons.warning),
      _numField(_60_90, '61-90 يوم', Icons.warning_amber),
      _numField(_90_180, '91-180 يوم', Icons.error),
      _numField(_180_365, '181-365 يوم', Icons.error_outline),
      _numField(_over_365, '>365 يوم', Icons.cancel),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.credit_score),
        label: const Text('احسب ECL'))),
      if (_result != null) ..._renderResult(_result!),
    ]),
  );

  List<Widget> _renderResult(Map d) {
    final buckets = (d['buckets'] ?? []) as List;
    return [
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AC.err.withValues(alpha: 0.14), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.err.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text('إجمالي ECL', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${d['total_ecl']} ${d['currency']}',
            style: TextStyle(color: AC.err, fontSize: 26,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          Text('${d['overall_coverage_pct']}% من التعرض',
            style: TextStyle(color: AC.ts, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AC.navy2,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.bdr)),
        child: Column(children: buckets.map<Widget>((b) => _kv(
          '${b['bucket']} (PD ${b['pd_pct']}%)',
          '${b['ecl_amount']}',
          vc: AC.err,
        )).toList()),
      ),
      _warnings((d['warnings'] ?? []) as List),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 5 — Provisions
// ═══════════════════════════════════════════════════════════════

class _ProvisionsTab extends StatefulWidget {
  const _ProvisionsTab();
  @override
  State<_ProvisionsTab> createState() => _ProvisionsTabState();
}

class _ProvisionsTabState extends State<_ProvisionsTab> {
  final _desc = TextEditingController(text: 'نزاع قضائي');
  final _est = TextEditingController(text: '500000');
  final _years = TextEditingController(text: '2');
  String _type = 'liability';
  String _prob = 'probable';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _probAr = const {
    'virtually_certain': 'شبه مؤكد',
    'probable': 'مرجّح (>50%)',
    'possible': 'محتمل (<50%)',
    'remote': 'ضئيل',
  };

  @override
  void dispose() { _desc.dispose(); _est.dispose(); _years.dispose(); super.dispose(); }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = {
        'entity_name': 'Co',
        'period_label': 'Q1 2026',
        'items': [{
          'description': _desc.text.trim(),
          'item_type': _type,
          'probability': _prob,
          'best_estimate': _est.text.trim(),
          'years_to_settlement': _years.text.trim(),
          'discount_rate_pct': '5',
        }],
      };
      final r = await ApiService.provisionsClassify(body);
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _strField(_desc, 'الوصف', Icons.gavel),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _type,
          dropdownColor: AC.navy2,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'النوع',
            labelStyle: TextStyle(color: AC.ts, fontSize: 12),
            filled: true, fillColor: AC.navy3, isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          ),
          items: const [
            DropdownMenuItem(value: 'liability', child: Text('التزام')),
            DropdownMenuItem(value: 'asset', child: Text('أصل')),
          ],
          onChanged: (v) => setState(() => _type = v!),
        )),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(
          value: _prob,
          dropdownColor: AC.navy2,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'الاحتمالية',
            labelStyle: TextStyle(color: AC.ts, fontSize: 12),
            filled: true, fillColor: AC.navy3, isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          ),
          items: _probAr.entries.map((e) =>
            DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _prob = v!),
        )),
      ]),
      const SizedBox(height: 10),
      _numField(_est, 'أفضل تقدير', Icons.attach_money),
      _numField(_years, 'سنوات التسوية', Icons.schedule),
      if (_error != null) Text(_error!, style: TextStyle(color: AC.err)),
      SizedBox(height: 50, child: ElevatedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading ? const SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.rule),
        label: const Text('صنّف وفق IAS 37'))),
      if (_result != null) ..._renderResult(_result!),
    ]),
  );

  List<Widget> _renderResult(Map d) {
    final items = (d['items'] ?? []) as List;
    return [
      const SizedBox(height: 14),
      ...items.map((it) {
        final cls = it['classification'] as String;
        final color = cls == 'provision' ? AC.ok
          : (cls == 'ignore' ? AC.ts : AC.warn);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${it['description']}',
              style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('التصنيف: ${it['classification']}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            _kv('التقدير الحالي', '${it['best_estimate']}'),
            _kv('PV بعد الخصم', '${it['discounted_estimate']}'),
            _kv('يُعترف بها؟', it['recognise'] == true ? 'نعم' : 'لا'),
            _kv('يُفصح عنها؟', it['disclose'] == true ? 'نعم' : 'لا'),
            const SizedBox(height: 4),
            Text(it['rationale'] ?? '',
              style: TextStyle(color: AC.ts, fontSize: 11, fontStyle: FontStyle.italic)),
          ]),
        );
      }),
      _warnings((d['warnings'] ?? []) as List),
    ];
  }
}
