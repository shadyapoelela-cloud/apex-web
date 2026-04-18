# Opening the 4 wave PRs

All 5 branches pushed to `origin` (shadyapoelela-cloud/apex-web).

## Option A — Click to open (fastest)

Open each URL and the compare page pre-fills everything. Copy the
title + body blocks below into the form.

### PR #1 — Wave 0 (Reality audit + docs)
Base: `main` ← Head: `claude/brave-yonath-wave-0`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/main...claude/brave-yonath-wave-0?expand=1>

```
Title: Wave 0: reality audit + archive aspirational V3 blueprint

Body:
Two-commit foundation PR. No code changes — only documentation
and an honest reality check that every later wave is built on.

Contents:
- STATE_OF_APEX.md: real counts for the codebase (99 Flutter routes,
  368 FastAPI endpoints, 842 tests pass, 1 Alembic migration) and a
  list of 40+ `apex_*.dart` widgets + 10 backend files that V3
  claimed but never built.
- blueprints/README.md orders the 4 canonical docs, archives V3 as
  historical context only, promotes Master Blueprint to primary.
- Alembic env.py multi-Base bug documented: `target_metadata` ends
  up pointing at KB.Base (14 tables) instead of the combined 72-
  table schema because wildcard imports overwrite `Base`. Any
  autogenerate run would drop the `users` table — fix deferred.

This PR ships no runtime change; it is the accuracy baseline
before Wave 1 security work lands.
```

### PR #2 — Wave 1 (Security hardening, 8 sub-PRs squashed)
Base: `claude/brave-yonath-wave-0` ← Head: `claude/brave-yonath-wave-1`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-0...claude/brave-yonath-wave-1?expand=1>

```
Title: Wave 1: close all 6 P0 security gaps from STATE_OF_APEX

Body:
Eight security commits closing every P0 gap the Wave 0 audit
surfaced. Each commit is self-contained so `git bisect` lands on
a single concern.

- PR#1 JWT ≥ 32-byte enforcement (+ 8 unit tests). Eliminates the
  ~850 InsecureKeyLengthWarning lines the test suite was emitting.
- PR#2 Google id_token verified against Google JWKS with
  GOOGLE_OAUTH_CLIENT_ID audience (+ 12 tests). Dev bypass logs a
  warning when the env var is unset; production refuses to boot.
- PR#3 Apple identity_token verified via PyJWKClient against Apple
  JWKS + APPLE_CLIENT_ID, with Hide-My-Email fallback (+ 3 tests).
- PR#4 Real RFC 6238 TOTP 2FA replacing the SMS stub. Fernet-
  encrypted secrets, 10 bcrypt-hashed recovery codes, /auth/totp/
  {setup,verify,disable,status} routes (+ 14 tests).
- PR#5 Redis-backed rate limiter with sorted-set sliding window and
  in-memory fallback when REDIS_URL is unreachable (+ 10 tests).
- PR#6 Auth routes emit audit events + tamper-evidence tests prove
  the existing hash chain catches mutations (+ 8 tests).
- PR#7 Sentry + python-json-logger bootstrap. Idempotent. Traces
  sample-rate defaults 0.05 in prod, 0.0 in dev, PII never sent
  (+ 8 tests).
- PR#8 Strict env validator: six new required-in-prod vars + CORS
  wildcard warning + unknown-ENVIRONMENT detection (+ 16 tests).

Test suite: 842 → 921 pass (+79 new) · 2 skip · 0 fail.
New deps: google-auth, pyotp, qrcode[pil], redis, sentry-sdk[fastapi],
python-json-logger, pyjwt[crypto].
```

### PR #3 — Wave 1.5 (V4 module-hierarchy shell)
Base: `claude/brave-yonath-wave-1` ← Head: `claude/brave-yonath-wave-1-5`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-1...claude/brave-yonath-wave-1-5?expand=1>

```
Title: Wave 1.5: V4 module-hierarchy shell (Launchpad → Sidebar → Tabs)

Body:
Implements the 3-level IA contract from the APEX V4 Module
Hierarchy Map:
  Level 1 → 6 module-group Launchpad cards
  Level 2 → per-group Sidebar (46 sub-modules planned; 11 wired in ERP)
  Level 3 → per-sub-module TabBar (≤5 visible) + "More ▾" overflow

Strangler pattern: new routes under /app/... coexist with the
existing 99 flat routes. Nothing is removed so users can opt into
V4 while legacy screens keep working.

Components (lib/core/v4/):
- v4_groups.dart — 454 lines of const data defining the group/
  sub-module/screen graph. ERP fully populated with 11 sub-modules;
  Sales & AR has 5 visible + 5 overflow entries. Other 5 groups
  are header-only with "قريبًا" until their dedicated waves.
- apex_screen_host.dart — five canonical states (loading, emptyFirst,
  emptyAfterFilter, error, unauthorized, ready). Every V4 screen
  wraps its body here so layout/typography/motion stay consistent.
- apex_launchpad.dart — responsive 3/2/1-wide grid, hover elevation
  + group-color glow, "قريبًا" dialog on empty groups.
- apex_tab_bar.dart — horizontal tabs + PopupMenu overflow with an
  active indicator on "More ▾" when the active screen lives in it.
- apex_sub_module_shell.dart — group ribbon + breadcrumb + 260px
  sidebar + content, collapses to Drawer below 900px.
- v4_routes.dart — /app/{group}/{sub}/{screen} with graceful
  redirects. Screen IDs stay stable ({group}-{sub}-{slug}) for
  telemetry even when tabs are pinned/reordered.

Verification: dart analyze v4/ clean, flutter build web succeeds,
pytest unchanged at 921 pass.
```

