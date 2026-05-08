# Trial Balance — Real-Data Audit (G-TB-REAL-DATA-AUDIT)

**Date:** 2026-05-08
**Owner:** Backend + Frontend (single PR)
**Branch:** `feat/g-tb-real-data-audit`
**Issue closed:** UAT follow-up to G-TB-DISPLAY-1 — "هل ميزان المراجعة فعلاً يقرأ بيانات حقيقية؟"

---

## TL;DR

After G-TB-DISPLAY-1 wired the dedicated TB screen (PR #173), the open
question was: does the TB pipeline pull *real* posted journal entries
end-to-end, or are mocks/sentinels involved?

This audit walked the full data path — frontend widget → ApiService →
FastAPI route → SQLAlchemy query → Postgres / SQLite — and found:

1. **No mocks anywhere.** `compute_trial_balance` reads directly from
   `pilot_gl_postings` (the immutable GL ledger). No stubs, no
   in-memory fixtures, no hardcoded sentinels. Drafts (which only have
   `pilot_journal_lines` rows, no `pilot_gl_postings`) correctly never
   appear in TB output.
2. **One critical security bug.** `_entity_or_404` in
   `app/pilot/routes/gl_routes.py` checked only `Entity.id == eid` —
   any authenticated user could pull *any* entity's TB by guessing the
   id. Pilot models do **not** inherit from `TenantMixin`, so the
   global `attach_tenant_guard` doesn't apply to them. This PR closes
   that gap with an explicit `current_user.tenant_id`-vs-`Entity.tenant_id`
   comparison + `403 Forbidden` for cross-tenant probes. 11 backend
   tests pin this down (5 isolation + 5 real-data + 1 schema sanity).
3. **One UX gap.** With real data flowing, the user has no way to tell
   whether the screen shows fresh values or a cached pre-deploy
   response. Two indicators added: a header timestamp ("آخر تحديث:
   HH:MM:SS") and a footer line ("المصدر: pilot_journal_lines — N قيد
   مرحّل") backed by a new `posted_je_count` field on the response.

---

## Layer-by-layer walk

### Layer 1 — Frontend widget (`trial_balance_screen.dart`)

The widget calls `ApiService.get('/pilot/entities/$entityId/reports/trial-balance?...')`
with `as_of` and `include_zero` query params, then maps the response
`rows[]` straight into `DataTable` rows. No mock branch, no
"if running locally use stub" fallback. The `_data` Map is populated
exactly once per fetch — there is no in-memory enrichment.

Verified:
- `grep -n "mock\|stub\|fake\|hardcoded" apex_finance/lib/screens/finance/trial_balance_screen.dart`
  → 0 hits.
- `_loadData()` only writes to state from the HTTP response body.

### Layer 2 — Transport (`ApiService`)

Standard authed JSON GET. `Authorization: Bearer <S.token>` header.
Centralised in `apex_finance/lib/core/api_config.dart` + `api_service.dart`.
No mock interceptor.

### Layer 3 — Pydantic schema (`app/pilot/schemas/gl.py`)

`TrialBalanceResponse` is a flat passthrough — `entity_id`,
`as_of_date`, `rows[]`, `total_debit`, `total_credit`, `balanced`, plus
the new `posted_je_count: int = 0`. The `= 0` default keeps older
fixtures + tests valid; backend always sets it explicitly.

### Layer 4 — Route handler (`app/pilot/routes/gl_routes.py`)

```python
@router.get("/entities/{entity_id}/reports/trial-balance",
            response_model=TrialBalanceResponse)
def trial_balance(entity_id, as_of, include_zero, db,
                  current_user: dict = Depends(get_current_user)):
    _entity_or_404(db, entity_id, current_user=current_user)  # ← tenant gate
    rows = compute_trial_balance(db, entity_id=entity_id, as_of_date=as_of_date,
                                 include_zero=include_zero)
    total_debit  = sum(Decimal(str(r["total_debit"]))  for r in rows)
    total_credit = sum(Decimal(str(r["total_credit"])) for r in rows)
    posted_je_count = (
        db.query(JournalEntry)
          .filter(JournalEntry.entity_id == entity_id,
                  JournalEntry.status == JournalEntryStatus.posted.value,
                  JournalEntry.je_date <= as_of_date)
          .count()
    )
    return TrialBalanceResponse(...)
```

The handler does **two** queries: one aggregation against
`pilot_gl_postings` (via `compute_trial_balance`) and one count against
`pilot_journal_entries` for the footer indicator. Both filter by the
authoritative `entity_id` from the URL — never from the JWT or
request body — and the entity is itself tenant-checked before either
query runs.

### Layer 5 — SQL (`compute_trial_balance` in `gl_engine.py:720`)

Single GROUP BY over `pilot_gl_postings`:

```python
db.query(
    GLPosting.account_id,
    func.sum(GLPosting.debit_amount).label("total_debit"),
    func.sum(GLPosting.credit_amount).label("total_credit"),
).filter(
    GLPosting.entity_id == entity_id,
    GLPosting.posting_date <= as_of_date,
).group_by(GLPosting.account_id).all()
```

`pilot_gl_postings` is the immutable GL ledger — it's only written by
`post_journal_entry` (the production posting service) when a JE
transitions to `status='posted'`. **A `draft` JE has rows in
`pilot_journal_lines` but zero rows in `pilot_gl_postings`** — confirmed
by `tests/test_tb_real_data_flow.py::test_draft_je_does_not_appear_in_tb`.

The query then joins each posting account against `pilot_gl_accounts`
and computes the natural balance per `normal_balance`. There is no
sentinel data — empty entities return `[]`.

### Layer 6 — Cross-tenant isolation ⚠️ **bug closed in this PR**

**Pre-PR contract:** `_entity_or_404(db, eid)` ran one query —
`SELECT * FROM pilot_entities WHERE id=:eid AND is_deleted=False`. If
the row existed, the request proceeded. **No tenant check.**

**Why the global guard didn't catch it:** `attach_tenant_guard`
(`app/core/tenant_guard.py`) installs a SQLAlchemy `before_compile`
hook that injects `WHERE tenant_id=:current_tenant` for any model
inheriting from `TenantMixin`. Pilot models (`Entity`, `JournalEntry`,
`GLPosting`, `GLAccount`, …) **do not inherit `TenantMixin`** — they
declare `tenant_id` as a plain `Column(String(36))`. So the global
guard silently skipped them.

**Post-PR contract:**

```python
def _entity_or_404(db, eid, *, current_user=None):
    e = db.query(Entity).filter(Entity.id == eid,
                                Entity.is_deleted == False).first()
    if not e:
        raise HTTPException(404, f"Entity {eid} not found")
    if current_user is not None:
        user_tenant = current_user.get("tenant_id") or current_user.get("tid")
        if not user_tenant or str(e.tenant_id) != str(user_tenant):
            raise HTTPException(403,
                "Access denied — entity belongs to a different tenant")
    return e
```

Choice notes:
- **403, not 404, on cross-tenant.** The 404 path is reserved for
  genuinely missing ids so an attacker cannot probe entity-id existence
  by reading status codes (test:
  `test_404_for_genuinely_missing_entity_no_info_leak`).
- **Optional `current_user` keyword arg.** Lets the same helper still
  serve internal call-sites that don't hold a JWT (e.g., reports that
  haven't been hardened yet — see "Out of scope" below).
- **`tenant_id` *or* `tid` claim.** Production tokens (post PR #169 /
  ERR-2 Phase 3) carry both; older tokens may carry only one. Missing
  both → 403 with same message.

---

## Tests added — `tests/test_tb_real_data_flow.py`

11 cases. **All pass.** Backend regression sweep across TB + reports
+ COA + dimensions: **62 / 62 pass.**

| Class | Test | Asserts |
|---|---|---|
| `TestCrossTenantIsolation` | `test_user_a_cannot_read_user_b_entity_tb` | user A token + entity B id → 403 + "different tenant" in body |
| `TestCrossTenantIsolation` | `test_user_a_can_read_user_a_entity_tb` | symmetric — own tenant → 200 + empty rows |
| `TestCrossTenantIsolation` | `test_token_without_tenant_claim_is_forbidden` | legacy JWT (no `tenant_id`) → 403, not silent leak |
| `TestCrossTenantIsolation` | `test_404_for_genuinely_missing_entity_no_info_leak` | random id → 404 (not 403) — status code carries no existence signal |
| `TestCrossTenantIsolation` | `test_user_b_can_read_user_b_entity_tb` | symmetric to test 1 — no over-correction blocked legitimate path |
| `TestRealDataFlow` | `test_empty_entity_returns_empty_rows_and_zero_count` | new entity → `rows=[]`, `total_debit=0`, `total_credit=0`, `balanced=true`, `posted_je_count=0` |
| `TestRealDataFlow` | `test_posted_je_appears_in_tb_with_correct_totals` | post 1 JE (1000 dr/cr) → 2 rows {1101, 4101}, totals 1000/1000, `posted_je_count=1` |
| `TestRealDataFlow` | `test_draft_je_does_not_appear_in_tb` | draft (no GLPosting) → `rows=[]`, `posted_je_count=0` |
| `TestRealDataFlow` | `test_posted_je_count_is_count_of_posted_only` | 2 posted + 1 draft → `posted_je_count=2`, totals = posted only |
| `TestRealDataFlow` | `test_as_of_date_filters_je_count` | yesterday + tomorrow JEs, `as_of=today` → only yesterday counts |
| `TestResponseShape` | `test_response_carries_posted_je_count_field` | field present, type `int` |

Fixture choices:
- `_mk_posted_je` inserts `GLPosting` rows directly rather than calling
  `post_journal_entry()`. The full posting service requires
  `journal_entry_sequence` rows + period stat updates + auth side-
  effects unrelated to this audit. Direct inserts mirror the database
  state the production path produces, which is what TB reads.
- `_user_token` uses the same `create_access_token(..., tenant_id=…)`
  pattern as ERR-2 Phase 3 + G-DEMO-DATA-SEEDER tests, so JWTs carry
  the same `tenant_id` claim as production post-PR #169.

---

## Frontend changes — `trial_balance_screen.dart`

Two thin additions, no logic refactor:

1. **`_lastFetchedAt: DateTime?`** state, set to `DateTime.now()` after
   each successful fetch. Header renders
   `"آخر تحديث: HH:MM:SS"` next to the refresh button when non-null.

2. **Footer source line** under the totals row:
   ```
   المصدر: pilot_journal_lines — 12 قيد مرحّل
   ```
   Backed by the new `posted_je_count` field. If the field is absent
   (e.g., backend not yet deployed), the footer shows an em-dash
   (`— قيد مرحّل`) instead of the misleading `0 قيد مرحّل`.

`flutter analyze --no-fatal-infos` → **0 issues.** Existing TB widget
contract tests (chip declaration, wired-screens registration, pin
route, pin contract) — all 6 pass. Full Flutter regression sweep
(routing + auth + TB) — **35 / 35 pass.** `flutter build web --release`
succeeds.

---

## Manual verification path

Follow [TB_REAL_DATA_UAT_SCRIPT.md](TB_REAL_DATA_UAT_SCRIPT.md) for the
end-to-end clickthrough. Summary:

1. Login as registered user (post-PR #169 token with `tenant_id`).
2. Open `/app/erp/finance/je-builder` → create + post a balanced JE.
3. Open `/app/erp/finance/trial-balance`.
4. Expect the JE's debit + credit to appear, totals balanced,
   `posted_je_count >= 1` in the footer.
5. Edit a draft JE (don't post) → refresh TB. Numbers don't change.

Cross-tenant smoke (curl):
```bash
TOKEN_A=...   # JWT for tenant A
ENTITY_B=...  # entity belonging to tenant B
curl -H "Authorization: Bearer $TOKEN_A" \
     "$API_BASE/pilot/entities/$ENTITY_B/reports/trial-balance"
# Expected: HTTP 403 + {"detail":"Access denied — entity belongs to a different tenant"}
```

---

## Out of scope (follow-ups)

The following pilot report endpoints in `gl_routes.py` still call
`_entity_or_404(db, entity_id)` *without* `current_user` and so retain
the pre-PR (cross-tenant readable) contract. Each is a near-trivial
follow-up that mirrors the TB fix; bundling here would have made the
PR harder to review and the test split unclear.

| Route | Function | Risk |
|---|---|---|
| `/entities/{id}/reports/income-statement` | `income_statement` | Read |
| `/entities/{id}/reports/balance-sheet` | `balance_sheet` | Read |
| `/entities/{id}/reports/cash-flow` | `cash_flow` | Read |
| `/entities/{id}/reports/comparative` | `comparative_report` | Read |

Recommended ticket: **G-PILOT-REPORTS-TENANT-AUDIT** — sweep all
`_entity_or_404(db, entity_id)` call-sites and pass `current_user` +
add cross-tenant 403 tests symmetrically. Same one-line fix per route.

Other deferred items:
- **Period-split TB** (`opening / period / closing` columns per
  account). Backend has snapshot semantics today; period split needs a
  `period_start` parameter + a different aggregation shape. Separate
  ticket.
- **Excel / PDF export** — placeholder SnackBars in the UI today
  ("قريبًا — تصدير Excel/PDF قيد التطوير"). Real export is a
  serializer + `printing`/`excel` package wiring task.
- **Hierarchical indenting by `GLAccount.level`** — the screen renders
  detail accounts flat in code order.

---

## Files touched

```
app/pilot/routes/gl_routes.py     +27 −7   tenant gate + posted_je_count
app/pilot/schemas/gl.py           +6 −0    posted_je_count: int = 0
apex_finance/lib/screens/finance/
  trial_balance_screen.dart       +44 −9   freshness badge + footer
tests/test_tb_real_data_flow.py   +332 −0  11 tests, 3 classes
docs/TB_DATA_FLOW_AUDIT_2026-05-08.md      this file
docs/TB_REAL_DATA_UAT_SCRIPT.md            manual UAT path
```

No alembic migrations. No `main.dart` edits. No schema-breaking
response field changes (default keeps older fixtures green).

---

## References

- G-TB-DISPLAY-1 (PR #173) — wired the dedicated TB screen this PR
  audits.
- ERR-2 Phase 3 (PR #169) — added `tenant_id` claim to JWTs.
- G-LEGACY-TENANT-MIGRATION (PR #170) — re-issued legacy tokens.
- G-DEMO-DATA-SEEDER (PR #171) — seeds the data UAT script reads.
- G-A3.1 (closed 2026-05-03) — alembic + `_MODEL_MODULES` discipline
  this PR did **not** need to touch.
