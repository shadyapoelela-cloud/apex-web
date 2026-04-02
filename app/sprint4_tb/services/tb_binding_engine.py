"""
APEX Sprint 4 — TB Binding Engine
═══════════════════════════════════════════════════════════════
Matches Trial Balance rows to the client's approved COA.

Matching priority (per Apex_Coa_First_Workflow §15.1):
  1. account_code exact match
  2. account_name exact match
  3. normalized name match
  4. client-specific alias/rule
  5. fuzzy suggestion (high-similarity)

Outputs per row:
  matched, match_type, binding_confidence, mismatch_reason, requires_review

If unmatched accounts exceed 15%, analysis is blocked.
"""

import re, json
from typing import Dict, List, Optional
from difflib import SequenceMatcher


def _norm(text: str) -> str:
    if not text:
        return ""
    t = text.strip().lower()
    t = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670]', '', t)
    t = t.replace("\u0623", "\u0627").replace("\u0625", "\u0627").replace("\u0622", "\u0627")
    t = t.replace("\u0649", "\u064a").replace("\u0629", "\u0647")
    return re.sub(r"\s+", " ", t)


def bind_tb_to_coa(
    tb_upload_id: str,
    coa_upload_id: str,
    client_id: str,
    fuzzy_threshold: float = 0.80,
) -> Dict:
    """
    Run binding engine: match each TB row to approved COA account.
    Saves results to tb_binding_results table.
    Returns binding summary.
    """
    from app.phase1.models.platform_models import SessionLocal, gen_uuid
    from sqlalchemy import text as _t

    db = SessionLocal()
    try:
        # ── Load approved COA accounts ──
        coa_rows = db.execute(_t(
            """SELECT id, account_code, account_name_raw, account_name_normalized,
                      normalized_class, statement_section, cashflow_role
               FROM client_chart_of_accounts
               WHERE coa_upload_id = :cid AND record_status != 'rejected'
               ORDER BY source_row_number"""
        ), {"cid": coa_upload_id}).fetchall()

        if not coa_rows:
            return {"success": False, "error": "No COA accounts found for this upload"}

        # Build lookup indices
        coa_by_code = {}
        coa_by_name = {}
        coa_by_norm = {}
        coa_list = []

        for r in coa_rows:
            entry = {
                "id": r[0], "code": (r[1] or "").strip(),
                "name_raw": r[2], "name_norm": _norm(r[2] or ""),
                "nc": r[4], "section": r[5], "cashflow": r[6],
            }
            coa_list.append(entry)
            if entry["code"]:
                coa_by_code[entry["code"]] = entry
            if entry["name_raw"]:
                coa_by_name[entry["name_raw"].strip().lower()] = entry
            if entry["name_norm"]:
                coa_by_norm[entry["name_norm"]] = entry

        # ── Load client-specific rules ──
        client_rules = []
        try:
            rule_rows = db.execute(_t(
                """SELECT condition_json, action_json FROM client_coa_rules
                   WHERE client_id = :cid AND is_active = true ORDER BY priority DESC"""
            ), {"cid": client_id}).fetchall()
            for rr in rule_rows:
                cond = rr[0] if isinstance(rr[0], dict) else json.loads(rr[0] or "{}")
                act = rr[1] if isinstance(rr[1], dict) else json.loads(rr[1] or "{}")
                client_rules.append({"condition": cond, "action": act})
        except:
            pass

        # ── Load TB parsed rows ──
        tb_rows = db.execute(_t(
            """SELECT id, account_code, account_name_raw, account_name_normalized,
                      close_debit, close_credit, net_balance
               FROM tb_parsed_rows
               WHERE tb_upload_id = :uid AND is_summary_row = false
               ORDER BY source_row_number"""
        ), {"uid": tb_upload_id}).fetchall()

        if not tb_rows:
            return {"success": False, "error": "No TB rows found"}

        # ── Clear previous binding results ──
        db.execute(_t(
            "DELETE FROM tb_binding_results WHERE tb_upload_id = :uid"
        ), {"uid": tb_upload_id})

        # ── Run matching ──
        stats = {"matched": 0, "unmatched": 0, "new_accounts": 0, "total_conf": 0.0}
        results = []

        for tb in tb_rows:
            tb_id = tb[0]
            tb_code = (tb[1] or "").strip()
            tb_name = (tb[2] or "").strip()
            tb_norm = _norm(tb_name)
            tb_debit = tb[4] or 0.0
            tb_credit = tb[5] or 0.0
            tb_net = tb[6] or 0.0

            match = None  # (coa_entry, match_type, confidence)

            # Strategy 1: Exact code match
            if tb_code and tb_code in coa_by_code:
                match = (coa_by_code[tb_code], "exact_code", 1.0)

            # Strategy 2: Exact name match
            if not match and tb_name.lower() in coa_by_name:
                match = (coa_by_name[tb_name.lower()], "exact_name", 0.95)

            # Strategy 3: Normalized name match
            if not match and tb_norm in coa_by_norm:
                match = (coa_by_norm[tb_norm], "normalized_name", 0.90)

            # Strategy 4: Client-specific rules
            if not match and client_rules:
                for rule in client_rules:
                    cond = rule["condition"]
                    field_val = tb_name if cond.get("field") == "account_name_raw" else tb_code
                    contains = cond.get("contains", "")
                    if contains and contains.lower() in (field_val or "").lower():
                        act = rule["action"]
                        target_class = act.get("set_class")
                        if target_class:
                            for c in coa_list:
                                if c["nc"] == target_class and _norm(c["name_raw"]) == tb_norm:
                                    match = (c, "client_rule", 0.85)
                                    break
                        if match:
                            break

            # Strategy 5: Fuzzy matching
            if not match:
                best_ratio = 0.0
                best_coa = None
                for c in coa_list:
                    if not c["name_norm"]:
                        continue
                    ratio = SequenceMatcher(None, tb_norm, c["name_norm"]).ratio()
                    if ratio > best_ratio:
                        best_ratio = ratio
                        best_coa = c

                if best_coa and best_ratio >= fuzzy_threshold:
                    match = (best_coa, "fuzzy_match", round(best_ratio, 3))

            # ── Build binding result ──
            if match:
                coa_entry, match_type, confidence = match
                binding = {
                    "id": gen_uuid(), "tb_upload_id": tb_upload_id,
                    "tb_row_id": tb_id, "coa_account_id": coa_entry["id"],
                    "tb_account_code": tb_code, "tb_account_name_raw": tb_name,
                    "tb_amount_debit": tb_debit, "tb_amount_credit": tb_credit,
                    "tb_net_balance": tb_net,
                    "matched": True, "match_type": match_type,
                    "binding_confidence": confidence,
                    "mismatch_reason": None,
                    "requires_review": confidence < 0.85,
                    "coa_normalized_class": coa_entry["nc"],
                    "coa_statement_section": coa_entry["section"],
                    "coa_cashflow_role": coa_entry["cashflow"],
                    "review_status": "auto",
                }
                stats["matched"] += 1
                stats["total_conf"] += confidence
            else:
                binding = {
                    "id": gen_uuid(), "tb_upload_id": tb_upload_id,
                    "tb_row_id": tb_id, "coa_account_id": None,
                    "tb_account_code": tb_code, "tb_account_name_raw": tb_name,
                    "tb_amount_debit": tb_debit, "tb_amount_credit": tb_credit,
                    "tb_net_balance": tb_net,
                    "matched": False, "match_type": "unmatched",
                    "binding_confidence": 0.0,
                    "mismatch_reason": "no_matching_coa_account",
                    "requires_review": True,
                    "coa_normalized_class": None,
                    "coa_statement_section": None,
                    "coa_cashflow_role": None,
                    "review_status": "requires_manual_match",
                }
                stats["unmatched"] += 1

            results.append(binding)

        # ── Save all binding results ──
        for b in results:
            db.execute(_t(
                """INSERT INTO tb_binding_results
                   (id, tb_upload_id, tb_row_id, coa_account_id,
                    tb_account_code, tb_account_name_raw,
                    tb_amount_debit, tb_amount_credit, tb_net_balance,
                    matched, match_type, binding_confidence, mismatch_reason,
                    requires_review, coa_normalized_class, coa_statement_section,
                    coa_cashflow_role, review_status, created_at)
                   VALUES (:id, :tb_upload_id, :tb_row_id, :coa_account_id,
                           :tb_account_code, :tb_account_name_raw,
                           :tb_amount_debit, :tb_amount_credit, :tb_net_balance,
                           :matched, :match_type, :binding_confidence, :mismatch_reason,
                           :requires_review, :coa_normalized_class, :coa_statement_section,
                           :coa_cashflow_role, :review_status, CURRENT_TIMESTAMP)"""
            ), b)

        # ── Update TB upload summary ──
        total = len(tb_rows)
        avg_conf = round(stats["total_conf"] / max(stats["matched"], 1), 3)
        status = "bound" if stats["unmatched"] == 0 else "bound_with_issues"

        db.execute(_t(
            """UPDATE trial_balance_uploads SET
                upload_status = :status,
                total_matched = :matched,
                total_unmatched = :unmatched,
                total_new_accounts = :new_acc,
                binding_confidence_avg = :avg_conf
            WHERE id = :uid"""
        ), {
            "status": status, "matched": stats["matched"],
            "unmatched": stats["unmatched"], "new_acc": stats["new_accounts"],
            "avg_conf": avg_conf, "uid": tb_upload_id,
        })

        db.commit()

        # ── Check if analysis is safe to run ──
        unmatched_pct = round(stats["unmatched"] / max(total, 1) * 100, 1)
        can_analyze = unmatched_pct <= 15.0

        return {
            "success": True,
            "tb_upload_id": tb_upload_id,
            "coa_upload_id": coa_upload_id,
            "total_tb_rows": total,
            "matched": stats["matched"],
            "unmatched": stats["unmatched"],
            "unmatched_percentage": unmatched_pct,
            "avg_binding_confidence": avg_conf,
            "can_proceed_to_analysis": can_analyze,
            "analysis_blocked_reason": f"نسبة الحسابات غير المطابقة {unmatched_pct}% تتجاوز الحد المسموح (15%)" if not can_analyze else None,
            "status": status,
            "match_type_distribution": _count_match_types(results),
        }
    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()


