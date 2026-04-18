/// APEX V4 — Module Hierarchy Data (Wave 1.5).
///
/// Source of truth for the V4 Module Hierarchy Map:
///   6 Module Groups → 46 Sub-Modules → ~320 Screens.
///
/// This file is intentionally pure data (no widgets, no I/O) so the
/// shell components can be rendered, tested, and tree-shaken without
/// importing UI dependencies.
///
/// See blueprints/APEX_V4_Module_Hierarchy.txt for the full narrative.
library;

import 'package:flutter/material.dart';

import 'v4_groups_data.dart';

/// Stable identifier for screen telemetry. Never renames once shipped —
/// analytics pipelines key on these strings.
typedef ScreenId = String;

/// A single screen slot inside a sub-module. Visible tabs render in the
/// TabBar row; overflow entries go under the "More ▾" popover.
@immutable
class V4Screen {
  /// Stable, URL-safe id. Format: `{group}-{sub}-{screen}` lowercased.
  final ScreenId id;

  /// Human-readable Arabic label shown in the tab.
  final String labelAr;

  /// Short English label for bilingual users / copy/paste search.
  final String labelEn;

  /// Icon shown in the "More ▾" popover and as a chip when pinned.
  final IconData icon;

  /// RBAC capability required to see this screen. Null = everyone who
  /// can see the sub-module. Format: `{group}.{sub}.{screen}.view`.
  final String? requiredCapability;

  /// Set to true when the screen is shipping behind a feature flag.
  /// Shell reads `flagsDisabled` from user prefs to hide unreleased tabs.
  final String? featureFlag;

  const V4Screen({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    this.requiredCapability,
    this.featureFlag,
  });
}

/// A functional area inside a module group (Sales, Workpapers, Ratios, …).
/// Sub-modules are the sidebar items; screens are the tabs.
@immutable
class V4SubModule {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final String descriptionAr;

  /// Up to ~5 screens rendered as visible tabs. Order is the default;
  /// users can reorder and pin/unpin via per-user prefs.
  final List<V4Screen> visibleTabs;

  /// Overflow screens in the "More ▾" popover. Can be pinned up to
  /// visibleTabs by user.
  final List<V4Screen> overflow;

  const V4SubModule({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.descriptionAr,
    required this.visibleTabs,
    this.overflow = const [],
  });

  /// All screens regardless of visible/overflow position — useful for
  /// command palette + deep-link resolution.
  List<V4Screen> get allScreens => [...visibleTabs, ...overflow];
}

/// A top-level card on the Launchpad (ERP, Audit, Feas, …).
@immutable
class V4ModuleGroup {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;

  /// Brand colour used for the Launchpad card, the sidebar header,
  /// and the status ribbon at the top of every sub-module.
  final Color color;

  final String descriptionAr;
  final List<V4SubModule> subModules;

  const V4ModuleGroup({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.color,
    required this.descriptionAr,
    required this.subModules,
  });

  V4SubModule? subModuleById(String id) {
    for (final s in subModules) {
      if (s.id == id) return s;
    }
    return null;
  }
}

// ── Screen definitions ────────────────────────────────────────────────

// Keep these const so the whole registry is a compile-time graph.
// The IDs mirror the "snake-hyphen" slug used in URLs.

