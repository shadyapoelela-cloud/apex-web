/// APEX Wave 52 — Budget vs Actual.
/// Route: /app/erp/finance/budget-actual
///
/// Compare planned vs realized performance with variance
/// analysis and commentary.
library;

import 'package:flutter/material.dart';

class BudgetVsActualScreen extends StatefulWidget {
  const BudgetVsActualScreen({super.key});
  @override
  State<BudgetVsActualScreen> createState() => _BudgetVsActualScreenState();
}

class _BudgetVsActualScreenState extends State<BudgetVsActualScreen> {
  String _period = 'Q1-2026';
  String _view = 'summary';

  final _lines = <_BudgetLine>[
    _BudgetLine('4100', 'إيرادات المبيعات', 'إيرادات', 1850000, 1925000, 'revenue'),
    _BudgetLine('4200', 'إيرادات الخدمات', 'إيرادات', 420000, 395000, 'revenue'),
    _BudgetLine('4300', 'إيرادات أخرى', 'إيرادات', 45000, 52000, 'revenue'),
    _BudgetLine('5100', 'مصروف الرواتب', 'مصروفات', 620000, 648000, 'expense'),
    _BudgetLine('5200', 'مصروف الإيجار', 'مصروفات', 180000, 180000, 'expense'),
    _BudgetLine('5300', 'مصروفات تسويق', 'مصروفات', 125000, 168000, 'expense'),
    _BudgetLine('5400', 'مصروفات كهرباء وماء', 'مصروفات', 48000, 52500, 'expense'),
    _BudgetLine('5500', 'مصروفات اتصالات', 'مصروفات', 28000, 26200, 'expense'),
    _BudgetLine('5600', 'مصروفات صيانة', 'مصروفات', 85000, 96800, 'expense'),
    _BudgetLine('5700', 'مصروفات قانونية', 'مصروفات', 42000, 38500, 'expense'),
    _BudgetLine('5800', 'مصروفات سفر', 'مصروفات', 65000, 78200, 'expense'),
    _BudgetLine('5900', 'مصروفات متنوعة', 'مصروفات', 35000, 31500, 'expense'),
  ];