def _count_match_types(results: List[Dict]) -> Dict:
    dist = {}
    for r in results:
        mt = r.get("match_type", "unknown")
        dist[mt] = dist.get(mt, 0) + 1
    return dist


def manually_match_tb_row(binding_id: str, coa_account_id: str, matched_by: str = None) -> Dict:
    """Manually match a TB row to a COA account."""
    from app.phase1.models.platform_models import SessionLocal
    from sqlalchemy import text as _t
    from datetime import datetime, timezone

    db = SessionLocal()
    try:
        coa = db.execute(_t(
            """SELECT id, normalized_class, statement_section, cashflow_role
               FROM client_chart_of_accounts WHERE id = :cid"""
        ), {"cid": coa_account_id}).fetchone()

        if not coa:
            return {"success": False, "error": "COA account not found"}

        now = datetime.now(timezone.utc).isoformat()
        db.execute(_t(
            """UPDATE tb_binding_results SET
                coa_account_id = :cid, matched = true,
                match_type = 'manual', binding_confidence = 1.0,
                mismatch_reason = NULL, requires_review = false,
                coa_normalized_class = :nc, coa_statement_section = :ss,
                coa_cashflow_role = :cf,
                review_status = 'manually_matched',
                reviewed_by = :by, reviewed_at = :now
            WHERE id = :bid"""
        ), {
            "cid": coa_account_id, "nc": coa[1], "ss": coa[2], "cf": coa[3],
            "by": matched_by, "now": now, "bid": binding_id,
        })
        db.commit()
        return {"success": True, "binding_id": binding_id, "status": "manually_matched"}
    except Exception as e:
        db.rollback()
        return {"success": False, "error": str(e)}
    finally:
        db.close()


