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

### PR #6 — Wave 4 (Full V4 Launchpad + Compliance Status screen)
Base: `claude/brave-yonath-wave-3` ← Head: `claude/brave-yonath-wave-4`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-3...claude/brave-yonath-wave-4?expand=1>

### PR #7 — Wave 5 (ZATCA offline retry queue — exponential backoff)
Base: `claude/brave-yonath-wave-4` ← Head: `claude/brave-yonath-wave-5`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-4...claude/brave-yonath-wave-5?expand=1>

### PR #8 — Wave 6 (ZATCA queue UI — stats strip + filterable list)
Base: `claude/brave-yonath-wave-5` ← Head: `claude/brave-yonath-wave-6`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-5...claude/brave-yonath-wave-6?expand=1>

### PR #9 — Wave 7 (Confidence-gated AI guardrails)
Base: `claude/brave-yonath-wave-6` ← Head: `claude/brave-yonath-wave-7`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-6...claude/brave-yonath-wave-7?expand=1>

### PR #10 — Wave 8 (AI Guardrails UI — wires Wave 7 backend)
Base: `claude/brave-yonath-wave-7` ← Head: `claude/brave-yonath-wave-8`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-7...claude/brave-yonath-wave-8?expand=1>

### PR #11 — Wave 9 (ZATCA queue background worker — closes Wave 5)
Base: `claude/brave-yonath-wave-8` ← Head: `claude/brave-yonath-wave-9`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-8...claude/brave-yonath-wave-9?expand=1>

### PR #12 — Wave 10 (fix Alembic multi-Base env.py — closes Wave 0 debt)
Base: `claude/brave-yonath-wave-9` ← Head: `claude/brave-yonath-wave-10`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-9...claude/brave-yonath-wave-10?expand=1>

### PR #13 — Wave 11 (ZATCA CSID lifecycle — encrypted keystore + expiry)
Base: `claude/brave-yonath-wave-10` ← Head: `claude/brave-yonath-wave-11`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-10...claude/brave-yonath-wave-11?expand=1>

### PR #14 — Wave 12 (CSID management UI — wires Wave 11 backend)
Base: `claude/brave-yonath-wave-11` ← Head: `claude/brave-yonath-wave-12`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-11...claude/brave-yonath-wave-12?expand=1>

### PR #19 — Wave 17 (Bank-rec gap fixes — approval reconciles, currency guard, idempotency, routing)
Base: `claude/brave-yonath-wave-16` ← Head: `claude/brave-yonath-wave-17`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-16...claude/brave-yonath-wave-17?expand=1>

