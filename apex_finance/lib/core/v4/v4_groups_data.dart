/// APEX V4 — Full sub-module definitions for groups 2-6 (Wave 4 PR#1).
///
/// Split out of v4_groups.dart so the single-file size stays readable.
/// Each group mirrors its row in APEX_V4_Module_Hierarchy.txt: every
/// sub-module gets its 5 "visible tabs" populated with icons + Arabic
/// labels. Overflow is left empty until each group's dedicated wave
/// ships; most screens will pick up the _defaultScreenHost stub in
/// v4_routes.dart until they're wired.
library;

import 'package:flutter/material.dart';

import 'v4_groups.dart';

// ── Audit & Review (7 sub-modules) — CaseWare-class engagement flow ──

const auditDashboard = V4SubModule(
  id: 'dashboard',
  labelAr: 'لوحة التدقيق',
  labelEn: 'Audit Dashboard',
  icon: Icons.dashboard_outlined,
  descriptionAr: 'نظرة شاملة على الارتباطات، المخاطر، المواعيد، طاقة الفريق.',
  visibleTabs: [
    V4Screen(id: 'audit-dashboard-engagements', labelAr: 'الارتباطات النشطة', labelEn: 'Active Engagements', icon: Icons.assignment_outlined),
    V4Screen(id: 'audit-dashboard-heatmap', labelAr: 'خريطة المخاطر', labelEn: 'Risk Heatmap', icon: Icons.grid_view_rounded),
    V4Screen(id: 'audit-dashboard-deadlines', labelAr: 'المواعيد', labelEn: 'Deadlines', icon: Icons.event_note),
    V4Screen(id: 'audit-dashboard-capacity', labelAr: 'طاقة الفريق', labelEn: 'Team Capacity', icon: Icons.groups),
    V4Screen(id: 'audit-dashboard-issues', labelAr: 'المشكلات', labelEn: 'Issues', icon: Icons.report_problem_outlined),
  ],
);

const auditPlanning = V4SubModule(
  id: 'planning',
  labelAr: 'تخطيط الارتباط',
  labelEn: 'Engagement Planning',
  icon: Icons.edit_note,
  descriptionAr: 'قبول العميل، النطاق، الأهمية النسبية، الفريق، الميزانية.',
  visibleTabs: [
    V4Screen(id: 'audit-planning-client', labelAr: 'بيانات العميل', labelEn: 'Client Info', icon: Icons.business),
    V4Screen(id: 'audit-planning-acceptance', labelAr: 'القبول', labelEn: 'Acceptance', icon: Icons.verified),
    V4Screen(id: 'audit-planning-scope', labelAr: 'النطاق', labelEn: 'Scope', icon: Icons.crop_free),
    V4Screen(id: 'audit-planning-materiality', labelAr: 'الأهمية النسبية', labelEn: 'Materiality', icon: Icons.balance),
    V4Screen(id: 'audit-planning-team', labelAr: 'الفريق والميزانية', labelEn: 'Team & Budget', icon: Icons.account_tree),
  ],
);

const auditRisk = V4SubModule(
  id: 'risk',
  labelAr: 'تقييم المخاطر',
  labelEn: 'Risk Assessment',
  icon: Icons.warning_amber_outlined,
  descriptionAr: 'سجل المخاطر، الإقرارات، الضوابط، مصفوفة RoMM.',
  visibleTabs: [
    V4Screen(id: 'audit-risk-register', labelAr: 'سجل المخاطر', labelEn: 'Risk Register', icon: Icons.list_alt),
    V4Screen(id: 'audit-risk-assertions', labelAr: 'الإقرارات', labelEn: 'Assertions', icon: Icons.check_box_outlined),
    V4Screen(id: 'audit-risk-controls', labelAr: 'الضوابط', labelEn: 'Controls', icon: Icons.shield_outlined),
    V4Screen(id: 'audit-risk-romm', labelAr: 'مصفوفة RoMM', labelEn: 'RoMM Matrix', icon: Icons.grid_on),
    V4Screen(id: 'audit-risk-fraud', labelAr: 'مخاطر الاحتيال', labelEn: 'Fraud Risks', icon: Icons.crisis_alert),
  ],
);

const auditWorkpapers = V4SubModule(
  id: 'workpapers',
  labelAr: 'أوراق العمل',
  labelEn: 'Workpapers',
  icon: Icons.folder_copy_outlined,
  descriptionAr: 'شجرة الفهرس، جداول قيادة، علامات، مراجع متقاطعة.',
  visibleTabs: [
    V4Screen(id: 'audit-wp-index', labelAr: 'شجرة الفهرس', labelEn: 'Index Tree', icon: Icons.account_tree_outlined),
    V4Screen(id: 'audit-wp-lead', labelAr: 'جداول القيادة', labelEn: 'Lead Sheets', icon: Icons.list),
    V4Screen(id: 'audit-wp-tb', labelAr: 'ميزان المراجعة', labelEn: 'Trial Balance', icon: Icons.balance),
    V4Screen(id: 'audit-wp-ticks', labelAr: 'علامات التدقيق', labelEn: 'Tick Marks', icon: Icons.done_all),
    V4Screen(id: 'audit-wp-refs', labelAr: 'المراجع المتقاطعة', labelEn: 'References', icon: Icons.link),
  ],
);

