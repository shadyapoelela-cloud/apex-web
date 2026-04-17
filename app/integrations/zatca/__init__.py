"""ZATCA Phase 2 (Fatoora) integration — Saudi e-invoicing.

This package wraps the lower-level `app.core.zatca_service` (UBL XML + TLV QR
+ invoice hash + ICV/PIH chain) with:

  • signer.py         — XAdES-BES signing & extended 7-field TLV QR.
  • fatoora_client.py — HTTP client for compliance / clearance / reporting.
  • cert_store.py     — load onboarded CSID + PCSID certs from env/disk.

Entry points re-exported for ergonomic imports:
  from app.integrations.zatca import (
      build_signed_invoice,
      submit_to_fatoora,
      ZatcaFatooraError,
  )

Sandbox vs production is selected by ZATCA_MODE env var (sandbox/production).
"""

from app.core.zatca_service import (  # noqa: F401 — re-export
    ZatcaBuyer,
    ZatcaInvoice,
    ZatcaLineItem,
    ZatcaResult,
    ZatcaSeller,
    build_simplified_invoice,
    build_tlv_qr,
    validate_vat_number,
)

# Heavy deps (cryptography, requests) are lazy-loaded inside the modules below
# so importing this package never crashes when optional deps are absent.

__all__ = [
    "ZatcaBuyer",
    "ZatcaInvoice",
    "ZatcaLineItem",
    "ZatcaResult",
    "ZatcaSeller",
    "build_simplified_invoice",
    "build_tlv_qr",
    "validate_vat_number",
]
