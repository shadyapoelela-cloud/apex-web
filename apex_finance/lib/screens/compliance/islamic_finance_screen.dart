/// APEX — Islamic Finance (Murabaha / Ijarah / Zakah)
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class IslamicFinanceScreen extends StatefulWidget {
  const IslamicFinanceScreen({super.key});
  @override
  State<IslamicFinanceScreen> createState() => _IslamicFinanceScreenState();
}

class _IslamicFinanceScreenState extends State<IslamicFinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('المنتجات الإسلامية',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.ts,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'مرابحة'),
              Tab(text: 'إجارة'),
              Tab(text: 'زكاة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [_MurabahaTab(), _IjarahTab(), _ZakahTab()],
        ),
      ),
    );
  }
}

class _MurabahaTab extends StatefulWidget {
  const _MurabahaTab();
  @override
  State<_MurabahaTab> createState() => _MurabahaTabState();
}

class _MurabahaTabState extends State<_MurabahaTab> {
  final _cost = TextEditingController(text: '100000');
  final _sell = TextEditingController(text: '120000');
  final _inst = TextEditingController(text: '24');
  final _date = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _run() async {
    setState(() => _loading = true);
    final res = await ApiService.aiMurabaha(
      costPrice: double.tryParse(_cost.text) ?? 0,
      sellingPrice: double.tryParse(_sell.text) ?? 0,
      startDate: _date.text,
      installments: int.tryParse(_inst.text) ?? 12,
    );
    if (!mounted) return;
    setState(() {
      _result = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'جدول مرابحة بطريقة Effective Yield (AAOIFI FAS 28) — الربح موزّع حسب الرصيد المتبقي، لا خط مستقيم.',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
          ),
          const SizedBox(height: 12),
          _row([
            _num(_cost, 'سعر التكلفة'),
            _num(_sell, 'سعر البيع'),
          ]),
          _row([
            _num(_inst, 'عدد الأقساط'),
            _num(_date, 'تاريخ البداية (YYYY-MM-DD)'),
          ]),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.calculate),
            label: const Text('احسب الجدول', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
          if (_loading) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
          if (_result != null) ..._murabahaResult(_result!),
        ],
      ),
    );
  }

  List<Widget> _murabahaResult(Map<String, dynamic> r) {
    final sched = (r['schedule'] as List?) ?? [];
    return [
      const SizedBox(height: 14),
      _summary([
        ('إجمالي الربح', r['total_markup']),
        ('قسط شهري', r['installment_amount']),
        ('العائد الفعلي / فترة %', r['effective_yield_per_period']),
      ]),
      const SizedBox(height: 10),
      ...sched.map((e) => _installmentRow(e as Map)),
    ];
  }

  Widget _installmentRow(Map e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('#${e['seq']}',
              style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.w700))),
          Expanded(child: Text('${e['due_date']}',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5))),
          Text('ربح ${e['profit_recognized']}',
              style: TextStyle(color: AC.ok, fontFamily: 'Tajawal', fontSize: 11)),
          const SizedBox(width: 10),
          Text('أصل ${e['principal_reduction']}',
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 11)),
        ],
      ),
    );
  }

  Widget _summary(List<(String, dynamic)> pairs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: pairs.map((p) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.$1, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
              Text('${p.$2}',
                  style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList()),
    );
  }

  Widget _num(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
        filled: true, fillColor: AC.navy3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}

class _IjarahTab extends StatelessWidget {
  const _IjarahTab();
  @override
  Widget build(BuildContext context) {
    return const _SimpleForm(
      title: 'إجارة تشغيلية (AAOIFI FAS 32)',
      subtitle: 'اعتراف دوري بالإيجار — وشيك depreciation الأصل.',
    );
  }
}

class _ZakahTab extends StatefulWidget {
  const _ZakahTab();
  @override
  State<_ZakahTab> createState() => _ZakahTabState();
}

class _ZakahTabState extends State<_ZakahTab> {
  final _ca = TextEditingController(text: '500000');
  final _inv = TextEditingController(text: '100000');
  final _fa = TextEditingController(text: '800000');
  final _int = TextEditingController(text: '50000');
  final _cl = TextEditingController(text: '200000');
  final _ltd = TextEditingController(text: '100000');
  bool _loading = false;
  Map<String, dynamic>? _result;

  Future<void> _run() async {
    setState(() => _loading = true);
    final res = await ApiService.aiZakah({
      'current_assets': double.tryParse(_ca.text) ?? 0,
      'investments_for_trade': double.tryParse(_inv.text) ?? 0,
      'fixed_assets_net': double.tryParse(_fa.text) ?? 0,
      'intangibles': double.tryParse(_int.text) ?? 0,
      'current_liabilities': double.tryParse(_cl.text) ?? 0,
      'long_term_liabilities_due_within_year': double.tryParse(_ltd.text) ?? 0,
    });
    if (!mounted) return;
    setState(() {
      _result = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      _loading = false;
    });
  }

  Widget _num(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
        filled: true, fillColor: AC.navy3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'حساب وعاء الزكاة (SOCPA) — 2.5% على صافي الأصول الزكوية بعد خصم الالتزامات قصيرة الأجل.',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
          ),
          const SizedBox(height: 12),
          _num(_ca, 'أصول متداولة'),
          const SizedBox(height: 8),
          _num(_inv, 'استثمارات للمتاجرة'),
          const SizedBox(height: 8),
          _num(_fa, 'أصول ثابتة صافية (غير زكوية — للعرض فقط)'),
          const SizedBox(height: 8),
          _num(_int, 'أصول غير ملموسة (غير زكوية)'),
          const SizedBox(height: 8),
          _num(_cl, 'التزامات متداولة'),
          const SizedBox(height: 8),
          _num(_ltd, 'الجزء المتداول من الالتزامات طويلة الأجل'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.calculate),
            label: const Text('احسب الزكاة', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
          ),
          if (_loading) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
          if (_result != null) ..._zakahResult(_result!),
        ],
      ),
    );
  }

  List<Widget> _zakahResult(Map r) => [
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.15), AC.gold.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('وعاء الزكاة', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12)),
          Text('${r['base']} SAR',
              style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('الزكاة المستحقة ${r['rate_pct']}%',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12)),
          Text('${r['zakah_payable']} SAR',
              style: TextStyle(color: AC.ok, fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
    const SizedBox(height: 10),
    Text(r['method']?.toString() ?? '',
        style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5)),
  ];
}

class _SimpleForm extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SimpleForm({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'واجهة الإجارة مفعّلة عبر /api/v1/ai/islamic/ijarah — إضافة نموذج إدخال كامل في الخطوة التالية.',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
