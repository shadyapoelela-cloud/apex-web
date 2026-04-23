/// APEX Wave 88 — Investment Portfolio / Treasury Investments.
/// Route: /app/erp/treasury/investments
///
/// Fixed income, equities, funds, FX — with P&L and risk metrics.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class InvestmentPortfolioScreen extends StatefulWidget {
  const InvestmentPortfolioScreen({super.key});
  @override
  State<InvestmentPortfolioScreen> createState() => _InvestmentPortfolioScreenState();
}

class _InvestmentPortfolioScreenState extends State<InvestmentPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _holdings = [
    _Holding('ARAMCO', 'أرامكو السعودية', 'equity', 15000, 28.50, 32.15, 15.4, core_theme.AC.ok),
    _Holding('SABIC', 'سابك', 'equity', 8000, 76.40, 82.10, 2.1, core_theme.AC.ok),
    _Holding('STC', 'الاتصالات السعودية', 'equity', 12000, 38.70, 42.25, -0.8, core_theme.AC.ok),
    _Holding('SUKUK-2028', 'صكوك سعودية سيادية 2028', 'sukuk', 500, 1000, 1045, 4.2, core_theme.AC.info),
    _Holding('GOV-BONDS', 'سندات حكومية 5Y', 'bond', 400, 10000, 10185, 3.8, core_theme.AC.info),
    _Holding('RAJHI-MF', 'صندوق الراجحي للأسهم', 'fund', 1800, 485, 542, 0.5, core_theme.AC.purple),
    _Holding('RIYAD-MM', 'صندوق الرياض لأسواق المال', 'fund', 2500, 100, 104, 1.2, core_theme.AC.info),
    _Holding('USD-FXD', 'وديعة بالدولار', 'deposit', 1, 1125000, 1168125, 0, core_theme.AC.warn),
    _Holding('EUR-FXD', 'وديعة باليورو', 'deposit', 1, 820000, 832400, 0, core_theme.AC.warn),
    _Holding('ALINMA-REIT', 'صندوق الإنماء للعقارات', 'reit', 3200, 11.20, 12.85, 6.8, core_theme.AC.gold),
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

  double get _totalInvested => _holdings.fold(0.0, (s, h) => s + h.units * h.avgCost);
  double get _totalMarket => _holdings.fold(0.0, (s, h) => s + h.units * h.currentPrice);
  double get _totalGain => _totalMarket - _totalInvested;
  double get _totalReturn => _totalInvested > 0 ? _totalGain / _totalInvested * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildSummary(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.list, size: 16), text: 'الحيازات'),
            Tab(icon: Icon(Icons.pie_chart, size: 16), text: 'التخصيص'),
            Tab(icon: Icon(Icons.shield, size: 16), text: 'المخاطر'),
            Tab(icon: Icon(Icons.history, size: 16), text: 'الحركات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildHoldingsTab(),
              _buildAllocationTab(),
              _buildRiskTab(),
              _buildTransactionsTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محفظة الاستثمار',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Treasury Investments — أسهم · صكوك · سندات · صناديق · ودائع · REITs',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
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
          _summary('القيمة السوقية', _fmtM(_totalMarket), null, core_theme.AC.gold, Icons.account_balance),
          _summary('التكلفة الأصلية', _fmtM(_totalInvested), null, core_theme.AC.info, Icons.input),
          _summary('الربح/الخسارة', _fmtM(_totalGain), _totalGain >= 0, core_theme.AC.ok, Icons.trending_up),
          _summary('العائد الكلي', '${_totalReturn >= 0 ? '+' : ''}${_totalReturn.toStringAsFixed(2)}%', _totalReturn >= 0, core_theme.AC.purple, Icons.analytics),
          _summary('Yield السنوي', '5.82%', true, core_theme.AC.info, Icons.percent),
        ],
      ),
    );
  }

  Widget _summary(String label, String value, bool? positive, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Row(
                    children: [
                      if (positive != null)
                        Icon(positive ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14, color: positive ? core_theme.AC.ok : core_theme.AC.err),
                      Text(value,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: positive == null ? color : (positive ? core_theme.AC.ok : core_theme.AC.err))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingsTab() {
    final sorted = List<_Holding>.from(_holdings)..sort((a, b) {
      final vA = a.units * a.currentPrice;
      final vB = b.units * b.currentPrice;
      return vB.compareTo(vA);
    });
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: const Row(
                  children: [
                    Expanded(child: Text('الرمز', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('الأداة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الوحدات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المتوسط', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('السعر الحالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('القيمة السوقية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('ربح/خسارة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('عائد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final h in sorted) _holdingRow(h),
            ],
          ),
        ),
      ],
    );
  }

  Widget _holdingRow(_Holding h) {
    final invested = h.units * h.avgCost;
    final market = h.units * h.currentPrice;
    final gain = market - invested;
    final returnPct = invested > 0 ? gain / invested * 100 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(h.symbol, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w900))),
          Expanded(flex: 3, child: Text(h.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: h.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(_typeLabel(h.type),
                  style: TextStyle(fontSize: 10, color: h.color, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            ),
          ),
          Expanded(child: Text(_fmt(h.units.toDouble()), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(_fmt(h.avgCost), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(_fmt(h.currentPrice), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(
            child: Text(_fmtM(market),
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
          ),
          Expanded(
            child: Text(_fmtM(gain),
                style: TextStyle(
                    fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: gain >= 0 ? core_theme.AC.ok : core_theme.AC.err)),
          ),
          Expanded(
            child: Text(
              '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: returnPct >= 0 ? core_theme.AC.ok : core_theme.AC.err),
            ),
          ),
          Expanded(child: Text('${h.yield}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: core_theme.AC.purple))),
        ],
      ),
    );
  }

  Widget _buildAllocationTab() {
    final byType = <String, double>{};
    for (final h in _holdings) {
      byType[h.type] = (byType[h.type] ?? 0) + h.units * h.currentPrice;
    }
    final target = const {
      'equity': 40.0,
      'sukuk': 20.0,
      'bond': 10.0,
      'fund': 15.0,
      'deposit': 10.0,
      'reit': 5.0,
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التخصيص الحالي vs المستهدف',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              for (final entry in byType.entries) _allocationRow(entry.key, entry.value / _totalMarket * 100, target[entry.key] ?? 0),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.balance, color: core_theme.AC.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'السياسة الاستثمارية المعتمدة: 40% أسهم، 30% دخل ثابت (صكوك+سندات)، 15% صناديق، 10% ودائع، 5% عقارات. يُنصح بإعادة التوازن ربع سنوياً.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _allocationRow(String type, double actual, double target) {
    final diff = actual - target;
    final color = _typeColor(type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(_typeLabel(type), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('الحالي: ', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              Text('${actual.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: 14),
              Text('الهدف: ', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              Text('${target.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (diff.abs() < 2 ? core_theme.AC.ok : core_theme.AC.warn).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}pp',
                  style: TextStyle(
                      fontSize: 10,
                      color: diff.abs() < 2 ? core_theme.AC.ok : core_theme.AC.warn,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(height: 12, color: core_theme.AC.navy3),
              FractionallySizedBox(
                widthFactor: (actual / 100).clamp(0.0, 1.0),
                child: Container(height: 12, color: color),
              ),
              Positioned(
                left: MediaQuery.of(context).size.width * (target / 100).clamp(0.0, 1.0) * 0.5,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: core_theme.AC.tp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskTab() {
    final metrics = [
      _RiskMetric('الانحراف المعياري', '12.4%', 'قياس تذبذب المحفظة', core_theme.AC.warn),
      _RiskMetric('Sharpe Ratio', '1.82', 'أعلى من متوسط السوق (1.2)', core_theme.AC.ok),
      _RiskMetric('Max Drawdown', '-8.5%', 'أسوأ انخفاض تاريخي', core_theme.AC.err),
      _RiskMetric('Beta', '0.85', 'أقل تذبذباً من السوق', core_theme.AC.info),
      _RiskMetric('VaR (95%)', '420K ر.س', 'الخسارة القصوى المتوقّعة', core_theme.AC.purple),
      _RiskMetric('التركيز — أكبر موقف', '28.5%', 'أرامكو (الحد الأعلى 35%)', core_theme.AC.warn),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 2.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final m in metrics)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: m.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: TextStyle(fontSize: 12, color: m.color, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(m.value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: m.color)),
                    const Spacer(),
                    Text(m.description,
                        style: TextStyle(fontSize: 10, color: core_theme.AC.ts, height: 1.4)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: core_theme.AC.warn),
                  SizedBox(width: 8),
                  Text('حدود السياسة — مؤشرات المخاطر',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              _policyLimit('تعرّض الأسهم الفردية الواحدة', '< 35%', '28.5%', true),
              _policyLimit('تركيز القطاع الواحد', '< 30%', '28.2%', true),
              _policyLimit('السيولة (ودائع + أدوات قصيرة)', '> 15%', '18.3%', true),
              _policyLimit('الاستثمار المباشر في الأسهم', '< 50%', '47.8%', true),
              _policyLimit('تعرّض العملات غير الخليجية', '< 25%', '22.1%', true),
              _policyLimit('الحد الأدنى للتصنيف الائتماني (BBB)', '≥ BBB', 'A- avg', true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _policyLimit(String name, String limit, String actual, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, size: 18, color: ok ? core_theme.AC.ok : core_theme.AC.err),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(limit, style: TextStyle(fontSize: 12, color: core_theme.AC.ts, fontFamily: 'monospace'))),
          Expanded(
            child: Text(actual,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ok ? core_theme.AC.ok : core_theme.AC.err,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final txns = [
      _Txn('2026-04-18', 'ARAMCO', 'شراء', 5000, 32.15, 160750, core_theme.AC.ok),
      _Txn('2026-04-15', 'SUKUK-2028', 'استلام كوبون', 0, 0, 21000, core_theme.AC.info),
      _Txn('2026-04-10', 'SABIC', 'توزيع أرباح', 0, 0, 48000, core_theme.AC.info),
      _Txn('2026-04-05', 'RAJHI-MF', 'شراء', 500, 542, 271000, core_theme.AC.ok),
      _Txn('2026-04-02', 'STC', 'بيع', 2000, 42.25, 84500, core_theme.AC.err),
      _Txn('2026-03-28', 'USD-FXD', 'تجديد وديعة', 0, 0, 1168125, core_theme.AC.warn),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: txns.length,
      itemBuilder: (ctx, i) {
        final t = txns[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(
                  t.action == 'شراء'
                      ? Icons.add_circle
                      : t.action == 'بيع'
                          ? Icons.remove_circle
                          : Icons.attach_money,
                  color: t.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(4)),
                          child: Text(t.action,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        Text(t.symbol, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                      ],
                    ),
                    Text(t.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                  ],
                ),
              ),
              if (t.units > 0)
                Text('${t.units.toStringAsFixed(0)} × ${t.price}',
                    style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Text(_fmt(t.amount.toDouble()),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: t.color, fontFamily: 'monospace')),
              Text(' ر.س', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ],
          ),
        );
      },
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'equity':
        return core_theme.AC.ok;
      case 'sukuk':
      case 'bond':
        return core_theme.AC.info;
      case 'fund':
        return core_theme.AC.purple;
      case 'deposit':
        return core_theme.AC.warn;
      case 'reit':
        return core_theme.AC.gold;
      default:
        return core_theme.AC.td;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'equity':
        return 'أسهم';
      case 'sukuk':
        return 'صكوك';
      case 'bond':
        return 'سندات';
      case 'fund':
        return 'صناديق';
      case 'deposit':
        return 'وديعة';
      case 'reit':
        return 'REIT';
      default:
        return t;
    }
  }

  String _fmt(double v) {
    if (v == v.toInt() && v.abs() >= 100) {
      return v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return v.toStringAsFixed(2);
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Holding {
  final String symbol;
  final String name;
  final String type;
  final int units;
  final double avgCost;
  final double currentPrice;
  final double yield;
  final Color color;
  const _Holding(this.symbol, this.name, this.type, this.units, this.avgCost, this.currentPrice, this.yield, this.color);
}

class _RiskMetric {
  final String name;
  final String value;
  final String description;
  final Color color;
  const _RiskMetric(this.name, this.value, this.description, this.color);
}

class _Txn {
  final String date;
  final String symbol;
  final String action;
  final int units;
  final double price;
  final int amount;
  final Color color;
  const _Txn(this.date, this.symbol, this.action, this.units, this.price, this.amount, this.color);
}
