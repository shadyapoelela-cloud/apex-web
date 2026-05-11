# G-POS-SESSION-HARDENING (2026-05-11)

## Background

Post-go-live carry-forward from the 4-tester Finance Module final
audit. Three small hardening items that the testers flagged as
acceptable to ship but worth closing before the next sprint:

1. Cashier-vs-session attribution gap in `POST /pilot/pos-transactions`.
2. Race window in the frontend `_ensureOpenSession` helper (two
   concurrent cashiers could both open a session for the same branch).
3. Duplicate `GoRoute` registration for `/onboarding/wizard` in the
   Flutter router — second registration was dead code under
   go-router's first-match semantics.

All three are hardening, not feature work. None of them change a
user-visible flow on the happy path.

## The three fixes

### Fix #1 — cashier == session-owner check (most defensible)

**File**: `app/pilot/routes/pos_routes.py` (function `create_transaction`).

The docstring above the function already claimed step 1 of the
atomic flow was "Lock الوردية (مفتوحة + من نفس الكاشير مفروضاً)" —
the open-session check was enforced, but the same-cashier predicate
was not. Pre-fix, cashier B could log a sale on cashier A's open
shift. GL stayed correct (session → branch → tenant chain unchanged)
but the Z-Report attributed the receipt to cashier B while the
opening/closing balances and audit trail still pointed at cashier A.

**Why 403**: this is an authorization concern, not a validation
concern (the body parses fine — 400 is wrong) and not a state
conflict (the session is in the right state — 409 is wrong). The
Arabic error message names both the requesting cashier and the
session owner so the cashier in front of the terminal sees the
exact correction needed.

### Fix #2 — partial unique index on open sessions (race close)

**File**: `alembic/versions/l5b8c1f4a3e7_pos_session_open_unique.py`.

The frontend `_ensureOpenSession` is a list-then-create flow:

1. `GET /pilot/pos-sessions?status=open&branch_id=...`
2. If empty → `POST /pilot/pos-sessions` to create a new one.

Two cashiers checking in at the same branch within the same window
both see step 1 return empty and both proceed to step 2. Pre-fix,
the database accepted both inserts and the branch ended up with
two `status=open` sessions.

The fix is a DB-layer partial unique index on
`pilot_pos_sessions(branch_id) WHERE status='open'`. The race-loser
cashier now sees a 409 from the create call. The existing frontend
retry path (re-list, re-fetch the now-existing session) handles
this transparently — **no frontend code change required**.

Both Postgres and SQLite (≥ 3.8.0) support the partial-index form
natively. The alembic migration uses `postgresql_where` +
`sqlite_where` so it emits the right SQL on either dialect, and
both upgrade/downgrade are wrapped in try/except so the
`create_all() → alembic-stamp` bootstrap path stays idempotent.

#### Migration caveat — staging deploy

The migration is **conservative**: it does NOT auto-close
historical duplicate-open sessions. If staging or any DB with
prior data already has two or more `status='open'` rows for the
same `branch_id`, `CREATE UNIQUE INDEX` will fail with a
constraint violation.

Before applying on staging, close any orphaned duplicates:

```sql
-- Check first
SELECT branch_id, COUNT(*)
  FROM pilot_pos_sessions
 WHERE status = 'open'
 GROUP BY branch_id
HAVING COUNT(*) > 1;

-- Close the older duplicates, keep the newest per branch
UPDATE pilot_pos_sessions
   SET status = 'closed',
       closed_at = NOW()
 WHERE status = 'open'
   AND branch_id IN (
     SELECT branch_id FROM pilot_pos_sessions
      WHERE status = 'open'
      GROUP BY branch_id HAVING COUNT(*) > 1
   )
   AND id NOT IN (
     SELECT MAX(id) FROM pilot_pos_sessions
      WHERE status = 'open'
      GROUP BY branch_id
   );
```

Production: no historical data, so this clean-up is not required.

### Fix #3 — router dedup (trivial)

**File**: `apex_finance/lib/core/router.dart`.

`GoRoute(path: '/onboarding/wizard', ...)` was registered TWICE
(line ~572 and line ~969). Both redirected to the same target
(`/app/erp/finance/onboarding`) — go-router's first-match
semantics meant the second registration was unreachable dead code.

