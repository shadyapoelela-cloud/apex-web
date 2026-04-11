"""
APEX Sprint 5 — Analysis Trigger Routes
APIs to run financial analysis using approved COA + TB binding.
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional
import json
import logging
from app.core.db_utils import get_db_session as _db, exec_sql as _exec


class RunAnalysisRequest(BaseModel):
    client_id: str = Field(..., description="Client ID")
    tb_upload_id: str = Field(..., description="Trial balance upload ID")
    industry: str = Field("general", description="Industry sector")
    closing_inventory: Optional[float] = Field(None, description="Closing inventory value")
    triggered_by: Optional[str] = Field(None, description="Who triggered the analysis")


router = APIRouter()


# ══════════════════════════════════════════════════════════════
# 1. Validate preconditions before analysis
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/validate/{client_id}/{tb_upload_id}", tags=["Analysis Trigger"])
def validate_analysis(client_id: str, tb_upload_id: str):
    """Check if analysis can proceed for this client + TB."""
    db = _db()
    try:
        from app.sprint5_analysis.services.analysis_trigger_service import (
            validate_analysis_preconditions,
        )

        result = validate_analysis_preconditions(db, client_id, tb_upload_id)
        return {"success": True, "data": result}
    except HTTPException:
        raise
    except Exception as e:
        logging.error("Analysis validation failed", exc_info=True)
        raise HTTPException(500, "Analysis validation failed")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 2. Run COA-aware analysis
# ══════════════════════════════════════════════════════════════
@router.post("/analysis/run", tags=["Analysis Trigger"])
def run_analysis(body: RunAnalysisRequest):
    """
    Run financial analysis using approved COA mapping + TB binding.
    Required: client_id, tb_upload_id
    Optional: industry, closing_inventory
    """
    client_id = body.client_id
    tb_upload_id = body.tb_upload_id

    industry = body.industry
    closing_inventory = body.closing_inventory

    db = _db()
    try:
        from app.sprint5_analysis.services.analysis_trigger_service import (
            run_coa_aware_analysis,
        )

        result = run_coa_aware_analysis(
            db,
            client_id,
            tb_upload_id,
            industry=industry,
            closing_inventory=closing_inventory,
            triggered_by=body.triggered_by,
        )
        if not result.get("success"):
            raise HTTPException(400, result)
        return result
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 3. Get analysis run by ID
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/runs/{run_id}", tags=["Analysis Trigger"])
def get_analysis_run(run_id: str):
    """Get a specific analysis run with all results."""
    db = _db()
    try:
        row = _exec(
            db,
            """SELECT id, client_id, tb_upload_id, coa_upload_id,
                      run_status, industry, overall_confidence,
                      total_accounts_analyzed, matched_accounts, unmatched_accounts,
                      binding_quality_score,
                      income_statement_json, balance_sheet_json,
                      cash_flow_json, ratios_json, readiness_json,
                      validations_json, knowledge_brain_json,
                      classification_json, warnings_json,
                      error_message, created_at, completed_at
               FROM analysis_runs WHERE id = :id""",
            {"id": run_id},
        ).fetchone()
        if not row:
            raise HTTPException(404, "Analysis run not found")

        def _parse(val):
            if val is None:
                return None
            if isinstance(val, str):
                try:
                    return json.loads(val)
                except Exception:
                    return val
            return val

        return {
            "success": True,
            "data": {
                "id": row[0],
                "client_id": row[1],
                "tb_upload_id": row[2],
                "coa_upload_id": row[3],
                "run_status": row[4],
                "industry": row[5],
                "overall_confidence": row[6],
                "total_accounts_analyzed": row[7],
                "matched_accounts": row[8],
                "unmatched_accounts": row[9],
                "binding_quality_score": row[10],
                "income_statement": _parse(row[11]),
                "balance_sheet": _parse(row[12]),
                "cash_flow": _parse(row[13]),
                "ratios": _parse(row[14]),
                "readiness": _parse(row[15]),
                "validations": _parse(row[16]),
                "knowledge_brain": _parse(row[17]),
                "classification": _parse(row[18]),
                "warnings": _parse(row[19]),
                "error_message": row[20],
                "created_at": row[21],
                "completed_at": row[22],
            },
        }
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 4. List analysis runs for a client
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/client/{client_id}/runs", tags=["Analysis Trigger"])
def list_client_runs(
    client_id: str, status: Optional[str] = None, page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100)
):
    """List analysis runs for a client."""
    db = _db()
    try:
        where = "WHERE client_id = :cid"
        params = {"cid": client_id}
        if status:
            where += " AND run_status = :st"
            params["st"] = status

        total = _exec(db, f"SELECT count(*) FROM analysis_runs {where}", params).scalar() or 0

        offset = (page - 1) * page_size
        params["lim"] = page_size
        params["off"] = offset

        rows = _exec(
            db,
            f"""SELECT id, tb_upload_id, coa_upload_id, run_status,
                       industry, overall_confidence,
                       total_accounts_analyzed, matched_accounts,
                       binding_quality_score, created_at, completed_at
                FROM analysis_runs {where}
                ORDER BY created_at DESC LIMIT :lim OFFSET :off""",
            params,
        ).fetchall()

        return {
            "success": True,
            "data": {
                "runs": [
                    {
                        "id": r[0],
                        "tb_upload_id": r[1],
                        "coa_upload_id": r[2],
                        "run_status": r[3],
                        "industry": r[4],
                        "overall_confidence": r[5],
                        "total_accounts_analyzed": r[6],
                        "matched_accounts": r[7],
                        "binding_quality_score": r[8],
                        "created_at": r[9],
                        "completed_at": r[10],
                    }
                    for r in rows
                ],
                "total": total,
                "page": page,
                "page_size": page_size,
            },
        }
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 5. Get income statement from latest completed run
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/client/{client_id}/income-statement", tags=["Analysis Trigger"])
def get_latest_income_statement(client_id: str):
    """Get income statement from the latest completed analysis."""
    db = _db()
    try:
        row = _exec(
            db,
            """SELECT id, income_statement_json, overall_confidence, created_at
               FROM analysis_runs
               WHERE client_id = :cid AND run_status = 'completed'
               ORDER BY created_at DESC LIMIT 1""",
            {"cid": client_id},
        ).fetchone()
        if not row:
            raise HTTPException(404, "No completed analysis found for this client")
        return {
            "success": True,
            "data": {
                "analysis_run_id": row[0],
                "income_statement": json.loads(row[1]) if isinstance(row[1], str) else row[1],
                "confidence": row[2],
                "created_at": row[3],
            },
        }
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 6. Get balance sheet from latest completed run
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/client/{client_id}/balance-sheet", tags=["Analysis Trigger"])
def get_latest_balance_sheet(client_id: str):
    """Get balance sheet from the latest completed analysis."""
    db = _db()
    try:
        row = _exec(
            db,
            """SELECT id, balance_sheet_json, overall_confidence, created_at
               FROM analysis_runs
               WHERE client_id = :cid AND run_status = 'completed'
               ORDER BY created_at DESC LIMIT 1""",
            {"cid": client_id},
        ).fetchone()
        if not row:
            raise HTTPException(404, "No completed analysis found for this client")
        return {
            "success": True,
            "data": {
                "analysis_run_id": row[0],
                "balance_sheet": json.loads(row[1]) if isinstance(row[1], str) else row[1],
                "confidence": row[2],
                "created_at": row[3],
            },
        }
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 7. Get full financial report (all statements + ratios)
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/client/{client_id}/full-report", tags=["Analysis Trigger"])
def get_full_report(client_id: str):
    """Get complete financial report from latest completed analysis."""
    db = _db()
    try:
        row = _exec(
            db,
            """SELECT id, income_statement_json, balance_sheet_json,
                      cash_flow_json, ratios_json, readiness_json,
                      validations_json, knowledge_brain_json,
                      classification_json, warnings_json,
                      overall_confidence, industry,
                      total_accounts_analyzed, matched_accounts,
                      unmatched_accounts, binding_quality_score,
                      created_at, completed_at
               FROM analysis_runs
               WHERE client_id = :cid AND run_status = 'completed'
               ORDER BY created_at DESC LIMIT 1""",
            {"cid": client_id},
        ).fetchone()
        if not row:
            raise HTTPException(404, "No completed analysis found for this client")

        def _p(v):
            if v is None:
                return None
            if isinstance(v, str):
                try:
                    return json.loads(v)
                except Exception:
                    return v
            return v

        return {
            "success": True,
            "data": {
                "analysis_run_id": row[0],
                "income_statement": _p(row[1]),
                "balance_sheet": _p(row[2]),
                "cash_flow": _p(row[3]),
                "ratios": _p(row[4]),
                "readiness": _p(row[5]),
                "validations": _p(row[6]),
                "knowledge_brain": _p(row[7]),
                "classification": _p(row[8]),
                "warnings": _p(row[9]),
                "confidence": row[10],
                "industry": row[11],
                "total_accounts": row[12],
                "matched_accounts": row[13],
                "unmatched_accounts": row[14],
                "binding_quality_score": row[15],
                "created_at": row[16],
                "completed_at": row[17],
            },
        }
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════
# 8. Compare two analysis runs
# ══════════════════════════════════════════════════════════════
@router.get("/analysis/compare/{run_id_1}/{run_id_2}", tags=["Analysis Trigger"])
def compare_runs(run_id_1: str, run_id_2: str):
    """Compare two analysis runs side by side."""
    db = _db()
    try:

        def _get(rid):
            r = _exec(
                db,
                """SELECT id, run_status, overall_confidence,
                          income_statement_json, balance_sheet_json,
                          ratios_json, created_at
                   FROM analysis_runs WHERE id = :id""",
                {"id": rid},
            ).fetchone()
            if not r:
                raise HTTPException(404, f"Run {rid} not found")

            def _p(v):
                if v and isinstance(v, str):
                    try:
                        return json.loads(v)
                    except Exception:
                        return v
                return v

            return {
                "id": r[0],
                "status": r[1],
                "confidence": r[2],
                "income_statement": _p(r[3]),
                "balance_sheet": _p(r[4]),
                "ratios": _p(r[5]),
                "created_at": r[6],
            }

        r1 = _get(run_id_1)
        r2 = _get(run_id_2)

        # Calculate deltas for key metrics
        deltas = {}
        for key in ["net_profit", "total_revenue", "total_assets", "total_liabilities"]:
            v1 = (r1.get("income_statement") or r1.get("balance_sheet") or {}).get(key, 0) or 0
            v2 = (r2.get("income_statement") or r2.get("balance_sheet") or {}).get(key, 0) or 0
            deltas[key] = {"run_1": v1, "run_2": v2, "delta": v2 - v1}

        return {
            "success": True,
            "data": {
                "run_1": r1,
                "run_2": r2,
                "deltas": deltas,
                "confidence_delta": (r2.get("confidence") or 0) - (r1.get("confidence") or 0),
            },
        }
    finally:
        db.close()