### PR #4 — Wave 2 (UX Quick Wins + first real V4 screen)
Base: `claude/brave-yonath-wave-1-5` ← Head: `claude/brave-yonath-wave-2`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-1-5...claude/brave-yonath-wave-2?expand=1>

### PR #5 — Wave 3 (Anomaly detector — 5 patterns + UI feed)
Base: `claude/brave-yonath-wave-2` ← Head: `claude/brave-yonath-wave-3`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-2...claude/brave-yonath-wave-3?expand=1>

```
Title: Wave 3: anomaly detector — duplicate payments, round numbers, off-hours, new vendor, spikes

Body:
Backend + UI for patterns #110 ("anomaly feed with $-impact") and
#111 ("duplicate payment detector") from APEX_GLOBAL_RESEARCH_210.

- PR#1 app/core/anomaly_detector.py: five pure-function detectors
  over caller-supplied dicts so the same code runs against the DB,
  CSV uploads, or OCR output with no adapter:
    1. Duplicate payments — fuzzy vendor (Arabic diacritic folding +
       alef/yeh/teh-marbuta variants) × amount ±0.01 × date window.
       3+ matches = high severity. Impact = (count-1) × amount.
    2. Round-number flags at 50k/10k/5k tiers with high/medium/low.
    3. Off-hours entries 22:00–06:00 local; ≥10k bumps to high.
    4. New vendor's first transaction ≥ 50k = high.
    5. Category spike vs prior-90-day baseline; 3× = medium, 5× = high.
  scan_all() runs every detector and sorts findings by severity desc
  then impact desc so the UI Anomaly Feed card leads with the worst.
- app/core/anomaly_routes.py + POST /anomalies/scan endpoint.
- tests/test_anomaly_detector.py: 25 tests covering positive +
  negative cases for each detector, Arabic vendor-name folding,
  coordinator ordering, route auth + integration.

- PR#2 apex_finance/lib/core/v4/apex_anomaly_feed.dart: ApexAnomalyFeed
  renders the findings as severity-ribbon cards with type-specific
  icons and a "لا شذوذ مكتشَف" empty-state. Optional onDrill callback
  surfaces the finding's transaction_ids so the parent screen can
  navigate to the transaction drawer.
- api_service.dart.scanAnomalies(transactions, {options}) → the
  endpoint. Options dict lets callers override thresholds inline.

Test suite: 942 → 967 pass (+25 new) · 2 skip · 0 fail.
```

---

```
Title: Wave 2: command palette + MENA localization + first wired screen

Body:
Five commits ticking off the highest-impact S-effort UX items from
APEX_GLOBAL_RESEARCH_210.

- PR#1 Command Palette (Ctrl+K) — pattern #141. Linear-style overlay,
  fuzzy Arabic-aware search (diacritic folding + alef/yeh/teh-marbuta
  normalization), bilingual haystack, session-scoped recents, keyboard
  nav (↑↓ Enter Esc), mounted at every V4 route + Launchpad.
- PR#2 Dual numerals + Hijri/Gregorian dates — patterns #134 + #203.
  ApexNumeralScope owns mode (western default for tabular figures),
  ApexNumeralToggleButton flips it. Storage stays ISO 8601 UTC
  Gregorian; Hijri is a display layer using the `hijri` package so
  no data migrations.
- PR#3 First wired V4 screen: ERP Sales Customers calls
  /api/v1/clients and renders via ApexScreenHost. Establishes the
  template every subsequent wired screen copies; new wiring is a
  one-line addition to the _wiredScreens registry in v4_routes.dart.
- PR#4 Arabic ZATCA rejection translator (backend) — pattern #184.
  Curated catalog of 14 BR-KSA-* codes + regex heuristic fallback.
  GET /zatca/errors/explain and POST /zatca/errors/translate
  endpoints + 21 tests covering all 3 payload shapes.
- PR#5 UI side: ApexZatcaErrorCard renders the bilingual card with
  a severity ribbon + "ما معنى هذا الرمز؟" explain popover that
  calls the backend endpoint.

Test suite: 921 → 942 pass (+21 new) · 2 skip · 0 fail.
New dep: hijri (pure Dart).
```

---

## Option B — `gh` CLI (after `gh auth login`)

```bash
gh auth login  # interactive — log in once, then:

gh pr create --base main \
  --head claude/brave-yonath-wave-0 \
  --title "Wave 0: reality audit + archive aspirational V3 blueprint" \
  --body-file <(sed -n '/^### PR #1/,/^### PR #2/p' PR_INSTRUCTIONS.md | sed -n '/^Body:$/,/^```$/p')

# Repeat with PR #2, #3, #4 using the appropriate --head/--base/--title.
```

---

## Stacked-PR etiquette note

Because the PRs are stacked (each targets the previous wave's branch,
not `main` directly), merge them **in order**:

1. Merge Wave 0 → main
2. Change Wave 1's base to `main` (GitHub does this automatically via
   "Update branch"), then merge → main
3. Repeat for Wave 1.5 and Wave 2

Each PR's diff stays focused on its own wave's changes throughout.
