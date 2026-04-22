import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 131 — Pro-Forma Financial Statements (Advisory)
class ProformaStatementsScreen extends StatefulWidget {
  const ProformaStatementsScreen({super.key});
  @override
  State<ProformaStatementsScreen> createState() => _ProformaStatementsScreenState();
}

class _ProformaStatementsScreenState extends State<ProformaStatementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'قائمة الدخل'), Tab(text: 'المركز المالي'), Tab(text: 'التدفقات النقدية'), Tab(text: 'الافتراضات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_incomeTab(), _balanceTab(), _cashflowTab(), _assumptionsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.assessment, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('القوائم المالية التقديرية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Pro-Forma Financials — توقعات 5 سنوات + تحليل الحساسية', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('سنة الأساس', '2026', Icons.calendar_today, const Color(0xFF1A237E))),
    Expanded(child: _kpi('أفق التوقع', '5 سنوات', Icons.timeline, core_theme.AC.gold)),
    Expanded(child: _kpi('CAGR مبيعات', '+18.4%', Icons.trending_up, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('IRR', '26.8%', Icons.stars, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _incomeTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _income.length, itemBuilder: (_, i) {
    final row = _income[i];
    final isBold = row.isSubtotal;
    return Card(margin: const EdgeInsets.only(bottom: 6), child: Padding(padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(flex: 3, child: Text(row.label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
        ...row.years.map((v) => Expanded(child: Text(v, textAlign: TextAlign.end,
          style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12, color: isBold ? const Color(0xFF4A148C) : core_theme.AC.tp)))),
      ]),
    ));
  });

  Widget _balanceTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _balance.length, itemBuilder: (_, i) {
    final row = _balance[i];
    final isBold = row.isSubtotal;
    return Card(margin: const EdgeInsets.only(bottom: 6), child: Padding(padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(flex: 3, child: Text(row.label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
        ...row.years.map((v) => Expanded(child: Text(v, textAlign: TextAlign.end,
          style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12, color: isBold ? const Color(0xFF1A237E) : core_theme.AC.tp)))),
      ]),
    ));
  });

  Widget _cashflowTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _cashflow.length, itemBuilder: (_, i) {
    final row = _cashflow[i];
    final isBold = row.isSubtotal;
    return Card(margin: const EdgeInsets.only(bottom: 6), child: Padding(padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(flex: 3, child: Text(row.label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
        ...row.years.map((v) => Expanded(child: Text(v, textAlign: TextAlign.end,
          style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12, color: isBold ? const Color(0xFF2E7D32) : core_theme.AC.tp)))),
      ]),
    ));
  });

  Widget _assumptionsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _assumptions.length, itemBuilder: (_, i) {
    final a = _assumptions[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
        child: Icon(a.icon, color: const Color(0xFF4A148C))),
      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(a.detail, style: const TextStyle(fontSize: 11)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: core_theme.AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Text(a.value, style: TextStyle(fontWeight: FontWeight.bold, color: core_theme.AC.gold))),
    ));
  });

  static const List<_Row> _income = [
    _Row('الإيرادات', ['12.4M', '14.7M', '17.4M', '20.6M', '24.3M'], false),
    _Row('تكلفة البضاعة', ['(6.2M)', '(7.0M)', '(8.0M)', '(9.3M)', '(10.8M)'], false),
    _Row('الربح الإجمالي', ['6.2M', '7.7M', '9.4M', '11.3M', '13.5M'], true),
    _Row('مصاريف التشغيل', ['(3.1M)', '(3.6M)', '(4.2M)', '(4.8M)', '(5.5M)'], false),
    _Row('EBITDA', ['3.1M', '4.1M', '5.2M', '6.5M', '8.0M'], true),
    _Row('الاستهلاك', ['(0.8M)', '(0.9M)', '(1.1M)', '(1.2M)', '(1.4M)'], false),
    _Row('EBIT', ['2.3M', '3.2M', '4.1M', '5.3M', '6.6M'], true),
    _Row('مصاريف التمويل', ['(0.4M)', '(0.4M)', '(0.4M)', '(0.3M)', '(0.3M)'], false),
    _Row('الضريبة الفعلية', ['(0.4M)', '(0.6M)', '(0.7M)', '(1.0M)', '(1.3M)'], false),
    _Row('صافي الربح', ['1.5M', '2.2M', '3.0M', '4.0M', '5.0M'], true),
    _Row('هامش صافي الربح', ['12.1%', '15.0%', '17.2%', '19.4%', '20.6%'], false),
  ];

  static const List<_Row> _balance = [
    _Row('نقدية ومعادلات', ['2.1M', '3.2M', '4.8M', '7.0M', '9.8M'], false),
    _Row('ذمم مدينة', ['1.2M', '1.5M', '1.8M', '2.1M', '2.4M'], false),
    _Row('مخزون', ['0.8M', '1.0M', '1.2M', '1.4M', '1.6M'], false),
    _Row('أصول ثابتة (صافي)', ['4.5M', '5.2M', '5.8M', '6.4M', '7.0M'], false),
    _Row('إجمالي الأصول', ['8.6M', '10.9M', '13.6M', '16.9M', '20.8M'], true),
    _Row('ذمم دائنة', ['0.9M', '1.1M', '1.3M', '1.5M', '1.7M'], false),
    _Row('قروض طويلة الأجل', ['3.5M', '3.2M', '2.8M', '2.4M', '2.0M'], false),
    _Row('إجمالي الالتزامات', ['4.4M', '4.3M', '4.1M', '3.9M', '3.7M'], true),
    _Row('رأس المال', ['2.5M', '2.5M', '2.5M', '2.5M', '2.5M'], false),
    _Row('أرباح مستبقاة', ['1.7M', '4.1M', '7.0M', '10.5M', '14.6M'], false),
    _Row('إجمالي حقوق الملكية', ['4.2M', '6.6M', '9.5M', '13.0M', '17.1M'], true),
  ];

  static const List<_Row> _cashflow = [
    _Row('صافي الربح', ['1.5M', '2.2M', '3.0M', '4.0M', '5.0M'], false),
    _Row('الاستهلاك (إضافة)', ['0.8M', '0.9M', '1.1M', '1.2M', '1.4M'], false),
    _Row('تغير رأس المال العامل', ['(0.2M)', '(0.3M)', '(0.4M)', '(0.5M)', '(0.6M)'], false),
    _Row('النقدية من التشغيل', ['2.1M', '2.8M', '3.7M', '4.7M', '5.8M'], true),
    _Row('استثمارات رأسمالية', ['(1.5M)', '(1.4M)', '(1.6M)', '(1.7M)', '(1.9M)'], false),
    _Row('النقدية من الاستثمار', ['(1.5M)', '(1.4M)', '(1.6M)', '(1.7M)', '(1.9M)'], true),
    _Row('سداد قروض', ['(0.3M)', '(0.3M)', '(0.4M)', '(0.4M)', '(0.4M)'], false),
    _Row('توزيعات أرباح', ['0', '0', '(0.1M)', '(0.4M)', '(0.7M)'], false),
    _Row('النقدية من التمويل', ['(0.3M)', '(0.3M)', '(0.5M)', '(0.8M)', '(1.1M)'], true),
    _Row('صافي تغير النقدية', ['0.3M', '1.1M', '1.6M', '2.2M', '2.8M'], true),
  ];

  static const List<_Assumption> _assumptions = [
    _Assumption('نمو الإيرادات', 'معدل نمو سنوي مركّب (CAGR)', '+18.4%', Icons.trending_up),
    _Assumption('هامش الربح الإجمالي', 'نسبة الربح الإجمالي من الإيرادات', '50%', Icons.percent),
    _Assumption('هامش EBITDA', 'هامش ربح التشغيل قبل الفوائد والضرائب', '25-33%', Icons.attach_money),
    _Assumption('سعر الضريبة', 'معدل الضريبة الفعلي', '15% (Zakat)', Icons.gavel),
    _Assumption('سعر الخصم (WACC)', 'التكلفة الموزونة لرأس المال', '12.5%', Icons.calculate),
    _Assumption('دوران المخزون', 'عدد مرات دوران المخزون سنوياً', '7.5x', Icons.inventory),
    _Assumption('DSO (فترة التحصيل)', 'متوسط أيام تحصيل الذمم المدينة', '36 يوم', Icons.schedule),
    _Assumption('CAPEX نسبة من الإيرادات', 'إنفاق رأسمالي سنوي', '9%', Icons.construction),
  ];
}

class _Row { final String label; final List<String> years; final bool isSubtotal;
  const _Row(this.label, this.years, this.isSubtotal); }
class _Assumption { final String name, detail, value; final IconData icon;
  const _Assumption(this.name, this.detail, this.value, this.icon); }
