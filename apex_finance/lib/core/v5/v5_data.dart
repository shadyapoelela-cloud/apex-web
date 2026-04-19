/// APEX V5.1 — Hierarchy data (V4 Blueprint restructure).
///
/// 6 Services × 51 Apps (V5MainModules) × ~170 Chips.
///
/// **ERP = 16 Apps** (per V4 INTEGRATION_PLAN_V2.md blueprint):
///   1.1 Finance (GL)        1.9  HR & Payroll
///   1.2 Consolidation       1.10 Projects & Jobs
///   1.3 Treasury & Banking  1.11 CRM & Marketing
///   1.4 Sales & AR          1.12 Manufacturing
///   1.5 Purchasing & AP     1.13 Hotel PMS
///   1.6 Expenses            1.14 Construction
///   1.7 POS                 1.15 Industry Packs
///   1.8 Inventory & Cost    1.16 Reports & BI
///
/// Horizontal layer (NOT chips): Cmd+K, AI Copilot, Live Bell,
/// Knowledge search, Entity Scope Selector — rendered once in shell.
///
/// Each chip maps either to a V4SubModule (reusing existing tabs) OR
/// to a dashboard definition (new in V5).
library;

import 'package:flutter/material.dart';

import '../v4/v4_groups.dart';
import 'v5_models.dart';

// ──────────────────────────────────────────────────────────────────────
// Dashboard widget templates — reused across services.
// ──────────────────────────────────────────────────────────────────────

const _financeDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'فواتير متأخرة > 90 يوم',
    labelEn: 'Overdue invoices > 90 days',
    icon: Icons.warning_amber,
    kind: V5WidgetKind.actionList,
    actionRoute: '/app/erp/sales/ar?filter=overdue-90',
    actionLabelAr: 'أرسل تذكير للكل',
    dataEndpoint: '/ar/aging?bucket=90+',
    severity: V5WidgetSeverity.critical,
  ),
  V5DashboardWidget(
    labelAr: 'متوسط فترة التحصيل',
    labelEn: 'Days Sales Outstanding',
    icon: Icons.schedule,
    kind: V5WidgetKind.kpi,
    dataEndpoint: '/analytics/dso',
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'الرصيد النقدي',
    labelEn: 'Cash position',
    icon: Icons.account_balance_wallet,
    kind: V5WidgetKind.kpi,
    dataEndpoint: '/analytics/cash-position',
    severity: V5WidgetSeverity.success,
  ),
  V5DashboardWidget(
    labelAr: 'قيود تنتظر الاعتماد',
    labelEn: 'Journal entries pending approval',
    icon: Icons.rule,
    kind: V5WidgetKind.actionList,
    actionRoute: '/app/erp/finance/gl?filter=pending',
    actionLabelAr: 'راجع الكل',
    dataEndpoint: '/ai/guardrails/stats',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'أعمار الذمم المدينة',
    labelEn: 'AR Aging breakdown',
    icon: Icons.bar_chart,
    kind: V5WidgetKind.chart,
    dataEndpoint: '/ar/aging',
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'لقطة الأرباح والخسائر',
    labelEn: 'P&L snapshot',
    icon: Icons.trending_up,
    kind: V5WidgetKind.chart,
    dataEndpoint: '/fin-statements/pnl-snapshot',
    severity: V5WidgetSeverity.info,
  ),
];

const _treasuryDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'معاملات بنكية غير مطابقة',
    labelEn: 'Unmatched bank transactions',
    icon: Icons.compare_arrows,
    kind: V5WidgetKind.actionList,
    actionRoute: '/app/erp/treasury/recon?t=ai',
    actionLabelAr: 'طابق باستخدام الذكاء',
    dataEndpoint: '/bank-feeds/stats',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'إجمالي الأرصدة البنكية',
    labelEn: 'Total bank balances',
    icon: Icons.account_balance,
    kind: V5WidgetKind.kpi,
    dataEndpoint: '/bank-feeds/stats',
    severity: V5WidgetSeverity.success,
  ),
  V5DashboardWidget(
    labelAr: 'توقّع التدفق النقدي (13 أسبوع)',
    labelEn: '13-week cash forecast',
    icon: Icons.timeline,
    kind: V5WidgetKind.chart,
    dataEndpoint: '/cashflow/forecast',
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'تعرّض العملات الأجنبية',
    labelEn: 'FX exposure',
    icon: Icons.currency_exchange,
    kind: V5WidgetKind.kpi,
    dataEndpoint: '/fx/exposure',
    severity: V5WidgetSeverity.info,
  ),
];

const _complianceDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'فواتير زاتكا فشلت — تحتاج معالجة',
    labelEn: 'ZATCA failed invoices',
    icon: Icons.error_outline,
    kind: V5WidgetKind.actionList,
    actionRoute: '/app/compliance/zatca/queue?t=giveup',
    actionLabelAr: 'عرض القائمة',
    dataEndpoint: '/zatca/queue/stats',
    severity: V5WidgetSeverity.critical,
  ),
  V5DashboardWidget(
    labelAr: 'شهادات CSID قريبة الانتهاء',
    labelEn: 'CSIDs expiring soon (≤30d)',
    icon: Icons.badge,
    kind: V5WidgetKind.actionList,
    actionRoute: '/app/compliance/zatca/csid?t=expiring',
    actionLabelAr: 'جدّد الآن',
    dataEndpoint: '/zatca/csid/expiring-soon',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'إقرار ضريبة القيمة المضافة التالي',
    labelEn: 'Next VAT return due',
    icon: Icons.event,
    kind: V5WidgetKind.kpi,
    dataEndpoint: '/tax/vat/next-deadline',
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'درجة الامتثال',
    labelEn: 'Compliance Score',
    icon: Icons.verified_user,
    kind: V5WidgetKind.kpi,
    dataEndpoint: '/compliance/score',
    severity: V5WidgetSeverity.success,
  ),
];

const _salesDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'فرص مفتوحة في خط الأنابيب',
    labelEn: 'Open pipeline opportunities',
    icon: Icons.filter_alt,
    kind: V5WidgetKind.kpi,
    actionRoute: '/app/erp/crm-marketing/pipeline',
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'فواتير صدرت اليوم',
    labelEn: 'Invoices issued today',
    icon: Icons.receipt,
    kind: V5WidgetKind.kpi,
    actionRoute: '/app/erp/sales/invoices',
    severity: V5WidgetSeverity.success,
  ),
  V5DashboardWidget(
    labelAr: 'عملاء جُدد هذا الشهر',
    labelEn: 'New customers this month',
    icon: Icons.person_add,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
];

const _purchasingDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'أوامر شراء تنتظر الاعتماد',
    labelEn: 'POs pending approval',
    icon: Icons.pending_actions,
    kind: V5WidgetKind.actionList,
    actionRoute: '/app/erp/purchasing/requisitions',
    actionLabelAr: 'اعتمد',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'فواتير موردين غير مدفوعة',
    labelEn: 'Unpaid vendor bills',
    icon: Icons.receipt_long,
    kind: V5WidgetKind.kpi,
    actionRoute: '/app/erp/purchasing/ap',
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'موردون يحتاجون تجديد عقد',
    labelEn: 'Suppliers needing contract renewal',
    icon: Icons.autorenew,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.warning,
  ),
];

const _inventoryDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'أصناف تحتاج إعادة طلب',
    labelEn: 'Items needing reorder',
    icon: Icons.warning,
    kind: V5WidgetKind.actionList,
    actionLabelAr: 'أنشئ أوامر شراء',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'أصناف منتهية الصلاحية',
    labelEn: 'Expired items',
    icon: Icons.event_busy,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.critical,
  ),
  V5DashboardWidget(
    labelAr: 'قيمة المخزون الحالية',
    labelEn: 'Current inventory value',
    icon: Icons.inventory,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
];

const _hrDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'إجازات معلّقة',
    labelEn: 'Pending leaves',
    icon: Icons.event_available,
    kind: V5WidgetKind.actionList,
    actionLabelAr: 'اعتمد',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'عدد الموظفين',
    labelEn: 'Headcount',
    icon: Icons.groups,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'إجمالي راتب الشهر',
    labelEn: 'Monthly payroll',
    icon: Icons.payments,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.success,
  ),
];

const _projectsDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'مشاريع نشطة',
    labelEn: 'Active projects',
    icon: Icons.work,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'مشاريع متأخرة عن الجدول',
    labelEn: 'Projects behind schedule',
    icon: Icons.schedule,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.critical,
  ),
  V5DashboardWidget(
    labelAr: 'الاستغلال الحالي للموارد',
    labelEn: 'Current resource utilization',
    icon: Icons.insights,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
];

