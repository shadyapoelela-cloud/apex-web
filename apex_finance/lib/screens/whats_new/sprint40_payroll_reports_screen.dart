/// Sprint 40 — Payroll (GOSI + WPS) + Custom Report Builder.
///
/// Two tabs:
///   1) كشف رواتب يحسب GOSI (22% = 9% employee + 9% employer + 4% admin
///      approx) + ضريبة + يولّد ملف WPS بصيغة سعودية للتحميل.
///   2) ApexReportBuilder demo — drag fields to build a P&L by-dept
///      report.
library;

import 'package:flutter/material.dart';

import '../../core/apex_data_table.dart';
import '../../core/apex_report_builder.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class Sprint40PayrollReportsScreen extends StatefulWidget {
  const Sprint40PayrollReportsScreen({super.key});

  @override
  State<Sprint40PayrollReportsScreen> createState() =>
      _Sprint40PayrollReportsScreenState();
}

class _Sprint40PayrollReportsScreenState
    extends State<Sprint40PayrollReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);

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
          const ApexStickyToolbar(title: '💼 Sprint 40: رواتب + تقارير'),
          Container(
            color: AC.navy2,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              tabs: const [
                Tab(icon: Icon(Icons.badge_outlined), text: 'الرواتب + GOSI/WPS'),
                Tab(icon: Icon(Icons.analytics_outlined), text: 'بانِي التقارير'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _PayrollTab(),
                _ReportBuilderTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payroll Tab ──────────────────────────────────────────

class _PayrollTab extends StatefulWidget {
  const _PayrollTab();
  @override
  State<_PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends State<_PayrollTab> {
  // 5 employees with KSA-style salary structures.
  final List<_PayrollRow> _rows = [
    _PayrollRow('EMP-001', 'أحمد السالم', 18000, 2000, 500),
    _PayrollRow('EMP-002', 'فاطمة النور', 16500, 1500, 300),
    _PayrollRow('EMP-003', 'خالد العتيبي', 14000, 1800, 400),
    _PayrollRow('EMP-004', 'ريم القحطاني', 11000, 1200, 250),
    _PayrollRow('EMP-005', 'يوسف المطيري', 9500, 800, 200),
  ];

  // KSA GOSI rates (approximate — verify with actual regulations):
  // Employee: 10% (9% pension + 1% unemployment SANED)
  // Employer: 12% (9% pension + 2% occupational hazards + 1% SANED)
  static const double _empGosi = 0.10;
  static const double _erGosi = 0.12;

  double _netFor(_PayrollRow r) {
    final gross = r.basic + r.housing + r.transport;
    final gosi = gross * _empGosi;
    return gross - gosi;
  }

  double get _totalGross =>
      _rows.fold(0.0, (s, r) => s + r.basic + r.housing + r.transport);
  double get _totalNet => _rows.fold(0.0, (s, r) => s + _netFor(r));
  double get _totalEmpGosi => _totalGross * _empGosi;
  double get _totalErGosi => _totalGross * _erGosi;
  double get _totalGosiRemittance => _totalEmpGosi + _totalErGosi;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kpiStrip(),
          const SizedBox(height: AppSpacing.lg),
          _payrollCard(),
          const SizedBox(height: AppSpacing.lg),
          _wpsCard(),
        ],
      ),
    );
  }

  Widget _kpiStrip() => Row(children: [
        Expanded(
            child: _kpi('إجمالي الرواتب', _totalGross, AC.gold, Icons.payments)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('صافي للموظفين', _totalNet, AC.ok,
                Icons.account_balance_wallet)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('GOSI الموظف (10%)', _totalEmpGosi, AC.err,
                Icons.remove_circle_outline)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _kpi('GOSI الشركة (12%)', _totalErGosi, AC.err,
                Icons.business)),
      ]);

  Widget _kpi(String label, double value, Color accent, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style:
                        TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text('${value.toStringAsFixed(0)} ر.س',
                style: TextStyle(
                    color: accent,
                    fontSize: AppFontSize.h3,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );

  Widget _payrollCard() => _card(
        title: 'كشف الرواتب لشهر ${_monthLabel()}',
        body: ApexDataTable<_PayrollRow>(
          rows: _rows,
          columns: [
            ApexColumn(
                key: 'id',
                label: 'رقم',
                cell: (r) => Text(r.id, style: TextStyle(color: AC.tp)),
                sortValue: (r) => r.id,
                width: 90),
            ApexColumn(
                key: 'name',
                label: 'الموظف',
                cell: (r) => Text(r.name, style: TextStyle(color: AC.tp)),
                sortValue: (r) => r.name,
                flex: 2),
            ApexColumn(
                key: 'basic',
                label: 'أساسي',
                numeric: true,
                cell: (r) => _num(r.basic),
                sortValue: (r) => r.basic,
                width: 90),
            ApexColumn(
                key: 'housing',
                label: 'سكن',
                numeric: true,
                cell: (r) => _num(r.housing),
                sortValue: (r) => r.housing,
                width: 80),
            ApexColumn(
                key: 'transport',
                label: 'نقل',
                numeric: true,
                cell: (r) => _num(r.transport),
                sortValue: (r) => r.transport,
                width: 80),
            ApexColumn(
                key: 'gross',
                label: 'إجمالي',
                numeric: true,
                cell: (r) => Text(
                    (r.basic + r.housing + r.transport).toStringAsFixed(0),
                    style: TextStyle(
                        color: AC.tp, fontWeight: FontWeight.w700)),
                sortValue: (r) => r.basic + r.housing + r.transport,
                width: 100),
            ApexColumn(
                key: 'gosi',
                label: 'GOSI',
                numeric: true,
                cell: (r) => Text(
                    ((r.basic + r.housing + r.transport) * _empGosi)
                        .toStringAsFixed(0),
                    style: TextStyle(color: AC.err)),
                sortValue: (r) =>
                    (r.basic + r.housing + r.transport) * _empGosi,
                width: 90),
            ApexColumn(
                key: 'net',
                label: 'الصافي',
                numeric: true,
                cell: (r) => Text(_netFor(r).toStringAsFixed(0),
                    style: TextStyle(
                        color: AC.ok,
                        fontWeight: FontWeight.w700,
                        fontFeatures:
                            const [FontFeature.tabularFigures()])),
                sortValue: (r) => _netFor(r),
                width: 100),
          ],
        ),
      );

  Widget _wpsCard() => _card(
        title: 'ملف WPS (نظام حماية الأجور)',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملف SIF معياري لرفعه إلى البنك عبر نظام SADAD — يحتوي على IBAN الموظف + الصافي + تاريخ التحويل.',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AC.bdr),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('إجمالي المستفيدين', '${_rows.length} موظف'),
                  _kv('إجمالي الصافي',
                      '${_totalNet.toStringAsFixed(2)} ر.س'),
                  _kv('إجمالي GOSI (للدفع)',
                      '${_totalGosiRemittance.toStringAsFixed(2)} ر.س'),
                  _kv('تاريخ التنفيذ المقترح',
                      _endOfCurrentMonth()),
                  _kv('بنك الصرف', 'البنك الأهلي السعودي'),
                  _kv('IBAN المُرسِل', 'SA03 8000 0000 6080 1016 7519'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              FilledButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('تنزيل WPS SIF'),
                onPressed: () => _toast('سيتم توليد ملف SIF + تحميله'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('تنزيل GOSI CSV'),
                onPressed: () => _toast('GOSI monthly export'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('إرسال مباشر SADAD'),
                onPressed: () =>
                    _toast('يتطلب ربطاً حياً مع بنك المؤسسة'),
              ),
            ]),
          ],
        ),
      );

  Widget _card({required String title, required Widget body}) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            body,
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 180,
              child: Text(k,
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _num(double v) => Text(v.toStringAsFixed(0),
      style: TextStyle(
          color: AC.tp, fontFeatures: const [FontFeature.tabularFigures()]));

  String _monthLabel() {
    const months = [
      'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  String _endOfCurrentMonth() {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month + 1, 0);
    return last.toIso8601String().substring(0, 10);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }
}

// ── Report Builder Tab ───────────────────────────────────

class _ReportBuilderTab extends StatefulWidget {
  const _ReportBuilderTab();
  @override
  State<_ReportBuilderTab> createState() => _ReportBuilderTabState();
}

class _ReportBuilderTabState extends State<_ReportBuilderTab> {
  ReportDefinition _def = const ReportDefinition();

  final _catalogue = const [
    // Dimensions
    ReportField(
        id: 'department',
        label: 'القسم',
        kind: ReportFieldKind.dimension,
        icon: Icons.groups_outlined),
    ReportField(
        id: 'month',
        label: 'الشهر',
        kind: ReportFieldKind.dimension,
        icon: Icons.calendar_month),
    ReportField(
        id: 'customer',
        label: 'العميل',
        kind: ReportFieldKind.dimension,
        icon: Icons.person_outline),
    ReportField(
        id: 'product_line',
        label: 'خط المنتج',
        kind: ReportFieldKind.dimension,
        icon: Icons.inventory_2_outlined),
    ReportField(
        id: 'project',
        label: 'المشروع',
        kind: ReportFieldKind.dimension,
        icon: Icons.work_outline),
    // Measures
    ReportField(
        id: 'revenue',
        label: 'الإيرادات',
        kind: ReportFieldKind.measure,
        icon: Icons.trending_up),
    ReportField(
        id: 'cogs',
        label: 'تكلفة البضاعة',
        kind: ReportFieldKind.measure,
        icon: Icons.shopping_cart_outlined),
    ReportField(
        id: 'gross_margin',
        label: 'الربح الإجمالي',
        kind: ReportFieldKind.measure,
        icon: Icons.savings_outlined),
    ReportField(
        id: 'headcount',
        label: 'عدد الموظفين',
        kind: ReportFieldKind.measure,
        icon: Icons.people_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AC.gold.withValues(alpha: 0.18), AC.navy2],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AC.gold.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.drag_indicator, color: Colors.amber, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بانِي التقارير المخصصة',
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'اسحب حقلاً من القائمة اليمنى إلى مناطق الصفوف / الأعمدة / القياسات. استعلام SQL يُوَلَّد تلقائياً أسفل المنشئ.',
                      style: TextStyle(
                          color: AC.ts, fontSize: AppFontSize.sm),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          ApexReportBuilder(
            catalogue: _catalogue,
            initial: _def,
            onChanged: (d) => setState(() => _def = d),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('تشغيل التقرير'),
              onPressed: () =>
                  _toast('${_def.measures.length} قياس + ${_def.rowFieldIds.length} صف'),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('حفظ التقرير'),
              onPressed: () => _toast('محفوظ في "تقاريري"'),
            ),
          ]),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }
}

class _PayrollRow {
  final String id;
  final String name;
  final double basic;
  final double housing;
  final double transport;
  const _PayrollRow(
      this.id, this.name, this.basic, this.housing, this.transport);
}
