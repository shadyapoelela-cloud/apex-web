# `app.invoicing` — Invoicing Orchestration Layer

Orchestration layer **on top of** the existing pilot invoice routes
(INV-1, Sprint 18). The pilot routes still own create / list / issue /
payment for `pilot_sales_invoices` and `pilot_purchase_invoices`;
this module adds:

- Credit / debit notes (ZATCA-aware, full lifecycle)
- Recurring invoice templates + scheduler hook
- Invoice attachments
- Aged AR / AP reports
- Bulk operations (issue, email, PDF)
- Write-off path
- Dashboard widgets

See `GAP_ANALYSIS.md` for what existed before this PR vs what changed.

## Schema (4 tables)

| table | role |
|---|---|
| `credit_notes` | one row per credit / debit note (lifecycle: draft → issued → applied → cancelled) |
| `credit_note_lines` | line items |
| `recurring_invoice_templates` | periodic invoice schedules (daily/weekly/monthly/quarterly/yearly) |
| `invoice_attachments` | file attachments for any invoice type |

Migration `j7e2c8d4f9b1` is **idempotent** (DASH-1 hotfix pattern: every `op.create_table` gated by `inspect().has_table()`). Verified locally with the prod-failure scenario reproduction.

## Permissions (12 added to `app.core.custom_roles`)

| perm | purpose |
|---|---|
| `read:credit_notes` | view |
| `write:credit_notes` | create / update draft |
| `issue:credit_notes` | move from draft → issued |
| `apply:credit_notes` | apply to a target invoice |
| `read:recurring_invoices` | view templates |
| `write:recurring_invoices` | create / update / pause |
| `run:recurring_invoices` | manual trigger + admin sweep |
| `export:invoice_pdf` | download PDF |
| `bulk:invoice_actions` | issue/email batches |
| `upload:invoice_attachments` | upload + delete |
| `read:aged_ar_ap` | aged reports |
| `write_off:invoices` | bad-debt write-off |

## Endpoints (21 under `/api/v1/invoicing`)

```
POST   /credit-notes
GET    /credit-notes
GET    /credit-notes/{id}
POST   /credit-notes/{id}/issue
POST   /credit-notes/{id}/apply
POST   /credit-notes/{id}/cancel
POST   /recurring
GET    /recurring
PATCH  /recurring/{id}
POST   /recurring/{id}/run-now
POST   /recurring/{id}/pause
GET    /aged-ar?entity_id=...&as_of_date=...
GET    /aged-ap?entity_id=...&as_of_date=...
POST   /sales-invoices/{id}/pdf
POST   /purchase-invoices/{id}/pdf
POST   /sales-invoices/bulk/issue
POST   /sales-invoices/bulk/email
POST   /invoices/{id}/attachments
GET    /invoices/{id}/attachments
DELETE /attachments/{id}
POST   /invoices/{id}/write-off
POST   /admin/run-due-now
```

All return `{success, data}` except the PDF endpoints which stream `application/pdf`.

## Recurring scheduler

The spec called for a daily `apscheduler` job at 02:00. We deliberately ship a **cron-driven** model instead (no extra dependency, no background thread):

1. `app/invoicing/scheduler.py::run_due_recurring(db)` — programmatic single-shot runner.
2. `POST /api/v1/invoicing/admin/run-due-now` — exposes the runner via HTTP (perm-gated on `run:recurring_invoices`).
3. **Render-side cron** hits the admin endpoint daily.

When we adopt apscheduler (INV-1.3), `schedule_daily_runner()` is the single function to grow.

## Dashboard widgets

4 new entries in `app/dashboard/seeds.SYSTEM_WIDGETS` + resolvers in `app/dashboard/resolvers.py`:

| code | type | refresh |
|---|---|---|
| `kpi.aged_ar_summary` | kpi | 600s |
| `kpi.aged_ap_summary` | kpi | 600s |
| `list.overdue_invoices` | list | 300s |
| `kpi.recurring_due_today` | kpi | 1800s |

CFO + Accountant default layouts (`DEFAULT_LAYOUTS`) updated to include them.

## Tests

```
pytest tests/test_invoicing_api.py           45 passed in 13.68s
Coverage on app/invoicing/                   75.47%
  models.py 100% / schemas.py 100%
  router.py 78% (admin paths exercised manually)
  service.py 58% (pilot-model integration paths require seeded
                  pilot SalesInvoice rows in tests — INV-1 follow-up)
```

## Cross-references

- `app/invoicing/GAP_ANALYSIS.md` — why this is an orchestration layer, not a replacement
- `app/pilot/models/customer.py::SalesInvoice` — runtime sales invoice table
- `app/pilot/models/purchasing.py::PurchaseInvoice` — runtime purchase invoice table
- `app/integrations/zatca/invoice_pdf.py::generate_invoice_pdf` — PDF renderer reused via `service.generate_invoice_pdf`
- `app/coa/router.py` — `chart_of_accounts.account_id` referenced by line items
- DASH-1 hotfix `h2c5e8f1a4b7` + CoA-1 `i3d9f6c2e8a5` — the migration pattern this PR's `j7e2c8d4f9b1` follows

## Deferred follow-ups

- **INV-1.1** — branded PDF (multi-page, headers, watermarks) — out of scope here
- **INV-1.2** — HTML branded email template
- **INV-1.3** — apscheduler in-process scheduler (Render cron is enough for now)
- **CoA-1.2 + INV-2** — full Flutter UI (api_service stubs are wired so the UI can build with hook injection)
- **JE wiring** — credit-note issue currently sets `zatca_status=queued` + leaves `journal_entry_id=null`; downstream subscribers to `invoice.credit_note.issued` create the JE (out of band, tracked separately)
- **Storage backend** — attachment `storage_key` is a synthetic local path; S3 binding tracked under storage-module rewrite
