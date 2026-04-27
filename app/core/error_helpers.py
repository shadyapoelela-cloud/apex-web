"""APEX — Structured error helpers.

Wave 4 / A6 of APEX_IMPROVEMENT_PLAN.md.

Wraps the FastAPI error path so handlers stop forwarding raw exception
text to clients (`detail=str(e)` is a privacy + security smell flagged
72 times in `tools/api_audit.py` output) AND start emitting structured
log records the operator can ship to Sentry / Datadog without further
parsing.

Usage in a route
----------------

    from app.core.error_helpers import handle_route_error, log_error

    @router.post("/sales-invoices")
    def create_invoice(...):
        try:
            ...
        except ValueError as e:
            # Bad input — surface a friendly message, log the detail.
            raise handle_route_error(
                e,
                user_message="بيانات الفاتورة غير صالحة",
                status_code=400,
                endpoint="POST /sales-invoices",
            )
        except Exception as e:
            # Unexpected — generic message, full traceback in logs.
            raise handle_route_error(
                e,
                user_message="حدث خطأ غير متوقّع",
                status_code=500,
                endpoint="POST /sales-invoices",
            )

The user only ever sees the `user_message`. The traceback + `endpoint`
+ exception type are recorded structured so production telemetry can
slice/dice without regex on free-form strings.
"""

from __future__ import annotations

import logging
import traceback
import uuid
from typing import Any, Optional

from fastapi import HTTPException

logger = logging.getLogger("apex.error")


def log_error(
    exc: BaseException,
    *,
    endpoint: str,
    extra: Optional[dict[str, Any]] = None,
    correlation_id: Optional[str] = None,
) -> str:
    """Emit a structured ERROR-level log record and return the correlation id.

    The returned id can be sent to the client so support can find the
    matching log entry without giving away internals.

    The record uses `extra=` so structured loggers (Sentry, Datadog,
    Logfire) capture each field as its own attribute.
    """
    cid = correlation_id or uuid.uuid4().hex[:12]
    logger.error(
        "Unhandled error in %s (cid=%s): %s",
        endpoint,
        cid,
        exc.__class__.__name__,
        extra={
            "correlation_id": cid,
            "endpoint": endpoint,
            "exc_type": exc.__class__.__name__,
            "exc_message": str(exc),
            **(extra or {}),
        },
        exc_info=True,
    )
    return cid


def handle_route_error(
    exc: BaseException,
    *,
    user_message: str,
    status_code: int = 500,
    endpoint: str = "",
    extra: Optional[dict[str, Any]] = None,
) -> HTTPException:
    """Build an HTTPException with a user-safe `detail` and log the
    underlying exception with full traceback + context.

    Returns the HTTPException so the caller can `raise` it.
    """
    cid = log_error(exc, endpoint=endpoint, extra=extra)
    return HTTPException(
        status_code=status_code,
        detail={
            "success": False,
            "error": user_message,
            "correlation_id": cid,
        },
    )


def safe_dict_response(success: bool, **kwargs: Any) -> dict[str, Any]:
    """Build a {success: bool, ...} response body that conforms to the
    platform's documented shape. Use this in handlers that currently
    return bare dicts without the `success` key (10 such cases flagged
    by the audit).
    """
    return {"success": success, **kwargs}


def get_traceback(exc: BaseException) -> str:
    """Return the formatted traceback as a single string. Useful when
    you want to attach a redacted trace to a structured field rather
    than relying on the logger's exc_info path.
    """
    return "".join(
        traceback.format_exception(type(exc), exc, exc.__traceback__)
    )
