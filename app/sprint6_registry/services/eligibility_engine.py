"""
APEX Sprint 6 — Eligibility Engine Service
Evaluates client eligibility for funding, support, and licensing programs.
Uses approved financial data from analysis runs + client profile.
"""

import json
from datetime import datetime, timezone
from sqlalchemy import text as _t


def _db():
    from app.phase1.models.platform_models import SessionLocal
    return SessionLocal()

def _now():
    return datetime.now(timezone.utc)

def _exec(db, sql, params=None):
    if params:
        return db.execute(_t(sql), params)
    return db.execute(_t(sql))


def get_client_financial_snapshot(db, client_id: str) -> dict | None:
    """Get latest completed analysis for the client."""
    row = _exec(db,
        """SELECT id, income_statement_json, balance_sheet_json,
                  ratios_json, overall_confidence, industry
           FROM analysis_runs
           WHERE client_id = :cid AND run_status = 'completed'
           ORDER BY created_at DESC LIMIT 1""",
        {"cid": client_id}).fetchone()
    if not row:
        return None

    def _p(v):
        if v is None: return {}
        if isinstance(v, str):
            try: return json.loads(v)
            except: return {}
        return v if isinstance(v, dict) else {}

    return {
        "analysis_run_id": row[0],
        "income": _p(row[1]),
        "balance": _p(row[2]),
        "ratios": _p(row[3]),
        "confidence": row[4] or 0,
        "industry": row[5] or "general",
    }


def get_client_profile(db, client_id: str) -> dict | None:
    """Get client profile info."""
    row = _exec(db,
        """SELECT id, name, client_type, industry, country
           FROM clients WHERE id = :cid""",
        {"cid": client_id}).fetchone()
    if not row:
        return None
    return {
        "id": row[0], "name": row[1], "client_type": row[2],
        "industry": row[3], "country": row[4],
    }


# ══════════════════════════════════════════════════════════════
# FUNDING ELIGIBILITY ENGINE
# ══════════════════════════════════════════════════════════════

def assess_funding_eligibility(db, client_id: str, program_id: str | None = None) -> list[dict]:
    """
    Assess client eligibility for funding programs.
    If program_id is None, checks all active programs.
    """
    import uuid

    client = get_client_profile(db, client_id)
    if not client:
        return [{"error": "العميل غير موجود"}]

    financials = get_client_financial_snapshot(db, client_id)

    # Get programs
    if program_id:
        programs = _exec(db,
            "SELECT * FROM funding_programs WHERE id = :id AND is_active = true",
            {"id": program_id}).fetchall()
    else:
        programs = _exec(db,
            "SELECT * FROM funding_programs WHERE is_active = true ORDER BY name_ar").fetchall()

    if not programs:
        return [{"message": "لا توجد برامج تمويلية متاحة حالياً"}]

    results = []
    for prog in programs:
        assessment = _evaluate_single_program(
            client, financials, prog, "funding_program", db)
        results.append(assessment)

    return results


def assess_support_eligibility(db, client_id: str, program_id: str | None = None) -> list[dict]:
    """Assess client eligibility for support programs."""
    client = get_client_profile(db, client_id)
    if not client:
        return [{"error": "العميل غير موجود"}]

    financials = get_client_financial_snapshot(db, client_id)

    if program_id:
        programs = _exec(db,
            "SELECT * FROM support_programs WHERE id = :id AND is_active = true",
            {"id": program_id}).fetchall()
    else:
        programs = _exec(db,
            "SELECT * FROM support_programs WHERE is_active = true ORDER BY name_ar").fetchall()

    if not programs:
        return [{"message": "لا توجد برامج دعم متاحة حالياً"}]

    results = []
    for prog in programs:
        assessment = _evaluate_single_program(
            client, financials, prog, "support_program", db)
        results.append(assessment)

    return results


def assess_license_eligibility(db, client_id: str, license_id: str | None = None) -> list[dict]:
    """Assess client eligibility for licenses."""
    client = get_client_profile(db, client_id)
    if not client:
        return [{"error": "العميل غير موجود"}]

    financials = get_client_financial_snapshot(db, client_id)

    if license_id:
        licenses = _exec(db,
            "SELECT * FROM license_registry WHERE id = :id AND is_active = true",
            {"id": license_id}).fetchall()
    else:
        licenses = _exec(db,
            "SELECT * FROM license_registry WHERE is_active = true ORDER BY name_ar").fetchall()

    if not licenses:
        return [{"message": "لا توجد تراخيص متاحة حالياً"}]

    results = []
    for lic in licenses:
        assessment = _evaluate_single_program(
            client, financials, lic, "license", db)
        results.append(assessment)

    return results


