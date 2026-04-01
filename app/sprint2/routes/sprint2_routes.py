"""Sprint 2 — COA Classification APIs"""
from fastapi import APIRouter
from sqlalchemy import text as sa_text, HTTPException
import json, uuid
from datetime import datetime, timezone

router = APIRouter()

def _get_db():
    from app.phase1.models.platform_models import SessionLocal
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ── POST /coa/uploads/{upload_id}/classify ──
@router.post("/coa/classify/{upload_id}")
def classify_upload(upload_id: str):
    """Run classification engine on all parsed accounts for this upload."""
    from app.phase1.models.platform_models import SessionLocal
    from app.sprint2.services.coa_classifier import classify_upload as run_classify

    db = SessionLocal()
    try:
        # Get upload
        row = db.execute(sa_text("SELECT id, upload_status, client_id FROM client_coa_uploads WHERE id = :uid"),
            {"uid": upload_id}
        ).fetchone()

        if not row:
            raise HTTPException(404, "Upload not found")

        status = row[1] if isinstance(row, tuple) else row.upload_status
        if status not in ("parsed", "parsed_with_warnings"):
            raise HTTPException(400, f"Upload must be parsed first. Current status: {status}")

        # Get all parsed accounts
        accounts = db.execute(sa_text("")"SELECT id, account_code, account_name_raw, account_name_normalized,
                      parent_code, parent_name, account_level, account_type_raw, 
                      normal_balance, source_row_number, issues_json
               FROM client_chart_of_accounts 
               WHERE coa_upload_id = :uid AND record_status != 'rejected'
               ORDER BY source_row_number""",
            {"uid": upload_id}
        ).fetchall()

        if not accounts:
            raise HTTPException(400, "No parsed accounts found for this upload")

        # Build account dicts
        acc_list = []
        for a in accounts:
            acc_list.append({
                "id": a[0],
                "account_code": a[1],
                "account_name_raw": a[2],
                "account_name_normalized": a[3],
                "parent_code": a[4],
                "parent_name": a[5],
                "account_level": a[6],
                "account_type_raw": a[7],
                "normal_balance": a[8],
            })

        # Run classifier
        results = run_classify(acc_list)

        # Update accounts with classification
        high_conf = 0
        low_conf = 0
        unclassified = 0
        class_dist = {}
        section_dist = {}
        total_conf = 0.0

        for acc, cls_result in zip(acc_list, results):
            acc_id = acc["id"]
            conf = cls_result["mapping_confidence"]
            nc = cls_result["normalized_class"]
            ss = cls_result["statement_section"]

            total_conf += conf
            if conf >= 0.75:
                high_conf += 1
            elif conf >= 0.40:
                low_conf += 1
            else:
                unclassified += 1

            class_dist[nc] = class_dist.get(nc, 0) + 1
            if ss:
                section_dist[ss] = section_dist.get(ss, 0) + 1

            db.execute(sa_text("")"UPDATE client_chart_of_accounts SET
                    normalized_class = :nc,
                    statement_section = :ss,
                    subcategory = :sub,
                    current_noncurrent = :cn,
                    cashflow_role = :cf,
                    sign_rule = :sr,
                    mapping_confidence = :mc,
                    mapping_source = :ms,
                    review_status = :rs,
                    classification_issues_json = :ci
                WHERE id = :aid""",
                {
                    "nc": cls_result["normalized_class"],
                    "ss": cls_result["statement_section"],
                    "sub": cls_result.get("subcategory"),
                    "cn": cls_result["current_noncurrent"],
                    "cf": cls_result["cashflow_role"],
                    "sr": cls_result["sign_rule"],
                    "mc": cls_result["mapping_confidence"],
                    "ms": cls_result["mapping_source"],
                    "rs": cls_result["review_status"],
                    "ci": json.dumps(cls_result["classification_issues"]),
                    "aid": acc_id,
                }
            )

        db.commit()

        total = len(acc_list)
        avg_conf = round(total_conf / total, 3) if total > 0 else 0.0

        return {
            "upload_id": upload_id,
            "total_accounts": total,
            "classified": high_conf + low_conf,
            "high_confidence": high_conf,
            "low_confidence": low_conf,
            "unclassified": unclassified,
            "avg_confidence": avg_conf,
            "class_distribution": class_dist,
            "section_distribution": section_dist,
        }
    finally:
        db.close()

