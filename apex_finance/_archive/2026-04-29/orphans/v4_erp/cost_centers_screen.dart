/// APEX Wave 85 — Cost Center Analysis.
/// Route: /app/erp/finance/cost-centers
///
/// Per-department P&L with allocation and drill-down.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class CostCentersScreen extends StatefulWidget {
  const CostCentersScreen({super.key});
  @override
  State<CostCentersScreen> createState() => _CostCentersScreenState();
}

class _CostCentersScreenState extends State<CostCentersScreen> {
  String _period = 'Q1-2026';
  String _view = 'summary';
  _CostCenter? _selectedCenter;

  final _centers = [
    _CostCenter('CC-100', 'المبيعات', 'Sales', 6_200_000, 3_800_000, 18, Color(0xFF1A237E)),
    _CostCenter('CC-200', 'التسويق', 'Marketing', 1_200_000, 1_420_000, 8, core_theme.AC.purple),
    _CostCenter('CC-300', 'الإنتاج', 'Production', 3_800_000, 2_250_000, 42, core_theme.AC.warn),
    _CostCenter('CC-400', 'البحث والتطوير', 'R&D', 0, 2_100_000, 22, Color(0xFF4A148C)),
    _CostCenter('CC-500', 'تقنية المعلومات', 'IT', 0, 1_280_000, 18, core_theme.AC.info),
    _CostCenter('CC-600', 'المالية', 'Finance', 0, 890_000, 12, core_theme.AC.gold),
    _CostCenter('CC-700', 'الموارد البشرية', 'HR', 0, 620_000, 8, core_theme.AC.info),
    _CostCenter('CC-800', 'خدمة العملاء', 'Customer Service', 1_850_000, 980_000, 15, core_theme.AC.ok),
    _CostCenter('CC-900', 'القانونية والامتثال', 'Legal', 0, 540_000, 5, core_theme.AC.purple),
    _CostCenter('CC-950', 'الإدارة العليا', 'Executive', 0, 1_250_000, 6, core_theme.AC.err),
  ];

