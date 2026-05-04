/// APEX — Service Hub (one shell for all 11 services)
/// Takes a service ID and renders that service's tile grid.
///
/// Routes:
///   /sales       → SalesHub
///   /purchase    → PurchaseHub
///   /accounting  → AccountingHub
///   /operations  → OperationsHub
///   /compliance-hub  → ComplianceHub
///   /audit-hub   → AuditHub
///   /analytics   → AnalyticsHub
///   /hr-hub      → HRHub
///   /workflow-hub → WorkflowHub
///   /settings-hub → SettingsHub
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class _Tile {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final bool featured;
  const _Tile(this.title, this.subtitle, this.route, this.icon, {this.featured = false});
}

class _Section {
  final String title;
  final IconData icon;
  final int color;
  final List<_Tile> tiles;
  const _Section(this.title, {required this.icon, required this.color, required this.tiles});
}

class _ServiceConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final int color;
  final List<_Tile> tiles;
  final String? heroRoute;
  final String? heroLabel;
  final String? heroIcon;
  /// Canonical input → output flow as a list of route paths.
  /// Each route must exist in [tiles] (used to resolve title/icon).
  final List<String> flow;
  /// Optional grouped sections. When present, supersedes the
  /// featured/others split — tiles render under labelled section headers
  /// (e.g. المدخلات / الدفاتر / المخرجات / التحليل / الإعدادات).
  final List<_Section> sections;
  const _ServiceConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tiles,
    this.heroRoute,
    this.heroLabel,
    this.heroIcon,
    this.flow = const [],
    this.sections = const [],
  });
}

class ApexServiceHubScreen extends StatelessWidget {
  final String serviceId;
  const ApexServiceHubScreen({super.key, required this.serviceId});

