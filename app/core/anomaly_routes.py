"""
APEX — Anomaly scan route (Wave 3 PR#1).

POST /anomalies/scan — accepts a caller-supplied list of transactions
and returns the findings from every enabled detector. Because the
detectors are pure functions over dicts, this endpoint works whether
the caller is pulling from the DB, an uploaded CSV, or the AI OCR
extract pipeline.

Returned shape matches the "Anomaly Feed" card expected by the UI
(see APEX_GLOBAL_RESEARCH_210 §7 pattern #110).
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.anomaly_detector import scan_all
from app.core.auth_utils import extract_user_id

router = APIRouter(prefix="/anomalies", tags=["Anomalies"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


class ScanRequest(BaseModel):
    transactions: list[dict[str, Any]] = Field(
        ..., description="Transaction dicts (see anomaly_detector module docstring)"
    )
    window_days: int = Field(default=7, ge=1, le=90)
    round_number_min: str = Field(default="5000")
    business_hours_start: int = Field(default=6, ge=0, le=23)
    business_hours_end: int = Field(default=22, ge=1, le=24)
    new_vendor_threshold: str = Field(default="50000")
    spike_multiplier: float = Field(default=3.0, ge=1.0, le=100.0)


@router.post("/scan")
async def scan_anomalies(req: ScanRequest, _user_id: str = Depends(_auth)):
    if req.business_hours_end <= req.business_hours_start:
        raise HTTPException(
            status_code=400,
            detail="business_hours_end must be greater than business_hours_start",
        )
    findings = scan_all(
        req.transactions,
        window_days=req.window_days,
        round_number_min=Decimal(req.round_number_min),
        business_hours=(req.business_hours_start, req.business_hours_end),
        new_vendor_threshold=Decimal(req.new_vendor_threshold),
        spike_multiplier=req.spike_multiplier,
    )
    by_severity: dict[str, int] = {"high": 0, "medium": 0, "low": 0}
    for f in findings:
        by_severity[f.severity] = by_severity.get(f.severity, 0) + 1
    return {
        "success": True,
        "data": {
            "count": len(findings),
            "by_severity": by_severity,
            "findings": [f.to_dict() for f in findings],
        },
    }
