/// APEX — Reports Hub
/// /reports — one-stop access to every financial + operational report
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  static const _sections = [
    _Section(
      title: 'القوائم المالية الأساسية',
      icon: Icons.assessment,
      reports: [
        _Report('ميزان المراجعة', 'Trial Balance Live', '/accounting/trial-balance', Icons.book),
        _Report('قائمة الدخل', 'Income Statement', '/compliance/financial-statements', Icons.trending_up),
        _Report('الميزانية العمومية', 'Balance Sheet', '/compliance/financial-statements', Icons.account_balance),
        _Report('قائمة التدفقات النقدية', 'Cash Flow Statement', '/compliance/cashflow-statement', Icons.water),
      ],
    ),
    _Section(
      title: 'الذمم والأعمار',
      icon: Icons.timeline,
      reports: [
        _Report('أعمار AR', 'Customer Aging', '/app/erp/sales/ar-aging', Icons.people),
        _Report('أعمار AP', 'Vendor Aging', '/purchase/aging', Icons.local_shipping),
        _Report('قائمة الفواتير', 'Sales Invoices', '/app/erp/sales/invoices', Icons.receipt_long),
        _Report('فواتير الموردين', 'Bills', '/purchase/bills', Icons.receipt),
      ],
    ),
    _Section(
      title: 'تحليلات + توقعات',
      icon: Icons.analytics,
      reports: [
        _Report('توقع التدفق النقدي', '90-day forecast', '/analytics/cash-flow-forecast', Icons.show_chart),
        _Report('النسب المالية', 'Liquidity / Solvency / Profitability', '/compliance/ratios', Icons.calculate),
        _Report('Health Score', 'مؤشر صحة الكيان', '/compliance/health-score', Icons.health_and_safety),
        _Report('رأس المال العامل', 'Working Capital', '/compliance/working-capital', Icons.savings),
      ],
    ),
    _Section(
      title: 'الامتثال والضرائب',
      icon: Icons.gavel,
      reports: [
        _Report('التقويم الضريبي', '7 obligations سعودية', '/compliance/tax-calendar', Icons.event),
        _Report('VAT Return', 'إقرار ضريبة القيمة المضافة', '/compliance/vat-return', Icons.receipt_long),
        _Report('الزكاة', 'Zakat Calculator', '/compliance/zakat', Icons.account_balance_wallet),
        _Report('WHT', 'استقطاع المصدر', '/compliance/wht', Icons.percent),
      ],
    ),
    _Section(
      title: 'المراجعة الداخلية',
      icon: Icons.verified_user,
      reports: [
        _Report('Engagement Workspace', '5 tabs مع Evidence Chain', '/audit/engagements', Icons.folder),
        _Report('Benford Analysis', 'تحليل الرقم الأول', '/audit/benford', Icons.bar_chart),
        _Report('JE Sampling', 'عينة قيود deterministic', '/audit/sampling', Icons.shuffle),
        _Report('Audit Trail', 'سلسلة الأحداث', '/compliance/audit-trail', Icons.history),
      ],
    ),
    _Section(
      title: 'الموارد البشرية',
      icon: Icons.people,
      reports: [
        _Report('قائمة الموظفين', 'مع Saudization', '/hr/employees', Icons.badge),
        _Report('Payroll', 'كشف الرواتب', '/compliance/payroll', Icons.account_balance_wallet),
        _Report('GOSI', 'تأمينات اجتماعية', '/compliance/payroll', Icons.shield),
      ],
    ),
    _Section(
      title: 'متقدّمة',
      icon: Icons.auto_awesome,
      reports: [
        _Report('Consolidation', 'تجميع الكيانات', '/compliance/consolidation', Icons.layers),
        _Report('Multi-Currency', 'تحليل FX', '/compliance/multi-currency', Icons.currency_exchange),
        _Report('Fixed Assets', 'الأصول الثابتة', '/compliance/fixed-assets', Icons.business),
        _Report('Investments', 'المحفظة الاستثمارية', '/compliance/investment', Icons.savings),
        _Report('Lease Accounting', 'IFRS 16', '/compliance/lease', Icons.apartment),
        _Report('IFRS Tools', 'IFRS 2 / IAS 40 / IFRS 16', '/compliance/ifrs-tools', Icons.science),
        _Report('Islamic Finance', 'Murabaha / Ijarah / Zakah', '/compliance/islamic-finance', Icons.mosque),
        _Report('Transfer Pricing', 'TP documentation', '/compliance/transfer-pricing', Icons.compare_arrows),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('مركز التقارير', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AC.gold),
            tooltip: 'بحث (Cmd+K)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('استخدم Cmd+K للبحث')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _sections.length + 1,
        itemBuilder: (_, i) {
          if (i == _sections.length) {
            return const ApexOutputChips(items: [
              ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
              ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
              ApexChipLink('Health Score', '/analytics/health-score-v2', Icons.health_and_safety),
              ApexChipLink('توقع التدفق', '/analytics/cash-flow-forecast', Icons.show_chart),
            ]);
          }
          return _sectionCard(_sections[i], context);
        },
      ),
    );
  }

  Widget _sectionCard(_Section section, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Icon(section.icon, color: AC.gold, size: 20),
            const SizedBox(width: 10),
            Text(section.title,
                style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
            childAspectRatio: 2.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: section.reports.map((r) => _reportTile(r, context)).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _reportTile(_Report r, BuildContext context) {
    return InkWell(
      onTap: () => context.go(r.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy3,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(r.icon, color: AC.gold, size: 16),
              const Spacer(),
              Icon(Icons.chevron_left, color: AC.ts, size: 12),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title,
                  style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(r.subtitle,
                  style: TextStyle(color: AC.ts, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final IconData icon;
  final List<_Report> reports;
  const _Section({required this.title, required this.icon, required this.reports});
}

class _Report {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  const _Report(this.title, this.subtitle, this.route, this.icon);
}
