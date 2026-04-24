"""AI HTTP surface — proactive scans, Ask APEX, and usage metering.

Three endpoints:

  POST /api/v1/ai/scan    — trigger every proactive scanner, return findings.
  POST /api/v1/ai/ask     — "اسأل أبكس" — NL question over the tenant's books
                            via the Copilot agent + tool-use loop.
  GET  /api/v1/ai/usage   — Claude token / cost summary for the calling tenant
                            in the current billing month.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Body, HTTPException, Query

from app.ai.proactive import run_all_scans
from app.core.api_version import v1_prefix

router = APIRouter(prefix=v1_prefix("/ai"), tags=["AI"])


# ── Proactive scanner ─────────────────────────────────────


@router.post("/scan")
def trigger_scan(
    tenant_id: Optional[str] = Query(None, description="Filter to one tenant"),
    emit_activity: bool = Query(
        True, description="Emit activity_log rows for each finding"
    ),
):
    """Run every registered proactive scan and return the summary."""
    summary = run_all_scans(tenant_id=tenant_id, emit_activity=emit_activity)
    return {"success": True, "data": summary}


# ── Ask APEX — NL Q&A over the books ──────────────────────


@router.post("/ask")
def ask_apex(
    payload: dict[str, Any] = Body(...),
):
    """Natural-language question over the tenant's financial data.

    Request
    -------
    {
      "query": "كم صرفنا على التسويق الشهر الماضي؟",
      "history": [                              # optional, for multi-turn
        {"role": "user", "content": "..."},
        {"role": "assistant", "content": "..."}
      ],
      "max_turns": 5                            # optional, default 5
    }

    Response (success)
    -----------------
    {
      "success": true,
      "data": {
        "answer": "صرفت 12,450 ريال على التسويق في مارس 2026 ...",
        "tool_calls": [
          {"name": "query_financial_data", "args": {...}, "result": {...}},
          ...
        ],
        "model": "claude-sonnet-4-5"
      }
    }

    Response (failure)
    -----------------
    HTTP 400 / 500 with `{"success": false, "error": "..."}`
    """
    query = (payload.get("query") or "").strip()
    if not query:
        raise HTTPException(status_code=400, detail="query is required")

    history = payload.get("history") or None
    max_turns = int(payload.get("max_turns") or 5)
    max_turns = max(1, min(10, max_turns))  # cap — never let a bad client burn 50 turns

    try:
        from app.services.copilot_agent import run_agent
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"agent unavailable: {e}")

    result = run_agent(
        user_query=query,
        conversation_history=history,
        max_turns=max_turns,
    )

    if not result.success:
        # Return 200 with success=false so the client can render the
        # degraded message inline rather than showing a toast error —
        # matches the convention used elsewhere in the project.
        return {
            "success": False,
            "error": result.error or "agent did not produce an answer",
            "data": {
                "answer": "",
                "tool_calls": result.tool_calls,
                "model": result.model,
            },
        }

    return {
        "success": True,
        "data": {
            "answer": result.answer,
            "tool_calls": result.tool_calls,
            "model": result.model,
        },
    }


# ── AI suggestions — human-in-the-loop approval ───────────


@router.get("/suggestions")
def list_ai_suggestions(
    status: Optional[str] = Query(
        None, description="Filter by status: needs_approval / approved / rejected / auto_applied"
    ),
    source: Optional[str] = Query(None, description="Filter by source (e.g. copilot_agent)"),
    tenant_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
):
    """Return AiSuggestion rows — the pending-approval queue for the UI.

    Default call (no filters) returns the most recent 50 suggestions
    across all statuses. Use `?status=needs_approval` for the approval
    inbox and `?status=approved` for the audit view.
    """
    try:
        from app.core.ai_guardrails import list_rows
        rows = list_rows(status=status, source=source, tenant_id=tenant_id, limit=limit)
        return {"success": True, "data": rows, "count": len(rows)}
    except Exception as e:
        return {"success": False, "error": str(e), "data": [], "count": 0}


@router.get("/suggestions/{suggestion_id}")
def get_ai_suggestion(suggestion_id: str):
    """Fetch one AiSuggestion row by id."""
    try:
        from app.core.ai_guardrails import get_row
        row = get_row(suggestion_id)
        if row is None:
            raise HTTPException(status_code=404, detail="suggestion not found")
        return {"success": True, "data": row}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/suggestions/{suggestion_id}/approve")
def approve_ai_suggestion(
    suggestion_id: str,
    payload: Optional[dict[str, Any]] = Body(None),
):
    """Human approves a NEEDS_APPROVAL suggestion.

    Approval flips the row's status + records an audit event. Actually
    *executing* the approved action (posting the invoice, dispatching
    the reminder) is a separate concern — a worker reads approved rows
    and performs the domain write. This endpoint only captures the
    human signal.
    """
    user_id = (payload or {}).get("user_id", "system")
    try:
        from app.core.ai_guardrails import approve
        verdict = approve(suggestion_id, user_id=user_id)
        return {"success": True, "data": {"id": suggestion_id, "verdict": verdict.value}}
    except LookupError:
        raise HTTPException(status_code=404, detail="suggestion not found")
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/suggestions/{suggestion_id}/execute")
def execute_ai_suggestion(suggestion_id: str):
    """Run the approved action. Only acts on rows with status='approved';
    flips them to 'executed' or 'failed'. Safe to call repeatedly on
    the same id — idempotent on terminal states.
    """
    try:
        from app.ai.approval_executor import execute_suggestion
        result = execute_suggestion(suggestion_id)
        return {
            "success": result.ok,
            "data": {
                "id": result.suggestion_id,
                "status": result.status,
                "detail": result.detail,
                "output": result.output,
            },
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/suggestions/execute-approved")
def drain_approved_suggestions(limit: int = Query(50, ge=1, le=500)):
    """Drain the approved-but-not-executed queue. Returns counters."""
    try:
        from app.ai.approval_executor import execute_all_approved
        return {"success": True, "data": execute_all_approved(limit=limit)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/suggestions/{suggestion_id}/reject")
def reject_ai_suggestion(
    suggestion_id: str,
    payload: Optional[dict[str, Any]] = Body(None),
):
    """Human rejects a suggestion. Idempotent."""
    payload = payload or {}
    user_id = payload.get("user_id", "system")
    reason = payload.get("reason")
    try:
        from app.core.ai_guardrails import reject
        verdict = reject(suggestion_id, user_id=user_id, reason=reason)
        return {"success": True, "data": {"id": suggestion_id, "verdict": verdict.value}}
    except LookupError:
        raise HTTPException(status_code=404, detail="suggestion not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Audit workflow — Benford / JE sample / workpapers ────


@router.post("/audit/benford")
def audit_benford(payload: dict[str, Any] = Body(...)):
    """Run Benford's Law test on a list of amounts or on the tenant's ledger.

    Body:
      { "amounts": [1234.5, 5678.9, ...] }   — explicit amounts
      OR
      { "start_date": "2026-01-01", "end_date": "2026-12-31" }
         — pull from journal lines in window
    """
    try:
        from app.core.audit_workflow import benford_analyze, benford_on_journal_entries
        amounts = payload.get("amounts")
        if isinstance(amounts, list) and amounts:
            return {"success": True, "data": benford_analyze(amounts).to_dict()}
        from datetime import date as _date
        sd = payload.get("start_date")
        ed = payload.get("end_date")
        result = benford_on_journal_entries(
            start_date=_date.fromisoformat(sd) if sd else None,
            end_date=_date.fromisoformat(ed) if ed else None,
        )
        return {"success": True, "data": result.to_dict()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/audit/je-sample")
def audit_je_sample(payload: dict[str, Any] = Body(...)):
    """Pull a deterministic JE sample for walkthrough testing."""
    try:
        from app.core.audit_workflow import sample_journal_entries
        from datetime import date as _date
        sd = payload.get("start_date")
        ed = payload.get("end_date")
        rows = sample_journal_entries(
            start_date=_date.fromisoformat(sd) if sd else None,
            end_date=_date.fromisoformat(ed) if ed else None,
            sample_size=int(payload.get("sample_size", 25)),
            threshold_amount=float(payload.get("threshold_amount", 10_000)),
            seed=str(payload.get("seed", "apex-audit-2026")),
        )
        return {"success": True, "data": rows, "count": len(rows)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/audit/workpapers")
def list_audit_workpapers():
    from app.core.audit_workflow import list_workpapers
    return {"success": True, "data": list_workpapers()}


@router.get("/audit/workpapers/{template_id}")
def get_audit_workpaper(template_id: str):
    from app.core.audit_workflow import get_workpaper
    tpl = get_workpaper(template_id)
    if tpl is None:
        raise HTTPException(status_code=404, detail="workpaper not found")
    return {"success": True, "data": tpl}


# ── Multi-entity consolidation ───────────────────────────


@router.post("/consolidation")
def run_consolidation(payload: dict[str, Any] = Body(...)):
    """Produce a consolidated TB from N entity TBs.

    Request shape (see app/core/consolidation.py docstring for full form):
      {
        "group_name": "APEX Group",
        "period_label": "FY 2025",
        "functional_currency": "SAR",
        "entities": [ {entity_id, currency, fx_rate_*, lines: [...]}, ... ]
      }
    """
    try:
        from app.core.consolidation import consolidate_from_dicts
        return {"success": True, "data": consolidate_from_dicts(payload)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Islamic finance (AAOIFI-aligned) ──────────────────────


@router.post("/islamic/murabaha")
def islamic_murabaha(payload: dict[str, Any] = Body(...)):
    try:
        from app.core.islamic_finance import murabaha_schedule
        return {"success": True, "data": murabaha_schedule(
            cost_price=float(payload["cost_price"]),
            selling_price=float(payload["selling_price"]),
            start_date=str(payload["start_date"]),
            installments=int(payload["installments"]),
            period_days=int(payload.get("period_days", 30)),
        )}
    except KeyError as ke:
        raise HTTPException(status_code=400, detail=f"missing field: {ke}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/islamic/ijarah")
def islamic_ijarah(payload: dict[str, Any] = Body(...)):
    try:
        from app.core.islamic_finance import ijarah_schedule
        return {"success": True, "data": ijarah_schedule(
            rental_per_period=float(payload["rental_per_period"]),
            periods=int(payload["periods"]),
            start_date=str(payload["start_date"]),
            period_days=int(payload.get("period_days", 30)),
            asset_value=float(payload.get("asset_value", 0)),
            useful_life_periods=int(payload.get("useful_life_periods", 0)),
        )}
    except KeyError as ke:
        raise HTTPException(status_code=400, detail=f"missing field: {ke}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/islamic/zakah")
def islamic_zakah(payload: dict[str, Any] = Body(...)):
    try:
        from app.core.islamic_finance import zakah_base
        return {"success": True, "data": zakah_base(
            current_assets=float(payload.get("current_assets", 0)),
            investments_for_trade=float(payload.get("investments_for_trade", 0)),
            fixed_assets_net=float(payload.get("fixed_assets_net", 0)),
            intangibles=float(payload.get("intangibles", 0)),
            current_liabilities=float(payload.get("current_liabilities", 0)),
            long_term_liabilities_due_within_year=float(
                payload.get("long_term_liabilities_due_within_year", 0)
            ),
            tax_rate_pct=float(payload.get("tax_rate_pct", 2.5)),
        )}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Industry-specific COA templates ──────────────────────


@router.get("/coa-templates")
def list_coa_templates():
    """Return industry COA templates for the onboarding picker."""
    try:
        from app.core.coa_industry_templates import list_templates
        return {"success": True, "data": list_templates()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/coa-templates/{template_id}")
def get_coa_template(template_id: str):
    """Return one template with its full account list."""
    try:
        from app.core.coa_industry_templates import get_template
        tpl = get_template(template_id)
        if tpl is None:
            raise HTTPException(status_code=404, detail="template not found")
        return {"success": True, "data": tpl}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Bank reconciliation — AI-assisted matching ────────────


@router.get("/bank-rec/suggestions/{txn_id}")
def get_bank_rec_suggestions(
    txn_id: str,
    limit: int = Query(5, ge=1, le=20),
    min_confidence: float = Query(0.30, ge=0.0, le=1.0),
):
    """Return candidate journal entries that likely match a bank txn."""
    try:
        from app.core.bank_reconciliation_ai import suggest_matches_for_transaction
        items = suggest_matches_for_transaction(
            txn_id=txn_id, limit=limit, min_confidence=min_confidence,
        )
        return {"success": True, "data": items, "count": len(items)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bank-rec/auto-match")
def run_auto_match(
    limit: int = Query(100, ge=1, le=500),
    confidence_floor: float = Query(0.95, ge=0.7, le=1.0),
    tenant_id: Optional[str] = Query(None),
):
    """Batch-apply high-confidence matches. Used by the "Auto-match
    overnight" scheduler + the "Match all" button on the bank-rec UI."""
    try:
        from app.core.bank_reconciliation_ai import auto_match_all
        return {
            "success": True,
            "data": auto_match_all(
                tenant_id=tenant_id,
                confidence_floor=confidence_floor,
                limit=limit,
            ),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Tax timeline — upcoming obligations ───────────────────


@router.get("/tax-timeline")
def get_tax_timeline(
    horizon_days: int = Query(120, ge=1, le=365),
    country: str = Query("sa"),
    vat_cadence: str = Query("monthly"),
    fiscal_year_end: Optional[str] = Query(None),
    zatca_csid_expires_at: Optional[str] = Query(None),
):
    """Return upcoming tax/compliance obligations as a visual timeline.

    Lightweight + deterministic — no external API calls. The tenant
    profile comes in as query args; when tenant storage lands, replace
    the query args with a DB lookup by tenant_id.
    """
    try:
        from app.core.tax_timeline import upcoming_obligations
        profile = {
            "country": country,
            "vat_cadence": vat_cadence,
            "fiscal_year_end": fiscal_year_end,
            "zatca_csid_expires_at": zatca_csid_expires_at,
        }
        rows = upcoming_obligations(
            horizon_days=horizon_days,
            tenant_profile=profile,
        )
        return {"success": True, "data": rows, "count": len(rows)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Usage / cost summary ─────────────────────────────────


@router.get("/usage")
def get_ai_usage(
    tenant_id: Optional[str] = Query(
        None,
        description="Tenant to query. If omitted, resolved from request context.",
    ),
    since: Optional[str] = Query(
        None,
        description="ISO-8601 datetime lower bound. Default: first of current month.",
    ),
):
    """Return the caller tenant's Claude consumption for the period.

    Used by the billing/entitlements layer and by the "AI usage" widget
    in the admin dashboard. Silent on a fresh DB (zeros) — never 500s.
    """
    # Resolve tenant if not passed explicitly.
    tid = tenant_id
    if not tid:
        try:
            from app.core.tenant_guard import current_tenant
            tid = current_tenant() or None
        except Exception:
            tid = None
    if not tid:
        raise HTTPException(status_code=400, detail="tenant_id not resolvable")

    since_dt: Optional[datetime] = None
    if since:
        try:
            since_dt = datetime.fromisoformat(since.replace("Z", "+00:00"))
        except Exception:
            raise HTTPException(status_code=400, detail="invalid 'since' — use ISO-8601")

    try:
        from app.core.ai_usage_log import tenant_usage_summary
        summary = tenant_usage_summary(tenant_id=tid, since=since_dt)
        return {"success": True, "data": summary}
    except Exception as e:
        # Never 500 on the usage endpoint — it's a telemetry view, not a
        # business-critical path. Degrade to a zero summary.
        return {
            "success": True,
            "data": {
                "tenant_id": tid,
                "input_tokens": 0,
                "output_tokens": 0,
                "cost_usd": 0.0,
                "calls": 0,
                "_note": f"usage summary degraded: {e.__class__.__name__}",
            },
        }
