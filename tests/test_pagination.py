"""Tests for cursor-based pagination.

Covers:
  • encode/decode roundtrip for each supported type
  • tampered / malformed cursors raise CursorError
  • paginate() returns first page + next_cursor + has_more correctly
  • subsequent pages follow the cursor forward
  • desc direction works
  • limit is clamped to MAX_LIMIT
  • cursor from mismatched sort is rejected
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

import pytest


# ── Cursor encode/decode ────────────────────────────────────


def test_encode_decode_int():
    from app.core.pagination import decode_cursor, encode_cursor

    c = encode_cursor("id", "asc", 42)
    assert decode_cursor(c) == ("id", "asc", 42)


def test_encode_decode_string():
    from app.core.pagination import decode_cursor, encode_cursor

    c = encode_cursor("name", "desc", "أحمد")
    f, d, v = decode_cursor(c)
    assert f == "name"
    assert d == "desc"
    assert v == "أحمد"


def test_encode_decode_datetime():
    from app.core.pagination import decode_cursor, encode_cursor

    dt = datetime(2026, 4, 17, 10, 30)
    c = encode_cursor("created_at", "desc", dt)
    f, d, v = decode_cursor(c)
    assert v == dt


def test_encode_decode_date():
    from app.core.pagination import decode_cursor, encode_cursor

    d0 = date(2026, 1, 15)
    c = encode_cursor("txn_date", "asc", d0)
    f, d, v = decode_cursor(c)
    assert v == d0


def test_encode_decode_decimal():
    from app.core.pagination import decode_cursor, encode_cursor

    amt = Decimal("12345.67")
    c = encode_cursor("amount", "desc", amt)
    f, d, v = decode_cursor(c)
    assert v == amt
    assert isinstance(v, Decimal)


def test_decode_empty_raises():
    from app.core.pagination import CursorError, decode_cursor

    with pytest.raises(CursorError):
        decode_cursor("")


def test_decode_garbage_raises():
    from app.core.pagination import CursorError, decode_cursor

    with pytest.raises(CursorError):
        decode_cursor("not_valid_base64_!!!###")


def test_decode_missing_key_raises():
    import base64
    import json

    from app.core.pagination import CursorError, decode_cursor

    # Valid base64, valid JSON, missing 'f'
    tampered = base64.urlsafe_b64encode(
        json.dumps({"d": "asc", "v": 1}).encode()
    ).decode().rstrip("=")
    with pytest.raises(CursorError):
        decode_cursor(tampered)


# ── paginate() against a real table ─────────────────────────


@pytest.fixture
def _db_session_with_hr_data():
    """Create 30 employees with a unique prefix per test, then clean up."""
    from app import main  # noqa: F401
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import with_system_context
    from app.hr.models import Employee
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    set_tenant(None)
    # Unique prefix per fixture invocation — isolates tests from each other.
    prefix = f"PG-{uuid.uuid4().hex[:8]}"

    with with_system_context():
        for i in range(30):
            emp = Employee(
                id=str(uuid.uuid4()),
                tenant_id=None,
                employee_number=f"{prefix}-{i:04d}",
                name_ar=f"موظف {i}",
                hire_date=date(2026, 1, 1),
                basic_salary=Decimal("1000"),
                housing_allowance=Decimal("0"),
                transport_allowance=Decimal("0"),
                other_allowances=Decimal("0"),
                gosi_applicable=True,
                gosi_employee_rate=Decimal("0.10"),
                gosi_employer_rate=Decimal("0.12"),
                status="active",
            )
            db.add(emp)
        db.commit()

    yield db, Employee, prefix
    # Cleanup.
    with with_system_context():
        db.query(Employee).filter(
            Employee.employee_number.like(f"{prefix}-%")
        ).delete(synchronize_session=False)
        db.commit()
    db.close()


def test_paginate_first_page_and_next_cursor(_db_session_with_hr_data):
    from app.core.pagination import paginate

    db, Employee, prefix = _db_session_with_hr_data
    # Filter to only the 30 rows we just inserted (employee_number starts with PAG-)
    q = db.query(Employee).filter(Employee.employee_number.like(f"{prefix}-%"))
    page = paginate(q, order_field=Employee.employee_number, direction="asc", limit=10)
    assert len(page.items) == 10
    assert page.has_more is True
    assert page.next_cursor is not None
    # First page should be {prefix}-0000..0009 in ascending order
    assert page.items[0].employee_number == f"{prefix}-0000"
    assert page.items[9].employee_number == f"{prefix}-0009"


def test_paginate_follows_cursor_forward(_db_session_with_hr_data):
    from app.core.pagination import paginate

    db, Employee, prefix = _db_session_with_hr_data
    q = db.query(Employee).filter(Employee.employee_number.like(f"{prefix}-%"))

    page1 = paginate(q, order_field=Employee.employee_number, direction="asc", limit=10)
    page2 = paginate(
        q,
        order_field=Employee.employee_number,
        direction="asc",
        limit=10,
        cursor=page1.next_cursor,
    )
    page3 = paginate(
        q,
        order_field=Employee.employee_number,
        direction="asc",
        limit=10,
        cursor=page2.next_cursor,
    )

    assert [e.employee_number for e in page2.items[:3]] == [f"{prefix}-0010", f"{prefix}-0011", f"{prefix}-0012"]
    assert [e.employee_number for e in page3.items[:3]] == [f"{prefix}-0020", f"{prefix}-0021", f"{prefix}-0022"]
    assert page3.has_more is False
    assert page3.next_cursor is None


def test_paginate_desc_direction(_db_session_with_hr_data):
    from app.core.pagination import paginate

    db, Employee, prefix = _db_session_with_hr_data
    q = db.query(Employee).filter(Employee.employee_number.like(f"{prefix}-%"))

    page = paginate(q, order_field=Employee.employee_number, direction="desc", limit=5)
    assert page.items[0].employee_number == f"{prefix}-0029"
    assert page.items[4].employee_number == f"{prefix}-0025"


def test_paginate_limit_clamped_to_max(_db_session_with_hr_data):
    from app.core.pagination import MAX_LIMIT, paginate

    db, Employee, prefix = _db_session_with_hr_data
    q = db.query(Employee).filter(Employee.employee_number.like(f"{prefix}-%"))

    page = paginate(q, order_field=Employee.employee_number, limit=99999)
    assert page.limit == MAX_LIMIT


def test_paginate_rejects_mismatched_cursor(_db_session_with_hr_data):
    """A cursor encoded for (field=A, direction=asc) cannot be used
    against a query ordering by (field=B, direction=desc)."""
    from app.core.pagination import CursorError, encode_cursor, paginate

    db, Employee, prefix = _db_session_with_hr_data
    bad_cursor = encode_cursor("hire_date", "desc", date(2026, 1, 1))
    q = db.query(Employee).filter(Employee.employee_number.like(f"{prefix}-%"))

    with pytest.raises(CursorError):
        paginate(
            q,
            order_field=Employee.employee_number,
            direction="asc",
            cursor=bad_cursor,
        )


def test_to_dict_shape():
    from app.core.pagination import CursorPage

    page = CursorPage(items=[1, 2, 3], next_cursor="abc", has_more=True, limit=10)
    d = page.to_dict()
    assert set(d.keys()) == {"data", "next_cursor", "has_more", "limit", "total_hint"}
    assert d["data"] == [1, 2, 3]
    assert d["has_more"] is True


def test_parse_pagination_query_defaults():
    from app.core.pagination import DEFAULT_LIMIT, parse_pagination_query

    assert parse_pagination_query() == (None, DEFAULT_LIMIT)
    assert parse_pagination_query(cursor="abc") == ("abc", DEFAULT_LIMIT)
    assert parse_pagination_query(limit=0)[1] == 1    # floor
    assert parse_pagination_query(limit=9999)[1] <= 100  # max
