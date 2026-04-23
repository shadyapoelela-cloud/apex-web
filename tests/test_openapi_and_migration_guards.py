"""Regression guards for the April 24, 2026 post-deploy audit.

Two classes of bugs this file defends against:

1. ``/openapi.json`` returning 500 because a route was declared with
   ``response_class=None``. FastAPI's OpenAPI generator trips on that
   with ``AssertionError: A response class is needed to generate
   OpenAPI``, which breaks Swagger UI, auto-docs fetch, and any SDK
   generator pointing at the live schema. Caught in production by
   ``scripts/post_deploy_check.sh`` — locking it in with a real
   unit test so it can't regress silently.

2. The integrity-constraints migration (``e4c7d9f8a123``) losing its
   ``_has_column`` guards. Those guards are what keep prod from
   blowing up on schema-drifted columns (see the commit history —
   prod's ``clients`` table was bootstrapped before
   ``vat_registration_number`` existed and ``create_all`` never
   back-fills). A well-meaning future "clean-up" PR that strips them
   would silently re-break the deploy path on the next Alembic run.
"""

from __future__ import annotations

import pathlib
import re

from fastapi.routing import APIRoute


# ══════════════════════════════════════════════════════════════════════
# 1. OpenAPI schema generates cleanly
# ══════════════════════════════════════════════════════════════════════
def test_openapi_schema_generates_without_errors() -> None:
    """Regenerating the schema must not raise. A route declared with
    ``response_class=None`` will trip FastAPI's internal assertion."""
    from app.main import app
    schema = app.openapi()
    assert isinstance(schema, dict)
    assert "paths" in schema
    # Sanity: we should have a meaningful number of paths. If someone
    # accidentally wipes the router registrations this will catch it.
    assert len(schema["paths"]) >= 100, (
        f"Only {len(schema['paths'])} paths in schema — did routers fail to mount?"
    )


def test_every_api_route_has_a_response_class() -> None:
    """Every APIRoute must have a non-None ``response_class``. Explicit
    ``response_class=None`` is the bug that 500'd ``/openapi.json``
    on 2026-04-24 — the regression guard is simply ``!= None``."""
    from app.main import app
    offenders: list[str] = []
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        if getattr(route, "response_class", None) is None:
            methods = ",".join(sorted(route.methods or []))
            offenders.append(f"{methods} {route.path} (name={route.name})")
    assert not offenders, (
        "Routes with response_class=None (breaks /openapi.json):\n  - "
        + "\n  - ".join(offenders)
    )


def test_openapi_endpoint_returns_200() -> None:
    """End-to-end: hitting ``/openapi.json`` through the TestClient must
    return 200 with a valid schema body. This is the exact failure
    mode that ``scripts/post_deploy_check.sh`` caught in production."""
    from fastapi.testclient import TestClient
    from app.main import app
    client = TestClient(app)
    r = client.get("/openapi.json")
    assert r.status_code == 200, (
        f"/openapi.json returned {r.status_code}: {r.text[:400]}"
    )
    data = r.json()
    assert data.get("openapi", "").startswith("3."), "not an OpenAPI 3.x schema"
    assert "paths" in data


# ══════════════════════════════════════════════════════════════════════
# 2. Integrity-constraints migration keeps its _has_column guards
# ══════════════════════════════════════════════════════════════════════
_MIGRATION_PATH = (
    pathlib.Path(__file__).parent.parent
    / "alembic" / "versions"
    / "e4c7d9f8a123_integrity_constraints_vat_unique_je_balance_membership_audit.py"
)


def test_integrity_migration_has_column_drift_guards() -> None:
    """The integrity-constraints migration MUST check that the columns
    it references exist before touching them. Prod's ``clients`` table
    predates ``vat_registration_number`` (bootstrapped via
    ``create_all()`` at an older model revision); without the guard the
    ``CREATE UNIQUE INDEX`` raises UndefinedColumn and kills startup."""
    assert _MIGRATION_PATH.exists(), f"migration not at {_MIGRATION_PATH}"
    src = _MIGRATION_PATH.read_text(encoding="utf-8")

    # Must define the helper function.
    assert "def _has_column(" in src, (
        "migration must define _has_column helper (see ~line 59)"
    )

    # Must guard the VAT index against the column missing.
    assert re.search(
        r'_has_column\(\s*"clients"\s*,\s*"vat_registration_number"\s*\)',
        src,
    ), "VAT unique index creation must be guarded by _has_column for vat_registration_number"

    # Must guard the JE balance CHECK against the columns missing.
    assert re.search(
        r'_has_column\(\s*"pilot_journal_entries"\s*,\s*"total_debit"\s*\)',
        src,
    ), "JE balance CHECK must be guarded by _has_column for total_debit"
    assert re.search(
        r'_has_column\(\s*"pilot_journal_entries"\s*,\s*"total_credit"\s*\)',
        src,
    ), "JE balance CHECK must be guarded by _has_column for total_credit"

    # Must guard the JE line XOR CHECK against the columns missing.
    assert re.search(
        r'_has_column\(\s*"pilot_journal_lines"\s*,\s*"debit"\s*\)',
        src,
    ), "JE line CHECK must be guarded by _has_column for debit"
    assert re.search(
        r'_has_column\(\s*"pilot_journal_lines"\s*,\s*"credit"\s*\)',
        src,
    ), "JE line CHECK must be guarded by _has_column for credit"


def test_integrity_migration_bails_out_on_missing_tables() -> None:
    """The migration must skip entirely if the target tables don't
    exist yet (happens on fresh CI DBs where app tables are created
    later via create_all)."""
    src = _MIGRATION_PATH.read_text(encoding="utf-8")
    # Each operation block must start with a _has_table guard.
    for table in (
        "clients",
        "pilot_journal_entries",
        "pilot_journal_lines",
        "client_memberships",
    ):
        assert f'_has_table("{table}")' in src, (
            f"migration must guard {table!r} operations with _has_table"
        )
