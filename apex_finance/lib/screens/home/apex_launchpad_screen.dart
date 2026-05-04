/// APEX — Launchpad (Services → Apps → Screens hierarchy)
/// /launchpad — single entry point to all canonical features
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class ApexLaunchpadScreen extends StatefulWidget {
  const ApexLaunchpadScreen({super.key});
  @override
  State<ApexLaunchpadScreen> createState() => _ApexLaunchpadScreenState();
}

class _ApexLaunchpadScreenState extends State<ApexLaunchpadScreen> {
  String? _expandedService;

  static final List<_Service> _services = [
    _Service(
      id: 'today',
      title: 'الرئيسية',
      subtitle: 'لوحة اليوم — KPIs + AI Pulse',
      icon: Icons.dashboard,
      color: 0xFFFFC107,
      apps: [
        _App('اليوم', 'Today Dashboard مع AI', '/today', Icons.today),
        _App('التقارير', 'Reports Hub — 28 تقرير', '/reports', Icons.assessment),
        _App('الإشعارات', 'صندوق الوارد + إشعارات', '/notifications/panel', Icons.notifications_outlined),
      ],
    ),
    _Service(
      id: 'sales',
      title: 'المبيعات',
      subtitle: 'العملاء · الفواتير · التحصيلات',
      icon: Icons.receipt_long,
      color: 0xFF4CAF50,
      apps: [
        _App('دورة المبيعات', 'Live Sales Cycle', '/operations/live-sales-cycle', Icons.shopping_cart),
        _App('العملاء', 'قائمة + Customer 360', '/app/erp/finance/sales-customers', Icons.people),
        _App('الفواتير', '5 filters + WhatsApp', '/app/erp/sales/invoices', Icons.receipt),
        _App('عروض الأسعار', 'Pipeline + Win %', '/app/erp/sales/dashboard', Icons.description),
        _App('الإشعارات الدائنة/المدينة', 'Credit/Debit notes', '/app/erp/sales/credit-notes', Icons.note),
        _App('فواتير متكررة', 'MRR + ARR tracking', '/app/erp/finance/recurring-entries', Icons.repeat),
        _App('أعمار AR', '5 buckets ملوّنة', '/app/erp/sales/ar-aging', Icons.timeline),
      ],
    ),
    _Service(
      id: 'purchase',
      title: 'المشتريات',
      subtitle: 'الموردون · فواتير الشراء · المدفوعات',
      icon: Icons.local_shipping,
      color: 0xFF2196F3,
      apps: [
        _App('دورة الشراء', 'Purchase Cycle', '/operations/purchase-cycle', Icons.shopping_basket),
        _App('الموردون', 'قائمة + Vendor 360', '/app/erp/purchasing/suppliers', Icons.business),
        _App('فواتير الموردين', 'Bills List + filters', '/app/erp/finance/purchase-bills', Icons.receipt_outlined),
        _App('أعمار AP', 'AP Aging buckets', '/app/erp/purchasing/ap-aging', Icons.timeline),
      ],
    ),
    _Service(
      id: 'accounting',
      title: 'المحاسبة',
      subtitle: 'القيود · شجرة الحسابات · ميزان المراجعة',
      icon: Icons.account_balance,
      color: 0xFF9C27B0,
      apps: [
        _App('قائمة القيود', 'JE List canonical', '/app/erp/finance/je-builder', Icons.book),
        _App('شجرة الحسابات', 'CoA Tree v2 (SOCPA)', '/app/erp/finance/coa-editor', Icons.account_tree),
        _App('محرر الحسابات', 'CoA Editor', '/app/erp/finance/coa-editor', Icons.edit_note),
        _App('ميزان المراجعة', 'TB + drill chain', '/compliance/financial-statements', Icons.assessment),
        _App('التسوية البنكية AI', 'Auto-match >95%', '/app/erp/treasury/recon', Icons.account_balance_wallet),
        _App('إقفال الفترة', 'NetSuite checklist', '/operations/period-close', Icons.lock_clock),
      ],
    ),
    _Service(
      id: 'operations',
      title: 'العمليات',
      subtitle: 'POS · إيصالات · مخزون · أصول',
      icon: Icons.precision_manufacturing,
      color: 0xFFFF5722,
      apps: [
        _App('بيع سريع POS', 'Mada/STC/Apple Pay', '/pos/quick-sale', Icons.point_of_sale),
        _App('التقاط إيصال', 'OCR scaffold', '/receipt/capture', Icons.receipt),
        _App('المخزون', 'FIFO/LIFO/WAC', '/operations/inventory-v2', Icons.inventory_2),
        _App('بطاقة الصنف', 'Stock card timeline', '/operations/stock-card', Icons.timeline),
        _App('الأصول الثابتة', 'IAS 16 register', '/operations/fixed-assets-v2', Icons.business),
        _App('العهدة النقدية', 'Petty Cash + low-balance', '/operations/petty-cash', Icons.savings),
      ],
    ),
    _Service(
      id: 'compliance',
      title: 'الامتثال',
      subtitle: 'ZATCA · VAT · زكاة · IFRS · KYC',
      icon: Icons.gavel,
      color: 0xFFE91E63,
      apps: [
        _App('التقويم الضريبي', '7 obligations سعودية', '/compliance/tax-calendar', Icons.event),
        _App('ZATCA Status Center', 'CSID + Queue + Errors', '/compliance/zatca-status', Icons.verified),
        _App('VAT Return', 'إقرار شهري', '/compliance/vat-return', Icons.receipt_long),
        _App('الزكاة', 'الوعاء الزكوي 2.5%', '/compliance/zakat', Icons.account_balance_wallet),
        _App('استقطاع المصدر WHT', '5/15/20% بحسب الفئة', '/compliance/wht-v2', Icons.percent),
        _App('IFRS 16 — الإيجارات', 'ROU + جدول إهلاك', '/compliance/lease-v2', Icons.apartment),
        _App('IFRS 10 — التوحيد', 'Multi-entity + استبعادات', '/compliance/consolidation-v2', Icons.layers),
        _App('KYC/AML', 'Sanctions + PEP', '/compliance/kyc-aml', Icons.fact_check),
        _App('سجل المخاطر', 'Heatmap matrix', '/compliance/risk-register', Icons.shield),
        _App('سجل النشاط', 'Hash-Chain timeline', '/compliance/activity-log-v2', Icons.history),
      ],
    ),
    _Service(
      id: 'audit',
      title: 'المراجعة',
      subtitle: 'Engagement · Benford · Sampling · Sign-off',
      icon: Icons.verified_user,
      color: 0xFF607D8B,
      apps: [
        _App('Engagement Workspace', '5 tabs + Evidence Chain', '/audit/engagements', Icons.folder),
        _App('Benford Analysis', 'تحليل الرقم الأول', '/audit/benford', Icons.bar_chart),
        _App('JE Sampling', 'عينة deterministic', '/audit/sampling', Icons.shuffle),
        _App('Workpapers', 'PBC list + sign-off', '/audit/workpapers', Icons.description),
      ],
    ),
    _Service(
      id: 'analytics',
      title: 'التحليلات',
      subtitle: 'تدفقات · موازنات · صحة · عملات',
      icon: Icons.analytics,
      color: 0xFF00BCD4,
      apps: [
        _App('توقع التدفق النقدي', '90 يوم + شهور التشغيل', '/analytics/cash-flow-forecast', Icons.show_chart),
        _App('بناء الموازنة', '12 شهر + AI generation', '/analytics/budget-builder', Icons.calculate),
        _App('انحراف الموازنة', 'IBCS variance bars', '/analytics/budget-variance-v2', Icons.trending_up),
        _App('Health Score', 'Radial gauge — 6 أبعاد', '/analytics/health-score-v2', Icons.health_and_safety),
        _App('متابعة العملات', 'FX exposure + hedging', '/analytics/multi-currency-v2', Icons.currency_exchange),
        _App('المحفظة الاستثمارية', 'Donut + 5 categories', '/analytics/investment-portfolio-v2', Icons.savings),
        _App('ربحية المشاريع', 'P&L per project', '/analytics/project-profitability', Icons.engineering),
        _App('انحراف التكاليف', 'Material/Labour/OH', '/analytics/cost-variance-v2', Icons.precision_manufacturing),
      ],
    ),
    _Service(
      id: 'hr',
      title: 'الموارد البشرية',
      subtitle: 'الموظفون · الرواتب · GOSI · سعودة',
      icon: Icons.people,
      color: 0xFF8BC34A,
      apps: [
        _App('الموظفون', 'مع Saudization tier', '/hr/employees', Icons.badge),
        _App('تشغيل الرواتب', 'GOSI 22%/2% + Saudization', '/hr/payroll-run', Icons.payments),
        _App('سجل ساعات العمل', 'Weekly timesheet', '/hr/timesheet', Icons.access_time),
        _App('تقارير المصاريف', 'Expense workflow', '/hr/expense-reports', Icons.receipt_long),
      ],
    ),
    _Service(
      id: 'workflow',
      title: 'سير العمل والمعرفة',
      subtitle: 'الموافقات · AI · المعرفة',
      icon: Icons.account_tree,
      color: 0xFF673AB7,
      apps: [
        _App('صندوق الموافقات', 'Multi-step approval queue', '/workflow/approvals', Icons.inbox),
        _App('اقتراحات AI', 'Confidence-Gated Autopilot', '/admin/ai-suggestions-v2', Icons.lightbulb_outline),
        _App('قاعدة المعرفة', 'بحث في الأدلة', '/knowledge/search', Icons.menu_book),
        _App('Copilot', 'Ask APEX بالعربي', '/copilot', Icons.smart_toy),
      ],
    ),
    _Service(
      id: 'settings',
      title: 'الإعدادات',
      subtitle: 'الحساب · الكيان · التكاملات',
      icon: Icons.settings,
      color: 0xFF795548,
      apps: [
        _App('الإعدادات الموحّدة', '5 sections + sign-out', '/settings/unified', Icons.tune),
        _App('ربط البنوك', '11 بنك سعودي', '/settings/bank-feeds', Icons.account_balance),
        _App('إعداد الكيان', 'Onboarding wizard', '/onboarding', Icons.business_center),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('APEX Launchpad — كل التطبيقات',
            style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AC.gold),
            tooltip: 'Cmd+K للبحث',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _heroCard(),
          const SizedBox(height: 14),
          ..._services.map(_serviceCard),
        ],
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.18), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_services.length} خدمة · ${_services.fold<int>(0, (a, s) => a + s.apps.length)} تطبيق',
              style: TextStyle(color: AC.gold, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('اضغط أي خدمة لتوسيعها وعرض التطبيقات',
              style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // Quick links — top 4 destinations
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in [
              ('/today', '🏠 اليوم'),
              ('/app/erp/finance/sales-customers', '👥 العملاء'),
              ('/accounting/trial-balance', '📊 ميزان المراجعة'),
              ('/audit', '🔍 المراجعة'),
              ('/reports', '📋 التقارير'),
              ('/copilot', '🤖 كوبايلوت'),
            ])
              ActionChip(
                label: Text(q.$2, style: const TextStyle(fontSize: 11.5)),
                backgroundColor: AC.navy3,
                onPressed: () => context.go(q.$1),
              ),
          ]),
        ]),
      );

  Widget _serviceCard(_Service service) {
    final color = Color(service.color);
    final isExpanded = _expandedService == service.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: color.withValues(alpha: 0.4), width: isExpanded ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() {
            _expandedService = isExpanded ? null : service.id;
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(service.icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(service.title,
                      style: TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(service.subtitle,
                      style: TextStyle(color: AC.ts, fontSize: 11.5)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${service.apps.length}',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              ),
              const SizedBox(width: 6),
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AC.ts),
            ]),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: service.apps.map((app) => _appTile(app, color)).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _appTile(_App app, Color serviceColor) {
    return InkWell(
      onTap: () => context.go(app.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy3,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(app.icon, color: serviceColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(app.title,
                    style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(app.subtitle,
                    style: TextStyle(color: AC.ts, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: AC.ts, size: 14),
        ]),
      ),
    );
  }
}

class _Service {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final int color;
  final List<_App> apps;
  _Service({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.apps,
  });
}

class _App {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  const _App(this.title, this.subtitle, this.route, this.icon);
}