  final _lineItems = const [
    _LineItem('رواتب ومزايا', 480000, 'staff'),
    _LineItem('إيجار مكاتب', 125000, 'occupancy'),
    _LineItem('معدات وأثاث', 45000, 'capex'),
    _LineItem('مصاريف سفر', 38000, 'travel'),
    _LineItem('تدريب وتطوير', 22000, 'training'),
    _LineItem('برامج واشتراكات', 65000, 'software'),
    _LineItem('اتصالات وإنترنت', 18000, 'utilities'),
    _LineItem('قرطاسية وطباعة', 12000, 'supplies'),
    _LineItem('استشارات خارجية', 85000, 'services'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        _buildTotals(),
        const SizedBox(height: 16),
        _buildViewSwitch(),
        const SizedBox(height: 16),
        if (_view == 'summary') _buildSummaryView()
        else if (_view == 'matrix') _buildMatrixView()
        else _buildProfitability(),
        if (_selectedCenter != null) ...[
          const SizedBox(height: 16),
          _buildDrillDown(),
        ],
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF006064), Color(0xFF00897B)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.pie_chart, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تحليل مراكز التكلفة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Cost Center Analysis — ربحية كل قسم، توزيع المصروفات، ضوابط الموازنة',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: const Color(0xFF006064),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'Q1-2026', child: Text('الربع الأول 2026')),
                DropdownMenuItem(value: 'Q4-2025', child: Text('الربع الرابع 2025')),
                DropdownMenuItem(value: 'YTD-2026', child: Text('منذ بداية 2026')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final totalRevenue = _centers.fold(0.0, (s, c) => s + c.revenue);
    final totalCost = _centers.fold(0.0, (s, c) => s + c.cost);
    final totalHC = _centers.fold(0, (s, c) => s + c.headcount);
    final directCenters = _centers.where((c) => c.revenue > 0).length;
    return Row(
      children: [
        _kpi('إجمالي الإيرادات', _fmtM(totalRevenue), core_theme.AC.gold, Icons.trending_up),
        _kpi('إجمالي التكاليف', _fmtM(totalCost), core_theme.AC.warn, Icons.trending_down),
        _kpi('صافي الربح', _fmtM(totalRevenue - totalCost), core_theme.AC.ok, Icons.savings),
        _kpi('مراكز مباشرة', '$directCenters / ${_centers.length}', core_theme.AC.info, Icons.hub),
        _kpi('إجمالي الموظفين', '$totalHC', core_theme.AC.info, Icons.people),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitch() {
    return Row(
      children: [
        _viewBtn('summary', 'ملخّص', Icons.list),
        const SizedBox(width: 8),
        _viewBtn('matrix', 'مصفوفة', Icons.grid_view),
        const SizedBox(width: 8),
        _viewBtn('profitability', 'الربحية', Icons.analytics),
      ],
    );
  }

  Widget _viewBtn(String id, String label, IconData icon) {
    final selected = _view == id;
    return InkWell(
      onTap: () => setState(() => _view = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF006064) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF006064) : core_theme.AC.td),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : core_theme.AC.tp)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    return Container(
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
                Expanded(child: Text('الرقم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('المركز', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('الموظفون', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('الإيرادات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('التكلفة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('الربح/الخسارة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('الهامش', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                SizedBox(width: 80),
              ],
            ),
          ),
          for (final c in _centers) _summaryRow(c),
        ],
      ),
    );
  }

  Widget _summaryRow(_CostCenter c) {
    final profit = c.revenue - c.cost;
    final margin = c.revenue > 0 ? profit / c.revenue * 100 : 0.0;
    final isDirect = c.revenue > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
        color: _selectedCenter?.id == c.id ? const Color(0xFF006064).withValues(alpha: 0.05) : null,
      ),
      child: Row(
        children: [
          Expanded(child: Text(c.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(width: 6, height: 24, color: c.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(c.nameEn, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Text('${c.headcount}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(
            flex: 2,
            child: Text(isDirect ? _fmt(c.revenue) : '—',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.gold, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmt(c.cost),
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.warn, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text(isDirect ? _fmt(profit) : _fmt(-c.cost),
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    color: (isDirect ? profit : -c.cost) >= 0 ? core_theme.AC.ok : core_theme.AC.err)),
          ),
          Expanded(
            child: isDirect
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: (margin >= 20 ? core_theme.AC.ok : margin >= 0 ? core_theme.AC.warn : core_theme.AC.err).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('${margin.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 11,
                            color: margin >= 20 ? core_theme.AC.ok : margin >= 0 ? core_theme.AC.warn : core_theme.AC.err,
                            fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                  )
                : Text('مساند', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ),
          SizedBox(
            width: 80,
            child: OutlinedButton(
              onPressed: () => setState(() => _selectedCenter = c),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              child: Text('تفاصيل', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixView() {
    final maxCost = _centers.fold(0.0, (m, c) => c.cost > m ? c.cost : m);
    return GridView.count(
      crossAxisCount: 5,
      childAspectRatio: 1.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final c in _centers)
          InkWell(
            onTap: () => setState(() => _selectedCenter = c),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: c.cost / maxCost * 0.5 + 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.color.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.id,
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: c.color, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(_fmtM(c.cost),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  Text('${c.headcount} موظف · ${((c.cost / maxCost) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfitability() {
    final direct = _centers.where((c) => c.revenue > 0).toList();
    direct.sort((a, b) => (b.revenue - b.cost).compareTo(a.revenue - a.cost));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ترتيب مراكز التكلفة المباشرة بالربحية',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          for (final c in direct) _profitabilityBar(c, direct.first.revenue - direct.first.cost),
        ],
      ),
    );
  }

  Widget _profitabilityBar(_CostCenter c, double maxProfit) {
    final profit = c.revenue - c.cost;
    final pct = maxProfit > 0 ? (profit / maxProfit).abs().clamp(0.0, 1.0) : 0.0;
    final margin = c.revenue > 0 ? profit / c.revenue * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(c.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 30,
                  decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: profit >= 0 ? core_theme.AC.ok : core_theme.AC.err,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${_fmtM(profit)} ر.س (${margin.toStringAsFixed(1)}%)',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillDown() {
    final c = _selectedCenter!;
    final profit = c.revenue - c.cost;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.business, color: c.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.id} · ${c.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(c.nameEn, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedCenter = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _drillKpi('الإيرادات', _fmtM(c.revenue), core_theme.AC.gold),
              _drillKpi('التكلفة', _fmtM(c.cost), core_theme.AC.warn),
              _drillKpi('الربح/الخسارة', _fmtM(profit), profit >= 0 ? core_theme.AC.ok : core_theme.AC.err),
              _drillKpi('الموظفون', '${c.headcount}', core_theme.AC.info),
              _drillKpi('تكلفة/موظف', _fmtM(c.cost / c.headcount), core_theme.AC.info),
            ],
          ),
          const SizedBox(height: 20),
          Text('تفصيل مصروفات المركز', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final item in _lineItems) _lineItemRow(item, c.cost),
        ],
      ),
    );
  }

  Widget _drillKpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _lineItemRow(_LineItem item, double totalCost) {
    final pct = item.amount / totalCost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(_lineIcon(item.category), size: 16, color: core_theme.AC.ts),
          const SizedBox(width: 8),
          SizedBox(width: 140, child: Text(item.name, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: core_theme.AC.bdr,
              valueColor: AlwaysStoppedAnimation(core_theme.AC.gold),
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 10),
          Text(_fmt(item.amount.toDouble()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            child: Text('${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ),
        ],
      ),
    );
  }

  IconData _lineIcon(String c) {
    switch (c) {
      case 'staff':
        return Icons.people;
      case 'occupancy':
        return Icons.home_work;
      case 'capex':
        return Icons.chair;
      case 'travel':
        return Icons.flight;
      case 'training':
        return Icons.school;
      case 'software':
        return Icons.apps;
      case 'utilities':
        return Icons.bolt;
      case 'supplies':
        return Icons.print;
      case 'services':
        return Icons.business_center;
      default:
        return Icons.circle;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _CostCenter {
  final String id;
  final String name;
  final String nameEn;
  final double revenue;
  final double cost;
  final int headcount;
  final Color color;
  const _CostCenter(this.id, this.name, this.nameEn, this.revenue, this.cost, this.headcount, this.color);
}

class _LineItem {
  final String name;
  final int amount;
  final String category;
  const _LineItem(this.name, this.amount, this.category);
}
