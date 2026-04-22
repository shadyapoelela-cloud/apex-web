/// APEX V5 — Canonical app colors (Odoo-style per-app identity).
///
/// Research basis (global platform conventions):
///   Odoo 17 — each app has a distinct brand color (Sales:mint, Purchase:violet,
///     Inventory:amber, Manufacturing:slate, HR:pink, CRM:red)
///   Microsoft 365 Fluent — Teams(purple), Excel(green), Word(navy),
///     PowerPoint(orange), Outlook(blue), Teams(violet), OneNote(magenta),
///     PowerBI(yellow), SharePoint(teal)
///   Google Workspace — Gmail(red), Drive(multi), Calendar(blue), Meet(green),
///     Docs(blue), Sheets(green), Slides(yellow)
///   Atlassian — Jira(blue), Confluence(teal), Bitbucket(navy), Trello(blue)
///   Salesforce Lightning — each cloud has a signature color
///   SAP Fiori 3 — consistent accent + varying saturation by group
///
/// Palette: Tailwind CSS 600-700 range — uniform saturation/luminance
/// → harmonious hues while still visually distinct. WCAG AA contrast
/// on white backgrounds for white-icon readability.
///
/// Grouping mirrors the app's AppGroup taxonomy (see v5_models.dart).
library;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// Color catalogue — 40+ module IDs mapped to identity colors
// ═══════════════════════════════════════════════════════════════════
const Map<String, Color> _moduleColors = <String, Color>{
  // ── ERP ▸ النواة المحاسبية (Core) ─────────────────────────────
  'finance': Color(0xFFCA8A04),         // Yellow-600  — APEX gold identity
  'consolidation': Color(0xFF0F766E),   // Teal-700    — hierarchical structure
  'treasury': Color(0xFF1E40AF),        // Blue-800    — banking classic

  // ── ERP ▸ دورات الأعمال (Business cycles) ─────────────────────
  'sales': Color(0xFF059669),           // Emerald-600 — revenue
  'purchases': Color(0xFF4338CA),       // Indigo-700  — procurement formal
  'expenses': Color(0xFFDC2626),        // Red-600     — cost
  'pos': Color(0xFFE11D48),             // Rose-600    — retail vibrant

  // ── ERP ▸ العمليات والإنتاج (Operations) ──────────────────────
  'inventory': Color(0xFFD97706),       // Amber-600   — warehouse
  'manufacturing': Color(0xFF475569),   // Slate-600   — industrial
  'construction': Color(0xFF78716C),    // Stone-500   — concrete
  'hotels': Color(0xFF86198F),          // Fuchsia-800 — hospitality
  'industry-packs': Color(0xFF0891B2),  // Cyan-600    — sector tech

  // ── ERP ▸ إدارة الموارد (Resources) ───────────────────────────
  'hr': Color(0xFFDB2777),              // Pink-600    — people
  'projects': Color(0xFF2563EB),        // Blue-600    — PM
  'crm': Color(0xFF7C3AED),             // Violet-600  — customer engagement

  // ── ERP ▸ المخرجات (Output) ───────────────────────────────────
  'reports': Color(0xFFEAB308),         // Yellow-500  — BI sunshine
  'bi': Color(0xFFEAB308),              // alias

  // ── COMPLIANCE ─────────────────────────────────────────────────
  'zatca': Color(0xFF0EA5E9),           // Sky-500
  'vat': Color(0xFF06B6D4),             // Cyan-500
  'tax': Color(0xFF0891B2),             // Cyan-600
  'governance': Color(0xFF64748B),      // Slate-500
  'aml': Color(0xFFB91C1C),             // Red-700
  'esg': Color(0xFF16A34A),             // Green-600

  // ── AUDIT ──────────────────────────────────────────────────────
  'planning': Color(0xFF3B82F6),        // Blue-500
  'fieldwork': Color(0xFF10B981),       // Emerald-500
  'reporting': Color(0xFFF59E0B),       // Amber-500
  'quality': Color(0xFF8B5CF6),         // Violet-500

  // ── ADVISORY ───────────────────────────────────────────────────
  'valuation': Color(0xFF14B8A6),       // Teal-500
  'forecasting': Color(0xFFF97316),     // Orange-500
  'strategy': Color(0xFF6366F1),        // Indigo-500
  'diligence': Color(0xFF9333EA),       // Purple-600
  'ma': Color(0xFFC2410C),              // Orange-700 (M&A)

  // ── MARKETPLACE ────────────────────────────────────────────────
  'marketplace': Color(0xFFEF4444),     // Red-500
  'rfp': Color(0xFFA855F7),             // Purple-500
  'providers': Color(0xFF0D9488),       // Teal-600
  'jobs': Color(0xFF7C2D12),            // Orange-900

  // ── Other / shared ─────────────────────────────────────────────
  'dashboard': Color(0xFF0EA5E9),       // Sky-500 (generic)
  'documents': Color(0xFF525B68),       // Slate-600
  'integrations': Color(0xFF059669),    // Emerald
  'onboarding': Color(0xFFCA8A04),      // Gold
  'settings': Color(0xFF6B7280),        // Gray-500
};

// ═══════════════════════════════════════════════════════════════════
// Lookup helpers
// ═══════════════════════════════════════════════════════════════════

/// Returns the canonical color for a module id, or [fallback] if not mapped.
Color moduleColor(String id, {required Color fallback}) =>
    _moduleColors[id] ?? fallback;

/// Returns `true` if this module has a canonical identity color.
bool hasModuleColor(String id) => _moduleColors.containsKey(id);

/// A darker companion — for gradient bottom-right stop, border accents,
/// hover shadows. Uses HSL tweak to preserve hue while dimming by 18%.
Color moduleColorDeep(String id, {required Color fallback}) {
  final base = moduleColor(id, fallback: fallback);
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation - 0.05).clamp(0.0, 1.0))
      .toColor();
}

/// Tinted soft background — for hover tints, selection surfaces.
/// Takes the module color and blends with white at 92% transparency.
Color moduleColorSoft(String id, {required Color fallback}) {
  final base = moduleColor(id, fallback: fallback);
  return Color.alphaBlend(base.withValues(alpha: 0.08), Colors.white);
}

/// Returns the gradient angle direction for a module — different groups
/// use different angles for subtle shape variation (Odoo-style).
/// 0 = top-left→bottom-right (default)
/// 1 = top→bottom
/// 2 = top-right→bottom-left
/// 3 = bottom-right→top-left (reversed, for emphasis)
int moduleGradientAngle(String id) {
  // Core accounting — diagonal (classic)
  if (<String>{'finance', 'consolidation', 'treasury'}.contains(id)) return 0;
  // Business cycles — vertical
  if (<String>{'sales', 'purchases', 'expenses', 'pos'}.contains(id)) return 1;
  // Operations — reverse diagonal
  if (<String>{'inventory', 'manufacturing', 'construction', 'hotels', 'industry-packs'}.contains(id)) return 2;
  // Resources — reversed full
  if (<String>{'hr', 'projects', 'crm'}.contains(id)) return 3;
  // default
  return 0;
}

/// Builds a gradient for this module's icon tile.
LinearGradient moduleGradient(String id, {required Color fallback}) {
  final c = moduleColor(id, fallback: fallback);
  final deep = moduleColorDeep(id, fallback: fallback);
  switch (moduleGradientAngle(id)) {
    case 1:
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[c, deep],
      );
    case 2:
      return LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: <Color>[c, deep],
      );
    case 3:
      return LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: <Color>[c, deep],
      );
    case 0:
    default:
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[c, deep],
      );
  }
}