const auditTesting = V4SubModule(
  id: 'testing',
  labelAr: 'اختبار الضوابط',
  labelEn: 'Control Testing',
  icon: Icons.science_outlined,
  descriptionAr: 'خطط الاختبار، العينات، النتائج، الاستثناءات، الخلاصة.',
  visibleTabs: [
    V4Screen(id: 'audit-test-plans', labelAr: 'خطط الاختبار', labelEn: 'Test Plans', icon: Icons.rule),
    V4Screen(id: 'audit-test-samples', labelAr: 'العينات', labelEn: 'Samples', icon: Icons.filter_3),
    V4Screen(id: 'audit-test-results', labelAr: 'النتائج', labelEn: 'Results', icon: Icons.fact_check),
    V4Screen(id: 'audit-test-exceptions', labelAr: 'الاستثناءات', labelEn: 'Exceptions', icon: Icons.error_outline),
    V4Screen(id: 'audit-test-conclusion', labelAr: 'الخلاصة', labelEn: 'Conclusion', icon: Icons.summarize),
  ],
);

const auditReport = V4SubModule(
  id: 'report',
  labelAr: 'إصدار التقرير',
  labelEn: 'Report Issuance',
  icon: Icons.description_outlined,
  descriptionAr: 'بناء الرأي، التقرير، خطاب الإدارة، حوكمة.',
  visibleTabs: [
    V4Screen(id: 'audit-report-opinion', labelAr: 'بناء الرأي', labelEn: 'Opinion Builder', icon: Icons.gavel),
    V4Screen(id: 'audit-report-audit', labelAr: 'تقرير التدقيق', labelEn: 'Audit Report', icon: Icons.article),
    V4Screen(id: 'audit-report-mgmt-letter', labelAr: 'خطاب الإدارة', labelEn: 'Management Letter', icon: Icons.mail_outline),
    V4Screen(id: 'audit-report-governance', labelAr: 'تقرير الحوكمة', labelEn: 'Governance Report', icon: Icons.account_balance),
    V4Screen(id: 'audit-report-rep', labelAr: 'خطاب الإقرار', labelEn: 'Rep Letter', icon: Icons.approval),
  ],
);

const auditQc = V4SubModule(
  id: 'qc',
  labelAr: 'مراقبة الجودة',
  labelEn: 'Quality Control',
  icon: Icons.verified_user_outlined,
  descriptionAr: 'إسناد الفريق، ملاحظات المراجعة، EQCR، الأرشفة.',
  visibleTabs: [
    V4Screen(id: 'audit-qc-notes', labelAr: 'ملاحظات المراجعة', labelEn: 'Review Notes', icon: Icons.rate_review),
    V4Screen(id: 'audit-qc-assignments', labelAr: 'الإسناد', labelEn: 'Assignments', icon: Icons.assignment_ind),
    V4Screen(id: 'audit-qc-signoff', labelAr: 'التوقيع', labelEn: 'Signoff', icon: Icons.draw),
    V4Screen(id: 'audit-qc-eqcr', labelAr: 'EQCR', labelEn: 'EQCR', icon: Icons.reviews),
    V4Screen(id: 'audit-qc-archive', labelAr: 'الأرشفة', labelEn: 'Archive', icon: Icons.archive),
  ],
);

// ── Feasibility Studies (8 sub-modules) ──

const feasDashboard = V4SubModule(
  id: 'dashboard',
  labelAr: 'لوحة الجدوى',
  labelEn: 'Feasibility Dashboard',
  icon: Icons.dashboard_outlined,
  descriptionAr: 'محفظة مشاريع الجدوى مع قمع المراحل والقرارات.',
  visibleTabs: [
    V4Screen(id: 'feas-dashboard-portfolio', labelAr: 'المحفظة', labelEn: 'Portfolio', icon: Icons.folder_special),
    V4Screen(id: 'feas-dashboard-funnel', labelAr: 'قمع المراحل', labelEn: 'Stage Funnel', icon: Icons.filter_alt),
    V4Screen(id: 'feas-dashboard-decisions', labelAr: 'القرارات', labelEn: 'Decisions', icon: Icons.how_to_vote),
    V4Screen(id: 'feas-dashboard-team', labelAr: 'تحميل الفريق', labelEn: 'Team Load', icon: Icons.groups_2),
    V4Screen(id: 'feas-dashboard-alerts', labelAr: 'التنبيهات', labelEn: 'Alerts', icon: Icons.notifications_active_outlined),
  ],
);

