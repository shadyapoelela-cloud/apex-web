# Trial Balance — Real-Data UAT Script

**Pairs with:** [TB_DATA_FLOW_AUDIT_2026-05-08.md](TB_DATA_FLOW_AUDIT_2026-05-08.md)
**Audience:** UAT operators verifying G-TB-REAL-DATA-AUDIT after deploy.
**Time:** ~10 minutes.

The goal is to confirm three claims end-to-end on a real (deployed)
backend + frontend pair:

1. The TB screen **reflects real ledger data** — values change when
   real journal entries get posted, and only then.
2. The **freshness badge + footer source** behave correctly — visible,
   accurate, and updated on each refresh.
3. **Cross-tenant access is rejected** — a token from tenant A cannot
   read tenant B's trial balance.

---

## Pre-flight

| Check | How |
|---|---|
| Backend deploy is live | `curl https://apex-api-ootk.onrender.com/health` → `{"ok": true}` |
| Frontend pages-deploy is live | Hard-refresh `https://shadyapoelela-cloud.github.io/apex_app/` + DevTools → Application → Service Workers → Unregister |
| Token carries `tenant_id` | DevTools → Application → Local Storage → `apex_token` → paste at jwt.io → check `payload.tenant_id` is a UUID |
| Demo data is seeded for the entity | Run G-DEMO-DATA-SEEDER (PR #171) for the entity before starting, or have a fresh entity with at least 5 posted JEs |

If `tenant_id` is missing from the token, log out + log back in. The
post-PR #169 login flow injects the claim. If still missing, run the
G-LEGACY-TENANT-MIGRATION endpoint (PR #170) to re-issue.

---

## Path A — Real-data flow

### A.1 Empty entity baseline

1. From the Quick Access bar at the top, click the **`tb` pin**
   (ميزان المراجعة).
2. **Expected URL:** `/app/erp/finance/trial-balance` (not `/statements`).
3. **Expected:** the screen header shows "ميزان المراجعة" + a
   refresh button + Excel + PDF buttons.
4. **Expected:** the freshness badge reads
   `آخر تحديث: HH:MM:SS` to the right of the refresh icon — within
   ~2 s of page load.
5. **If the entity has zero posted JEs:** rows table shows the
   "no rows" empty state. Footer line reads:
   `المصدر: pilot_journal_lines — — قيد مرحّل` (em-dash, not "0").

### A.2 Post a real JE

1. Open `/app/erp/finance/je-builder` (or click the empty-state
   "فتح قيود اليومية" CTA on the TB screen).
2. Create a balanced JE with 2 lines:
   - Line 1: account `1101` (نقدية) — debit `1000.00`
   - Line 2: account `4101` (إيرادات) — credit `1000.00`
3. Memo: `اختبار TB — UAT`. Save → submit → approve → **post**.
4. Confirm the JE status badge reads `posted` after the action.

### A.3 TB picks it up

1. Navigate back to `/app/erp/finance/trial-balance` and click the
   refresh icon.
2. **Expected:** freshness badge timestamp updates to "now".
3. **Expected rows:** the table shows two rows:
   - `1101 / نقدية / 1000.00 / 0.00 / 1000.00 / asset`
   - `4101 / إيرادات / 0.00 / 1000.00 / 1000.00 / revenue`
   (existing rows for any prior posted JEs are still there in
   addition.)
4. **Expected totals card:** total debit ≥ 1000, total credit ≥ 1000,
   balanced indicator green.
5. **Expected footer:** `المصدر: pilot_journal_lines — N قيد مرحّل`
   where `N` is the count of all posted JEs ≤ today for this entity.

### A.4 Drafts must NOT leak in

1. In `je-builder`, create another balanced JE with the same shape
   (`1102 dr 500 / 4102 cr 500`) but **leave it as `draft`** — do not
   submit/approve/post.
2. Refresh the TB screen.
3. **Expected:** rows for accounts `1102` / `4102` do **not** appear.
   `posted_je_count` in the footer must not increment.

If the draft leaks into TB → backend regression — file a bug
referencing
`tests/test_tb_real_data_flow.py::test_draft_je_does_not_appear_in_tb`.

### A.5 As-of-date filter

1. (If the entity has multiple historical JEs:) change the as-of-date
   picker to a date *before* the JE created in A.2.
2. **Expected:** the new JE's rows disappear from the table; footer
   `posted_je_count` decreases by 1.
3. Reset the as-of-date to today.

---

## Path B — Cross-tenant isolation

This path needs **two registered users belonging to different tenants**
and an entity owned by user B's tenant. Tenant assignments live in the
JWT `tenant_id` claim — verify in DevTools before starting.

### B.1 Read your own → 200

1. Login as **user B**. Note `tenant_id` in the token (call it
   `tenant_B`).
2. Note the URL of an entity-B trial balance — copy the entity UUID
   from the URL, call it `entity_B`.
3. Open `/app/erp/finance/trial-balance`. **Expected:** loads cleanly,
   shows entity B's TB.

### B.2 Read someone else's → 403

1. Logout. Login as **user A** (different tenant — `tenant_A`).
2. **Manually navigate** to
   `https://<frontend>/app/erp/finance/trial-balance?entity=<entity_B>`
   — i.e., paste `entity_B` from B.1 into a URL meant to load
   tenant A's session against tenant B's entity.
   *Or*, easier — open DevTools → Network and intercept the GET to
   `/pilot/entities/<entity_B>/reports/trial-balance`.
3. **Expected:** the network call returns **HTTP 403** with body
   `{"detail":"Access denied — entity belongs to a different tenant"}`.
4. **Expected UI:** the screen shows the error state
   ("تعذر تحميل ميزان المراجعة"). It does **not** render any rows or
   totals from entity B.

If the request returns 200 → **stop the UAT and file a sev-1 security
bug.** Reference
`tests/test_tb_real_data_flow.py::test_user_a_cannot_read_user_b_entity_tb`
and the regression in `_entity_or_404`.

### B.3 curl smoke (optional, faster)

If you have a terminal handy and don't want to swap browser sessions:

```bash
TOKEN_A=eyJhbGc...   # user A's token
ENTITY_B=...uuid...  # tenant B's entity id

# Should return 403:
curl -i -H "Authorization: Bearer $TOKEN_A" \
  "https://apex-api-ootk.onrender.com/pilot/entities/$ENTITY_B/reports/trial-balance"

# Should return 404 (not 403) for a genuinely missing id:
curl -i -H "Authorization: Bearer $TOKEN_A" \
  "https://apex-api-ootk.onrender.com/pilot/entities/00000000-0000-0000-0000-000000000000/reports/trial-balance"
```

The 403 vs 404 distinction matters: if missing entities returned 403
under tenant A's token, an attacker could probe entity-id existence
just by reading status codes.

---

## Path C — Freshness badge sanity

1. On the TB screen, note the timestamp in the freshness badge.
2. Wait 30 s without clicking anything.
3. **Expected:** the timestamp does **not** update on its own — it
   only updates on explicit refresh / data load.
4. Click the refresh icon.
5. **Expected:** timestamp jumps to "now" within ~1 s.

If the badge is missing entirely after a successful load → frontend
regression. The widget sets `_lastFetchedAt = DateTime.now()` in the
success branch of `_loadData()`; verify the API call returned 200.

---

## Sign-off checklist

Tick each before closing the UAT ticket:

- [ ] A.1 — empty / pre-existing baseline screen loads with freshness badge
- [ ] A.2 — JE created + posted via je-builder
- [ ] A.3 — TB shows the new JE's rows + footer count incremented
- [ ] A.4 — draft JE does NOT appear in TB
- [ ] A.5 — as-of-date filter hides newer JE
- [ ] B.1 — user B can read entity B's TB (200)
- [ ] B.2 — user A cannot read entity B's TB (403 + error UI)
- [ ] B.3 (optional) — 404 for genuinely missing entity, not 403
- [ ] C — freshness badge updates on refresh, not by itself

If any tick fails, attach the screenshot + the network call
(method/URL/status/body) to the bug and reference this script.

---

## Notes for the operator

- The empty-state CTA navigates to `/app/erp/finance/je-builder` —
  if it lands on `/statements` instead, the routing got de-wired
  (regression of G-TB-DISPLAY-1).
- Excel / PDF buttons surface a SnackBar
  `"قريبًا — تصدير Excel/PDF قيد التطوير"`. This is intentional —
  export is a follow-up ticket.
- The footer line reads from `posted_je_count` which is a new field
  added in this PR. If the backend isn't redeployed yet, the field is
  missing and the footer shows an em-dash (`—`) instead of `0`. That's
  the correct fallback — it tells the operator "data unknown" rather
  than misleading "0 entries".
