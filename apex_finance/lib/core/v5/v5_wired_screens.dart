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
import '../../screens/v4_compliance/compliance_status_screen.dart';
import '../../screens/v4_compliance/realtime_tax_screen.dart';
import '../../screens/v4_compliance/zatca_csid_screen.dart';
import '../../screens/v4_compliance/zatca_queue_screen.dart';
import '../../screens/v4_erp/ai_bank_reconciliation_screen.dart';
import '../../screens/v4_erp/bank_feeds_screen.dart';
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
  // Wave 16 — AI Bank Reconciliation (V5.1 POC)
  'erp/treasury/recon': (ctx) => const AiBankReconciliationScreen(),

  // ── Compliance & Tax ─────────────────────────────────────────────
  'compliance/zatca/csid': (ctx) => const ZatcaCsidScreen(),
  'compliance/zatca/zatca-queue': (ctx) => const ZatcaQueueScreen(),
  'compliance/zatca/queue': (ctx) => const ZatcaQueueScreen(),
  // Real-time GCC Tax Calculator — World-first feature
  'compliance/tax/vat': (ctx) => const RealtimeTaxScreen(),
  'compliance/tax/realtime': (ctx) => const RealtimeTaxScreen(),

  // ── Audit ────────────────────────────────────────────────────────
  'audit/fieldwork/risk': (ctx) => const ComplianceStatusScreen(),

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