const feasSetup = V4SubModule(
  id: 'setup',
  labelAr: 'تأسيس المشروع',
  labelEn: 'Project Setup',
  icon: Icons.settings_outlined,
  descriptionAr: 'الهوية، النطاق، القالب، الفريق، العملة، الأفق الزمني.',
  visibleTabs: [
    V4Screen(id: 'feas-setup-identity', labelAr: 'الهوية', labelEn: 'Identity', icon: Icons.badge_outlined),
    V4Screen(id: 'feas-setup-scope', labelAr: 'النطاق', labelEn: 'Scope', icon: Icons.crop_free),
    V4Screen(id: 'feas-setup-template', labelAr: 'القالب', labelEn: 'Template', icon: Icons.dashboard_customize),
    V4Screen(id: 'feas-setup-team', labelAr: 'الفريق', labelEn: 'Team', icon: Icons.group),
    V4Screen(id: 'feas-setup-settings', labelAr: 'الإعدادات', labelEn: 'Settings', icon: Icons.tune),
  ],
);

const feasMarket = V4SubModule(
  id: 'market',
  labelAr: 'تحليل السوق',
  labelEn: 'Market Analysis',
  icon: Icons.public,
  descriptionAr: 'TAM/SAM/SOM، المنافسون، الطلب، استراتيجية التسعير.',
  visibleTabs: [
    V4Screen(id: 'feas-market-tam', labelAr: 'TAM/SAM/SOM', labelEn: 'TAM/SAM/SOM', icon: Icons.track_changes),
    V4Screen(id: 'feas-market-competitors', labelAr: 'المنافسون', labelEn: 'Competitors', icon: Icons.people_alt),
    V4Screen(id: 'feas-market-demand', labelAr: 'نموذج الطلب', labelEn: 'Demand Model', icon: Icons.show_chart),
    V4Screen(id: 'feas-market-pricing', labelAr: 'التسعير', labelEn: 'Pricing', icon: Icons.local_offer),
    V4Screen(id: 'feas-market-sources', labelAr: 'المصادر', labelEn: 'Sources', icon: Icons.menu_book),
  ],
);

const feasCost = V4SubModule(
  id: 'cost',
  labelAr: 'نموذج التكلفة والإيراد',
  labelEn: 'Cost & Revenue Model',
  icon: Icons.calculate_outlined,
  descriptionAr: 'Capex، Opex، محركات الإيراد، رأس المال العامل.',
  visibleTabs: [
    V4Screen(id: 'feas-cost-capex', labelAr: 'Capex', labelEn: 'Capex', icon: Icons.construction),
    V4Screen(id: 'feas-cost-opex', labelAr: 'Opex', labelEn: 'Opex', icon: Icons.receipt_long),
    V4Screen(id: 'feas-cost-revenue', labelAr: 'الإيراد', labelEn: 'Revenue', icon: Icons.trending_up),
    V4Screen(id: 'feas-cost-wc', labelAr: 'رأس المال العامل', labelEn: 'Working Capital', icon: Icons.swap_horiz),
    V4Screen(id: 'feas-cost-financing', labelAr: 'التمويل', labelEn: 'Financing', icon: Icons.account_balance_wallet),
  ],
);

const feasProForma = V4SubModule(
  id: 'proforma',
  labelAr: 'القوائم التقديرية',
  labelEn: 'Pro-Forma Financials',
  icon: Icons.table_chart_outlined,
  descriptionAr: 'الدخل، المركز المالي، التدفق النقدي، 3-10 سنوات.',
  visibleTabs: [
    V4Screen(id: 'feas-pf-pl', labelAr: 'الأرباح والخسائر', labelEn: 'P&L', icon: Icons.trending_up),
    V4Screen(id: 'feas-pf-bs', labelAr: 'الميزانية', labelEn: 'Balance Sheet', icon: Icons.balance),
    V4Screen(id: 'feas-pf-cf', labelAr: 'التدفق النقدي', labelEn: 'Cash Flow', icon: Icons.waterfall_chart),
    V4Screen(id: 'feas-pf-funding', labelAr: 'خطة التمويل', labelEn: 'Funding Plan', icon: Icons.stacked_bar_chart),
    V4Screen(id: 'feas-pf-covenants', labelAr: 'الالتزامات', labelEn: 'Covenants', icon: Icons.fact_check_outlined),
  ],
);

const feasValuation = V4SubModule(
  id: 'valuation',
  labelAr: 'التقييم ومؤشرات القرار',
  labelEn: 'Valuation & Decision Metrics',
  icon: Icons.analytics_outlined,
  descriptionAr: 'NPV، IRR، MIRR، Payback، DSCR، LLCR.',
  visibleTabs: [
    V4Screen(id: 'feas-val-npv', labelAr: 'NPV / IRR', labelEn: 'NPV / IRR', icon: Icons.functions),
    V4Screen(id: 'feas-val-payback', labelAr: 'الاسترداد', labelEn: 'Payback', icon: Icons.timer),
    V4Screen(id: 'feas-val-dscr', labelAr: 'DSCR / LLCR', labelEn: 'DSCR / LLCR', icon: Icons.speed),
    V4Screen(id: 'feas-val-wacc', labelAr: 'WACC', labelEn: 'WACC', icon: Icons.percent),
    V4Screen(id: 'feas-val-summary', labelAr: 'الملخص', labelEn: 'Summary', icon: Icons.summarize_outlined),
  ],
);