const _manufacturingDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'أوامر إنتاج نشطة',
    labelEn: 'Active production orders',
    icon: Icons.precision_manufacturing,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'اختناقات في قائمة المواد',
    labelEn: 'BOM bottlenecks',
    icon: Icons.warning,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.critical,
  ),
  V5DashboardWidget(
    labelAr: 'معدل جودة الخط',
    labelEn: 'Line quality rate',
    icon: Icons.verified,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.success,
  ),
];

const _posDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'مبيعات اليوم',
    labelEn: 'Sales today',
    icon: Icons.point_of_sale,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.success,
  ),
  V5DashboardWidget(
    labelAr: 'فروع نشطة',
    labelEn: 'Active outlets',
    icon: Icons.storefront,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'جلسات مفتوحة',
    labelEn: 'Open shifts',
    icon: Icons.schedule,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.warning,
  ),
];

const _reportsDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'تقارير جاهزة',
    labelEn: 'Ready reports',
    icon: Icons.assessment,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'لوحات مخصصة',
    labelEn: 'Custom dashboards',
    icon: Icons.dashboard_customize,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'درجة الاستدامة ESG',
    labelEn: 'ESG Score',
    icon: Icons.eco,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.success,
  ),
];

const _consolidationDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'كيانات مشمولة',
    labelEn: 'Entities consolidated',
    icon: Icons.merge,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
  V5DashboardWidget(
    labelAr: 'معاملات بين الشركات تنتظر التسوية',
    labelEn: 'Intercompany open items',
    icon: Icons.sync_alt,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'حقوق الملكية',
    labelEn: 'Equity position',
    icon: Icons.donut_large,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.success,
  ),
];

const _expensesDashboardWidgets = <V5DashboardWidget>[
  V5DashboardWidget(
    labelAr: 'مطالبات تنتظر الاعتماد',
    labelEn: 'Claims pending approval',
    icon: Icons.pending_actions,
    kind: V5WidgetKind.actionList,
    actionLabelAr: 'راجع',
    severity: V5WidgetSeverity.warning,
  ),
  V5DashboardWidget(
    labelAr: 'مطالبات خارج السياسة',
    labelEn: 'Policy violations',
    icon: Icons.report_problem,
    kind: V5WidgetKind.actionList,
    severity: V5WidgetSeverity.critical,
  ),
  V5DashboardWidget(
    labelAr: 'إنفاق الشهر',
    labelEn: 'Month-to-date spend',
    icon: Icons.account_balance_wallet,
    kind: V5WidgetKind.kpi,
    severity: V5WidgetSeverity.info,
  ),
];

// ──────────────────────────────────────────────────────────────────────
// Helper — convert V4SubModule into V5Chip.
// ──────────────────────────────────────────────────────────────────────

V5Chip _chipFromV4(String v4GroupId, String v4SubId, {
  String? labelOverrideAr,
  IconData? iconOverride,
}) {
  final group = v4GroupById(v4GroupId);
  final sub = group?.subModuleById(v4SubId);
  if (sub == null) {
    // Placeholder — sub-module not yet in v4_groups_data.
    return V5Chip(
      id: v4SubId,
      labelAr: labelOverrideAr ?? v4SubId,
      labelEn: v4SubId,
      icon: iconOverride ?? Icons.help_outline,
    );
  }
  return V5Chip(
    id: sub.id,
    labelAr: labelOverrideAr ?? sub.labelAr,
    labelEn: sub.labelEn,
    icon: iconOverride ?? sub.icon,
    subModule: sub,
  );
}

V5Chip _dashboardChip({
  required String id,
  required String labelAr,
  required String labelEn,
  required IconData icon,
  required List<V5DashboardWidget> widgets,
}) =>
    V5Chip(
      id: id,
      labelAr: labelAr,
      labelEn: labelEn,
      icon: icon,
      isDashboard: true,
      dashboardWidgets: widgets,
    );

// ──────────────────────────────────────────────────────────────────────
// The 6 V5 Services.
// ──────────────────────────────────────────────────────────────────────