# ── GET /coa/uploads/{upload_id}/mapping ──
@router.get("/coa/mapping/{upload_id}")
def get_mapping_preview(
    upload_id: str,
    page: int = 1,
    page_size: int = 50,
    confidence_min: float = None,
    confidence_max: float = None,
    normalized_class: str = None,
    review_status: str = None,
    has_issues: bool = None,
    search: str = None,
):
    """Get classification mapping preview with filters."""
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        # Build query
        where = ["coa_upload_id = :uid", "record_status != 'rejected'"]
        params = {"uid": upload_id}

        if confidence_min is not None:
            where.append("mapping_confidence >= :cmin")
            params["cmin"] = confidence_min
        if confidence_max is not None:
            where.append("mapping_confidence <= :cmax")
            params["cmax"] = confidence_max
        if normalized_class:
            where.append("normalized_class = :ncls")
            params["ncls"] = normalized_class
        if review_status:
            where.append("review_status = :rs")
            params["rs"] = review_status
        if search:
            where.append("(account_name_raw LIKE :srch OR account_code LIKE :srch)")
            params["srch"] = f"%{search}%"

        where_sql = " AND ".join(where)

        # Count
        count_row = db.execute(
            f"SELECT COUNT(*) FROM client_chart_of_accounts WHERE {where_sql}",
            params
        ).fetchone()
        total = count_row[0]

        # Fetch page
        offset = (page - 1) * page_size
        rows = db.execute(sa_text(f"""SELECT id, source_row_number, account_code, account_name_raw,
                       parent_code, account_level, account_type_raw, normal_balance,
                       normalized_class, statement_section, subcategory,
                       current_noncurrent, cashflow_role, sign_rule,
                       mapping_confidence, mapping_source, review_status,
                       issues_json, classification_issues_json
                FROM client_chart_of_accounts
                WHERE {where_sql}
                ORDER BY source_row_number
                LIMIT :lim OFFSET :off"""),
            {**params, "lim": page_size, "off": offset}
        ).fetchall()

        accounts = []
        for r in rows:
            issues = []
            cls_issues = []
            try:
                issues = json.loads(r[17] or "[]")
            except: pass
            try:
                cls_issues = json.loads(r[18] or "[]")
            except: pass

            accounts.append({
                "id": r[0],
                "source_row_number": r[1],
                "account_code": r[2],
                "account_name_raw": r[3],
                "parent_code": r[4],
                "account_level": r[5],
                "account_type_raw": r[6],
                "normal_balance": r[7],
                "normalized_class": r[8],
                "statement_section": r[9],
                "subcategory": r[10],
                "current_noncurrent": r[11],
                "cashflow_role": r[12],
                "sign_rule": r[13],
                "mapping_confidence": r[14] or 0.0,
                "mapping_source": r[15],
                "review_status": r[16],
                "issues": issues,
                "classification_issues": cls_issues,
            })

        return {
            "upload_id": upload_id,
            "total": total,
            "page": page,
            "page_size": page_size,
            "accounts": accounts,
        }
    finally:
        db.close()

# ── PUT /coa/accounts/{account_id} ──
@router.put("/coa/account/{account_id}")
def edit_account_classification(account_id: str, body: dict):
    """Edit classification for a single account."""
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        row = db.execute(sa_text("SELECT id FROM client_chart_of_accounts WHERE id = :aid"),
            {"aid": account_id}
        ).fetchone()
        if not row:
            raise HTTPException(404, "Account not found")

        allowed = ["normalized_class", "statement_section", "subcategory",
                    "current_noncurrent", "cashflow_role", "sign_rule"]
        updates = []
        params = {"aid": account_id}

        for field in allowed:
            if field in body:
                updates.append(f"{field} = :{field}")
                params[field] = body[field]

        if not updates:
            raise HTTPException(400, "No valid fields to update")

        updates.append("mapping_source = 'manual'")
        updates.append("mapping_confidence = 1.0")
        updates.append("review_status = 'manually_edited'")

        db.execute(
            f"UPDATE client_chart_of_accounts SET {', '.join(updates)} WHERE id = :aid",
            params
        )
        db.commit()

        return {"id": account_id, "status": "updated", "review_status": "manually_edited"}
    finally:
        db.close()

# ── POST /coa/accounts/{account_id}/approve ──
@router.post("/coa/approve/{account_id}")
def approve_account(account_id: str):
    """Approve classification for a single account."""
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        row = db.execute(sa_text("SELECT id, review_status FROM client_chart_of_accounts WHERE id = :aid"),
            {"aid": account_id}
        ).fetchone()
        if not row:
            raise HTTPException(404, "Account not found")

        now = datetime.now(timezone.utc).isoformat()
        db.execute(sa_text("")"UPDATE client_chart_of_accounts SET
                review_status = 'approved', approved_at = :now
            WHERE id = :aid""",
            {"aid": account_id, "now": now}
        )
        db.commit()
        return {"id": account_id, "review_status": "approved"}
    finally:
        db.close()

# ── POST /coa/uploads/{upload_id}/bulk-approve ──
@router.post("/coa/bulk-approve/{upload_id}")
def bulk_approve(upload_id: str, body: dict = {}):
    """Bulk approve accounts by IDs or confidence threshold."""
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc).isoformat()
        account_ids = body.get("account_ids", [])
        min_confidence = body.get("min_confidence") or body.get("approve_all_above")

        if account_ids:
            placeholders = ",".join([f":id{i}" for i in range(len(account_ids))])
            params = {f"id{i}": aid for i, aid in enumerate(account_ids)}
            params["now"] = now
            params["uid"] = upload_id
            db.execute(sa_text(f"""UPDATE client_chart_of_accounts SET
                    review_status = 'approved', approved_at = :now, mapping_source = 'bulk_approve'
                WHERE coa_upload_id = :uid AND id IN ({placeholders})"""),
                params
            )
        elif min_confidence is not None:
            db.execute(sa_text("")"UPDATE client_chart_of_accounts SET
                    review_status = 'approved', approved_at = :now, mapping_source = 'bulk_approve'
                WHERE coa_upload_id = :uid 
                AND mapping_confidence >= :mc
                AND record_status != 'rejected'""",
                {"uid": upload_id, "now": now, "mc": min_confidence}
            )
        else:
            raise HTTPException(400, "Provide account_ids or min_confidence")

        db.commit()

        # Count approved
        count = db.execute(sa_text("")"SELECT COUNT(*) FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND review_status = 'approved'""",
            {"uid": upload_id}
        ).fetchone()[0]

        total = db.execute(sa_text("")"SELECT COUNT(*) FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND record_status != 'rejected'""",
            {"uid": upload_id}
        ).fetchone()[0]

        return {
            "upload_id": upload_id,
            "approved_count": count,
            "total_accounts": total,
            "approval_percentage": round(count / total * 100, 1) if total > 0 else 0,
        }
    finally:
        db.close()

