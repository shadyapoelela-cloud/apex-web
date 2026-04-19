/// APEX V5.1 — Wired Screens Registry.
///
/// Maps V5 chip paths (`{service}/{main}/{chip}`) to the existing
/// Flutter screens built in brave-yonath (Waves 1-146).
///
/// Pure additive — we don't duplicate logic, we reuse widgets.
///
/// V4 Blueprint restructure (Phase 1): ERP is now 16 apps instead of 4.
/// Route keys updated to match new module IDs:
///   - sales → erp/sales/* (was erp/finance/*)
///   - purchasing → erp/purchasing/* (was erp/finance/ap + erp/operations/*)
///   - consolidation → erp/consolidation/* (was erp/finance/*)
///   - inventory → erp/inventory/* (was erp/operations/*)
///   - projects → erp/projects/* (was erp/operations/*)
///   - crm-marketing → erp/crm-marketing/* (was erp/operations/*)
///   - manufacturing → erp/manufacturing/* (first-class)
///   - hotel-pms → erp/hotel-pms/* (first-class)
///   - construction → erp/construction/* (first-class)
///   - industry-packs → erp/industry-packs/* (was erp/operations/*)
///   - reports-bi → erp/reports-bi/* (was erp/finance/*)
///   - expenses → erp/expenses/* (was erp/finance/expenses)
///   - pos → erp/pos/* (was erp/operations/*)
library;

import 'package:flutter/material.dart';