const _erpSales = V4SubModule(
  id: 'sales',
  labelAr: 'المبيعات',
  labelEn: 'Sales & AR',
  icon: Icons.trending_up,
  descriptionAr: 'دورة الإيرادات — عروض، فواتير، مدفوعات، كشوف حساب.',
  visibleTabs: [
    V4Screen(
      id: 'erp-sales-customers',
      labelAr: 'العملاء',
      labelEn: 'Customers',
      icon: Icons.people_alt_outlined,
    ),
    V4Screen(
      id: 'erp-sales-invoices',
      labelAr: 'الفواتير',
      labelEn: 'Invoices',
      icon: Icons.receipt_long_outlined,
    ),
    V4Screen(
      id: 'erp-sales-payments',
      labelAr: 'المدفوعات',
      labelEn: 'Payments',
      icon: Icons.account_balance_wallet_outlined,
    ),
    V4Screen(
      id: 'erp-sales-statements',
      labelAr: 'كشوف الحساب',
      labelEn: 'Statements',
      icon: Icons.description_outlined,
    ),
    V4Screen(
      id: 'erp-sales-quotes',
      labelAr: 'عروض الأسعار',
      labelEn: 'Quotes',
      icon: Icons.request_quote_outlined,
    ),
  ],
  overflow: [
    V4Screen(
      id: 'erp-sales-credit-notes',
      labelAr: 'إشعارات دائنة',
      labelEn: 'Credit Notes',
      icon: Icons.undo,
    ),
    V4Screen(
      id: 'erp-sales-recurring',
      labelAr: 'فواتير متكررة',
      labelEn: 'Recurring Invoices',
      icon: Icons.repeat,
    ),
    V4Screen(
      id: 'erp-sales-price-lists',
      labelAr: 'قوائم الأسعار',
      labelEn: 'Price Lists',
      icon: Icons.price_change_outlined,
    ),
    V4Screen(
      id: 'erp-sales-aging',
      labelAr: 'تقرير الأعمار',
      labelEn: 'Aging Report',
      icon: Icons.hourglass_bottom,
    ),
    V4Screen(
      id: 'erp-sales-settings',
      labelAr: 'الإعدادات',
      labelEn: 'Sales Settings',
      icon: Icons.settings,
    ),
  ],
);

const _erpDashboard = V4SubModule(
  id: 'dashboard',
  labelAr: 'اللوحة الرئيسية',
  labelEn: 'Dashboard',
  icon: Icons.dashboard_outlined,
  descriptionAr: 'نظرة شاملة على كل وحدات ERP: KPIs، تنبيهات، نشاط حديث.',
  visibleTabs: [
    V4Screen(id: 'erp-dash-overview', labelAr: 'نظرة عامة', labelEn: 'Overview', icon: Icons.insights),
    V4Screen(id: 'erp-dash-kpis', labelAr: 'المؤشرات', labelEn: 'KPIs', icon: Icons.leaderboard),
    V4Screen(id: 'erp-dash-alerts', labelAr: 'التنبيهات', labelEn: 'Alerts', icon: Icons.notifications_active_outlined),
    V4Screen(id: 'erp-dash-activity', labelAr: 'النشاط', labelEn: 'Activity', icon: Icons.timeline),
    V4Screen(id: 'erp-dash-calendar', labelAr: 'التقويم', labelEn: 'Calendar', icon: Icons.calendar_month),
  ],
);

const _erpGl = V4SubModule(
  id: 'gl',
  labelAr: 'دفتر الأستاذ',
  labelEn: 'General Ledger',
  icon: Icons.account_tree_outlined,
  descriptionAr: 'شجرة الحسابات، قيود اليومية، ميزان المراجعة، القوائم المالية.',
  visibleTabs: [
    V4Screen(id: 'erp-gl-coa', labelAr: 'شجرة الحسابات', labelEn: 'CoA Tree', icon: Icons.account_tree),
    V4Screen(id: 'erp-gl-journals', labelAr: 'قيود اليومية', labelEn: 'Journals', icon: Icons.menu_book),
    V4Screen(id: 'erp-gl-tb', labelAr: 'ميزان المراجعة', labelEn: 'Trial Balance', icon: Icons.balance),
    V4Screen(id: 'erp-gl-fs', labelAr: 'القوائم المالية', labelEn: 'Financial Statements', icon: Icons.summarize),
    V4Screen(id: 'erp-gl-close', labelAr: 'إقفال الفترة', labelEn: 'Period Close', icon: Icons.lock_clock),
  ],
);