```
Title: Wave 17: bank-rec gap fixes (approval reconciles, currency guard, idempotency, governance routing)

Body:
Four correctness gaps found during review of Waves 15 + 16, closed in
one focused PR. No new features.

Gap 1 — AI Oversight sub-module unreachable by URL (pre-existing from
Wave 8): `complianceGovernance.id='governance'` but every child
screen uses the `compliance-gov-*` id prefix. The V4 router builds
`{group}-{sub}-{slug}` from URL segments and matches against screen
ids, so the six Governance screens (Board Pack / Meetings / Minutes /
Resolutions / Policies / AI Oversight) were all dead links. The
Wave 16 UI deep-link into AI Oversight inherited the same broken
path.

Fix: rename the sub-module id from `governance` → `gov` in
v4_groups_data.dart. All six screens now resolve. Comment pins the
invariant so a future edit can't silently re-break it.

Gap 2 — Human approval didn't actually reconcile (Wave 15): the
generic `/ai/guardrails/{id}/approve` just flips the suggestion
status. For bank-rec suggestions it never called
`bank_feeds.mark_reconciled`, so an accountant approving a
NEEDS_APPROVAL row left the bank_tx unreconciled forever —
approval was cosmetic.

Fix: new `approve_and_reconcile(row_id, user_id)` in
bank_reconciliation.py that
  (a) reads the AiSuggestion row,
  (b) rejects non-bank-rec sources (ValueError → 400 on the route),
  (c) validates after_json shape (bank_tx_id + candidate_id present),
  (d) calls ai_guardrails.approve() then bank_feeds.mark_reconciled(),
  (e) surfaces partial-state (approved but not reconciled) as 502 so
      the operator sees it instead of silent desync.
Dedicated `POST /bank-rec/approve/{row_id}` route + matching
ApiService.bankRecApprove() on the client. The generic approval path
still works for anything else (COA, OCR, Copilot).

Gap 3 — Currency mismatch passed scoring (Wave 15): _amount_score
ignored currency, so 100 SAR vs 100 USD scored 1.0 on amount.

Fix: _amount_score now takes optional currency_a / currency_b and
returns 0.0 when both are provided AND differ (case-insensitive).
When either side omits currency, behaviour is unchanged — upstream
is assumed to have vetted it. score_pair + propose_matches propagate
the currency through from bank_tx / candidate dicts.

Gap 4 — auto-match was not idempotent (Wave 15): a second call on an
already-reconciled bank_tx (a) created a duplicate AiSuggestion row
and (b) overwrote the existing matched_entity_id — which may have
been a deliberate human pick.

Fix: new _already_reconciled() guard at the top of
auto_match_via_guardrail. When the bank_tx is already matched, the
function returns verdict="already_matched" WITHOUT creating a new
suggestion or calling mark_reconciled. The matched_entity_id stays
untouched.

Tests (14 new in tests/test_bank_reconciliation.py, bringing the
file to 44):
- Amount score: currency mismatch → 0; same-currency (case-
  insensitive) still scores 1.0; one-side-missing currency is not
  treated as mismatch.
- score_pair + propose: currency mismatch drops the total by the
  amount-weight share; same-currency candidate ranks first when both
  are provided.
- Idempotency: already-matched short-circuits with no new
  AiSuggestion; existing matched_entity_id is preserved.
- approve_and_reconcile: approves a needs_approval row and actually
  flips matched_entity_id/by on the bank_tx; unknown row raises
  LookupError; non-bank-rec source raises ValueError.
- Route: auth required, happy path returns 200 with reconciled=true,
  unknown row → 404, wrong source → 400.

Test suite: 1133 → 1147 pass (+14 new) · 2 skip · 0 fail.
Flutter: dart analyze clean on V4 surface; flutter build web
succeeds (36s).
```

### PR #18 — Wave 16 (AI bank reconciliation UI — wires Wave 15 backend)
Base: `claude/brave-yonath-wave-15` ← Head: `claude/brave-yonath-wave-16`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-15...claude/brave-yonath-wave-16?expand=1>

```
Title: Wave 16: AI bank reconciliation UI (wires Wave 15 backend)

Body:
Flutter UI completing Wave 15. Accountants pick an unreconciled bank
transaction, enter candidate entries, and either see a ranked proposal
list or route the top candidate through the Wave 7 AI guardrail in one
click. NEEDS_APPROVAL decisions deep-link into the existing AI
Oversight screen from Wave 8 — no new approval surface needed.

apex_finance/lib/screens/v4_erp/bank_reconciliation_screen.dart (new):
- Two-pane layout, responsive: side-by-side above 900px, stacked
  vertically below. Left pane is the unreconciled-txns list
  (auto-loaded from /bank-feeds/transactions?unreconciled_only=true),
  right pane is the candidate builder + results.
- Txn list: one row per unreconciled bank_tx with color ribbon
  (green credit ↓ / amber debit ↑), description + counterparty +
  date, amount right-aligned in monospace. Selected row gets a gold
  wash.
- Candidate builder: starts with one empty candidate; "+ مرشح جديد"
  appends more. Each candidate is a compact 5-field card (id /
  amount / date / vendor / description). Empty candidates are
  silently skipped on submit.
- Two actions: "اقترح مطابقات" POSTs /bank-rec/propose with
  min_score=0.0 so the UI can show every candidate with its score;
  "طابق تلقائياً" POSTs /bank-rec/auto-match with the real bank_tx_id
  so AUTO_APPLIED paths post the reconciliation in-band.
- Proposal cards: score badge (green ≥95 / gold ≥70 / amber ≥40 /
  red <40) plus per-feature chips (مبلغ/تاريخ/مورِّد/وصف) so the user
  can see *why* a proposal ranks where it does.
- Auto-match card: verdict pill (auto_applied green, needs_approval
  amber, rejected red), confidence % badge, the guardrail reason
  text straight from the backend, and — on needs_approval — a
  "راجعها في ضوابط الذكاء" chip that GOes to
  /app/compliance/gov/ai-oversight so the user lands on the pending
  row without leaving the flow.
- On auto_applied success the left pane reloads so the just-matched
  row disappears from the unreconciled list.

apex_finance/lib/api_service.dart: two new methods — bankRecPropose,
bankRecAutoMatch. Both are simple POST wrappers; the screen does all
the payload shaping so future callers (e.g. a "bulk auto-match"
command palette action) can reuse them unchanged.

apex_finance/lib/core/v4/v4_routes.dart._wiredScreens: registers
'erp-tre-rec' → BankReconciliationScreen. Sixth V4 screen wired to
real backend data after ERP Customers, Compliance Status, ZATCA
Queue, AI Guardrails, ZATCA CSID, Bank Feeds.

Verification: dart analyze clean, flutter build web succeeds (36s),
pytest unchanged at 1133 pass.
```

