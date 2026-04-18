/// APEX Wave 89 — Cap Table / Shareholders Register.
/// Route: /app/erp/finance/cap-table
///
/// Equity structure, funding rounds, vesting, and dilution.
library;

import 'package:flutter/material.dart';

class CapTableScreen extends StatefulWidget {
  const CapTableScreen({super.key});
  @override
  State<CapTableScreen> createState() => _CapTableScreenState();
}

class _CapTableScreenState extends State<CapTableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // 1,000,000 total shares fully diluted
  final _shareholders = const [
    _Shareholder('SH-001', 'المؤسسون', 'founders', 380000, 38.0, 'Common', '2015-06-15', 1.00, null, Color(0xFFD4AF37)),
    _Shareholder('SH-002', 'Gulf Capital Partners', 'vc', 145000, 14.5, 'Series A Pref', '2018-03-20', 4.50, '1x Non-participating', Colors.blue),
    _Shareholder('SH-003', 'Aramco Ventures', 'vc', 95000, 9.5, 'Series B Pref', '2020-09-12', 8.20, '1x Participating', Colors.green),
    _Shareholder('SH-004', 'STV - Saudi Technology Ventures', 'vc', 80000, 8.0, 'Series B Pref', '2020-09-12', 8.20, '1x Participating', Colors.green),
    _Shareholder('SH-005', 'Public Investment Fund', 'vc', 125000, 12.5, 'Series C Pref', '2023-11-08', 15.75, '1x Non-participating', Colors.purple),
    _Shareholder('SH-006', 'Employee Stock Option Pool', 'esop', 85000, 8.5, 'Options', '—', 4.25, null, Colors.orange),
    _Shareholder('SH-007', 'Angel Investors (Group)', 'angel', 35000, 3.5, 'Common', '2016-11-01', 1.80, null, Colors.teal),
    _Shareholder('SH-008', 'مستثمرون استراتيجيون', 'strategic', 55000, 5.5, 'Series B Pref', '2021-04-15', 9.10, '1x Participating', Colors.indigo),
  ];

  final _rounds = const [
    _FundingRound('التأسيس', '2015-06', 1.00, 380000, 'المؤسسون', 1500000, Color(0xFFD4AF37)),
    _FundingRound('Seed (Angel)', '2016-11', 1.80, 35000, 'أفراد مستثمرون', 63000, Colors.teal),
    _FundingRound('Series A', '2018-03', 4.50, 145000, 'Gulf Capital Partners', 652500, Colors.blue),
    _FundingRound('Series B', '2020-09', 8.20, 175000, 'Aramco Ventures + STV', 1435000, Colors.green),
    _FundingRound('Strategic', '2021-04', 9.10, 55000, 'مستثمرون استراتيجيون', 500500, Colors.indigo),
    _FundingRound('Series C', '2023-11', 15.75, 125000, 'Public Investment Fund', 1968750, Colors.purple),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  double get _totalShares => _shareholders.fold(0.0, (s, sh) => s + sh.shares);
  double get _currentValuation => 485_000_000;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildSummary(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 16), text: 'المساهمون'),
            Tab(icon: Icon(Icons.pie_chart, size: 16), text: 'هيكل الملكية'),
            Tab(icon: Icon(Icons.history, size: 16), text: 'جولات التمويل'),
            Tab(icon: Icon(Icons.trending_up, size: 16), text: 'تحليل التخفيف'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildShareholdersTab(),
              _buildOwnershipTab(),
              _buildRoundsTab(),
              _buildDilutionTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.donut_large, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('جدول رأس المال (Cap Table)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('هيكل الملكية · جولات التمويل · التخفيف · شروط الأفضلية · Vesting',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('القيمة الحالية', '485M ر.س', const Color(0xFFD4AF37), Icons.monetization_on),
          _kpi('إجمالي الأسهم', '${_fmt(_totalShares)}', Colors.blue, Icons.bar_chart),
          _kpi('عدد المساهمين', '${_shareholders.length}', Colors.purple, Icons.people),
          _kpi('جولات التمويل', '${_rounds.length}', Colors.green, Icons.trending_up),
          _kpi('آخر جولة', 'Series C · 15.75', Colors.teal, Icons.flag),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareholdersTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    Expanded(child: Text('المعرّف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('المساهم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الأسهم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('النسبة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الفئة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('سعر الاقتناء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('القيمة الحالية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final sh in _shareholders) _shRow(sh),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    const Expanded(flex: 3, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                    const Expanded(child: SizedBox()),
                    Expanded(child: Text(_fmt(_totalShares), style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
                    const Expanded(child: Text('100.0%', style: TextStyle(fontWeight: FontWeight.w900))),
                    const Expanded(flex: 2, child: SizedBox()),
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: Text('${_fmtM(_currentValuation)} ر.س',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shRow(_Shareholder sh) {
    final currentValue = sh.shares / _totalShares * _currentValuation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(sh.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(width: 6, height: 24, color: sh.color),
                const SizedBox(width: 8),
                Expanded(child: Text(sh.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: sh.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(_typeLabel(sh.type),
                  style: TextStyle(fontSize: 10, color: sh.color, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            ),
          ),
          Expanded(child: Text(_fmt(sh.shares.toDouble()), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text('${sh.percentage}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sh.shareClass, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                if (sh.preference != null)
                  Text(sh.preference!, style: const TextStyle(fontSize: 9, color: Colors.black54)),
              ],
            ),
          ),
          Expanded(child: Text('${sh.pricePerShare} ر.س', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(
            child: Text(_fmtM(currentValue),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnershipTab() {
    // Group by type
    final byType = <String, double>{};
    final colorByType = <String, Color>{};
    for (final sh in _shareholders) {
      byType[sh.type] = (byType[sh.type] ?? 0) + sh.percentage;
      colorByType[sh.type] = sh.color;
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('التوزيع حسب نوع المساهم',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              // Stacked bar
              Container(
                height: 60,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      for (final entry in byType.entries)
                        Flexible(
                          flex: (entry.value * 10).round(),
                          child: Container(
                            color: colorByType[entry.key],
                            child: Center(
                              child: Text(
                                entry.value >= 5 ? '${entry.value.toStringAsFixed(0)}%' : '',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              for (final entry in byType.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: colorByType[entry.key], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: Text(_typeLabel(entry.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                      Expanded(flex: 4, child: LinearProgressIndicator(
                        value: entry.value / 100,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(colorByType[entry.key] ?? Colors.grey),
                        minHeight: 10,
                      )),
                      const SizedBox(width: 10),
                      Text('${entry.value.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colorByType[entry.key])),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('ملاحظات هيكل الملكية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              _note('المؤسسون لا يزالون يمتلكون 38% — تحكّم قوي بالتصويت'),
              _note('مجموع حصة الصناديق الحكومية (PIF + Aramco) = 22% — تأثير استراتيجي'),
              _note('ESOP مخصّص للموظفين 8.5% — ضمن الحدود الطبيعية للصناعة'),
              _note('Series C عند 15.75 ر.س/سهم — القيمة 10.5x عن Seed'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.6))),
        ],
      ),
    );
  }

  Widget _buildRoundsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (var i = 0; i < _rounds.length; i++) _roundCard(_rounds[i], i),
      ],
    );
  }

  Widget _roundCard(_FundingRound r, int index) {
    final prev = index > 0 ? _rounds[index - 1] : null;
    final multiplier = prev != null ? r.pricePerShare / prev.pricePerShare : 1.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: r.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(color: r.color, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                Text(r.date, style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace')),
                Text(r.leadInvestor, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سعر السهم', style: TextStyle(fontSize: 10, color: Colors.black54)),
                Text('${r.pricePerShare} ر.س',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: r.color, fontFamily: 'monospace')),
                if (prev != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('+${((multiplier - 1) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأسهم المُصدرة', style: TextStyle(fontSize: 10, color: Colors.black54)),
                Text(_fmt(r.sharesIssued.toDouble()),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('إجمالي الجولة', style: TextStyle(fontSize: 10, color: Colors.black54)),
                Text('${_fmtM(r.amount.toDouble())} ر.س',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDilutionTab() {
    final scenarios = const [
      _DilutionScenario('الوضع الحالي', 0, 0, 100),
      _DilutionScenario('Series D مقترح (+20M ر.س)', 22.5, 1000000, 81.8),
      _DilutionScenario('IPO مقترح (+100M ر.س)', 30.0, 3500000, 71.4),
      _DilutionScenario('زيادة ESOP (+5%)', 15.75, 500000, 95.0),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سيناريوهات التخفيف تعرض أثر الجولات المستقبلية على نسب ملكية المساهمين الحاليين.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in scenarios) _scenarioCard(s),
      ],
    );
  }

  Widget _scenarioCard(_DilutionScenario s) {
    final color = s.retention >= 95 ? Colors.green : s.retention >= 80 ? Colors.orange : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('احتفاظ ${s.retention.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (s.pricePerShare > 0) ...[
            Row(
              children: [
                _metric('سعر السهم الجديد', '${s.pricePerShare} ر.س', Colors.blue),
                _metric('أسهم جديدة', _fmt(s.newShares), Colors.purple),
                _metric('إجمالي الأسهم بعد', _fmt(_totalShares + s.newShares), Colors.teal),
                _metric('القيمة بعد الجولة', '${_fmtM(_currentValuation + s.newShares * s.pricePerShare)} ر.س', Colors.green),
              ],
            ),
            const SizedBox(height: 14),
            const Text('أثر التخفيف على المساهمين الحاليين:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
            const SizedBox(height: 10),
            for (final sh in _shareholders.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(width: 6, height: 16, color: sh.color),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: Text(sh.name, style: const TextStyle(fontSize: 11))),
                    Text('${sh.percentage}%',
                        style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, size: 11, color: Colors.black45),
                    ),
                    Text('${(sh.percentage * s.retention / 100).toStringAsFixed(2)}%',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFD4AF37), fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Text('(${((sh.percentage * s.retention / 100) - sh.percentage).toStringAsFixed(2)}pp)',
                        style: const TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ),
              ),
          ] else
            const Text('الوضع الحالي — لا تغيير',
                style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'founders':
        return 'مؤسسون';
      case 'vc':
        return 'استثمار جريء';
      case 'angel':
        return 'مستثمر ملائكي';
      case 'esop':
        return 'موظفون';
      case 'strategic':
        return 'استراتيجي';
      default:
        return t;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Shareholder {
  final String id;
  final String name;
  final String type;
  final int shares;
  final double percentage;
  final String shareClass;
  final String acquiredAt;
  final double pricePerShare;
  final String? preference;
  final Color color;
  const _Shareholder(this.id, this.name, this.type, this.shares, this.percentage, this.shareClass, this.acquiredAt, this.pricePerShare, this.preference, this.color);
}

class _FundingRound {
  final String name;
  final String date;
  final double pricePerShare;
  final int sharesIssued;
  final String leadInvestor;
  final int amount;
  final Color color;
  const _FundingRound(this.name, this.date, this.pricePerShare, this.sharesIssued, this.leadInvestor, this.amount, this.color);
}

class _DilutionScenario {
  final String name;
  final double pricePerShare;
  final double newShares;
  final double retention;
  const _DilutionScenario(this.name, this.pricePerShare, this.newShares, this.retention);
}