// Reuse existing brave-yonath screens (Waves 2-146).
import '../../screens/v4_ai/ai_agents_gallery_screen.dart';
import '../../screens/v4_compliance/aml_kyc_screen.dart';
import '../../screens/v4_compliance/audit_analytics_screen.dart';
import '../../screens/v4_compliance/audit_reporting_screen.dart';
import '../../screens/compliance/consolidation_screen.dart';
import '../../screens/compliance/depreciation_screen.dart';
import '../../screens/v4_compliance/tax_filing_center_screen.dart';
import '../../screens/v4_compliance/zatca_csid_manager_screen.dart';
import '../../screens/v4_compliance/zatca_error_decoder_screen.dart';
import '../../screens/v4_compliance/compliance_calendar_global_screen.dart';
import '../../screens/v4_erp/business_intelligence_screen.dart';
import '../../screens/v4_erp/customer_success_screen.dart';
import '../../screens/v4_erp/legal_docs_automation_screen.dart';
import '../../screens/v4_erp/procurement_rfq_screen.dart';
import '../../screens/v4_compliance/compliance_status_screen.dart';
import '../../screens/v4_compliance/gosi_wps_screen.dart';
import '../../screens/v4_compliance/governance_screen.dart';
import '../../screens/v4_compliance/workpapers_detail_screen.dart';
import '../../screens/v4_compliance/realtime_tax_screen.dart';
import '../../screens/v4_erp/admin_panel_screen.dart';
import '../../screens/v4_erp/ai_bank_reconciliation_screen.dart';
import '../../screens/v4_erp/ai_financial_analyst_screen.dart';
import '../../screens/v4_erp/advanced_ratios_screen.dart';
import '../../screens/v4_erp/apex_match_screen.dart';
import '../../screens/v4_erp/apex_studio_screen.dart';
import '../../screens/v4_erp/asset_tracking_screen.dart';
import '../../screens/v4_erp/budget_planning_screen.dart';
import '../../screens/v4_erp/construction_screen.dart';
import '../../screens/v4_erp/ecommerce_store_screen.dart';
import '../../screens/v4_erp/education_lms_screen.dart';
import '../../screens/v4_erp/employee_wellness_screen.dart';
import '../../screens/v4_erp/financial_upload_screen.dart';
import '../../screens/v4_erp/ma_deal_room_screen.dart';
import '../../screens/v4_erp/marketplace_client_requests_screen.dart';
import '../../screens/v4_erp/marketplace_provider_jobs_screen.dart';
import '../../screens/v4_erp/marketplace_provider_profile_screen.dart';
import '../../screens/v4_erp/marketplace_provider_ratings_screen.dart';
import '../../screens/v4_erp/proforma_statements_screen.dart';
import '../../screens/v4_erp/valuation_models_screen.dart';
import '../../screens/v4_erp/field_service_screen.dart';
import '../../screens/v4_erp/franchise_management_screen.dart';
import '../../screens/v4_erp/hotel_pms_screen.dart';
import '../../screens/v4_erp/marketing_automation_screen.dart';
import '../../screens/v4_erp/restaurant_pos_screen.dart';
import '../../screens/v4_erp/retail_pos_screen.dart';
import '../../screens/v4_erp/service_pos_screen.dart';
import '../../screens/v4_erp/corporate_cards_screen.dart';
import '../../screens/v4_erp/travel_per_diem_screen.dart';
import '../../screens/v4_erp/bom_mrp_screen.dart';
import '../../screens/v4_erp/shop_floor_screen.dart';
import '../../screens/v4_erp/resource_allocation_screen.dart';
import '../../screens/v4_erp/milestone_billing_screen.dart';
import '../../screens/v4_erp/transport_logistics_screen.dart';
import '../../screens/v4_erp/grant_management_screen.dart';
import '../../screens/v4_erp/subscription_billing_screen.dart';
import '../../screens/v4_erp/healthcare_claims_screen.dart';
import '../../screens/v4_erp/real_estate_screen.dart';
import '../../screens/v4_erp/whatsapp_business_screen.dart';
import '../../screens/v4_compliance/audit_acceptance_screen.dart';
import '../../screens/v4_compliance/audit_kickoff_screen.dart';
import '../../screens/v4_compliance/audit_planning_screen.dart';
import '../../screens/v4_compliance/controls_library_screen.dart';
import '../../screens/v4_compliance/deferred_tax_screen.dart';
import '../../screens/v4_compliance/risk_register_screen.dart';
import '../../screens/v4_compliance/bcp_screen.dart';
import '../../screens/v4_compliance/lease_accounting_screen.dart';
import '../../screens/v4_compliance/quality_management_screen.dart';
import '../../screens/v4_compliance/legal_contract_ai_screen.dart';
import '../../screens/v4_compliance/revenue_recognition_screen.dart';
import '../../screens/v4_compliance/sustainability_report_screen.dart';
import '../../screens/v4_compliance/tax_optimizer_screen.dart';
import '../../screens/v4_compliance/whistleblower_screen.dart';
import '../../screens/v4_compliance/tax_calendar_screen.dart';
import '../../screens/v4_compliance/transfer_pricing_v5_screen.dart';
import '../../screens/v4_compliance/uae_ct_screen.dart';
import '../../screens/v4_compliance/vat_return_builder_screen.dart';
import '../../screens/v4_compliance/wht_calculator_v5_screen.dart';
import '../../screens/v4_compliance/zakat_calculator_v5_screen.dart';
import '../../screens/v4_erp/benefits_eos_screen.dart';
import '../../screens/v4_erp/board_pack_screen.dart';
import '../../screens/v4_erp/budget_vs_actual_screen.dart';
import '../../screens/v4_erp/cap_table_screen.dart';
import '../../screens/v4_erp/credit_notes_screen.dart';
import '../../screens/v4_erp/credit_scoring_screen.dart';
import '../../screens/v4_erp/customer_loyalty_screen.dart';
import '../../screens/v4_erp/fleet_management_screen.dart';
import '../../screens/v4_erp/intercompany_screen.dart';
import '../../screens/v4_erp/price_list_screen.dart';
import '../../screens/v4_erp/warehouse_management_screen.dart';
import '../../screens/v4_erp/warranty_service_screen.dart';
import '../../screens/v4_erp/integrations_hub_screen.dart';
import '../../screens/v4_erp/performance_reviews_screen.dart';
import '../../screens/v4_erp/recruitment_ats_screen.dart';
import '../../screens/v4_erp/subscription_management_screen.dart';
import '../../screens/v4_erp/cost_centers_screen.dart';
import '../../screens/v4_erp/cybersecurity_dashboard_screen.dart';
import '../../screens/v4_erp/investment_portfolio_screen.dart';
import '../../screens/v4_erp/purchase_requisition_screen.dart';
import '../../screens/v4_erp/training_lms_screen.dart';
import '../../screens/v4_erp/expense_claims_screen.dart';
import '../../screens/v4_erp/cash_flow_forecast_screen.dart';
import '../../screens/v4_erp/client_portal_screen.dart';
import '../../screens/v4_erp/connected_planning_screen.dart';
import '../../screens/v4_erp/activity_log_screen.dart';
import '../../screens/v4_erp/ai_copilot_screen.dart';
import '../../screens/v4_erp/anomaly_detector_screen.dart';
import '../../screens/v4_erp/approval_workflows_screen.dart';
import '../../screens/v4_erp/break_even_screen.dart';
import '../../screens/v4_erp/commission_engine_screen.dart';
import '../../screens/v4_erp/esg_dashboard_screen.dart';
import '../../screens/v4_erp/scenario_planning_screen.dart';
import '../../screens/v4_erp/bank_guarantees_screen.dart';
import '../../screens/v4_erp/close_checklist_screen.dart';
import '../../screens/v4_erp/okrs_scorecard_screen.dart';
import '../../screens/v4_erp/project_profitability_screen.dart';
import '../../screens/v4_erp/contract_management_screen.dart';
import '../../screens/v4_erp/crm_screen.dart';
import '../../screens/v4_erp/document_vault_screen.dart';
import '../../screens/v4_erp/employee_self_service_screen.dart';
import '../../screens/v4_erp/executive_dashboard_v5_screen.dart';
import '../../screens/v4_erp/customer_360_screen.dart';
import '../../screens/v4_erp/fixed_assets_register_screen.dart';
import '../../screens/v4_erp/fx_management_screen.dart';
import '../../screens/v4_erp/general_ledger_screen.dart';
import '../../screens/v4_erp/helpdesk_tickets_screen.dart';
import '../../screens/v4_erp/knowledge_base_screen.dart';
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
import '../../screens/v4_erp/vendor_onboarding_screen.dart';

