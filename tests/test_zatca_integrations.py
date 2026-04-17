"""Tests for app.integrations.zatca (signer + fatoora_client + cert_store).

These tests do NOT hit the real ZATCA network. They verify:
  - Graceful degradation when credentials are missing.
  - Public-key extraction + ECDSA signing with generated keys (happy path).
  - Fatoora client returns structured error (no raise) on missing creds / net.
"""

from __future__ import annotations

import os
from unittest.mock import patch

import pytest


# ── cert_store ──────────────────────────────────────────────────


def test_cert_store_returns_none_when_unset(monkeypatch):
    for k in (
        "ZATCA_CSID_PEM",
        "ZATCA_PCSID_PEM",
        "ZATCA_PRIVATE_KEY_PEM",
        "ZATCA_CSID_PATH",
        "ZATCA_PRIVATE_KEY_PATH",
    ):
        monkeypatch.delenv(k, raising=False)
    from app.integrations.zatca.cert_store import is_configured, load_credentials

    assert load_credentials() is None
    assert is_configured() is False


def test_cert_store_loads_inline_pems(monkeypatch):
    monkeypatch.setenv("ZATCA_CSID_PEM", "-----BEGIN CERT-----\nMIIB\n-----END CERT-----")
    monkeypatch.setenv("ZATCA_PRIVATE_KEY_PEM", "-----BEGIN KEY-----\nABCD\n-----END KEY-----")
    # Re-import with the monkeypatched env in place
    import importlib

    from app.integrations.zatca import cert_store

    importlib.reload(cert_store)
    creds = cert_store.load_credentials()
    assert creds is not None
    assert "BEGIN CERT" in creds.cert_pem
    assert "BEGIN KEY" in creds.private_key_pem


# ── signer ──────────────────────────────────────────────────────


def _minimal_zatca_result():
    """Produce a ZatcaResult via the real builder so we have a valid hash/QR."""
    from datetime import datetime, timezone
    from decimal import Decimal

    from app.core.zatca_service import (
        ZatcaLineItem,
        ZatcaSeller,
        build_simplified_invoice,
    )

    seller = ZatcaSeller(
        name="شركة اختبار",
        vat_number="300000000000003",
        cr_number="1010000000",
    )
    lines = [
        ZatcaLineItem(
            name="اختبار",
            quantity=Decimal("1"),
            unit_price=Decimal("100.00"),
        )
    ]
    return build_simplified_invoice(
        seller=seller,
        lines=lines,
        issue_datetime=datetime(2026, 4, 17, tzinfo=timezone.utc),
        client_id="test-zatca-sign-1",
        fiscal_year="2027",  # avoid collision with other ZATCA tests
    )


def test_signer_without_credentials_returns_unsigned(monkeypatch):
    """With no creds configured, signer must fall back to the 5-field QR."""
    for k in (
        "ZATCA_CSID_PEM",
        "ZATCA_PCSID_PEM",
        "ZATCA_PRIVATE_KEY_PEM",
        "ZATCA_CSID_PATH",
        "ZATCA_PRIVATE_KEY_PATH",
    ):
        monkeypatch.delenv(k, raising=False)

    import importlib

    from app.integrations.zatca import cert_store, signer

    importlib.reload(cert_store)
    importlib.reload(signer)

    result = _minimal_zatca_result()
    signed = signer.build_signed_qr(result)
    assert signed.signed is False
    assert signed.qr_b64 == result.qr_b64
    assert signed.warning is not None


