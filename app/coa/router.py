"""FastAPI surface for the Chart of Accounts.

Mounted by app/main.py via the HAS_COA try/except guard at:

    /api/v1/coa/tree                          read:chart_of_accounts
    /api/v1/coa/list                          read:chart_of_accounts
    /api/v1/coa/{id}                          read:chart_of_accounts
    /api/v1/coa/                              POST   write:chart_of_accounts
    /api/v1/coa/{id}                          PATCH  write:chart_of_accounts
    /api/v1/coa/{id}                          DELETE delete:chart_of_accounts
    /api/v1/coa/{id}/deactivate               POST   write:chart_of_accounts
    /api/v1/coa/{id}/reactivate               POST   write:chart_of_accounts
    /api/v1/coa/merge                         POST   merge:chart_of_accounts
    /api/v1/coa/templates                     read:chart_of_accounts
    /api/v1/coa/templates/{code}/import       import:coa_template
    /api/v1/coa/{id}/changelog                read:chart_of_accounts
    /api/v1/coa/{id}/usage                    read:chart_of_accounts
    /api/v1/coa/export                        export:chart_of_accounts
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import PlainTextResponse

from app.coa.models import ChartOfAccount
from app.coa.schemas import (
    AccountCreateIn,
    AccountOut,
    AccountUpdateIn,
    ChangeLogEntryOut,
    DeactivateIn,
    ImportTemplateIn,
    MergeIn,
    TemplateDetailOut,
    TemplateSummaryOut,
    UsageReportOut,
)
from app.coa import service as coa_service
from app.core.api_version import v1_prefix
from app.phase1.models.platform_models import SessionLocal
from app.phase1.routes.phase1_routes import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix=v1_prefix("/coa"), tags=["Chart of Accounts"])


# ── Permission helper ─────────────────────────────────────


def _user_perms(user: dict) -> set[str]:
    raw = user.get("permissions") if user else None
    if isinstance(raw, list):
        return {str(p) for p in raw}
    if isinstance(raw, set):
        return {str(p) for p in raw}
    role = user.get("role") if user else None
    if role:
        try:
            from app.core.custom_roles import role_permissions

            resolved = role_permissions(role)
            if resolved:
                return set(resolved)
        except Exception:  # noqa: BLE001
            pass
    return set()


def _require(user: dict, perm: str) -> None:
    if perm not in _user_perms(user):
        raise HTTPException(status_code=403, detail=f"missing permission: {perm}")


# ── Serialization ─────────────────────────────────────────


def _to_out(a: ChartOfAccount) -> AccountOut:
    return AccountOut(
        id=a.id,
        entity_id=a.entity_id,
        account_code=a.account_code,
        parent_id=a.parent_id,
        level=a.level,
        full_path=a.full_path,
        name_ar=a.name_ar,
        name_en=a.name_en,
        account_class=a.account_class,
        account_type=a.account_type,
        normal_balance=a.normal_balance,
        is_active=bool(a.is_active),
        is_system=bool(a.is_system),
        is_postable=bool(a.is_postable),
        is_reconcilable=bool(a.is_reconcilable),
        requires_cost_center=bool(a.requires_cost_center),
        requires_project=bool(a.requires_project),
        requires_partner=bool(a.requires_partner),
        default_tax_rate=a.default_tax_rate,
        standard_ref=a.standard_ref,
        currency_code=a.currency_code,
        tags=list(a.tags or []),
        custom_fields=dict(a.custom_fields or {}),
        created_at=a.created_at,
        updated_at=a.updated_at,
        created_by=a.created_by,
    )


# ── READ ──────────────────────────────────────────────────


@router.get("/tree")
def get_tree(
    entity_id: str = Query(..., min_length=1),
    include_inactive: bool = Query(False),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:chart_of_accounts")
    db = SessionLocal()
    try:
        nodes = coa_service.build_tree(
            db, entity_id, include_inactive=include_inactive
        )
        return {"success": True, "data": nodes}
    finally:
        db.close()


@router.get("/list")
def list_accounts(
    entity_id: str = Query(..., min_length=1),
    is_active: Optional[bool] = Query(None),
    account_class: Optional[str] = Query(None),
    is_postable: Optional[bool] = Query(None),
    is_reconcilable: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
    limit: int = Query(1000, ge=1, le=5000),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:chart_of_accounts")
    db = SessionLocal()
    try:
        rows = coa_service.list_accounts(
            db, entity_id,
            is_active=is_active,
            account_class=account_class,
            is_postable=is_postable,
            is_reconcilable=is_reconcilable,
            search=search,
            limit=limit, offset=offset,
        )
        return {
            "success": True,
            "data": [_to_out(r).model_dump(mode="json") for r in rows],
        }
    finally:
        db.close()


@router.get("/templates")
def list_templates(user: dict = Depends(get_current_user)):
    _require(user, "read:chart_of_accounts")
    db = SessionLocal()
    try:
        rows = coa_service.list_templates(db)
        out = [
            TemplateSummaryOut(
                id=r.id,
                code=r.code,
                name_ar=r.name_ar,
                name_en=r.name_en,
                description_ar=r.description_ar,
                description_en=r.description_en,
                standard=r.standard,
                industry=r.industry,
                account_count=r.account_count,
                is_official=bool(r.is_official),
                created_at=r.created_at,
            ).model_dump(mode="json")
            for r in rows
        ]
        return {"success": True, "data": out}
    finally:
        db.close()


@router.get("/export", response_class=PlainTextResponse)
def export_accounts(
    entity_id: str = Query(..., min_length=1),
    fmt: str = Query("json", pattern="^(json|csv)$"),
    user: dict = Depends(get_current_user),
):
    _require(user, "export:chart_of_accounts")
    db = SessionLocal()
    try:
        return coa_service.export_accounts(db, entity_id, fmt=fmt)
    finally:
        db.close()


@router.get("/{account_id}")
def get_account(account_id: str, user: dict = Depends(get_current_user)):
    _require(user, "read:chart_of_accounts")
    db = SessionLocal()
    try:
        row = coa_service.get_account(db, account_id)
        if row is None:
            raise HTTPException(status_code=404, detail="account not found")
        return {"success": True, "data": _to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.get("/{account_id}/changelog")
def get_changelog(
    account_id: str,
    limit: int = Query(50, ge=1, le=500),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:chart_of_accounts")
    db = SessionLocal()
    try:
        rows = coa_service.get_changelog(db, account_id, limit=limit)
        out = [
            ChangeLogEntryOut(
                id=r.id,
                account_id=r.account_id,
                action=r.action,
                diff=r.diff or {},
                user_id=r.user_id,
                timestamp=r.timestamp,
                reason=r.reason,
            ).model_dump(mode="json")
            for r in rows
        ]
        return {"success": True, "data": out}
    finally:
        db.close()


@router.get("/{account_id}/usage")
def get_usage(account_id: str, user: dict = Depends(get_current_user)):
    _require(user, "read:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            data = coa_service.get_usage(db, account_id)
        except coa_service.AccountNotFoundError:
            raise HTTPException(status_code=404, detail="account not found")
        return {"success": True, "data": UsageReportOut(**data).model_dump(mode="json")}
    finally:
        db.close()


# ── WRITE ─────────────────────────────────────────────────


@router.post("/", status_code=201)
def create_account(payload: AccountCreateIn, user: dict = Depends(get_current_user)):
    _require(user, "write:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            row = coa_service.create_account(
                db, payload,
                user_id=user.get("user_id") or user.get("sub"),
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.AccountCodeConflictError as e:
            raise HTTPException(status_code=409, detail=str(e))
        except coa_service.InvalidParentError as e:
            raise HTTPException(status_code=422, detail=str(e))
        except coa_service.CoaError as e:
            raise HTTPException(status_code=400, detail=str(e))
        return {"success": True, "data": _to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.patch("/{account_id}")
def update_account(
    account_id: str,
    payload: AccountUpdateIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "write:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            row = coa_service.update_account(
                db, account_id, payload,
                user_id=user.get("user_id") or user.get("sub"),
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.AccountNotFoundError:
            raise HTTPException(status_code=404, detail="account not found")
        except coa_service.InvalidParentError as e:
            raise HTTPException(status_code=422, detail=str(e))
        except coa_service.CoaError as e:
            raise HTTPException(status_code=400, detail=str(e))
        return {"success": True, "data": _to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/{account_id}/deactivate")
def deactivate_account(
    account_id: str,
    payload: DeactivateIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "write:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            row = coa_service.deactivate_account(
                db, account_id,
                user_id=user.get("user_id") or user.get("sub"),
                reason=payload.reason,
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.AccountNotFoundError:
            raise HTTPException(status_code=404, detail="account not found")
        return {"success": True, "data": _to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/{account_id}/reactivate")
def reactivate_account(
    account_id: str, user: dict = Depends(get_current_user)
):
    _require(user, "write:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            row = coa_service.reactivate_account(
                db, account_id,
                user_id=user.get("user_id") or user.get("sub"),
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.AccountNotFoundError:
            raise HTTPException(status_code=404, detail="account not found")
        return {"success": True, "data": _to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.delete("/{account_id}")
def delete_account(account_id: str, user: dict = Depends(get_current_user)):
    _require(user, "delete:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            coa_service.delete_account(
                db, account_id,
                user_id=user.get("user_id") or user.get("sub"),
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.AccountNotFoundError:
            raise HTTPException(status_code=404, detail="account not found")
        except coa_service.AccountInUseError as e:
            raise HTTPException(
                status_code=409,
                detail={"error": "account_in_use", "blockers": e.blockers},
            )
        return {"success": True, "data": {"id": account_id}}
    finally:
        db.close()


@router.post("/merge")
def merge_accounts(payload: MergeIn, user: dict = Depends(get_current_user)):
    _require(user, "merge:chart_of_accounts")
    db = SessionLocal()
    try:
        try:
            row = coa_service.merge_accounts(
                db, payload.source_id, payload.target_id,
                user_id=user.get("user_id") or user.get("sub"),
                reason=payload.reason,
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.AccountNotFoundError as e:
            raise HTTPException(status_code=404, detail=str(e))
        except coa_service.CoaError as e:
            raise HTTPException(status_code=400, detail=str(e))
        return {"success": True, "data": _to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/templates/{code}/import")
def import_template(
    code: str,
    payload: ImportTemplateIn,
    user: dict = Depends(get_current_user),
):
    _require(user, "import:coa_template")
    db = SessionLocal()
    try:
        try:
            count = coa_service.import_template(
                db, code, payload.entity_id,
                user_id=user.get("user_id") or user.get("sub"),
                overwrite=payload.overwrite,
                tenant_id=user.get("tenant_id"),
            )
        except coa_service.CoaError as e:
            raise HTTPException(status_code=400, detail=str(e))
        return {"success": True, "data": {"imported": count, "code": code}}
    finally:
        db.close()


__all__ = ["router"]