const feasSensitivity = V4SubModule(
  id: 'sensitivity',
  labelAr: 'الحساسية والمخاطر',
  labelEn: 'Sensitivity & Risk',
  icon: Icons.tune_rounded,
  descriptionAr: 'أحادي/ثنائي الاتجاه، Monte Carlo، سيناريوهات، Tornado.',
  visibleTabs: [
    V4Screen(id: 'feas-sens-oneway', labelAr: 'أحادي الاتجاه', labelEn: '1-Way Sensitivity', icon: Icons.linear_scale),
    V4Screen(id: 'feas-sens-twoway', labelAr: 'شبكة ثنائية', labelEn: '2-Way Grid', icon: Icons.grid_4x4),
    V4Screen(id: 'feas-sens-mc', labelAr: 'Monte Carlo', labelEn: 'Monte Carlo', icon: Icons.casino),
    V4Screen(id: 'feas-sens-scenarios', labelAr: 'السيناريوهات', labelEn: 'Scenarios', icon: Icons.alt_route),
    V4Screen(id: 'feas-sens-tornado', labelAr: 'Tornado', labelEn: 'Tornado', icon: Icons.sort),
  ],
);

const feasFinal = V4SubModule(
  id: 'final',
  labelAr: 'التقرير النهائي',
  labelEn: 'Final Report',
  icon: Icons.picture_as_pdf_outlined,
  descriptionAr: 'الملخص التنفيذي، الأقسام، الملاحق، التصدير.',
  visibleTabs: [
    V4Screen(id: 'feas-final-exec', labelAr: 'الملخص التنفيذي', labelEn: 'Executive Summary', icon: Icons.article_outlined),
    V4Screen(id: 'feas-final-sections', labelAr: 'الأقسام', labelEn: 'Sections', icon: Icons.list_alt),
    V4Screen(id: 'feas-final-appendices', labelAr: 'الملاحق', labelEn: 'Appendices', icon: Icons.attach_file),
    V4Screen(id: 'feas-final-export', labelAr: 'التصدير', labelEn: 'Export', icon: Icons.file_download),
    V4Screen(id: 'feas-final-signoff', labelAr: 'المراجعة والتوقيع', labelEn: 'Review & Signoff', icon: Icons.done_all),
  ],
);

// ── External Financial Analysis (7 sub-modules) ──

const extDashboard = V4SubModule(
  id: 'dashboard',
  labelAr: 'لوحة التحليل',
  labelEn: 'Analysis Dashboard',
  icon: Icons.dashboard_outlined,
  descriptionAr: 'محفظة المشاريع، المقارنات، التنبيهات.',
  visibleTabs: [
    V4Screen(id: 'ext-dashboard-projects', labelAr: 'المشاريع', labelEn: 'Projects', icon: Icons.folder_open),
    V4Screen(id: 'ext-dashboard-peers', labelAr: 'مقارنة النظراء', labelEn: 'Peer Compare', icon: Icons.compare_arrows),
    V4Screen(id: 'ext-dashboard-alerts', labelAr: 'التنبيهات', labelEn: 'Alerts', icon: Icons.notifications_active_outlined),
    V4Screen(id: 'ext-dashboard-activity', labelAr: 'النشاط', labelEn: 'Activity', icon: Icons.timeline),
    V4Screen(id: 'ext-dashboard-saved', labelAr: 'المحفوظات', labelEn: 'Saved Views', icon: Icons.bookmark_outline),
  ],
);

const extUpload = V4SubModule(
  id: 'upload',
  labelAr: 'رفع القوائم المالية',
  labelEn: 'Upload Statements',
  icon: Icons.upload_file,
  descriptionAr: 'رفع PDF/Excel، OCR، ربط الحسابات، التحقق.',
  visibleTabs: [
    V4Screen(id: 'ext-upload-file', labelAr: 'الرفع', labelEn: 'Upload', icon: Icons.cloud_upload),
    V4Screen(id: 'ext-upload-ocr', labelAr: 'التحليل و OCR', labelEn: 'Parse & OCR', icon: Icons.document_scanner),
    V4Screen(id: 'ext-upload-mapping', labelAr: 'ربط الحسابات', labelEn: 'Mapping', icon: Icons.link),
    V4Screen(id: 'ext-upload-validation', labelAr: 'التحقق', labelEn: 'Validation', icon: Icons.verified),
    V4Screen(id: 'ext-upload-history', labelAr: 'السجل', labelEn: 'History', icon: Icons.history),
  ],
);

const extRatios = V4SubModule(
  id: 'ratios',
  labelAr: 'تحليل النسب',
  labelEn: 'Ratio Analysis',
  icon: Icons.analytics_outlined,
  descriptionAr: 'السيولة، الرفع، الربحية، النشاط، السوق.',
  visibleTabs: [
    V4Screen(id: 'ext-ratios-liquidity', labelAr: 'السيولة', labelEn: 'Liquidity', icon: Icons.water_drop),
    V4Screen(id: 'ext-ratios-leverage', labelAr: 'الرفع المالي', labelEn: 'Leverage', icon: Icons.scale),
    V4Screen(id: 'ext-ratios-profit', labelAr: 'الربحية', labelEn: 'Profitability', icon: Icons.savings),
    V4Screen(id: 'ext-ratios-activity', labelAr: 'النشاط', labelEn: 'Activity', icon: Icons.autorenew),
    V4Screen(id: 'ext-ratios-market', labelAr: 'السوق', labelEn: 'Market', icon: Icons.show_chart),
  ],
);

