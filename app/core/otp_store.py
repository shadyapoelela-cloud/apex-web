"""
APEX Platform -- OTP Store
In-memory OTP storage with TTL, attempt limits, and rate limiting.

For multi-instance production, swap the backend for Redis by setting
OTP_BACKEND=redis (see _RedisBackend stub below).
"""

import os
import time
import secrets
import hashlib
import logging
from collections import defaultdict
from threading import Lock
from typing import Optional

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────

OTP_BACKEND = os.environ.get("OTP_BACKEND", "memory")  # "memory" or "redis"
OTP_LENGTH = 6
OTP_TTL_SECONDS = 5 * 60  # 5 minutes
OTP_MAX_ATTEMPTS = 5  # max verify attempts per code
OTP_SEND_COOLDOWN_SECONDS = 60  # min seconds between sends to same number
OTP_SEND_MAX_PER_HOUR = 5  # max OTPs per number per hour


def _hash_code(code: str) -> str:
    """Hash OTP code so we never store plaintext in memory dumps/logs."""
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def generate_otp(length: int = OTP_LENGTH) -> str:
    """Generate a cryptographically secure numeric OTP."""
    max_val = 10**length
    return str(secrets.randbelow(max_val)).zfill(length)


class _MemoryBackend:
    """Thread-safe in-memory OTP store. Fine for single-instance deploys.

    Stores:
      codes[phone] = {"hash": sha256, "expires_at": ts, "attempts": int, "created_at": ts}
      send_history[phone] = [ts, ts, ...]
    """

    def __init__(self):
        self._codes = {}
        self._send_history = defaultdict(list)
        self._lock = Lock()

    def _cleanup_expired(self, now: float) -> None:
        """Remove expired codes and old send history. Caller must hold lock."""
        expired = [p for p, d in self._codes.items() if d["expires_at"] < now]
        for p in expired:
            del self._codes[p]
        for p in list(self._send_history.keys()):
            self._send_history[p] = [t for t in self._send_history[p] if now - t < 3600]
            if not self._send_history[p]:
                del self._send_history[p]

    def can_send(self, phone: str) -> tuple[bool, Optional[str]]:
        """Check if we can send a new OTP to this number right now.

        Returns (True, None) if allowed, else (False, reason).
        """
        now = time.time()
        with self._lock:
            self._cleanup_expired(now)
            history = self._send_history.get(phone, [])
            if history:
                last_sent = history[-1]
                if now - last_sent < OTP_SEND_COOLDOWN_SECONDS:
                    wait = int(OTP_SEND_COOLDOWN_SECONDS - (now - last_sent))
                    return False, f"انتظر {wait} ثانية قبل طلب رمز جديد"
            if len(history) >= OTP_SEND_MAX_PER_HOUR:
                return False, "تم تجاوز حد طلبات الرمز. حاول بعد ساعة."
        return True, None

    def store(self, phone: str, code: str) -> None:
        """Store a new OTP (replacing any previous one for this number)."""
        now = time.time()
        with self._lock:
            self._codes[phone] = {
                "hash": _hash_code(code),
                "expires_at": now + OTP_TTL_SECONDS,
                "attempts": 0,
                "created_at": now,
            }
            self._send_history[phone].append(now)

    def verify(self, phone: str, code: str) -> tuple[bool, Optional[str]]:
        """Verify an OTP. Returns (True, None) on success, else (False, reason).

        Deletes the code on success OR after max attempts (single-use semantics).
        """
        now = time.time()
        with self._lock:
            record = self._codes.get(phone)
            if not record:
                return False, "لا يوجد رمز فعّال لهذا الرقم"
            if record["expires_at"] < now:
                del self._codes[phone]
                return False, "انتهت صلاحية الرمز"
            if record["attempts"] >= OTP_MAX_ATTEMPTS:
                del self._codes[phone]
                return False, "تم تجاوز عدد المحاولات المسموح. اطلب رمزاً جديداً."

            record["attempts"] += 1

            if record["hash"] == _hash_code(code):
                del self._codes[phone]
                return True, None
            else:
                remaining = OTP_MAX_ATTEMPTS - record["attempts"]
                if remaining <= 0:
                    del self._codes[phone]
                    return False, "الرمز غير صحيح. تم تجاوز عدد المحاولات."
                return False, f"الرمز غير صحيح. محاولات متبقية: {remaining}"

    def clear(self, phone: str) -> None:
        """Manually clear any stored OTP for a number (e.g. on logout)."""
        with self._lock:
            self._codes.pop(phone, None)


class _RedisBackend:
    """Stub for Redis-backed OTP store (multi-instance production).

    Not implemented yet — activate once Redis is provisioned.
    Keys:
      otp:{phone}           -> hash (with EX=300)
      otp:{phone}:attempts  -> int (with EX=300)
      otp:send:{phone}      -> list of timestamps (EX=3600)
    """

    def __init__(self):  # pragma: no cover
        raise NotImplementedError(
            "Redis OTP backend not implemented. Set OTP_BACKEND=memory or implement this class."
        )


_backend_instance = None


def get_store():
    """Return the active OTP backend (singleton)."""
    global _backend_instance
    if _backend_instance is not None:
        return _backend_instance
    if OTP_BACKEND == "redis":
        _backend_instance = _RedisBackend()
    else:
        _backend_instance = _MemoryBackend()
    return _backend_instance


# ── Public API ────────────────────────────────────────────────


def request_otp(phone: str) -> tuple[Optional[str], Optional[str]]:
    """Generate and store a new OTP for the given phone number.

    Returns (code, None) on success — caller sends via SMS.
    Returns (None, reason) if rate-limited or blocked.
    """
    store = get_store()
    allowed, reason = store.can_send(phone)
    if not allowed:
        return None, reason
    code = generate_otp()
    store.store(phone, code)
    return code, None


def verify_otp(phone: str, code: str) -> tuple[bool, Optional[str]]:
    """Verify an OTP code. Returns (True, None) or (False, reason)."""
    if not code or not code.isdigit() or len(code) != OTP_LENGTH:
        return False, f"يجب أن يكون الرمز {OTP_LENGTH} أرقام"
    return get_store().verify(phone, code)


def clear_otp(phone: str) -> None:
    """Clear any pending OTP for a phone number."""
    get_store().clear(phone)
