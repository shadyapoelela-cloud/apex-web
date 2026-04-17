"""ZATCA Fatoora API client.

Submits signed invoices to the ZATCA Phase 2 Fatoora platform.

Endpoints (per ZATCA spec v2.5):
  POST /compliance/invoices       — initial onboarding compliance check
  POST /clearance/single          — standard (B2B) invoice real-time clearance
  POST /reporting/single          — simplified (B2C) invoice reporting (≤24h)

Sandbox base URL: https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal
Production base:  https://gw-fatoora.zatca.gov.sa/e-invoicing/core

Both override-able via ZATCA_FATOORA_BASE_URL.

All network calls are wrapped in try/except — callers receive a structured
FatooraResponse dataclass, never a raw exception. Failures go into a retry
queue (to be implemented in a separate module).
"""

from __future__ import annotations

import base64
import logging
import os
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

from .cert_store import ZATCA_MODE, ZatcaCredentials, load_credentials

logger = logging.getLogger(__name__)

# ── URLs ──────────────────────────────────────────────────────

_DEFAULT_SANDBOX_BASE = (
    "https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal"
)
_DEFAULT_PRODUCTION_BASE = "https://gw-fatoora.zatca.gov.sa/e-invoicing/core"


def _base_url() -> str:
    override = os.environ.get("ZATCA_FATOORA_BASE_URL", "").strip()
    if override:
        return override.rstrip("/")
    return (
        _DEFAULT_PRODUCTION_BASE if ZATCA_MODE == "production" else _DEFAULT_SANDBOX_BASE
    ).rstrip("/")


# ── Models ────────────────────────────────────────────────────


class SubmitKind(str, Enum):
    COMPLIANCE = "compliance"
    CLEARANCE = "clearance"
    REPORTING = "reporting"


@dataclass
class FatooraResponse:
    """Structured result from a Fatoora call.

    status:
      'cleared'  — ZATCA accepted (standard B2B flow).
      'reported' — ZATCA acknowledged (simplified B2C flow).
      'warnings' — accepted with warnings (should be reviewed).
      'rejected' — ZATCA refused (see errors for details).
      'error'    — transport/network/auth issue (retry candidate).
    """

    status: str
    http_status: int = 0
    request_id: Optional[str] = None
    cleared_invoice_b64: Optional[str] = None
    errors: list[dict] = field(default_factory=list)
    warnings: list[dict] = field(default_factory=list)
    raw: dict = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return self.status in ("cleared", "reported", "warnings")


# ── Client ────────────────────────────────────────────────────


def _auth_header(creds: ZatcaCredentials) -> dict:
    """ZATCA uses HTTP Basic auth with the CSID cert (base64 PEM) and secret.

    The Fatoora API expects:
      Authorization: Basic base64(base64(cert-PEM):secret)
    The 'secret' is what's returned alongside the CSID at onboarding time.
    For this scaffold we take it from ZATCA_CSID_SECRET env var.
    """
    secret = os.environ.get("ZATCA_CSID_SECRET", "")
    cert_b64 = base64.b64encode(creds.cert_pem.encode("utf-8")).decode()
    token = base64.b64encode(f"{cert_b64}:{secret}".encode("utf-8")).decode()
    return {"Authorization": f"Basic {token}"}


def _submit(
    kind: SubmitKind,
    signed_xml: str,
    invoice_hash_b64: str,
    invoice_uuid: str,
) -> FatooraResponse:
    creds = load_credentials()
    if creds is None:
        return FatooraResponse(
            status="error",
            errors=[{"code": "NO_CREDENTIALS", "message": "ZATCA credentials not configured"}],
        )

    try:
        import requests
    except ImportError:
        return FatooraResponse(
            status="error",
            errors=[{"code": "NO_REQUESTS", "message": "requests library not installed"}],
        )

    url_path = {
        SubmitKind.COMPLIANCE: "/compliance/invoices",
        SubmitKind.CLEARANCE: "/invoices/clearance/single",
        SubmitKind.REPORTING: "/invoices/reporting/single",
    }[kind]
    url = f"{_base_url()}{url_path}"

    payload = {
        "invoiceHash": invoice_hash_b64,
        "uuid": invoice_uuid,
        "invoice": base64.b64encode(signed_xml.encode("utf-8")).decode(),
    }
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Accept-Language": "en",
        "Accept-Version": "V2",
        **_auth_header(creds),
    }

    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=30)
    except requests.RequestException as e:
        logger.error("Fatoora submit network error: %s", e)
        return FatooraResponse(
            status="error",
            errors=[{"code": "NETWORK", "message": str(e)}],
        )

    try:
        body = resp.json()
    except ValueError:
        body = {"raw_text": resp.text[:500]}

    if resp.status_code in (200, 202):
        results = body.get("validationResults", {}) if isinstance(body, dict) else {}
        status_key = (
            body.get("clearanceStatus") or body.get("reportingStatus") or ""
        ).lower()
        mapped = {
            "cleared": "cleared",
            "cleared_with_warnings": "warnings",
            "not_cleared": "rejected",
            "reported": "reported",
            "reported_with_warnings": "warnings",
            "not_reported": "rejected",
        }.get(status_key, "warnings" if resp.status_code == 202 else "cleared")
        return FatooraResponse(
            status=mapped,
            http_status=resp.status_code,
            cleared_invoice_b64=body.get("clearedInvoice") if isinstance(body, dict) else None,
            errors=results.get("errorMessages", []) if isinstance(results, dict) else [],
            warnings=results.get("warningMessages", []) if isinstance(results, dict) else [],
            raw=body if isinstance(body, dict) else {},
        )

    # 4xx / 5xx
    return FatooraResponse(
        status="rejected" if 400 <= resp.status_code < 500 else "error",
        http_status=resp.status_code,
        errors=[{"code": f"HTTP_{resp.status_code}", "message": (body if isinstance(body, dict) else {}).get("message", "")}],
        raw=body if isinstance(body, dict) else {},
    )


def submit_clearance(
    signed_xml: str,
    invoice_hash_b64: str,
    invoice_uuid: str,
) -> FatooraResponse:
    """Real-time clearance for standard (B2B) invoices. Must happen BEFORE
    the invoice is printed/sent to the buyer."""
    return _submit(SubmitKind.CLEARANCE, signed_xml, invoice_hash_b64, invoice_uuid)


def submit_reporting(
    signed_xml: str,
    invoice_hash_b64: str,
    invoice_uuid: str,
) -> FatooraResponse:
    """Reporting for simplified (B2C) invoices. Must happen within 24h
    after issuance."""
    return _submit(SubmitKind.REPORTING, signed_xml, invoice_hash_b64, invoice_uuid)


def submit_compliance(
    signed_xml: str,
    invoice_hash_b64: str,
    invoice_uuid: str,
) -> FatooraResponse:
    """Onboarding compliance check (used during CSID setup — not runtime)."""
    return _submit(SubmitKind.COMPLIANCE, signed_xml, invoice_hash_b64, invoice_uuid)
