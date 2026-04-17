"""Tests for the ZATCA invoice PDF generator."""

from __future__ import annotations

import uuid


def _sample_kwargs():
    return dict(
        invoice_number="INV-PDF-1",
        invoice_uuid=uuid.uuid4().hex,
        invoice_hash_b64="AAAA" * 4,
        qr_base64="dGVzdC1xcg==",  # "test-qr" base64
        seller={
            "name": "APEX Holdings",
            "vat_number": "300000000000003",
            "cr_number": "1010101010",
            "address_street": "King Fahd Rd",
            "address_city": "Riyadh",
        },
        buyer={
            "name": "عميل اختبار",
            "vat_number": None,
            "address_city": "Jeddah",
        },
        lines=[
            {"name": "استشارات", "quantity": "1", "unit_price": "1000", "vat_rate": "15"},
            {"name": "تدريب", "quantity": "2", "unit_price": "500", "vat_rate": "15"},
        ],
        totals={"subtotal": 2000, "vat_amount": 300, "grand_total": 2300},
        currency="SAR",
        submission_status="reported",
    )


def test_generate_invoice_pdf_returns_real_pdf_bytes():
    from app.integrations.zatca.invoice_pdf import (
        generate_invoice_pdf,
        looks_like_pdf,
    )
    out = generate_invoice_pdf(**_sample_kwargs())
    assert isinstance(out, bytes)
    assert looks_like_pdf(out), "output doesn't start with %PDF-"
    # Must be at least a few kilobytes — a blank reportlab page is ~1kb,
    # our template has tables + QR so should be larger.
    assert len(out) > 2000, f"PDF suspiciously small: {len(out)} bytes"


def test_generate_pdf_tolerates_missing_buyer():
    """Buyer=None shouldn't crash (walk-in retail invoices have no buyer)."""
    from app.integrations.zatca.invoice_pdf import (
        generate_invoice_pdf,
        looks_like_pdf,
    )
    kw = _sample_kwargs()
    kw["buyer"] = None
    out = generate_invoice_pdf(**kw)
    assert looks_like_pdf(out)


def test_generate_pdf_tolerates_empty_lines():
    """Credit-notes in draft sometimes have zero lines — still render."""
    from app.integrations.zatca.invoice_pdf import (
        generate_invoice_pdf,
        looks_like_pdf,
    )
    kw = _sample_kwargs()
    kw["lines"] = []
    out = generate_invoice_pdf(**kw)
    assert looks_like_pdf(out)


def test_generate_pdf_soft_fails_with_placeholder_on_internal_error(monkeypatch):
    """If reportlab itself throws, we return an error-shaped PDF (not raise)."""
    from app.integrations.zatca import invoice_pdf as mod

    def boom(**kwargs):
        raise RuntimeError("simulated reportlab failure")

    monkeypatch.setattr(mod, "_render", boom)
    out = mod.generate_invoice_pdf(**_sample_kwargs())
    # Error PDF is still a valid PDF document
    assert mod.looks_like_pdf(out)
    # And it's small — just an error banner
    assert len(out) < 2000


def test_pdf_download_route_returns_pdf(client):
    """End-to-end: submit → GET /submission/{id}/pdf → bytes are a PDF."""
    from unittest.mock import patch
    from app.integrations.zatca import fatoora_client

    fake = type("R", (), {
        "status": "reported",
        "http_status": 200,
        "errors": [],
        "warnings": [],
        "cleared_invoice_b64": "<x/>",
    })()

    submit_body = {
        "client_id": 42,
        "fiscal_year": 2026,
        "invoice_number": f"INV-PDF-R-{uuid.uuid4().hex[:6]}",
        "seller": {
            "name": "APEX",
            "vat_number": "300000000000003",
            "cr_number": "1010101010",
            "address_street": "King Fahd Rd",
            "address_city": "Riyadh",
            "address_postal": "11564",
            "country_code": "SA",
        },
        "lines": [{"name": "X", "quantity": "1", "unit_price": "100", "vat_rate": "15"}],
    }
    with patch.object(fatoora_client, "submit_reporting", return_value=fake):
        r = client.post("/api/v1/zatca/submit-e2e", json=submit_body)
    sid = r.json()["data"]["submission_id"]

    pdf = client.get(f"/api/v1/zatca/submission/{sid}/pdf")
    assert pdf.status_code == 200
    assert pdf.headers["content-type"] == "application/pdf"
    assert pdf.content.startswith(b"%PDF-")


def test_pdf_download_route_returns_404_for_unknown(client):
    resp = client.get("/api/v1/zatca/submission/does-not-exist/pdf")
    assert resp.status_code == 404