// V5.2 Reference Implementations (using unified templates)
import '../../screens/v5_2/invoices_v52_screen.dart';
import '../../screens/v5_2/je_builder_v52_screen.dart';
import '../../screens/v5_2/onboarding_v52_screen.dart';
import '../../screens/v5_2/customer_360_v52_screen.dart';
import '../../screens/v5_2/supplier_360_v52_screen.dart';
import '../../screens/v5_2/crm_v52_screen.dart';
import '../../screens/v5_2/vat_return_v52_screen.dart';
import '../../screens/v5_2/sales_pipeline_v52_screen.dart';
import '../../screens/v5_2/projects_v52_screen.dart';
import '../../screens/v5_2/audit_planning_v52_screen.dart';
import '../../screens/v5_2/contract_v52_screen.dart';
import '../../screens/v5_2/purchasing_ap_v52_screen.dart';
import '../../screens/v5_2/expense_claims_v52_screen.dart';
import '../../screens/v5_2/risk_register_v52_screen.dart';
import '../../screens/v5_2/ma_deal_room_v52_screen.dart';
import '../../screens/v5_2/ai_analyst_v52_screen.dart';
import '../../screens/v5_2/financial_statements_v52_screen.dart';
import '../../screens/v5_2/fixed_assets_v52_screen.dart';
import '../../screens/v5_2/workpapers_v52_screen.dart';

/// Key format: `{serviceId}/{mainId}/{chipId}`.
/// Returns the Flutter widget to render for that chip.
///
/// When a chip has both a dashboard (isDashboard=true) and a wired
/// screen, the dashboard wins — wired screens are for non-dashboard
/// chips that exist in production today.
typedef V5ChipBuilder = Widget Function(BuildContext ctx);