### PR #17 — Wave 15 (AI bank reconciliation — guardrail-gated auto-match)
Base: `main` ← Head: `claude/brave-yonath-wave-15`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/main...claude/brave-yonath-wave-15?expand=1>

```
Title: Wave 15: AI bank reconciliation — guardrail-gated auto-match

Body:
Closes the loop the Bank Feeds waves opened. Wave 13 ingested the
transactions; Wave 14 let a human reconcile them one-by-one in the
UI; Wave 15 scores every (bank_tx, candidate) pair and pushes the
top proposal through the Wave 7 AI guardrail so high-confidence
matches auto-post while weak ones land in the /ai/guardrails
needs_approval queue.

Two-layer design, same shape as Waves 5 / 7 / 11 / 13:

1. app/core/bank_reconciliation.py — pure scoring + guardrail bridge:
   - Weighted feature vector (sum = 1.0):
       _W_AMOUNT = 0.50   (exact-amount match dominates)
       _W_DATE   = 0.25   (linear decay across a 7-day default window)
       _W_VENDOR = 0.20   (Arabic-folded Jaccard on tokens)
       _W_DESC   = 0.05   (token Jaccard, tiebreaker only)
     Weights are asserted at import so a future edit can't silently
     drift. Amount score returns 0 on sign mismatch (a credit can't
     reconcile a debit).
   - propose_matches(bank_tx, candidates, *, date_window_days=7,
     min_score=0.3, top_k=5) → ranked proposals with a full score
     breakdown so the UI can render a "why this matched" tooltip.
   - auto_match_via_guardrail() pins min_score=0.0 inside the
     guardrail pipeline — otherwise a borderline 0.28 score would
     be silently dropped instead of being routed to needs_approval.
     Top candidate wraps into a Suggestion(source=
     "bank_reconciliation", action_type="match_bank_transaction")
     and goes through ai_guardrails.guard(). On AUTO_APPLIED with a
     real bank_tx_id the function calls bank_feeds.mark_reconciled
     (imported locally so the scoring math stays DB-free for unit
     tests and to avoid any future circular-import risk).
   - Vendor + description folding reuses the same NFKD +
     alef/yeh/teh-marbuta normalization as Wave 3 anomaly_detector.

2. app/core/bank_reconciliation_routes.py — two endpoints:
     POST /bank-rec/propose      — score only, no writes
     POST /bank-rec/auto-match   — score + guardrail; on AUTO_APPLIED
                                    the bank_feed_transaction row is
                                    marked reconciled in-band.
   Both require auth. Pydantic ReconTxn model mirrors
   BankFeedTransaction so the UI passes rows through without a
   translation layer.

Tests (30 new in tests/test_bank_reconciliation.py):
- Feature scorers: amount identity / linear decay / sign mismatch /
  missing fields; date same-day vs decay vs outside-window; vendor
  Arabic folding + token Jaccard; weights sum + ordering invariants.
- propose_matches: ranking, min_score filter, top_k cap, date decay.
- auto_match_via_guardrail: high-score → AUTO_APPLIED; low-score →
  NEEDS_APPROVAL; no candidates → REJECTED; destructive flag forces
  approval even at 100% confidence; AUTO_APPLIED path actually flips
  matched_entity_id/type on the BankFeedTransaction row.
- Routes: auth required; propose happy path; auto-match high-score
  full end-to-end; auto-match low-score routes to needs_approval.

Test suite: 1103 → 1133 pass (+30 new) · 2 skip · 0 fail.
```

### PR #15 — Wave 13 (Bank Feeds abstraction — Lean / Tarabut / Salt Edge)
Base: `claude/brave-yonath-wave-12` ← Head: `claude/brave-yonath-wave-13`
**Open**: <https://github.com/shadyapoelela-cloud/apex-web/compare/claude/brave-yonath-wave-12...claude/brave-yonath-wave-13?expand=1>

