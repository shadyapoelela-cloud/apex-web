/// APEX V5.1 — Data models (Level -1 Workspaces → Level 4 More).
///
/// V5 extends V4's architecture with two new levels:
///   Level -1: Workspace (role-based bundle — CFO/Auditor/Accountant...)
///   Level 0:  Service (5 apps — ERP/Compliance/Audit/Advisory/Marketplace)
///   Level 1:  Main Module (4-5 per service — Finance/HR/Ops/Treasury within ERP)
///   Level 2:  Chip (Dashboard first + specialized — [لوحة] | GL | AR | AP)
///   Level 3:  Tab (5 visible per chip)
///   Level 4:  More ▾ (overflow items)
///
/// Backward compatibility: V5Chip wraps V4SubModule — all existing
/// V4Screen / V4SubModule data is reusable under V5.
///
/// See blueprints/APEX_V5_HIERARCHY.md for the full narrative.
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;

import '../v4/v4_groups.dart';

/// Level 0: Service (5 apps in V5.1).
@immutable
class V5Service {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final Color color;
  final String descriptionAr;
  final List<V5MainModule> mainModules;
  final String? requiredCapability;

  const V5Service({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.color,
    required this.descriptionAr,
    required this.mainModules,
    this.requiredCapability,
  });

  V5MainModule? mainModuleById(String id) {
    for (final m in mainModules) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Level 1: Main Module (Finance, HR, Operations, Treasury within ERP).
@immutable
class V5MainModule {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final String descriptionAr;

  /// Chips inside this module. First chip MUST be a dashboard (by
  /// convention — enforced at render time).
  final List<V5Chip> chips;

  /// Optional app group for sidebar coloring/headers (ERP 16 apps → 5 groups).
  final AppGroup? group;

  const V5MainModule({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.descriptionAr,
    required this.chips,
    this.group,
  });

  V5Chip? chipById(String id) {
    for (final c in chips) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The first chip is conventionally the dashboard.
  V5Chip get dashboardChip => chips.first;
}

/// Level 2: Chip (a tab-group within a main module).
///
/// V5Chip is a thin wrapper around V4SubModule — we reuse all visible
/// tabs + overflow logic. `isDashboard=true` gets special rendering
/// (live widgets instead of a tab row).
@immutable
class V5Chip {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final bool isDashboard;

  /// When isDashboard=false, this holds the V4SubModule with tabs.
  /// When isDashboard=true, this is null and dashboardWidgets is used.
  final V4SubModule? subModule;

  /// Dashboard widgets — rendered when isDashboard=true. Each widget
  /// is an action-oriented card (enhancement #3 from V5.1).
  final List<V5DashboardWidget>? dashboardWidgets;

  /// RBAC capability. Format: `{service}.{mainModule}.{chip}.view`.
  final String? requiredCapability;

  /// 4-phase journey tag (Setup/Capture/Process/Report).
  /// When set, chips are grouped by phase in the chip row with
  /// visual dividers and phase headers.
  final ChipPhase? phase;

  /// Setup sub-grouping (only meaningful when phase == Setup).
  /// Maps to the 7-phase accountant onboarding journey used by SAP /
  /// Oracle / NetSuite / D365. Values:
  ///   foundation   — Entity, fiscal calendar, currencies, tax registration
  ///   backbone     — Chart of Accounts, sub-ledgers, bank accounts, tax codes
  ///   dimensions   — Cost centers, profit centers, internal orders, segments
  ///   documents    — Document types, numbering, templates, approval workflow
  ///   operations   — Auto-posting, recurring, period-close, FX revaluation
  ///   integrations — Bank feeds, ZATCA, payment gateways, APIs, import/export
  ///   golive       — Opening balances, pre-go-live checklist, onboarding
  final String? setupGroup;

  const V5Chip({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    this.isDashboard = false,
    this.subModule,
    this.dashboardWidgets,
    this.requiredCapability,
    this.phase,
    this.setupGroup,
  });

  /// Convenience: build from existing V4SubModule.
  factory V5Chip.fromSubModule(V4SubModule sub) => V5Chip(
        id: sub.id,
        labelAr: sub.labelAr,
        labelEn: sub.labelEn,
        icon: sub.icon,
        subModule: sub,
      );
}

/// Level -1: Workspace — role-based bundle of shortcuts.
///
/// Each workspace points to 4-8 shortcut targets across services.
/// The user sees these in their personal landing page.
@immutable
class V5Workspace {
  final String id;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final Color color;
  final String descriptionAr;

  /// Shortcuts across services. Each shortcut = {service_id}/{main_id}/{chip_id}.
  final List<V5Shortcut> shortcuts;

  const V5Workspace({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.color,
    required this.descriptionAr,
    required this.shortcuts,
  });
}

@immutable
class V5Shortcut {
  final String serviceId;
  final String mainId;
  final String chipId;
  final String labelAr;
  final IconData icon;

  const V5Shortcut({
    required this.serviceId,
    required this.mainId,
    required this.chipId,
    required this.labelAr,
    required this.icon,
  });

  String get route => '/app/$serviceId/$mainId/$chipId';
}

/// Action-oriented dashboard widget (enhancement #3).
///
/// Each widget has a label + value + action. Clicking the action
/// navigates to the relevant chip with filters pre-applied.
@immutable
class V5DashboardWidget {
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final V5WidgetKind kind;

  /// Optional: where to navigate when the widget is clicked.
  final String? actionRoute;

  /// Optional action label (e.g., "أرسل تذكير" for overdue invoices).
  final String? actionLabelAr;

  /// Live data source — backend endpoint to fetch the value.
  /// POC uses mock data; production binds to ApiService.
  final String? dataEndpoint;

  /// Severity for color-coding (info/warning/critical/success).
  final V5WidgetSeverity severity;

  const V5DashboardWidget({
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.kind,
    this.actionRoute,
    this.actionLabelAr,
    this.dataEndpoint,
    this.severity = V5WidgetSeverity.info,
  });
}

enum V5WidgetKind {
  /// Single KPI value (e.g., DSO: 42 days).
  kpi,

  /// Actionable list (e.g., "5 overdue invoices [send reminder]").
  actionList,

  /// Small chart (line/bar).
  chart,

  /// Alert banner.
  alert,
}

enum V5WidgetSeverity { info, success, warning, critical }

/// The 4-phase journey pattern for chips within an app.
///
/// Every app tells a story across 4 phases:
///   [setup] → [capture] → [process] → [report]
///
/// Chips are visually grouped by phase in the chip row, making it
/// obvious what the user should do first and where the workflow ends.
enum ChipPhase {
  /// Setup & configuration (CoA, periods, employees, currencies).
  setup,

  /// Daily data entry (journals, invoices, claims, orders).
  capture,

  /// Processing, approvals, reconciliation, close.
  process,

  /// Final output — statements, dashboards, regulatory reports.
  report,
}

/// App group for sidebar organization (16 ERP apps → 5 colored groups).
enum AppGroup {
  core,            // 🟡 النواة المحاسبية (Finance/Consolidation/Treasury)
  businessCycles,  // 🔵 دورات الأعمال (Sales/Purchasing/Expenses/POS)
  operations,      // 🟢 العمليات والإنتاج (Inventory/Mfg/Construction/Hotel/IndustryPacks)
  resources,       // 🟣 إدارة الموارد (HR/Projects/CRM)
  output,          // 🟠 المخرجات (Reports & BI)
}

extension AppGroupX on AppGroup {
  String get labelAr {
    switch (this) {
      case AppGroup.core:
        return 'النواة المحاسبية';
      case AppGroup.businessCycles:
        return 'دورات الأعمال';
      case AppGroup.operations:
        return 'العمليات والإنتاج';
      case AppGroup.resources:
        return 'إدارة الموارد';
      case AppGroup.output:
        return 'المخرجات';
    }
  }

  String get labelEn {
    switch (this) {
      case AppGroup.core:
        return 'Core';
      case AppGroup.businessCycles:
        return 'Business Cycles';
      case AppGroup.operations:
        return 'Operations';
      case AppGroup.resources:
        return 'Resources';
      case AppGroup.output:
        return 'Output';
    }
  }

  Color get color {
    switch (this) {
      case AppGroup.core:
        return core_theme.AC.gold; // Gold
      case AppGroup.businessCycles:
        return const Color(0xFF1565C0); // Blue
      case AppGroup.operations:
        return const Color(0xFF2E7D5B); // Green
      case AppGroup.resources:
        return const Color(0xFF4A148C); // Purple
      case AppGroup.output:
        return const Color(0xFFE65100); // Orange
    }
  }

  IconData get icon {
    switch (this) {
      case AppGroup.core:
        return Icons.account_balance;
      case AppGroup.businessCycles:
        return Icons.sync;
      case AppGroup.operations:
        return Icons.factory;
      case AppGroup.resources:
        return Icons.groups;
      case AppGroup.output:
        return Icons.assessment;
    }
  }
}

extension ChipPhaseX on ChipPhase {
  String get labelAr {
    switch (this) {
      case ChipPhase.setup:
        return 'الإعداد';
      case ChipPhase.capture:
        return 'الإدخال';
      case ChipPhase.process:
        return 'المعالجة';
      case ChipPhase.report:
        return 'التقارير';
    }
  }

  String get labelEn {
    switch (this) {
      case ChipPhase.setup:
        return 'Setup';
      case ChipPhase.capture:
        return 'Capture';
      case ChipPhase.process:
        return 'Process';
      case ChipPhase.report:
        return 'Report';
    }
  }

  IconData get icon {
    switch (this) {
      case ChipPhase.setup:
        return Icons.tune;
      case ChipPhase.capture:
        return Icons.edit_note;
      case ChipPhase.process:
        return Icons.sync;
      case ChipPhase.report:
        return Icons.assessment;
    }
  }

  Color get color {
    switch (this) {
      case ChipPhase.setup:
        return const Color(0xFF607D8B); // Blue grey
      case ChipPhase.capture:
        return const Color(0xFF1565C0); // Blue
      case ChipPhase.process:
        return core_theme.AC.gold; // Gold
      case ChipPhase.report:
        return const Color(0xFF2E7D5B); // Emerald
    }
  }
}