def approve_binding(tb_upload_id: str, approved_by: str = None) -> Dict:
    """Approve the TB binding — marks it ready for analysis."""
    from app.phase1.models.platform_models import SessionLocal
    from sqlalchemy import text as _t

    db = SessionLocal()
    try:
        unmatched = db.execute(_t(
            "SELECT COUNT(*) FROM tb_binding_results WHERE tb_upload_id = :uid AND matched = false"
        ), {"uid": tb_upload_id}).fetchone()[0]

        total = db.execute(_t(
            "SELECT COUNT(*) FROM tb_binding_results WHERE tb_upload_id = :uid"
        ), {"uid": tb_upload_id}).fetchone()[0]

        if total == 0:
            return {"success": False, "error": "No binding results found. Run binding first."}

        unmatched_pct = round(unmatched / total * 100, 1)

        db.execute(_t(
            "UPDATE trial_balance_uploads SET upload_status = 'approved', binding_approved = true WHERE id = :uid"
        ), {"uid": tb_upload_id})
        db.commit()

        return {
            "success": True, "tb_upload_id": tb_upload_id, "status": "approved",
            "total_rows": total, "unmatched_remaining": unmatched,
            "unmatched_percentage": unmatched_pct, "ready_for_analysis": True,
            "warning": f"لا يزال هناك {unmatched} حساب غير مطابق ({unmatched_pct}%)" if unmatched > 0 else None,
        }
    except Exception as e:
        db.rollback()
        return {"success": False, "error": str(e)}
    finally:
        db.close()
