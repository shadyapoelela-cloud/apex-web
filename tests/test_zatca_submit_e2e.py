"""Integration tests for the ZATCA end-to-end submit route.

Verifies the /api/v1/zatca/submit-e2e pipeline:
  1. Accepts a simplified invoice payload.
  2. Builds UBL XML + QR + hash.
  3. Enqueues a ZatcaSubmission.
  4. Runs the first attempt (mocked to hit Fatoora).
  5. Returns submission_id + current status.
"""

from __future__ import annotations

from unittest.mock import patch


def _sample_payload(invoice_number: str = "INV-E2E-1"):
    return {
        "client_id": 1,
        "fiscal_year": 2026,
        "invoice_number": invoice_number,
        "seller": {
            "name": "APEX Holdings",
            "vat_number": "300000000000003",
            "cr_number": "1010101010",
            "address_street": "King Fahd Rd",
            "address_city": "Riyadh",
            "address_postal": "11564",
            "country_code": "SA",
        },
        "buyer": {
            "name": "عميل اختبار",
            "country_code": "SA",
        },
        "lines": [
            {"name": "استشارات محاسبية", "quantity": "1", "unit_price": "1000.00", "vat_rate": "15.00"},
            {"name": "تدريب فريق", "quantity": "2", "unit_price": "500.00", "vat_rate": "15.00"},
        ],
    }


def test_submit_e2e_happy_path_reports_to_fatoora(client):
    """Simulate Fatoora returning 'reported' — submission ends in REPORTED."""
    from app.integrations.zatca import fatoora_client as fc

    fake = type("R", (), {
        "status": "reported",
        "http_status": 200,
        "errors": [],
        "warnings": [],
        "cleared_invoice_b64": "<x/>",
    })()

    with patch.object(fc, "submit_reporting", return_value=fake):
        resp = client.post("/api/v1/zatca/submit-e2e", json=_sample_payload("INV-E2E-OK"))
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["status"] == "reported"
    assert data["terminal"] is True
    assert data["submission_id"]
    assert data["invoice_number"] == "INV-E2E-OK"
    # UBL QR should always be produced
    assert data["qr_base64"]


def test_submit_e2e_transient_error_enqueues_retry(client):
    """Simulate Fatoora 5xx — submission status becomes ERROR + scheduled retry."""
    from app.integrations.zatca import fatoora_client as fc

    fake = type("R", (), {
        "status": "error",
        "http_status": 503,
        "errors": [{"code": "HTTP_503", "message": "service unavailable"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()

    with patch.object(fc, "submit_reporting", return_value=fake):
        resp = client.post(
            "/api/v1/zatca/submit-e2e", json=_sample_payload("INV-E2E-RETRY")
        )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["status"] == "error"
    assert data["terminal"] is False
    assert data["attempts"] == 1
    assert data["next_attempt_at"] is not None


def test_submit_e2e_rejected_is_terminal(client):
    """Simulate Fatoora 4xx → rejected → terminal, no retry."""
    from app.integrations.zatca import fatoora_client as fc

    fake = type("R", (), {
        "status": "rejected",
        "http_status": 400,
        "errors": [{"code": "BAD_XML", "message": "missing seller.vat_number"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()

    with patch.object(fc, "submit_reporting", return_value=fake):
        resp = client.post(
            "/api/v1/zatca/submit-e2e", json=_sample_payload("INV-E2E-REJ")
        )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["status"] == "rejected"
    assert data["terminal"] is True


def test_submission_polling(client):
    """After submit, GET /submission/{id} should return current status."""
    from app.integrations.zatca import fatoora_client as fc

    fake = type("R", (), {
        "status": "reported",
        "http_status": 200,
        "errors": [],
        "warnings": [],
        "cleared_invoice_b64": "<x/>",
    })()

    with patch.object(fc, "submit_reporting", return_value=fake):
        submit = client.post(
            "/api/v1/zatca/submit-e2e", json=_sample_payload("INV-POLL-1")
        )
    sid = submit.json()["data"]["submission_id"]

    poll = client.get(f"/api/v1/zatca/submission/{sid}")
    assert poll.status_code == 200
    d = poll.json()["data"]
    assert d["submission_id"] == sid
    assert d["terminal"] is True
    assert d["invoice_number"] == "INV-POLL-1"


def test_submission_not_found(client):
    poll = client.get("/api/v1/zatca/submission/does-not-exist-xyz")
    assert poll.status_code == 404


def test_submit_rejects_bad_vat(client):
    """Seller vat_number must be exactly 15 digits — pydantic 422."""
    bad = _sample_payload()
    bad["seller"]["vat_number"] = "123"
    resp = client.post("/api/v1/zatca/submit-e2e", json=bad)
    assert resp.status_code == 422