```
Title: Wave 13: Bank Feeds abstraction — provider-agnostic core + mock

Body:
Pattern #137 — SAMA Open Banking aggregation via Lean / Tarabut /
Salt Edge. The real differentiator over Qoyod / Wafeq, which still
require CSV upload.

Three layers mirroring Waves 5 / 7 / 11:

1. bank_feed_connection + bank_feed_transaction tables:
   tenant-scoped, unique on (tenant, provider, external_account_id)
   and (connection_id, external_id). Tokens are Fernet-encrypted;
   raw provider payloads preserved in raw_json for re-normalization.
   Reconciliation pointers (matched_entity_type/id, matched_at/by)
   set the table up for AI bank-rec in future waves.

2. bank_feeds.py — core:
   - Abstract BankFeedProvider with fetch_transactions(tokens,
     account, since). Concrete Lean/Tarabut/Salt Edge adapters will
     live outside this module so the core stays vendor-free.
   - MockBankFeedProvider registered at import: deterministic
     2-transaction fixture so the pipeline runs offline in dev/tests.
   - register_provider / get_provider / available_providers build a
     runtime adapter registry.
   - Lifecycle: connect / sync / disconnect / reconcile. Every
     transition audits through the Wave 1 hash chain. sync guards
     against duplicates via (connection_id, external_id); errors
     are isolated to the connection row.
   - BANK_FEEDS_ENCRYPTION_KEY env (prod-required; dev derives from
     JWT_SECRET with a warning — same pattern as TOTP + CSID).

3. bank_feeds_routes.py — 9 endpoints:
     POST  /bank-feeds/connections
     GET   /bank-feeds/connections
     GET   /bank-feeds/connections/{id}
     POST  /bank-feeds/connections/{id}/sync        (409 if wrong status)
     POST  /bank-feeds/connections/{id}/disconnect
     GET   /bank-feeds/transactions
     POST  /bank-feeds/transactions/{id}/reconcile
     GET   /bank-feeds/stats
     GET   /bank-feeds/providers
   Route invariant (enforced by tests): no endpoint returns the
   decrypted access/refresh tokens.

Tests (27 bank-feeds + 2 env):
- Encryption round-trip + ciphertext ≠ plaintext at rest.
- Unknown provider rejected; empty token rejected.
- sync idempotent (duplicates counted, not re-inserted).
- sync on disconnected row raises ValueError → 409 from route.
- provider-exception isolation: flips status=error + stores message.
- reconcile marks match + emits audit event.
- Route "grep plaintext in response" check passes.

Test suite: 1074 → 1103 pass (+29 new) · 2 skip · 0 fail.
```

---

```
Title: Wave 12: CSID management screen (wires Wave 11 backend)

Body:
Flutter UI completing Wave 11. Accountants see every Fatoora cert on
a single screen — color-coded by expiry, with a top banner when ≥1
cert is within 30 days of expiring.

zatca_csid_screen.dart:
- Expiry banner (amber) when ≥1 active cert ≤ 30 days from expiring,
  counting only actives so already-handled rows don't nag.
- 5 status chips (All / سارية / قيد التجديد / منتهية / ملغاة) with
  live counts + segmented env control (All / Sandbox / Production).
- CSID cards: subject + cert_serial monospace + expiry date + three
  badges (env / status / days-to-expiry). Days badge: red ≤7, amber
  ≤30, green otherwise.
- Inline revoke button on active/renewing rows with optional-Arabic-
  reason dialog wired to the backend rejection_reason field.
- Revoked rows display the rejection_reason inline in a red callout.
- "مسح المنتهية" admin button → sweep_expired after confirm. Safe:
  doesn't delete, only flips active→expired.
- All flows through ApexScreenHost: loading / empty-first-time (with
  an explanation of what CSID is) / empty-after-filter / error.

api_service.dart: six new client methods covering stats, list,
expiring-soon, detail, revoke, sweep-expired. Critically — NO method
returns decrypted cert/key material. The Wave 11 invariant is that
plaintext never leaves the server; this client preserves it.

v4_routes.dart._wiredScreens gains compliance-zatca-certs →
ZatcaCsidScreen. Fifth V4 screen wired to real backend data after
ERP Customers, Compliance Status, ZATCA Queue, AI Guardrails.

Verification: dart analyze clean, flutter build web succeeds (45s),
pytest unchanged at 1074 pass.
```

