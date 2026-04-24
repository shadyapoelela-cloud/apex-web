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

    # Soft-enforce per-tier quota — deny if monthly calls/cost exhausted.
    try:
        from app.core.ai_rate_limits import check_quota
        from app.core.tenant_guard import current_tenant
        qd = check_quota(current_tenant())
        if not qd.allowed:
            return {
                "success": False,
                "error": qd.reason or "quota exhausted",
                "data": {"answer": "", "tool_calls": [], "model": "", "quota": qd.to_dict()},
            }
    except Exception:
        pass

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


# ── Audit hash-chain integrity ───────────────────────────


# ── Period close checklist (NetSuite pattern) ────────────


@router.post("/period-close/start")
def start_period_close(payload: dict[str, Any] = Body(...)):
    """Start a new close cycle with the default 12-task template."""
    try:
        from app.core.period_close import start_close
        close_id = start_close(
            tenant_id=str(payload["tenant_id"]),
            entity_id=str(payload["entity_id"]),
            fiscal_period_id=str(payload["fiscal_period_id"]),
            period_code=str(payload["period_code"]),
        )
        return {"success": True, "data": {"close_id": close_id}}
    except KeyError as ke:
        raise HTTPException(status_code=400, detail=f"missing field: {ke}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/period-close/tasks/{task_id}/complete")
def complete_period_close_task(task_id: str, payload: Optional[dict[str, Any]] = Body(None)):
    payload = payload or {}
    try:
        from app.core.period_close import complete_task
        out = complete_task(
            task_id=task_id,
            user_id=str(payload.get("user_id", "system")),
            notes=payload.get("notes"),
        )
        return {"success": out.get("ok", False), "data": out}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/period-close/{close_id}")
def get_period_close(close_id: str):
    try:
        from app.core.period_close import get_close
        c = get_close(close_id)
        if c is None:
            raise HTTPException(status_code=404, detail="close not found")
        return {"success": True, "data": c}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/period-close")
