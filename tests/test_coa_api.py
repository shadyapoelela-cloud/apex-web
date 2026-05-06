"""Chart of Accounts API tests (CoA-1, Sprint 17).

Covers `app/coa/router.py`, `app/coa/service.py`, `app/coa/seeds.py`:
  - CRUD happy paths
  - Hierarchy validation (cycle detection, full_path recompute)
  - Permission filtering at each endpoint
  - Merge correctness (children re-parented, source soft-deactivated)
  - Change_log accuracy
  - Import-template round-trip
  - Prevent-delete-when-used
  - Export round-trip (JSON + CSV)
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.coa.models import AccountChangeLog, AccountTemplate, ChartOfAccount
from app.coa.schemas import AccountCreateIn, AccountUpdateIn
from app.coa.seeds import seed_coa_templates
from app.coa import service as coa_service
from app.phase1.models.platform_models import SessionLocal


JWT_SECRET = os.environ["JWT_SECRET"]


def _token(*, perms: list[str], user_id: str = "u-1", tenant_id: str = "t-coa") -> str:
    return jwt.encode(
        {
            "sub": user_id,
            "user_id": user_id,
            "username": user_id,
            "role": "tester",
            "permissions": perms,
            "tenant_id": tenant_id,
            "type": "access",
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
            "iat": datetime.now(timezone.utc),
        },
        JWT_SECRET,
        algorithm="HS256",
    )


def _hdr(perms: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {_token(perms=perms)}"}


CFO_PERMS = [
    "read:chart_of_accounts",
    "write:chart_of_accounts",
    "delete:chart_of_accounts",
    "merge:chart_of_accounts",
    "import:coa_template",
    "export:chart_of_accounts",
]
READER_PERMS = ["read:chart_of_accounts"]


@pytest.fixture(autouse=True)
def _isolate_test_entity():
    """Each test runs against its own entity_id so they don't pollute
    each other's tree state. Cleanup at teardown wipes any account
    written under the test entity prefix.

    Tenant context is bound to "t-coa" for the test BODY so the
    `TenantMixin` auto-filter in `app.core.tenant_guard` doesn't hide
    rows we just wrote — but we deliberately seed templates BEFORE
    binding the tenant, because templates ship as tenant_id=NULL
    rows (system-shared). If we seeded inside the bound-tenant block,
    `_before_flush` would auto-fill tenant_id="t-coa" on first insert
    and trip the unique constraint on subsequent runs.
    """
    from app.core.tenant_context import set_tenant

    # Seed templates with NULL tenant first.
    db = SessionLocal()
    try:
        seed_coa_templates(db)
    finally:
        db.close()

    # Now bind the tenant for the test body.
    set_tenant("t-coa")
    yield
    set_tenant(None)

    # Teardown — also runs without tenant bound so the cleanup query
    # isn't auto-filtered.
    db = SessionLocal()
    try:
        db.query(ChartOfAccount).filter(
            ChartOfAccount.entity_id.like("e-test-%")
        ).delete(synchronize_session=False)
        db.query(AccountChangeLog).filter(
            AccountChangeLog.tenant_id == "t-coa"
        ).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def _create_root(db, entity_id: str, code: str = "1", name: str = "الأصول") -> ChartOfAccount:
    return coa_service.create_account(
        db,
        AccountCreateIn(
            entity_id=entity_id,
            account_code=code,
            name_ar=name,
            name_en="Assets",
            account_class="asset",
            account_type="asset",
            normal_balance="debit",
            is_postable=False,
        ),
        user_id="seed",
        tenant_id="t-coa",
    )


# ── 1. Seeds + templates ───────────────────────────────────


def test_seeds_create_three_official_templates():
    db = SessionLocal()
    try:
        rows = db.query(AccountTemplate).filter(
            AccountTemplate.is_official == True  # noqa: E712
        ).all()
        codes = {r.code for r in rows}
        assert {"socpa-retail-2024", "ifrs-services-2024", "ifrs-manufacturing-2024"}.issubset(codes)
    finally:
        db.close()


def test_socpa_retail_template_has_all_five_classes():
    db = SessionLocal()
    try:
        t = db.query(AccountTemplate).filter(
            AccountTemplate.code == "socpa-retail-2024"
        ).first()
        assert t is not None
        classes = {a["account_class"] for a in t.accounts}
        assert {"asset", "liability", "equity", "revenue", "expense"} == classes
    finally:
        db.close()


def test_socpa_retail_first_level_is_correct():
    db = SessionLocal()
    try:
        t = db.query(AccountTemplate).filter(
            AccountTemplate.code == "socpa-retail-2024"
        ).first()
        roots = [a for a in t.accounts if a.get("parent_code") is None]
        codes = {a["account_code"] for a in roots}
        assert codes == {"1", "2", "3", "4", "5"}
    finally:
        db.close()


def test_get_templates_endpoint_filters_by_perm(client):
    r = client.get("/api/v1/coa/templates", headers=_hdr(READER_PERMS))
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    codes = {t["code"] for t in body["data"]}
    assert "socpa-retail-2024" in codes


def test_get_templates_unauthenticated_is_401(client):
    r = client.get("/api/v1/coa/templates")
    assert r.status_code == 401


def test_get_templates_without_read_perm_is_403(client):
    r = client.get("/api/v1/coa/templates", headers=_hdr(["write:chart_of_accounts"]))
    assert r.status_code == 403


# ── 2. Create + tree ─────────────────────────────────────


def test_create_root_account(client):
    r = client.post(
        "/api/v1/coa/",
        json={
            "entity_id": "e-test-create",
            "account_code": "1",
            "name_ar": "الأصول",
            "account_class": "asset",
            "account_type": "asset",
            "normal_balance": "debit",
            "is_postable": False,
        },
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 201, r.text
    data = r.json()["data"]
    assert data["account_code"] == "1"
    assert data["level"] == 1
    assert data["full_path"] == "1"


def test_create_with_parent_computes_full_path(client):
    db = SessionLocal()
    try:
        root = _create_root(db, "e-test-path")
    finally:
        db.close()
    r = client.post(
        "/api/v1/coa/",
        json={
            "entity_id": "e-test-path",
            "account_code": "11",
            "parent_id": root.id,
            "name_ar": "أصول متداولة",
            "account_class": "asset",
            "account_type": "current_asset",
            "normal_balance": "debit",
            "is_postable": False,
        },
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 201
    child = r.json()["data"]
    assert child["level"] == 2
    assert child["full_path"] == "1.11"


def test_create_duplicate_code_is_409(client):
    db = SessionLocal()
    try:
        _create_root(db, "e-test-dup")
    finally:
        db.close()
    r = client.post(
        "/api/v1/coa/",
        json={
            "entity_id": "e-test-dup",
            "account_code": "1",
            "name_ar": "Other root with same code",
            "account_class": "asset",
            "account_type": "asset",
            "normal_balance": "debit",
        },
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 409


def test_create_without_write_perm_is_403(client):
    r = client.post(
        "/api/v1/coa/",
        json={
            "entity_id": "e-test-noperm",
            "account_code": "1",
            "name_ar": "Unauthorised",
            "account_class": "asset",
            "account_type": "asset",
            "normal_balance": "debit",
        },
        headers=_hdr(READER_PERMS),
    )
    assert r.status_code == 403


def test_create_invalid_account_class_is_422(client):
    r = client.post(
        "/api/v1/coa/",
        json={
            "entity_id": "e-test-bad-class",
            "account_code": "1",
            "name_ar": "Bad",
            "account_class": "made_up",
            "account_type": "asset",
            "normal_balance": "debit",
        },
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 422


def test_get_tree_returns_nested_structure(client):
    db = SessionLocal()
    try:
        root = _create_root(db, "e-test-tree")
        coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-tree",
                account_code="11",
                parent_id=root.id,
                name_ar="Cur",
                account_class="asset",
                account_type="current_asset",
                normal_balance="debit",
                is_postable=False,
            ),
            user_id="seed",
            tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.get(
        "/api/v1/coa/tree?entity_id=e-test-tree", headers=_hdr(READER_PERMS)
    )
    assert r.status_code == 200
    nodes = r.json()["data"]
    assert len(nodes) == 1  # one root
    assert nodes[0]["account_code"] == "1"
    assert len(nodes[0]["children"]) == 1
    assert nodes[0]["children"][0]["account_code"] == "11"


def test_list_accounts_filters_by_class(client):
    db = SessionLocal()
    try:
        _create_root(db, "e-test-filter", "1", "Asset")
        coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-filter",
                account_code="2",
                name_ar="Liability",
                account_class="liability",
                account_type="liability",
                normal_balance="credit",
                is_postable=False,
            ),
            user_id="seed", tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.get(
        "/api/v1/coa/list?entity_id=e-test-filter&account_class=liability",
        headers=_hdr(READER_PERMS),
    )
    assert r.status_code == 200
    rows = r.json()["data"]
    assert len(rows) == 1
    assert rows[0]["account_class"] == "liability"


def test_list_accounts_search_matches_arabic_name(client):
    db = SessionLocal()
    try:
        coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-search", account_code="1101",
                name_ar="الصندوق الرئيسي",
                account_class="asset", account_type="cash", normal_balance="debit",
            ),
            user_id="seed", tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.get(
        "/api/v1/coa/list?entity_id=e-test-search&search=الصندوق",
        headers=_hdr(READER_PERMS),
    )
    assert r.status_code == 200
    rows = r.json()["data"]
    assert any("الصندوق" in row["name_ar"] for row in rows)


# ── 3. Update / state changes ─────────────────────────────


def test_update_records_diff_in_changelog(client):
    db = SessionLocal()
    try:
        root = _create_root(db, "e-test-update")
    finally:
        db.close()
    r = client.patch(
        f"/api/v1/coa/{root.id}",
        json={"name_ar": "الأصول (محدّث)", "reason": "test rename"},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    assert r.json()["data"]["name_ar"] == "الأصول (محدّث)"

    log = client.get(
        f"/api/v1/coa/{root.id}/changelog", headers=_hdr(READER_PERMS)
    ).json()["data"]
    actions = [e["action"] for e in log]
    assert "update" in actions
    update_entry = next(e for e in log if e["action"] == "update")
    assert update_entry["diff"]["name_ar"]["new"] == "الأصول (محدّث)"
    assert update_entry["reason"] == "test rename"


def test_update_parent_recomputes_descendant_paths():
    db = SessionLocal()
    try:
        root1 = _create_root(db, "e-test-reparent", "1", "Root 1")
        root2 = _create_root(db, "e-test-reparent", "2", "Root 2")
        child = coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-reparent",
                account_code="11", parent_id=root1.id,
                name_ar="Child", account_class="asset",
                account_type="current_asset", normal_balance="debit",
                is_postable=False,
            ),
            user_id="seed", tenant_id="t-coa",
        )
        grand = coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-reparent",
                account_code="111", parent_id=child.id,
                name_ar="Grand", account_class="asset",
                account_type="current_asset", normal_balance="debit",
            ),
            user_id="seed", tenant_id="t-coa",
        )
        assert child.full_path == "1.11"
        assert grand.full_path == "1.11.111"

        coa_service.update_account(
            db, child.id,
            AccountUpdateIn(parent_id=root2.id),
            user_id="u", tenant_id="t-coa",
        )
        # Re-fetch
        c = coa_service.get_account(db, child.id)
        g = coa_service.get_account(db, grand.id)
        assert c.full_path == "2.11"
        assert g.full_path == "2.11.111"
        assert g.level == 3
    finally:
        db.close()


def test_update_cycle_detection_rejects():
    db = SessionLocal()
    try:
        a = _create_root(db, "e-test-cycle", "A", "A")
        b = coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-cycle", account_code="B", parent_id=a.id,
                name_ar="B", account_class="asset",
                account_type="current_asset", normal_balance="debit",
            ),
            user_id="seed", tenant_id="t-coa",
        )
        with pytest.raises(coa_service.InvalidParentError):
            coa_service.update_account(
                db, a.id,
                AccountUpdateIn(parent_id=b.id),
                user_id="u", tenant_id="t-coa",
            )
    finally:
        db.close()


def test_deactivate_marks_inactive_and_logs(client):
    db = SessionLocal()
    try:
        root = _create_root(db, "e-test-deact")
    finally:
        db.close()
    r = client.post(
        f"/api/v1/coa/{root.id}/deactivate",
        json={"reason": "no longer needed"},
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    assert r.json()["data"]["is_active"] is False

    log = client.get(
        f"/api/v1/coa/{root.id}/changelog", headers=_hdr(READER_PERMS)
    ).json()["data"]
    assert any(e["action"] == "deactivate" for e in log)


# ── 4. Delete + usage ────────────────────────────────────


def test_delete_with_children_returns_409(client):
    db = SessionLocal()
    try:
        root = _create_root(db, "e-test-del-children")
        root_id = root.id  # capture before session close to avoid lazy-load
        coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-del-children",
                account_code="11", parent_id=root_id,
                name_ar="Child", account_class="asset",
                account_type="current_asset", normal_balance="debit",
            ),
            user_id="seed", tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.delete(f"/api/v1/coa/{root_id}", headers=_hdr(CFO_PERMS))
    assert r.status_code == 409
    assert "blockers" in r.json()["detail"]


def test_delete_leaf_succeeds(client):
    db = SessionLocal()
    try:
        leaf = _create_root(db, "e-test-del-leaf")
    finally:
        db.close()
    r = client.delete(f"/api/v1/coa/{leaf.id}", headers=_hdr(CFO_PERMS))
    assert r.status_code == 200
    assert coa_service.get_account(SessionLocal(), leaf.id) is None


def test_delete_without_perm_is_403(client):
    db = SessionLocal()
    try:
        leaf = _create_root(db, "e-test-del-noperm")
    finally:
        db.close()
    r = client.delete(
        f"/api/v1/coa/{leaf.id}",
        headers=_hdr(["write:chart_of_accounts"]),  # no delete:
    )
    assert r.status_code == 403


def test_get_usage_returns_blocker_list(client):
    db = SessionLocal()
    try:
        root = _create_root(db, "e-test-usage")
        root_id = root.id
        coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-usage",
                account_code="11", parent_id=root_id,
                name_ar="C", account_class="asset",
                account_type="current_asset", normal_balance="debit",
            ),
            user_id="seed", tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.get(f"/api/v1/coa/{root_id}/usage", headers=_hdr(READER_PERMS))
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["can_delete"] is False
    assert any("children" in b for b in data["deletion_blockers"])


# ── 5. Merge ─────────────────────────────────────────────


def test_merge_reparents_children_and_deactivates_source():
    db = SessionLocal()
    try:
        src = _create_root(db, "e-test-merge", "S", "Source")
        tgt = _create_root(db, "e-test-merge", "T", "Target")
        c1 = coa_service.create_account(
            db,
            AccountCreateIn(
                entity_id="e-test-merge", account_code="S1", parent_id=src.id,
                name_ar="C1", account_class="asset",
                account_type="current_asset", normal_balance="debit",
            ),
            user_id="seed", tenant_id="t-coa",
        )
        result = coa_service.merge_accounts(
            db, src.id, tgt.id, user_id="u", reason="dup", tenant_id="t-coa"
        )
        assert result.id == tgt.id
        c1_re = coa_service.get_account(db, c1.id)
        assert c1_re.parent_id == tgt.id
        src_re = coa_service.get_account(db, src.id)
        assert src_re.is_active is False
        # change log captures merge
        log = (
            db.query(AccountChangeLog)
            .filter(AccountChangeLog.account_id == src.id)
            .all()
        )
        actions = [e.action for e in log]
        assert "merge" in actions
    finally:
        db.close()


def test_merge_self_is_400():
    db = SessionLocal()
    try:
        src = _create_root(db, "e-test-merge-self", "X", "X")
        with pytest.raises(coa_service.CoaError):
            coa_service.merge_accounts(
                db, src.id, src.id, user_id="u", tenant_id="t-coa"
            )
    finally:
        db.close()


def test_merge_endpoint_requires_merge_perm(client):
    r = client.post(
        "/api/v1/coa/merge",
        json={"source_id": "x", "target_id": "y"},
        headers=_hdr(["read:chart_of_accounts", "write:chart_of_accounts"]),
    )
    assert r.status_code == 403


# ── 6. Import template ───────────────────────────────────


def test_import_template_creates_full_tree():
    db = SessionLocal()
    try:
        count = coa_service.import_template(
            db, "ifrs-services-2024", "e-test-import-services",
            user_id="u", tenant_id="t-coa",
        )
        assert count >= 30
        rows = coa_service.list_accounts(db, "e-test-import-services", limit=2000)
        codes = {r.account_code for r in rows}
        assert {"1", "2", "3", "4", "5"}.issubset(codes)
    finally:
        db.close()


def test_import_template_preserves_parent_links():
    db = SessionLocal()
    try:
        coa_service.import_template(
            db, "ifrs-services-2024", "e-test-import-parents",
            user_id="u", tenant_id="t-coa",
        )
        rows = coa_service.list_accounts(db, "e-test-import-parents", limit=2000)
        by_code = {r.account_code: r for r in rows}
        # 110 should be child of 11
        cash = by_code["110"]
        assert cash.parent_id == by_code["11"].id
        assert cash.full_path == "1.11.110"
    finally:
        db.close()


def test_import_template_endpoint_requires_perm(client):
    r = client.post(
        "/api/v1/coa/templates/ifrs-services-2024/import",
        json={"entity_id": "e-test-import-ep"},
        headers=_hdr(READER_PERMS),
    )
    assert r.status_code == 403


def test_import_template_blocks_on_existing_unless_overwrite():
    db = SessionLocal()
    try:
        coa_service.import_template(
            db, "ifrs-services-2024", "e-test-import-overwrite",
            user_id="u", tenant_id="t-coa",
        )
        with pytest.raises(coa_service.CoaError):
            coa_service.import_template(
                db, "ifrs-services-2024", "e-test-import-overwrite",
                user_id="u", tenant_id="t-coa",
            )
        # overwrite=True succeeds
        count = coa_service.import_template(
            db, "ifrs-services-2024", "e-test-import-overwrite",
            user_id="u", tenant_id="t-coa", overwrite=True,
        )
        assert count >= 30
    finally:
        db.close()


# ── 7. Export ────────────────────────────────────────────


def test_export_json_round_trip(client):
    db = SessionLocal()
    try:
        coa_service.import_template(
            db, "ifrs-services-2024", "e-test-export-json",
            user_id="u", tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.get(
        "/api/v1/coa/export?entity_id=e-test-export-json&fmt=json",
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    import json
    parsed = json.loads(r.text)
    assert isinstance(parsed, list)
    assert len(parsed) >= 30


def test_export_csv_has_header_row(client):
    db = SessionLocal()
    try:
        coa_service.import_template(
            db, "ifrs-services-2024", "e-test-export-csv",
            user_id="u", tenant_id="t-coa",
        )
    finally:
        db.close()
    r = client.get(
        "/api/v1/coa/export?entity_id=e-test-export-csv&fmt=csv",
        headers=_hdr(CFO_PERMS),
    )
    assert r.status_code == 200
    first_line = r.text.splitlines()[0]
    assert "account_code" in first_line
    assert "name_ar" in first_line


def test_export_without_perm_is_403(client):
    r = client.get(
        "/api/v1/coa/export?entity_id=e-test-x", headers=_hdr(READER_PERMS)
    )
    assert r.status_code == 403


# ── 8. Service-layer unit ───────────────────────────────


def test_get_recent_changes_returns_latest_first():
    db = SessionLocal()
    try:
        a = _create_root(db, "e-test-recent", "AA", "Recent A")
        coa_service.update_account(
            db, a.id, AccountUpdateIn(name_ar="Recent A v2"),
            user_id="u", tenant_id="t-coa",
        )
        rows = coa_service.get_recent_changes(db, limit=5)
        assert len(rows) >= 2
        assert rows[0].timestamp >= rows[1].timestamp
    finally:
        db.close()


def test_changelog_is_account_scoped():
    db = SessionLocal()
    try:
        a = _create_root(db, "e-test-cl-scope", "A", "A")
        b = _create_root(db, "e-test-cl-scope", "B", "B")
        coa_service.update_account(
            db, a.id, AccountUpdateIn(name_ar="A v2"),
            user_id="u", tenant_id="t-coa",
        )
        a_log = coa_service.get_changelog(db, a.id)
        b_log = coa_service.get_changelog(db, b.id)
        assert all(e.account_id == a.id for e in a_log)
        # b should have only its create
        assert all(e.account_id == b.id for e in b_log)
        assert any(e.action == "create" for e in b_log)
    finally:
        db.close()
