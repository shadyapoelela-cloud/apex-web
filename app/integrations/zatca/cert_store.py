"""ZATCA certificate loader.

Loads the onboarded CSID (Compliance Cryptographic Stamp Identifier) or
PCSID (Production CSID) from environment variables or disk, with a consistent
shape that signer.py can consume.

Environment variables (all optional — module returns None if unset):
  ZATCA_MODE              "sandbox" | "production" (default: sandbox)
  ZATCA_CSID_PEM          Full CSID certificate PEM (sandbox / onboarding)
  ZATCA_PCSID_PEM         Production CSID certificate PEM
  ZATCA_PRIVATE_KEY_PEM   ECC private key PEM (PKCS8, no passphrase)
  ZATCA_CSID_PATH         Alternative: path to a PEM file on disk
  ZATCA_PRIVATE_KEY_PATH  Path to private-key PEM file on disk

The module never raises on import. If certs are missing, sign() calls in
signer.py will return an unsigned invoice with a clear warning in the
`warnings` list of the ZatcaResult.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

ZATCA_MODE = os.environ.get("ZATCA_MODE", "sandbox").lower()


@dataclass(frozen=True)
class ZatcaCredentials:
    """Loaded certificate + private key, in PEM form."""

    cert_pem: str
    private_key_pem: str
    mode: str  # 'sandbox' or 'production'

    @property
    def is_production(self) -> bool:
        return self.mode == "production"


def _read_path(path: Optional[str]) -> Optional[str]:
    if not path:
        return None
    p = Path(path)
    try:
        return p.read_text(encoding="utf-8")
    except OSError as e:
        logger.warning("ZATCA: could not read cert/key at %s: %s", path, e)
        return None


def load_credentials() -> Optional[ZatcaCredentials]:
    """Load onboarded ZATCA credentials, or return None if not configured."""
    cert_pem = os.environ.get(
        "ZATCA_PCSID_PEM" if ZATCA_MODE == "production" else "ZATCA_CSID_PEM",
        "",
    ).strip()
    if not cert_pem:
        cert_pem = _read_path(os.environ.get("ZATCA_CSID_PATH")) or ""

    key_pem = os.environ.get("ZATCA_PRIVATE_KEY_PEM", "").strip()
    if not key_pem:
        key_pem = _read_path(os.environ.get("ZATCA_PRIVATE_KEY_PATH")) or ""

    if not cert_pem or not key_pem:
        return None

    return ZatcaCredentials(
        cert_pem=cert_pem,
        private_key_pem=key_pem,
        mode=ZATCA_MODE,
    )


def is_configured() -> bool:
    """True if ZATCA credentials are loadable right now."""
    return load_credentials() is not None