const extBenchmark = V4SubModule(
  id: 'benchmark',
  labelAr: 'القياس الصناعي',
  labelEn: 'Industry Benchmarking',
  icon: Icons.leaderboard_outlined,
  descriptionAr: 'القطاع، مجموعة النظراء، الربعيات، الرادار.',
  visibleTabs: [
    V4Screen(id: 'ext-bench-sector', labelAr: 'القطاع', labelEn: 'Sector', icon: Icons.category),
    V4Screen(id: 'ext-bench-peers', labelAr: 'النظراء', labelEn: 'Peer Set', icon: Icons.people_outline),
    V4Screen(id: 'ext-bench-quartile', labelAr: 'الربعيات', labelEn: 'Quartile Chart', icon: Icons.bar_chart),
    V4Screen(id: 'ext-bench-radar', labelAr: 'الرادار', labelEn: 'Radar', icon: Icons.radar),
    V4Screen(id: 'ext-bench-time', labelAr: 'السلسلة الزمنية', labelEn: 'Time Series', icon: Icons.timeline),
  ],
);

const extValuation = V4SubModule(
  id: 'valuation',
  labelAr: 'نماذج التقييم',
  labelEn: 'Valuation Models',
  icon: Icons.functions,
  descriptionAr: 'DCF، Trading Comps، Precedents، NAV، Football Field.',
  visibleTabs: [
    V4Screen(id: 'ext-val-dcf', labelAr: 'DCF', labelEn: 'DCF', icon: Icons.account_tree),
    V4Screen(id: 'ext-val-comps', labelAr: 'Trading Comps', labelEn: 'Trading Comps', icon: Icons.table_view),
    V4Screen(id: 'ext-val-prec', labelAr: 'Precedents', labelEn: 'Precedents', icon: Icons.history_toggle_off),
    V4Screen(id: 'ext-val-nav', labelAr: 'NAV', labelEn: 'NAV', icon: Icons.calculate),
    V4Screen(id: 'ext-val-ff', labelAr: 'Football Field', labelEn: 'Football Field', icon: Icons.sports_score),
  ],
);

const extCredit = V4SubModule(
  id: 'credit',
  labelAr: 'تحليل الائتمان',
  labelEn: 'Credit Analysis',
  icon: Icons.credit_score_outlined,
  descriptionAr: 'درجة الائتمان، التصنيف، العهود، التحذير المبكر.',
  visibleTabs: [
    V4Screen(id: 'ext-credit-score', labelAr: 'درجة الائتمان', labelEn: 'Credit Score', icon: Icons.speed),
    V4Screen(id: 'ext-credit-rating', labelAr: 'التصنيف', labelEn: 'Risk Rating', icon: Icons.grade),
    V4Screen(id: 'ext-credit-covenants', labelAr: 'العهود', labelEn: 'Covenants', icon: Icons.rule_folder),
    V4Screen(id: 'ext-credit-coverage', labelAr: 'تغطية التدفق', labelEn: 'Cash Flow Coverage', icon: Icons.waterfall_chart),
    V4Screen(id: 'ext-credit-warning', labelAr: 'التحذير المبكر', labelEn: 'Early Warning', icon: Icons.warning_amber),
  ],
);

const extReports = V4SubModule(
  id: 'reports',
  labelAr: 'التقارير التحليلية',
  labelEn: 'Analytical Reports',
  icon: Icons.assignment_outlined,
  descriptionAr: 'تنفيذي، مذكرة ائتمان، فحص نافي للجهالة، تقييم.',
  visibleTabs: [
    V4Screen(id: 'ext-rep-exec', labelAr: 'التنفيذي', labelEn: 'Executive', icon: Icons.article),
    V4Screen(id: 'ext-rep-credit', labelAr: 'مذكرة ائتمان', labelEn: 'Credit Memo', icon: Icons.credit_card),
    V4Screen(id: 'ext-rep-dd', labelAr: 'الفحص النافي', labelEn: 'Due Diligence', icon: Icons.search),
    V4Screen(id: 'ext-rep-opinion', labelAr: 'رأي التقييم', labelEn: 'Valuation Opinion', icon: Icons.gavel),
    V4Screen(id: 'ext-rep-custom', labelAr: 'مخصص', labelEn: 'Custom', icon: Icons.edit_document),
  ],
);

// ── Service Providers (6 sub-modules) ──