def _evaluate_single_program(client: dict, financials: dict | None,
                              program_row, program_type: str, db) -> dict:
    """Evaluate a single program/license against client data."""
    import uuid

    # Extract program info based on column positions
    # (SQLite returns tuples, not dicts)
    prog_id = program_row[0]
    prog_name_ar = program_row[1]
    prog_name_en = program_row[2] if len(program_row) > 2 else ""

    met = []
    gaps = []
    missing_docs = []
    next_actions = []
    score = 50.0  # Base score

    has_financials = financials is not None and financials.get("confidence", 0) > 0

    # Check 1: Financial data availability
    if has_financials:
        met.append("بيانات مالية محللة متاحة")
        score += 10
    else:
        gaps.append("لا توجد بيانات مالية محللة — يجب رفع وتحليل القوائم المالية أولاً")
        next_actions.append("رفع شجرة الحسابات وميزان المراجعة وتشغيل التحليل المالي")
        score -= 20

    # Check 2: If financials available, check ratios
    if has_financials:
        ratios = financials.get("ratios", {})
        income = financials.get("income", {})
        balance = financials.get("balance", {})

        # Current ratio
        cr = ratios.get("current_ratio", 0) or 0
        if cr >= 1.0:
            met.append(f"نسبة التداول مقبولة ({cr:.2f})")
            score += 5
        elif cr > 0:
            gaps.append(f"نسبة التداول منخفضة ({cr:.2f}) — المطلوب 1.0 أو أعلى")
            next_actions.append("تحسين السيولة قصيرة الأجل")

        # Revenue
        revenue = income.get("total_revenue", 0) or income.get("net_sales", 0) or 0
        if revenue > 0:
            met.append(f"إيرادات موجودة ({revenue:,.0f})")
            score += 5
        else:
            gaps.append("لا توجد إيرادات مسجلة")

        # Net profit
        profit = income.get("net_profit", 0) or 0
        if profit > 0:
            met.append("المنشأة تحقق أرباحاً")
            score += 10
        else:
            gaps.append("المنشأة لا تحقق أرباحاً حالياً")
            next_actions.append("مراجعة هيكل التكاليف والمصروفات")

        # Debt ratio
        dr = ratios.get("debt_ratio", 0) or 0
        if dr < 0.7:
            met.append(f"نسبة الديون مقبولة ({dr:.2f})")
            score += 5
        elif dr > 0:
            gaps.append(f"نسبة الديون مرتفعة ({dr:.2f})")

    # Determine status
    score = max(min(score, 100), 0)
    if score >= 80:
        status = "likely_eligible"
    elif score >= 60:
        status = "conditionally_eligible"
    elif score >= 40:
        status = "review_required"
    else:
        status = "not_eligible"

    # Boundary warning
    boundary = "advisory"
    explanation = "هذا التقييم استرشادي ولا يمثل موافقة نهائية من الجهة المختصة."

    if not has_financials:
        boundary = "uncertain"
        explanation = "لا تتوفر بيانات مالية كافية لتقييم دقيق. يرجى إكمال التحليل المالي أولاً."

    # Save assessment
    assessment_id = str(uuid.uuid4())
    try:
        _exec(db,
            """INSERT INTO eligibility_assessments
               (id, client_id, assessment_type, target_program_id,
                target_program_type, target_program_name,
                eligibility_status, readiness_score, confidence,
                risk_severity, boundary_status,
                met_requirements_json, gaps_json,
                missing_documents_json, next_actions_json,
                financial_data_json, explanation_ar,
                requires_human_review, analysis_run_id, created_at)
               VALUES (:id, :cid, :atype, :pid, :ptype, :pname,
                       :status, :score, :conf, :risk, :boundary,
                       :met, :gaps, :docs, :actions, :fin,
                       :expl, :review, :run_id, :now)""",
            {
                "id": assessment_id,
                "cid": client["id"],
                "atype": program_type.replace("_program", ""),
                "pid": prog_id,
                "ptype": program_type,
                "pname": prog_name_ar,
                "status": status,
                "score": score,
                "conf": financials.get("confidence", 0) if financials else 0,
                "risk": "low" if score >= 70 else "medium" if score >= 40 else "high",
                "boundary": boundary,
                "met": json.dumps(met, ensure_ascii=False),
                "gaps": json.dumps(gaps, ensure_ascii=False),
                "docs": json.dumps(missing_docs, ensure_ascii=False),
                "actions": json.dumps(next_actions, ensure_ascii=False),
                "fin": json.dumps({"has_data": has_financials}, ensure_ascii=False),
                "expl": explanation,
                "review": 1 if status == "review_required" else 0,
                "run_id": financials.get("analysis_run_id") if financials else None,
                "now": _now().isoformat(),
            })
        db.commit()
    except Exception:
        pass  # Assessment saved best-effort

    return {
        "assessment_id": assessment_id,
        "program_id": prog_id,
        "program_name": prog_name_ar,
        "program_type": program_type,
        "eligibility_status": status,
        "readiness_score": score,
        "confidence": financials.get("confidence", 0) if financials else 0,
        "boundary_status": boundary,
        "met_requirements": met,
        "gaps": gaps,
        "missing_documents": missing_docs,
        "next_actions": next_actions,
        "explanation": explanation,
        "requires_human_review": status == "review_required",
    }