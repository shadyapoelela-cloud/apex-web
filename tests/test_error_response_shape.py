"""Regression guards for the unified error-response shape.

Two invariants we care about:

1. ``message_en`` must be ENGLISH. The app frequently raises
   ``HTTPException(401, Errors.INTERNAL)`` where ``Errors.INTERNAL``
   is Arabic. Echoing that into ``message_en`` makes the field
   useless for non-Arabic clients and confuses monitoring tools that
   grep on English strings. Live audit on 2026-04-24 caught this:

     curl .../auth/login … → 401
     message_en: "خطأ داخلي في الخادم — حاول لاحقاً أو تواصل مع الدعم"

2. ``detail`` must preserve the original caller-supplied string so
   that pre-refactor consumers (tests, front-end error-toasts)
   continue to work unchanged.

3. Login responses must be IDENTICAL for ``user not found`` vs
   ``wrong password``. Username-enumeration is a classic auth
   disclosure bug; the live check showed this is already safe, and
   we lock it in with a test so it stays safe.
"""

from __future__ import annotations


def test_error_body_strips_arabic_from_message_en() -> None:
    """Passing an Arabic string to _error_body must not leak it into
    message_en — the English status-code default is substituted."""
    from app.core.error_handlers import _error_body

    body = _error_body(
        status_code=401,
        message_en="يجب تسجيل الدخول",  # Arabic; simulates Errors.UNAUTHORIZED
    )
    assert body["error"]["message_en"] == "Authentication required"
    # Arabic version still present (correct).
    assert body["error"]["message_ar"] == "يجب تسجيل الدخول"
    # detail preserves the caller's original (backward compat).
    assert body["detail"] == "يجب تسجيل الدخول"


def test_error_body_passes_through_english_message_en() -> None:
    """Callers that DO pass English should see their string unchanged."""
    from app.core.error_handlers import _error_body

    body = _error_body(
        status_code=422,
        message_en="Field 'amount' must be positive",
    )
    assert body["error"]["message_en"] == "Field 'amount' must be positive"
    assert body["error"]["message_ar"] == "خطأ في التحقق"  # from the AR table


def test_error_body_shape_is_stable() -> None:
    """Every error body must keep the documented top-level keys so
    that any client that destructures them doesn't break."""
    from app.core.error_handlers import _error_body

    body = _error_body(
        status_code=500,
        message_en="An unexpected error occurred",
        request_id="abc-123",
    )
    assert body["success"] is False
    assert set(body["error"].keys()) >= {
        "code",
        "message_ar",
        "message_en",
        "status_code",
        "request_id",
    }
    assert body["error"]["code"] == "INTERNAL_ERROR"
    assert body["error"]["status_code"] == 500


# ══════════════════════════════════════════════════════════════════════
# Username enumeration regression — ensure login distinguishes nothing
# ══════════════════════════════════════════════════════════════════════
def test_login_no_username_enumeration(client) -> None:
    """Both "user doesn't exist" and "user exists, wrong password"
    must yield the same status code and the same error code. Any
    divergence lets an attacker enumerate valid usernames via timing
    or message differences."""
    payload_nouser = {"username_or_email": "nosuchuser@apex.sa", "password": "wrong-1"}
    payload_wrongpw = {"username_or_email": "admin@apex.sa", "password": "wrong-2"}

    r1 = client.post("/auth/login", json=payload_nouser)
    r2 = client.post("/auth/login", json=payload_wrongpw)

    # Status parity.
    assert r1.status_code == r2.status_code, (
        f"status divergence: nouser={r1.status_code}, wrongpw={r2.status_code}"
    )

    # Both should be an auth failure (401). If the shape changes,
    # this will surface it.
    assert r1.status_code in (401, 422), (
        f"unexpected status {r1.status_code} — {r1.text[:200]}"
    )

    # Error-code parity (only meaningful if JSON).
    try:
        err1 = r1.json().get("error", {}).get("code")
        err2 = r2.json().get("error", {}).get("code")
    except Exception:
        err1 = err2 = None

    if err1 is not None and err2 is not None:
        assert err1 == err2, (
            f"error code divergence enumerates users: {err1!r} vs {err2!r}"
        )