const providersDashboard = V4SubModule(
  id: 'dashboard',
  labelAr: 'لوحة مقدم الخدمة',
  labelEn: 'Provider Dashboard',
  icon: Icons.dashboard_outlined,
  descriptionAr: 'الأرباح، الوظائف النشطة، التقييمات، خط الخدمات.',
  visibleTabs: [
    V4Screen(id: 'providers-dashboard-earnings', labelAr: 'الأرباح', labelEn: 'Earnings', icon: Icons.paid),
    V4Screen(id: 'providers-dashboard-jobs', labelAr: 'الوظائف النشطة', labelEn: 'Active Jobs', icon: Icons.work_outline),
    V4Screen(id: 'providers-dashboard-ratings', labelAr: 'التقييمات', labelEn: 'Ratings', icon: Icons.star_outline),
    V4Screen(id: 'providers-dashboard-pipeline', labelAr: 'خط الخدمات', labelEn: 'Pipeline', icon: Icons.view_kanban_outlined),
    V4Screen(id: 'providers-dashboard-calendar', labelAr: 'التقويم', labelEn: 'Calendar', icon: Icons.calendar_month),
  ],
);

const providersMarketplace = V4SubModule(
  id: 'marketplace',
  labelAr: 'السوق',
  labelEn: 'Marketplace',
  icon: Icons.store_outlined,
  descriptionAr: 'تصفح، بحث، مقارنة، خريطة، مشاهدات حديثة.',
  visibleTabs: [
    V4Screen(id: 'providers-mkt-browse', labelAr: 'تصفح', labelEn: 'Browse', icon: Icons.grid_view),
    V4Screen(id: 'providers-mkt-saved', labelAr: 'بحث محفوظ', labelEn: 'Saved Searches', icon: Icons.bookmark),
    V4Screen(id: 'providers-mkt-compare', labelAr: 'مقارنة', labelEn: 'Compare', icon: Icons.compare),
    V4Screen(id: 'providers-mkt-map', labelAr: 'عرض خريطة', labelEn: 'Map View', icon: Icons.map),
    V4Screen(id: 'providers-mkt-recent', labelAr: 'المشاهدات الحديثة', labelEn: 'Recently Viewed', icon: Icons.history),
  ],
);

const providersLegal = V4SubModule(
  id: 'legal',
  labelAr: 'العقود والقانون',
  labelEn: 'Legal & Contracts',
  icon: Icons.gavel_outlined,
  descriptionAr: 'عقود، قوالب، توقيع إلكتروني، أميال، تعديلات.',
  visibleTabs: [
    V4Screen(id: 'providers-legal-contracts', labelAr: 'العقود', labelEn: 'Contracts', icon: Icons.description),
    V4Screen(id: 'providers-legal-templates', labelAr: 'القوالب', labelEn: 'Templates', icon: Icons.content_copy),
    V4Screen(id: 'providers-legal-esign', labelAr: 'التوقيع الإلكتروني', labelEn: 'E-Signature', icon: Icons.edit_outlined),
    V4Screen(id: 'providers-legal-milestones', labelAr: 'الأميال', labelEn: 'Milestones', icon: Icons.flag),
    V4Screen(id: 'providers-legal-variations', labelAr: 'التعديلات', labelEn: 'Variations', icon: Icons.edit_note),
  ],
);

const providersTasks = V4SubModule(
  id: 'tasks',
  labelAr: 'المهام والتسليمات',
  labelEn: 'Tasks & Deliverables',
  icon: Icons.task_alt_outlined,
  descriptionAr: 'Kanban، قائمة، جدول زمني، ملفات، محادثة.',
  visibleTabs: [
    V4Screen(id: 'providers-tasks-kanban', labelAr: 'Kanban', labelEn: 'Kanban', icon: Icons.view_kanban),
    V4Screen(id: 'providers-tasks-list', labelAr: 'قائمة', labelEn: 'List', icon: Icons.list),
    V4Screen(id: 'providers-tasks-timeline', labelAr: 'الجدول الزمني', labelEn: 'Timeline', icon: Icons.view_timeline),
    V4Screen(id: 'providers-tasks-files', labelAr: 'الملفات', labelEn: 'Files', icon: Icons.folder),
    V4Screen(id: 'providers-tasks-chat', labelAr: 'المحادثة', labelEn: 'Chat', icon: Icons.chat_bubble_outline),
  ],
);

const providersBilling = V4SubModule(
  id: 'billing',
  labelAr: 'الفوترة والمدفوعات',
  labelEn: 'Billing & Payments',
  icon: Icons.payments_outlined,
  descriptionAr: 'الفواتير، الضمان، الدفعات، النزاعات، كشوف حساب.',
  visibleTabs: [
    V4Screen(id: 'providers-bill-invoices', labelAr: 'الفواتير', labelEn: 'Invoices', icon: Icons.receipt_long),
    V4Screen(id: 'providers-bill-escrow', labelAr: 'الضمان', labelEn: 'Escrow', icon: Icons.lock_outline),
    V4Screen(id: 'providers-bill-payouts', labelAr: 'الدفعات', labelEn: 'Payouts', icon: Icons.account_balance_wallet),
    V4Screen(id: 'providers-bill-disputes', labelAr: 'النزاعات', labelEn: 'Disputes', icon: Icons.flag_outlined),
    V4Screen(id: 'providers-bill-statements', labelAr: 'كشوف الحساب', labelEn: 'Statements', icon: Icons.description_outlined),
  ],
);