def list_period_closes(
    tenant_id: Optional[str] = Query(None),
    entity_id: Optional[str] = Query(None),
):
    try:
        from app.core.period_close import list_closes
        return {"success": True, "data": list_closes(tenant_id=tenant_id, entity_id=entity_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Onboarding — create tenant + entity + seed COA in one call ──


@router.post("/onboarding/complete")
def onboarding_complete(payload: dict[str, Any] = Body(...)):
    """Complete onboarding end-to-end:
    1. Create Tenant + primary Entity
    2. Seed the industry-specific CoA (via gl_engine + template)
    3. Seed 12 monthly fiscal periods for current year
    """
    try:
        from datetime import date, datetime, timezone, timedelta
        from app.phase1.models.platform_models import SessionLocal, gen_uuid
        from app.pilot.models import (
            Tenant, Entity, GLAccount, FiscalPeriod, PeriodStatus,
        )
        from app.core.coa_industry_templates import get_template

        name = str(payload.get("company_name", "")).strip()
        country = str(payload.get("country", "sa"))
        vat = str(payload.get("vat_number", "")).strip() or None
        industry_id = str(payload.get("industry", "")).strip()
        email = str(payload.get("email", "")).strip() or f"owner@{name.lower().replace(' ', '-')[:30] or 'example'}.local"

        if not name:
            raise HTTPException(status_code=400, detail="company_name required")

        ccy = {"sa": "SAR", "ae": "AED", "eg": "EGP", "om": "OMR", "bh": "BHD"}.get(country, "SAR")
        import re
        slug_base = re.sub(r"[^a-z0-9-]", "", name.lower().replace(" ", "-"))[:50] or "tenant"

        db = SessionLocal()
        accounts_created = 0
        periods_created = 0
        try:
            # 1. Tenant
            slug = slug_base
            i = 1
            while db.query(Tenant).filter(Tenant.slug == slug).first() is not None:
                slug = f"{slug_base}-{i}"
                i += 1

            tenant = Tenant(
                id=gen_uuid(),
                slug=slug,
                legal_name_ar=name,
                primary_vat_number=vat,
                primary_country=country.upper(),
                primary_email=email,
                status="trial",
                tier="starter",
            )
            db.add(tenant)
            db.flush()

            # 2. Entity
            entity = Entity(
                id=gen_uuid(),
                tenant_id=tenant.id,
                code=(name[:10].upper().replace(" ", "-") or "ENT-001"),
                name_ar=name,
                type="company",
                status="active",
                country=country.upper(),
                vat_number=vat,
                functional_currency=ccy,
                fiscal_year_start_month=1,
            )
            db.add(entity)
            db.flush()

            # 3. Seed Chart of Accounts
            try:
                from app.pilot.services.gl_engine import DEFAULT_COA
                code_to_id: dict[str, str] = {}
                for acct in DEFAULT_COA:
                    parent_id = code_to_id.get(acct.get("parent")) if acct.get("parent") else None
                    row = GLAccount(
                        id=gen_uuid(),
                        tenant_id=tenant.id,
                        entity_id=entity.id,
                        parent_account_id=parent_id,
                        code=acct["code"],
                        name_ar=acct["name_ar"],
                        name_en=acct.get("name_en"),
                        category=acct["category"],
                        subcategory=acct.get("subcategory"),
                        type=acct.get("type", "detail"),
                        normal_balance=acct["normal_balance"],
                        level=acct.get("level", 1),
                        is_control=acct.get("is_control", False),
                    )
                    db.add(row)
                    db.flush()
                    code_to_id[acct["code"]] = row.id
                    accounts_created += 1

                # Industry overlay
                if industry_id:
                    tpl = get_template(industry_id)
                    if tpl:
                        for acct in tpl["accounts"]:
                            if acct["code"] in code_to_id:
                                continue
                            parent_id = code_to_id.get(acct.get("parent")) if acct.get("parent") else None
                            row = GLAccount(
                                id=gen_uuid(),
                                tenant_id=tenant.id,
                                entity_id=entity.id,
                                parent_account_id=parent_id,
                                code=acct["code"],
                                name_ar=acct["name_ar"],
                                name_en=acct.get("name_en"),
                                category=acct["category"],
                                subcategory=acct.get("subcategory"),
                                type=acct.get("type", "detail"),
                                normal_balance=acct["normal_balance"],
                                level=acct.get("level", 3),
                                is_control=acct.get("is_control", False),
                            )
                            db.add(row)
                            db.flush()
                            code_to_id[acct["code"]] = row.id
                            accounts_created += 1
            except Exception as coa_err:
                import logging
                logging.warning(f"COA seed skipped: {coa_err}")

            # 4. Fiscal periods
            try:
                year = date.today().year
                months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
                          'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر']
                for m in range(1, 13):
                    start = date(year, m, 1)
                    end = date(year, 12, 31) if m == 12 else (date(year, m + 1, 1) - timedelta(days=1))
                    db.add(FiscalPeriod(
                        id=gen_uuid(),
                        tenant_id=tenant.id,
                        entity_id=entity.id,
                        code=f"{year}-{m:02d}",
                        name_ar=f"{months[m-1]} {year}",
                        year=year,
                        month=m,
                        start_date=start,
                        end_date=end,
                        status=PeriodStatus.open.value,
                    ))
                    periods_created += 1
            except Exception as fp_err:
                import logging
                logging.warning(f"Fiscal period seed skipped: {fp_err}")

            db.commit()
            return {
                "success": True,
                "data": {
                    "tenant_id": tenant.id,
                    "tenant_slug": tenant.slug,
                    "entity_id": entity.id,
                    "industry": industry_id or None,
                    "accounts_created": accounts_created,
                    "periods_created": periods_created,
                    "functional_currency": ccy,
                },
            }
        finally:
            db.close()
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/onboarding/seed-demo")
def onboarding_seed_demo(payload: dict[str, Any] = Body(...)):
    """Seed a demo company with sample customers + 3 demo journal
    entries (opening capital + revenue + expense) so the user sees
    a fully populated system on day 1."""
    try:
        from datetime import date, datetime, timezone
        from decimal import Decimal
        from app.phase1.models.platform_models import SessionLocal, gen_uuid
        from app.pilot.models import (
            Customer, Entity, FiscalPeriod, GLAccount,
            JournalEntry, JournalEntryKind, JournalEntryStatus,
            JournalLine, PeriodStatus,
        )

        tenant_id = str(payload.get("tenant_id", "")).strip()
        entity_id = str(payload.get("entity_id", "")).strip()
        if not tenant_id or not entity_id:
            raise HTTPException(status_code=400, detail="tenant_id + entity_id required")

        db = SessionLocal()
        customers_created = 0
        jes_created = 0
        try:
            entity = db.query(Entity).filter(Entity.id == entity_id).first()
            if entity is None:
                raise HTTPException(status_code=404, detail="entity not found")

            sample_customers = [
                ("CUST-0001", "شركة الرياض للمقاولات", "300111111300003", "0501234567"),
                ("CUST-0002", "مؤسسة الخليج التجارية", "300222222300003", "0502345678"),
                ("CUST-0003", "مجموعة أرامكو للخدمات", "300333333300003", "0503456789"),
                ("CUST-0004", "شركة جدة للتطوير", "300444444300003", "0504567890"),
                ("CUST-0005", "شركة الدمام للصناعة", "300555555300003", "0505678901"),
            ]
            for code, name_ar, vat, phone in sample_customers:
                exists = db.query(Customer).filter(
                    Customer.tenant_id == tenant_id, Customer.code == code,
                ).first()
                if exists is None:
                    db.add(Customer(
                        id=gen_uuid(), tenant_id=tenant_id, code=code,
                        name_ar=name_ar, kind="company",
                        phone=phone, vat_number=vat,
                        currency=entity.functional_currency,
                    ))
                    customers_created += 1

            period = db.query(FiscalPeriod).filter(
                FiscalPeriod.entity_id == entity_id,
                FiscalPeriod.status == PeriodStatus.open.value,
            ).order_by(FiscalPeriod.start_date).first()

            if period is not None:
                cash = db.query(GLAccount).filter(
                    GLAccount.entity_id == entity_id, GLAccount.code == "1120",
                ).first()
                capital = db.query(GLAccount).filter(
                    GLAccount.entity_id == entity_id, GLAccount.category == "equity",
                    GLAccount.type == "detail",
                ).first()
                revenue = db.query(GLAccount).filter(
                    GLAccount.entity_id == entity_id, GLAccount.category == "revenue",
                    GLAccount.type == "detail",
                ).first()
                expense = db.query(GLAccount).filter(
                    GLAccount.entity_id == entity_id, GLAccount.category == "expense",
                    GLAccount.type == "detail",
                ).first()

                demos = [
                    ("JE-DEMO-001", "رأس المال الافتتاحي", JournalEntryKind.opening.value,
                     Decimal("1000000"), cash, capital, "إيداع نقدي", "رأس المال"),
                    ("JE-DEMO-002", "إيراد مبيعات نقدية", JournalEntryKind.manual.value,
                     Decimal("50000"), cash, revenue, "قبض نقدي", "مبيعات"),
                    ("JE-DEMO-003", "مصاريف تشغيلية",  JournalEntryKind.manual.value,
                     Decimal("15000"), expense, cash, "مصاريف", "دفع"),
                ]
                for num, memo, kind, amount, dr_acc, cr_acc, dr_desc, cr_desc in demos:
                    if not (dr_acc and cr_acc):
                        continue
                    je = JournalEntry(
                        id=gen_uuid(), tenant_id=tenant_id, entity_id=entity_id,
                        fiscal_period_id=period.id,
                        je_number=num, kind=kind,
                        status=JournalEntryStatus.draft.value,    # posted below via post_journal_entry
                        memo_ar=memo,
                        je_date=period.start_date,
                        currency=entity.functional_currency,
                        total_debit=amount, total_credit=amount,
                    )
                    db.add(je)
                    db.flush()
                    db.add(JournalLine(
                        id=gen_uuid(), tenant_id=tenant_id, journal_entry_id=je.id,
                        line_number=1, account_id=dr_acc.id,
                        currency=entity.functional_currency,
                        debit_amount=amount, credit_amount=0,
                        functional_debit=amount, functional_credit=0,
                        description=dr_desc,
                    ))
                    db.add(JournalLine(
                        id=gen_uuid(), tenant_id=tenant_id, journal_entry_id=je.id,
                        line_number=2, account_id=cr_acc.id,
                        currency=entity.functional_currency,
                        debit_amount=0, credit_amount=amount,
                        functional_debit=0, functional_credit=amount,
                        description=cr_desc,
                    ))
                    # Actually post to GL (creates GLPosting rows).
                    try:
                        from app.pilot.services.gl_engine import post_journal_entry
                        db.flush()   # make sure JE+lines are persisted before posting
                        post_journal_entry(db, je.id)
                    except Exception as _pe:
                        import logging
                        logging.warning(f"demo post_journal_entry failed: {_pe}")
                    jes_created += 1

            db.commit()
            return {
                "success": True,
                "data": {
                    "customers_created": customers_created,
                    "journal_entries_created": jes_created,
                },
            }
        finally:
            db.close()
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ── SAP-style Universal Journal ──────────────────────────


@router.post("/universal-journal/query")
def universal_journal_query(payload: dict[str, Any] = Body(...)):
    """Pull ACDOCA-style rows — one flat view over all finance postings."""
    try:
        from app.core.universal_journal import query_universal_journal
        from datetime import date as _date
        sd = payload.get("start_date")
        ed = payload.get("end_date")
        rows = query_universal_journal(
            tenant_id=payload.get("tenant_id"),
            entity_id=payload.get("entity_id"),
            start_date=_date.fromisoformat(sd) if sd else None,
            end_date=_date.fromisoformat(ed) if ed else None,
            account_codes=payload.get("account_codes"),
            account_categories=payload.get("account_categories"),
            source_types=payload.get("source_types"),
            status=payload.get("status", "posted"),
            ledger_id=payload.get("ledger_id", "L1"),
            partner_id=payload.get("partner_id"),
            dimension_filters=payload.get("dimension_filters"),
            limit=int(payload.get("limit", 500)),
            offset=int(payload.get("offset", 0)),
        )
        return {"success": True, "data": rows, "count": len(rows)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/universal-journal/document-flow/{source_type}/{source_id}")
def universal_journal_document_flow(source_type: str, source_id: str):
    """SAP-pattern bidirectional document flow."""
    try:
        from app.core.universal_journal import document_flow
        return {"success": True, "data": document_flow(source_type, source_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/audit/chain/verify")
def verify_audit_chain_endpoint(limit: int = Query(1000, ge=1, le=50_000)):
    """Walk the audit_trail hash chain and verify each row's hash.
    Returns {ok, verified, first_mismatch}."""
    try:
        from app.core.compliance_service import verify_audit_chain
        return {"success": True, "data": verify_audit_chain(limit=limit)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/audit/chain/events")
def list_audit_events(limit: int = Query(50, ge=1, le=500)):
    """Return the latest audit events with hash + prev_hash for the UI."""
    try:
        from app.phase1.models.platform_models import SessionLocal
        from app.core.compliance_models import AuditTrail
        db = SessionLocal()
        try:
            rows = (
                db.query(AuditTrail)
                .order_by(AuditTrail.created_at.desc())
                .limit(limit)
                .all()
            )
            data = [{
                "id": r.id,
                "action": r.action,
                "entity_type": r.entity_type,
                "entity_id": r.entity_id,
                "actor_user_id": r.actor_user_id,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "prev_hash": r.prev_hash,
                "this_hash": r.this_hash,
                "chain_seq": r.chain_seq,
            } for r in rows]
            return {"success": True, "data": data, "count": len(data)}
        finally:
            db.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Regulatory news feed ─────────────────────────────────


@router.get("/regulatory-news")
def list_regulatory_news(
    jurisdiction: Optional[str] = Query(None),
    only_future: bool = Query(False),
    limit: int = Query(20, ge=1, le=100),
):
    try:
        from app.core.regulatory_news import list_news
        return {"success": True, "data": list_news(
            jurisdiction=jurisdiction, only_future=only_future, limit=limit,
        )}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/regulatory-news/{item_id}")
def get_regulatory_news(item_id: str):
    from app.core.regulatory_news import get_news
    item = get_news(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="news item not found")
    return {"success": True, "data": item}


# ── Fixed-asset depreciation (IAS 16) ────────────────────


@router.post("/fixed-assets/schedule")
def build_depreciation_schedule(payload: dict[str, Any] = Body(...)):
    """Generate a depreciation schedule. Method is 'straight_line' (default),
    'declining_balance', 'double_declining', or 'units_of_production'.
    """
    method = str(payload.get("method", "straight_line")).lower()
    try:
        from app.core import fixed_assets as fa
        if method == "straight_line":
            r = fa.straight_line(
                cost=float(payload["cost"]),
                salvage=float(payload.get("salvage", 0)),
                useful_life_periods=int(payload["useful_life_periods"]),
            )
        elif method == "declining_balance":
            r = fa.declining_balance(
                cost=float(payload["cost"]),
                salvage=float(payload.get("salvage", 0)),
                useful_life_periods=int(payload["useful_life_periods"]),
                rate_pct=payload.get("rate_pct"),
            )
        elif method == "double_declining":
            r = fa.double_declining(
                cost=float(payload["cost"]),
                salvage=float(payload.get("salvage", 0)),
                useful_life_periods=int(payload["useful_life_periods"]),
            )
        elif method == "units_of_production":
            r = fa.units_of_production(
                cost=float(payload["cost"]),
                salvage=float(payload.get("salvage", 0)),
                total_units_lifetime=float(payload["total_units_lifetime"]),
                units_per_period=list(payload.get("units_per_period", [])),
            )
        else:
            raise HTTPException(status_code=400, detail=f"unknown method: {method}")
        return {"success": True, "data": r}
    except KeyError as ke:
        raise HTTPException(status_code=400, detail=f"missing field: {ke}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Multi-currency dashboard ─────────────────────────────


@router.get("/multi-currency/dashboard")
def multi_currency_dashboard(
    display_currency: str = Query("SAR"),
    tenant_id: Optional[str] = Query(None),
):
    try:
        from app.core.multi_currency import dashboard
        return {"success": True, "data": dashboard(
            display_currency=display_currency, tenant_id=tenant_id,
        )}
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