List<V5Service> v5Services = [
  // ── Service 1: ERP — 16 Apps (V4 Blueprint restructure) ─────────────
  V5Service(
    id: 'erp',
    labelAr: 'المحاسبة والعمليات',
    labelEn: 'ERP',
    icon: Icons.business_center,
    color: const Color(0xFFD4AF37), // Gold
    descriptionAr: 'العمليات اليومية — 16 تطبيق متخصص',
    mainModules: [
      // 1.1 Finance (GL) — #1 in Middle East target
      // 25 chips organized by 4-phase journey:
      // Dashboard → Master Data → Transactions → Period Close → Reporting → Setup
      V5MainModule(
        id: 'finance',
        labelAr: 'المحاسبة المالية',
        labelEn: 'Finance (GL)',
        icon: Icons.bar_chart,
        descriptionAr: 'دفتر أستاذ شامل، قمرة إقفال ذكية، قوائم مالية بـ4 إصدارات، AI عربي',
        group: AppGroup.core,
        chips: [
          // ━━━ Dashboard ━━━
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المالية',
            labelEn: 'Finance Dashboard',
            icon: Icons.dashboard,
            widgets: _financeDashboardWidgets,
          ),

          // ━━━ Master Data (5) ━━━
          const V5Chip(id: 'coa-editor', labelAr: 'دليل الحسابات', labelEn: 'Chart of Accounts', icon: Icons.account_tree, phase: ChipPhase.setup),
          const V5Chip(id: 'cost-centers', labelAr: 'مراكز التكلفة', labelEn: 'Cost Centers', icon: Icons.pie_chart, phase: ChipPhase.setup),
          const V5Chip(id: 'profit-centers', labelAr: 'مراكز الربحية', labelEn: 'Profit Centers', icon: Icons.donut_small, phase: ChipPhase.setup),
          const V5Chip(id: 'internal-orders', labelAr: 'الأوامر الداخلية', labelEn: 'Internal Orders', icon: Icons.assignment_turned_in, phase: ChipPhase.setup),
          const V5Chip(id: 'dimensions', labelAr: 'الأبعاد المحاسبية', labelEn: 'Accounting Dimensions', icon: Icons.view_in_ar, phase: ChipPhase.setup),

          // ━━━ Transactions (5) ━━━
          _chipFromV4('erp', 'gl', labelOverrideAr: 'الأستاذ الشامل'),
          const V5Chip(id: 'je-builder', labelAr: 'قيود اليومية', labelEn: 'Journal Entries', icon: Icons.edit_note, phase: ChipPhase.capture),
          const V5Chip(id: 'recurring-entries', labelAr: 'القيود الدورية', labelEn: 'Recurring Entries', icon: Icons.repeat, phase: ChipPhase.capture),
          const V5Chip(id: 'fixed-assets', labelAr: 'الأصول الثابتة', labelEn: 'Fixed Assets', icon: Icons.business, phase: ChipPhase.capture),
          const V5Chip(id: 'ai-reconciliation', labelAr: 'المطابقات الذكية', labelEn: 'AI Reconciliation', icon: Icons.auto_fix_high, phase: ChipPhase.capture),

          // ━━━ Period Close (3) ━━━
          const V5Chip(id: 'period-close', labelAr: 'قمرة الإقفال 🎯', labelEn: 'Closing Cockpit', icon: Icons.lock_clock, phase: ChipPhase.process),
          const V5Chip(id: 'workflows', labelAr: 'مسارات الاعتماد', labelEn: 'Approval Workflows', icon: Icons.approval, phase: ChipPhase.process),
          const V5Chip(id: 'anomalies', labelAr: 'كاشف الشذوذ AI', labelEn: 'AI Anomaly Detector', icon: Icons.psychology, phase: ChipPhase.process),

          // ━━━ Reporting (7) ━━━
          const V5Chip(id: 'statements', labelAr: 'القوائم المالية', labelEn: 'Financial Statements', icon: Icons.insert_chart, phase: ChipPhase.report),
          const V5Chip(id: 'ai-analyst', labelAr: 'المحلل المالي AI 🎉', labelEn: 'AI Financial Analyst', icon: Icons.auto_awesome, phase: ChipPhase.report),
          const V5Chip(id: 'budgets', labelAr: 'الموازنات', labelEn: 'Budgets', icon: Icons.pie_chart, phase: ChipPhase.report),
          const V5Chip(id: 'budget-actual', labelAr: 'الموازنة مقابل الفعلي', labelEn: 'Budget vs Actual', icon: Icons.compare_arrows, phase: ChipPhase.report),
          const V5Chip(id: 'budget-planning', labelAr: 'تخطيط الموازنات', labelEn: 'Budget Planning', icon: Icons.account_tree, phase: ChipPhase.report),
          const V5Chip(id: 'scenarios', labelAr: 'سيناريوهات What-If', labelEn: 'What-If Scenarios', icon: Icons.insights, phase: ChipPhase.report),
          const V5Chip(id: 'breakeven', labelAr: 'نقطة التعادل', labelEn: 'Break-Even', icon: Icons.balance, phase: ChipPhase.report),

          // ━━━ Setup (4) ━━━
          const V5Chip(id: 'documents', labelAr: 'خزانة الوثائق', labelEn: 'Document Vault', icon: Icons.folder_shared, phase: ChipPhase.setup),
          const V5Chip(id: 'integrations', labelAr: 'التكاملات API', labelEn: 'Integrations Hub', icon: Icons.hub, phase: ChipPhase.setup),
          const V5Chip(id: 'onboarding', labelAr: 'رحلة الإعداد', labelEn: 'Onboarding', icon: Icons.auto_awesome, phase: ChipPhase.setup),
          const V5Chip(id: 'advanced-settings', labelAr: 'إعدادات متقدّمة', labelEn: 'Advanced Settings', icon: Icons.settings_applications, phase: ChipPhase.setup),
        ],
      ),

      // 1.2 Consolidation — multi-entity rollup (NEW)
      V5MainModule(
        id: 'consolidation',
        labelAr: 'التوحيد والكيانات',
        labelEn: 'Consolidation',
        icon: Icons.merge,
        group: AppGroup.core,
        descriptionAr: 'توحيد كيانات متعددة، معاملات بين الشركات، هيكل الملكية',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة التوحيد',
            labelEn: 'Consolidation Dashboard',
            icon: Icons.dashboard,
            widgets: _consolidationDashboardWidgets,
          ),
          const V5Chip(id: 'consolidation', labelAr: 'التوحيد', labelEn: 'Consolidation', icon: Icons.merge),
          const V5Chip(id: 'intercompany', labelAr: 'المعاملات بين الشركات', labelEn: 'Intercompany', icon: Icons.sync_alt),
          const V5Chip(id: 'cap-table', labelAr: 'هيكل الملكية', labelEn: 'Cap Table', icon: Icons.donut_large),
          const V5Chip(id: 'board', labelAr: 'بوابة المجلس', labelEn: 'Board Portal', icon: Icons.account_balance),
          const V5Chip(id: 'ma-deal-room', labelAr: 'غرفة صفقات M&A', labelEn: 'M&A Deal Room', icon: Icons.handshake),
        ],
      ),

      // 1.3 Treasury & Banking — unchanged
      V5MainModule(
        id: 'treasury',
        labelAr: 'الخزينة والبنوك',
        labelEn: 'Treasury & Banking',
        icon: Icons.account_balance,
        group: AppGroup.core,
        descriptionAr: 'البنوك، المطابقة، التدفق النقدي، صرف العملات',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة الخزينة',
            labelEn: 'Treasury Dashboard',
            icon: Icons.dashboard,
            widgets: _treasuryDashboardWidgets,
          ),
          _chipFromV4('erp', 'tre', labelOverrideAr: 'البنوك'),
          const V5Chip(id: 'recon', labelAr: 'المطابقة البنكية', labelEn: 'Reconciliation', icon: Icons.compare_arrows),
          const V5Chip(id: 'cashflow', labelAr: 'التدفق النقدي', labelEn: 'Cash Flow', icon: Icons.waterfall_chart),
          const V5Chip(id: 'fx', labelAr: 'صرف العملات', labelEn: 'FX', icon: Icons.currency_exchange),
          const V5Chip(id: 'guarantees', labelAr: 'الضمانات والاعتمادات', labelEn: 'Guarantees & L/Cs', icon: Icons.verified_user),
          const V5Chip(id: 'investments', labelAr: 'محفظة الاستثمار', labelEn: 'Investment Portfolio', icon: Icons.show_chart),
        ],
      ),

      // 1.4 Sales & AR
      V5MainModule(
        id: 'sales',
        labelAr: 'المبيعات والذمم المدينة',
        labelEn: 'Sales & AR',
        icon: Icons.point_of_sale,
        group: AppGroup.businessCycles,
        descriptionAr: 'دورة المبيعات، الفواتير، الذمم، الأسعار، العقود',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المبيعات',
            labelEn: 'Sales Dashboard',
            icon: Icons.dashboard,
            widgets: _salesDashboardWidgets,
          ),
          _chipFromV4('erp', 'sales', labelOverrideAr: 'حسابات القبض'),
          const V5Chip(id: 'sales-workflow', labelAr: 'دورة المبيعات', labelEn: 'Sales Workflow', icon: Icons.point_of_sale),
          const V5Chip(id: 'invoices', labelAr: 'الفواتير', labelEn: 'Invoices', icon: Icons.receipt),
          const V5Chip(id: 'credit-notes', labelAr: 'إشعارات الدائن', labelEn: 'Credit Notes', icon: Icons.assignment_return),
          const V5Chip(id: 'price-list', labelAr: 'قائمة الأسعار', labelEn: 'Price List', icon: Icons.price_change),
          const V5Chip(id: 'contracts', labelAr: 'العقود', labelEn: 'Contracts', icon: Icons.gavel),
          const V5Chip(id: 'subscription-billing', labelAr: 'فوترة الاشتراكات', labelEn: 'Subscription Billing', icon: Icons.autorenew),
          const V5Chip(id: 'credit', labelAr: 'التصنيف الائتماني', labelEn: 'Credit Scoring', icon: Icons.credit_score),
        ],
      ),

      // 1.5 Purchasing & AP
      V5MainModule(
        id: 'purchasing',
        labelAr: 'المشتريات والذمم الدائنة',
        labelEn: 'Purchasing & AP',
        icon: Icons.shopping_cart,
        group: AppGroup.businessCycles,
        descriptionAr: 'الموردون، طلبات الشراء، عروض الأسعار، المدفوعات',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المشتريات',
            labelEn: 'Purchasing Dashboard',
            icon: Icons.dashboard,
            widgets: _purchasingDashboardWidgets,
          ),
          const V5Chip(id: 'ap', labelAr: 'حسابات الدفع', labelEn: 'Accounts Payable', icon: Icons.receipt_long),
          const V5Chip(id: 'suppliers', labelAr: 'المورّدون 360°', labelEn: 'Suppliers 360°', icon: Icons.store),
          const V5Chip(id: 'vendor-onboarding', labelAr: 'إدخال مورد', labelEn: 'Vendor Onboarding', icon: Icons.person_add),
          const V5Chip(id: 'requisitions', labelAr: 'طلبات الشراء', labelEn: 'Purchase Requisitions', icon: Icons.shopping_cart),
          const V5Chip(id: 'procurement-rfq', labelAr: 'عروض الأسعار RFQ', labelEn: 'Procurement RFQ', icon: Icons.request_quote),
        ],
      ),

      // 1.6 Expenses & Reimbursements (NEW)
      V5MainModule(
        id: 'expenses',
        labelAr: 'المصروفات والتعويضات',
        labelEn: 'Expenses',
        icon: Icons.receipt,
        group: AppGroup.businessCycles,
        descriptionAr: 'مطالبات الموظفين، البطاقات، السفر، السياسات',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المصروفات',
            labelEn: 'Expenses Dashboard',
            icon: Icons.dashboard,
            widgets: _expensesDashboardWidgets,
          ),
          const V5Chip(id: 'expenses', labelAr: 'مطالبات المصروفات', labelEn: 'Expense Claims', icon: Icons.receipt),
          const V5Chip(id: 'corporate-cards', labelAr: 'بطاقات الشركة', labelEn: 'Corporate Cards', icon: Icons.credit_card),
          const V5Chip(id: 'travel', labelAr: 'السفر والإقامة', labelEn: 'Travel & Per Diem', icon: Icons.flight),
        ],
      ),

      // 1.7 POS (NEW — first-class)
      V5MainModule(
        id: 'pos',
        labelAr: 'نقاط البيع',
        labelEn: 'Point of Sale',
        icon: Icons.point_of_sale,
        group: AppGroup.businessCycles,
        descriptionAr: 'نقاط البيع للمطاعم والتجزئة والخدمات',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة نقاط البيع',
            labelEn: 'POS Dashboard',
            icon: Icons.dashboard,
            widgets: _posDashboardWidgets,
          ),
          const V5Chip(id: 'restaurant-pos', labelAr: 'نقاط بيع المطاعم 🎉', labelEn: 'Restaurant POS', icon: Icons.restaurant),
          const V5Chip(id: 'retail-pos', labelAr: 'نقاط بيع التجزئة', labelEn: 'Retail POS', icon: Icons.storefront),
          const V5Chip(id: 'service-pos', labelAr: 'نقاط بيع الخدمات', labelEn: 'Service POS', icon: Icons.room_service),
        ],
      ),

      // 1.8 Inventory & Cost
      V5MainModule(
        id: 'inventory',
        labelAr: 'المخزون والتكلفة',
        labelEn: 'Inventory & Cost',
        icon: Icons.inventory_2,
        group: AppGroup.operations,
        descriptionAr: 'المستودعات، الأصناف، التتبع، الأسطول، الضمانات',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المخزون',
            labelEn: 'Inventory Dashboard',
            icon: Icons.dashboard,
            widgets: _inventoryDashboardWidgets,
          ),
          const V5Chip(id: 'inventory', labelAr: 'المخزون', labelEn: 'Inventory', icon: Icons.inventory),
          const V5Chip(id: 'warehouse', labelAr: 'إدارة المستودعات', labelEn: 'Warehouse Mgmt', icon: Icons.warehouse),
          const V5Chip(id: 'asset-tracking', labelAr: 'تتبع الأصول (RFID)', labelEn: 'Asset Tracking', icon: Icons.qr_code_scanner),
          const V5Chip(id: 'fleet', labelAr: 'الأسطول', labelEn: 'Fleet', icon: Icons.local_shipping),
          const V5Chip(id: 'warranty', labelAr: 'الضمانات والخدمة', labelEn: 'Warranty & Service', icon: Icons.verified),
        ],
      ),

      // 1.9 HR & Payroll — unchanged
      V5MainModule(
        id: 'hr',
        labelAr: 'الموارد البشرية والرواتب',
        labelEn: 'HR & Payroll',
        icon: Icons.people,
        group: AppGroup.resources,
        descriptionAr: 'الموظفون، الرواتب، الإجازات، GOSI/WPS',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة الموارد البشرية',
            labelEn: 'HR Dashboard',
            icon: Icons.dashboard,
            widgets: _hrDashboardWidgets,
          ),
          const V5Chip(id: 'employees', labelAr: 'الموظفون', labelEn: 'Employees', icon: Icons.person),
          const V5Chip(id: 'payroll', labelAr: 'الرواتب', labelEn: 'Payroll', icon: Icons.payments),
          const V5Chip(id: 'leaves', labelAr: 'الإجازات', labelEn: 'Leaves', icon: Icons.event),
          const V5Chip(id: 'benefits', labelAr: 'المزايا', labelEn: 'Benefits', icon: Icons.health_and_safety),
          const V5Chip(id: 'commissions', labelAr: 'العمولات', labelEn: 'Commissions', icon: Icons.emoji_events),
          const V5Chip(id: 'self-service', labelAr: 'بوابة الموظف', labelEn: 'ESS Portal', icon: Icons.person_pin),
          const V5Chip(id: 'training', labelAr: 'التدريب والأكاديمية', labelEn: 'Training & LMS', icon: Icons.school),
          const V5Chip(id: 'performance', labelAr: 'تقييم الأداء', labelEn: 'Performance Reviews', icon: Icons.trending_up),
          const V5Chip(id: 'recruitment', labelAr: 'التوظيف ATS', labelEn: 'Recruitment', icon: Icons.person_search),
          const V5Chip(id: 'wellness', labelAr: 'صحة الموظفين', labelEn: 'Wellness', icon: Icons.favorite),
        ],
      ),

      // 1.10 Projects & Jobs
      V5MainModule(
        id: 'projects',
        labelAr: 'المشاريع والمهام',
        labelEn: 'Projects & Jobs',
        icon: Icons.work,
        group: AppGroup.resources,
        descriptionAr: 'إدارة المشاريع، ربحية العمل، الموارد، الفوترة بالمراحل',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المشاريع',
            labelEn: 'Projects Dashboard',
            icon: Icons.dashboard,
            widgets: _projectsDashboardWidgets,
          ),
          const V5Chip(id: 'projects', labelAr: 'المشاريع', labelEn: 'Projects', icon: Icons.work),
          const V5Chip(id: 'project-pnl', labelAr: 'ربحية المشاريع', labelEn: 'Project P&L', icon: Icons.analytics),
          const V5Chip(id: 'tickets', labelAr: 'تذاكر الدعم', labelEn: 'Helpdesk', icon: Icons.support_agent),
          const V5Chip(id: 'resource-allocation', labelAr: 'تخصيص الموارد', labelEn: 'Resource Allocation', icon: Icons.group_work),
          const V5Chip(id: 'milestone-billing', labelAr: 'فوترة المراحل', labelEn: 'Milestone Billing', icon: Icons.flag),
        ],
      ),

      // 1.11 CRM & Marketing
      V5MainModule(
        id: 'crm-marketing',
        labelAr: 'علاقات العملاء والتسويق',
        labelEn: 'CRM & Marketing',
        icon: Icons.contacts,
        group: AppGroup.resources,
        descriptionAr: 'إدارة العملاء، الأنبوب، الحملات، الولاء، التواصل',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة CRM والتسويق',
            labelEn: 'CRM Dashboard',
            icon: Icons.dashboard,
            widgets: _salesDashboardWidgets,
          ),
          const V5Chip(id: 'crm', labelAr: 'إدارة العملاء', labelEn: 'CRM', icon: Icons.contacts),
          const V5Chip(id: 'customers-360', labelAr: 'العميل 360°', labelEn: 'Customer 360°', icon: Icons.person_pin_circle),
          const V5Chip(id: 'pipeline', labelAr: 'أنبوب المبيعات', labelEn: 'Sales Pipeline', icon: Icons.filter_alt),
          const V5Chip(id: 'marketing', labelAr: 'أتمتة التسويق', labelEn: 'Marketing Automation', icon: Icons.campaign),
          const V5Chip(id: 'loyalty', labelAr: 'برنامج الولاء 🎉', labelEn: 'Loyalty Program', icon: Icons.loyalty),
          const V5Chip(id: 'whatsapp', labelAr: 'WhatsApp Business 🎉', labelEn: 'WhatsApp Business', icon: Icons.chat),
        ],
      ),

      // 1.12 Manufacturing (first-class)
      V5MainModule(
        id: 'manufacturing',
        labelAr: 'التصنيع',
        labelEn: 'Manufacturing',
        icon: Icons.precision_manufacturing,
        group: AppGroup.operations,
        descriptionAr: 'أوامر الإنتاج، قائمة المواد، خط الإنتاج، الجودة',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة التصنيع',
            labelEn: 'Manufacturing Dashboard',
            icon: Icons.dashboard,
            widgets: _manufacturingDashboardWidgets,
          ),
          const V5Chip(id: 'manufacturing', labelAr: 'أوامر الإنتاج', labelEn: 'Production Orders', icon: Icons.precision_manufacturing),
          const V5Chip(id: 'bom-mrp', labelAr: 'قائمة المواد BOM/MRP', labelEn: 'BOM / MRP', icon: Icons.account_tree),
          const V5Chip(id: 'shop-floor', labelAr: 'إدارة خط الإنتاج', labelEn: 'Shop Floor', icon: Icons.factory),
        ],
      ),

      // 1.13 Hotel PMS (first-class)
      V5MainModule(
        id: 'hotel-pms',
        labelAr: 'إدارة الفنادق PMS',
        labelEn: 'Hotel PMS',
        icon: Icons.hotel,
        group: AppGroup.operations,
        descriptionAr: 'حجوزات، غرف، نزلاء، فوترة فندقية',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الفندق',
            labelEn: 'Hotel Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'hotel-pms', labelAr: 'إدارة الفندق', labelEn: 'Hotel PMS', icon: Icons.hotel),
        ],
      ),

      // 1.14 Construction (first-class)
      V5MainModule(
        id: 'construction',
        labelAr: 'مقاولات البناء',
        labelEn: 'Construction',
        icon: Icons.engineering,
        group: AppGroup.operations,
        descriptionAr: 'مشاريع إنشائية، مراحل، تكلفة، مطالبات',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة البناء',
            labelEn: 'Construction Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'construction', labelAr: 'مقاولات البناء', labelEn: 'Construction', icon: Icons.engineering),
        ],
      ),

      // 1.15 Industry Packs — simple verticals under one umbrella
      V5MainModule(
        id: 'industry-packs',
        labelAr: 'حزم القطاعات',
        labelEn: 'Industry Packs',
        icon: Icons.apps,
        group: AppGroup.operations,
        descriptionAr: 'قطاعات متخصصة — عقارات، صحة، تعليم، نقل، منح، امتياز، إلكترونيات، خدمة ميدانية',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة القطاعات',
            labelEn: 'Industry Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'real-estate', labelAr: 'إدارة العقارات', labelEn: 'Real Estate', icon: Icons.apartment),
          V5Chip(id: 'healthcare', labelAr: 'مطالبات صحية', labelEn: 'Healthcare Claims', icon: Icons.local_hospital),
          V5Chip(id: 'education', labelAr: 'إدارة المدارس', labelEn: 'Education SIS', icon: Icons.school),
          V5Chip(id: 'transport', labelAr: 'النقل واللوجستيات', labelEn: 'Transport TMS', icon: Icons.local_shipping),
          V5Chip(id: 'grants', labelAr: 'إدارة المنح (NGO)', labelEn: 'Grant Management', icon: Icons.volunteer_activism),
          V5Chip(id: 'franchise', labelAr: 'الامتياز التجاري', labelEn: 'Franchise', icon: Icons.store_mall_directory),
          V5Chip(id: 'ecommerce', labelAr: 'المتجر الإلكتروني', labelEn: 'E-Commerce', icon: Icons.shopping_bag),
          V5Chip(id: 'field-service', labelAr: 'الخدمة الميدانية', labelEn: 'Field Service', icon: Icons.engineering),
        ],
      ),

      // 1.16 Reports & BI
      V5MainModule(
        id: 'reports-bi',
        labelAr: 'التقارير والذكاء',
        labelEn: 'Reports & BI',
        icon: Icons.assessment,
        group: AppGroup.output,
        descriptionAr: 'التقارير الجاهزة، منشئ التقارير، لوحة التنفيذيين، OKRs، ESG',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة التقارير',
            labelEn: 'Reports Dashboard',
            icon: Icons.dashboard,
            widgets: _reportsDashboardWidgets,
          ),
          const V5Chip(id: 'reports', labelAr: 'التقارير', labelEn: 'Reports', icon: Icons.assessment),
          const V5Chip(id: 'custom-reports', labelAr: 'منشئ التقارير', labelEn: 'Report Builder', icon: Icons.dashboard_customize),
          const V5Chip(id: 'exec', labelAr: 'لوحة التنفيذيين', labelEn: 'Executive Dashboard', icon: Icons.star),
          const V5Chip(id: 'okrs', labelAr: 'الأهداف OKRs', labelEn: 'OKRs', icon: Icons.track_changes),
          const V5Chip(id: 'esg', labelAr: 'الاستدامة ESG', labelEn: 'ESG', icon: Icons.eco),
        ],
      ),
    ],
  ),

  // ── Service 2: Compliance & Tax — 7 apps ─────────────────────────────
  V5Service(
    id: 'compliance',
    labelAr: 'الامتثال والضرائب',
    labelEn: 'Compliance & Tax',
    icon: Icons.shield,
    color: const Color(0xFF2E7D5B), // Emerald
    descriptionAr: 'زاتكا، VAT، GOSI/WPS، AML، الحوكمة، الأمن، القانون',
    mainModules: [
      // 2.1 Tax Filings — core tax operations
      V5MainModule(
        id: 'tax',
        labelAr: 'الإقرارات الضريبية',
        labelEn: 'Tax Filings',
        icon: Icons.request_quote,
        descriptionAr: 'VAT، WHT، الزكاة، UAE CT، أسعار التحويل، تحسين الضرائب',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة الضرائب',
            labelEn: 'Tax Dashboard',
            icon: Icons.dashboard,
            widgets: _complianceDashboardWidgets,
          ),
          const V5Chip(id: 'vat', labelAr: 'ضريبة القيمة المضافة', labelEn: 'VAT', icon: Icons.percent),
          const V5Chip(id: 'vat-return', labelAr: 'إقرار VAT', labelEn: 'VAT Return', icon: Icons.description),
          const V5Chip(id: 'wht', labelAr: 'ضريبة الاستقطاع', labelEn: 'WHT', icon: Icons.money_off),
          const V5Chip(id: 'zakat', labelAr: 'الزكاة', labelEn: 'Zakat', icon: Icons.star),
          const V5Chip(id: 'uae_ct', labelAr: 'ضريبة الشركات الإماراتية', labelEn: 'UAE CT', icon: Icons.flag),
          const V5Chip(id: 'tp', labelAr: 'أسعار التحويل', labelEn: 'Transfer Pricing', icon: Icons.swap_horiz),
          const V5Chip(id: 'calendar', labelAr: 'الرزنامة الضريبية', labelEn: 'Tax Calendar', icon: Icons.calendar_month),
          const V5Chip(id: 'optimizer', labelAr: 'محاكي تحسين الضرائب', labelEn: 'Tax Optimizer', icon: Icons.savings),
          const V5Chip(id: 'filings', labelAr: 'مركز الإقرارات', labelEn: 'Filing Center', icon: Icons.folder_special),
        ],
      ),

      // 2.2 ZATCA E-Invoicing
      V5MainModule(
        id: 'zatca',
        labelAr: 'الفوترة الإلكترونية (زاتكا)',
        labelEn: 'ZATCA E-Invoicing',
        icon: Icons.receipt,
        descriptionAr: 'الإقرار، CSID، قائمة الانتظار، سجل الأخطاء',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة الفوترة',
            labelEn: 'ZATCA Dashboard',
            icon: Icons.dashboard,
            widgets: _complianceDashboardWidgets,
          ),
          _chipFromV4('compliance', 'zatca', labelOverrideAr: 'الإقرار'),
          const V5Chip(id: 'csid', labelAr: 'شهادات CSID', labelEn: 'CSID', icon: Icons.badge),
          _chipFromV4('compliance', 'zatca-queue', labelOverrideAr: 'قائمة الانتظار والإعادة'),
          const V5Chip(id: 'errors', labelAr: 'سجل الأخطاء', labelEn: 'Error Log', icon: Icons.error),
        ],
      ),

      // 2.3 IFRS Standards (NEW — split from tax)
      V5MainModule(
        id: 'ifrs',
        labelAr: 'معايير IFRS',
        labelEn: 'IFRS Standards',
        icon: Icons.menu_book,
        descriptionAr: 'IFRS 15 الإيراد، IFRS 16 الإيجارات، الضريبة المؤجلة IAS 12',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة IFRS',
            labelEn: 'IFRS Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'revenue-recognition', labelAr: 'الاعتراف بالإيراد IFRS 15', labelEn: 'Revenue Recognition', icon: Icons.receipt_long),
          V5Chip(id: 'leases', labelAr: 'الإيجارات IFRS 16', labelEn: 'Leases (IFRS 16)', icon: Icons.home_work),
          V5Chip(id: 'deferred', labelAr: 'الضريبة المؤجلة IAS 12', labelEn: 'Deferred Tax', icon: Icons.account_balance_wallet),
        ],
      ),

      // 2.4 Labor Compliance (GOSI + WPS)
      V5MainModule(
        id: 'labor',
        labelAr: 'الامتثال العمالي',
        labelEn: 'Labor Compliance',
        icon: Icons.work_outline,
        descriptionAr: 'التأمينات الاجتماعية، نظام حماية الأجور، التوطين',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة العمل',
            labelEn: 'Labor Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'gosi', labelAr: 'التأمينات الاجتماعية', labelEn: 'GOSI', icon: Icons.health_and_safety),
          V5Chip(id: 'wps', labelAr: 'نظام حماية الأجور', labelEn: 'WPS', icon: Icons.shield),
          V5Chip(id: 'saudization', labelAr: 'نسبة السعودة', labelEn: 'Saudization', icon: Icons.groups),
        ],
      ),

      // 2.5 AML & Ethics (NEW)
      V5MainModule(
        id: 'aml-ethics',
        labelAr: 'مكافحة الغسل والأخلاقيات',
        labelEn: 'AML & Ethics',
        icon: Icons.gpp_good,
        descriptionAr: 'AML/KYC، البلاغات الأخلاقية، سجل النشاط، العقوبات',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة AML',
            labelEn: 'AML Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'aml', labelAr: 'مكافحة غسل الأموال', labelEn: 'AML / KYC', icon: Icons.gavel),
          V5Chip(id: 'whistleblower', labelAr: 'البلاغات الأخلاقية', labelEn: 'Whistleblower', icon: Icons.shield_moon),
          V5Chip(id: 'activity-log', labelAr: 'سجل النشاط', labelEn: 'Activity Log', icon: Icons.history_edu),
          V5Chip(id: 'sanctions', labelAr: 'قائمة العقوبات', labelEn: 'Sanctions Screening', icon: Icons.block),
        ],
      ),

      // 2.6 Governance & Risk (NEW)
      V5MainModule(
        id: 'governance-risk',
        labelAr: 'الحوكمة والمخاطر',
        labelEn: 'Governance & Risk',
        icon: Icons.account_tree,
        descriptionAr: 'الحوكمة، سجل المخاطر، الجودة، الاستدامة ESG',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الحوكمة',
            labelEn: 'Governance Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'governance', labelAr: 'الحوكمة والمجلس', labelEn: 'Governance', icon: Icons.account_tree),
          V5Chip(id: 'risk-register', labelAr: 'سجل المخاطر', labelEn: 'Risk Register', icon: Icons.shield),
          V5Chip(id: 'quality', labelAr: 'إدارة الجودة QMS', labelEn: 'Quality Mgmt', icon: Icons.verified_user),
          V5Chip(id: 'sustainability', labelAr: 'تقارير الاستدامة ESG', labelEn: 'ESG Report', icon: Icons.eco),
        ],
      ),

      // 2.7 Legal & Continuity (NEW — combined Security+BCP+Legal)
      V5MainModule(
        id: 'legal-security',
        labelAr: 'القانون والأمن والاستمرارية',
        labelEn: 'Legal, Security & BCP',
        icon: Icons.gavel,
        descriptionAr: 'مراجعة العقود AI، أتمتة الوثائق، الأمن السيبراني، استمرارية الأعمال',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الأمن والقانون',
            labelEn: 'Security & Legal Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'legal-ai', labelAr: 'المراجعة القانونية AI', labelEn: 'Legal Contract AI', icon: Icons.gavel),
          V5Chip(id: 'legal-docs-automation', labelAr: 'أتمتة الوثائق القانونية', labelEn: 'Legal Docs Automation', icon: Icons.description),
          V5Chip(id: 'compliance-calendar', labelAr: 'رزنامة الامتثال', labelEn: 'Compliance Calendar', icon: Icons.event_note),
          V5Chip(id: 'cybersecurity', labelAr: 'الأمن السيبراني', labelEn: 'Cybersecurity', icon: Icons.security),
          V5Chip(id: 'bcp', labelAr: 'استمرارية الأعمال', labelEn: 'BCP / DR', icon: Icons.health_and_safety),
        ],
      ),
    ],
  ),

  // ── Service 3: Audit — 7 apps ───────────────────────────────────────
  V5Service(
    id: 'audit',
    labelAr: 'المراجعة',
    labelEn: 'Audit',
    icon: Icons.fact_check,
    color: const Color(0xFF4A148C), // Deep Purple
    descriptionAr: 'دورة المراجعة الكاملة — ارتباط، مخاطر، ميدان، ضوابط، تحليلات، رأي، جودة',
    mainModules: const [
      // 3.1 Engagement (Planning + Acceptance + Kickoff)
      V5MainModule(
        id: 'engagement',
        labelAr: 'الارتباط',
        labelEn: 'Engagement',
        icon: Icons.handshake,
        descriptionAr: 'القبول، التخطيط، مؤشرات البدء، تحديد النطاق',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الارتباط',
            labelEn: 'Engagement Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'acceptance', labelAr: 'القبول والاستقلالية', labelEn: 'Acceptance & Independence', icon: Icons.check_circle),
          V5Chip(id: 'planning', labelAr: 'التخطيط', labelEn: 'Audit Planning', icon: Icons.edit_calendar),
          V5Chip(id: 'kickoff', labelAr: 'البدء', labelEn: 'Kick-off', icon: Icons.rocket_launch),
          V5Chip(id: 'materiality', labelAr: 'الأهمية النسبية', labelEn: 'Materiality', icon: Icons.straighten),
        ],
      ),

      // 3.2 Risk Assessment (NEW standalone)
      V5MainModule(
        id: 'risk',
        labelAr: 'تقييم المخاطر',
        labelEn: 'Risk Assessment',
        icon: Icons.warning_amber,
        descriptionAr: 'مخاطر الاحتيال، الأخطاء الجوهرية، مخاطر التوقف',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة المخاطر',
            labelEn: 'Risk Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'risk', labelAr: 'تقييم المخاطر', labelEn: 'Risk Assessment', icon: Icons.warning),
          V5Chip(id: 'fraud-risk', labelAr: 'مخاطر الاحتيال', labelEn: 'Fraud Risk', icon: Icons.policy),
          V5Chip(id: 'going-concern', labelAr: 'الاستمرارية', labelEn: 'Going Concern', icon: Icons.trending_down),
        ],
      ),

      // 3.3 Workpapers (NEW — CaseWare-class)
      V5MainModule(
        id: 'workpapers',
        labelAr: 'أوراق العمل',
        labelEn: 'Workpapers',
        icon: Icons.folder_open,
        descriptionAr: 'توثيق الأدلة، مراجعة الفريق، ربط القوائم المالية',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة أوراق العمل',
            labelEn: 'Workpapers Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'workpapers', labelAr: 'أوراق العمل', labelEn: 'Workpapers', icon: Icons.folder),
          V5Chip(id: 'trial-balance-tie', labelAr: 'ربط ميزان المراجعة', labelEn: 'TB Tie-Out', icon: Icons.link),
          V5Chip(id: 'evidence', labelAr: 'إدارة الأدلة', labelEn: 'Evidence Library', icon: Icons.receipt_long),
        ],
      ),

      // 3.4 Controls Testing
      V5MainModule(
        id: 'controls',
        labelAr: 'اختبار الضوابط',
        labelEn: 'Controls Testing',
        icon: Icons.rule,
        descriptionAr: 'مكتبة الضوابط، اختبار التشغيل، إثبات التصميم',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الضوابط',
            labelEn: 'Controls Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'controls-library', labelAr: 'مكتبة الضوابط', labelEn: 'Controls Library', icon: Icons.security),
          V5Chip(id: 'control', labelAr: 'اختبار الضوابط', labelEn: 'Control Testing', icon: Icons.rule),
          V5Chip(id: 'walkthroughs', labelAr: 'جولات التشغيل', labelEn: 'Walkthroughs', icon: Icons.directions_walk),
        ],
      ),

      // 3.5 Audit Analytics (NEW — Inflo/MindBridge-class)
      V5MainModule(
        id: 'analytics',
        labelAr: 'تحليلات المراجعة',
        labelEn: 'Audit Analytics',
        icon: Icons.query_stats,
        descriptionAr: 'تحليل البيانات بالـ AI، اختبار 100%، كشف الشذوذ',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التحليلات',
            labelEn: 'Analytics Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'full-population', labelAr: 'اختبار 100% للمجتمع', labelEn: 'Full-Population Test', icon: Icons.all_inclusive),
          V5Chip(id: 'ai-anomalies', labelAr: 'شذوذات AI', labelEn: 'AI Anomalies', icon: Icons.psychology),
          V5Chip(id: 'journal-entry-testing', labelAr: 'اختبار قيود اليومية', labelEn: 'JE Testing', icon: Icons.edit_note),
        ],
      ),

      // 3.6 Opinion & Reporting
      V5MainModule(
        id: 'reporting',
        labelAr: 'الرأي وإصدار التقارير',
        labelEn: 'Opinion & Reporting',
        icon: Icons.description,
        descriptionAr: 'منشئ الرأي، رسالة الإدارة، تقرير المراجعة النهائي',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التقارير',
            labelEn: 'Reporting Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'opinion', labelAr: 'منشئ الرأي', labelEn: 'Opinion Builder', icon: Icons.gavel),
          V5Chip(id: 'ml', labelAr: 'رسالة الإدارة', labelEn: 'Management Letter', icon: Icons.mail),
          V5Chip(id: 'final-report', labelAr: 'التقرير النهائي', labelEn: 'Final Report', icon: Icons.picture_as_pdf),
        ],
      ),

      // 3.7 Quality Control (NEW)
      V5MainModule(
        id: 'quality',
        labelAr: 'ضبط الجودة',
        labelEn: 'Quality Control',
        icon: Icons.verified,
        descriptionAr: 'مراجعة النظير، EQCR، سياسات الجودة، ISQM 1',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة ضبط الجودة',
            labelEn: 'QC Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'qc', labelAr: 'ضمان الجودة', labelEn: 'QC Review', icon: Icons.verified),
          V5Chip(id: 'eqcr', labelAr: 'مراجع الجودة EQCR', labelEn: 'EQCR Review', icon: Icons.person_search),
          V5Chip(id: 'isqm1', labelAr: 'نظام الجودة ISQM 1', labelEn: 'ISQM 1 Monitoring', icon: Icons.policy),
        ],
      ),
    ],
  ),

  // ── Service 4: Advisory — 8 apps (Feasibility 4 + External 4) ─────
  V5Service(
    id: 'advisory',
    labelAr: 'الاستشارات',
    labelEn: 'Advisory',
    icon: Icons.analytics,
    color: const Color(0xFF1565C0), // Blue
    descriptionAr: 'دراسات جدوى، تقييم، تحليل خارجي، نسب، ائتمان، معايير IFRS',
    mainModules: const [
      // 4.1 Feasibility Studies
      V5MainModule(
        id: 'feasibility',
        labelAr: 'دراسات الجدوى',
        labelEn: 'Feasibility',
        icon: Icons.lightbulb,
        descriptionAr: 'تحليل السوق، القوائم التقديرية، التقييم، الحساسية',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة دراسات الجدوى',
            labelEn: 'Feasibility Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'market', labelAr: 'تحليل السوق', labelEn: 'Market Analysis', icon: Icons.query_stats),
          V5Chip(id: 'proforma', labelAr: 'القوائم التقديرية', labelEn: 'Pro-Forma', icon: Icons.calculate),
          V5Chip(id: 'sensitivity', labelAr: 'الحساسية', labelEn: 'Sensitivity', icon: Icons.tune),
          V5Chip(id: 'scenario', labelAr: 'السيناريوهات', labelEn: 'Scenario Analysis', icon: Icons.insights),
        ],
      ),

      // 4.2 Valuation (NEW — split from feasibility)
      V5MainModule(
        id: 'valuation',
        labelAr: 'نماذج التقييم',
        labelEn: 'Valuation Models',
        icon: Icons.monetization_on,
        descriptionAr: 'DCF، المضاعفات، LBO، تقييم الأسواق المقارنة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التقييم',
            labelEn: 'Valuation Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'valuation', labelAr: 'التقييم', labelEn: 'Valuation', icon: Icons.monetization_on),
          V5Chip(id: 'dcf', labelAr: 'التدفقات المخصومة DCF', labelEn: 'DCF Model', icon: Icons.show_chart),
          V5Chip(id: 'multiples', labelAr: 'المضاعفات', labelEn: 'Trading Multiples', icon: Icons.compare_arrows),
          V5Chip(id: 'lbo', labelAr: 'نموذج LBO', labelEn: 'LBO Model', icon: Icons.account_balance),
        ],
      ),

      // 4.3 External Upload & OCR
      V5MainModule(
        id: 'upload',
        labelAr: 'الرفع والقراءة',
        labelEn: 'Upload & OCR',
        icon: Icons.upload_file,
        descriptionAr: 'رفع القوائم المالية، تحليل PDF/Excel، استخراج ذكي',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الرفع',
            labelEn: 'Upload Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'upload', labelAr: 'الرفع والقراءة الضوئية', labelEn: 'Upload & OCR', icon: Icons.upload_file),
          V5Chip(id: 'parse-tb', labelAr: 'استخراج ميزان المراجعة', labelEn: 'TB Parser', icon: Icons.table_rows),
          V5Chip(id: 'classify', labelAr: 'تصنيف البنود', labelEn: 'Auto-Classify', icon: Icons.auto_fix_high),
        ],
      ),

      // 4.4 CoA Analyzer (AI) — first-class per user discussion
      V5MainModule(
        id: 'coa',
        labelAr: 'محلل دليل الحسابات AI',
        labelEn: 'CoA Analyzer (AI)',
        icon: Icons.account_tree,
        descriptionAr: 'فحص دليل الحسابات بالذكاء الاصطناعي، توصيات، ربط بـ IFRS',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة دليل الحسابات',
            labelEn: 'CoA Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'coa-analyzer', labelAr: 'محلل دليل الحسابات', labelEn: 'CoA Analyzer', icon: Icons.account_tree),
          V5Chip(id: 'coa-mapping', labelAr: 'ربط الحسابات بمعايير IFRS', labelEn: 'IFRS Mapping', icon: Icons.link),
          V5Chip(id: 'coa-cleanup', labelAr: 'تنظيف دليل الحسابات', labelEn: 'CoA Cleanup', icon: Icons.cleaning_services),
        ],
      ),

      // 4.5 Ratios & Benchmarking
      V5MainModule(
        id: 'ratios',
        labelAr: 'النسب والمقارنات',
        labelEn: 'Ratios & Benchmarking',
        icon: Icons.analytics,
        descriptionAr: '25 نسبة مالية، مقارنة قطاعية، أداء الصناعة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة النسب',
            labelEn: 'Ratios Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'ratios', labelAr: 'النسب المالية', labelEn: 'Financial Ratios', icon: Icons.analytics),
          V5Chip(id: 'benchmarking', labelAr: 'المقارنة المرجعية', labelEn: 'Benchmarking', icon: Icons.compare),
          V5Chip(id: 'industry', labelAr: 'أداء الصناعة', labelEn: 'Industry Performance', icon: Icons.factory),
        ],
      ),

      // 4.6 Credit Analysis
      V5MainModule(
        id: 'credit',
        labelAr: 'التحليل الائتماني',
        labelEn: 'Credit Analysis',
        icon: Icons.credit_score,
        descriptionAr: 'نموذج Altman Z، احتمال التعثر، تصنيف المخاطر',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الائتمان',
            labelEn: 'Credit Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'credit', labelAr: 'التحليل الائتماني', labelEn: 'Credit Analysis', icon: Icons.credit_score),
          V5Chip(id: 'altman-z', labelAr: 'نموذج Altman Z', labelEn: 'Altman Z-Score', icon: Icons.calculate),
          V5Chip(id: 'pd', labelAr: 'احتمال التعثر', labelEn: 'Probability of Default', icon: Icons.warning_amber),
        ],
      ),

      // 4.7 IFRS Tools — asset lifecycle + lease
      V5MainModule(
        id: 'ifrs-tools',
        labelAr: 'أدوات IFRS',
        labelEn: 'IFRS Tools',
        icon: Icons.menu_book,
        descriptionAr: 'أصول ثابتة، إهلاك، IFRS 16، معالجة الإيجارات',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة أدوات IFRS',
            labelEn: 'IFRS Tools Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'fixed_assets', labelAr: 'الأصول الثابتة', labelEn: 'Fixed Assets', icon: Icons.domain),
          V5Chip(id: 'depreciation', labelAr: 'الإهلاك', labelEn: 'Depreciation', icon: Icons.trending_down),
          V5Chip(id: 'lease', labelAr: 'عقود الإيجار (IFRS 16)', labelEn: 'Lease (IFRS 16)', icon: Icons.apartment),
        ],
      ),

      // 4.8 Financial Calculators
      V5MainModule(
        id: 'calculators',
        labelAr: 'الحاسبات المالية',
        labelEn: 'Financial Calculators',
        icon: Icons.calculate,
        descriptionAr: 'نقطة التعادل، NPV/IRR، DSCR، WACC',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الحاسبات',
            labelEn: 'Calculators Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'breakeven', labelAr: 'نقطة التعادل', labelEn: 'Break-Even', icon: Icons.balance),
          V5Chip(id: 'npv-irr', labelAr: 'NPV / IRR', labelEn: 'NPV / IRR', icon: Icons.timeline),
          V5Chip(id: 'dscr', labelAr: 'DSCR تغطية خدمة الدين', labelEn: 'DSCR Calculator', icon: Icons.account_balance_wallet),
          V5Chip(id: 'wacc', labelAr: 'التكلفة المرجحة WACC', labelEn: 'WACC Calculator', icon: Icons.percent),
        ],
      ),
    ],
  ),

  // ── Service 5: Marketplace — 6 apps (Client 3 + Provider 3) ───────
  V5Service(
    id: 'marketplace',
    labelAr: 'السوق',
    labelEn: 'Marketplace',
    icon: Icons.store,
    color: const Color(0xFFE65100), // Deep Orange
    descriptionAr: 'سوق مزدوج — عملاء يطلبون، مزوّدون يقدّمون، ضمان ومدفوعات',
    mainModules: const [
      // 5.1 Browse & Discover (Client)
      V5MainModule(
        id: 'browse',
        labelAr: 'تصفّح المزوّدين',
        labelEn: 'Browse Providers',
        icon: Icons.search,
        descriptionAr: 'البحث، APEX Match AI، التصفية، المقارنة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التصفّح',
            labelEn: 'Browse Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'browse', labelAr: 'تصفّح', labelEn: 'Browse', icon: Icons.search),
          V5Chip(id: 'apex-match', labelAr: 'ذكاء الاقتران APEX Match', labelEn: 'APEX Match AI', icon: Icons.auto_awesome),
          V5Chip(id: 'compare', labelAr: 'مقارنة المزوّدين', labelEn: 'Compare Providers', icon: Icons.compare),
        ],
      ),

      // 5.2 Client Requests (RFPs + Projects)
      V5MainModule(
        id: 'client',
        labelAr: 'طلبات العميل',
        labelEn: 'Client Requests',
        icon: Icons.assignment,
        descriptionAr: 'طلبات الخدمة، العروض، المشاريع المباشرة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الطلبات',
            labelEn: 'Requests Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'requests', labelAr: 'طلباتي', labelEn: 'My Requests', icon: Icons.assignment),
          V5Chip(id: 'proposals', labelAr: 'العروض المستلمة', labelEn: 'Proposals Received', icon: Icons.inbox),
          V5Chip(id: 'active-projects', labelAr: 'المشاريع الجارية', labelEn: 'Active Projects', icon: Icons.folder_open),
        ],
      ),

      // 5.3 Billing & Escrow (Client + Provider shared)
      V5MainModule(
        id: 'billing',
        labelAr: 'الفوترة والضمان',
        labelEn: 'Billing & Escrow',
        icon: Icons.account_balance_wallet,
        descriptionAr: 'ضمان المدفوعات، الفواتير، الاشتراكات، المدفوعات',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الفوترة',
            labelEn: 'Billing Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'billing', labelAr: 'الفوترة والضمان', labelEn: 'Billing & Escrow', icon: Icons.receipt_long),
          V5Chip(id: 'subscriptions', labelAr: 'الاشتراكات', labelEn: 'Subscriptions', icon: Icons.autorenew),
          V5Chip(id: 'disputes', labelAr: 'النزاعات', labelEn: 'Disputes', icon: Icons.gavel),
        ],
      ),

      // 5.4 Provider Profile
      V5MainModule(
        id: 'provider',
        labelAr: 'ملف المزوّد',
        labelEn: 'Provider Profile',
        icon: Icons.badge,
        descriptionAr: 'الملف التعريفي، الشهادات، الخبرات، المحفظة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة المزوّد',
            labelEn: 'Provider Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'profile', labelAr: 'ملفي', labelEn: 'My Profile', icon: Icons.person),
          V5Chip(id: 'certifications', labelAr: 'الشهادات', labelEn: 'Certifications', icon: Icons.verified),
          V5Chip(id: 'portfolio', labelAr: 'المحفظة', labelEn: 'Portfolio', icon: Icons.photo_library),
        ],
      ),

      // 5.5 Provider Jobs & Payouts
      V5MainModule(
        id: 'provider-ops',
        labelAr: 'عمليات المزوّد',
        labelEn: 'Provider Operations',
        icon: Icons.work,
        descriptionAr: 'المهام النشطة، سجل العمل، المدفوعات، الضرائب',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة العمليات',
            labelEn: 'Ops Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'jobs', labelAr: 'المهام النشطة', labelEn: 'Active Jobs', icon: Icons.work),
          V5Chip(id: 'payouts', labelAr: 'المدفوعات', labelEn: 'Payouts', icon: Icons.payments),
          V5Chip(id: 'tax-1099', labelAr: 'التقارير الضريبية', labelEn: 'Tax Reporting', icon: Icons.description),
        ],
      ),

      // 5.6 Ratings & Reviews
      V5MainModule(
        id: 'reviews',
        labelAr: 'التقييمات والمراجعات',
        labelEn: 'Ratings & Reviews',
        icon: Icons.star,
        descriptionAr: 'التقييمات من العملاء، الردود، السمعة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التقييمات',
            labelEn: 'Reviews Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'ratings', labelAr: 'التقييمات', labelEn: 'Ratings', icon: Icons.star),
          V5Chip(id: 'reviews-received', labelAr: 'مراجعات مستلمة', labelEn: 'Reviews Received', icon: Icons.rate_review),
          V5Chip(id: 'reputation', labelAr: 'سمعة المزوّد', labelEn: 'Reputation Score', icon: Icons.military_tech),
        ],
      ),
    ],
  ),
];