const providersRatings = V4SubModule(
  id: 'ratings',
  labelAr: 'التقييمات والمراجعات',
  labelEn: 'Ratings & Reviews',
  icon: Icons.reviews_outlined,
  descriptionAr: 'تقييماتي، أعطِ تقييم، الردود، التحليلات، النزاعات.',
  visibleTabs: [
    V4Screen(id: 'providers-rat-my', labelAr: 'تقييماتي', labelEn: 'My Reviews', icon: Icons.star),
    V4Screen(id: 'providers-rat-give', labelAr: 'أعطِ تقييمًا', labelEn: 'Give Review', icon: Icons.rate_review),
    V4Screen(id: 'providers-rat-responses', labelAr: 'الردود', labelEn: 'Responses', icon: Icons.reply),
    V4Screen(id: 'providers-rat-analytics', labelAr: 'التحليلات', labelEn: 'Analytics', icon: Icons.insights),
    V4Screen(id: 'providers-rat-disputes', labelAr: 'النزاعات', labelEn: 'Disputes', icon: Icons.gavel),
  ],
);

// ── Eligibility & Compliance (7 sub-modules) ──

const complianceDashboard = V4SubModule(
  id: 'dashboard',
  labelAr: 'لوحة الامتثال',
  labelEn: 'Compliance Dashboard',
  icon: Icons.dashboard_outlined,
  descriptionAr: 'لقطة الحالة، المواعيد، التنبيهات، صحة الشهادات.',
  visibleTabs: [
    V4Screen(id: 'compliance-dashboard-status', labelAr: 'الحالة', labelEn: 'Status', icon: Icons.health_and_safety_outlined),
    V4Screen(id: 'compliance-dashboard-deadlines', labelAr: 'المواعيد', labelEn: 'Deadlines', icon: Icons.event_note),
    V4Screen(id: 'compliance-dashboard-alerts', labelAr: 'التنبيهات', labelEn: 'Alerts', icon: Icons.notifications_active_outlined),
    V4Screen(id: 'compliance-dashboard-certs', labelAr: 'الشهادات', labelEn: 'Certificates', icon: Icons.verified),
    V4Screen(id: 'compliance-dashboard-filings', labelAr: 'سجل التقديم', labelEn: 'Filings Log', icon: Icons.history),
  ],
);

const complianceEligibility = V4SubModule(
  id: 'eligibility',
  labelAr: 'فحص الأهلية',
  labelEn: 'Eligibility Check',
  icon: Icons.fact_check_outlined,
  descriptionAr: 'SME، IPO، تداول، المناقصات، المنح — معايير وتقارير الفجوة.',
  visibleTabs: [
    V4Screen(id: 'compliance-elig-run', labelAr: 'تشغيل فحص', labelEn: 'Run Check', icon: Icons.play_arrow),
    V4Screen(id: 'compliance-elig-my', labelAr: 'فحوصاتي', labelEn: 'My Checks', icon: Icons.folder_open),
    V4Screen(id: 'compliance-elig-criteria', labelAr: 'مكتبة المعايير', labelEn: 'Criteria Library', icon: Icons.menu_book),
    V4Screen(id: 'compliance-elig-gap', labelAr: 'تقرير الفجوة', labelEn: 'Gap Report', icon: Icons.rule),
    V4Screen(id: 'compliance-elig-remediation', labelAr: 'خطة المعالجة', labelEn: 'Remediation Plan', icon: Icons.build_outlined),
  ],
);

const complianceZatca = V4SubModule(
  id: 'zatca',
  labelAr: 'امتثال ZATCA',
  labelEn: 'ZATCA Compliance',
  icon: Icons.verified_outlined,
  descriptionAr: 'جاهزية الفوترة الإلكترونية، VAT، الشهادات، التقديم.',
  visibleTabs: [
    V4Screen(id: 'compliance-zatca-status', labelAr: 'حالة الفوترة', labelEn: 'E-Invoicing Status', icon: Icons.receipt_long),
    V4Screen(id: 'compliance-zatca-vat', labelAr: 'تقويم VAT', labelEn: 'VAT Calendar', icon: Icons.calendar_today),
    V4Screen(id: 'compliance-zatca-certs', labelAr: 'الشهادات', labelEn: 'Certificates', icon: Icons.verified_user),
    V4Screen(id: 'compliance-zatca-log', labelAr: 'سجل التخليص', labelEn: 'Clearance Log', icon: Icons.history_edu),
    V4Screen(id: 'compliance-zatca-corrections', labelAr: 'التصحيحات', labelEn: 'Corrections', icon: Icons.edit_note),
  ],
);

