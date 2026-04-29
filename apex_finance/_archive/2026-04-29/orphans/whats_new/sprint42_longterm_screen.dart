/// Sprint 42 — Q3-Q4 2026 long-term roadmap features.
///
/// Three tabs:
///   1) AI Cashflow Forecasting (historical + forecast + 90% CI + runway line)
///   2) Multi-Company Consolidation (parent + subsidiaries + FX + intercompany
///      eliminations + minority interest)
///   3) Manufacturing (BOM tree with MRP feasibility and run-size planning)
library;

import 'package:flutter/material.dart';

import '../../core/apex_bom_tree.dart';
import '../../core/apex_data_table.dart';
import '../../core/apex_forecast_chart.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/theme.dart' as core_theme;

class Sprint42LongTermScreen extends StatefulWidget {
  const Sprint42LongTermScreen({super.key});

  @override
  State<Sprint42LongTermScreen> createState() =>
      _Sprint42LongTermScreenState();
}

class _Sprint42LongTermScreenState extends State<Sprint42LongTermScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(
              title: '🔮 Sprint 42: خطة Q3-Q4 2026'),
          Container(
            color: AC.navy2,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              tabs: const [
                Tab(icon: Icon(Icons.auto_graph), text: 'AI Cashflow'),
                Tab(icon: Icon(Icons.hub_outlined), text: 'توحيد متعدد الشركات'),
                Tab(icon: Icon(Icons.precision_manufacturing_outlined), text: 'التصنيع'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _AiCashflowTab(),
                _ConsolidationTab(),
                _ManufacturingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Cashflow Forecasting Tab ──────────────────────────

class _AiCashflowTab extends StatelessWidget {
  const _AiCashflowTab();

  List<ForecastPoint> get _series => const [
        // 6 months actual
        ForecastPoint(label: 'أكتوبر', value: 420000),
        ForecastPoint(label: 'نوفمبر', value: 398000),
        ForecastPoint(label: 'ديسمبر', value: 455000),
        ForecastPoint(label: 'يناير', value: 410000),
        ForecastPoint(label: 'فبراير', value: 388000),
        ForecastPoint(label: 'مارس', value: 425000),
        // 6 months forecast with widening CI
        ForecastPoint(
            label: 'أبريل',
            value: 402000,
            lower: 370000,
            upper: 434000,
            isForecast: true),
        ForecastPoint(
            label: 'مايو',
            value: 378000,
            lower: 335000,
            upper: 421000,
            isForecast: true),
        ForecastPoint(
            label: 'يونيو',
            value: 351000,
            lower: 298000,
            upper: 404000,
            isForecast: true),
        ForecastPoint(
            label: 'يوليو',
            value: 319000,
            lower: 258000,
            upper: 380000,
            isForecast: true),
        ForecastPoint(
            label: 'أغسطس',
            value: 283000,
            lower: 215000,
            upper: 351000,
            isForecast: true),
        ForecastPoint(
            label: 'سبتمبر',
            value: 245000,
            lower: 168000,
            upper: 322000,
            isForecast: true),
      ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          _kpis(),
          const SizedBox(height: AppSpacing.lg),
          ApexForecastChart(
            series: _series,
            thresholdValue: 150000,
            thresholdLabel: 'حد السيولة الأدنى',
            yLabel: 'السيولة (ر.س)',
          ),
          const SizedBox(height: AppSpacing.lg),
          _insights(),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [core_theme.AC.purple.withValues(alpha: 0.25), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: core_theme.AC.purple.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.auto_awesome,
              color: core_theme.AC.purple, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('توقع التدفق النقدي بالذكاء الاصطناعي',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'نموذج يتعلّم من 6 أشهر فعلية + فواتير معلّقة + موسميّة → توقع 6 أشهر قادمة مع مجال ثقة 90%.',
                  style:
                      TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _kpis() => Row(children: [
        Expanded(
            child: _kpi('السيولة الحالية', '425,000 ر.س', AC.ok,
                Icons.account_balance_wallet)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('توقع بعد 6 أشهر', '245,000 ر.س', AC.gold,
                Icons.trending_down)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('Runway (معدّل)', '14.8 شهراً', AC.gold,
                Icons.timer_outlined)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('احتمال النزول تحت الحد', '18%', AC.err,
                Icons.warning_amber)),
      ]);

  Widget _kpi(String label, String value, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    style:
                        TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _insights() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lightbulb_outline,
                  color: core_theme.AC.warn, size: 20),
              const SizedBox(width: 6),
              Text('توصيات AI',
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _insight(
                'الإيرادات المتوقعة للربع القادم ستنخفض ~15% — خذ بعين الاعتبار حملة ترويجية أو عرض خصم',
                Icons.trending_down,
                AC.err),
            _insight(
                'هناك 3 فواتير معلّقة بقيمة 92,000 ر.س أكبر من 60 يوم — المتابعة قد تُقلّل مجال الثقة السفلي بـ 8%',
                Icons.receipt_long,
                core_theme.AC.warn),
            _insight(
                'تأجيل استثمار رأسمالي ≥ 80,000 ر.س يرفع Runway من 14.8 إلى 19.2 شهراً',
                Icons.savings_outlined,
                AC.ok),
            _insight(
                'الموسمية السابقة تُظهر نموّاً 22% في ديسمبر — خطّط للمخزون الإضافي الآن',
                Icons.calendar_month,
                AC.gold),
          ],
        ),
      );

  Widget _insight(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.sm,
                    height: 1.5)),
          ),
        ]),
      );
}

