"""ZATCA XAdES-BES signer + 7-field TLV QR extension.

This module adds the production signing layer on top of `zatca_service` (which
produces the canonical UBL XML + 5-field TLV QR + invoice hash).

Responsibilities:
  1. Load CSID credentials via `cert_store`.
  2. Produce an ECDSA-SECP256R1 signature over the canonical invoice hash.
  3. Return a 7-field TLV QR (adds tags 6=hash, 7=signature, 8=public-key).
  4. Graceful degradation: if cryptography isn't installed OR certs are
     missing, returns a clear-marked unsigned result — never raises.

The heavy dependency `cryptography` is imported lazily so importing this
module without the library available doesn't break the app.
"""

from __future__ import annotations

import base64
import hashlib
import logging
from dataclasses import dataclass
from typing import Optional

from app.core.zatca_service import ZatcaResult, _tlv  # type: ignore

from .cert_store import ZatcaCredentials, load_credentials

logger = logging.getLogger(__name__)


@dataclass
class SignedQrResult:
    """Output of sign_invoice(): 7-field QR or fallback to 5-field + reason."""

    qr_b64: str
    signed: bool
    signature_b64: Optional[str] = None
    warning: Optional[str] = None


def _load_crypto_libs():
    """Return (cryptography.hazmat modules) or None if unavailable."""
    try:
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.primitives.asymmetric.utils import (
            decode_dss_signature,
            encode_dss_signature,
        )
        from cryptography.x509 import load_pem_x509_certificate

        return (
            hashes,
            serialization,
            ec,
            decode_dss_signature,
            encode_dss_signature,
            load_pem_x509_certificate,
        )
    except ImportError as e:
        logger.warning("cryptography library not available for ZATCA signing: %s", e)
        return None


def _extract_public_key_der(cert_pem: str) -> Optional[bytes]:
    """Return the DER-encoded SubjectPublicKeyInfo from a PEM certificate."""
    libs = _load_crypto_libs()
    if libs is None:
        return None
    _, serialization, _, _, _, load_pem_x509_certificate = libs
    try:
        cert = load_pem_x509_certificate(cert_pem.encode("utf-8"))
        pub = cert.public_key()
        return pub.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    except Exception as e:
        logger.error("ZATCA: cert parse failed: %s", e)
        return None


def _sign_hash(private_key_pem: str, invoice_hash_bytes: bytes) -> Optional[bytes]:
    """Produce an ECDSA-SECP256R1 signature over the invoice hash."""
    libs = _load_crypto_libs()
    if libs is None:
        return None
    hashes, serialization, ec, _, _, _ = libs
    try:
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode("utf-8"),
            password=None,
        )
        if not isinstance(private_key, ec.EllipticCurvePrivateKey):
            logger.error("ZATCA: private key is not an ECC key")
            return None
        signature = private_key.sign(
            invoice_hash_bytes,
            ec.ECDSA(hashes.SHA256()),
        )
        return signature
    except Exception as e:
        logger.error("ZATCA: signing failed: %s", e)
        return None


def build_signed_qr(
    unsigned: ZatcaResult,
    credentials: Optional[ZatcaCredentials] = None,
) -> SignedQrResult:
    """Upgrade a 5-field TLV QR to 7-field by signing the invoice hash.

    If credentials are not supplied, they're loaded from env/disk. If
    unavailable OR crypto is not installed, returns the original 5-field
    QR with a warning — callers should propagate this as a non-fatal
    compliance notice.
    """
    creds = credentials or load_credentials()
    if creds is None:
        return SignedQrResult(
            qr_b64=unsigned.qr_b64,
            signed=False,
            warning="ZATCA credentials not configured — 5-field QR only",
        )

    # invoice_hash_b64 is base64 of the SHA-256 digest; we need the raw digest.
    try:
        hash_bytes = base64.b64decode(unsigned.invoice_hash_b64)
    except Exception as e:
        return SignedQrResult(
            qr_b64=unsigned.qr_b64,
            signed=False,
            warning=f"Could not decode invoice hash: {e}",
        )

    signature = _sign_hash(creds.private_key_pem, hash_bytes)
    if signature is None:
        return SignedQrResult(
            qr_b64=unsigned.qr_b64,
            signed=False,
            warning="Signing failed — returning unsigned 5-field QR",
        )

    public_key_der = _extract_public_key_der(creds.cert_pem)
    if public_key_der is None:
        return SignedQrResult(
            qr_b64=unsigned.qr_b64,
            signed=False,
            warning="Could not extract public key from certificate",
        )

    # Rebuild TLV: original 5 fields + 3 signature fields.
    try:
        original_tlv_raw = base64.b64decode(unsigned.qr_b64)
    except Exception:
        original_tlv_raw = b""

    extra = b"".join(
        [
            _tlv(6, unsigned.invoice_hash_b64),               # invoice hash (b64 string)
            _tlv(7, base64.b64encode(signature).decode()),    # ECDSA signature (b64)
            _tlv(8, base64.b64encode(public_key_der).decode()),  # public key (b64)
        ]
    )
    signed_tlv = original_tlv_raw + extra
    return SignedQrResult(
        qr_b64=base64.b64encode(signed_tlv).decode(),
        signed=True,
        signature_b64=base64.b64encode(signature).decode(),
    )


def sha256_b64(data: bytes) -> str:
    """Convenience: SHA-256 digest in base64 (matches ZATCA invoice_hash shape)."""
    return base64.b64encode(hashlib.sha256(data).digest()).decode()
