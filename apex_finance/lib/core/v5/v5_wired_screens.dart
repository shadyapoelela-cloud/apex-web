/// APEX V5.1 — Wired Screens Registry.
///
/// Maps V5 chip paths (`{service}/{main}/{chip}`) to the existing
/// Flutter screens built in brave-yonath (Waves 1-15).
///
/// Pure additive — we don't duplicate logic, we reuse widgets.
///
/// To add more wired screens: append to the _wired map. If a chip is
/// not in the map, V5 falls back to its default behaviour (dashboard
/// widgets or V4 sub-module reuse or coming-soon banner).
library;

import 'package:flutter/material.dart';

// Reuse existing brave-yonath screens (Waves 2-14).
// These imports may trigger transitive package imports; build verifies.
import '../../screens/v4_ai/ai_agents_gallery_screen.dart';
import '../../screens/v4_compliance/aml_kyc_screen.dart';
import '../../screens/v4_compliance/audit_analytics_screen.dart';
import '../../screens/v4_compliance/audit_reporting_screen.dart';
import '../../screens/v4_compliance/compliance_status_screen.dart';
import '../../screens/v4_compliance/gosi_wps_screen.dart';
import '../../screens/v4_compliance/governance_screen.dart';
import '../../screens/v4_compliance/workpapers_detail_screen.dart';
import '../../screens/v4_compliance/realtime_tax_screen.dart';
import '../../screens/v4_erp/admin_panel_screen.dart';
import '../../screens/v4_erp/ai_bank_reconciliation_screen.dart';
import '../../screens/v4_erp/apex_match_screen.dart';
import '../../screens/v4_erp/apex_studio_screen.dart';
import '../../screens/v4_compliance/audit_acceptance_screen.dart';
import '../../screens/v4_compliance/audit_kickoff_screen.dart';
import '../../screens/v4_compliance/audit_planning_screen.dart';
import '../../screens/v4_compliance/tax_calendar_screen.dart';
import '../../screens/v4_compliance/transfer_pricing_v5_screen.dart';
import '../../screens/v4_compliance/uae_ct_screen.dart';
import '../../screens/v4_compliance/vat_return_builder_screen.dart';
import '../../screens/v4_compliance/wht_calculator_v5_screen.dart';
import '../../screens/v4_compliance/zakat_calculator_v5_screen.dart';
import '../../screens/v4_erp/benefits_eos_screen.dart';
import '../../screens/v4_erp/budget_vs_actual_screen.dart';
import '../../screens/v4_erp/expense_claims_screen.dart';
import '../../screens/v4_erp/cash_flow_forecast_screen.dart';
import '../../screens/v4_erp/client_portal_screen.dart';
import '../../screens/v4_erp/connected_planning_screen.dart';
import '../../screens/v4_erp/activity_log_screen.dart';
import '../../screens/v4_erp/close_checklist_screen.dart';
import '../../screens/v4_erp/project_profitability_screen.dart';
import '../../screens/v4_erp/contract_management_screen.dart';
import '../../screens/v4_erp/crm_screen.dart';
import '../../screens/v4_erp/document_vault_screen.dart';
import '../../screens/v4_erp/executive_dashboard_v5_screen.dart';
import '../../screens/v4_erp/customer_360_screen.dart';
import '../../screens/v4_erp/fixed_assets_register_screen.dart';
import '../../screens/v4_erp/fx_management_screen.dart';
import '../../screens/v4_erp/general_ledger_screen.dart';
import '../../screens/v4_erp/leave_management_screen.dart';
import '../../screens/v4_erp/manufacturing_screen.dart';
import '../../screens/v4_erp/feasibility_deep_screen.dart';
import '../../screens/v4_erp/financial_statements_screen.dart';
import '../../screens/v4_erp/hr_employees_screen.dart';
import '../../screens/v4_erp/industry_packs_screen.dart';
import '../../screens/v4_erp/marketplace_deep_screen.dart';
import '../../screens/v4_erp/invoices_multi_view_screen.dart';
import '../../screens/v4_erp/je_builder_screen.dart';
import '../../screens/v4_erp/sales_workflow_screen.dart';
import '../../screens/v4_erp/mobile_receipt_screen.dart';
import '../../screens/v4_erp/onboarding_screen.dart';
import '../../screens/v4_erp/payroll_run_screen.dart';
import '../../screens/v4_erp/projects_screen.dart';
import '../../screens/v4_erp/purchasing_ap_screen.dart';
import '../../screens/v4_erp/sales_pipeline_screen.dart';
import '../../screens/v4_erp/supplier_360_screen.dart';