// ── Multi-Company Consolidation Tab ──────────────────────

class _ConsolidationTab extends StatelessWidget {
  const _ConsolidationTab();

  List<_CompanyRow> get _companies => const [
        _CompanyRow('APEX Holdings', 'SAR', 100.0, 2450000, 1820000, false),
        _CompanyRow('APEX KSA — Trading', 'SAR', 100.0, 1280000, 890000, true),
        _CompanyRow('APEX UAE — Services', 'AED', 100.0, 720000, 540000, true),
        _CompanyRow('APEX Egypt — Advisory', 'EGP', 65.0, 410000, 285000, true),
        _CompanyRow('Innovate Co. (associate)', 'USD', 25.0, 180000, 95000, true),
      ];

  @override
  Widget build(BuildContext context) {
    double totalRev = 0, totalExp = 0;
    double minority = 0;
    for (final c in _companies) {
      if (!c.isSubsidiary) continue;
      if (c.ownership == 100) {
        totalRev += c.revenueSar;
        totalExp += c.expenseSar;
      } else if (c.ownership >= 50) {
        totalRev += c.revenueSar;
        totalExp += c.expenseSar;
        minority += (c.revenueSar - c.expenseSar) * (1 - c.ownership / 100);
      } else {
        // associate — equity method: share of net income only
        totalRev += (c.revenueSar - c.expenseSar) * (c.ownership / 100);
      }
    }
    final intercoElim = 125000.0; // sample elimination
    final consolidatedNet = totalRev - totalExp - intercoElim - minority;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          _companiesTable(),
          const SizedBox(height: AppSpacing.lg),
          _rollup(totalRev, totalExp, intercoElim, minority, consolidatedNet),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [core_theme.AC.info.withValues(alpha: 0.25), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: core_theme.AC.info.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.hub, color: core_theme.AC.info, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('توحيد المجموعة (IFRS 10)',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'الشركة الأم + الشركات التابعة (>50%) + الشركات الشقيقة (20-50% بطريقة حقوق الملكية) + ترجمة عملات + حصة الأقلية.',
                  style:
                      TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _companiesTable() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكيانات القانونية',
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            ApexDataTable<_CompanyRow>(
              rows: _companies,
              columns: [
                ApexColumn(
                    key: 'name',
                    label: 'الكيان',
                    cell: (c) => Row(children: [
                          Icon(
                              c.isSubsidiary
                                  ? Icons.subdirectory_arrow_right
                                  : Icons.business,
                              size: 14,
                              color: c.isSubsidiary ? AC.ts : AC.gold),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.name,
                                style: TextStyle(
                                    color: AC.tp,
                                    fontWeight: c.isSubsidiary
                                        ? FontWeight.w500
                                        : FontWeight.w800)),
                          ),
                        ]),
                    sortValue: (c) => c.name,
                    flex: 3),
                ApexColumn(
                    key: 'ccy',
                    label: 'العملة',
                    cell: (c) => Text(c.currency,
                        style: TextStyle(color: AC.ts)),
                    sortValue: (c) => c.currency,
                    width: 80),
                ApexColumn(
                    key: 'own',
                    label: 'الملكية',
                    numeric: true,
                    cell: (c) => Text('${c.ownership.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: c.ownership >= 50 ? AC.ok : AC.gold,
                            fontWeight: FontWeight.w600)),
                    sortValue: (c) => c.ownership,
                    width: 80),
                ApexColumn(
                    key: 'rev',
                    label: 'الإيراد (ر.س)',
                    numeric: true,
                    cell: (c) => Text(c.revenueSar.toStringAsFixed(0),
                        style: TextStyle(
                            color: AC.gold,
                            fontWeight: FontWeight.w600,
                            fontFeatures:
                                const [FontFeature.tabularFigures()])),
                    sortValue: (c) => c.revenueSar,
                    width: 130),
                ApexColumn(
                    key: 'exp',
                    label: 'المصروف (ر.س)',
                    numeric: true,
                    cell: (c) => Text(c.expenseSar.toStringAsFixed(0),
                        style: TextStyle(
                            color: AC.err,
                            fontFeatures:
                                const [FontFeature.tabularFigures()])),
                    sortValue: (c) => c.expenseSar,
                    width: 130),
                ApexColumn(
                    key: 'method',
                    label: 'الطريقة',
                    cell: (c) => _methodPill(c),
                    sortable: false,
                    width: 120),
              ],
            ),
          ],
        ),
      );

  Widget _methodPill(_CompanyRow c) {
    if (!c.isSubsidiary) {
      return _pill('Parent', AC.gold);
    }
    if (c.ownership >= 100) return _pill('Full', AC.ok);
    if (c.ownership >= 50) return _pill('Full + NCI', core_theme.AC.warn);
    return _pill('Equity', core_theme.AC.info);
  }

  Widget _pill(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Text(s,
            style: TextStyle(
                color: c,
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.w700)),
      );

  Widget _rollup(double totalRev, double totalExp, double interco,
          double minority, double net) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('قائمة الدخل الموحّدة (بعد التعديلات)',
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            _row('إجمالي الإيرادات (قبل الاستبعاد)', totalRev, AC.gold),
            _row('(-) المصروفات', -totalExp, AC.err),
            _row('(-) استبعاد المعاملات الداخلية', -interco, AC.err),
            _row('(-) حصة الأقلية (NCI)', -minority, AC.err),
            const Divider(height: 20),
            _row('صافي الدخل الموحّد', net, AC.ok, bold: true),
          ],
        ),
      );

  Widget _row(String label, double value, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: bold ? AC.tp : AC.ts,
                    fontSize: bold ? AppFontSize.base : AppFontSize.sm,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
          ),
          Text('${value.toStringAsFixed(0)} ر.س',
              style: TextStyle(
                  color: color,
                  fontSize: bold ? AppFontSize.lg : AppFontSize.sm,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

class _CompanyRow {
  final String name;
  final String currency;
  final double ownership;
  final double revenueSar; // pre-translated for demo
  final double expenseSar;
  final bool isSubsidiary;
  const _CompanyRow(this.name, this.currency, this.ownership,
      this.revenueSar, this.expenseSar, this.isSubsidiary);
}

// ── Manufacturing BOM Tab ────────────────────────────────

class _ManufacturingTab extends StatefulWidget {
  const _ManufacturingTab();
  @override
  State<_ManufacturingTab> createState() => _ManufacturingTabState();
}

class _ManufacturingTabState extends State<_ManufacturingTab> {
  int _runSize = 10;

  BomNode get _bom => const BomNode(
        sku: 'FP-001',
        name: 'مكتب خشبي كامل',
        uom: 'EA',
        quantityPer: 1,
        unitCost: 120, // assembly labour
        onHand: 0,
        children: [
          BomNode(
            sku: 'SA-001',
            name: 'مجموعة الدرج',
            uom: 'EA',
            quantityPer: 2,
            unitCost: 40, // sub-assembly labour
            onHand: 15,
            children: [
              BomNode(
                  sku: 'RM-101',
                  name: 'خشب MDF 2.5cm × 30cm × 50cm',
                  uom: 'قطعة',
                  quantityPer: 2,
                  unitCost: 22,
                  onHand: 200),
              BomNode(
                  sku: 'RM-102',
                  name: 'مقبض درج معدني',
                  uom: 'EA',
                  quantityPer: 1,
                  unitCost: 8,
                  onHand: 40),
              BomNode(
                  sku: 'RM-103',
                  name: 'براغي 5cm × 100',
                  uom: 'علبة',
                  quantityPer: 0.1,
                  unitCost: 12,
                  onHand: 12),
            ],
          ),
          BomNode(
              sku: 'RM-201',
              name: 'لوح سطح المكتب MDF 120x60',
              uom: 'قطعة',
              quantityPer: 1,
              unitCost: 95,
              onHand: 8), // insufficient for 10 runs
          BomNode(
              sku: 'RM-202',
              name: 'قوائم معدنية 75cm',
              uom: 'قطعة',
              quantityPer: 4,
              unitCost: 18,
              onHand: 60),
          BomNode(
              sku: 'RM-203',
              name: 'ورق دِكور خشبي',
              uom: 'م²',
              quantityPer: 1.8,
              unitCost: 14,
              onHand: 25),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final rollup = _bom.rolledUpCost();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          _runSizeControl(rollup),
          const SizedBox(height: AppSpacing.lg),
          _tableHead(),
          const SizedBox(height: 4),
          ApexBomTree(root: _bom, runSize: _runSize),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [core_theme.AC.warn.withValues(alpha: 0.25), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: core_theme.AC.warn.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.precision_manufacturing,
              color: core_theme.AC.warn, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bill of Materials + فحص MRP',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'BOM متعدد المستويات + حساب التكلفة المُجمَّعة + تحذير نقص المخزون للتخطيط الإنتاجي.',
                  style:
                      TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _runSizeControl(double unitCost) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          Icon(Icons.tune, color: AC.gold, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('حجم الإنتاج:',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Slider(
              min: 1,
              max: 100,
              divisions: 99,
              value: _runSize.toDouble(),
              label: '$_runSize وحدة',
              activeColor: AC.gold,
              onChanged: (v) => setState(() => _runSize = v.round()),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$_runSize × ${unitCost.toStringAsFixed(0)} = ${(unitCost * _runSize).toStringAsFixed(0)} ر.س',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ]),
      );

  Widget _tableHead() => Row(children: [
        Expanded(
            flex: 4,
            child: Text('المكوّن',
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700))),
        Expanded(
            child: Text('مطلوب',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700))),
        Expanded(
            child: Text('متوفر',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700))),
        Expanded(
            child: Text('تكلفة /وحدة',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700))),
        Expanded(
            child: Text('الحالة',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AC.td,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700))),
      ]);
}