def test_signer_happy_path_produces_signed_qr():
    """With valid ECC credentials, produce a 7-field signed TLV QR.

    We generate an ECC keypair + self-signed cert on the fly so the test is
    hermetic and doesn't need real ZATCA onboarding.
    """
    try:
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.x509.oid import NameOID
    except ImportError:
        pytest.skip("cryptography library not installed")

    from datetime import datetime, timedelta, timezone

    # Generate a P-256 keypair.
    key = ec.generate_private_key(ec.SECP256R1())
    subject = issuer = x509.Name(
        [x509.NameAttribute(NameOID.COMMON_NAME, "APEX-TEST-CSID")]
    )
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(datetime.now(timezone.utc) - timedelta(days=1))
        .not_valid_after(datetime.now(timezone.utc) + timedelta(days=30))
        .sign(key, hashes.SHA256())
    )
    cert_pem = cert.public_bytes(serialization.Encoding.PEM).decode()
    key_pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode()

    from app.integrations.zatca.cert_store import ZatcaCredentials
    from app.integrations.zatca.signer import build_signed_qr

    creds = ZatcaCredentials(cert_pem=cert_pem, private_key_pem=key_pem, mode="sandbox")
    result = _minimal_zatca_result()
    signed = build_signed_qr(result, credentials=creds)
    assert signed.signed is True
    assert signed.signature_b64 is not None
    assert signed.qr_b64 != result.qr_b64  # now longer (has tags 6/7/8)


# ── fatoora_client ──────────────────────────────────────────────


def test_fatoora_submit_returns_error_without_credentials(monkeypatch):
    for k in (
        "ZATCA_CSID_PEM",
        "ZATCA_PCSID_PEM",
        "ZATCA_PRIVATE_KEY_PEM",
    ):
        monkeypatch.delenv(k, raising=False)

    import importlib

    from app.integrations.zatca import cert_store, fatoora_client

    importlib.reload(cert_store)
    importlib.reload(fatoora_client)

    resp = fatoora_client.submit_reporting(
        signed_xml="<x/>",
        invoice_hash_b64="AAAA",
        invoice_uuid="u-1",
    )
    assert resp.ok is False
    assert resp.status == "error"
    assert any(e["code"] == "NO_CREDENTIALS" for e in resp.errors)


def test_fatoora_maps_http_500_to_error_status(monkeypatch):
    """Transport/server errors must map to status='error' (retryable)."""
    monkeypatch.setenv("ZATCA_CSID_PEM", "cert")
    monkeypatch.setenv("ZATCA_PRIVATE_KEY_PEM", "key")
    import importlib

    from app.integrations.zatca import cert_store, fatoora_client

    importlib.reload(cert_store)
    importlib.reload(fatoora_client)

    fake_resp = type(
        "R",
        (),
        {
            "status_code": 500,
            "json": lambda self: {"message": "server down"},
            "text": "server down",
        },
    )()

    with patch("requests.post", return_value=fake_resp):
        resp = fatoora_client.submit_reporting(
            signed_xml="<x/>",
            invoice_hash_b64="AAAA",
            invoice_uuid="u-1",
        )
    assert resp.status == "error"
    assert resp.http_status == 500


def test_fatoora_maps_http_400_to_rejected(monkeypatch):
    """4xx → rejected (not retried)."""
    monkeypatch.setenv("ZATCA_CSID_PEM", "cert")
    monkeypatch.setenv("ZATCA_PRIVATE_KEY_PEM", "key")
    import importlib

    from app.integrations.zatca import cert_store, fatoora_client

    importlib.reload(cert_store)
    importlib.reload(fatoora_client)

    fake_resp = type(
        "R",
        (),
        {
            "status_code": 400,
            "json": lambda self: {"message": "invalid"},
            "text": "invalid",
        },
    )()

    with patch("requests.post", return_value=fake_resp):
        resp = fatoora_client.submit_reporting(
            signed_xml="<x/>",
            invoice_hash_b64="AAAA",
            invoice_uuid="u-1",
        )
    assert resp.status == "rejected"


def test_fatoora_network_failure_returns_error(monkeypatch):
    monkeypatch.setenv("ZATCA_CSID_PEM", "cert")
    monkeypatch.setenv("ZATCA_PRIVATE_KEY_PEM", "key")
    import importlib

    from app.integrations.zatca import cert_store, fatoora_client

    importlib.reload(cert_store)
    importlib.reload(fatoora_client)

    import requests

    with patch("requests.post", side_effect=requests.ConnectionError("dead")):
        resp = fatoora_client.submit_reporting(
            signed_xml="<x/>",
            invoice_hash_b64="AAAA",
            invoice_uuid="u-1",
        )
    assert resp.status == "error"
    assert any(e["code"] == "NETWORK" for e in resp.errors)
