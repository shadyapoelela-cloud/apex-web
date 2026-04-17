"""UAE FTA TRN (Tax Registration Number) validator.

Format: 15 digits. No checksum published by FTA; we validate:
  • numeric, exactly 15 digits
  • starts with '1' (FTA assigns 1xx…xxx)
  • no all-zero / all-same pattern (obvious test inputs)

For authoritative verification, POST to FTA's public TRN verification
service. That's a `verify_online()` function below — guarded behind an
environment flag because it's a live call.
"""

from __future__ import annotations

import logging
import os
import re
from typing import Optional

logger = logging.getLogger(__name__)

_TRN_RE = re.compile(r"^\d{15}$")


def normalize_trn(raw: str) -> str:
    """Strip spaces/dashes and return a 15-digit string (if applicable)."""
    return re.sub(r"[\s\-]", "", raw or "")


def validate_trn(raw: str) -> tuple[bool, Optional[str]]:
    """Return (ok, reason). reason is None on success, Arabic message on failure."""
    if not raw:
        return False, "الرقم الضريبي مطلوب"
    v = normalize_trn(raw)
    if not _TRN_RE.match(v):
        return False, "يجب أن يكون الرقم الضريبي 15 رقماً"
    if not v.startswith("1"):
        return False, "يبدأ الرقم الضريبي الإماراتي برقم 1"
    if v == v[0] * 15:
        return False, "رقم غير صحيح (نمط متكرر)"
    return True, None


def verify_online(trn: str) -> dict:
    """Live verification against FTA's public API.

    Only called if UAE_FTA_TRN_VERIFY_URL is set. Returns a dict with
    status + raw payload, or {'status': 'error', 'reason': '…'} on failure.
    This is a placeholder — the final URL/auth depends on the client's
    FTA portal credentials.
    """
    url = os.environ.get("UAE_FTA_TRN_VERIFY_URL", "")
    if not url:
        return {"status": "skipped", "reason": "UAE_FTA_TRN_VERIFY_URL not configured"}
    try:
        import requests
    except ImportError:
        return {"status": "error", "reason": "requests not installed"}
    try:
        resp = requests.get(url, params={"trn": trn}, timeout=10)
    except requests.RequestException as e:
        return {"status": "error", "reason": f"network: {e}"}
    if resp.status_code != 200:
        return {"status": "error", "reason": f"HTTP {resp.status_code}"}
    try:
        return {"status": "ok", "payload": resp.json()}
    except ValueError:
        return {"status": "error", "reason": "invalid JSON from FTA"}