const _erpPurchasing = V4SubModule(
  id: 'purchasing',
  labelAr: 'المشتريات',
  labelEn: 'Purchasing & AP',
  icon: Icons.shopping_cart_outlined,
  descriptionAr: 'دورة المشتريات — موردون، أوامر شراء، فواتير واردة، مطابقة ثلاثية.',
  visibleTabs: [
    V4Screen(id: 'erp-pur-vendors', labelAr: 'الموردون', labelEn: 'Vendors', icon: Icons.store),
    V4Screen(id: 'erp-pur-pos', labelAr: 'أوامر الشراء', labelEn: 'Purchase Orders', icon: Icons.assignment),
    V4Screen(id: 'erp-pur-bills', labelAr: 'الفواتير الواردة', labelEn: 'Bills', icon: Icons.receipt),
    V4Screen(id: 'erp-pur-payments', labelAr: 'المدفوعات', labelEn: 'Payments', icon: Icons.payments),
    V4Screen(id: 'erp-pur-grn', labelAr: 'إشعارات الاستلام', labelEn: 'Goods Receipts', icon: Icons.inventory),
  ],
);

const _erpTreasury = V4SubModule(
  id: 'treasury',
  labelAr: 'الخزينة والبنوك',
  labelEn: 'Treasury & Banking',
  icon: Icons.account_balance_outlined,
  descriptionAr: 'حسابات بنكية، تدفقات، مطابقة، تنبؤ نقدي، صرف عملات.',
  visibleTabs: [
    V4Screen(id: 'erp-tre-accounts', labelAr: 'الحسابات البنكية', labelEn: 'Bank Accounts', icon: Icons.account_balance),
    V4Screen(id: 'erp-tre-txns', labelAr: 'الحركات', labelEn: 'Transactions', icon: Icons.swap_vert),
    V4Screen(id: 'erp-tre-rec', labelAr: 'المطابقة', labelEn: 'Reconciliation', icon: Icons.check_circle_outline),
    V4Screen(id: 'erp-tre-cashflow', labelAr: 'التدفق النقدي', labelEn: 'Cash Flow', icon: Icons.waterfall_chart),
    V4Screen(id: 'erp-tre-fx', labelAr: 'أسعار الصرف', labelEn: 'FX Rates', icon: Icons.currency_exchange),
  ],
);

const _erpHr = V4SubModule(
  id: 'hr',
  labelAr: 'الموارد البشرية والرواتب',
  labelEn: 'HR & Payroll',
  icon: Icons.groups_outlined,
  descriptionAr: 'موظفون، رواتب، إجازات، GOSI/WPS، مكافأة نهاية الخدمة.',
  visibleTabs: [
    V4Screen(id: 'erp-hr-employees', labelAr: 'الموظفون', labelEn: 'Employees', icon: Icons.badge),
    V4Screen(id: 'erp-hr-org', labelAr: 'الهيكل التنظيمي', labelEn: 'Org Chart', icon: Icons.schema),
    V4Screen(id: 'erp-hr-payroll', labelAr: 'الرواتب', labelEn: 'Payroll Runs', icon: Icons.payments_outlined),
    V4Screen(id: 'erp-hr-leaves', labelAr: 'الإجازات', labelEn: 'Leaves', icon: Icons.event_available),
    V4Screen(id: 'erp-hr-attendance', labelAr: 'الدوام', labelEn: 'Attendance', icon: Icons.schedule),
  ],
);

const _erpReports = V4SubModule(
  id: 'reports',
  labelAr: 'التقارير والتحليلات',
  labelEn: 'Reports & Analytics',
  icon: Icons.assessment_outlined,
  descriptionAr: 'تقارير مالية وتشغيلية، بناء مخصص، جدولة إرسال.',
  visibleTabs: [
    V4Screen(id: 'erp-rep-financial', labelAr: 'المالية', labelEn: 'Financial', icon: Icons.pie_chart),
    V4Screen(id: 'erp-rep-operational', labelAr: 'التشغيلية', labelEn: 'Operational', icon: Icons.bar_chart),
    V4Screen(id: 'erp-rep-builder', labelAr: 'بناء تقرير', labelEn: 'Custom Builder', icon: Icons.edit_note),
    V4Screen(id: 'erp-rep-scheduled', labelAr: 'مجدولة', labelEn: 'Scheduled', icon: Icons.alarm),
    V4Screen(id: 'erp-rep-templates', labelAr: 'القوالب', labelEn: 'Templates', icon: Icons.dashboard_customize),
  ],
);

