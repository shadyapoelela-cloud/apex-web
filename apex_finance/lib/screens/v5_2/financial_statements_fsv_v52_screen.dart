/// V5.2 — Financial Statements with FSV Switcher (SAP pattern).
///
/// Same GL balances, 4 different reclassification presentations:
/// IFRS (international), SOCPA (Saudi local), Management (internal), Tax (ZATCA).
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class FinancialStatementsFsvV52Screen extends StatefulWidget {
  const FinancialStatementsFsvV52Screen({super.key});

  @override
  State<FinancialStatementsFsvV52Screen> createState() => _FinancialStatementsFsvV52ScreenState();
}

class _FinancialStatementsFsvV52ScreenState extends State<FinancialStatementsFsvV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _fsv = 'ifrs';
  String _statement = 'bs';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(children: [
          _header(),
          _fsvSelector(),
          _statementTabs(),
          const Divider(height: 1),
          Expanded(child: Container(padding: const EdgeInsets.all(24), child: _renderStatement())),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.insert_chart, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('القوائم المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('Q1 2026 · 4 إصدارات FSV من نفس الميزان (SAP pattern)', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.compare, size: 16), label: Text('مقارنة إصدارات')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 16), label: Text('تصدير PDF')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.check_circle, size: 16), label: Text('تفعيل')),
      ]),
    );
  }

  Widget _fsvSelector() {
    final fsvs = [
      ('ifrs', 'IFRS', 'المعايير الدولية', '🌍', core_theme.AC.info),
      ('socpa', 'SOCPA', 'الهيئة السعودية', '🇸🇦', core_theme.AC.ok),
      ('mgmt', 'Management', 'إدارية (للمجلس)', '💼', core_theme.AC.gold),
      ('tax', 'Tax/ZATCA', 'ضريبية', '📋', core_theme.AC.purple),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('إصدار القائمة (FSV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text('Financial Statement Version', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _gold))),
        ]),
        const SizedBox(height: 8),
        Row(children: fsvs.map((f) {
          final selected = f.$1 == _fsv;
          return Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: InkWell(
            onTap: () => setState(() => _fsv = f.$1),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? f.$5.withOpacity(0.10) : core_theme.AC.navy3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? f.$5 : core_theme.AC.bdr, width: selected ? 2 : 1),
              ),
              child: Row(children: [
                Text(f.$4, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? _navy : core_theme.AC.tp)),
                  Text(f.$3, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                ])),
                if (selected) Icon(Icons.check_circle, color: f.$5, size: 18),
              ]),
            ),
          )));
        }).toList()),
      ]),
    );
  }

  Widget _statementTabs() {
    const tabs = [
      ('bs', 'الميزانية', Icons.balance),
      ('is', 'الأرباح والخسائر', Icons.trending_up),
      ('cf', 'التدفقات النقدية', Icons.water_drop),
      ('eq', 'حقوق الملكية', Icons.donut_large),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: tabs.map((t) {
        final selected = t.$1 == _statement;
        return InkWell(
          onTap: () => setState(() => _statement = t.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _gold : Colors.transparent, width: 3))),
            child: Row(children: [
              Icon(t.$3, size: 16, color: selected ? _gold : core_theme.AC.ts),
              const SizedBox(width: 6),
              Text(t.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? _navy : core_theme.AC.ts)),
            ]),
          ),
        );
      }).toList()),
    );
  }

  Widget _renderStatement() {
    final fsvName = _fsv == 'ifrs' ? 'IFRS' : _fsv == 'socpa' ? 'SOCPA' : _fsv == 'mgmt' ? 'Management' : 'Tax/ZATCA';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_fsvColor().withOpacity(0.1), _gold.withOpacity(0.06)]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _fsvColor()),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: _fsvColor(), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _fsv == 'ifrs' ? 'عرض المعايير الدولية IFRS — ترتيب السيولة (Current → Non-Current)' :
            _fsv == 'socpa' ? 'عرض الهيئة السعودية SOCPA 2017 — يشمل الاحتياطي النظامي الإلزامي 10%' :
            _fsv == 'mgmt' ? 'عرض إداري للمجلس — تجميع حسب وحدات الأعمال + KPIs تشغيلية' :
            'عرض ضريبي ZATCA — يفصل البنود الخاضعة للضريبة عن المُعفاة',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          )),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _fsvColor().withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(fsvName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _fsvColor()))),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: _statement == 'bs' ? _bs() : _statement == 'is' ? _is() : _statement == 'cf' ? _cf() : _eq()),
    ]);
  }

  Color _fsvColor() {
    switch (_fsv) {
      case 'ifrs':
        return core_theme.AC.info;
      case 'socpa':
        return core_theme.AC.ok;
      case 'mgmt':
        return core_theme.AC.gold;
      case 'tax':
        return core_theme.AC.purple;
      default:
        return _navy;
    }
  }

  Widget _bs() {
    final rows = _fsv == 'ifrs' ? _ifrsBs() : _fsv == 'socpa' ? _socpaBs() : _fsv == 'mgmt' ? _mgmtBs() : _taxBs();
    return _table(['البند', 'Q1 2026', '2025', 'التغير'], rows);
  }

  List<(String, String?, String?, String?, bool, bool)> _ifrsBs() => const [
        ('الأصول المتداولة', null, null, null, true, false),
        ('  النقدية وما في حكمها', '3,240,000', '2,890,000', '+12.1%', false, false),
        ('  الذمم التجارية', '4,580,000', '4,120,000', '+11.2%', false, false),
        ('  المخزون', '890,000', '1,140,000', '-21.9%', false, false),
        ('  مصروفات مدفوعة مقدماً', '200,000', '180,000', '+11.1%', false, false),
        ('إجمالي الأصول المتداولة', '8,910,000', '8,330,000', '+7.0%', false, true),
        ('الأصول غير المتداولة', null, null, null, true, false),
        ('  الممتلكات والمعدات (صافي)', '18,400,000', '19,200,000', '-4.2%', false, false),
        ('  الأصول غير الملموسة', '1,840,000', '1,920,000', '-4.2%', false, false),
        ('  الاستثمارات', '5,600,000', '5,600,000', '0%', false, false),
        ('إجمالي الأصول غير المتداولة', '25,840,000', '26,720,000', '-3.3%', false, true),
        ('', null, null, null, false, false),
        ('إجمالي الأصول', '34,750,000', '35,050,000', '-0.9%', false, true),
      ];

  List<(String, String?, String?, String?, bool, bool)> _socpaBs() => const [
        ('الأصول المتداولة', null, null, null, true, false),
        ('  النقدية والبنوك', '3,240,000', '2,890,000', '+12.1%', false, false),
        ('  عملاء', '4,580,000', '4,120,000', '+11.2%', false, false),
        ('  المخزون', '890,000', '1,140,000', '-21.9%', false, false),
        ('إجمالي الأصول المتداولة', '8,710,000', '8,150,000', '+6.9%', false, true),
        ('الأصول الثابتة', null, null, null, true, false),
        ('  الأصول الثابتة (صافي بعد الإهلاك)', '18,400,000', '19,200,000', '-4.2%', false, false),
        ('  الاستثمارات طويلة الأجل', '5,600,000', '5,600,000', '0%', false, false),
        ('  الأصول غير الملموسة', '1,840,000', '1,920,000', '-4.2%', false, false),
        ('إجمالي الأصول الثابتة', '25,840,000', '26,720,000', '-3.3%', false, true),
        ('', null, null, null, false, false),
        ('إجمالي الأصول', '34,550,000', '34,870,000', '-0.9%', false, true),
        ('', null, null, null, false, false),
        ('حقوق الملكية', null, null, null, true, false),
        ('  رأس المال', '10,000,000', '10,000,000', '0%', false, false),
        ('  الاحتياطي النظامي (10%)', '1,000,000', '1,000,000', '0%', false, false),
        ('  الاحتياطي الاختياري', '1,500,000', '1,500,000', '0%', false, false),
        ('  الأرباح المحتجزة', '9,850,000', '8,700,000', '+13.2%', false, false),
        ('إجمالي حقوق الملكية', '22,350,000', '21,200,000', '+5.4%', false, true),
      ];

  List<(String, String?, String?, String?, bool, bool)> _mgmtBs() => const [
        ('وحدات الأعمال', null, null, null, true, false),
        ('  التجزئة (Retail)', '15,200,000', '14,800,000', '+2.7%', false, false),
        ('  الجملة (Wholesale)', '12,400,000', '13,100,000', '-5.3%', false, false),
        ('  الخدمات (Services)', '7,150,000', '7,150,000', '0%', false, false),
        ('إجمالي Operating Assets', '34,750,000', '35,050,000', '-0.9%', false, true),
        ('', null, null, null, false, false),
        ('KPIs تشغيلية', null, null, null, true, false),
        ('  Working Capital', '3,890,000', '3,370,000', '+15.4%', false, false),
        ('  Debt/Equity', '0.65x', '0.75x', '-13.3%', false, false),
        ('  Current Ratio', '1.77x', '1.68x', '+5.4%', false, false),
      ];

  List<(String, String?, String?, String?, bool, bool)> _taxBs() => const [
        ('الأصول الخاضعة للزكاة', null, null, null, true, false),
        ('  النقدية', '3,240,000', '2,890,000', '+12.1%', false, false),
        ('  الذمم التجارية', '4,580,000', '4,120,000', '+11.2%', false, false),
        ('  المخزون', '890,000', '1,140,000', '-21.9%', false, false),
        ('  الاستثمارات', '5,600,000', '5,600,000', '0%', false, false),
        ('إجمالي الخاضع للزكاة', '14,310,000', '13,750,000', '+4.1%', false, true),
        ('', null, null, null, false, false),
        ('الأصول غير الخاضعة', null, null, null, true, false),
        ('  الأصول الثابتة', '18,400,000', '19,200,000', '-4.2%', false, false),
        ('  الأصول غير الملموسة', '1,840,000', '1,920,000', '-4.2%', false, false),
        ('إجمالي غير الخاضع', '20,240,000', '21,120,000', '-4.2%', false, true),
        ('', null, null, null, false, false),
        ('مبلغ الزكاة (2.5%)', '357,750', '343,750', '+4.1%', false, true),
      ];

  Widget _is() {
    return _table(['البند', 'Q1 2026', 'Q1 2025', 'التغير'], const [
      ('الإيرادات', null, null, null, true, false),
      ('  مبيعات المنتجات', '14,200,000', '11,800,000', '+20.3%', false, false),
      ('  إيرادات الخدمات', '4,800,000', '3,400,000', '+41.2%', false, false),
      ('إجمالي الإيرادات', '19,000,000', '15,200,000', '+25.0%', false, true),
      ('تكلفة المبيعات', '(9,000,000)', '(7,700,000)', '+16.9%', false, true),
      ('مجمل الربح', '10,000,000', '7,500,000', '+33.3%', false, true),
      ('المصروفات التشغيلية', '(3,400,000)', '(2,850,000)', '+19.3%', false, true),
      ('الربح التشغيلي', '6,600,000', '4,650,000', '+41.9%', false, true),
      ('صافي الربح', '5,562,000', '3,753,000', '+48.2%', false, true),
    ]);
  }

  Widget _cf() {
    return _table(['البند', 'Q1 2026', 'Q1 2025', 'التغير'], const [
      ('التدفق التشغيلي', '6,372,000', '4,093,000', '+55.7%', false, true),
      ('التدفق الاستثماري', '(800,000)', '(840,000)', '-4.8%', false, true),
      ('التدفق التمويلي', '(2,900,000)', '(1,800,000)', '+61.1%', false, true),
      ('صافي التغير', '2,672,000', '1,453,000', '+83.9%', false, true),
    ]);
  }

  Widget _eq() {
    return _table(['البند', 'Q1 2026', '2025', 'التغير'], const [
      ('رأس المال', '10,000,000', '10,000,000', '0%', false, true),
      ('الاحتياطي النظامي', '2,500,000', '2,500,000', '0%', false, true),
      ('الأرباح المحتجزة', '9,850,000', '6,097,000', '+61.6%', false, true),
    ]);
  }

  Widget _table(List<String> headers, List<(String, String?, String?, String?, bool, bool)> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), color: _navy, child: Row(children: [
          Expanded(flex: 3, child: Text(headers[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
          Expanded(child: Text(headers[1], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          Expanded(child: Text(headers[2], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          Expanded(child: Text(headers[3], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
        ])),
        Expanded(child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            if (r.$1.isEmpty) return const SizedBox(height: 10);
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: r.$5 ? 10 : 6),
              decoration: BoxDecoration(
                color: r.$5 ? core_theme.AC.navy3 : (r.$6 ? _gold.withOpacity(0.05) : null),
                border: r.$6 ? Border(top: BorderSide(color: _gold, width: 1.5), bottom: BorderSide(color: _gold, width: 0.5)) : Border(bottom: BorderSide(color: core_theme.AC.navy3)),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: Text(r.$1, style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$5 || r.$6 ? FontWeight.w800 : FontWeight.w500, color: r.$5 || r.$6 ? _navy : core_theme.AC.tp))),
                Expanded(child: Text(r.$2 ?? '', style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$6 ? FontWeight.w800 : FontWeight.w500, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                Expanded(child: Text(r.$3 ?? '', style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$6 ? FontWeight.w800 : FontWeight.w500, fontFamily: 'monospace', color: core_theme.AC.ts), textAlign: TextAlign.end)),
                Expanded(child: Text(r.$4 ?? '', style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$6 ? FontWeight.w800 : FontWeight.w500, color: (r.$4 ?? '').contains('-') ? core_theme.AC.err : core_theme.AC.ok), textAlign: TextAlign.end)),
              ]),
            );
          },
        )),
      ]),
    );
  }
}
