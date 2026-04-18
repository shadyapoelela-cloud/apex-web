"""Tests for the reports download endpoint."""

from __future__ import annotations


def test_csv_download_for_trial_balance(client):
    r = client.get("/api/v1/reports/download/trial_balance_2026-04_csv")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/csv")
    # CSV includes the BOM + "account" header from the sample rows
    body = r.content.decode("utf-8-sig")
    assert "account" in body.lower() or "debit" in body.lower()
    # Sample rows for trial_balance contain these labels
    assert "1001 — Cash" in body


def test_excel_download_for_profit_and_loss(client):
    r = client.get("/api/v1/reports/download/profit_and_loss_Q1-2026_excel")
    assert r.status_code == 200
    ct = r.headers["content-type"]
    # Either xlsx content-type or the CSV fallback when openpyxl missing.
    assert "spreadsheetml" in ct or ct.startswith("text/csv")


def test_pdf_download_for_aging_report(client):
    r = client.get("/api/v1/reports/download/aging_report_2026-04-30_pdf")
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/pdf"
    assert r.content.startswith(b"%PDF-")


def test_unknown_report_type_400(client):
    r = client.get("/api/v1/reports/download/not_a_type_csv")
    assert r.status_code == 400


def test_unsupported_format_400(client):
    r = client.get("/api/v1/reports/download/trial_balance_2026-04_jpeg")
    assert r.status_code == 400


def test_malformed_slug_400(client):
    r = client.get("/api/v1/reports/download/onetoken")
    assert r.status_code == 400


def test_rejects_special_characters_in_slug(client):
    r = client.get("/api/v1/reports/download/trial%2Fbalance_2026_csv")
    # URL has `/` after decoding — Starlette will route differently; we
    # mostly want to be sure the endpoint doesn't crash.
    assert r.status_code in (400, 404)


def test_period_with_underscores_parses(client):
    """Period like '2026-04-01_2026-04-30' has its own underscore; the
    parser must still pick it up correctly."""
    r = client.get(
        "/api/v1/reports/download/profit_and_loss_2026-04-01_2026-04-30_csv"
    )
    assert r.status_code == 200
    body = r.content.decode("utf-8-sig")
    assert "Net income" in body


def test_content_disposition_inline_set(client):
    r = client.get("/api/v1/reports/download/trial_balance_period_csv")
    assert "content-disposition" in r.headers
    assert r.headers["content-disposition"].startswith("inline; ")