---

```
Title: Wave 11: ZATCA CSID lifecycle (encrypted keystore, expiry alerts, rotation)

Body:
Patterns #121 and #173 — CSID lifecycle UX and encrypted keystore
with 60/30/7-day alerts. Without this, an expired Fatoora cert
silently breaks every submission until someone notices.

Three layers mirroring Waves 5 / 7 / 9:

1. compliance_models.py: new `zatca_csid` table with
   cert_pem_encrypted, private_key_pem_encrypted, cert_serial,
   issued_at, expires_at, status (active/expired/revoked/renewing),
   compliance_csid, production_csid, revocation audit fields.
2. zatca_csid.py: Fernet-encrypted at rest. The only function that
   returns decrypted material is get_active_csid(tenant, env) —
   used by the submission pipeline; never by routes. register /
   list / stats / get_row return metadata projections with a
   denormalized days_to_expiry. expiring_soon(days) feeds the
   dashboard banner. sweep_expired() flips past-due active rows.
   Every transition emits an audit event through the Wave 1 hash
   chain (zatca.csid.register / expired / revoked / renewing).
3. zatca_csid_routes.py: 8 endpoints behind auth. Route-layer
   invariant enforced by tests: no endpoint returns plaintext.

env_validator.py: ZATCA_CERT_ENCRYPTION_KEY is required in
production, warned in dev (pattern matches TOTP_ENCRYPTION_KEY
from Wave 1 PR#4).

tests (31 CSID + 2 env-validator):
- Encryption round-trip preserves material.
- Ciphertext ≠ plaintext at rest.
- list/get_row never leak plaintext OR ciphertext fields.
- Lifecycle transitions + idempotency + cross-state guards.
- expiring_soon windowing + sweep_expired flipping.
- "grep plaintext" check on list endpoint response body.
- ZATCA_CERT_ENCRYPTION_KEY missing → prod error, dev warning.

Test suite: 1041 → 1074 pass (+33 new) · 2 skip · 0 fail.
```

---

```
Title: Wave 10: fix Alembic multi-Base env.py (closes Wave 0 debt)

Body:
Pays down the technical debt from STATE_OF_APEX §6a: the old env.py's
wildcard imports silently rebound `Base` to the Knowledge-Brain base,
so target_metadata saw 14 tables instead of 95. Any autogenerate run
would produce a migration that DROPS the users table + 94 others.

Root cause:
  from app.phase1.models.platform_models import Base
  from app.phase1.models.platform_models import *
  ... 18 wildcard imports ...
  from app.knowledge_brain.models.db_models import *  # shadows Base

Fix:
- Import each Base under a distinct alias (PhaseBase /
  KnowledgeBrainBase). Wildcard imports can no longer shadow.
- Replace wildcard side-effect imports with importlib.import_module()
  over an explicit module list. Same effect, obvious intent.
- target_metadata points at PhaseBase.metadata. KB runs against a
  SEPARATE engine (KB_DATABASE_URL) — including it would produce
  false drift. KB schema stays managed by create_all at startup.
- Confirmed working: after the fix, autogenerate against a
  create_all'd DB produces an EMPTY migration (zero drift),
  proving metadata and DB are in sync. The old version would have
  emitted ~1021 lines of incorrect drop_table ops.

tests/test_alembic_env_fix.py (5 tests) pins the invariant:
- target_metadata is PhaseBase.metadata (not KB.Base.metadata).
- Table count ≥ 80 — any regression to the wildcard shadow crashes
  this threshold immediately.
- Spot checks: users, user_sessions, audit_trail,
  zatca_submission_queue, ai_suggestion are all registered.
- KB tables are NOT in phase1 metadata (confirms separation).
- DB_URL re-exports correctly.

STATE_OF_APEX.md §6a is marked resolved with historical context
preserved for future archaeology.

Verification: 1036 → 1041 pass (+5 new) · 2 skip · 0 fail.
```

---