V5Service? v5ServiceById(String id) {
  for (final s in v5Services) {
    if (s.id == id) return s;
  }
  return null;
}

// ──────────────────────────────────────────────────────────────────────
// Workspaces (Level -1) — 5 role-based bundles.
// ──────────────────────────────────────────────────────────────────────

const v5Workspaces = <V5Workspace>[
  V5Workspace(
    id: 'cfo',
    labelAr: 'بيئة المدير المالي',
    labelEn: 'CFO Workspace',
    icon: Icons.person_pin,
    color: Color(0xFFD4AF37),
    descriptionAr: 'نظرة شاملة على الأداء المالي والامتثال والتنبؤات',
    shortcuts: [
      V5Shortcut(serviceId: 'erp', mainId: 'finance', chipId: 'dashboard', labelAr: 'لوحة المالية', icon: Icons.bar_chart),
      V5Shortcut(serviceId: 'erp', mainId: 'treasury', chipId: 'dashboard', labelAr: 'لوحة الخزينة', icon: Icons.account_balance),
      V5Shortcut(serviceId: 'compliance', mainId: 'tax', chipId: 'dashboard', labelAr: 'لوحة الضرائب', icon: Icons.request_quote),
      V5Shortcut(serviceId: 'advisory', mainId: 'feasibility', chipId: 'dashboard', labelAr: 'دراسات الجدوى', icon: Icons.lightbulb),
      V5Shortcut(serviceId: 'erp', mainId: 'reports-bi', chipId: 'dashboard', labelAr: 'التقارير', icon: Icons.assessment),
    ],
  ),
  V5Workspace(
    id: 'accountant',
    labelAr: 'بيئة المحاسب',
    labelEn: 'Accountant Workspace',
    icon: Icons.calculate,
    color: Color(0xFF2E7D5B),
    descriptionAr: 'العمليات اليومية — قيود، فواتير، مطابقة، ضرائب',
    shortcuts: [
      V5Shortcut(serviceId: 'erp', mainId: 'finance', chipId: 'gl', labelAr: 'دفتر الأستاذ', icon: Icons.book),
      V5Shortcut(serviceId: 'erp', mainId: 'sales', chipId: 'sales', labelAr: 'حسابات القبض', icon: Icons.receipt),
      V5Shortcut(serviceId: 'erp', mainId: 'treasury', chipId: 'recon', labelAr: 'المطابقة البنكية', icon: Icons.compare_arrows),
      V5Shortcut(serviceId: 'compliance', mainId: 'zatca', chipId: 'zatca', labelAr: 'زاتكا', icon: Icons.receipt),
      V5Shortcut(serviceId: 'compliance', mainId: 'tax', chipId: 'vat', labelAr: 'VAT', icon: Icons.percent),
    ],
  ),
  V5Workspace(
    id: 'auditor',
    labelAr: 'بيئة المراجع',
    labelEn: 'Auditor Workspace',
    icon: Icons.fact_check,
    color: Color(0xFF4A148C),
    descriptionAr: 'ارتباطات المراجعة — عمل ميداني، أوراق عمل، إصدار تقارير',
    shortcuts: [
      V5Shortcut(serviceId: 'audit', mainId: 'engagement', chipId: 'dashboard', labelAr: 'لوحة الارتباط', icon: Icons.handshake),
      V5Shortcut(serviceId: 'audit', mainId: 'fieldwork', chipId: 'workpapers', labelAr: 'أوراق العمل', icon: Icons.folder),
      V5Shortcut(serviceId: 'audit', mainId: 'fieldwork', chipId: 'risk', labelAr: 'تقييم المخاطر', icon: Icons.warning),
      V5Shortcut(serviceId: 'audit', mainId: 'reporting', chipId: 'opinion', labelAr: 'منشئ الرأي', icon: Icons.gavel),
    ],
  ),
  V5Workspace(
    id: 'advisor',
    labelAr: 'بيئة المستشار',
    labelEn: 'Advisor Workspace',
    icon: Icons.analytics,
    color: Color(0xFF1565C0),
    descriptionAr: 'مشاريع استشارية — جدوى، تحليل خارجي، تقييم',
    shortcuts: [
      V5Shortcut(serviceId: 'advisory', mainId: 'valuation', chipId: 'valuation', labelAr: 'التقييم', icon: Icons.monetization_on),
      V5Shortcut(serviceId: 'advisory', mainId: 'ratios', chipId: 'ratios', labelAr: 'النسب المالية', icon: Icons.analytics),
      V5Shortcut(serviceId: 'advisory', mainId: 'feasibility', chipId: 'sensitivity', labelAr: 'الحساسية', icon: Icons.tune),
      V5Shortcut(serviceId: 'advisory', mainId: 'ifrs-tools', chipId: 'lease', labelAr: 'IFRS 16', icon: Icons.apartment),
    ],
  ),
  V5Workspace(
    id: 'compliance',
    labelAr: 'بيئة مسؤول الامتثال',
    labelEn: 'Compliance Workspace',
    icon: Icons.shield,
    color: Color(0xFF2E7D5B),
    descriptionAr: 'الامتثال التنظيمي — زاتكا، GOSI/WPS، AML، الحوكمة',
    shortcuts: [
      V5Shortcut(serviceId: 'compliance', mainId: 'zatca', chipId: 'dashboard', labelAr: 'لوحة الفوترة', icon: Icons.receipt),
      V5Shortcut(serviceId: 'compliance', mainId: 'labor', chipId: 'gosi', labelAr: 'التأمينات', icon: Icons.health_and_safety),
      V5Shortcut(serviceId: 'compliance', mainId: 'aml-ethics', chipId: 'aml', labelAr: 'مكافحة غسل الأموال', icon: Icons.gavel),
      V5Shortcut(serviceId: 'compliance', mainId: 'tax', chipId: 'vat', labelAr: 'VAT', icon: Icons.percent),
    ],
  ),
];
