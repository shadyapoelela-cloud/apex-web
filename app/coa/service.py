"""CoA service layer — CRUD, hierarchy, merge, import, audit logger.

Public API used by the FastAPI router and tests:

    list_accounts(db, entity_id, filters)           → list[ChartOfAccount]
    get_account(db, account_id)                     → ChartOfAccount | None
    build_tree(db, entity_id, *, include_inactive)  → list[dict] (nested)
    create_account(db, payload, user_id)            → ChartOfAccount
    update_account(db, account_id, payload, user_id) → ChartOfAccount
    deactivate_account(db, account_id, user_id, reason) → ChartOfAccount
    delete_account(db, account_id, user_id)         → None  (raises on used)
    merge_accounts(db, source_id, target_id, user_id, reason) → ChartOfAccount
    import_template(db, code, entity_id, user_id, *, overwrite) → int
    list_templates(db)                              → list[AccountTemplate]
    get_changelog(db, account_id, *, limit)         → list[AccountChangeLog]
    get_usage(db, account_id)                       → dict

Permission checks live at the router layer; this module assumes the
caller is authorised.
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Iterable, Optional

from sqlalchemy.orm import Session

from app.coa.models import (
    AccountAction,
    AccountChangeLog,
    AccountTemplate,
    ChartOfAccount,
)
from app.coa.schemas import AccountCreateIn, AccountUpdateIn

logger = logging.getLogger(__name__)


# ── Errors ─────────────────────────────────────────────────


class CoaError(Exception):
    """Base class — every service-layer failure derives from this."""


class AccountNotFoundError(CoaError):
    pass


class AccountInUseError(CoaError):
    """Raised when DELETE is requested but the account is referenced
    elsewhere (children, journal lines, etc.)."""

    def __init__(self, blockers: list[str]):
        super().__init__(f"account in use: {', '.join(blockers)}")
        self.blockers = blockers


class AccountCodeConflictError(CoaError):
    pass


class InvalidParentError(CoaError):
    """Cycle detection or cross-entity parent."""


# ── Helpers ────────────────────────────────────────────────


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _new_id() -> str:
    return str(uuid.uuid4())


def _account_to_dict(a: ChartOfAccount) -> dict[str, Any]:
    return {
        "id": a.id,
        "entity_id": a.entity_id,
        "account_code": a.account_code,
        "parent_id": a.parent_id,
        "level": a.level,
        "full_path": a.full_path,
        "name_ar": a.name_ar,
        "name_en": a.name_en,
        "account_class": a.account_class,
        "account_type": a.account_type,
        "normal_balance": a.normal_balance,
        "is_active": a.is_active,
        "is_system": a.is_system,
        "is_postable": a.is_postable,
        "is_reconcilable": a.is_reconcilable,
        "requires_cost_center": a.requires_cost_center,
        "requires_project": a.requires_project,
        "requires_partner": a.requires_partner,
        "default_tax_rate": a.default_tax_rate,
        "standard_ref": a.standard_ref,
        "currency_code": a.currency_code,
        "tags": list(a.tags or []),
        "custom_fields": dict(a.custom_fields or {}),
        "created_at": a.created_at.isoformat() if a.created_at else None,
        "updated_at": a.updated_at.isoformat() if a.updated_at else None,
        "created_by": a.created_by,
    }


def _record_change(
    db: Session,
    account_id: Optional[str],
    action: str,
    diff: dict[str, Any],
    user_id: Optional[str],
    reason: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> AccountChangeLog:
    row = AccountChangeLog(
        id=_new_id(),
        tenant_id=tenant_id,
        account_id=account_id,
        action=action,
        diff=diff,
        user_id=user_id,
        timestamp=_utcnow(),
        reason=reason,
    )
    db.add(row)
    return row


def _compute_full_path(db: Session, parent_id: Optional[str], code: str) -> str:
    """Compute the dot-separated full_path for a new/moved account."""
    if parent_id is None:
        return code
    parent = db.query(ChartOfAccount).filter(ChartOfAccount.id == parent_id).first()
    if parent is None:
        raise InvalidParentError(f"parent not found: {parent_id}")
    return f"{parent.full_path}.{code}" if parent.full_path else code


def _compute_level(db: Session, parent_id: Optional[str]) -> int:
    if parent_id is None:
        return 1
    parent = db.query(ChartOfAccount).filter(ChartOfAccount.id == parent_id).first()
    if parent is None:
        raise InvalidParentError(f"parent not found: {parent_id}")
    return parent.level + 1


def _detect_cycle(db: Session, candidate_parent_id: str, descendant_id: str) -> bool:
    """True when `descendant_id` is in the ancestor chain of
    `candidate_parent_id` — i.e. moving descendant under candidate
    would create a cycle."""
    seen: set[str] = set()
    cur = candidate_parent_id
    while cur is not None:
        if cur == descendant_id:
            return True
        if cur in seen:
            return False  # already-corrupted chain — bail
        seen.add(cur)
        row = db.query(ChartOfAccount).filter(ChartOfAccount.id == cur).first()
        if row is None:
            return False
        cur = row.parent_id
    return False


def _refresh_descendant_paths(db: Session, root_id: str) -> None:
    """When an account moves, every descendant's `full_path` and `level`
    must be recomputed.

    We walk the subtree breadth-first to avoid recursion depth issues.
    """
    queue: list[str] = [root_id]
    while queue:
        nxt: list[str] = []
        for parent_id in queue:
            parent = (
                db.query(ChartOfAccount).filter(ChartOfAccount.id == parent_id).first()
            )
            if parent is None:
                continue
            children = (
                db.query(ChartOfAccount).filter(ChartOfAccount.parent_id == parent_id).all()
            )
            for c in children:
                c.level = parent.level + 1
                c.full_path = (
                    f"{parent.full_path}.{c.account_code}"
                    if parent.full_path
                    else c.account_code
                )
                c.updated_at = _utcnow()
                nxt.append(c.id)
        queue = nxt


# ── Read ───────────────────────────────────────────────────


def list_accounts(
    db: Session,
    entity_id: str,
    *,
    is_active: Optional[bool] = None,
    account_class: Optional[str] = None,
    is_postable: Optional[bool] = None,
    is_reconcilable: Optional[bool] = None,
    search: Optional[str] = None,
    limit: int = 1000,
    offset: int = 0,
) -> list[ChartOfAccount]:
    q = db.query(ChartOfAccount).filter(ChartOfAccount.entity_id == entity_id)
    if is_active is not None:
        q = q.filter(ChartOfAccount.is_active == is_active)
    if account_class is not None:
        q = q.filter(ChartOfAccount.account_class == account_class)
    if is_postable is not None:
        q = q.filter(ChartOfAccount.is_postable == is_postable)
    if is_reconcilable is not None:
        q = q.filter(ChartOfAccount.is_reconcilable == is_reconcilable)
    if search:
        like = f"%{search}%"
        q = q.filter(
            (ChartOfAccount.account_code.ilike(like))
            | (ChartOfAccount.name_ar.ilike(like))
            | (ChartOfAccount.name_en.ilike(like))
        )
    return (
        q.order_by(ChartOfAccount.full_path).offset(offset).limit(limit).all()
    )


def get_account(db: Session, account_id: str) -> Optional[ChartOfAccount]:
    return db.query(ChartOfAccount).filter(ChartOfAccount.id == account_id).first()


def build_tree(
    db: Session, entity_id: str, *, include_inactive: bool = False
) -> list[dict[str, Any]]:
    """Build the nested tree as a list of dicts (root nodes with `children`)."""
    q = db.query(ChartOfAccount).filter(ChartOfAccount.entity_id == entity_id)
    if not include_inactive:
        q = q.filter(ChartOfAccount.is_active == True)  # noqa: E712
    rows = q.order_by(ChartOfAccount.full_path).all()

    by_id: dict[str, dict[str, Any]] = {}
    roots: list[dict[str, Any]] = []
    for r in rows:
        d = _account_to_dict(r)
        d["children"] = []
        by_id[r.id] = d
    for r in rows:
        d = by_id[r.id]
        if r.parent_id and r.parent_id in by_id:
            by_id[r.parent_id]["children"].append(d)
        else:
            roots.append(d)
    return roots


# ── Create / Update / State changes ──────────────────────


def create_account(
    db: Session,
    payload: AccountCreateIn,
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> ChartOfAccount:
    # account_code uniqueness (entity-scoped)
    dup = (
        db.query(ChartOfAccount)
        .filter(
            ChartOfAccount.entity_id == payload.entity_id,
            ChartOfAccount.account_code == payload.account_code,
        )
        .first()
    )
    if dup is not None:
        raise AccountCodeConflictError(
            f"account_code {payload.account_code} already exists for entity"
        )

    level = _compute_level(db, payload.parent_id)
    full_path = _compute_full_path(db, payload.parent_id, payload.account_code)

    if level > 4:
        raise CoaError("4-level hierarchy maximum exceeded")

    row = ChartOfAccount(
        id=_new_id(),
        tenant_id=tenant_id,
        entity_id=payload.entity_id,
        account_code=payload.account_code,
        parent_id=payload.parent_id,
        level=level,
        full_path=full_path,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        account_class=payload.account_class,
        account_type=payload.account_type,
        normal_balance=payload.normal_balance,
        is_active=payload.is_active,
        is_system=payload.is_system,
        is_postable=payload.is_postable,
        is_reconcilable=payload.is_reconcilable,
        requires_cost_center=payload.requires_cost_center,
        requires_project=payload.requires_project,
        requires_partner=payload.requires_partner,
        default_tax_rate=payload.default_tax_rate,
        standard_ref=payload.standard_ref,
        currency_code=payload.currency_code,
        tags=list(payload.tags or []),
        custom_fields=dict(payload.custom_fields or {}),
        created_by=user_id,
    )
    db.add(row)
    _record_change(
        db,
        account_id=row.id,
        action=AccountAction.CREATE,
        diff={"new": _account_to_dict(row)},
        user_id=user_id,
        tenant_id=tenant_id,
    )
    db.commit()
    db.refresh(row)
    return row


def update_account(
    db: Session,
    account_id: str,
    payload: AccountUpdateIn,
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> ChartOfAccount:
    row = get_account(db, account_id)
    if row is None:
        raise AccountNotFoundError(f"account not found: {account_id}")

    diff: dict[str, dict[str, Any]] = {}
    fields = (
        "account_code", "parent_id", "name_ar", "name_en", "account_class",
        "account_type", "normal_balance", "is_active", "is_postable",
        "is_reconcilable", "requires_cost_center", "requires_project",
        "requires_partner", "default_tax_rate", "standard_ref",
        "currency_code", "tags", "custom_fields",
    )
    parent_changed = False
    code_changed = False
    for f in fields:
        new_v = getattr(payload, f, None)
        if new_v is None:
            continue
        old_v = getattr(row, f)
        if isinstance(old_v, list):
            old_serial = list(old_v)
        elif isinstance(old_v, dict):
            old_serial = dict(old_v)
        else:
            old_serial = old_v
        if old_serial == new_v:
            continue
        diff[f] = {"old": old_serial, "new": new_v}
        if f == "parent_id":
            parent_changed = True
        if f == "account_code":
            code_changed = True
        setattr(row, f, new_v)

    if not diff:
        return row  # no-op

    # Cycle + level + path recomputation when the parent moved.
    if parent_changed:
        if row.parent_id is not None and _detect_cycle(db, row.parent_id, row.id):
            raise InvalidParentError("cycle detected")
        row.level = _compute_level(db, row.parent_id)

    if parent_changed or code_changed:
        row.full_path = _compute_full_path(db, row.parent_id, row.account_code)
        row.updated_at = _utcnow()
        # commit once so descendants see the new parent.full_path
        db.flush()
        _refresh_descendant_paths(db, row.id)

    row.updated_at = _utcnow()
    _record_change(
        db,
        account_id=row.id,
        action=AccountAction.UPDATE,
        diff=diff,
        user_id=user_id,
        reason=payload.reason,
        tenant_id=tenant_id,
    )
    db.commit()
    db.refresh(row)
    return row


def deactivate_account(
    db: Session,
    account_id: str,
    *,
    user_id: Optional[str] = None,
    reason: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> ChartOfAccount:
    row = get_account(db, account_id)
    if row is None:
        raise AccountNotFoundError(f"account not found: {account_id}")
    if not row.is_active:
        return row
    row.is_active = False
    row.updated_at = _utcnow()
    _record_change(
        db,
        account_id=row.id,
        action=AccountAction.DEACTIVATE,
        diff={"is_active": {"old": True, "new": False}},
        user_id=user_id,
        reason=reason,
        tenant_id=tenant_id,
    )
    db.commit()
    db.refresh(row)
    return row


def reactivate_account(
    db: Session,
    account_id: str,
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> ChartOfAccount:
    row = get_account(db, account_id)
    if row is None:
        raise AccountNotFoundError(f"account not found: {account_id}")
    if row.is_active:
        return row
    row.is_active = True
    row.updated_at = _utcnow()
    _record_change(
        db,
        account_id=row.id,
        action=AccountAction.REACTIVATE,
        diff={"is_active": {"old": False, "new": True}},
        user_id=user_id,
        tenant_id=tenant_id,
    )
    db.commit()
    db.refresh(row)
    return row


def _get_blockers(db: Session, row: ChartOfAccount) -> list[str]:
    blockers: list[str] = []
    child_count = (
        db.query(ChartOfAccount).filter(ChartOfAccount.parent_id == row.id).count()
    )
    if child_count:
        blockers.append(f"has_{child_count}_children")
    if row.is_system:
        blockers.append("is_system_account")

    # Journal-line linkage — best-effort across known JE tables.
    je_tables = ("pilot_journal_lines", "journal_lines", "journal_entry_lines")
    bind = db.get_bind()
    try:
        from sqlalchemy import inspect as sa_inspect

        inspector = sa_inspect(bind)
        for tname in je_tables:
            if not inspector.has_table(tname):
                continue
            cols = {c["name"] for c in inspector.get_columns(tname)}
            account_col = None
            for c in ("account_id", "gl_account_id", "coa_account_id"):
                if c in cols:
                    account_col = c
                    break
            if account_col is None:
                continue
            from sqlalchemy import text

            r = bind.execute(
                text(f"SELECT count(*) FROM {tname} WHERE {account_col} = :aid"),
                {"aid": row.id},
            ).scalar() or 0
            if r:
                blockers.append(f"has_{int(r)}_{tname}_lines")
                break
    except Exception as e:  # noqa: BLE001
        logger.warning("usage check failed: %s", e)

    return blockers


def delete_account(
    db: Session,
    account_id: str,
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> None:
    row = get_account(db, account_id)
    if row is None:
        raise AccountNotFoundError(f"account not found: {account_id}")

    blockers = _get_blockers(db, row)
    if blockers:
        raise AccountInUseError(blockers)

    snapshot = _account_to_dict(row)
    db.delete(row)
    _record_change(
        db,
        account_id=account_id,
        action=AccountAction.DELETE,
        diff={"old": snapshot},
        user_id=user_id,
        tenant_id=tenant_id,
    )
    db.commit()


def merge_accounts(
    db: Session,
    source_id: str,
    target_id: str,
    *,
    user_id: Optional[str] = None,
    reason: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> ChartOfAccount:
    """Target absorbs source: source's children re-parent to target,
    source is then soft-deactivated and tagged with `merged_into=target_id`.

    We deliberately don't hard-delete source so the historical journal
    references stay valid. The change_log carries the merge metadata.
    """
    if source_id == target_id:
        raise CoaError("source and target are the same account")
    source = get_account(db, source_id)
    target = get_account(db, target_id)
    if source is None:
        raise AccountNotFoundError(f"source not found: {source_id}")
    if target is None:
        raise AccountNotFoundError(f"target not found: {target_id}")
    if source.entity_id != target.entity_id:
        raise CoaError("source and target belong to different entities")

    # Re-parent children
    children = (
        db.query(ChartOfAccount).filter(ChartOfAccount.parent_id == source.id).all()
    )
    for c in children:
        c.parent_id = target.id
        c.full_path = _compute_full_path(db, target.id, c.account_code)
        c.level = _compute_level(db, target.id)
        c.updated_at = _utcnow()
        _refresh_descendant_paths(db, c.id)

    source.is_active = False
    source.tags = list(source.tags or []) + [f"merged_into:{target.id}"]
    source.updated_at = _utcnow()

    _record_change(
        db,
        account_id=source.id,
        action=AccountAction.MERGE,
        diff={"merged_into": target.id, "children_moved": [c.id for c in children]},
        user_id=user_id,
        reason=reason,
        tenant_id=tenant_id,
    )
    db.commit()
    db.refresh(target)
    return target


# ── Templates ─────────────────────────────────────────────


def list_templates(db: Session) -> list[AccountTemplate]:
    return (
        db.query(AccountTemplate)
        .filter(AccountTemplate.is_active == True)  # noqa: E712
        .order_by(AccountTemplate.code)
        .all()
    )


def get_template(db: Session, code: str) -> Optional[AccountTemplate]:
    return db.query(AccountTemplate).filter(AccountTemplate.code == code).first()


def import_template(
    db: Session,
    template_code: str,
    entity_id: str,
    *,
    user_id: Optional[str] = None,
    overwrite: bool = False,
    tenant_id: Optional[str] = None,
) -> int:
    """Insert every account from `template.accounts` into the
    `chart_of_accounts` table for `entity_id`. Returns the number of
    accounts created. Raises CoaError on conflict unless overwrite=True.
    """
    template = get_template(db, template_code)
    if template is None:
        raise CoaError(f"template not found: {template_code}")

    accounts = list(template.accounts or [])
    if not accounts:
        return 0

    if not overwrite:
        existing = (
            db.query(ChartOfAccount)
            .filter(ChartOfAccount.entity_id == entity_id)
            .count()
        )
        if existing:
            raise CoaError(
                f"entity {entity_id} already has {existing} accounts; "
                "pass overwrite=True to replace"
            )

    if overwrite:
        db.query(ChartOfAccount).filter(
            ChartOfAccount.entity_id == entity_id
        ).delete(synchronize_session=False)
        db.flush()

    # Sort by level so parents are inserted before children.
    accounts.sort(key=lambda d: d.get("level", 1))

    # Track id + full_path + level locally so we don't re-query the
    # session for parents we just added. (Autoflush + TenantMixin
    # filter combo can hide just-inserted rows from the same session.)
    code_to_meta: dict[str, dict[str, Any]] = {}
    created = 0
    for spec in accounts:
        new_id = _new_id()
        parent_code = spec.get("parent_code")
        parent_meta = code_to_meta.get(parent_code) if parent_code else None
        if parent_meta:
            level = parent_meta["level"] + 1
            parent_path = parent_meta["full_path"]
            full_path = (
                f"{parent_path}.{spec['account_code']}"
                if parent_path
                else spec["account_code"]
            )
            parent_db_id = parent_meta["id"]
        else:
            level = spec.get("level", 1)
            full_path = spec["account_code"]
            parent_db_id = None
        row = ChartOfAccount(
            id=new_id,
            tenant_id=tenant_id,
            entity_id=entity_id,
            account_code=spec["account_code"],
            parent_id=parent_db_id,
            level=level,
            full_path=full_path,
            name_ar=spec["name_ar"],
            name_en=spec.get("name_en"),
            account_class=spec["account_class"],
            account_type=spec.get("account_type", spec["account_class"]),
            normal_balance=spec["normal_balance"],
            is_active=spec.get("is_active", True),
            is_system=spec.get("is_system", False),
            is_postable=spec.get("is_postable", True),
            is_reconcilable=spec.get("is_reconcilable", False),
            requires_cost_center=spec.get("requires_cost_center", False),
            requires_project=spec.get("requires_project", False),
            requires_partner=spec.get("requires_partner", False),
            default_tax_rate=spec.get("default_tax_rate"),
            standard_ref=spec.get("standard_ref"),
            currency_code=spec.get("currency_code"),
            tags=list(spec.get("tags") or []),
            custom_fields=dict(spec.get("custom_fields") or {}),
            created_by=user_id,
        )
        db.add(row)
        code_to_meta[spec["account_code"]] = {
            "id": new_id,
            "level": level,
            "full_path": full_path,
        }
        created += 1

    _record_change(
        db,
        account_id=None,
        action=AccountAction.IMPORT_TEMPLATE,
        diff={"template_code": template_code, "entity_id": entity_id, "count": created},
        user_id=user_id,
        tenant_id=tenant_id,
    )
    db.commit()
    return created


# ── Audit / Usage ────────────────────────────────────────


def get_changelog(
    db: Session, account_id: str, *, limit: int = 50
) -> list[AccountChangeLog]:
    return (
        db.query(AccountChangeLog)
        .filter(AccountChangeLog.account_id == account_id)
        .order_by(AccountChangeLog.timestamp.desc())
        .limit(limit)
        .all()
    )


def get_recent_changes(db: Session, *, limit: int = 50) -> list[AccountChangeLog]:
    """Tenant-scoped (via TenantMixin filter); used by the dashboard
    `list.recent_account_changes` widget."""
    return (
        db.query(AccountChangeLog)
        .order_by(AccountChangeLog.timestamp.desc())
        .limit(limit)
        .all()
    )


def get_usage(db: Session, account_id: str) -> dict[str, Any]:
    row = get_account(db, account_id)
    if row is None:
        raise AccountNotFoundError(f"account not found: {account_id}")
    blockers = _get_blockers(db, row)
    can_delete = not blockers
    journal_line_count = 0
    last_used: Optional[datetime] = None
    bind = db.get_bind()
    try:
        from sqlalchemy import inspect as sa_inspect, text

        inspector = sa_inspect(bind)
        for tname in ("pilot_journal_lines", "journal_lines", "journal_entry_lines"):
            if not inspector.has_table(tname):
                continue
            cols = {c["name"] for c in inspector.get_columns(tname)}
            account_col = None
            for c in ("account_id", "gl_account_id", "coa_account_id"):
                if c in cols:
                    account_col = c
                    break
            if account_col is None:
                continue
            cnt = bind.execute(
                text(f"SELECT count(*) FROM {tname} WHERE {account_col} = :aid"),
                {"aid": account_id},
            ).scalar() or 0
            journal_line_count += int(cnt)
            break
    except Exception:  # noqa: BLE001
        pass

    return {
        "account_id": account_id,
        "journal_lines": journal_line_count,
        "last_used_at": last_used,
        "is_used_in_drafts": False,
        "can_delete": can_delete,
        "deletion_blockers": blockers,
    }


def export_accounts(
    db: Session, entity_id: str, *, fmt: str = "json"
) -> str:
    """Export the entity's full chart as JSON/CSV. XLSX hookup is a
    follow-up (csv covers most operator needs)."""
    rows = list_accounts(db, entity_id, limit=10000)
    serialised = [_account_to_dict(r) for r in rows]
    if fmt == "json":
        return json.dumps(serialised, ensure_ascii=False, indent=2, default=str)
    if fmt == "csv":
        import csv
        import io

        buf = io.StringIO()
        if not serialised:
            return ""
        writer = csv.DictWriter(buf, fieldnames=list(serialised[0].keys()))
        writer.writeheader()
        for r in serialised:
            row = {
                k: (json.dumps(v, ensure_ascii=False) if isinstance(v, (list, dict)) else v)
                for k, v in r.items()
            }
            writer.writerow(row)
        return buf.getvalue()
    raise CoaError(f"unsupported format: {fmt}")


__all__ = [
    "CoaError",
    "AccountNotFoundError",
    "AccountInUseError",
    "AccountCodeConflictError",
    "InvalidParentError",
    "list_accounts",
    "get_account",
    "build_tree",
    "create_account",
    "update_account",
    "deactivate_account",
    "reactivate_account",
    "delete_account",
    "merge_accounts",
    "list_templates",
    "get_template",
    "import_template",
    "get_changelog",
    "get_recent_changes",
    "get_usage",
    "export_accounts",
]