// Remaining ERP sub-modules defined as lightweight stubs for the pilot;
// their visibleTabs are from V4 tables but no overflow is populated yet.
const _erpInventory = V4SubModule(
  id: 'inventory',
  labelAr: 'المخزون',
  labelEn: 'Inventory',
  icon: Icons.inventory_2_outlined,
  descriptionAr: 'أصناف، مستودعات، حركات، جرد دوري.',
  visibleTabs: [
    V4Screen(id: 'erp-inv-items', labelAr: 'الأصناف', labelEn: 'Items', icon: Icons.category),
    V4Screen(id: 'erp-inv-stock', labelAr: 'الرصيد الحالي', labelEn: 'Stock On-Hand', icon: Icons.inventory),
    V4Screen(id: 'erp-inv-moves', labelAr: 'الحركات', labelEn: 'Stock Moves', icon: Icons.swap_horiz),
    V4Screen(id: 'erp-inv-warehouses', labelAr: 'المستودعات', labelEn: 'Warehouses', icon: Icons.warehouse),
    V4Screen(id: 'erp-inv-counts', labelAr: 'الجرد', labelEn: 'Cycle Counts', icon: Icons.checklist),
  ],
);

const _erpProjects = V4SubModule(
  id: 'projects',
  labelAr: 'المشاريع',
  labelEn: 'Projects',
  icon: Icons.folder_outlined,
  descriptionAr: 'مشاريع، مهام، جداول زمنية، موازنات.',
  visibleTabs: [
    V4Screen(id: 'erp-prj-list', labelAr: 'المشاريع', labelEn: 'Projects', icon: Icons.folder),
    V4Screen(id: 'erp-prj-tasks', labelAr: 'المهام', labelEn: 'Tasks', icon: Icons.check_box_outlined),
    V4Screen(id: 'erp-prj-time', labelAr: 'الوقت', labelEn: 'Timesheets', icon: Icons.access_time),
    V4Screen(id: 'erp-prj-gantt', labelAr: 'الجانت', labelEn: 'Gantt', icon: Icons.view_timeline),
    V4Screen(id: 'erp-prj-billing', labelAr: 'الفوترة', labelEn: 'Billing', icon: Icons.receipt_long),
  ],
);

const _erpCrm = V4SubModule(
  id: 'crm',
  labelAr: 'إدارة علاقات العملاء',
  labelEn: 'CRM',
  icon: Icons.contact_mail_outlined,
  descriptionAr: 'عملاء محتملون، فرص، خط بيع، حملات.',
  visibleTabs: [
    V4Screen(id: 'erp-crm-leads', labelAr: 'العملاء المحتملون', labelEn: 'Leads', icon: Icons.person_add),
    V4Screen(id: 'erp-crm-opps', labelAr: 'الفرص', labelEn: 'Opportunities', icon: Icons.emoji_events),
    V4Screen(id: 'erp-crm-pipeline', labelAr: 'خط البيع', labelEn: 'Pipeline', icon: Icons.view_kanban),
    V4Screen(id: 'erp-crm-activities', labelAr: 'الأنشطة', labelEn: 'Activities', icon: Icons.event_note),
    V4Screen(id: 'erp-crm-contacts', labelAr: 'جهات الاتصال', labelEn: 'Contacts', icon: Icons.contacts),
  ],
);

const _erpZatca = V4SubModule(
  id: 'zatca',
  labelAr: 'ZATCA والضرائب',
  labelEn: 'ZATCA & Tax',
  icon: Icons.verified_outlined,
  descriptionAr: 'الفوترة الإلكترونية، إقرارات، ضريبة استقطاع، شهادات.',
  visibleTabs: [
    V4Screen(id: 'erp-zat-clearance', labelAr: 'التخليص', labelEn: 'E-Invoice Clearance', icon: Icons.verified),
    V4Screen(id: 'erp-zat-vat', labelAr: 'إقرار VAT', labelEn: 'VAT Return', icon: Icons.request_page),
    V4Screen(id: 'erp-zat-wht', labelAr: 'ضريبة الاستقطاع', labelEn: 'Withholding Tax', icon: Icons.percent),
    V4Screen(id: 'erp-zat-certs', labelAr: 'الشهادات', labelEn: 'Certificates', icon: Icons.card_membership),
    V4Screen(id: 'erp-zat-log', labelAr: 'سجل التقديم', labelEn: 'Filings Log', icon: Icons.history),
  ],
);

