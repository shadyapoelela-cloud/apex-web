"""
APEX Platform — Unified Error Response Shape
═══════════════════════════════════════════════════════════════
All error responses follow:
  {
    "success": false,
    "error": {
      "code": "VALIDATION_ERROR",
      "message_ar": "خطأ في التحقق",
      "message_en": "Validation error",
      "details": [...],
      "request_id": "uuid"
    }
  }
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


_ERROR_MESSAGES_AR = {
    400: "طلب غير صحيح",
    401: "يجب تسجيل الدخول",
    403: "غير مصرَّح بالوصول",
    404: "المورد غير موجود",
    405: "الطريقة غير مسموحة",
    409: "تعارض في البيانات",
    422: "خطأ في التحقق",
    429: "تم تجاوز حد الطلبات — حاول لاحقاً",
    500: "خطأ داخلي في الخادم",
    502: "خطأ في البوابة",
    503: "الخدمة غير متاحة حالياً",
}

_ERROR_CODES = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    405: "METHOD_NOT_ALLOWED",
    409: "CONFLICT",
    422: "VALIDATION_ERROR",
    429: "RATE_LIMITED",
    500: "INTERNAL_ERROR",
    502: "BAD_GATEWAY",
    503: "SERVICE_UNAVAILABLE",
}


def _error_body(
    status_code: int,
    message_en: str,
    details: Any = None,
    request_id: str | None = None,
) -> dict:
    code = _ERROR_CODES.get(status_code, "ERROR")
    message_ar = _ERROR_MESSAGES_AR.get(status_code, message_en)
    body: dict = {
        "success": False,
        "error": {
            "code": code,
            "message_ar": message_ar,
            "message_en": message_en,
            "status_code": status_code,
        },
        # Backward-compatible `detail` field (FastAPI / Pydantic convention)
        "detail": details if details is not None else message_en,
    }
    if details is not None:
        body["error"]["details"] = details
    if request_id is not None:
        body["error"]["request_id"] = request_id
    return body


def register_error_handlers(app: FastAPI) -> None:
    """Attach unified error handlers to a FastAPI app."""

    @app.exception_handler(RequestValidationError)
    async def _validation_handler(request: Request, exc: RequestValidationError):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        details = []
        for e in exc.errors():
            details.append({
                "field": ".".join(str(x) for x in e.get("loc", [])),
                "message": e.get("msg", ""),
                "type": e.get("type", ""),
            })
        body = _error_body(
            status_code=422,
            message_en="Validation failed",
            details=details,
            request_id=req_id,
        )
        return JSONResponse(status_code=422, content=body)

    @app.exception_handler(StarletteHTTPException)
    async def _http_handler(request: Request, exc: StarletteHTTPException):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        body = _error_body(
            status_code=exc.status_code,
            message_en=str(exc.detail) if exc.detail else "HTTP error",
            details=exc.detail if isinstance(exc.detail, (list, dict)) else None,
            request_id=req_id,
        )
        return JSONResponse(status_code=exc.status_code, content=body)

    @app.exception_handler(Exception)
    async def _unhandled_handler(request: Request, exc: Exception):
        req_id = getattr(request.state, "request_id", str(uuid.uuid4()))
        logging.error(
            f"Unhandled exception [req_id={req_id}] {type(exc).__name__}: {exc}",
            exc_info=True,
        )
        body = _error_body(
            status_code=500,
            message_en="An unexpected error occurred",
            request_id=req_id,
        )
        return JSONResponse(status_code=500, content=body)
