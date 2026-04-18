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
import '../../screens/v4_ai/ai_guardrails_screen.dart';
import '../../screens/v4_compliance/aml_kyc_screen.dart';
import '../../screens/v4_compliance/audit_analytics_screen.dart';
import '../../screens/v4_compliance/audit_reporting_screen.dart';
import '../../screens/v4_compliance/compliance_status_screen.dart';
import '../../screens/v4_compliance/gosi_wps_screen.dart';
import '../../screens/v4_compliance/workpapers_detail_screen.dart';
import '../../screens/v4_compliance/realtime_tax_screen.dart';
import '../../screens/v4_compliance/zatca_csid_screen.dart';
import '../../screens/v4_compliance/zatca_queue_screen.dart';
import '../../screens/v4_erp/ai_bank_reconciliation_screen.dart';
import '../../screens/v4_erp/apex_match_screen.dart';
import '../../screens/v4_erp/apex_studio_screen.dart';
import '../../screens/v4_erp/bank_feeds_screen.dart';
import '../../screens/v4_erp/client_portal_screen.dart';
import '../../screens/v4_erp/connected_planning_screen.dart';
import '../../screens/v4_erp/crm_screen.dart';
import '../../screens/v4_erp/hr_employees_screen.dart';
import '../../screens/v4_erp/invoices_multi_view_screen.dart';
import '../../screens/v4_erp/mobile_receipt_screen.dart';
import '../../screens/v4_erp/onboarding_screen.dart';
import '../../screens/v4_erp/projects_screen.dart';
import '../../screens/v4_erp/purchasing_ap_screen.dart';
import '../../screens/v4_erp/sales_customers_screen.dart';

/// Key format: `{serviceId}/{mainId}/{chipId}`.
/// Returns the Flutter widget to render for that chip.
///
/// When a chip has both a dashboard (isDashboard=true) and a wired
/// screen, the dashboard wins — wired screens are for non-dashboard
/// chips that exist in production today.
typedef V5ChipBuilder = Widget Function(BuildContext ctx);

final Map<String, V5ChipBuilder> v5WiredScreens = {
  // ── ERP ──────────────────────────────────────────────────────────
  'erp/finance/sales': (ctx) => const SalesCustomersScreen(),
  'erp/treasury/banks': (ctx) => const BankFeedsScreen(),
  // Multiple Views demo (Enhancement #4)
  'erp/finance/invoices': (ctx) => const InvoicesMultiViewScreen(),
  // Wave 16 — AI Bank Reconciliation (V5.1 POC)
  'erp/treasury/recon': (ctx) => const AiBankReconciliationScreen(),
  // Wave 17 — Purchasing & AP (replaces AP placeholder)
  'erp/finance/ap': (ctx) => const PurchasingApScreen(),
  // Wave 18 — HR Employees
  'erp/hr/employees': (ctx) => const HrEmployeesScreen(),
  // Wave 19 — Projects (Tasks/Timesheets/Gantt/Billing)
  'erp/operations/projects': (ctx) => const ProjectsScreen(),
  // Wave 20 — CRM (Leads/Opportunities/Pipeline/Activities/Contacts)
  'erp/operations/crm': (ctx) => const CrmScreen(),
  // Onboarding Journey (#8)
  'erp/finance/onboarding': (ctx) => const OnboardingScreen(),
  // Connected Planning Drivers (#16) — Anaplan replacement
  'erp/finance/budgets': (ctx) => const ConnectedPlanningScreen(),
  // Mobile Receipt Capture (#20) — Expensify replacement
  'erp/finance/consolidation': (ctx) => const MobileReceiptScreen(),
  // Client Portal (#12) — Freshbooks replacement
  'erp/finance/reports': (ctx) => const ClientPortalScreen(),
  // APEX Studio no-code (#11) — Odoo Studio replacement
  'erp/finance/gl': (ctx) => const ApexStudioScreen(),

  // ── Marketplace ──────────────────────────────────────────────────
  // APEX Match AI pairing (#15) — Toptal-style
  'marketplace/client/browse': (ctx) => const ApexMatchScreen(),

  // ── Compliance & Tax ─────────────────────────────────────────────
  'compliance/zatca/csid': (ctx) => const ZatcaCsidScreen(),
  'compliance/zatca/zatca-queue': (ctx) => const ZatcaQueueScreen(),
  'compliance/zatca/queue': (ctx) => const ZatcaQueueScreen(),
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

  // ── AI Settings (horizontal layer — still accessible via /app) ───
  'compliance/regulatory/aml': (ctx) => const AiGuardrailsScreen(),
  // Note: Guardrails UI is the most generic "AI review queue" we have.
  // In production it moves to /settings/ai-agents.
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
