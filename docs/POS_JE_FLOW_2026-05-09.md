# POS Daily Report → JE Verification — Sprint 7

**Status:** in force as of 2026-05-09 (G-FIN-POS-JE-AUTOPOST).
**Closes:** Sprint 1 audit Gap §3 row 7 ("POS daily summary screen
— POS works; needs a `/pos-sessions/{id}/summary` UI").

---

## TL;DR

Backend `auto_post_pos_sale` (gl_engine.py:578) has shipped since
well before this sprint. Every completed POS transaction posts up to
**3 JEs**:

```
Sales JE (always):
  DR Cash (1110) or Bank (1120)   grand_total       ← which one depends on payment method
  CR Sales Revenue (4100)         taxable_amount    ← (or 4200 for returns)
  CR VAT Output Payable (2120)    vat_total

COGS JE (only when product line has a cost):
  DR Cost of Sales (5100)         Σ(qty × unit_cost)
  CR Inventory (1140)             Σ(qty × unit_cost)

Refund JE: same shape as sales JE with debits/credits flipped.
```

The verification surface was missing — pilots had no place to confirm
that "today's 5 sales actually moved the trial balance the way I
expected." Sprint 7 ships that surface.

## What's new

| File | Purpose |
|---|---|
| [pos_daily_report_screen.dart](../apex_finance/lib/screens/operations/pos_daily_report_screen.dart) | Two-pane screen. Left rail lists POS sessions for the active branch. Right pane shows the Z-report KPIs, payment-method breakdown, and per-transaction JE links. |
| [v5_wired_screens.dart](../apex_finance/lib/core/v5/v5_wired_screens.dart) | New chip mapping `erp/finance/pos-report` → `PosDailyReportScreen`. |
| [v5_wired_keys.dart](../apex_finance/lib/core/v5/v5_wired_keys.dart) | New entry `'erp/finance/pos-report'` so the routing-validator inventory stays in sync. |

## KPIs surfaced (top of right pane)

Row 1 — **the day at a glance:**
- إجمالي المبيعات (gross sales)
- إجمالي VAT (output VAT)
- صافي (net = gross − VAT)
- عدد الفواتير (transaction count)

Row 2 — **cash reconciliation:**
- الكاش المتوقّع (expected cash from session)
- الكاش الفعلي (closing count)
- الفرق (variance — green when |Δ| < 0.01, amber otherwise)

## Sections below KPIs

- **توزيع طرق الدفع** — chip-style breakdown reading
  `payment_breakdown` from the Z-report response (نقدي / مدى / فيزا
  / Apple Pay / STC Pay / آجل etc).
- **العمليات المُرحَّلة** — list of transactions for the session.
  Each row shows the receipt number, timestamp, total, and a
  `JE #XXXXXXXX` button that links to `/app/erp/finance/je-builder`
  so the user can drill into the auto-posted entry.

## Test coverage

[pos_je_autopost_test.dart](../apex_finance/test/screens/pos_je_autopost_test.dart) — 5 source-grep contracts:

1. Screen calls `pilotZReport`, `pilotListPosTransactions`, and
   `pilotListPosSessions` (all three endpoints exist server-side).
2. The 7 KPI labels remain on the screen (sales / VAT / net / count
   / expected cash / closing cash / variance).
3. `payment_breakdown` is read from the Z-report and surfaced under
   a "توزيع طرق الدفع" section.
4. Each transaction row reads `journal_entry_id` from the txn payload
   and exposes a button linking to the JE list.
5. The `erp/finance/pos-report` chip is wired in both
   `v5_wired_screens.dart` and `v5_wired_keys.dart`.

5/5 pass.

## Manual UAT

1. Open `/app/erp/finance/pos` → start a session, ring up 2 sales
   (one cash, one card), and one refund.
2. Navigate to `/app/erp/finance/pos-report`.
3. Left rail: see the open session at the top. Click it.
4. Right pane:
   - إجمالي المبيعات should equal the sum of the 2 sales gross
     totals minus the refund.
   - عدد الفواتير should be 3.
   - توزيع طرق الدفع should show نقدي + بطاقة (or مدى) chips.
   - 3 transaction rows; each row's JE-link button is non-empty.
5. Click any JE-link button → opens `/app/erp/finance/je-builder`.
6. Navigate to `/app/erp/finance/trial-balance`. Expected
   movements:
   - Cash (1110) ↑ by net cash received
   - Bank (1120) ↑ by net card received
   - Sales Revenue (4100) credit balance ↑ by taxable amount
   - VAT Output (2120) credit balance ↑ by VAT total
   - Inventory (1140) ↓ by Σ(qty × unit_cost) for product lines
   - COGS (5100) ↑ by Σ(qty × unit_cost)
7. Income Statement: gross profit = net sales − COGS.

## What's deferred

- **Live stream of in-progress transactions.** The current screen is
  pull-on-load, not real-time. A websocket or SSE feed could update
  the KPIs as new sales come in during an open session — bookmarked.
- **Z-close → JE auto-post on close.** Today the Z-close endpoint
  produces the report but doesn't post a "closing" cash JE. Adding
  a daily summary JE on close is a separate workstream.