# ── GET /coa/uploads/{upload_id}/classification-summary ──
@router.get("/coa/classification-summary/{upload_id}")
def classification_summary(upload_id: str):
    """Get classification summary statistics."""
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        rows = db.execute(sa_text("")"SELECT normalized_class, statement_section, mapping_confidence, 
                      review_status, mapping_source
               FROM client_chart_of_accounts
               WHERE coa_upload_id = :uid AND record_status != 'rejected'""",
            {"uid": upload_id}
        ).fetchall()

        if not rows:
            raise HTTPException(404, "No accounts found")

        total = len(rows)
        high = sum(1 for r in rows if (r[2] or 0) >= 0.75)
        low = sum(1 for r in rows if 0.40 <= (r[2] or 0) < 0.75)
        unclassified = sum(1 for r in rows if (r[2] or 0) < 0.40)
        avg_conf = round(sum(r[2] or 0 for r in rows) / total, 3)

        class_dist = {}
        section_dist = {}
        review_dist = {}
        source_dist = {}

        for r in rows:
            nc = r[0] or "unclassified"
            ss = r[1] or "unknown"
            rs = r[3] or "draft"
            ms = r[4] or "none"

            class_dist[nc] = class_dist.get(nc, 0) + 1
            section_dist[ss] = section_dist.get(ss, 0) + 1
            review_dist[rs] = review_dist.get(rs, 0) + 1
            source_dist[ms] = source_dist.get(ms, 0) + 1

        return {
            "upload_id": upload_id,
            "total_accounts": total,
            "high_confidence": high,
            "low_confidence": low,
            "unclassified": unclassified,
            "avg_confidence": avg_conf,
            "class_distribution": class_dist,
            "section_distribution": section_dist,
            "review_status_distribution": review_dist,
            "source_distribution": source_dist,
        }
    finally:
        db.close()

@router.post("/coa/debug-classify/{upload_id}")
def debug_classify(upload_id: str):
    """Debug classify with full traceback."""
    import traceback
    try:
        from app.phase1.models.platform_models import SessionLocal
        db = SessionLocal()
        
        # Check upload exists
        row = db.execute(sa_text("SELECT id, upload_status FROM client_coa_uploads WHERE id = :uid"),
            {"uid": upload_id}
        ).fetchone()
        
        if not row:
            return {"error": "Upload not found", "upload_id": upload_id}
        
        # Check accounts exist
        accounts = db.execute(sa_text("SELECT id, account_code, account_name_raw, account_name_normalized, parent_code, normal_balance, account_level, account_type_raw FROM client_chart_of_accounts WHERE coa_upload_id = :uid AND record_status != 'rejected' LIMIT 3"),
            {"uid": upload_id}
        ).fetchall()
        
        if not accounts:
            return {"error": "No accounts found", "upload_status": row[1]}
        
        # Check columns exist
        try:
            db.execute("SELECT normalized_class FROM client_chart_of_accounts LIMIT 1").fetchone()
            cols_ok = True
        except Exception as ce:
            cols_ok = str(ce)
        
        # Try classify one account
        from app.sprint2.services.coa_classifier import classify_account
        sample = accounts[0]
        cls_result = classify_account(
            account_name_raw=sample[2],
            account_name_normalized=sample[3],
            account_code=sample[1],
            normal_balance=sample[5],
            account_level=sample[6],
            account_type_raw=sample[7],
        )
        
        db.close()
        return {
            "upload_found": True,
            "upload_status": row[1],
            "accounts_count": len(accounts),
            "cols_exist": cols_ok,
            "sample_account": sample[2],
            "classification": cls_result,
        }
    except Exception as e:
        return {"error": str(e), "traceback": traceback.format_exc()}
