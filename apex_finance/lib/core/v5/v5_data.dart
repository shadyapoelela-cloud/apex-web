/// APEX V5.1 — Hierarchy data.
///
/// 5 Services × 15 Main Modules × 70 Chips.
/// POC scope: ERP fully populated; other services skeleton-only.
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
    actionRoute: '/app/erp/finance/ar?filter=overdue-90',
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
// The 5 V5 Services.
// ──────────────────────────────────────────────────────────────────────

List<V5Service> v5Services = [
  // ── Service 1: ERP ──────────────────────────────────────────────────
  V5Service(
    id: 'erp',
    labelAr: 'المحاسبة والعمليات',
    labelEn: 'ERP',
    icon: Icons.business_center,
    color: const Color(0xFFD4AF37), // Gold
    descriptionAr: 'العمليات اليومية — محاسبة، مخزون، خزينة، موارد بشرية',
    mainModules: [
      V5MainModule(
        id: 'finance',
        labelAr: 'الإدارة المالية',
        labelEn: 'Finance',
        icon: Icons.bar_chart,
        descriptionAr: 'دفتر الأستاذ، الذمم، الموازنات، التقارير',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة المالية',
            labelEn: 'Finance Dashboard',
            icon: Icons.dashboard,
            widgets: _financeDashboardWidgets,
          ),
          _chipFromV4('erp', 'gl', labelOverrideAr: 'دفتر الأستاذ العام'),
          V5Chip(
            id: 'je-builder',
            labelAr: 'قيود اليومية',
            labelEn: 'Journal Entries',
            icon: Icons.edit_note,
          ),
          V5Chip(
            id: 'period-close',
            labelAr: 'إقفال الفترة',
            labelEn: 'Period Close',
            icon: Icons.lock_clock,
          ),
          V5Chip(
            id: 'coa-editor',
            labelAr: 'دليل الحسابات',
            labelEn: 'Chart of Accounts',
            icon: Icons.account_tree,
          ),
          V5Chip(
            id: 'fixed-assets',
            labelAr: 'الأصول الثابتة',
            labelEn: 'Fixed Assets',
            icon: Icons.business,
          ),
          _chipFromV4('erp', 'sales', labelOverrideAr: 'حسابات القبض'),
          V5Chip(
            id: 'sales-workflow',
            labelAr: 'دورة المبيعات',
            labelEn: 'Sales Workflow',
            icon: Icons.point_of_sale,
          ),
          V5Chip(
            id: 'invoices',
            labelAr: 'الفواتير',
            labelEn: 'Invoices',
            icon: Icons.receipt,
          ),
          V5Chip(
            id: 'ap',
            labelAr: 'حسابات الدفع',
            labelEn: 'Accounts Payable',
            icon: Icons.receipt_long,
          ),
          V5Chip(
            id: 'statements',
            labelAr: 'القوائم المالية',
            labelEn: 'Financial Statements',
            icon: Icons.insert_chart,
          ),
          V5Chip(
            id: 'budgets',
            labelAr: 'الموازنات',
            labelEn: 'Budgets',
            icon: Icons.pie_chart,
          ),
          V5Chip(
            id: 'budget-actual',
            labelAr: 'الموازنة مقابل الفعلي',
            labelEn: 'Budget vs Actual',
            icon: Icons.compare_arrows,
          ),
          V5Chip(
            id: 'reports',
            labelAr: 'التقارير',
            labelEn: 'Reports',
            icon: Icons.assessment,
          ),
          V5Chip(
            id: 'custom-reports',
            labelAr: 'منشئ التقارير',
            labelEn: 'Report Builder',
            icon: Icons.dashboard_customize,
          ),
          V5Chip(
            id: 'consolidation',
            labelAr: 'التوحيد',
            labelEn: 'Consolidation',
            icon: Icons.merge,
          ),
          V5Chip(
            id: 'onboarding',
            labelAr: 'رحلة الإعداد',
            labelEn: 'Onboarding',
            icon: Icons.auto_awesome,
          ),
          V5Chip(
            id: 'expenses',
            labelAr: 'مطالبات المصروفات',
            labelEn: 'Expense Claims',
            icon: Icons.receipt,
          ),
          V5Chip(
            id: 'exec',
            labelAr: 'لوحة التنفيذيين',
            labelEn: 'Executive Dashboard',
            icon: Icons.star,
          ),
          V5Chip(
            id: 'documents',
            labelAr: 'خزانة الوثائق',
            labelEn: 'Document Vault',
            icon: Icons.folder_shared,
          ),
          V5Chip(
            id: 'close-checklist',
            labelAr: 'قائمة الإقفال',
            labelEn: 'Close Checklist',
            icon: Icons.checklist,
          ),
          V5Chip(
            id: 'okrs',
            labelAr: 'الأهداف OKRs',
            labelEn: 'OKRs',
            icon: Icons.track_changes,
          ),
          V5Chip(
            id: 'workflows',
            labelAr: 'مسارات الاعتماد',
            labelEn: 'Approval Workflows',
            icon: Icons.approval,
          ),
          V5Chip(
            id: 'anomalies',
            labelAr: 'كاشف الشذوذ AI',
            labelEn: 'AI Anomaly Detector',
            icon: Icons.psychology,
          ),
          V5Chip(
            id: 'copilot',
            labelAr: 'مساعد AI',
            labelEn: 'AI Copilot',
            icon: Icons.auto_awesome,
          ),
          V5Chip(
            id: 'esg',
            labelAr: 'الاستدامة ESG',
            labelEn: 'ESG',
            icon: Icons.eco,
          ),
          V5Chip(
            id: 'scenarios',
            labelAr: 'سيناريوهات What-If',
            labelEn: 'What-If Scenarios',
            icon: Icons.insights,
          ),
          V5Chip(
            id: 'breakeven',
            labelAr: 'نقطة التعادل',
            labelEn: 'Break-Even',
            icon: Icons.balance,
          ),
          V5Chip(
            id: 'knowledge',
            labelAr: 'قاعدة المعرفة',
            labelEn: 'Knowledge Base',
            icon: Icons.menu_book,
          ),
          V5Chip(
            id: 'board',
            labelAr: 'بوابة المجلس',
            labelEn: 'Board Portal',
            icon: Icons.account_balance,
          ),
          V5Chip(
            id: 'cost-centers',
            labelAr: 'مراكز التكلفة',
            labelEn: 'Cost Centers',
            icon: Icons.pie_chart,
          ),
          V5Chip(
            id: 'cap-table',
            labelAr: 'هيكل الملكية',
            labelEn: 'Cap Table',
            icon: Icons.donut_large,
          ),
          V5Chip(
            id: 'integrations',
            labelAr: 'التكاملات API',
            labelEn: 'Integrations Hub',
            icon: Icons.hub,
          ),
        ],
      ),
      V5MainModule(
        id: 'hr',
        labelAr: 'الموارد البشرية والرواتب',
        labelEn: 'HR & Payroll',
        icon: Icons.people,
        descriptionAr: 'الموظفون، الرواتب، الإجازات، GOSI/WPS',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة الموارد البشرية',
            labelEn: 'HR Dashboard',
            icon: Icons.dashboard,
            widgets: const [
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
            ],
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
        ],
      ),
      V5MainModule(
        id: 'operations',
        labelAr: 'العمليات',
        labelEn: 'Operations',
        icon: Icons.inventory_2,
        descriptionAr: 'المخزون، المشاريع، إدارة العملاء، التصنيع',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة العمليات',
            labelEn: 'Operations Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [
              V5DashboardWidget(
                labelAr: 'أصناف تحتاج إعادة طلب',
                labelEn: 'Items needing reorder',
                icon: Icons.warning,
                kind: V5WidgetKind.actionList,
                actionLabelAr: 'أنشئ أوامر شراء',
                severity: V5WidgetSeverity.warning,
              ),
              V5DashboardWidget(
                labelAr: 'أوامر الشراء المفتوحة',
                labelEn: 'Open POs',
                icon: Icons.shopping_cart,
                kind: V5WidgetKind.kpi,
                severity: V5WidgetSeverity.info,
              ),
            ],
          ),
          V5Chip(id: 'inventory', labelAr: 'المخزون', labelEn: 'Inventory', icon: Icons.inventory),
          V5Chip(id: 'projects', labelAr: 'المشاريع', labelEn: 'Projects', icon: Icons.work),
          V5Chip(id: 'crm', labelAr: 'إدارة العملاء', labelEn: 'CRM', icon: Icons.contacts),
          V5Chip(id: 'customers-360', labelAr: 'العميل 360°', labelEn: 'Customer 360°', icon: Icons.person_pin_circle),
          V5Chip(id: 'suppliers', labelAr: 'المورّدون 360°', labelEn: 'Suppliers 360°', icon: Icons.store),
          V5Chip(id: 'pipeline', labelAr: 'أنبوب المبيعات', labelEn: 'Sales Pipeline', icon: Icons.filter_alt),
          V5Chip(id: 'project-pnl', labelAr: 'ربحية المشاريع', labelEn: 'Project P&L', icon: Icons.analytics),
          V5Chip(id: 'tickets', labelAr: 'تذاكر الدعم', labelEn: 'Helpdesk', icon: Icons.support_agent),
          V5Chip(id: 'vendor-onboarding', labelAr: 'إدخال مورد', labelEn: 'Vendor Onboarding', icon: Icons.person_add),
          V5Chip(id: 'requisitions', labelAr: 'طلبات الشراء', labelEn: 'Purchase Requisitions', icon: Icons.shopping_cart),
          V5Chip(id: 'fleet', labelAr: 'الأسطول', labelEn: 'Fleet', icon: Icons.local_shipping),
          V5Chip(id: 'contracts', labelAr: 'العقود', labelEn: 'Contracts', icon: Icons.gavel),
          V5Chip(id: 'manufacturing', labelAr: 'التصنيع', labelEn: 'Manufacturing', icon: Icons.precision_manufacturing),
        ],
      ),
      V5MainModule(
        id: 'treasury',
        labelAr: 'الخزينة',
        labelEn: 'Treasury',
        icon: Icons.account_balance,
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
    ],
  ),

  // ── Service 2: Compliance & Tax ─────────────────────────────────────
  V5Service(
    id: 'compliance',
    labelAr: 'الامتثال والضرائب',
    labelEn: 'Compliance & Tax',
    icon: Icons.shield,
    color: const Color(0xFF2E7D5B), // Emerald
    descriptionAr: 'زاتكا، VAT، GOSI/WPS، AML، الحوكمة',
    mainModules: [
      V5MainModule(
        id: 'tax',
        labelAr: 'الإقرارات الضريبية',
        labelEn: 'Tax Filings',
        icon: Icons.request_quote,
        descriptionAr: 'VAT، WHT، الزكاة، UAE CT، أسعار التحويل',
        chips: [
          _dashboardChip(
            id: 'dashboard',
            labelAr: 'لوحة الضرائب',
            labelEn: 'Tax Dashboard',
            icon: Icons.dashboard,
            widgets: _complianceDashboardWidgets,
          ),
          const V5Chip(id: 'vat', labelAr: 'ضريبة القيمة المضافة', labelEn: 'VAT', icon: Icons.percent),
          const V5Chip(id: 'wht', labelAr: 'ضريبة الاستقطاع', labelEn: 'WHT', icon: Icons.money_off),
          const V5Chip(id: 'zakat', labelAr: 'الزكاة', labelEn: 'Zakat', icon: Icons.star),
          const V5Chip(id: 'uae_ct', labelAr: 'ضريبة الشركات الإماراتية', labelEn: 'UAE CT', icon: Icons.flag),
          const V5Chip(id: 'tp', labelAr: 'أسعار التحويل', labelEn: 'Transfer Pricing', icon: Icons.swap_horiz),
          const V5Chip(id: 'calendar', labelAr: 'الرزنامة الضريبية', labelEn: 'Tax Calendar', icon: Icons.calendar_month),
          const V5Chip(id: 'vat-return', labelAr: 'إقرار VAT', labelEn: 'VAT Return', icon: Icons.description),
          const V5Chip(id: 'deferred', labelAr: 'الضريبة المؤجلة', labelEn: 'Deferred Tax', icon: Icons.account_balance_wallet),
        ],
      ),
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
      V5MainModule(
        id: 'regulatory',
        labelAr: 'التنظيم والحوكمة',
        labelEn: 'Regulatory',
        icon: Icons.gavel,
        descriptionAr: 'GOSI/WPS، مكافحة غسل الأموال، الحوكمة',
        chips: const [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التنظيم',
            labelEn: 'Regulatory Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'gosi', labelAr: 'التأمينات الاجتماعية', labelEn: 'GOSI', icon: Icons.health_and_safety),
          V5Chip(id: 'wps', labelAr: 'نظام حماية الأجور', labelEn: 'WPS', icon: Icons.shield),
          V5Chip(id: 'aml', labelAr: 'مكافحة غسل الأموال', labelEn: 'AML', icon: Icons.gavel),
          V5Chip(id: 'governance', labelAr: 'الحوكمة والمجلس', labelEn: 'Governance', icon: Icons.account_tree),
          V5Chip(id: 'activity-log', labelAr: 'سجل النشاط', labelEn: 'Activity Log', icon: Icons.shield),
          V5Chip(id: 'cybersecurity', labelAr: 'الأمن السيبراني', labelEn: 'Cybersecurity', icon: Icons.security),
          V5Chip(id: 'risk-register', labelAr: 'سجل المخاطر', labelEn: 'Risk Register', icon: Icons.shield),
          V5Chip(id: 'whistleblower', labelAr: 'البلاغات الأخلاقية', labelEn: 'Whistleblower', icon: Icons.shield_moon),
          V5Chip(id: 'bcp', labelAr: 'استمرارية الأعمال', labelEn: 'BCP / DR', icon: Icons.health_and_safety),
        ],
      ),
    ],
  ),

  // ── Service 3: Audit ────────────────────────────────────────────────
  V5Service(
    id: 'audit',
    labelAr: 'المراجعة',
    labelEn: 'Audit',
    icon: Icons.fact_check,
    color: const Color(0xFF4A148C), // Deep Purple
    descriptionAr: 'ارتباط، عمل ميداني، إصدار التقارير',
    mainModules: const [
      V5MainModule(
        id: 'engagement',
        labelAr: 'الارتباط',
        labelEn: 'Engagement',
        icon: Icons.handshake,
        descriptionAr: 'التخطيط، القبول، البدء',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الارتباط',
            labelEn: 'Engagement Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'planning', labelAr: 'التخطيط', labelEn: 'Planning', icon: Icons.edit_calendar),
          V5Chip(id: 'acceptance', labelAr: 'القبول', labelEn: 'Acceptance', icon: Icons.check),
          V5Chip(id: 'kickoff', labelAr: 'البدء', labelEn: 'Kick-off', icon: Icons.rocket_launch),
        ],
      ),
      V5MainModule(
        id: 'fieldwork',
        labelAr: 'العمل الميداني',
        labelEn: 'Fieldwork',
        icon: Icons.biotech,
        descriptionAr: 'أوراق العمل، المخاطر، اختبار الضوابط',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الفحص',
            labelEn: 'Fieldwork Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'workpapers', labelAr: 'أوراق العمل', labelEn: 'Workpapers', icon: Icons.folder),
          V5Chip(id: 'controls-library', labelAr: 'مكتبة الضوابط', labelEn: 'Controls Library', icon: Icons.security),
          V5Chip(id: 'risk', labelAr: 'تقييم المخاطر', labelEn: 'Risk Assessment', icon: Icons.warning),
          V5Chip(id: 'control', labelAr: 'اختبار الضوابط', labelEn: 'Control Testing', icon: Icons.rule),
        ],
      ),
      V5MainModule(
        id: 'reporting',
        labelAr: 'إصدار التقارير',
        labelEn: 'Reporting',
        icon: Icons.description,
        descriptionAr: 'الرأي، رسالة الإدارة، ضمان الجودة',
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
          V5Chip(id: 'qc', labelAr: 'ضمان الجودة', labelEn: 'QC', icon: Icons.verified),
        ],
      ),
    ],
  ),

  // ── Service 4: Advisory ─────────────────────────────────────────────
  V5Service(
    id: 'advisory',
    labelAr: 'الاستشارات',
    labelEn: 'Advisory',
    icon: Icons.analytics,
    color: const Color(0xFF1565C0), // Blue
    descriptionAr: 'دراسات جدوى، تحليل خارجي، أدوات مالية',
    mainModules: const [
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
          V5Chip(id: 'valuation', labelAr: 'التقييم', labelEn: 'Valuation', icon: Icons.monetization_on),
          V5Chip(id: 'sensitivity', labelAr: 'الحساسية', labelEn: 'Sensitivity', icon: Icons.tune),
        ],
      ),
      V5MainModule(
        id: 'external',
        labelAr: 'التحليل الخارجي',
        labelEn: 'External Analysis',
        icon: Icons.search,
        descriptionAr: 'الرفع، النسب، المقارنة المرجعية، الائتمان',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة التحليل',
            labelEn: 'External Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'upload', labelAr: 'الرفع والقراءة الضوئية', labelEn: 'Upload & OCR', icon: Icons.upload_file),
          V5Chip(id: 'ratios', labelAr: 'النسب المالية', labelEn: 'Ratios', icon: Icons.analytics),
          V5Chip(id: 'benchmarking', labelAr: 'المقارنة المرجعية', labelEn: 'Benchmarking', icon: Icons.compare),
          V5Chip(id: 'credit', labelAr: 'التحليل الائتماني', labelEn: 'Credit', icon: Icons.credit_score),
        ],
      ),
      V5MainModule(
        id: 'tools',
        labelAr: 'الأدوات المالية',
        labelEn: 'Financial Tools',
        icon: Icons.calculate,
        descriptionAr: 'الأصول، الإهلاك، الإيجار، التعادل',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة الأدوات',
            labelEn: 'Tools Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'fixed_assets', labelAr: 'الأصول الثابتة', labelEn: 'Fixed Assets', icon: Icons.domain),
          V5Chip(id: 'depreciation', labelAr: 'الإهلاك', labelEn: 'Depreciation', icon: Icons.trending_down),
          V5Chip(id: 'lease', labelAr: 'عقود الإيجار (IFRS 16)', labelEn: 'Lease', icon: Icons.apartment),
          V5Chip(id: 'breakeven', labelAr: 'نقطة التعادل', labelEn: 'Break-even', icon: Icons.balance),
        ],
      ),
    ],
  ),

  // ── Service 5: Marketplace ──────────────────────────────────────────
  V5Service(
    id: 'marketplace',
    labelAr: 'السوق',
    labelEn: 'Marketplace',
    icon: Icons.store,
    color: const Color(0xFFE65100), // Deep Orange
    descriptionAr: 'سوق مزدوج — عملاء يطلبون خدمات، مزوّدون يقدّمونها',
    mainModules: const [
      V5MainModule(
        id: 'client',
        labelAr: 'جانب العميل',
        labelEn: 'Client Side',
        icon: Icons.person_outline,
        descriptionAr: 'تصفّح المزوّدين، الطلبات، الفوترة',
        chips: [
          V5Chip(
            id: 'dashboard',
            labelAr: 'لوحة العميل',
            labelEn: 'Client Dashboard',
            icon: Icons.dashboard,
            isDashboard: true,
            dashboardWidgets: [],
          ),
          V5Chip(id: 'browse', labelAr: 'تصفّح المزوّدين', labelEn: 'Browse Providers', icon: Icons.search),
          V5Chip(id: 'requests', labelAr: 'طلباتي', labelEn: 'My Requests', icon: Icons.assignment),
          V5Chip(id: 'billing', labelAr: 'الفوترة والضمان', labelEn: 'Billing & Escrow', icon: Icons.receipt_long),
        ],
      ),
      V5MainModule(
        id: 'provider',
        labelAr: 'جانب المزوّد',
        labelEn: 'Provider Side',
        icon: Icons.business,
        descriptionAr: 'الملف، المهام، المدفوعات، التقييمات',
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
          V5Chip(id: 'jobs', labelAr: 'المهام النشطة', labelEn: 'Active Jobs', icon: Icons.work),
          V5Chip(id: 'payouts', labelAr: 'المدفوعات', labelEn: 'Payouts', icon: Icons.payments),
          V5Chip(id: 'ratings', labelAr: 'التقييمات', labelEn: 'Ratings', icon: Icons.star),
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
      V5Shortcut(serviceId: 'erp', mainId: 'finance', chipId: 'reports', labelAr: 'التقارير', icon: Icons.assessment),
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
      V5Shortcut(serviceId: 'erp', mainId: 'finance', chipId: 'sales', labelAr: 'حسابات القبض', icon: Icons.receipt),
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
      V5Shortcut(serviceId: 'advisory', mainId: 'feasibility', chipId: 'valuation', labelAr: 'التقييم', icon: Icons.monetization_on),
      V5Shortcut(serviceId: 'advisory', mainId: 'external', chipId: 'ratios', labelAr: 'النسب المالية', icon: Icons.analytics),
      V5Shortcut(serviceId: 'advisory', mainId: 'feasibility', chipId: 'sensitivity', labelAr: 'الحساسية', icon: Icons.tune),
      V5Shortcut(serviceId: 'advisory', mainId: 'tools', chipId: 'lease', labelAr: 'IFRS 16', icon: Icons.apartment),
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
      V5Shortcut(serviceId: 'compliance', mainId: 'regulatory', chipId: 'gosi', labelAr: 'التأمينات', icon: Icons.health_and_safety),
      V5Shortcut(serviceId: 'compliance', mainId: 'regulatory', chipId: 'aml', labelAr: 'مكافحة غسل الأموال', icon: Icons.gavel),
      V5Shortcut(serviceId: 'compliance', mainId: 'tax', chipId: 'vat', labelAr: 'VAT', icon: Icons.percent),
    ],
  ),
];