```
Title: Wave 9: ZATCA retry queue background worker (closes Wave 5)

Body:
Until now the Wave 5 retry queue only drained when someone hit the
dry-run endpoint. With this PR the queue processes itself on a
configurable interval — Wave 5 now stands alone.

zatca_queue_worker.py:
- ZatcaQueueWorker: asyncio task that calls process_due() every N
  seconds. Injectable submit_fn preserves Wave 5's rule that the queue
  module stays free of any HTTP client.
- Opt-in via ZATCA_WORKER_ENABLED; dev + test default OFF so imports
  never silently drain the queue. Interval and batch_limit configurable
  via env (clamped: interval ≥ 10s, batch ∈ [1, 500]).
- Graceful shutdown: stop() sets a stop-event AND cancels the task.
  The loop sleeps via wait_for(stop_event, timeout=interval) so
  shutdown is always bounded by cancellation, not by interval.
- default_noop_submit() drop-in until the real Fatoora HTTP client
  gets wired.

main.py lifespan:
- get_default_worker().start() on startup + stop() in finally block
  of the yield so service restarts never leave the worker dangling.

env_validator.py:
- Warns when ZATCA_WORKER_ENABLED is unset (same pattern as Wave 7
  for REDIS_URL / SENTRY_DSN), so operators see in the startup log
  that automatic queue processing is off.

tests/test_zatca_queue_worker.py: 17 tests —
- Flag semantics (disabled by default + 5 truthy values + constructor
  override).
- Interval + batch_limit clamping.
- run_once() invokes submit_fn per due row + tracks summary +
  iteration count + failure path rescheduling.
- start/stop lifecycle: disabled no-op, clean drain + stop, double-
  start no-op, stop-before-start no-op.
- default_noop_submit never raises, get_default_worker is stable.

Test suite: 1019 → 1036 pass (+17 new) · 2 skip · 0 fail.
```

---

```
Title: Wave 8: AI Guardrails Flutter UI (wires Wave 7 backend)

Body:
Controllers and accountants now have a single screen to review every
AI decision — pending approvals with inline approve/reject, auto-
applied rows ready for retroactive takedown, rejection trail for the
audit binder.

Files:
- ai_guardrails_screen.dart: 5 filter chips with live counts from
  /ai/guardrails/stats. Suggestion cards show source icon (Copilot /
  COA / OCR), action type, target id, Arabic reasoning, the gate_reason
  explainer, a confidence % badge (green ≥95%, amber 80-94%, red <80%),
  and a red "تدميري" pill when destructive=True so the reason for
  needing approval is visible at a glance. Needs-approval rows render
  inline موافقة/رفض buttons; reject opens an optional-Arabic-reason
  dialog wired to the backend rejection_reason column.
- api_service.dart: six new methods mirroring the Wave 7 routes.
- v4_groups_data.dart: adds "compliance-gov-ai-oversight" as an
  overflow entry under Compliance > Governance — AI policy enforcement
  lives with governance until the Settings → AI Agents gallery ships.
- v4_routes.dart: registers AiGuardrailsScreen under that id. Fourth
  V4 screen wired to real data (ERP Customers / Compliance Status /
  ZATCA Queue / AI Guardrails).

Verification: dart analyze clean, flutter build web succeeds (44s),
pytest unchanged at 1019 pass.
```

---

```
Title: Wave 7: confidence-gated AI guardrails (pattern #102)

Body:
Every AI-generated suggestion — Copilot, COA classifier, receipt OCR,
vendor matcher — now passes through a gate before it can write real
data. Closes the biggest risk of embedding AI deeper in the
accounting workflow: silent bad posting.

Rules:
- confidence < min_confidence (default 0.95) → needs_approval.
- destructive=True → needs_approval regardless of confidence.
- confidence outside [0, 1] → rejected outright (guards against
  model bugs returning sentinel values).
- min_confidence overridable per-suggestion so stricter pipelines
  (COA auto-posting) opt into 0.98 without changing the module.

Three layers:
1. ai_suggestion table with gate_reason, status, approval trail.
   Confidence stored as 0-1000 permille for deterministic equality.
2. ai_guardrails.py: pure Suggestion/GuardedDecision/Verdict types +
   guard/approve/reject/list_rows/stats. guard() writes the row and
   fires an audit event (ai.gate.auto_applied / needs_approval /
   rejected / approved / rejected_by_human) through the Wave 1 hash
   chain. The guardrail is ADVISORY — never touches domain tables.
3. /ai/guardrails routes: evaluate / list / stats / {id} / approve /
   reject. Approve on a terminal-non-approved row returns 409.

28 new tests. Pytest: 991 → 1019 pass · 2 skip · 0 fail.
```

---