const _erpModuleGroup = V4ModuleGroup(
  id: 'erp',
  labelAr: 'نظام ERP',
  labelEn: 'ERP System',
  icon: Icons.apps,
  color: Color(0xFFD97706), // amber-600
  descriptionAr: 'العمود الفقري التشغيلي — محاسبة، مبيعات، مشتريات، مخزون.',
  subModules: [
    _erpDashboard,
    _erpGl,
    _erpSales,
    _erpPurchasing,
    _erpInventory,
    _erpTreasury,
    _erpHr,
    _erpProjects,
    _erpCrm,
    _erpZatca,
    _erpReports,
  ],
);

// ── Remaining 5 groups as headers only for the Launchpad ──
// Full sub-module breakdowns will land in follow-up PRs when each
// group gets real screens wired. This keeps Wave 1.5 scope bounded.

const _auditGroup = V4ModuleGroup(
  id: 'audit',
  labelAr: 'التدقيق والمراجعة',
  labelEn: 'Audit & Review',
  icon: Icons.fact_check_outlined,
  color: Color(0xFF2563EB), // blue-600
  descriptionAr: 'دورة ارتباط تدقيق كاملة بمعايير CaseWare: تخطيط، مخاطر، أوراق عمل.',
  subModules: auditSubModules,
);

const _feasGroup = V4ModuleGroup(
  id: 'feas',
  labelAr: 'دراسات الجدوى',
  labelEn: 'Feasibility Studies',
  icon: Icons.insights,
  color: Color(0xFF7C3AED), // violet-600
  descriptionAr: 'دورة كاملة لدراسات الجدوى من الفكرة إلى تقرير القرار.',
  subModules: feasSubModules,
);

const _externalGroup = V4ModuleGroup(
  id: 'external',
  labelAr: 'التحليل المالي الخارجي',
  labelEn: 'External Financial Analysis',
  icon: Icons.analytics_outlined,
  color: Color(0xFF0891B2), // cyan-600
  descriptionAr: 'تحليل منشآت من بياناتها المنشورة: نسب، مقارنات، تقييم، ائتمان.',
  subModules: externalSubModules,
);

const _providersGroup = V4ModuleGroup(
  id: 'providers',
  labelAr: 'مقدمو الخدمات المهنية',
  labelEn: 'Service Providers',
  icon: Icons.store_mall_directory_outlined,
  color: Color(0xFFDB2777), // pink-600
  descriptionAr: 'سوق ذو جانبين: العملاء يطلبون خدمات، المهنيون ينفذون.',
  subModules: providersSubModules,
);

const _complianceGroup = V4ModuleGroup(
  id: 'compliance',
  labelAr: 'الامتثال والأهلية',
  labelEn: 'Eligibility & Compliance',
  icon: Icons.policy_outlined,
  color: Color(0xFF059669), // emerald-600
  descriptionAr: 'مركز الحوكمة — ZATCA، GOSI، WPS، AML، إفصاحات مجلس.',
  subModules: complianceSubModules,
);

/// The canonical list of module groups — renders the Launchpad in order.
const List<V4ModuleGroup> v4ModuleGroups = [
  _erpModuleGroup,
  _auditGroup,
  _feasGroup,
  _externalGroup,
  _providersGroup,
  _complianceGroup,
];

/// Lookup a group by its short id (`erp`, `audit`, …). Case-insensitive.
V4ModuleGroup? v4GroupById(String id) {
  final needle = id.toLowerCase();
  for (final g in v4ModuleGroups) {
    if (g.id == needle) return g;
  }
  return null;
}

/// Find any screen by its stable id across ALL groups and sub-modules.
/// Used by the command palette and deep-link resolver.
V4Screen? v4ScreenById(ScreenId id) {
  for (final g in v4ModuleGroups) {
    for (final s in g.subModules) {
      for (final scr in s.allScreens) {
        if (scr.id == id) return scr;
      }
    }
  }
  return null;
}