/// Key format: `{serviceId}/{mainId}/{chipId}`.
/// Returns the Flutter widget to render for that chip.
///
/// When a chip has both a dashboard (isDashboard=true) and a wired
/// screen, the dashboard wins — wired screens are for non-dashboard
/// chips that exist in production today.
typedef V5ChipBuilder = Widget Function(BuildContext ctx);

final Map<String, V5ChipBuilder> v5WiredScreens = {
  // ── ERP ──────────────────────────────────────────────────────────
  // Note: 'erp/finance/sales' and 'erp/treasury/banks' are intentionally
  // NOT wired in this POC build — they call the authenticated backend
  // and would show "unauthorized" without a login flow. They stay in
  // production (the screens still exist) and fall back to the V5
  // default dashboard/coming-soon in the POC.
  // Multiple Views demo (Enhancement #4)
  'erp/finance/invoices': (ctx) => const InvoicesMultiViewScreen(),
  // Wave 16 — AI Bank Reconciliation (V5.1 POC)
  'erp/treasury/recon': (ctx) => const AiBankReconciliationScreen(),
  // Wave 17 — Purchasing & AP (replaces AP placeholder)
  'erp/finance/ap': (ctx) => const PurchasingApScreen(),
  // Wave 18 — HR Employees
  'erp/hr/employees': (ctx) => const HrEmployeesScreen(),
  // Wave 40 — Payroll Run
  'erp/hr/payroll': (ctx) => const PayrollRunScreen(),
  // Wave 19 — Projects (Tasks/Timesheets/Gantt/Billing)
  'erp/operations/projects': (ctx) => const ProjectsScreen(),
  // Wave 20 — CRM (Leads/Opportunities/Pipeline/Activities/Contacts)
  'erp/operations/crm': (ctx) => const CrmScreen(),
  // Wave 25 — Feasibility Market Analysis (Advisory)
  'advisory/feasibility/market': (ctx) => const FeasibilityMarketScreen(),
  'advisory/feasibility/sensitivity': (ctx) => const FeasibilityMarketScreen(),
  // Wave 26 — External Analysis (Benchmarking + Credit)
  'advisory/external/benchmarking': (ctx) => const ExternalAnalysisScreen(),
  'advisory/external/credit': (ctx) => const ExternalAnalysisScreen(),

  // ── Marketplace Deep ─────────────────────────────────────────────
  // Wave 27 — Marketplace Billing/Escrow/Payouts
  'marketplace/client/billing': (ctx) => const MarketplaceBillingScreen(),
  'marketplace/provider/payouts': (ctx) => const MarketplaceBillingScreen(),

  // Wave 28 — Eligibility Check (KSA SME/Nomu/Tadawul)
  'compliance/regulatory/eligibility': (ctx) => const EligibilityCheckScreen(),
  'compliance/regulatory/governance': (ctx) => const GovernanceScreen(),
  // Wave 32 — Notifications Center
  'platform/notifications/center': (ctx) => const NotificationsCenterScreen(),
  // Wave 33 — Industry Packs (F&B / Manufacturing / Healthcare / Logistics / Retail)
  'marketplace/client/industry-packs': (ctx) => const IndustryPacksScreen(),
  // Wave 34 — Help Center
  'platform/help/center': (ctx) => const HelpCenterScreen(),
  // Wave 37 — JE Builder + Period Close (CRITICAL)
  'erp/finance/je-builder': (ctx) => const JeBuilderScreen(),
  'erp/finance/period-close': (ctx) => const PeriodCloseScreen(),
  // Wave 38 — Sales Workflow (CRITICAL)
  'erp/finance/sales-workflow': (ctx) => const SalesWorkflowScreen(),
  // Wave 39 — Financial Statements + CoA + Inventory (CRITICAL)
  'erp/finance/statements': (ctx) => const FinancialStatementsScreen(),
  'erp/finance/coa-editor': (ctx) => const CoaEditorScreen(),
  // Inventory chip is now wired to the detailed view
  'erp/operations/inventory': (ctx) => const InventoryDetailedScreen(),
  // Wave 41 — General Ledger viewer (replaces confusing ApexStudio wiring)
  'erp/finance/gl': (ctx) => const GeneralLedgerScreen(),
  // Wave 42 — 13-week Cash Flow Forecast
  'erp/treasury/cashflow': (ctx) => const CashFlowForecastScreen(),
  // Wave 43 — Zakat Calculator (ZATCA-compliant)
  'compliance/tax/zakat': (ctx) => const ZakatCalculatorV5Screen(),
  // Wave 44 — Fixed Assets Register
  'erp/finance/fixed-assets': (ctx) => const FixedAssetsRegisterScreen(),
  // Wave 45 — Leave Management
  'erp/hr/leaves': (ctx) => const LeaveManagementScreen(),
  // Wave 46 — Manufacturing & BOM
  'erp/operations/manufacturing': (ctx) => const ManufacturingScreen(),
  // Wave 47 — WHT Calculator (ZATCA withholding tax)
  'compliance/tax/wht': (ctx) => const WhtCalculatorV5Screen(),
  // Wave 48 — Audit Engagement Planning
  'audit/engagement/planning': (ctx) => const AuditPlanningScreen(),
  // Wave 49 — FX / Currency Management
  'erp/treasury/fx': (ctx) => const FxManagementScreen(),
  // Wave 50 — UAE Corporate Tax
  'compliance/tax/uae_ct': (ctx) => const UaeCtScreen(),
  // Wave 51 — Transfer Pricing
  'compliance/tax/tp': (ctx) => const TransferPricingV5Screen(),
  // Wave 52 — Budget vs Actual
  'erp/finance/budget-actual': (ctx) => const BudgetVsActualScreen(),
  // Wave 53 — Benefits & End-of-Service
  'erp/hr/benefits': (ctx) => const BenefitsEosScreen(),
  // Wave 54 — Tax Calendar (unified deadlines)
  'compliance/tax/calendar': (ctx) => const TaxCalendarScreen(),
  // Wave 55 — Expense Claims
  'erp/finance/expenses': (ctx) => const ExpenseClaimsScreen(),
  // Wave 56 — Audit Acceptance
  'audit/engagement/acceptance': (ctx) => const AuditAcceptanceScreen(),
  // Wave 57 — Supplier 360
  'erp/operations/suppliers': (ctx) => const Supplier360Screen(),
  // Wave 58 — Customer 360
  'erp/operations/customers-360': (ctx) => const Customer360Screen(),
  // Wave 59 — Audit Kickoff
  'audit/engagement/kickoff': (ctx) => const AuditKickoffScreen(),
  // Wave 60 — Sales Pipeline (Kanban)
  'erp/operations/pipeline': (ctx) => const SalesPipelineScreen(),
  // Wave 61 — Contract Management
  'erp/operations/contracts': (ctx) => const ContractManagementScreen(),
  // Wave 62 — Executive Dashboard (C-Suite)
  'erp/finance/exec': (ctx) => const ExecutiveDashboardV5Screen(),
  // Wave 63 — Document Vault / DMS
  'erp/finance/documents': (ctx) => const DocumentVaultScreen(),
  // Wave 64 — Activity Log / Audit Trail
  'compliance/regulatory/activity-log': (ctx) => const ActivityLogScreen(),
  // Wave 65 — VAT Return Builder
  'compliance/tax/vat-return': (ctx) => const VatReturnBuilderScreen(),
  // Wave 66 — Project Profitability
  'erp/operations/project-pnl': (ctx) => const ProjectProfitabilityScreen(),
  // Wave 67 — Financial Close Checklist
  'erp/finance/close-checklist': (ctx) => const CloseChecklistScreen(),
  // Wave 35 — AI Agents Gallery
  'platform/ai/agents': (ctx) => const AiAgentsGalleryScreen(),
  // Wave 36 — Global Search Results
  'platform/search/results': (ctx) => const GlobalSearchScreen(),
  // Wave 29 — Admin Panel (Tenant Settings + Users + Integrations)
  'platform/admin/settings': (ctx) => const AdminPanelScreen(),
  // Wave 30 — Custom Report Builder
  'erp/finance/custom-reports': (ctx) => const ReportBuilderScreen(),
  // Onboarding Journey (#8)
  'erp/finance/onboarding': (ctx) => const OnboardingScreen(),
  // Connected Planning Drivers (#16) — Anaplan replacement
  'erp/finance/budgets': (ctx) => const ConnectedPlanningScreen(),
  // Mobile Receipt Capture (#20) — Expensify replacement
  // Lives under Operations as a dedicated chip, not under Finance.
  'erp/operations/mobile-receipt': (ctx) => const MobileReceiptScreen(),
  // Client Portal (#12) — Freshbooks replacement
  'platform/portal/client': (ctx) => const ClientPortalScreen(),
  // APEX Studio no-code (#11) — Odoo Studio replacement
  'platform/studio/builder': (ctx) => const ApexStudioScreen(),

  // ── Marketplace ──────────────────────────────────────────────────
  // APEX Match AI pairing (#15) — Toptal-style
  'marketplace/client/browse': (ctx) => const ApexMatchScreen(),

  // ── Compliance & Tax ─────────────────────────────────────────────
  // ZATCA CSID / queue screens call the authenticated backend — not
  // wired in POC (same reason as sales/banks above).
  // Real-time GCC Tax Calculator — World-first feature
  'compliance/tax/vat': (ctx) => const RealtimeTaxScreen(),
  'compliance/tax/realtime': (ctx) => const RealtimeTaxScreen(),

  // Wave 21 — GOSI & WPS UI
  'compliance/regulatory/gosi': (ctx) => const GosiWpsScreen(),
  'compliance/regulatory/wps': (ctx) => const GosiWpsScreen(),
  // Wave 22 — AML & KYC (override the previous placeholder)
  'compliance/regulatory/aml': (ctx) => const AmlKycScreen(),

  // ── Audit ────────────────────────────────────────────────────────
  'audit/fieldwork/risk': (ctx) => const ComplianceStatusScreen(),
  // Wave 17 Audit Analytics (Inflo/MindBridge replacement)
  'audit/fieldwork/control': (ctx) => const AuditAnalyticsScreen(),
  // Wave 23 — Workpapers detailed view (CaseWare-class)
  'audit/fieldwork/workpapers': (ctx) => const WorkpapersDetailScreen(),
  // Wave 24 — Audit Reporting (Opinion Builder + Management Letter + QC)
  'audit/reporting/opinion': (ctx) => const AuditReportingScreen(),
  'audit/reporting/ml': (ctx) => const AuditReportingScreen(),
  'audit/reporting/qc': (ctx) => const AuditReportingScreen(),

  // Note: AiGuardrailsScreen is API-backed so it's not wired here.
  // In production it lives under /settings/ai-agents with auth.
};

/// Returns true if a chip has a wired screen.
bool isChipWired(String serviceId, String mainId, String chipId) {
  final key = '$serviceId/$mainId/$chipId';
  return v5WiredScreens.containsKey(key);
}

/// Returns the wired builder or null.
V5ChipBuilder? getWiredBuilder(String serviceId, String mainId, String chipId) {
  final key = '$serviceId/$mainId/$chipId';
  return v5WiredScreens[key];
}