```
Title: Wave 6: ZATCA retry queue Flutter UI (wires Wave 5 backend)

Body:
Flutter UI completing Wave 5. Accountants can now see which invoices
are stuck with ZATCA, why, and when the next retry fires — without
shelling into a Postgres console.

Files:
- zatca_queue_screen.dart — stats strip (5 filter chips: All,
  Pending, Cleared, Giveup, Draft — each with live count), color-
  ribbon list rows with invoice id + attempts badge + last-error or
  next-retry, and a detail drawer fetched from /zatca/queue/{id}.
  Every branch routes through ApexScreenHost (loading / empty-first-
  time with ladder explanation / empty-after-filter / error-with-
  retry) so conventions stay identical to the other V4 screens.
- api_service.dart — five client methods mirroring the Wave 5 routes
  (stats, list, detail, enqueue, process).
- v4_routes.dart._wiredScreens — "compliance-zatca-log" now points
  at ZatcaQueueScreen. Third V4 screen wired to real data after
  ERP Customers (Wave 2 PR#3) and Compliance Status (Wave 4 PR#2).

Verification: dart analyze clean, flutter build web succeeds (49s),
pytest unchanged at 991 pass.
```

---

```
Title: Wave 5: ZATCA offline retry queue (1m→5m→30m→2h→12h→24h→48h)

Body:
Makes APEX resilient to Fatoora outages — the single biggest
operational risk for a ZATCA-integrated product in MENA.

Design: 3 layers separated so nothing is coupled to the HTTP client.

1. compliance_models.py adds `zatca_submission_queue`:
   (tenant_id, invoice_id, payload, status, attempts, max_attempts,
   next_retry_at, last_error_code, last_error_message, cleared_uuid),
   indexed on (status, next_retry_at) for the hot due-query path.
2. zatca_retry_queue.py: pure functions over the ORM. enqueue(),
   due_for_retry(), record_success(), record_failure(), and a
   process_due(submit_fn) drain loop that lets the caller pass any
   submit function — so the module stays HTTP-free and tests run
   fully offline. Backoff ladder is 1m/5m/30m/2h/12h/24h/48h; the
   7th failure transitions to "giveup" requiring human action.
   Every state transition emits an audit-trail event via the hash
   chain from Wave 1 PR#6.
3. zatca_queue_routes.py: five endpoints — enqueue, list (with
   status/tenant filter), stats for KPI cards, detail drawer, and
   a DRY-RUN process endpoint. The real run is 501 from HTTP
   deliberately — the production worker imports process_due()
   directly with the real ZATCA client so the HTTP layer never
   accidentally hits Fatoora.

tests/test_zatca_retry_queue.py: 24 tests covering enqueue +
draft-vs-pending, backoff timing at 1m and 5m, giveup after
max_attempts, idempotent success, due_for_retry exclusion rules,
process_due drain + exception-as-failure, route auth + validation +
501 on non-dry-run.

Test suite: 967 → 991 pass (+24 new) · 2 skip · 0 fail.
```

---

```
Title: Wave 4: populate all 6 V4 groups + first Compliance screen

Body:
Brings the V4 Launchpad from "1 populated group + 5 coming-soon
placeholders" to all 6 groups fully enumerated per the V4 Module
Hierarchy Map, then wires the first non-ERP screen to prove the
registry pattern travels across groups.

- PR#1 v4_groups_data.dart: 454 lines of pure const data adding 35
  sub-modules × 5 visible tabs = 175 new V4Screen entries across
  Audit & Review, Feasibility Studies, External Financial Analysis,
  Service Providers, and Eligibility & Compliance. Total V4 screen
  registry grows 65 → 240. Every Launchpad card now drops into a
  real Sidebar + TabBar — no more "قريبًا" dialogs.
  Stable screen-id convention {group}-{sub}-{slug} is preserved so
  analytics keyed on those ids stay valid through any future
  reordering.
- PR#2 compliance_status_screen.dart: hero circular score gauge +
  responsive 3/2/1 grid of 6 KPI cards (ZATCA cert, wave, VAT return,
  GOSI submission, AML cases, invoice rejection rate). Data is
  placeholder until /compliance/status lands in a later backend wave;
  the layout won't need to change when it does.
- v4_routes.dart._wiredScreens adds compliance-dashboard-status →
  ComplianceStatusScreen. All other new sub-modules still render via
  the default "defined-but-not-implemented" host.

Verification: dart analyze clean, flutter build web succeeds (~56s),
pytest unchanged at 967 pass.
```

---

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