  static final Map<String, _ServiceConfig> _services = {
    'sales': _ServiceConfig(
      title: 'المبيعات',
      subtitle: 'العملاء · الفواتير · الذمم · المتكررة',
      icon: Icons.receipt_long,
      color: 0xFF4CAF50,
      heroRoute: '/operations/live-sales-cycle',
      heroLabel: 'افتح دورة المبيعات الكاملة',
      flow: ['/app/erp/finance/sales-customers', '/app/erp/sales/dashboard', '/app/erp/sales/invoices', '/app/erp/sales/ar-aging'],
      sections: [
        _Section('المدخلات — إنشاء',
          icon: Icons.input,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('عرض سعر جديد', 'Pipeline + Win %', '/app/erp/sales/dashboard', Icons.description),
            _Tile('فاتورة مبيعات', 'إصدار + ZATCA', '/app/erp/sales/invoices', Icons.receipt),
            _Tile('فاتورة متكررة', 'MRR + ARR', '/app/erp/finance/recurring-entries', Icons.repeat),
            _Tile('بيع سريع POS', 'Mada/STC/Apple Pay', '/pos/quick-sale', Icons.point_of_sale),
            _Tile('إشعار دائن/مدين', 'Credit/Debit notes', '/app/erp/sales/credit-notes', Icons.note),
          ]),
        _Section('الدفاتر — السجلات',
          icon: Icons.menu_book,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('قائمة العملاء', 'كل العملاء', '/app/erp/finance/sales-customers', Icons.people),
            _Tile('قائمة الفواتير', '5 filters + WhatsApp', '/app/erp/sales/invoices', Icons.receipt_long),
            _Tile('قائمة العروض', 'Quotes pipeline', '/app/erp/sales/dashboard', Icons.list_alt),
          ]),
        _Section('المخرجات — التقارير',
          icon: Icons.assessment,
          color: 0xFFFFC107,
          tiles: [
            _Tile('أعمار AR', '5 buckets ملوّنة', '/app/erp/sales/ar-aging', Icons.timeline),
            _Tile('VAT Return', 'إقرار الضريبة', '/compliance/vat-return', Icons.receipt_long),
            _Tile('ميزان المراجعة', 'TB + drill', '/compliance/financial-statements', Icons.assessment),
            _Tile('قائمة القيود', 'JE المُولّدة تلقائياً', '/app/erp/finance/je-builder', Icons.book),
          ]),
        _Section('الإعدادات',
          icon: Icons.settings,
          color: 0xFF795548,
          tiles: [
            _Tile('الإعدادات الموحّدة', 'الفواتير + الترقيم', '/settings/unified', Icons.tune),
          ]),
      ],
      tiles: [
        _Tile('العملاء', 'قائمة + Customer 360', '/app/erp/finance/sales-customers', Icons.people, featured: true),
        _Tile('الفواتير', '5 filters + WhatsApp', '/app/erp/sales/invoices', Icons.receipt, featured: true),
        _Tile('عروض الأسعار', 'Pipeline + Win %', '/app/erp/sales/dashboard', Icons.description),
        _Tile('فواتير متكررة', 'MRR + ARR tracking', '/app/erp/finance/recurring-entries', Icons.repeat),
        _Tile('الإشعارات الدائنة/المدينة', 'Credit/Debit notes', '/app/erp/sales/credit-notes', Icons.note),
        _Tile('أعمار AR', '5 buckets ملوّنة', '/app/erp/sales/ar-aging', Icons.timeline, featured: true),
        _Tile('بيع سريع POS', 'Mada/STC/Apple', '/pos/quick-sale', Icons.point_of_sale),
      ],
    ),
    'purchase': _ServiceConfig(
      title: 'المشتريات',
      subtitle: 'الموردون · فواتير · أعمار · مدفوعات',
      icon: Icons.local_shipping,
      color: 0xFF2196F3,
      heroRoute: '/operations/purchase-cycle',
      heroLabel: 'افتح دورة الشراء الكاملة',
      flow: ['/purchase/vendors', '/purchase/bills', '/purchase/aging'],
      sections: [
        _Section('المدخلات — إنشاء',
          icon: Icons.input,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('فاتورة شراء', 'تسجيل + WHT', '/purchase/bills', Icons.receipt_outlined),
            _Tile('التقاط إيصال', 'OCR — Claude Vision', '/receipt/capture', Icons.document_scanner),
            _Tile('تقرير مصاريف', 'Expense report', '/hr/expense-reports', Icons.receipt_long),
          ]),
        _Section('الدفاتر — السجلات',
          icon: Icons.menu_book,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('قائمة الموردين', 'كل الموردين', '/purchase/vendors', Icons.business),
            _Tile('قائمة الفواتير', 'Bills + filters', '/purchase/bills', Icons.list_alt),
          ]),
        _Section('المخرجات — التقارير',
          icon: Icons.assessment,
          color: 0xFFFFC107,
          tiles: [
            _Tile('أعمار AP', 'AP Aging buckets', '/purchase/aging', Icons.timeline),
            _Tile('استقطاع المصدر WHT', '5/15/20%', '/compliance/wht-v2', Icons.percent),
            _Tile('VAT Return', 'الضريبة المدخلة', '/compliance/vat-return', Icons.receipt_long),
            _Tile('قائمة القيود', 'JE المُولّدة تلقائياً', '/app/erp/finance/je-builder', Icons.book),
          ]),
        _Section('الإعدادات',
          icon: Icons.settings,
          color: 0xFF795548,
          tiles: [
            _Tile('الإعدادات الموحّدة', 'الموردين + الترقيم', '/settings/unified', Icons.tune),
          ]),
      ],
      tiles: [
        _Tile('الموردون', 'قائمة + Vendor 360', '/purchase/vendors', Icons.business, featured: true),
        _Tile('فواتير الموردين', 'Bills List + filters', '/purchase/bills', Icons.receipt_outlined, featured: true),
        _Tile('أعمار AP', 'AP Aging buckets', '/purchase/aging', Icons.timeline, featured: true),
      ],
    ),
    'accounting': _ServiceConfig(
      title: 'المحاسبة',
      subtitle: 'القيود · شجرة الحسابات · ميزان المراجعة',
      icon: Icons.account_balance,
      color: 0xFF9C27B0,
      heroRoute: '/compliance/financial-statements',
      heroLabel: 'افتح ميزان المراجعة (Live)',
      flow: ['/accounting/coa-v2', '/app/erp/finance/je-builder', '/compliance/financial-statements', '/operations/period-close'],
      sections: [
        _Section('المدخلات — مستندات المصدر',
          icon: Icons.input,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('قيد يومية جديد', 'إدخال يدوي + توازن تلقائي', '/app/erp/finance/je-builder/new', Icons.edit_note),
            _Tile('فاتورة مبيعات', 'إصدار + ZATCA Phase 2', '/app/erp/sales/invoices', Icons.receipt),
            _Tile('فاتورة مشتريات', 'تسجيل + WHT', '/purchase/bills', Icons.receipt_outlined),
            _Tile('بيع سريع POS', 'Mada/STC/Apple Pay', '/pos/quick-sale', Icons.point_of_sale),
            _Tile('التقاط إيصال', 'OCR — Claude Vision', '/receipt/capture', Icons.document_scanner),
          ]),
        _Section('الدفاتر — التسجيل',
          icon: Icons.menu_book,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('قائمة القيود', 'JE List canonical', '/app/erp/finance/je-builder', Icons.book),
            _Tile('شجرة الحسابات', 'CoA Tree (SOCPA)', '/accounting/coa-v2', Icons.account_tree),
            _Tile('التسوية البنكية AI', 'Auto-match >95%', '/accounting/bank-rec-v2', Icons.account_balance_wallet),
          ]),
        _Section('المخرجات — القوائم المالية',
          icon: Icons.assessment,
          color: 0xFFFFC107,
          tiles: [
            _Tile('ميزان المراجعة', 'TB + Drill chain', '/compliance/financial-statements', Icons.assessment),
            _Tile('إقفال الفترة', 'NetSuite checklist', '/operations/period-close', Icons.lock_clock),
            _Tile('مركز التقارير', 'كل القوائم', '/reports', Icons.folder_special),
            _Tile('سجل النشاط', 'Hash-Chain Audit Trail', '/compliance/activity-log-v2', Icons.history),
          ]),
        _Section('التحليل المالي',
          icon: Icons.analytics,
          color: 0xFF00BCD4,
          tiles: [
            _Tile('Health Score', 'مؤشر صحة الكيان', '/analytics/health-score-v2', Icons.health_and_safety),
            _Tile('توقع التدفق النقدي', '90 يوم + Runway', '/analytics/cash-flow-forecast', Icons.show_chart),
            _Tile('بناء الموازنة', '12 شهر + AI', '/analytics/budget-builder', Icons.calculate),
            _Tile('انحراف الموازنة', 'IBCS variance', '/analytics/budget-variance-v2', Icons.trending_up),
          ]),
        _Section('الإعدادات',
          icon: Icons.settings,
          color: 0xFF795548,
          tiles: [
            _Tile('محرر الحسابات', 'إضافة/تعديل CoA', '/accounting/coa/edit', Icons.edit_note),
            _Tile('ربط البنوك', '11 بنك سعودي', '/settings/bank-feeds', Icons.account_balance),
            _Tile('إعداد الكيان', 'Onboarding wizard', '/onboarding', Icons.business_center),
          ]),
      ],
      tiles: [
        _Tile('قائمة القيود', 'JE List canonical', '/app/erp/finance/je-builder', Icons.book, featured: true),
        _Tile('شجرة الحسابات', 'CoA Tree (SOCPA)', '/accounting/coa-v2', Icons.account_tree, featured: true),
        _Tile('محرر الحسابات', 'CoA Editor', '/accounting/coa/edit', Icons.edit_note),
        _Tile('ميزان المراجعة', 'TB + drill chain', '/compliance/financial-statements', Icons.assessment, featured: true),
        _Tile('التسوية البنكية AI', 'Auto-match >95%', '/accounting/bank-rec-v2', Icons.account_balance_wallet),
        _Tile('إقفال الفترة', 'NetSuite checklist', '/operations/period-close', Icons.lock_clock),
      ],
    ),
    'operations': _ServiceConfig(
      title: 'العمليات',
      subtitle: 'POS · إيصالات · مخزون · أصول · عهدة',
      icon: Icons.precision_manufacturing,
      color: 0xFFFF5722,
      flow: ['/receipt/capture', '/pos/quick-sale', '/operations/inventory-v2', '/operations/stock-card'],
      sections: [
        _Section('المدخلات',
          icon: Icons.input,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('بيع سريع POS', 'Mada/STC/Apple Pay', '/pos/quick-sale', Icons.point_of_sale),
            _Tile('التقاط إيصال', 'OCR Claude Vision', '/receipt/capture', Icons.document_scanner),
          ]),
        _Section('الدفاتر',
          icon: Icons.menu_book,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('المخزون', 'FIFO/LIFO/WAC', '/operations/inventory-v2', Icons.inventory_2),
            _Tile('بطاقة الصنف', 'Stock card timeline', '/operations/stock-card', Icons.timeline),
            _Tile('الأصول الثابتة', 'IAS 16 register', '/operations/fixed-assets-v2', Icons.business),
            _Tile('العهدة النقدية', 'Petty cash', '/operations/petty-cash', Icons.savings),
          ]),
        _Section('المخرجات',
          icon: Icons.assessment,
          color: 0xFFFFC107,
          tiles: [
            _Tile('إقفال الفترة', 'NetSuite checklist', '/operations/period-close', Icons.lock_clock),
            _Tile('قائمة القيود', 'JE من POS', '/app/erp/finance/je-builder', Icons.book),
            _Tile('ميزان المراجعة', 'TB live', '/compliance/financial-statements', Icons.assessment),
          ]),
      ],
      tiles: [
        _Tile('بيع سريع POS', 'Mada/STC/Apple Pay', '/pos/quick-sale', Icons.point_of_sale, featured: true),
        _Tile('التقاط إيصال', 'OCR scaffold', '/receipt/capture', Icons.receipt, featured: true),
        _Tile('المخزون', 'FIFO/LIFO/WAC', '/operations/inventory-v2', Icons.inventory_2, featured: true),
        _Tile('بطاقة الصنف', 'Stock card timeline', '/operations/stock-card', Icons.timeline),
        _Tile('الأصول الثابتة', 'IAS 16 register', '/operations/fixed-assets-v2', Icons.business),
        _Tile('العهدة النقدية', 'Petty Cash + low-balance', '/operations/petty-cash', Icons.savings),
      ],
    ),
    'compliance-hub': _ServiceConfig(
      title: 'الامتثال',
      subtitle: 'ZATCA · VAT · زكاة · IFRS · KYC · مخاطر',
      icon: Icons.gavel,
      color: 0xFFE91E63,
      heroRoute: '/compliance/tax-calendar',
      heroLabel: 'افتح التقويم الضريبي السعودي',
      flow: ['/compliance/tax-calendar', '/compliance/zatca-status', '/compliance/vat-return', '/compliance/activity-log-v2'],
      sections: [
        _Section('الضرائب — حسابات + إقرارات',
          icon: Icons.calculate,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('VAT Return', 'إقرار شهري', '/compliance/vat-return', Icons.receipt_long),
            _Tile('الزكاة', '2.5% من الوعاء', '/compliance/zakat', Icons.account_balance_wallet),
            _Tile('استقطاع المصدر WHT', '5/15/20%', '/compliance/wht-v2', Icons.percent),
          ]),
        _Section('ZATCA Phase 2',
          icon: Icons.verified,
          color: 0xFF2196F3,
          tiles: [
            _Tile('التقويم الضريبي', '7 obligations', '/compliance/tax-calendar', Icons.event),
            _Tile('ZATCA Status Center', 'CSID + Queue + Errors', '/compliance/zatca-status', Icons.verified),
          ]),
        _Section('IFRS — معايير دولية',
          icon: Icons.account_balance,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('IFRS 16 — الإيجارات', 'ROU + جدول إهلاك', '/compliance/lease-v2', Icons.apartment),
            _Tile('IFRS 10 — التوحيد', 'Multi-entity', '/compliance/consolidation-v2', Icons.layers),
          ]),
        _Section('المخاطر والامتثال',
          icon: Icons.shield,
          color: 0xFFE91E63,
          tiles: [
            _Tile('KYC/AML', 'Sanctions + PEP', '/compliance/kyc-aml', Icons.fact_check),
            _Tile('سجل المخاطر', 'Heatmap Impact×Probability', '/compliance/risk-register', Icons.shield),
            _Tile('سجل النشاط', 'Hash-Chain timeline', '/compliance/activity-log-v2', Icons.history),
          ]),
      ],
      tiles: [
        _Tile('التقويم الضريبي', '7 obligations', '/compliance/tax-calendar', Icons.event, featured: true),
        _Tile('ZATCA Status Center', 'CSID + Queue + Errors', '/compliance/zatca-status', Icons.verified, featured: true),
        _Tile('VAT Return', 'إقرار شهري', '/compliance/vat-return', Icons.receipt_long),
        _Tile('الزكاة', 'الوعاء الزكوي 2.5%', '/compliance/zakat', Icons.account_balance_wallet),
        _Tile('استقطاع المصدر WHT', '5/15/20%', '/compliance/wht-v2', Icons.percent),
        _Tile('IFRS 16 — الإيجارات', 'ROU + جدول إهلاك', '/compliance/lease-v2', Icons.apartment),
        _Tile('IFRS 10 — التوحيد', 'Multi-entity', '/compliance/consolidation-v2', Icons.layers),
        _Tile('KYC/AML', 'Sanctions + PEP', '/compliance/kyc-aml', Icons.fact_check, featured: true),
        _Tile('سجل المخاطر', 'Heatmap matrix', '/compliance/risk-register', Icons.shield),
        _Tile('سجل النشاط', 'Hash-Chain timeline', '/compliance/activity-log-v2', Icons.history),
      ],
    ),
    'audit-hub': _ServiceConfig(
      title: 'المراجعة الداخلية',
      subtitle: 'Workpapers · Benford · Sampling · Sign-off',
      icon: Icons.verified_user,
      color: 0xFF607D8B,
      heroRoute: '/audit/engagements',
      heroLabel: 'افتح Engagement Workspace',
      flow: ['/audit/workpapers', '/audit/sampling', '/audit/benford', '/audit/engagements'],
      sections: [
        _Section('التخطيط',
          icon: Icons.flag,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('Engagement Workspace', '5 tabs + Evidence Chain', '/audit/engagements', Icons.folder),
            _Tile('Workpapers', 'PBC list + sign-off', '/audit/workpapers', Icons.description),
          ]),
        _Section('الاختبارات',
          icon: Icons.science,
          color: 0xFF2196F3,
          tiles: [
            _Tile('JE Sampling', 'عينة deterministic', '/audit/sampling', Icons.shuffle),
            _Tile('Benford Analysis', 'تحليل الرقم الأول', '/audit/benford', Icons.bar_chart),
          ]),
        _Section('الأدلة والتقارير',
          icon: Icons.assessment,
          color: 0xFFFFC107,
          tiles: [
            _Tile('سجل النشاط', 'Hash-Chain Audit Trail', '/compliance/activity-log-v2', Icons.history),
            _Tile('سجل المخاطر', 'Risk register', '/compliance/risk-register', Icons.shield),
          ]),
      ],
      tiles: [
        _Tile('Engagement Workspace', '5 tabs + Evidence Chain', '/audit/engagements', Icons.folder, featured: true),
        _Tile('Benford Analysis', 'تحليل الرقم الأول', '/audit/benford', Icons.bar_chart, featured: true),
        _Tile('JE Sampling', 'عينة deterministic', '/audit/sampling', Icons.shuffle),
        _Tile('Workpapers', 'PBC list + sign-off', '/audit/workpapers', Icons.description),
      ],
    ),
    'analytics': _ServiceConfig(
      title: 'التحليلات',
      subtitle: 'تدفقات · موازنات · صحة · عملات · ربحية',
      icon: Icons.analytics,
      color: 0xFF00BCD4,
      flow: ['/analytics/cash-flow-forecast', '/analytics/health-score-v2', '/analytics/budget-builder', '/analytics/budget-variance-v2'],
      sections: [
        _Section('السيولة والتدفق',
          icon: Icons.water_drop,
          color: 0xFF2196F3,
          tiles: [
            _Tile('توقع التدفق النقدي', '90 يوم + Runway', '/analytics/cash-flow-forecast', Icons.show_chart),
            _Tile('متابعة العملات', 'FX exposure', '/analytics/multi-currency-v2', Icons.currency_exchange),
            _Tile('المحفظة الاستثمارية', 'Donut chart', '/analytics/investment-portfolio-v2', Icons.savings),
          ]),
        _Section('الموازنات والانحرافات',
          icon: Icons.calculate,
          color: 0xFFFFC107,
          tiles: [
            _Tile('بناء الموازنة', '12 شهر + AI', '/analytics/budget-builder', Icons.calculate),
            _Tile('انحراف الموازنة', 'IBCS variance bars', '/analytics/budget-variance-v2', Icons.trending_up),
            _Tile('انحراف التكاليف', 'Material/Labour/OH', '/analytics/cost-variance-v2', Icons.precision_manufacturing),
          ]),
        _Section('الأداء والربحية',
          icon: Icons.trending_up,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('Health Score', 'Radial gauge — 6 أبعاد', '/analytics/health-score-v2', Icons.health_and_safety),
            _Tile('ربحية المشاريع', 'P&L per project', '/analytics/project-profitability', Icons.engineering),
          ]),
      ],
      tiles: [
        _Tile('توقع التدفق النقدي', '90 يوم + شهور التشغيل', '/analytics/cash-flow-forecast', Icons.show_chart, featured: true),
        _Tile('Health Score', 'Radial gauge — 6 أبعاد', '/analytics/health-score-v2', Icons.health_and_safety, featured: true),
        _Tile('بناء الموازنة', '12 شهر + AI', '/analytics/budget-builder', Icons.calculate),
        _Tile('انحراف الموازنة', 'IBCS variance bars', '/analytics/budget-variance-v2', Icons.trending_up),
        _Tile('متابعة العملات', 'FX exposure', '/analytics/multi-currency-v2', Icons.currency_exchange),
        _Tile('المحفظة الاستثمارية', 'Donut chart', '/analytics/investment-portfolio-v2', Icons.savings),
        _Tile('ربحية المشاريع', 'P&L per project', '/analytics/project-profitability', Icons.engineering),
        _Tile('انحراف التكاليف', 'Material/Labour/OH', '/analytics/cost-variance-v2', Icons.precision_manufacturing),
      ],
    ),
    'hr-hub': _ServiceConfig(
      title: 'الموارد البشرية',
      subtitle: 'الموظفون · الرواتب · GOSI · سعودة',
      icon: Icons.people,
      color: 0xFF8BC34A,
      heroRoute: '/hr/employees',
      heroLabel: 'افتح قائمة الموظفين + Saudization',
      flow: ['/hr/employees', '/hr/timesheet', '/hr/payroll-run', '/hr/expense-reports'],
      sections: [
        _Section('المدخلات',
          icon: Icons.input,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('سجل ساعات العمل', 'Weekly timesheet', '/hr/timesheet', Icons.access_time),
            _Tile('تقارير المصاريف', 'Expense workflow', '/hr/expense-reports', Icons.receipt_long),
          ]),
        _Section('الدفاتر',
          icon: Icons.menu_book,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('قائمة الموظفين', 'مع Saudization tier', '/hr/employees', Icons.badge),
          ]),
        _Section('المخرجات — رواتب + GOSI',
          icon: Icons.assessment,
          color: 0xFFFFC107,
          tiles: [
            _Tile('تشغيل الرواتب', 'GOSI + Saudization', '/hr/payroll-run', Icons.payments),
            _Tile('حاسبة GOSI / GPSSA', 'KSA 10/12% · UAE 5/12.5%', '/hr/gosi', Icons.calculate),
            _Tile('مكافأة نهاية الخدمة', 'EOSB — KSA Art.84-85 · UAE Art.51-52', '/hr/eosb', Icons.logout),
            _Tile('قائمة القيود', 'JE من الرواتب', '/app/erp/finance/je-builder', Icons.book),
          ]),
      ],
      tiles: [
        _Tile('الموظفون', 'مع Saudization tier', '/hr/employees', Icons.badge, featured: true),
        _Tile('تشغيل الرواتب', 'GOSI + Saudization', '/hr/payroll-run', Icons.payments, featured: true),
        _Tile('حاسبة GOSI / GPSSA', 'حساب فوري للاشتراكات', '/hr/gosi', Icons.calculate, featured: true),
        _Tile('مكافأة نهاية الخدمة', 'EOSB Calculator', '/hr/eosb', Icons.logout, featured: true),
        _Tile('سجل ساعات العمل', 'Weekly timesheet', '/hr/timesheet', Icons.access_time),
        _Tile('تقارير المصاريف', 'Expense workflow', '/hr/expense-reports', Icons.receipt_long),
      ],
    ),
    'workflow-hub': _ServiceConfig(
      title: 'سير العمل والمعرفة',
      subtitle: 'الموافقات · AI · المعرفة · Copilot',
      icon: Icons.account_tree,
      color: 0xFF673AB7,
      flow: ['/copilot', '/admin/ai-suggestions-v2', '/workflow/approvals', '/knowledge/search'],
      sections: [
        _Section('الذكاء الاصطناعي',
          icon: Icons.psychology,
          color: 0xFF673AB7,
          tiles: [
            _Tile('Copilot', 'Ask APEX بالعربي', '/copilot', Icons.smart_toy),
            _Tile('اقتراحات AI', 'Confidence-Gated', '/admin/ai-suggestions-v2', Icons.lightbulb_outline),
          ]),
        _Section('الموافقات',
          icon: Icons.inbox,
          color: 0xFFFFC107,
          tiles: [
            _Tile('صندوق الموافقات', 'Multi-step queue', '/workflow/approvals', Icons.inbox),
          ]),
        _Section('المعرفة',
          icon: Icons.menu_book,
          color: 0xFF2196F3,
          tiles: [
            _Tile('قاعدة المعرفة', 'بحث في الأدلة', '/knowledge/search', Icons.menu_book),
          ]),
      ],
      tiles: [
        _Tile('صندوق الموافقات', 'Multi-step queue', '/workflow/approvals', Icons.inbox, featured: true),
        _Tile('اقتراحات AI', 'Confidence-Gated', '/admin/ai-suggestions-v2', Icons.lightbulb_outline, featured: true),
        _Tile('قاعدة المعرفة', 'بحث في الأدلة', '/knowledge/search', Icons.menu_book),
        _Tile('Copilot', 'Ask APEX بالعربي', '/copilot', Icons.smart_toy, featured: true),
      ],
    ),
    'settings-hub': _ServiceConfig(
      title: 'الإعدادات',
      subtitle: 'الحساب · الكيان · التكاملات · البنوك',
      icon: Icons.settings,
      color: 0xFF795548,
      flow: ['/onboarding', '/settings/unified', '/settings/bank-feeds'],
      sections: [
        _Section('إعداد الكيان',
          icon: Icons.business_center,
          color: 0xFF4CAF50,
          tiles: [
            _Tile('Onboarding Wizard', 'إعداد شركة + قالب CoA', '/onboarding', Icons.business_center),
          ]),
        _Section('الإعدادات الموحّدة',
          icon: Icons.tune,
          color: 0xFF2196F3,
          tiles: [
            _Tile('الإعدادات الموحّدة', '5 sections', '/settings/unified', Icons.tune),
          ]),
        _Section('التكاملات',
          icon: Icons.hub,
          color: 0xFF9C27B0,
          tiles: [
            _Tile('ربط البنوك', '11 بنك سعودي', '/settings/bank-feeds', Icons.account_balance),
          ]),
      ],
      tiles: [
        _Tile('الإعدادات الموحّدة', '5 sections', '/settings/unified', Icons.tune, featured: true),
        _Tile('ربط البنوك', '11 بنك سعودي', '/settings/bank-feeds', Icons.account_balance, featured: true),
        _Tile('إعداد الكيان', 'Onboarding wizard', '/onboarding', Icons.business_center),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final config = _services[serviceId];
    if (config == null) {
      return Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Text('خدمة غير معروفة', style: TextStyle(color: AC.gold)),
        ),
        body: Center(child: Text('Service "$serviceId" not found',
            style: TextStyle(color: AC.err))),
      );
    }
    final color = Color(config.color);
    final featured = config.tiles.where((t) => t.featured).toList();
    final others = config.tiles.where((t) => !t.featured).toList();
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text(config.title, style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.apps, color: AC.gold),
            tooltip: 'Launchpad',
            onPressed: () => context.go('/launchpad'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _heroCard(context, config, color),
          if (config.flow.isNotEmpty) ...[
            const SizedBox(height: 14),
            _flowChain(context, config, color),
          ],
          // Sections take precedence over featured/others when present.
          if (config.sections.isNotEmpty) ...[
            for (final s in config.sections) ...[
              const SizedBox(height: 18),
              _sectionHeader(s),
              const SizedBox(height: 8),
              _tilesGrid(context, s.tiles, Color(s.color)),
            ],
          ] else ...[
            if (featured.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('الأكثر استخداماً',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _tilesGrid(context, featured, color),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('الأدوات الإضافية',
                  style: TextStyle(color: AC.ts, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _tilesGrid(context, others, color),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(_Section section) {
    final color = Color(section.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), AC.navy3],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border(
          right: BorderSide(color: color, width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(section.icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(section.title,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${section.tiles.length}',
              style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _heroCard(BuildContext context, _ServiceConfig config, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(config.title,
                  style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(config.subtitle,
                  style: TextStyle(color: AC.ts, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${config.tiles.length}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ),
        ]),
        if (config.heroRoute != null) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.go(config.heroRoute!),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(config.heroLabel ?? 'افتح'),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
          ),
        ],
      ]),
    );
  }

  /// Visualizes the canonical input → output flow for the service.
  /// Each step is a clickable chip; arrows separate them.
  Widget _flowChain(BuildContext context, _ServiceConfig config, Color color) {
    final steps = <Widget>[];
    for (var i = 0; i < config.flow.length; i++) {
      final route = config.flow[i];
      final tile = config.tiles.firstWhere(
        (t) => t.route == route,
        orElse: () => _Tile(route, '', route, Icons.circle_outlined),
      );
      final isFirst = i == 0;
      final isLast = i == config.flow.length - 1;
      final stageLabel = isFirst ? 'مدخلات' : (isLast ? 'مخرجات' : 'معالجة');
      final stageColor = isFirst
          ? const Color(0xFF4CAF50)
          : (isLast ? const Color(0xFFFFC107) : color);
      steps.add(InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AC.navy2,
            border: Border.all(color: stageColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(tile.icon, color: stageColor, size: 14),
              const SizedBox(width: 6),
              Text(tile.title,
                  style: TextStyle(color: AC.tp, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 2),
            Text(stageLabel,
                style: TextStyle(color: stageColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ));
      if (!isLast) {
        steps.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_back, color: color.withValues(alpha: 0.6), size: 16),
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timeline, color: color, size: 14),
          const SizedBox(width: 6),
          Text('تدفق العمل — المدخلات تربط بالمخرجات',
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(children: steps),
        ),
      ]),
    );
  }

  Widget _tilesGrid(BuildContext context, List<_Tile> tiles, Color color) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: tiles.map((t) => _tileCard(context, t, color)).toList(),
    );
  }

  Widget _tileCard(BuildContext context, _Tile tile, Color color) {
    return InkWell(
      onTap: () => context.go(tile.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(
              color: tile.featured ? color.withValues(alpha: 0.5) : AC.bdr,
              width: tile.featured ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(tile.icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tile.title,
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(tile.subtitle,
                    style: TextStyle(color: AC.ts, fontSize: 10.5),
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
