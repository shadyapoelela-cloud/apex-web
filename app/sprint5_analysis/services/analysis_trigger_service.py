"""
APEX Sprint 5 — Analysis Trigger Service
Runs the financial analysis engine using approved COA mapping + TB binding.
Key rule: Analysis only runs if TB binding is approved and COA is approved.
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


def get_approved_coa_for_client(db, client_id: str) -> dict | None:
    """Find the latest approved COA for a client."""
    row = _exec(db,
        """SELECT ca.coa_upload_id, ca.id as approval_id, ca.overall_quality_score,
                  ca.approved_accounts, ca.total_accounts
           FROM coa_approval_records ca
           WHERE ca.client_id = :cid AND ca.action = 'approved' AND ca.is_current = true
           ORDER BY ca.created_at DESC LIMIT 1""",
        {"cid": client_id}).fetchone()
    if not row:
        return None
    return {
        "coa_upload_id": row[0],
        "approval_id": row[1],
        "quality_score": row[2],
        "approved_accounts": row[3],
        "total_accounts": row[4],
    }


def get_approved_tb_binding(db, tb_upload_id: str) -> dict | None:
    """Check if TB binding is approved."""
    row = _exec(db,
        """SELECT id, upload_status, client_id, coa_upload_id,
                  total_rows_parsed, total_matched, total_unmatched, binding_confidence_avg
           FROM trial_balance_uploads
           WHERE id = :tid""",
        {"tid": tb_upload_id}).fetchone()
    if not row:
        return None
    return {
        "id": row[0],
        "upload_status": row[1],
        "client_id": row[2],
        "coa_upload_id": row[3],
        "total_rows": row[4],
        "total_matched": row[5],
        "total_unmatched": row[6],
        "binding_confidence_avg": row[7],
    }


def get_bound_rows_as_classified(db, tb_upload_id: str) -> list[dict]:
    """
    Convert TB bound rows into classified_rows format
    that the existing financial engine understands.
    Each row needs: account_name, normalized_class, statement_section,
    current_noncurrent, cashflow_role, sign_rule, debit, credit, net_balance.
    """
    rows = _exec(db,
        """SELECT
              tp.account_code, tp.account_name,
              tp.debit_amount, tp.credit_amount, tp.net_balance,
              br.coa_account_id, br.match_strategy, br.confidence,
              ca.normalized_class, ca.statement_section,
              ca.subcategory, ca.current_noncurrent,
              ca.cashflow_role, ca.sign_rule,
              ca.account_name_raw as coa_account_name
           FROM tb_parsed_rows tp
           LEFT JOIN tb_binding_results br ON br.tb_upload_id = tp.tb_upload_id
               AND br.tb_row_id = tp.id
           LEFT JOIN client_chart_of_accounts ca ON ca.id = br.coa_account_id
           WHERE tp.tb_upload_id = :tid
           ORDER BY tp.row_number""",
        {"tid": tb_upload_id}).fetchall()

    classified = []
    for r in rows:
        classified.append({
            "account_code": r[0] or "",
            "account_name": r[1] or "",
            "debit": float(r[2] or 0),
            "credit": float(r[3] or 0),
            "net_balance": float(r[4] or 0),
            "coa_account_id": r[5],
            "match_strategy": r[6],
            "binding_confidence": float(r[7] or 0),
            # From COA classification
            "normalized_class": r[8] or "other",
            "statement_section": r[9] or "other",
            "subcategory": r[10] or "",
            "current_noncurrent": r[11] or "",
            "cashflow_role": r[12] or "",
            "sign_rule": r[13] or "natural",
            "coa_account_name": r[14] or "",
        })
    return classified


def validate_analysis_preconditions(db, client_id: str, tb_upload_id: str) -> dict:
    """
    Check all preconditions before running analysis.
    Returns: {"can_proceed": bool, "errors": [...], "warnings": [...], "context": {...}}
    """
    errors = []
    warnings = []
    context = {}

    # 1. Check approved COA exists
    coa = get_approved_coa_for_client(db, client_id)
    if not coa:
        errors.append("لا توجد شجرة حسابات معتمدة لهذا العميل. يجب اعتماد شجرة الحسابات أولاً.")
    else:
        context["coa"] = coa
        if coa["quality_score"] and coa["quality_score"] < 50:
            warnings.append(f"جودة شجرة الحسابات منخفضة ({coa['quality_score']:.0f}%). النتائج قد تكون أقل دقة.")

    # 2. Check TB binding
    tb = get_approved_tb_binding(db, tb_upload_id)
    if not tb:
        errors.append("ميزان المراجعة غير موجود.")
    elif tb["upload_status"] != "approved":
        errors.append(f"ربط الميزان غير معتمد بعد. الحالة الحالية: {tb['upload_status']}")
    else:
        context["tb"] = tb
        if tb["binding_confidence_avg"] and tb["binding_confidence_avg"] < 85:
            warnings.append(f"نسبة المطابقة منخفضة ({tb['binding_confidence_avg']:.0f}%). قد تكون هناك حسابات غير مربوطة.")

    # 3. Verify COA and TB belong to same client
    if coa and tb:
        if tb["client_id"] != client_id:
            errors.append("ميزان المراجعة لا ينتمي لهذا العميل.")
        if coa["coa_upload_id"] != tb.get("coa_upload_id"):
            warnings.append("الميزان مربوط بنسخة شجرة حسابات مختلفة عن النسخة المعتمدة حالياً.")

    return {
        "can_proceed": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "context": context,
    }


def run_coa_aware_analysis(db, client_id: str, tb_upload_id: str,
                           industry: str = "general",
                           closing_inventory: float | None = None,
                           triggered_by: str | None = None) -> dict:
    """
    Main entry point: run financial analysis using approved COA + TB binding.
    """
    from app.sprint5_analysis.models.analysis_models import AnalysisRun
    import uuid

    # Step 1: Validate preconditions
    validation = validate_analysis_preconditions(db, client_id, tb_upload_id)
    if not validation["can_proceed"]:
        return {
            "success": False,
            "errors": validation["errors"],
            "warnings": validation["warnings"],
        }

    coa_upload_id = validation["context"]["coa"]["coa_upload_id"]

    # Step 2: Create analysis run record
    run_id = str(uuid.uuid4())
    _exec(db,
        """INSERT INTO analysis_runs
           (id, client_id, tb_upload_id, coa_upload_id, run_status,
            industry, closing_inventory, triggered_by, created_at)
           VALUES (:id, :cid, :tid, :coa, 'running', :ind, :inv, :by, :now)""",
        {"id": run_id, "cid": client_id, "tid": tb_upload_id,
         "coa": coa_upload_id, "ind": industry, "inv": closing_inventory,
         "by": triggered_by, "now": _now().isoformat()})
    db.commit()

    try:
        # Step 3: Get classified rows from binding
        classified_rows = get_bound_rows_as_classified(db, tb_upload_id)
        if not classified_rows:
            raise ValueError("لا توجد صفوف مربوطة في ميزان المراجعة.")

        # Step 4: Run financial engine components
        from app.services.financial.income_statement_builder import IncomeStatementBuilder
        from app.services.financial.balance_sheet_builder import BalanceSheetBuilder
        from app.services.financial.cashflow_builder import CashFlowBuilder
        from app.services.financial.ratio_engine import RatioEngine
        from app.services.financial.readiness_engine import ReadinessEngine
        from app.services.financial.validation_engine import ValidationEngine
        from app.services.classification.account_classifier import AccountClassifier

        classifier = AccountClassifier()
        cls_summary = classifier.get_summary(classified_rows)

        # Opening inventory from classified rows
        opening_inv = sum(
            r.get("debit", 0) for r in classified_rows
            if r.get("normalized_class", "").lower() in ("inventory", "current_assets")
            and "inventory" in (r.get("subcategory", "") or r.get("account_name", "")).lower()
        )

        is_builder = IncomeStatementBuilder()
        is_result = is_builder.build(
            classified_rows,
            opening_inventory=opening_inv,
            closing_inventory_override=closing_inventory,
        )
        income = is_result["income_statement"]

        bs_builder = BalanceSheetBuilder()
        bs_result = bs_builder.build(
            classified_rows,
            net_profit=income.get("net_profit", 0),
            closing_inventory_override=closing_inventory,
        )
        balance = bs_result["balance_sheet"]

        cf_builder = CashFlowBuilder()
        cf_result = cf_builder.build(
            income=income, balance_current=balance,
            classified_rows=classified_rows,
        )
        cash_flow = cf_result["cash_flow"]

        ratio_engine = RatioEngine()
        ratio_result = ratio_engine.calculate(income, balance, industry=industry)
        ratios = ratio_result.get("ratios", {})

        validator = ValidationEngine()
        validations = validator.validate(
            classified_rows=classified_rows,
            income=income, balance=balance,
            classification_summary=cls_summary,
        )

        readiness_engine = ReadinessEngine()
        confidence = _calc_run_confidence(cls_summary, validations, classified_rows, validation)
        readiness_result = readiness_engine.calculate(
            income=income, balance=balance, ratios=ratios,
            validations=validations, confidence=confidence,
            industry=industry,
        )

        # Knowledge Brain evaluation
        brain_result = {}
        try:
            from app.knowledge_brain.services.brain_service import KnowledgeBrainService
            brain = KnowledgeBrainService()
            brain_result = brain.evaluate_analysis({
                "income_statement": income,
                "balance_sheet": balance,
                "ratios": ratios,
                "meta": {"industry": industry},
                "confidence": confidence,
            })
        except Exception:
            brain_result = {"brain_findings": [], "rules_evaluated": 0}

        # Collect all warnings
        all_warnings = validation["warnings"]
        all_warnings.extend(is_result.get("warnings", []))
        all_warnings.extend(bs_result.get("warnings", []))
        all_warnings.extend(cf_result.get("warnings", []))
        all_warnings.extend(ratio_result.get("warnings", []))

        # Step 5: Update run record with results
        _exec(db,
            """UPDATE analysis_runs SET
               run_status = 'completed',
               overall_confidence = :conf,
               total_accounts_analyzed = :total,
               matched_accounts = :matched,
               unmatched_accounts = :unmatched,
               binding_quality_score = :bq,
               income_statement_json = :is_j,
               balance_sheet_json = :bs_j,
               cash_flow_json = :cf_j,
               ratios_json = :rat_j,
               readiness_json = :rd_j,
               validations_json = :val_j,
               knowledge_brain_json = :kb_j,
               classification_json = :cls_j,
               warnings_json = :warn_j,
               completed_at = :now
               WHERE id = :id""",
            {
                "conf": confidence,
                "total": len(classified_rows),
                "matched": sum(1 for r in classified_rows if r.get("coa_account_id")),
                "unmatched": sum(1 for r in classified_rows if not r.get("coa_account_id")),
                "bq": validation["context"].get("tb", {}).get("binding_confidence_avg"),
                "is_j": json.dumps(income, ensure_ascii=False, default=str),
                "bs_j": json.dumps(balance, ensure_ascii=False, default=str),
                "cf_j": json.dumps(cash_flow, ensure_ascii=False, default=str),
                "rat_j": json.dumps(ratios, ensure_ascii=False, default=str),
                "rd_j": json.dumps(readiness_result, ensure_ascii=False, default=str),
                "val_j": json.dumps(validations, ensure_ascii=False, default=str),
                "kb_j": json.dumps(brain_result, ensure_ascii=False, default=str),
                "cls_j": json.dumps(cls_summary, ensure_ascii=False, default=str),
                "warn_j": json.dumps(all_warnings, ensure_ascii=False, default=str),
                "now": _now().isoformat(),
                "id": run_id,
            })
        db.commit()

        return {
            "success": True,
            "analysis_run_id": run_id,
            "status": "completed",
            "confidence": confidence,
            "total_accounts": len(classified_rows),
            "matched": sum(1 for r in classified_rows if r.get("coa_account_id")),
            "unmatched": sum(1 for r in classified_rows if not r.get("coa_account_id")),
            "income_statement": income,
            "balance_sheet": balance,
            "cash_flow": cash_flow,
            "ratios": ratios,
            "readiness": readiness_result.get("readiness", {}),
            "validations_summary": {
                "errors": sum(1 for v in validations if v.get("severity") == "ERROR"),
                "warnings": sum(1 for v in validations if v.get("severity") == "WARNING"),
            },
            "knowledge_brain": brain_result,
            "warnings": all_warnings,
        }

    except Exception as e:
        # Mark run as failed
        _exec(db,
            """UPDATE analysis_runs SET run_status = 'failed',
               error_message = :err, completed_at = :now WHERE id = :id""",
            {"err": str(e), "now": _now().isoformat(), "id": run_id})
        db.commit()
        return {
            "success": False,
            "analysis_run_id": run_id,
            "status": "failed",
            "errors": [str(e)],
            "warnings": validation.get("warnings", []),
        }


def _calc_run_confidence(cls_summary, validations, classified_rows, precondition) -> float:
    """Calculate overall confidence for a COA-aware analysis run."""
    score = 70.0  # Base score for COA-aware analysis (higher than raw TB)

    # Boost for binding quality
    tb_info = precondition.get("context", {}).get("tb", {})
    binding_confidence_avg = tb_info.get("binding_confidence_avg", 0) or 0
    if binding_confidence_avg >= 95:
        score += 15
    elif binding_confidence_avg >= 85:
        score += 10
    elif binding_confidence_avg >= 70:
        score += 5

    # Boost for COA quality
    coa_info = precondition.get("context", {}).get("coa", {})
    quality = coa_info.get("quality_score", 0) or 0
    if quality >= 80:
        score += 10
    elif quality >= 60:
        score += 5

    # Penalty for validation errors
    errors = sum(1 for v in validations if v.get("severity") == "ERROR")
    score -= min(errors * 3, 20)

    # Penalty for unmapped
    unmapped = cls_summary.get("unmapped_count", 0)
    if unmapped > 10:
        score -= 10
    elif unmapped > 5:
        score -= 5

    return max(min(score, 100), 0)