The first registration (line ~572) is kept and now carries a
breadcrumb comment pointing back to this hardening pass; the
second was deleted with an inline note at the deletion site.

## UAT steps

### Scenario 1 — cashier A logs sale on cashier A's session (happy path)

1. Cashier A opens a POS session at branch X.
2. Cashier A scans an item and submits the transaction.
3. **Expected**: 201 Created, receipt prints, Z-Report attributes
   the sale to cashier A.

### Scenario 2 — cashier B attempts to log sale on cashier A's session (the fix)

1. Cashier A's session at branch X is still open from Scenario 1.
2. Cashier B logs into a second terminal at branch X.
3. Cashier B's frontend picks up cashier A's open session (because
   it's the only open session for the branch — frontend behavior
   pre-fix as well).
4. Cashier B scans an item and submits.
5. **Expected**: 403 with the Arabic error message
   `الكاشير {B} غير مُخوَّل للوردية {code} (مفتوحة بواسطة {A})`.

### Scenario 3 — cashier B opens own session, then logs sale (recovery path)

1. After Scenario 2, cashier B explicitly opens a fresh session
   (the DB partial-unique index requires cashier A's session to
   be closed first — UI prompts cashier A or the manager to close
   it).
2. Cashier A's session is closed via the close-shift flow.
3. Cashier B's `_ensureOpenSession` now succeeds and opens
   cashier B's own session.
4. Cashier B submits a sale.
5. **Expected**: 201 Created, Z-Report attributes correctly to
   cashier B.

### Scenario 4 — race (two cashiers, same branch, simultaneous open)

1. Cashier A and cashier B both load the POS quick-sale screen at
   branch X within ~200ms of each other.
2. Both `_ensureOpenSession` flows fire: both see zero open
   sessions (`GET ?status=open&branch=X` returns []) and both
   issue `POST /pilot/pos-sessions`.
3. **Expected**: ONE create succeeds (201). The other gets a 409
   from the partial unique index. The frontend retry path on the
   loser re-fetches and lands on the winner's session. Eventually
   one of the two cashiers will be prompted to take over OR the
   manager closes one and re-opens for the other.
4. Verify in DB: `SELECT COUNT(*) FROM pilot_pos_sessions WHERE
   branch_id = 'X' AND status='open'` returns exactly 1.

## Rollback plan

All three fixes are independently revertible.

### Fix #1 (cashier check)

Revert the diff in `app/pilot/routes/pos_routes.py`. Removing the
new `if payload.cashier_user_id != session.opened_by_user_id`
block restores the pre-fix behavior. No data migration needed.

### Fix #2 (partial unique index)

```bash
alembic downgrade k9a1b3d5e7f2
```

The `downgrade()` step drops the index. Wrapped in try/except so
it's safe to re-run on a DB that's already at the down-revision.

### Fix #3 (router dedup)

Re-add the second `GoRoute(path: '/onboarding/wizard', ...)` block
in `router.dart`. No behavior change either way — the second
registration was dead code.

## Tests

`apex_finance/test/screens/pos_session_hardening_test.dart` — 9
source-grep contracts covering:

- Backend cashier-vs-session check exists and raises 403.
- Check is positioned after `_open_session_or_409` (needs the
  session row).
- Migration file exists with the correct revision chain
  (`l5b8c1f4a3e7` → `k9a1b3d5e7f2`).
- Migration uses `postgresql_where` + `sqlite_where` (partial
  index, not full unique).
- Migration is idempotent on both upgrade and downgrade.
- Migration keys on `pilot_pos_sessions(branch_id)` (per-branch,
  not per-tenant) with `unique=True`.
- `/onboarding/wizard` registered exactly once in `router.dart`.
- Sanity: `pos_v2_hotfix_test.dart` still present.

All assertions use `RegExp` with `[\s\S]` for CRLF/LF safety on
Windows checkouts.

## Out of scope

- `_ensureOpenSession` retry logic on the frontend — the DB-level
  partial unique index is sufficient. The existing 409-retry path
  already handles the race-loser.
- The cashier-vs-session check is **NOT** extended to existing
  payment endpoints in this PR. That's a separate audit item.
- No sales/purchase screen touches. No payment modal touches.