  double get _totalRevenueBudget => _lines.where((l) => l.nature == 'revenue').fold(0.0, (s, l) => s + l.budget);
  double get _totalRevenueActual => _lines.where((l) => l.nature == 'revenue').fold(0.0, (s, l) => s + l.actual);
  double get _totalExpenseBudget => _lines.where((l) => l.nature == 'expense').fold(0.0, (s, l) => s + l.budget);
  double get _totalExpenseActual => _lines.where((l) => l.nature == 'expense').fold(0.0, (s, l) => s + l.actual);
  double get _netIncomeBudget => _totalRevenueBudget - _totalExpenseBudget;
  double get _netIncomeActual => _totalRevenueActual - _totalExpenseActual;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        _buildKpiSummary(),
        const SizedBox(height: 16),
        _buildPeriodSelector(),
        const SizedBox(height: 16),
        _buildLinesTable(),
        const SizedBox(height: 16),
        _buildVarianceExplanation(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5E35B1), Color(0xFF7E57C2)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الموازنة مقابل الفعلي',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('تحليل الانحرافات مع تفسيرات مؤشرات الأداء',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: const Color(0xFF5E35B1),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'Q1-2026', child: Text('الربع الأول 2026')),
                DropdownMenuItem(value: 'Q4-2025', child: Text('الربع الرابع 2025')),
                DropdownMenuItem(value: 'YTD-2026', child: Text('منذ بداية 2026')),
                DropdownMenuItem(value: 'APR-2026', child: Text('أبريل 2026')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummary() {
    final netVariance = _netIncomeActual - _netIncomeBudget;
    final netPct = _netIncomeBudget != 0 ? (netVariance / _netIncomeBudget * 100) : 0;
    return Row(
      children: [
        _kpiCard(
          'الإيرادات',
          _totalRevenueActual,
          _totalRevenueBudget,
          _totalRevenueActual - _totalRevenueBudget,
          true,
          const Color(0xFFD4AF37),
        ),
        _kpiCard(
          'المصروفات',
          _totalExpenseActual,
          _totalExpenseBudget,
          _totalExpenseActual - _totalExpenseBudget,
          false,
          Colors.orange,
        ),
        _kpiCard(
          'صافي الربح',
          _netIncomeActual,
          _netIncomeBudget,
          netVariance,
          true,
          Colors.green,
          customPct: '${netPct >= 0 ? '+' : ''}${netPct.toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  Widget _kpiCard(String label, double actual, double budget, double variance, bool higherBetter, Color color, {String? customPct}) {
    final favorable = higherBetter ? variance >= 0 : variance <= 0;
    final variancePct = budget != 0 ? (variance / budget * 100) : 0;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                Icon(favorable ? Icons.trending_up : Icons.trending_down,
                    size: 18, color: favorable ? Colors.green : Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            Text(_fmt(actual), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
            Text('موازنة: ${_fmt(budget)}', style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (favorable ? Colors.green : Colors.red).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    customPct ?? '${variancePct >= 0 ? '+' : ''}${variancePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: favorable ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(favorable ? 'مفضّل' : 'غير مفضّل',
                    style: TextStyle(fontSize: 10, color: favorable ? Colors.green : Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _viewChip('summary', 'ملخّص', Icons.dashboard),
        const SizedBox(width: 8),
        _viewChip('detailed', 'تفصيلي', Icons.list),
        const SizedBox(width: 8),
        _viewChip('monthly', 'شهري', Icons.calendar_month),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download, size: 16),
          label: const Text('تصدير Excel'),
        ),
      ],
    );
  }

  Widget _viewChip(String id, String label, IconData icon) {
    final selected = _view == id;
    return InkWell(
      onTap: () => setState(() => _view = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5E35B1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF5E35B1) : Colors.black26),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.black54),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.black87,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesTable() {
    return Container(
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
                Expanded(child: Text('الحساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('الموازنة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('الفعلي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)))),
                Expanded(flex: 2, child: Text('الانحراف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 3, child: Text('التحقيق', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          for (final l in _lines) _lineRow(l),
          _totalRow('إجمالي الإيرادات', _totalRevenueBudget, _totalRevenueActual, true, Colors.green),
          _totalRow('إجمالي المصروفات', _totalExpenseBudget, _totalExpenseActual, false, Colors.orange),
          _totalRow('صافي الربح', _netIncomeBudget, _netIncomeActual, true, const Color(0xFFD4AF37), isGrand: true),
        ],
      ),
    );
  }

  Widget _lineRow(_BudgetLine l) {
    final variance = l.actual - l.budget;
    final isRevenue = l.nature == 'revenue';
    final favorable = isRevenue ? variance >= 0 : variance <= 0;
    final pct = l.budget != 0 ? (variance / l.budget * 100).abs() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(l.code, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ),
          Expanded(flex: 3, child: Text(l.name, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(_fmt(l.budget), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(
            flex: 2,
            child: Text(_fmt(l.actual), style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFD4AF37), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  favorable ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: favorable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(_fmt(variance.abs()),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: favorable ? Colors.green : Colors.red,
                    )),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (favorable ? Colors.green : Colors.red).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: favorable ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: LinearProgressIndicator(
                value: (l.actual / l.budget).clamp(0.0, 1.5),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(favorable ? Colors.green : Colors.red),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double budget, double actual, bool higherBetter, Color color, {bool isGrand = false}) {
    final variance = actual - budget;
    final favorable = higherBetter ? variance >= 0 : variance <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isGrand ? color.withOpacity(0.1) : Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: TextStyle(fontSize: isGrand ? 14 : 13, fontWeight: FontWeight.w900))),
          Expanded(flex: 2, child: Text(_fmt(budget), style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900))),
          Expanded(flex: 2, child: Text(_fmt(actual), style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900, color: color))),
          Expanded(
            flex: 2,
            child: Text(_fmt(variance.abs()),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  color: favorable ? Colors.green : Colors.red,
                )),
          ),
          const Expanded(flex: 4, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildVarianceExplanation() {
    return Container(
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
              Icon(Icons.lightbulb, color: Colors.blue),
              SizedBox(width: 8),
              Text('تفسير أهم الانحرافات',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          _insightRow(
            Icons.trending_up,
            Colors.green,
            'إيرادات المبيعات أعلى بـ 4%',
            'تجاوزنا الموازنة بسبب عقدين جديدين مع SABIC وARAMCO في فبراير. العمل الآن على تأكيد تكرار هذه العقود.',
          ),
          _insightRow(
            Icons.trending_down,
            Colors.red,
            'مصروفات التسويق أعلى بـ 34%',
            'زيادة مبالغ فيها بسبب حملة رمضان + معرض القاهرة الدولي. العائد على الاستثمار 2.8x، لكن يجب ضبط الموازنات للأرباع القادمة.',
          ),
          _insightRow(
            Icons.trending_down,
            Colors.red,
            'مصروفات السفر أعلى بـ 20%',
            'زيادة ناتجة عن زيارات ميدانية للعملاء في الخليج. نوصي بعقد اجتماعات عبر Zoom عندما يكون ممكناً.',
          ),
          _insightRow(
            Icons.trending_up,
            Colors.green,
            'مصروفات الاتصالات أقل بـ 6%',
            'الانتقال إلى باقات موحّدة مع STC للمنشأة حقّق وفرة شهرية.',
          ),
        ],
      ),
    );
  }

  Widget _insightRow(IconData icon, Color color, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(detail, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _BudgetLine {
  final String code;
  final String name;
  final String type;
  final double budget;
  final double actual;
  final String nature;
  const _BudgetLine(this.code, this.name, this.type, this.budget, this.actual, this.nature);
}
