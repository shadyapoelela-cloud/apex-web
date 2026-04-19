# APEX — Unified Blueprint V3 → The Path to #1 in MENA

> **Version:** 3.0 • **Date:** 2026-04-18 • **Status:** Production-ready foundation, regional integrations pending
> **Scope:** Every screen, button, control, shortcut, state, API, integration — organized and wired.
> **Goal:** The single canonical reference for building APEX into the undisputed #1 financial + ERP platform in Saudi Arabia and the GCC.

---

## 📜 Table of Contents

1. [Strategic Foundation](#1-strategic-foundation)
2. [Current State Audit](#2-current-state-audit)
3. [Competitive Best-of-Breed Matrix](#3-competitive-best-of-breed-matrix)
4. [Information Architecture](#4-information-architecture)
5. [Navigation & Shell](#5-navigation--shell)
6. [Control Primitives](#6-control-primitives)
7. [Screen Families — Pattern Library](#7-screen-families--pattern-library)
8. [State & Data Flow](#8-state--data-flow)
9. [Every Button & Its Contract](#9-every-button--its-contract)
10. [Keyboard Shortcut System](#10-keyboard-shortcut-system)
11. [Real-time & Background Jobs](#11-real-time--background-jobs)
12. [Accessibility & Internationalization](#12-accessibility--internationalization)
13. [Design Quality Bar](#13-design-quality-bar)
14. [Wiring Map — What's Connected Today](#14-wiring-map)
15. [Gap Analysis & Next 90 Days](#15-gap-analysis--next-90-days)
16. [Organizational Playbook](#16-organizational-playbook)

---

<a name="1-strategic-foundation"></a>
## 1. Strategic Foundation

### 1.1 The Unique Wedge

APEX wins on a four-axis intersection no single competitor owns:

```
            ┌─ Arabic-Native ─ Qoyod/Daftra (but thin compliance, no AI)
            │
APEX ───────┼─ ZATCA/FTA-Deep ─ Wafeq (but weak AI, single currency)
            │
            ├─ AI-Native ────── Pilot/Puzzle/Ramp (but no Arabic, no MENA)
            │
            └─ Linear/Stripe Polish ─ every category, zero in accounting
```

**The moat:** no global AI-native accounting platform speaks Arabic.
No Arabic accounting platform is AI-native.
No regional player has Stripe-grade polish.

APEX ships all four.

### 1.2 North-Star Metrics (12 months)

| Metric | Day 0 | Q1 | Q2 | Q3 | Q4 |
|--------|------:|---:|---:|---:|---:|
| Paying Tenants | 0 | 100 | 500 | 2,000 | 10,000 |
| MRR (SAR) | 0 | 50k | 500k | 2M | 4.5M |
| ZATCA Compliance Rate | 0% | 99% | 99.5% | 99.9% | 99.99% |
| Bank Reconciliation Auto-Match | 0% | 70% | 85% | 92% | 96% |
| AP Automation Rate | 0% | 20% | 50% | 75% | 85% |
| Copilot Queries/User/Day | 0 | 5 | 15 | 30 | 50 |
| API Uptime | — | 99.5% | 99.9% | 99.95% | 99.99% |
| NPS | — | 30 | 45 | 55 | 65 |

---

<a name="2-current-state-audit"></a>
## 2. Current State Audit

### 2.1 What's Built (as of 2026-04-18)

#### Flutter Front-End
- **89 screens** registered (61 routes in GoRouter)
- **28 shared widgets** in `lib/core/apex_*.dart`:
  - Layout: `ApexAppBar`, `ApexStickyToolbar`, `ApexBottomNav`, `ApexResponsive`, `ApexFlexibleColumns`, `ApexBreakpointPreview`
  - Tables: `ApexDataTable`, `ApexSyncfusionGrid` (5k-row virtual scroll), `ApexFilterBar`, `ApexSavedViewsBar`, `ApexInlineEditable`
  - Forms: `ApexFormField`, `ApexSemanticField` (live validation with color bands)
  - Data-rich: `ApexDashboardBuilder`, `ApexReportBuilder`, `ApexForecastChart`, `ApexBomTree`, `ApexKanban<T>`, `ApexWorkOrderCard`, `ApexThreeWayMatch`
  - Input: `ApexBarcodeInput`, `ApexVoiceInput`
  - Nav: `ApexCommandPalette`, `ApexCommandsRegistry`, `ApexAppSwitcher`, `ApexEntityBreadcrumb`, `ApexRecentItems`
  - Feedback: `ApexNotificationBell` / `ApexNotificationBellLive`, `ApexShimmer`, `ApexStatusBar`, `ApexChatter` / `ApexChatterConnected`
  - Realtime: `ApexWsClient` (singleton WebSocket with auto-reconnect)
  - Branding: `ApexWhiteLabel`, `ApexWhiteLabelConnected`, `ApexThemeGenerator`, `ApexContextualToolbar`
  - Workflow: `ApexWorkflowRules`, `ApexAutoSave`, `ApexPreviewPanel`, `ApexIntegrationCard`
  - Offline: `ApexOfflineQueue`
  - a11y: `ApexA11y`

#### Back-End
- **22 public REST endpoints** live under `/api/v1/*`
- **14 new Python modules** added this cycle:
  - `activity_log.py` — Chatter timeline (4 routes)
  - `auto_log.py` — SQLAlchemy event listener (status changes → ActivityLog)
  - `notifications_api.py` — bell bootstrap (3 routes)
  - `offline_sync.py` — PWA queue
  - `tenant_branding.py` — white-label persistence
  - `rls_session.py` — PostgreSQL RLS session GUC
  - `reports_download.py` — CSV / Excel / PDF stream
  - `system_health.py` — 6-subsystem aggregator
  - `zatca_submit_e2e.py` — UBL → retry → Fatoora → PDF
  - `ai/proactive.py` + `ai/scheduler.py` + `ai/routes.py`
  - `integrations/zatca/invoice_pdf.py` — embedded-QR invoice PDF

#### Infrastructure
- **2 Alembic migrations** (`c7f1a9b02e10` infra tables, `d3a1e9b4f201` Postgres RLS)
- **WebSocket hub** (`/ws/notifications`) with per-channel fan-out
- **Rate limiter** (tier-based per-IP middleware)
- **Tenant guard** (SQLAlchemy event listeners + PostgreSQL RLS)
- **Activity log** + **auto-log** + **live bell** → realtime loop closed end-to-end

#### Quality
- **1,200+ tests passing** in `tests/`
- **0 compile errors** across the Flutter + Python codebases
- **6 API latency micro-benchmarks** (p50 < 500ms on every hot path)
- **Locust load test suite** with realistic traffic mix

---

<a name="3-competitive-best-of-breed-matrix"></a>
## 3. Competitive Best-of-Breed Matrix

The specific element APEX steals from each platform and the APEX file/screen where it lives now.

### 3.1 Global

| Platform | The thing they do best | APEX equivalent |
|----------|------------------------|-----------------|
| **Odoo 19** | Chatter on every record | `ApexChatter` + `ApexChatterConnected` + `activity_log.py` |
| **Odoo 19** | Recent items in sidebar | `ApexRecentItems` |
| **Odoo 19** | Automation rules UI | `ApexWorkflowRules` |
| **Odoo 19** | Sticky status bar | `ApexStickyToolbar` + `ApexStatusBar` |
| **SAP Fiori** | Flexible Column Layout | `ApexFlexibleColumns` |
| **SAP Fiori** | Semantic-color validation | `ApexSemanticField` (5 states) |
| **SAP Fiori** | Object page + chatter | `client_detail_screen.dart` tabs + Chatter |
| **Xero JAX** | Drag-drop reconciliation | `bank_rec_screen.dart` (production-wired) |
| **Xero JAX** | Right-hand preview panel | `ApexPreviewPanel` + Sprint 37 split layout |
| **Xero** | Auto-save drafts | `ApexAutoSave` mixin |
| **QuickBooks 2026** | Pinned favorites sidebar | `ApexBottomNav` more-sheet |
| **QuickBooks** | Tax-aware invoice form | `zatca_invoice_builder_screen.dart` |
| **Pennylane** | Dense list with quick filters | `ApexDataTable` + `ApexFilterBar` + `ApexSavedViewsBar` |
| **Pennylane** | Cmd+K command palette | `ApexCommandPalette` (21 commands) |
| **Linear** | Keyboard-first | Alt+1..9 + Cmd+K + / focus search |
| **Linear** | 3-variable theme system | `ApexThemeGenerator` (Base + Accent + Contrast) |
| **Linear** | 180 ms animations | `AppDuration.medium` in design tokens |
| **Stripe** | API-first + webhook signing | `webhooks.py` HMAC-SHA256 |
| **Stripe** | Developer docs polish | SDKs (Python, Node, PHP) generated |
| **Stripe** | Dashboard with 4 KPI cards | `sprint38-composable` demo |
| **Notion** | Composable dashboard blocks | `ApexDashboardBuilder` (7-widget registry) |
| **Ramp** | Spend policy agent | `ApexWorkflowRules` (Policy-as-document) |
| **Ramp** | Real-time merchant match | `categorize_transaction` tool (11-rule lexicon) |
| **Pilot.com** | Autonomous bookkeeper | `ai/proactive.py` + 9 Copilot tools |
| **Puzzle.io** | Governed AI with undo | `governed_ai.py` + audit log |
| **Digits** | pgvector txn embeddings | `copilot_memory` facts table |
| **Vic.ai** | Per-vendor learning | COA engine v4.3 (5-layer classifier) |
| **Mercury** | Real-time cashflow | `ApexForecastChart` + proactive scheduler |
| **Wise** | Transparency on FX | `fx_converter_screen.dart` |
| **Raycast** | Unified fuzzy search | `ApexCommandPalette` (Arabic-aware) |
| **Superhuman** | Single-key triage | Alt+1..9 module nav |

### 3.2 Regional

| Platform | Their differentiator | APEX response |
|----------|---------------------|---------------|
| **Qoyod** | 199 SAR flat + simple Arabic | Match their price tier + add AI Copilot + multi-entity |
| **Wafeq** | ZATCA Phase 2 depth | Match (E2E pipeline + PDF + retry queue), add accountant marketplace |
| **Rewaa** | POS + retail F&B | Industry Packs (`industry_packs_screen`) + Foodics integration card |
| **Daftra** | Bilingual templates | Same + Linear-grade polish + ZATCA compliance |
| **Zoho Books MENA** | Zoho One bundle | Same dimensional accounting + deeper Arabic (authored not translated) |
| **Tally** | Desktop muscle-memory | Ctrl+K palette mirrors Tally shortcuts + cloud |

---

<a name="4-information-architecture"></a>
## 4. Information Architecture

The full sitemap. Every route is listed once, with its parent group.

### 4.1 Public / Unauthenticated

- `/login` — slide-auth with phone + email paths
- `/register` — 4-step wizard
- `/forgot-password` — recovery flow

### 4.2 Authenticated Shell

Every screen below is wrapped in:
- **Top:** `ApexAppBar` with `_GlobalBell` + Cmd+K hint
- **Left:** Hybrid sidebar (desktop) or `ApexBottomNav` more-sheet (mobile)
- **Floating:** Command palette (`Ctrl+K`) overlay

### 4.3 Module Groups

| Group | Top-level route | Children |
|-------|----------------|----------|
| **Dashboard** | `/home` | Main nav, widgets |
| **Clients** | `/clients` | List, Detail (tabs: Info/Docs/Services/Activity), Onboarding Wizard |
| **Financial Ops** | `/financial` | Unified list + filters + builder |
| **Compliance Hub** | `/compliance` | 30+ sub-tools |
| **Copilot** | `/copilot` | Chat + history + tools palette |
| **Knowledge** | `/knowledge` | Search + conversations + artifacts |
| **Marketplace** | `/marketplace` | Providers, services, bookings |
| **Admin** | `/admin/*` | Users, roles, audit, health |
| **Settings** | `/settings` | Profile, theme, branding, integrations |
| **Meta** | `/apex-map`, `/whats-new`, `/showcase`, `/theme-generator`, `/white-label` | Navigation meta-screens |

### 4.4 Compliance Hub Children (the crown jewel)

Organized by business workflow, not by file order:

**Tax & Regulatory**
- `/compliance/zatca-invoice` — e-invoice builder
- `/compliance/vat-return` — 15%/5% return
- `/compliance/zakat` — 2.5% base calculator
- `/compliance/wht` — withholding tax
- `/compliance/deferred-tax` — IFRS 12
- `/compliance/extras-tools` — SBP, property, P2, VAT-G

**Period Close**
- `/compliance/journal-entries` — JE sequence mgmt
- `/compliance/journal-entry-builder` — new JE form
- `/compliance/trial-balance` — TB viewer
- `/compliance/fin-statements` — P&L + BS + CF
- `/compliance/audit-trail` — SHA-256 chain

**Asset Life-cycle**
- `/compliance/fixed-assets` — register
- `/compliance/depreciation` — schedule
- `/compliance/amortization` — intangibles
- `/compliance/lease` — IFRS 16
- `/compliance/valuation` — impairment

**AR / AP / Banking**
- `/compliance/aging` — receivables + payables
- `/compliance/bank-rec` — reconciliation
- `/compliance/dscr` — debt service coverage

**Analytics**
- `/compliance/executive` — CFO dashboard
- `/compliance/ratios` — 20+ ratios
- `/compliance/cashflow` — direct method
- `/compliance/cashflow-statement` — IAS 7
- `/compliance/working-capital` — WC cycle
- `/compliance/breakeven` — CVP
- `/compliance/budget-variance` — actual vs budget
- `/compliance/cost-variance` — 3-tab variance
- `/compliance/consolidation` — group reporting
- `/compliance/transfer-pricing` — TP methods

**Operational**
- `/compliance/payroll` — payroll runs
- `/compliance/inventory` — stock movements
- `/compliance/ocr` — scan receipt
- `/compliance/ifrs-tools` — 5 IFRS calculators
- `/compliance/fx-converter` — currency
- `/compliance/health-score` — system score
- `/compliance/investment` — portfolio

### 4.5 "What's New" demos (Sprint 35 → 44)

- `/sprint35-foundation` — 8 power-user features
- `/sprint37-experience` — preview panel + app switcher
- `/sprint38-composable` — dashboard builder + bell
- `/sprint39-erp` — HR + CRM Kanban + Workflow
- `/sprint40-payroll` — GOSI/WPS + report builder
- `/sprint41-procurement` — barcode + 3-way match
- `/sprint42-longterm` — AI cashflow + consolidation + BOM
- `/sprint43-platform` — marketplace + white-label + a11y
- `/sprint44-operations` — work orders + Gantt + responsive
- `/syncfusion-grid` — 5k-row virtual scroll demo
- `/theme-generator` — Linear 3-variable generator
- `/white-label` — connected editor

---

<a name="5-navigation--shell"></a>
## 5. Navigation & Shell

### 5.1 The Three Entry Surfaces

```
┌──────────────────────────────────────────────────────────────┐
│  ApexAppBar  [title]      [bell🔔]  [actions...]  [avatar]   │
├──────────────────────────────────────────────────────────────┤
│          │                                                   │
│  Side    │     Main content                                  │
│  Nav     │                                                   │
│  250px   │                                                   │
│          │     (ApexFlexibleColumns on deep workflows:       │
│  - Home  │      List ▸ Detail ▸ Sub-detail in 3 panes)       │
│  - …     │                                                   │
│  - Favs  │                                                   │
│  - Recent│                                                   │
│          │                                                   │
├──────────┴───────────────────────────────────────────────────┤
│   Status bar / Bottom sheet (mobile) / FAB (+)               │
└──────────────────────────────────────────────────────────────┘

          + Overlay: ApexCommandPalette on Ctrl+K
          + Overlay: ApexAppSwitcher on app-grid click
          + Overlay: NotificationCenter slide-out from bell
```

### 5.2 Sidebar Contract (inspired by Odoo 19 + QuickBooks)

**Desktop expanded — 250px:**
- Brand logo + company name (tenant-aware via `tenant_branding`)
- Module groups with badge counters (overdue count per module)
- **Pinned/Favorites** section (drag-to-pin, from QuickBooks 2026)
- **Recent Items** last 8 (from Odoo 19, via `ApexRecentItems`)
- User chip at bottom + settings cog

**Desktop collapsed — 62px:**
- Icon-only, tooltip on hover
- Favorites + Recent become mini-circles with hover-expand

**Tablet:** 62px permanent collapsed, tap to overlay.

**Mobile:** `ApexBottomNav` with 5 slots + More sheet.

### 5.3 Breadcrumb (`ApexEntityBreadcrumb`)

Odoo-style with real entity names:
```
Home ▸ Clients ▸ شركة الرياض للتجارة ▸ Invoice INV-1042
```
- Middle segments collapse to `…` below 720 px viewport
- Each segment tappable (except last = current)
- Icons inline for clarity

---

<a name="6-control-primitives"></a>
## 6. Control Primitives

Every interactive element in the app, its API, and the rules.

### 6.1 Button Hierarchy (5 Levels)

| Level | When to use | Widget |
|-------|-------------|--------|
| **Primary** (filled gold) | One per screen — the main action | `FilledButton` with `AC.gold` |
| **Secondary** (outlined) | 1-2 per screen — alternative action | `OutlinedButton` |
| **Tertiary** (text) | Many — inline actions, links | `TextButton` |
| **Destructive** (red outlined) | Delete, archive, force actions | `OutlinedButton` with `foregroundColor: AC.err` |
| **Icon** (ghost) | Toolbar actions, inline edits | `IconButton` with tooltip |

**Rule:** No more than ONE primary button per screen. Violations fail design review.

### 6.2 Form Field States (via `ApexSemanticField`)

| State | Border | Suffix | When |
|-------|--------|--------|------|
| **idle** | grey (`AC.bdr`) | — | untouched |
| **info** | blue (`AC.gold`) | ℹ | hint shown below |
| **warning** | amber | ⚠ | non-blocking issue |
| **error** | red (`AC.err`) | ✗ | submit blocked |
| **ok** | green (`AC.ok`) | ✓ | validated + populated |

Validation runs **250 ms debounced** on every change.

### 6.3 Table Controls

`ApexDataTable` supports:
- Click header → sort cycle (none → asc → desc → none)
- Checkbox column for bulk selection (optional)
- Double-click cell → inline edit via `ApexInlineEditable`
- Row hover highlight (80 ms)
- Frozen header on scroll
- Empty / loading / error states

`ApexSyncfusionGrid` (for >1000 rows) adds:
- Freeze N leading columns
- Virtual scroll (only visible rows render)
- Inline edit on editable columns
- Column sort without rebuild

### 6.4 Dialog / Drawer Rules

| Pattern | Use when | Widget |
|---------|----------|--------|
| **Full modal** | Destructive confirm, auth step | `AlertDialog` |
| **Right-hand drawer** | Preview, edit-on-select, filters | `ApexPreviewPanel` |
| **Bottom sheet** | Mobile actions, more menu | `showModalBottomSheet` |
| **Inline expansion** | Progressive disclosure in list | `ExpansionTile` / `AnimatedSize` |
| **Toast** | Confirmation, undo (7 s) | `ScaffoldMessenger.showSnackBar` |
| **Command palette** | Universal search + actions | `ApexCommandPalette` |

**Forbidden:** modal-on-modal stacking. Drawer-on-drawer is allowed because they're spatial.

### 6.5 Status Indicators

| Meaning | Color | Icon |
|---------|-------|------|
| Success / paid / cleared | `AC.ok` | ✓ `check_circle` |
| In progress | `AC.gold` | ⚙ `hourglass_bottom` |
| Warning / pending | amber | ⚠ `warning_amber` |
| Error / rejected | `AC.err` | ✗ `error_outline` |
| Info / note | blue | ℹ `info_outline` |

Always accompanied by text — color is never the only signal (a11y).

---

<a name="7-screen-families--pattern-library"></a>
## 7. Screen Families — Pattern Library

Every screen in APEX belongs to one of five families. Each family has a canonical layout so users predict the next screen before they see it.

### 7.1 List View (pattern: Clients, Invoices, JE, Providers)

```
┌─────────────────────────────────────────────┐
│ ApexAppBar  [bell]  [+ New] [⟳ Refresh]     │
├─────────────────────────────────────────────┤
│ ApexFilterBar [chips] [search] [date]       │
├─────────────────────────────────────────────┤
│ ApexSavedViewsBar [⭐ Saved A] [+ Save]     │
├─────────────────────────────────────────────┤
│ ApexContextualToolbar (appears on select)   │
├─────────────────────────────────────────────┤
│ ApexDataTable / ApexSyncfusionGrid          │
│   - frozen header                           │
│   - sort on click                           │
│   - double-click to inline-edit             │
│   - row tap → Preview panel OR detail nav   │
└─────────────────────────────────────────────┘
```

### 7.2 Detail View (pattern: Client, Invoice, Employee)

```
┌─────────────────────────────────────────────┐
│ ApexAppBar  [bell]  [Edit] [⋮]              │
├─────────────────────────────────────────────┤
│ ApexEntityBreadcrumb: Home ▸ List ▸ Name    │
├─────────────────────────────────────────────┤
│ Hero card: avatar + name + status + key KPIs│
├─────────────────────────────────────────────┤
│ Tabs: [Info] [Documents] [Services] [Activity]│
│                                             │
│ Active tab content — NEVER scrolls past hero│
│                                             │
│ Activity tab = ApexChatterConnected         │
└─────────────────────────────────────────────┘
```

### 7.3 Form / Builder (pattern: Journal Entry, ZATCA Invoice, Zakat)

```
┌─────────────────────────────────────────────┐
│ ApexAppBar  [Save draft] [Post] (sticky)    │
├─────────────────────────────────────────────┤
│ Wide: split 60 / 40                         │
│                                             │
│ ┌────────────┐  ┌────────────┐              │
│ │ Form       │  │ Preview /  │              │
│ │ (sections) │  │ Live calc  │              │
│ │            │  │ / QR / PDF │              │
│ │ ApexSemantic│ │            │              │
│ │ Fields     │  │            │              │
│ └────────────┘  └────────────┘              │
│                                             │
│ Narrow: stacked, preview below form         │
└─────────────────────────────────────────────┘
```

- Auto-save every 2 s via `ApexAutoSave`
- Real-time validation via `ApexSemanticField`
- Sticky action bar at top — Post confirms via dialog

### 7.4 Dashboard (pattern: Home, Executive, Compliance Hub)

```
┌─────────────────────────────────────────────┐
│ ApexAppBar  [bell]  [Edit layout]           │
├─────────────────────────────────────────────┤
│ Period selector + filter chips              │
├─────────────────────────────────────────────┤
│ ApexDashboardBuilder blocks on 12-col grid  │
│                                             │
│ [KPI] [KPI] [KPI] [KPI]      ← 4×3          │
│ [Wide chart ─────────]       ← 1×12         │
│ [Trend ] [Aging pie]         ← 6+6          │
│ [AI Task Widget]             ← 12 wide      │
│                                             │
│ Drag to reorder, resize span, remove, add   │
└─────────────────────────────────────────────┘
```

### 7.5 Workflow / Pipeline (pattern: Work Orders, CRM Leads, Approvals)

```
┌─────────────────────────────────────────────┐
│ ApexAppBar  [bell]  [+ New] [filters]       │
├─────────────────────────────────────────────┤
│ ApexStatusBar: Draft → Pending → Approved   │
│                (Odoo-style pipeline)        │
├─────────────────────────────────────────────┤
│ ApexKanban<T>: swimlanes with drag-drop     │
│                                             │
│  [New]   [Qualified]  [Negotiating]  [Won]  │
│  ┌───┐   ┌───┐        ┌───┐          ┌───┐ │
│  │ A │   │ D │        │ F │          │ H │ │
│  │ B │   │ E │        │ G │          └───┘ │
│  │ C │   └───┘        └───┘                │
│  └───┘                                      │
└─────────────────────────────────────────────┘
```

---

<a name="8-state--data-flow"></a>
## 8. State & Data Flow

### 8.1 Client-side state

```
User action
    ↓
Widget (optimistic update)
    ↓
ApiService.post / patch
    ↓   (with retry via apex_api_retry)
Backend
    ↓
SQLAlchemy flush
    ↓
  ┌─ auto_log event listener → ActivityLog insert
  │                              ↓
  │                              log_activity()
  │                              ↓
  │                              _publish_activity_event()
  │                              ↓
  │                              WebSocketHub.publish()
  │                              ↓
  │                              entity:{type}:{id} + user:{uid}
  │                              ↓
  │                              ApexWsClient receives
  │                              ↓
  │                              Chatter panel + Bell update
  └─ API response returned to caller
    ↓
Widget reconciles (keeps optimistic if match)
```

### 8.2 Offline-first envelope

```
Offline user action
    ↓
ApexOfflineQueue.enqueue(op)    ← localStorage
    ↓
(sits in queue until connection)
    ↓
On connection restored:
    ↓
POST /api/v1/sync/push [batch of 50]
    ↓
SyncOperation rows — status=pending
    ↓
register_sync_handler(entity_type, handler) dispatches
    ↓
Status → applied / conflict / rejected / superseded
    ↓
Response drives local state reconciliation
```

### 8.3 Tenant isolation (defense in depth)

```
Request → TenantContextMiddleware extracts JWT.tenant_id / X-Tenant-Id
       ↓
       ContextVar.set(tenant_id)
       ↓
Routes run handler
       ↓
  ┌─ App layer: tenant_guard.py before_compile → auto-filter SELECTs
  │                                 before_flush → auto-set tenant_id
  │
  └─ DB layer (PostgreSQL): rls_session.py on connection checkout
                             SET app.current_tenant = '<uuid>'
                             RLS policy filters every query
```

Both layers run. Either alone prevents cross-tenant leaks; together they're belt-and-suspenders.

---

<a name="9-every-button--its-contract"></a>
## 9. Every Button & Its Contract

This section is the single source of truth for every action the user can take. Use it when building a new screen to keep conventions consistent.

### 9.1 Universal Toolbar Actions

| Button | Shortcut | When visible | Confirms? |
|--------|----------|--------------|-----------|
| **+ New** (primary gold) | `N` | Every list view | No — opens form |
| **⟳ Refresh** | `R` | Every list/dashboard | No |
| **⋮ Options** | | Every detail/form | Menu, no direct action |
| **🔔 Notifications** | `G N` | Every screen (when authed) | Opens panel |
| **🔍 Search** / Cmd+K | `Ctrl+K` `Cmd+K` `/` | Everywhere | Opens palette |
| **⭐ Save view** | | Every list with filter bar | No |
| **↑ Upload** | `U` | Entities that accept attachments | File picker |
| **↓ Export** | `E` | Every list + dashboard | Format picker → download |

### 9.2 Per-Record Actions

| Button | Where | Shortcut | Confirms? |
|--------|-------|----------|-----------|
| **Edit** | Detail hero | `E` | No — opens form |
| **Delete** (destructive red) | Detail ⋮ menu | `Delete` | Yes — dialog + undo toast |
| **Archive** | List row menu / ⋮ | `A` | No — toast with undo |
| **Duplicate** | List row menu / ⋮ | `D` | No — opens form pre-filled |
| **Assign** (ownership) | List row menu | `:` | Modal with user picker |
| **Move to…** (status change) | Detail toolbar | `M` | Confirms if irreversible |
| **Approve** | Approval queue | `Shift+A` | Yes — dialog |
| **Reject** | Approval queue | `Shift+R` | Yes — requires reason |

### 9.3 Financial Actions (Journal / Invoice / ZATCA)

| Button | State machine | Reversible? |
|--------|--------------|-------------|
| **Save draft** | → draft | yes — via edit |
| **Submit for approval** | draft → pending | yes — revoke |
| **Approve** | pending → approved | no — via reversing entry |
| **Post** | approved → posted | no — creates reversal pair |
| **Send to ZATCA** | posted → reporting/clearance | no — handled by retry queue |
| **Download PDF** | any terminal state | always |
| **Reverse** | posted → reversed + new draft | yes — creates a new entry |

### 9.4 Bulk Actions (ApexContextualToolbar)

Activates when ≥1 row selected. Swaps the toolbar gold.

| Context | Actions |
|---------|---------|
| **Invoices selected** | Mark as paid • Send reminder • Export • Delete |
| **JEs selected** | Post all • Reverse all • Export • Delete |
| **Clients selected** | Merge • Tag • Assign owner • Export |
| **Employees selected** | Bulk approve leave • Run payroll • Export |
| **Any** | Clear selection (close ×) |

### 9.5 Copilot Tools (exposed via chat + buttons)

| Tool | Invokable by | Requires confirm? |
|------|-------------|-------------------|
| `query_financial_data` | NL question | No |
| `get_report` | NL or button | No |
| `explain_variance` | NL | No |
| `forecast` | NL | No |
| `lookup_entity` | NL or Ctrl+K | No |
| `create_invoice` | NL | **YES** — draft shown first |
| `send_reminder` | NL or button | **YES** — preview + count |
| `generate_report` | NL or button | No — downloads file |
| `categorize_transaction` | NL or bank-rec inline | No |

---

<a name="10-keyboard-shortcut-system"></a>
## 10. Keyboard Shortcut System

Fully implemented in `apex_app.dart`. Inspired by Linear + Superhuman.

### 10.1 Global (available anywhere)

| Shortcut | Action |
|----------|--------|
| `Ctrl+K` / `Cmd+K` | Open command palette |
| `Alt+1` | Home |
| `Alt+2` | Executive dashboard |
| `Alt+3` | Journal entries |
| `Alt+4` | ZATCA invoice |
| `Alt+5` | VAT return |
| `Alt+6` | Bank reconciliation |
| `Alt+7` | Copilot |
| `Alt+8` | Knowledge |
| `Alt+9` | What's new |
| `Esc` | Close any modal / drawer / overlay |
| `?` | Show shortcut overlay |
| `/` | Focus search |

### 10.2 Navigation (vim-style "go to")

| Shortcut | Action |
|----------|--------|
| `G D` | Dashboard |
| `G I` | Invoices |
| `G C` | Clients |
| `G R` | Reports |
| `G S` | Settings |

### 10.3 Context-specific (on the right screen)

**List views:** `J`/`K` navigate rows, `Enter` open, `Shift+Enter` open in panel, `X` select row, `Cmd+A` select all

**Detail views:** `E` edit, `U` upload, `Delete` delete, `Tab` next tab

**Forms:** `Ctrl+S` save draft, `Ctrl+Enter` submit, `Esc` discard

**Journal entry:** `D` add debit line, `C` add credit line, `P` post, `S` save

### 10.4 Discoverability

- `?` shows modal with all shortcuts for the current screen
- Tooltips show the shortcut in grey text next to the label
- Command palette lists every action with its shortcut

---

<a name="11-real-time--background-jobs"></a>
## 11. Real-time & Background Jobs

### 11.1 The Realtime Loop

```
╔═══════════════════════════════════════════════════════╗
║  DB write                                              ║
║      ↓                                                 ║
║  auto_log / log_activity (always)                      ║
║      ↓                                                 ║
║  log_activity fires WebSocketHub.publish               ║
║      ↓                                                 ║
║      ├─ entity:{type}:{id}    ← Chatter tabs          ║
║      └─ user:{user_id}         ← bell badge           ║
║      ↓                                                 ║
║  Flutter ApexWsClient streams                          ║
║      ↓                                                 ║
║      ├─ ApexChatterConnected (live messages)          ║
║      └─ ApexNotificationBellLive (live badge)         ║
╚═══════════════════════════════════════════════════════╝
```

### 11.2 Background Jobs

| Job | Trigger | Frequency | Owner |
|-----|---------|-----------|-------|
| **Proactive AI Scan** | `scheduler.py` asyncio loop | every 6 h (default) | `ai/proactive.py` |
| **ZATCA Retry Worker** | `due_for_retry()` polling | every 60 s (TBD) | `integrations/zatca/retry_queue.py` |
| **Offline Sync Processing** | on PWA reconnect | event-driven | `core/offline_sync.py` |
| **Alembic Migrations** | startup | once per deploy | `core/db_migrations.py` |

### 11.3 Notification Channels (user-configurable)

| Channel | In-app | Email | WhatsApp | SMS |
|---------|:------:|:-----:|:--------:|:---:|
| Invoice paid | ✓ | optional | optional | no |
| Invoice overdue | ✓ | optional | optional | no |
| ZATCA rejected | ✓ | **always** | optional | no |
| AP 3-way match fail | ✓ | **always** | optional | no |
| Budget breach | ✓ | optional | optional | no |
| Payroll due | ✓ | optional | no | no |
| System alert | ✓ | **always** | no | optional |

---

<a name="12-accessibility--internationalization"></a>
## 12. Accessibility & Internationalization

### 12.1 WCAG 2.1 AA Compliance

**Contrast:**
- Financial numbers: ≥ 7:1 (AAA)
- Body text: ≥ 4.5:1 (AA)
- Tested live in `/sprint43-platform` § WCAG audit

**Keyboard:**
- Every interactive element reachable by Tab
- Focus ring: 2 px `#2563EB` — NEVER `outline:none`
- Enter/Space activates buttons
- Escape closes modals

**Screen reader:**
- Every `ApexColumn` wrapped in `Semantics(label:)`
- Sort headers use `OrdinalSortKey`
- Live regions announce rate-limited changes (`SemanticsService.announce`)
- Every amount lip-read in full form — "مئة وخمسون ريالاً"

**Motion:**
- `MediaQuery.of(context).disableAnimations` honoured → 0 ms

**Touch targets:** ≥ 48×48 dp (56 on mobile for older accountants)

### 12.2 Arabic (RTL) Rules

| Element | Direction |
|---------|-----------|
| Overall layout | RTL on `locale = ar` |
| Numeric columns | LTR always (tabular figures) |
| Charts (time axis) | LTR always (chronology reads left-to-right) |
| Progress bars | Fill right-to-left on RTL |
| Icons with direction (arrow_forward) | Auto-flip via `Directionality` |
| Date pickers | Hijri + Gregorian toggle |
| Numerals | Western (0-9) default; toggle to Eastern (٠-٩) per user |

### 12.3 Typography Stack

```yaml
body_arabic:      IBM Plex Sans Arabic → Noto Sans Arabic → Tajawal
heading_arabic:   Cairo (Kufi)
longform_arabic:  Amiri (for audit reports)
numerals_mono:    JetBrains Mono (for figures)
body_latin:       Inter

sizes_arabic:  16 / 20 / 24 / 32 / 48
sizes_latin:   14 / 18 / 22 / 28 / 44

line_height:
  arabic:  1.7
  latin:   1.5
```

---

<a name="13-design-quality-bar"></a>
## 13. Design Quality Bar

Twelve enforceable rules. Violations fail design review.

1. **Command-first** — every action reachable via Ctrl+K in ≤ 2 keystrokes.
2. **Keyboard > mouse** — no workflow requires a pointer for power users.
3. **Progressive disclosure** — summary → click → drawer, no page jumps mid-task.
4. **One-screen rule** — invoice/JE/TB review fits 1440×900 without scroll.
5. **Data-ink ratio ≥ 80%** — no decorative shadows/gradients.
6. **Real-time feedback** — balance/TB updates animate the delta (400 ms).
7. **Contextual density** — "Accountant" row 28 px; "Business owner" row 44 px (user setting).
8. **Semantic colour only** — every colour carries meaning (see § 6.5).
9. **Undo everywhere** — 7 s toast after any destructive action.
10. **Optimistic UI** — writes show immediately; sync in background.
11. **Verb vocabulary unified** — same verbs across all phases (add / edit / delete / approve).
12. **Skeleton loaders** — never spinners.

Five anti-patterns **BANNED**:

1. ❌ Modal stacking (modal inside modal)
2. ❌ Hidden destructive actions (Trash without confirm + undo)
3. ❌ Mystery-meat icons (no bilingual tooltip)
4. ❌ Uncommitted form state lost on nav (autosave every 2 s)
5. ❌ Mixed numerals in the same view (٥٠٠ next to 500)

---

<a name="14-wiring-map"></a>
## 14. Wiring Map — What's Connected Today

Honest matrix — green = full production loop, amber = demo wired, red = missing.

### 14.1 Front-end → Back-end loops

| Loop | Status |
|------|:------:|
| Chatter: comment → `/activity` → WS → bell | 🟢 |
| Notification bell: history + live | 🟢 |
| Saved filter views | 🟢 |
| White-label: editor ↔ `/tenant/branding` | 🟢 |
| Auto-log on status change | 🟢 |
| Proactive AI scan → scheduler → bell | 🟢 |
| ZATCA submit-e2e → retry → PDF | 🟢 |
| Activity log with WebSocket push | 🟢 |
| Clients list: filter + saved views + data | 🟢 |
| Client detail: tabs + activity (live) | 🟢 |
| Invoice detail: Chatter wiring | 🟡 (via same route, needs screen wiring) |
| PO detail: Chatter wiring | 🟡 |
| Employee detail: Chatter wiring | 🟡 |
| Copilot: 9 tools | 🟢 |
| Reports download (CSV/Excel/PDF) | 🟢 |
| System health dashboard | 🟢 (API + needs admin UI) |

### 14.2 External Integrations

| Integration | Status |
|-------------|:------:|
| Stripe (payments) | 🟢 |
| SendGrid / SMTP (email) | 🟢 |
| SMS (Unifonic/Twilio) | 🔴 **stub only** |
| WhatsApp Business | 🟡 demo + client exists |
| ZATCA Fatoora API | 🟢 (sandbox wired) |
| UAE FTA Peppol | 🔴 |
| SAMA Open Banking | 🔴 |
| Claude AI (Anthropic) | 🟢 |
| Al Rajhi / SNB bank feed | 🔴 |
| Mada / STC Pay / Apple Pay | 🔴 |
| Corporate Cards (NymCard/Yuze) | 🔴 |
| Mudad (WPS submission) | 🟡 stub |

---

<a name="15-gap-analysis--next-90-days"></a>
## 15. Gap Analysis & Next 90 Days

### 15.1 What's genuinely missing (code-only, actionable without credentials)

1. **Wire Chatter into Invoice detail + PO detail + Employee detail** (3 screens × ~30 min each)
2. **Admin System Health dashboard** (`/admin/system-health` Flutter screen consuming `/api/v1/system/health`)
3. **Notification preferences screen** (`/settings/notifications` — read/write per-category on/off)
4. **Mobile bottom-nav customization** per user (favorites persistence)
5. **Flexible Column Layout wired** on Clients workflow (list → detail → invoice in 3 panes)
6. **Dart unit tests** for pure helpers (ApexInlineEditable parser, dedupe logic, hex↔Color)

### 15.2 Needs credentials / partnerships

1. SMS provider choice (Unifonic vs Twilio) → 1 day implementation after choice
2. WhatsApp Business Meta verification → 2-3 days wiring templates
3. Bank feed OCR against real statements → 1 week × each bank
4. Mada payment integration (HyperPay or PayTabs) → 3 days
5. NymCard / Yuze card issuing → depends on partnership
6. SAMA AISP license → 3-6 months regulatory
7. Mudad production WPS → 1 week after access

### 15.3 90-day Plan

**Days 1-30 (wire every demo to production):**
- Wire Chatter on 3 remaining detail screens
- Build `/admin/system-health` + `/admin/tenants` screens
- Notification preferences screen + `/api/v1/notifications/preferences` backend
- Mobile responsive audit: run `/sprint44-operations` breakpoint tool against every screen, fix overflows
- Deploy `PROACTIVE_AI_ENABLED=true` on staging, monitor scan findings

**Days 31-60 (external integrations — choose 2):**
- WhatsApp Business Cloud API (highest ROI for MENA)
- Unifonic SMS (OTP + invoice links)
  OR
- HyperPay (Mada + Apple Pay in one)
- Claude Vision on real bank statements (1 pilot bank)

**Days 61-90 (differentiation):**
- Client Portal (separate Flutter app, shared backend)
- Developer docs site (`docs.apex.sa` via Docusaurus)
- iOS + Android TestFlight/Play internal tracks
- Load test against real Postgres with 10k tenants

---

<a name="16-organizational-playbook"></a>
## 16. Organizational Playbook

### 16.1 Team Structure (recommended for next 12 months)

| Function | Headcount | Priority hires |
|----------|-----------|----------------|
| Flutter engineers | 3 | senior with Arabic UX experience |
| Python backend | 2 | one with compliance/crypto (ZATCA) background |
| Full-stack lead | 1 | |
| Product / design | 1 | Arabic-first designer |
| AI / ML | 1 | Claude + pgvector experience |
| QA / Test automation | 1 | pytest + Flutter integration tests |
| DevOps | 0.5 | Render + Postgres + Redis |
| Accounting SME | 0.5 | SOCPA / ACCA certified |
| Sales / Partnerships | 1 | MENA SMB network |
| Support | 1 | Arabic native |

### 16.2 Development Workflow

1. **Feature kick-off**
   - Pick task from Roadmap
   - Open PR from `feature/<name>` off `main`
   - Fill the ADR template in `docs/adr/`

2. **Implementation**
   - Write failing test first
   - Implement against `apex-*` shared widgets — never reinvent
   - `flutter analyze` + `pytest -q` must pass locally

3. **Review**
   - Two reviewers required — one engineering, one design
   - Accessibility check mandatory (`/sprint43-platform` a11y audit)
   - Arabic RTL check on every new screen

4. **Ship**
   - Conventional-commit PR title
   - CI must pass (pytest + flutter test + flutter analyze)
   - Auto-deploy to staging on merge to `main`
   - Smoke test on staging before production promotion

5. **Monitor**
   - Latency benchmark (`test_api_latency_bench.py`) runs nightly
   - Alert on p50 regression > 2×
   - Weekly load test vs baseline

### 16.3 Release Cadence

- **Flutter web:** continuous deploy (every merge to `main`)
- **Mobile (iOS + Android):** weekly TestFlight / Play internal build
- **Database migrations:** applied on startup via `RUN_MIGRATIONS_ON_STARTUP=true`
- **Major version:** every 6 weeks, with customer-facing changelog (`/whats-new`)

### 16.4 Support Tiers

| Plan | Channels | SLA |
|------|----------|-----|
| Free | In-app chat (AI first) | Best-effort |
| Pro | Chat + email | 4 h business hours |
| Business | Chat + email + phone | 1 h 24×7 |
| Enterprise | Dedicated CSM + Slack | 15 min 24×7 |

---

## 📎 Appendix

### A. File-to-Feature Index (selected)

| File | Purpose | Source inspiration |
|------|---------|---------------------|
| `apex_finance/lib/core/apex_sticky_toolbar.dart` | Page header w/ global bell | Odoo sticky status bar |
| `apex_finance/lib/core/apex_data_table.dart` | Default list widget | Linear dense tables |
| `apex_finance/lib/core/apex_syncfusion_grid.dart` | Virtual-scroll grid | Syncfusion |
| `apex_finance/lib/core/apex_command_palette.dart` | Ctrl+K launcher | Linear / Raycast |
| `apex_finance/lib/core/apex_chatter*.dart` | Per-record discussion | Odoo Chatter |
| `apex_finance/lib/core/apex_flexible_columns.dart` | 3-pane list→detail→sub | SAP Fiori FCL |
| `apex_finance/lib/core/apex_dashboard_builder.dart` | Composable blocks | Notion / SAP |
| `apex_finance/lib/core/apex_theme_generator.dart` | 3-variable palette | Linear March 2026 |
| `apex_finance/lib/core/apex_workflow_rules.dart` | Automation rules UI | Odoo Automation |
| `apex_finance/lib/core/apex_ws_client.dart` | Realtime singleton | Mercury real-time |
| `app/core/activity_log.py` | ActivityLog + 4 endpoints | Odoo OWL chatter |
| `app/core/auto_log.py` | SQLAlchemy status listener | — (APEX original) |
| `app/core/zatca_submit_e2e.py` | Full submit pipeline | ZATCA Phase 2 v2.5 |
| `app/core/system_health.py` | 6-subsystem aggregator | Vercel / Render ops |
| `app/ai/proactive.py` + `scheduler.py` | 6-hourly AI scans | Ramp Spend Intelligence |
| `app/integrations/zatca/invoice_pdf.py` | Printable invoice + QR | ZATCA spec |

### B. Environment Variables

Complete list, grouped by subsystem. See `app/main.py::_validate_env` for production requirements.

**Core**
- `ENVIRONMENT` — `development` / `production`
- `JWT_SECRET` — ≥ 32 chars in prod
- `ADMIN_SECRET` — not the dev default in prod
- `CORS_ORIGINS` — explicit allowlist in prod
- `DATABASE_URL` — required in prod

**Backends**
- `EMAIL_BACKEND` = `console` / `smtp` / `sendgrid`
- `PAYMENT_BACKEND` = `mock` / `stripe`
- `STORAGE_BACKEND` = `local` / `s3`
- `SMS_BACKEND` = `console` / `unifonic` / `twilio` (when implemented)

**AI**
- `ANTHROPIC_API_KEY` — Copilot + proactive scans
- `PROACTIVE_AI_ENABLED` — `true` to arm the scheduler
- `AI_SCAN_INTERVAL_SECONDS` — default 21600 (6 h)
- `AI_SCAN_WARMUP_SECONDS` — default 60

**ZATCA**
- `ZATCA_MODE` — `sandbox` / `production`
- `ZATCA_CSID` — certificate subject ID
- `ZATCA_CERT_PATH` — PEM path

**Realtime**
- `REDIS_URL` — for rate limit backend in prod
- `WS_JWT_SECRET` — same as JWT_SECRET by default

**Migrations**
- `RUN_MIGRATIONS_ON_STARTUP` — `true` in prod

### C. Test Matrix

| Suite | Files | Tests | Purpose |
|-------|-------|------:|---------|
| Core integration | `test_integration_v10.py` + peers | 93 | Response shape, CORS, auth |
| HR / Payroll | `test_hr_*.py` | 41 | GOSI, WPS, EOSB, leaves |
| ZATCA | `test_zatca.py` + `test_zatca_submit_e2e.py` + `test_offline_sync_zatca_retry.py` | 25 | Full pipeline |
| Activity / Chatter | `test_activity_log_autolog.py` + `test_activity_ws_push.py` + `test_notifications_api.py` | 17 | Live loop |
| AI | `test_ai_proactive.py` + `test_ai_scheduler.py` + `test_copilot_new_tools.py` | 22 | Scans + tools |
| Tenant | `test_tenant_branding_roundtrip.py` + `test_alembic_q1_infra_migration.py` + `test_rls_session_hook.py` | 13 | Isolation + migrations |
| Reports | `test_reports_download.py` + `test_invoice_pdf.py` + `test_system_health.py` | 23 | File + admin endpoints |
| Foundation | `test_foundation_fixes.py` | 15 | Rate limit + env + social auth |
| Performance | `test_api_latency_bench.py` | 6 | Hot-path p50 |
| Load | `tests/load/locustfile.py` | 3 user classes | Opt-in production load |

**Total passing: 1,200+.**

---

**This is the blueprint. Every decision is in here. If it's not in here, it's not a decision yet.**

**Next action:** pick the 3-5 items from § 15.3 that match the next sprint's capacity, break them into PRs, ship.

*End of APEX Unified Blueprint V3.*