final Map<String, V5ChipBuilder> v5WiredScreens = {
  // ════════════════════════════════════════════════════════════════════
  // ERP — 16 Apps (V4 Blueprint restructure)
  // ════════════════════════════════════════════════════════════════════

  // ── 1.1 Finance (GL) ─────────────────────────────────────────────
  'erp/finance/gl': (ctx) => const GeneralLedgerScreen(),
  'erp/finance/je-builder': (ctx) => const JeBuilderV52Screen(),  // V5.2 ObjectPage
  'erp/finance/period-close': (ctx) => const CloseChecklistScreen(),
  'erp/finance/close-checklist': (ctx) => const CloseChecklistScreen(),
  'erp/finance/coa-editor': (ctx) => const CoaEditorScreen(),
  'erp/finance/fixed-assets': (ctx) => const FixedAssetsV52Screen(),  // V5.2
  'erp/finance/statements': (ctx) => const FinancialStatementsV52Screen(),  // V5.2
  'erp/finance/budgets': (ctx) => const ConnectedPlanningScreen(),
  'erp/finance/budget-actual': (ctx) => const BudgetVsActualScreen(),
  'erp/finance/budget-planning': (ctx) => const BudgetPlanningScreen(),
  'erp/finance/cost-centers': (ctx) => const CostCentersScreen(),
  'erp/finance/scenarios': (ctx) => const ScenarioPlanningScreen(),
  'erp/finance/breakeven': (ctx) => const BreakEvenScreen(),
  'erp/finance/anomalies': (ctx) => const AnomalyDetectorScreen(),
  'erp/finance/ai-analyst': (ctx) => const AiAnalystV52Screen(),  // V5.2
  'erp/finance/workflows': (ctx) => const ApprovalWorkflowsScreen(),
  'erp/finance/integrations': (ctx) => const IntegrationsHubScreen(),
  'erp/finance/documents': (ctx) => const DocumentVaultScreen(),
  'erp/finance/onboarding': (ctx) => const OnboardingV52Screen(),  // V5.2 Wizard

  // ── 1.2 Consolidation ────────────────────────────────────────────
  'erp/consolidation/consolidation': (ctx) => const ConsolidationScreen(),
  'erp/consolidation/intercompany': (ctx) => const IntercompanyScreen(),
  'erp/consolidation/cap-table': (ctx) => const CapTableScreen(),
  'erp/consolidation/board': (ctx) => const BoardPackScreen(),
  'erp/consolidation/ma-deal-room': (ctx) => const MaDealRoomV52Screen(),  // V5.2 ObjectPage

  // ── 1.3 Treasury & Banking ───────────────────────────────────────
  'erp/treasury/recon': (ctx) => const AiBankReconciliationScreen(),
  'erp/treasury/cashflow': (ctx) => const CashFlowForecastScreen(),
  'erp/treasury/fx': (ctx) => const FxManagementScreen(),
  'erp/treasury/guarantees': (ctx) => const BankGuaranteesScreen(),
  'erp/treasury/investments': (ctx) => const InvestmentPortfolioScreen(),

  // ── 1.4 Sales & AR ───────────────────────────────────────────────
  'erp/sales/sales-workflow': (ctx) => const SalesWorkflowScreen(),
  'erp/sales/invoices': (ctx) => const InvoicesV52Screen(),  // V5.2 MultiView
  'erp/sales/credit-notes': (ctx) => const CreditNotesScreen(),
  'erp/sales/price-list': (ctx) => const PriceListScreen(),
  'erp/sales/contracts': (ctx) => const ContractV52Screen(),  // V5.2 ObjectPage
  'erp/sales/subscription-billing': (ctx) => const SubscriptionBillingScreen(),
  'erp/sales/credit': (ctx) => const CreditScoringScreen(),

  // ── 1.5 Purchasing & AP ──────────────────────────────────────────
  'erp/purchasing/ap': (ctx) => const PurchasingApV52Screen(),  // V5.2
  'erp/purchasing/suppliers': (ctx) => const Supplier360V52Screen(),  // V5.2 ObjectPage
  'erp/purchasing/vendor-onboarding': (ctx) => const VendorOnboardingScreen(),
  'erp/purchasing/requisitions': (ctx) => const PurchaseRequisitionScreen(),
  'erp/purchasing/procurement-rfq': (ctx) => const ProcurementRfqScreen(),

  // ── 1.6 Expenses & Reimbursements ────────────────────────────────
  'erp/expenses/expenses': (ctx) => const ExpenseClaimsV52Screen(),  // V5.2
  'erp/expenses/mobile-receipt': (ctx) => const MobileReceiptScreen(),
  'erp/expenses/corporate-cards': (ctx) => const CorporateCardsScreen(),
  'erp/expenses/travel': (ctx) => const TravelPerDiemScreen(),

  // ── 1.7 POS ──────────────────────────────────────────────────────
  'erp/pos/restaurant-pos': (ctx) => const RestaurantPosScreen(),
  'erp/pos/retail-pos': (ctx) => const RetailPosScreen(),
  'erp/pos/service-pos': (ctx) => const ServicePosScreen(),

  // ── 1.8 Inventory & Cost ─────────────────────────────────────────
  'erp/inventory/inventory': (ctx) => const InventoryDetailedScreen(),
  'erp/inventory/warehouse': (ctx) => const WarehouseManagementScreen(),
  'erp/inventory/asset-tracking': (ctx) => const AssetTrackingScreen(),
  'erp/inventory/fleet': (ctx) => const FleetManagementScreen(),
  'erp/inventory/warranty': (ctx) => const WarrantyServiceScreen(),

  // ── 1.9 HR & Payroll ─────────────────────────────────────────────
  'erp/hr/employees': (ctx) => const HrEmployeesScreen(),
  'erp/hr/payroll': (ctx) => const PayrollRunScreen(),
  'erp/hr/leaves': (ctx) => const LeaveManagementScreen(),
  'erp/hr/benefits': (ctx) => const BenefitsEosScreen(),
  'erp/hr/commissions': (ctx) => const CommissionEngineScreen(),
  'erp/hr/self-service': (ctx) => const EmployeeSelfServiceScreen(),
  'erp/hr/training': (ctx) => const TrainingLmsScreen(),
  'erp/hr/performance': (ctx) => const PerformanceReviewsScreen(),
  'erp/hr/recruitment': (ctx) => const RecruitmentAtsScreen(),
  'erp/hr/wellness': (ctx) => const EmployeeWellnessScreen(),

  // ── 1.10 Projects & Jobs ─────────────────────────────────────────
  'erp/projects/projects': (ctx) => const ProjectsV52Screen(),  // V5.2
  'erp/projects/project-pnl': (ctx) => const ProjectProfitabilityScreen(),
  'erp/projects/tickets': (ctx) => const HelpdeskTicketsScreen(),
  'erp/projects/resource-allocation': (ctx) => const ResourceAllocationScreen(),
  'erp/projects/milestone-billing': (ctx) => const MilestoneBillingScreen(),

  // ── 1.11 CRM & Marketing ─────────────────────────────────────────
  'erp/crm-marketing/crm': (ctx) => const CrmV52Screen(),  // V5.2 MultiView
  'erp/crm-marketing/customers-360': (ctx) => const Customer360V52Screen(),  // V5.2 ObjectPage
  'erp/crm-marketing/pipeline': (ctx) => const SalesPipelineV52Screen(),  // V5.2
  'erp/crm-marketing/marketing': (ctx) => const MarketingAutomationScreen(),
  'erp/crm-marketing/loyalty': (ctx) => const CustomerLoyaltyScreen(),
  'erp/crm-marketing/whatsapp': (ctx) => const WhatsappBusinessScreen(),
  'erp/crm-marketing/customer-success': (ctx) => const CustomerSuccessScreen(),

  // ── 1.12 Manufacturing ───────────────────────────────────────────
  'erp/manufacturing/manufacturing': (ctx) => const ManufacturingScreen(),
  'erp/manufacturing/bom-mrp': (ctx) => const BomMrpScreen(),
  'erp/manufacturing/shop-floor': (ctx) => const ShopFloorScreen(),

  // ── 1.13 Hotel PMS ───────────────────────────────────────────────
  'erp/hotel-pms/hotel-pms': (ctx) => const HotelPmsScreen(),

  // ── 1.14 Construction ────────────────────────────────────────────
  'erp/construction/construction': (ctx) => const ConstructionScreen(),

  // ── 1.15 Industry Packs ──────────────────────────────────────────
  'erp/industry-packs/real-estate': (ctx) => const RealEstateScreen(),
  'erp/industry-packs/healthcare': (ctx) => const HealthcareClaimsScreen(),
  'erp/industry-packs/education': (ctx) => const EducationLmsScreen(),
  'erp/industry-packs/transport': (ctx) => const TransportLogisticsScreen(),
  'erp/industry-packs/grants': (ctx) => const GrantManagementScreen(),
  'erp/industry-packs/franchise': (ctx) => const FranchiseManagementScreen(),
  'erp/industry-packs/ecommerce': (ctx) => const EcommerceStoreScreen(),
  'erp/industry-packs/field-service': (ctx) => const FieldServiceScreen(),

  // ── 1.16 Reports & BI ────────────────────────────────────────────
  'erp/reports-bi/reports': (ctx) => const AuditReportingScreen(),
  'erp/reports-bi/custom-reports': (ctx) => const ReportBuilderScreen(),
  'erp/reports-bi/exec': (ctx) => const ExecutiveDashboardV5Screen(),
  'erp/reports-bi/okrs': (ctx) => const OkrsScorecardScreen(),
  'erp/reports-bi/knowledge': (ctx) => const KnowledgeBaseScreen(),
  'erp/reports-bi/esg': (ctx) => const EsgDashboardScreen(),
  'erp/reports-bi/bi': (ctx) => const BusinessIntelligenceScreen(),
  'erp/reports-bi/legal-docs': (ctx) => const LegalDocsAutomationScreen(),

  // ════════════════════════════════════════════════════════════════════
  // Advisory — 8 apps
  // ════════════════════════════════════════════════════════════════════

  // 4.1 Feasibility
  'advisory/feasibility/market': (ctx) => const FeasibilityMarketScreen(),
  'advisory/feasibility/sensitivity': (ctx) => const FeasibilityMarketScreen(),
  'advisory/feasibility/proforma': (ctx) => const ProformaStatementsScreen(),
  'advisory/feasibility/scenario': (ctx) => const FeasibilityMarketScreen(),

  // 4.2 Valuation
  'advisory/valuation/valuation': (ctx) => const ValuationModelsScreen(),
  'advisory/valuation/dcf': (ctx) => const ValuationModelsScreen(),
  'advisory/valuation/multiples': (ctx) => const ValuationModelsScreen(),
  'advisory/valuation/lbo': (ctx) => const ValuationModelsScreen(),

  // 4.3 Upload & OCR
  'advisory/upload/upload': (ctx) => const FinancialUploadScreen(),
  'advisory/upload/parse-tb': (ctx) => const FinancialUploadScreen(),
  'advisory/upload/classify': (ctx) => const FinancialUploadScreen(),

  // 4.4 CoA Analyzer (AI)
  'advisory/coa/coa-analyzer': (ctx) => const CoaEditorScreen(),
  'advisory/coa/coa-mapping': (ctx) => const CoaEditorScreen(),
  'advisory/coa/coa-cleanup': (ctx) => const CoaEditorScreen(),

  // 4.5 Ratios & Benchmarking
  'advisory/ratios/ratios': (ctx) => const AdvancedRatiosScreen(),
  'advisory/ratios/benchmarking': (ctx) => const ExternalAnalysisScreen(),
  'advisory/ratios/industry': (ctx) => const ExternalAnalysisScreen(),

  // 4.6 Credit
  'advisory/credit/credit': (ctx) => const ExternalAnalysisScreen(),
  'advisory/credit/altman-z': (ctx) => const AdvancedRatiosScreen(),
  'advisory/credit/pd': (ctx) => const AdvancedRatiosScreen(),

  // 4.7 IFRS Tools
  'advisory/ifrs-tools/fixed_assets': (ctx) => const FixedAssetsRegisterScreen(),
  'advisory/ifrs-tools/depreciation': (ctx) => const DepreciationScreen(),
  'advisory/ifrs-tools/lease': (ctx) => const LeaseAccountingScreen(),

  // 4.8 Calculators
  'advisory/calculators/breakeven': (ctx) => const BreakEvenScreen(),
  'advisory/calculators/npv-irr': (ctx) => const BreakEvenScreen(),
  'advisory/calculators/dscr': (ctx) => const BreakEvenScreen(),
  'advisory/calculators/wacc': (ctx) => const BreakEvenScreen(),

  // Backward-compat for old advisory routes
  'advisory/feasibility/valuation': (ctx) => const ValuationModelsScreen(),
  'advisory/external/upload': (ctx) => const FinancialUploadScreen(),
  'advisory/external/coa-analyzer': (ctx) => const CoaEditorScreen(),
  'advisory/external/benchmarking': (ctx) => const ExternalAnalysisScreen(),
  'advisory/external/credit': (ctx) => const ExternalAnalysisScreen(),
  'advisory/external/ratios': (ctx) => const AdvancedRatiosScreen(),
  'advisory/tools/fixed_assets': (ctx) => const FixedAssetsRegisterScreen(),
  'advisory/tools/depreciation': (ctx) => const DepreciationScreen(),
  'advisory/tools/lease': (ctx) => const LeaseAccountingScreen(),
  'advisory/tools/breakeven': (ctx) => const BreakEvenScreen(),

  // ════════════════════════════════════════════════════════════════════
  // Marketplace — 6 apps
  // ════════════════════════════════════════════════════════════════════

  // 5.1 Browse & Discover
  'marketplace/browse/browse': (ctx) => const ApexMatchScreen(),
  'marketplace/browse/apex-match': (ctx) => const ApexMatchScreen(),
  'marketplace/browse/compare': (ctx) => const ApexMatchScreen(),

  // 5.2 Client Requests
  'marketplace/client/requests': (ctx) => const MarketplaceClientRequestsScreen(),
  'marketplace/client/proposals': (ctx) => const MarketplaceClientRequestsScreen(),
  'marketplace/client/active-projects': (ctx) => const MarketplaceClientRequestsScreen(),

  // 5.3 Billing & Escrow
  'marketplace/billing/billing': (ctx) => const MarketplaceBillingScreen(),
  'marketplace/billing/subscriptions': (ctx) => const SubscriptionManagementScreen(),
  'marketplace/billing/disputes': (ctx) => const MarketplaceBillingScreen(),

  // 5.4 Provider Profile
  'marketplace/provider/profile': (ctx) => const MarketplaceProviderProfileScreen(),
  'marketplace/provider/certifications': (ctx) => const MarketplaceProviderProfileScreen(),
  'marketplace/provider/portfolio': (ctx) => const MarketplaceProviderProfileScreen(),

  // 5.5 Provider Operations
  'marketplace/provider-ops/jobs': (ctx) => const MarketplaceProviderJobsScreen(),
  'marketplace/provider-ops/payouts': (ctx) => const MarketplaceBillingScreen(),
  'marketplace/provider-ops/tax-1099': (ctx) => const MarketplaceBillingScreen(),

  // 5.6 Ratings & Reviews
  'marketplace/reviews/ratings': (ctx) => const MarketplaceProviderRatingsScreen(),
  'marketplace/reviews/reviews-received': (ctx) => const MarketplaceProviderRatingsScreen(),
  'marketplace/reviews/reputation': (ctx) => const MarketplaceProviderRatingsScreen(),

  // Backward-compat
  'marketplace/client/browse': (ctx) => const ApexMatchScreen(),
  'marketplace/client/billing': (ctx) => const MarketplaceBillingScreen(),
  'marketplace/client/industry-packs': (ctx) => const IndustryPacksScreen(),
  'marketplace/provider/jobs': (ctx) => const MarketplaceProviderJobsScreen(),
  'marketplace/provider/payouts': (ctx) => const MarketplaceBillingScreen(),
  'marketplace/provider/ratings': (ctx) => const MarketplaceProviderRatingsScreen(),

  // ════════════════════════════════════════════════════════════════════
  // Compliance & Tax — 7 apps
  // ════════════════════════════════════════════════════════════════════

  // 2.1 Tax Filings
  'compliance/tax/vat': (ctx) => const RealtimeTaxScreen(),
  'compliance/tax/vat-return': (ctx) => const VatReturnV52Screen(),  // V5.2 Wizard
  'compliance/tax/wht': (ctx) => const WhtCalculatorV5Screen(),
  'compliance/tax/zakat': (ctx) => const ZakatCalculatorV5Screen(),
  'compliance/tax/uae_ct': (ctx) => const UaeCtScreen(),
  'compliance/tax/tp': (ctx) => const TransferPricingV5Screen(),
  'compliance/tax/calendar': (ctx) => const TaxCalendarScreen(),
  'compliance/tax/optimizer': (ctx) => const TaxOptimizerScreen(),
  'compliance/tax/filings': (ctx) => const TaxFilingCenterScreen(),
  'compliance/tax/realtime': (ctx) => const RealtimeTaxScreen(),

  // 2.2 ZATCA
  'compliance/zatca/csid': (ctx) => const ZatcaCsidManagerScreen(),
  'compliance/zatca/errors': (ctx) => const ZatcaErrorDecoderScreen(),

  // 2.3 IFRS Standards (NEW app)
  'compliance/ifrs/revenue-recognition': (ctx) => const RevenueRecognitionScreen(),
  'compliance/ifrs/leases': (ctx) => const LeaseAccountingScreen(),
  'compliance/ifrs/deferred': (ctx) => const DeferredTaxScreen(),

  // 2.4 Labor Compliance (GOSI/WPS/Saudization)
  'compliance/labor/gosi': (ctx) => const GosiWpsScreen(),
  'compliance/labor/wps': (ctx) => const GosiWpsScreen(),
  'compliance/labor/saudization': (ctx) => const GosiWpsScreen(),

  // 2.5 AML & Ethics
  'compliance/aml-ethics/aml': (ctx) => const AmlKycScreen(),
  'compliance/aml-ethics/whistleblower': (ctx) => const WhistleblowerScreen(),
  'compliance/aml-ethics/activity-log': (ctx) => const ActivityLogScreen(),
  'compliance/aml-ethics/sanctions': (ctx) => const AmlKycScreen(),

  // 2.6 Governance & Risk
  'compliance/governance-risk/governance': (ctx) => const GovernanceScreen(),
  'compliance/governance-risk/risk-register': (ctx) => const RiskRegisterV52Screen(),  // V5.2
  'compliance/governance-risk/quality': (ctx) => const QualityManagementScreen(),
  'compliance/governance-risk/sustainability': (ctx) => const SustainabilityReportScreen(),

  // 2.7 Legal, Security & BCP
  'compliance/legal-security/legal-ai': (ctx) => const LegalContractAiScreen(),
  'compliance/legal-security/legal-docs-automation': (ctx) => const LegalDocsAutomationScreen(),
  'compliance/legal-security/compliance-calendar': (ctx) => const ComplianceCalendarGlobalScreen(),
  'compliance/legal-security/cybersecurity': (ctx) => const CybersecurityDashboardScreen(),
  'compliance/legal-security/bcp': (ctx) => const BcpScreen(),

  // Backward-compat (old compliance/regulatory/* and compliance/tax/leases|deferred)
  'compliance/tax/leases': (ctx) => const LeaseAccountingScreen(),
  'compliance/tax/deferred': (ctx) => const DeferredTaxScreen(),
  'compliance/tax/revenue-recognition': (ctx) => const RevenueRecognitionScreen(),
  'compliance/regulatory/gosi': (ctx) => const GosiWpsScreen(),
  'compliance/regulatory/wps': (ctx) => const GosiWpsScreen(),
  'compliance/regulatory/aml': (ctx) => const AmlKycScreen(),
  'compliance/regulatory/governance': (ctx) => const GovernanceScreen(),
  'compliance/regulatory/activity-log': (ctx) => const ActivityLogScreen(),
  'compliance/regulatory/cybersecurity': (ctx) => const CybersecurityDashboardScreen(),
  'compliance/regulatory/risk-register': (ctx) => const RiskRegisterScreen(),
  'compliance/regulatory/whistleblower': (ctx) => const WhistleblowerScreen(),
  'compliance/regulatory/bcp': (ctx) => const BcpScreen(),
  'compliance/regulatory/quality': (ctx) => const QualityManagementScreen(),
  'compliance/regulatory/sustainability': (ctx) => const SustainabilityReportScreen(),
  'compliance/regulatory/legal-ai': (ctx) => const LegalContractAiScreen(),
  'compliance/regulatory/compliance-calendar': (ctx) => const ComplianceCalendarGlobalScreen(),
  'compliance/regulatory/legal-docs-automation': (ctx) => const LegalDocsAutomationScreen(),
  'compliance/regulatory/eligibility': (ctx) => const EligibilityCheckScreen(),

  // ════════════════════════════════════════════════════════════════════
  // Audit — 7 apps
  // ════════════════════════════════════════════════════════════════════

  // 3.1 Engagement
  'audit/engagement/acceptance': (ctx) => const AuditAcceptanceScreen(),
  'audit/engagement/planning': (ctx) => const AuditPlanningV52Screen(),  // V5.2 Wizard
  'audit/engagement/kickoff': (ctx) => const AuditKickoffScreen(),
  'audit/engagement/materiality': (ctx) => const AuditPlanningScreen(),

  // 3.2 Risk Assessment (NEW)
  'audit/risk/risk': (ctx) => const ComplianceStatusScreen(),
  'audit/risk/fraud-risk': (ctx) => const ComplianceStatusScreen(),
  'audit/risk/going-concern': (ctx) => const ComplianceStatusScreen(),

  // 3.3 Workpapers
  'audit/workpapers/workpapers': (ctx) => const WorkpapersV52Screen(),  // V5.2
  'audit/workpapers/trial-balance-tie': (ctx) => const WorkpapersDetailScreen(),
  'audit/workpapers/evidence': (ctx) => const WorkpapersDetailScreen(),

  // 3.4 Controls Testing
  'audit/controls/controls-library': (ctx) => const ControlsLibraryScreen(),
  'audit/controls/control': (ctx) => const AuditAnalyticsScreen(),
  'audit/controls/walkthroughs': (ctx) => const ControlsLibraryScreen(),

  // 3.5 Analytics (NEW)
  'audit/analytics/full-population': (ctx) => const AuditAnalyticsScreen(),
  'audit/analytics/ai-anomalies': (ctx) => const AuditAnalyticsScreen(),
  'audit/analytics/journal-entry-testing': (ctx) => const AuditAnalyticsScreen(),

  // 3.6 Opinion & Reporting
  'audit/reporting/opinion': (ctx) => const AuditReportingScreen(),
  'audit/reporting/ml': (ctx) => const AuditReportingScreen(),
  'audit/reporting/final-report': (ctx) => const AuditReportingScreen(),

  // 3.7 Quality (NEW)
  'audit/quality/qc': (ctx) => const AuditReportingScreen(),
  'audit/quality/eqcr': (ctx) => const AuditReportingScreen(),
  'audit/quality/isqm1': (ctx) => const AuditReportingScreen(),

  // Backward-compat
  'audit/fieldwork/workpapers': (ctx) => const WorkpapersDetailScreen(),
  'audit/fieldwork/controls-library': (ctx) => const ControlsLibraryScreen(),
  'audit/fieldwork/risk': (ctx) => const ComplianceStatusScreen(),
  'audit/fieldwork/control': (ctx) => const AuditAnalyticsScreen(),
  'audit/reporting/qc': (ctx) => const AuditReportingScreen(),

  // ════════════════════════════════════════════════════════════════════
  // Platform (horizontal layer) — rendered in shell, not as chips
  // ════════════════════════════════════════════════════════════════════

  'platform/notifications/center': (ctx) => const NotificationsCenterScreen(),
  'platform/help/center': (ctx) => const HelpCenterScreen(),
  'platform/ai/agents': (ctx) => const AiAgentsGalleryScreen(),
  'platform/ai/copilot': (ctx) => const AiCopilotScreen(),
  'platform/search/results': (ctx) => const GlobalSearchScreen(),
  'platform/admin/settings': (ctx) => const AdminPanelScreen(),
  'platform/portal/client': (ctx) => const ClientPortalScreen(),
  'platform/studio/builder': (ctx) => const ApexStudioScreen(),

  // ════════════════════════════════════════════════════════════════════
  // Backward-compat aliases (old V4 routes → new V5.1 routes)
  // These preserve deep-linked bookmarks during the transition.
  // ════════════════════════════════════════════════════════════════════

  // finance → sales/purchasing/consolidation/expenses/reports-bi
  'erp/finance/ap': (ctx) => const PurchasingApScreen(),
  'erp/finance/sales-workflow': (ctx) => const SalesWorkflowScreen(),
  'erp/finance/invoices': (ctx) => const InvoicesV52Screen(),  // V5.2 alias
  'erp/finance/credit-notes': (ctx) => const CreditNotesScreen(),
  'erp/finance/subscription-billing': (ctx) => const SubscriptionBillingScreen(),
  'erp/finance/credit': (ctx) => const CreditScoringScreen(),
  'erp/finance/consolidation': (ctx) => const ConsolidationScreen(),
  'erp/finance/intercompany': (ctx) => const IntercompanyScreen(),
  'erp/finance/cap-table': (ctx) => const CapTableScreen(),
  'erp/finance/board': (ctx) => const BoardPackScreen(),
  'erp/finance/ma-deal-room': (ctx) => const MaDealRoomScreen(),
  'erp/finance/expenses': (ctx) => const ExpenseClaimsScreen(),
  'erp/finance/reports': (ctx) => const AuditReportingScreen(),
  'erp/finance/custom-reports': (ctx) => const ReportBuilderScreen(),
  'erp/finance/exec': (ctx) => const ExecutiveDashboardV5Screen(),
  'erp/finance/okrs': (ctx) => const OkrsScorecardScreen(),
  'erp/finance/knowledge': (ctx) => const KnowledgeBaseScreen(),
  'erp/finance/esg': (ctx) => const EsgDashboardScreen(),
  'erp/finance/bi': (ctx) => const BusinessIntelligenceScreen(),
  'erp/finance/legal-docs': (ctx) => const LegalDocsAutomationScreen(),
  'erp/finance/copilot': (ctx) => const AiCopilotScreen(),

  // operations → inventory/projects/crm-marketing/manufacturing/pos/hotel/construction/industry-packs/purchasing/sales
  'erp/operations/inventory': (ctx) => const InventoryDetailedScreen(),
  'erp/operations/warehouse': (ctx) => const WarehouseManagementScreen(),
  'erp/operations/asset-tracking': (ctx) => const AssetTrackingScreen(),
  'erp/operations/fleet': (ctx) => const FleetManagementScreen(),
  'erp/operations/warranty': (ctx) => const WarrantyServiceScreen(),
  'erp/operations/projects': (ctx) => const ProjectsScreen(),
  'erp/operations/project-pnl': (ctx) => const ProjectProfitabilityScreen(),
  'erp/operations/tickets': (ctx) => const HelpdeskTicketsScreen(),
  'erp/operations/crm': (ctx) => const CrmScreen(),
  'erp/operations/customers-360': (ctx) => const Customer360Screen(),
  'erp/operations/pipeline': (ctx) => const SalesPipelineScreen(),
  'erp/operations/loyalty': (ctx) => const CustomerLoyaltyScreen(),
  'erp/operations/whatsapp': (ctx) => const WhatsappBusinessScreen(),
  'erp/operations/marketing': (ctx) => const MarketingAutomationScreen(),
  'erp/operations/customer-success': (ctx) => const CustomerSuccessScreen(),
  'erp/operations/suppliers': (ctx) => const Supplier360Screen(),
  'erp/operations/vendor-onboarding': (ctx) => const VendorOnboardingScreen(),
  'erp/operations/requisitions': (ctx) => const PurchaseRequisitionScreen(),
  'erp/operations/procurement-rfq': (ctx) => const ProcurementRfqScreen(),
  'erp/operations/price-list': (ctx) => const PriceListScreen(),
  'erp/operations/contracts': (ctx) => const ContractManagementScreen(),
  'erp/operations/manufacturing': (ctx) => const ManufacturingScreen(),
  'erp/operations/restaurant-pos': (ctx) => const RestaurantPosScreen(),
  'erp/operations/hotel-pms': (ctx) => const HotelPmsScreen(),
  'erp/operations/construction': (ctx) => const ConstructionScreen(),
  'erp/operations/real-estate': (ctx) => const RealEstateScreen(),
  'erp/operations/healthcare': (ctx) => const HealthcareClaimsScreen(),
  'erp/operations/education': (ctx) => const EducationLmsScreen(),
  'erp/operations/transport': (ctx) => const TransportLogisticsScreen(),
  'erp/operations/grants': (ctx) => const GrantManagementScreen(),
  'erp/operations/franchise': (ctx) => const FranchiseManagementScreen(),
  'erp/operations/ecommerce': (ctx) => const EcommerceStoreScreen(),
  'erp/operations/field-service': (ctx) => const FieldServiceScreen(),
  'erp/operations/mobile-receipt': (ctx) => const MobileReceiptScreen(),

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