const complianceGosi = V4SubModule(
  id: 'gosi',
  labelAr: 'GOSI و WPS',
  labelEn: 'GOSI & WPS',
  icon: Icons.groups_outlined,
  descriptionAr: 'قائمة الموظفين، التقديمات الشهرية، مزامنة Mudad.',
  visibleTabs: [
    V4Screen(id: 'compliance-gosi-roster', labelAr: 'قائمة الموظفين', labelEn: 'Roster', icon: Icons.people),
    V4Screen(id: 'compliance-gosi-submission', labelAr: 'التقديم الشهري', labelEn: 'Monthly Submission', icon: Icons.upload),
    V4Screen(id: 'compliance-gosi-wps', labelAr: 'Mudad / WPS', labelEn: 'Mudad / WPS', icon: Icons.sync),
    V4Screen(id: 'compliance-gosi-variance', labelAr: 'الفروقات', labelEn: 'Variance', icon: Icons.error_outline),
    V4Screen(id: 'compliance-gosi-history', labelAr: 'السجل', labelEn: 'History', icon: Icons.history),
  ],
);

const complianceAml = V4SubModule(
  id: 'aml',
  labelAr: 'مكافحة غسيل الأموال',
  labelEn: 'AML & KYC',
  icon: Icons.shield_outlined,
  descriptionAr: 'فحص، مراقبة، SAR/STR، إدارة الحالات.',
  visibleTabs: [
    V4Screen(id: 'compliance-aml-screening', labelAr: 'الفحص', labelEn: 'Screening', icon: Icons.search),
    V4Screen(id: 'compliance-aml-cases', labelAr: 'الحالات', labelEn: 'Cases', icon: Icons.folder_special),
    V4Screen(id: 'compliance-aml-rules', labelAr: 'قواعد المراقبة', labelEn: 'Monitoring Rules', icon: Icons.rule),
    V4Screen(id: 'compliance-aml-sar', labelAr: 'SAR Filings', labelEn: 'SAR Filings', icon: Icons.report),
    V4Screen(id: 'compliance-aml-watchlist', labelAr: 'القائمة المراقبة', labelEn: 'Watchlist', icon: Icons.visibility),
  ],
);

const complianceGovernance = V4SubModule(
  id: 'governance',
  labelAr: 'الحوكمة والمجلس',
  labelEn: 'Governance & Board',
  icon: Icons.account_balance_outlined,
  descriptionAr: 'حزمة المجلس، الاجتماعات، المحاضر، القرارات، السياسات.',
  visibleTabs: [
    V4Screen(id: 'compliance-gov-board', labelAr: 'حزمة المجلس', labelEn: 'Board Pack', icon: Icons.business_center),
    V4Screen(id: 'compliance-gov-meetings', labelAr: 'الاجتماعات', labelEn: 'Meetings', icon: Icons.event_available),
    V4Screen(id: 'compliance-gov-minutes', labelAr: 'المحاضر', labelEn: 'Minutes', icon: Icons.assignment),
    V4Screen(id: 'compliance-gov-resolutions', labelAr: 'القرارات', labelEn: 'Resolutions', icon: Icons.gavel),
    V4Screen(id: 'compliance-gov-policies', labelAr: 'السياسات', labelEn: 'Policies', icon: Icons.policy),
  ],
);

const complianceReports = V4SubModule(
  id: 'reports',
  labelAr: 'تقارير الامتثال',
  labelEn: 'Compliance Reports',
  icon: Icons.summarize_outlined,
  descriptionAr: 'تنظيمية، للمجلس، جاهزة للتدقيق، مخصصة، مجدولة.',
  visibleTabs: [
    V4Screen(id: 'compliance-rep-regulatory', labelAr: 'تنظيمية', labelEn: 'Regulatory', icon: Icons.gavel),
    V4Screen(id: 'compliance-rep-board', labelAr: 'للمجلس', labelEn: 'Board', icon: Icons.business_center),
    V4Screen(id: 'compliance-rep-audit', labelAr: 'جاهزة للتدقيق', labelEn: 'Audit-Ready', icon: Icons.fact_check),
    V4Screen(id: 'compliance-rep-custom', labelAr: 'مخصصة', labelEn: 'Custom', icon: Icons.edit_document),
    V4Screen(id: 'compliance-rep-scheduled', labelAr: 'مجدولة', labelEn: 'Scheduled', icon: Icons.schedule),
  ],
);

// ── Public sub-module lists (consumed by v4_groups.dart) ────────────

const List<V4SubModule> auditSubModules = [
  auditDashboard,
  auditPlanning,
  auditRisk,
  auditWorkpapers,
  auditTesting,
  auditReport,
  auditQc,
];

const List<V4SubModule> feasSubModules = [
  feasDashboard,
  feasSetup,
  feasMarket,
  feasCost,
  feasProForma,
  feasValuation,
  feasSensitivity,
  feasFinal,
];

const List<V4SubModule> externalSubModules = [
  extDashboard,
  extUpload,
  extRatios,
  extBenchmark,
  extValuation,
  extCredit,
  extReports,
];

const List<V4SubModule> providersSubModules = [
  providersDashboard,
  providersMarketplace,
  providersLegal,
  providersTasks,
  providersBilling,
  providersRatings,
];

const List<V4SubModule> complianceSubModules = [
  complianceDashboard,
  complianceEligibility,
  complianceZatca,
  complianceGosi,
  complianceAml,
  complianceGovernance,
  complianceReports,
];
