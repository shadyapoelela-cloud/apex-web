"""
APEX Platform — ZATCA (Fatoora) Phase 2 e-invoice tests.
Covers:
  - VAT number validation (15-digit KSA rules)
  - TLV QR payload structure (base64 of tag-length-value bytes)
  - UBL 2.1 XML invoice build (deterministic + signed with hash)
  - ICV (Invoice Counter Value) continuity via JE sequence
  - /zatca/* HTTP routes
"""

import base64
from datetime import datetime, timezone
from decimal import Decimal

import pytest

from app.core.zatca_service import (
    ZatcaBuyer,
    ZatcaLineItem,
    ZatcaSeller,
    build_simplified_invoice,
    build_tlv_qr,
    validate_vat_number,
)


# ══════════════════════════════════════════════════════════════
# VAT number validation
# ══════════════════════════════════════════════════════════════


class TestVatValidation:
    def test_valid_ksa_vat(self):
        # Must start with 3, end with 3, be exactly 15 digits
        assert validate_vat_number("300000000000003") is True
        assert validate_vat_number("301234567890123") is True

    def test_invalid_length(self):
        assert validate_vat_number("30000000000003") is False       # 14
        assert validate_vat_number("3000000000000003") is False     # 16

    def test_invalid_prefix(self):
        assert validate_vat_number("100000000000003") is False  # starts with 1
        assert validate_vat_number("200000000000003") is False

    def test_invalid_suffix(self):
        assert validate_vat_number("300000000000001") is False  # ends with 1
        assert validate_vat_number("300000000000000") is False

    def test_non_digits(self):
        assert validate_vat_number("3000000000000O3") is False  # 'O' not zero
        assert validate_vat_number("") is False
        assert validate_vat_number(None) is False  # type: ignore


# ══════════════════════════════════════════════════════════════
# TLV QR payload
# ══════════════════════════════════════════════════════════════


class TestTlvQr:
    def test_qr_is_valid_base64(self):
        qr = build_tlv_qr(
            seller_name="Acme Co",
            vat_number="300000000000003",
            issue_datetime=datetime(2026, 1, 15, 10, 30, 0, tzinfo=timezone.utc),
            total_with_vat=Decimal("115.00"),
            vat_total=Decimal("15.00"),
        )
        # Must decode cleanly
        raw = base64.b64decode(qr)
        assert len(raw) > 0

    def test_qr_has_five_tlv_fields(self):
        qr = build_tlv_qr(
            seller_name="Acme",
            vat_number="300000000000003",
            issue_datetime=datetime(2026, 1, 15, tzinfo=timezone.utc),
            total_with_vat=Decimal("100.00"),
            vat_total=Decimal("15.00"),
        )
        raw = base64.b64decode(qr)
        # Parse TLV: iterate tag,length,value
        i = 0
        tags_seen = []
        while i < len(raw):
            tag = raw[i]
            length = raw[i + 1]
            value = raw[i + 2: i + 2 + length]
            tags_seen.append((tag, value.decode("utf-8")))
            i += 2 + length
        assert [t[0] for t in tags_seen] == [1, 2, 3, 4, 5]
        assert tags_seen[1][1] == "300000000000003"
        assert "T" in tags_seen[2][1]  # ISO datetime has 'T' separator
        assert tags_seen[3][1] == "100.00"
        assert tags_seen[4][1] == "15.00"

    def test_arabic_seller_name_in_qr(self):
        """Arabic names must round-trip through UTF-8."""
        qr = build_tlv_qr(
            seller_name="شركة أبكس للتحليل المالي",
            vat_number="300000000000003",
            issue_datetime=datetime(2026, 1, 15, tzinfo=timezone.utc),
            total_with_vat=Decimal("115.00"),
            vat_total=Decimal("15.00"),
        )
        raw = base64.b64decode(qr)
        assert b"\xd8" in raw  # Arabic bytes present

    def test_qr_rejects_very_long_name(self):
        long_name = "A" * 300
        with pytest.raises(ValueError):
            build_tlv_qr(
                seller_name=long_name,
                vat_number="300000000000003",
                issue_datetime=datetime(2026, 1, 15, tzinfo=timezone.utc),
                total_with_vat=Decimal("100.00"),
                vat_total=Decimal("15.00"),
            )


# ══════════════════════════════════════════════════════════════
# Invoice build
# ══════════════════════════════════════════════════════════════


def _seller() -> ZatcaSeller:
    return ZatcaSeller(
        name="شركة أبكس",
        vat_number="300000000000003",
        cr_number="1010000000",
        address_city="Riyadh",
        country_code="SA",
    )


def _lines() -> list[ZatcaLineItem]:
    return [
        ZatcaLineItem(
            name="Consulting hour",
            quantity=Decimal("10"),
            unit_price=Decimal("100.00"),
            vat_rate=Decimal("15"),
        )
    ]


class TestInvoiceBuild:
    def test_build_basic_simplified_invoice(self):
        r = build_simplified_invoice(
            seller=_seller(),
            lines=_lines(),
            client_id="test-zatca-client-1",
            fiscal_year="2026",
        )
        assert r.invoice_number
        assert r.icv >= 1
        assert r.invoice_hash_b64 and len(r.invoice_hash_b64) > 20
        assert r.qr_b64
        assert r.totals["subtotal"] == "1000.00"
        assert r.totals["vat_total"] == "150.00"
        assert r.totals["total"] == "1150.00"
        assert "<Invoice" in r.xml
        assert "300000000000003" in r.xml

    def test_icv_is_monotonic_per_client_year(self):
        a = build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id="test-zatca-client-2", fiscal_year="2026",
        )
        b = build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id="test-zatca-client-2", fiscal_year="2026",
        )
        assert b.icv == a.icv + 1

    def test_different_fiscal_years_isolated(self):
        # G-T1.8 fix: use a UUID-suffixed client_id so the JournalEntrySequence
        # row is fresh for each test run. The cascade test's subprocess
        # (tests/test_per_directory_coverage.py) inherits the parent's cwd and
        # DATABASE_URL=sqlite:///test.db, then writes JournalEntrySequence rows
        # that pollute the parent's later run. A unique client_id sidesteps the
        # shared-state path entirely. See 09 § 4 G-T1.8 for full evidence trail
        # and G-T1.8.2 for the deferred cascade-subprocess isolation fix.
        import uuid
        cid = f"test-zatca-client-isolated-{uuid.uuid4().hex[:8]}"
        a = build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id=cid, fiscal_year="2025",
        )
        b = build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id=cid, fiscal_year="2026",
        )
        assert a.icv == 1
        assert b.icv == 1  # independent counter

    def test_invalid_vat_rejected(self):
        bad = ZatcaSeller(name="X", vat_number="123", cr_number=None)
        with pytest.raises(ValueError, match="Invalid KSA VAT"):
            build_simplified_invoice(
                seller=bad, lines=_lines(),
                client_id="test-zatca-client-4", fiscal_year="2026",
            )

    def test_empty_lines_rejected(self):
        with pytest.raises(ValueError, match="At least one"):
            build_simplified_invoice(
                seller=_seller(), lines=[],
                client_id="test-zatca-client-5", fiscal_year="2026",
            )

    def test_negative_quantity_rejected(self):
        bad_line = ZatcaLineItem(
            name="X", quantity=Decimal("-1"), unit_price=Decimal("10"),
        )
        with pytest.raises(ValueError, match="quantity must be positive"):
            build_simplified_invoice(
                seller=_seller(), lines=[bad_line],
                client_id="test-zatca-client-6", fiscal_year="2026",
            )

    def test_pih_warning_when_icv_gt_1_no_hash(self):
        # First invoice (ICV=1, no PIH needed)
        build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id="test-zatca-client-7", fiscal_year="2026",
        )
        # Second invoice without PIH — should warn
        r2 = build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id="test-zatca-client-7", fiscal_year="2026",
        )
        assert any("PIH chain" in w for w in r2.warnings)

    def test_totals_use_decimal_exact(self):
        """The #1 reason we moved Float → Numeric. No 0.1+0.2 drift."""
        r = build_simplified_invoice(
            seller=_seller(),
            lines=[
                ZatcaLineItem(name="A", quantity=Decimal("1"), unit_price=Decimal("0.10")),
                ZatcaLineItem(name="B", quantity=Decimal("1"), unit_price=Decimal("0.20")),
            ],
            client_id="test-zatca-client-8", fiscal_year="2026",
        )
        assert r.totals["subtotal"] == "0.30"  # not "0.30000000000000004"

    def test_xml_contains_arabic(self):
        r = build_simplified_invoice(
            seller=_seller(), lines=_lines(),
            client_id="test-zatca-client-9", fiscal_year="2026",
        )
        assert "شركة أبكس" in r.xml


# ══════════════════════════════════════════════════════════════
# HTTP routes
# ══════════════════════════════════════════════════════════════


class TestZatcaRoutes:
    def test_vat_validate_requires_auth(self, client):
        r = client.post("/zatca/validate-vat", json={"vat_number": "300000000000003"})
        assert r.status_code == 401

    def test_vat_validate_valid(self, client, auth_header):
        r = client.post(
            "/zatca/validate-vat",
            json={"vat_number": "300000000000003"},
            headers=auth_header,
        )
        assert r.status_code == 200
        assert r.json()["data"]["valid"] is True

    def test_vat_validate_invalid(self, client, auth_header):
        r = client.post(
            "/zatca/validate-vat",
            json={"vat_number": "123"},
            headers=auth_header,
        )
        assert r.status_code == 200
        assert r.json()["data"]["valid"] is False
        assert r.json()["data"]["reason"] is not None

    def test_qr_build(self, client, auth_header):
        r = client.post(
            "/zatca/qr",
            json={
                "seller_name": "Acme",
                "vat_number": "300000000000003",
                "issue_datetime": "2026-01-15T10:30:00Z",
                "total_with_vat": "115.00",
                "vat_total": "15.00",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        qr = r.json()["data"]["qr_base64"]
        assert base64.b64decode(qr)

    def test_qr_rejects_bad_vat(self, client, auth_header):
        r = client.post(
            "/zatca/qr",
            json={
                "seller_name": "Acme",
                "vat_number": "123456789012345",  # 15 digits but starts with 1
                "issue_datetime": "2026-01-15T10:30:00Z",
                "total_with_vat": "100.00",
                "vat_total": "15.00",
            },
            headers=auth_header,
        )
        assert r.status_code == 422

    def test_invoice_build_full(self, client, auth_header):
        r = client.post(
            "/zatca/invoice/build",
            json={
                "seller": {
                    "name": "شركة أبكس",
                    "vat_number": "300000000000003",
                    "cr_number": "1010000000",
                },
                "lines": [
                    {
                        "name": "خدمة استشارية",
                        "quantity": "5",
                        "unit_price": "200.00",
                        "vat_rate": "15",
                    },
                ],
                "client_id": "http-test-client-1",
                "fiscal_year": "2026",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["icv"] >= 1
        assert data["invoice_hash_b64"]
        assert data["qr_base64"]
        assert data["totals"]["total"] == "1150.00"
        assert "<Invoice" in data["xml"]

    def test_invoice_build_rejects_empty_lines(self, client, auth_header):
        r = client.post(
            "/zatca/invoice/build",
            json={
                "seller": {"name": "X", "vat_number": "300000000000003"},
                "lines": [],
                "client_id": "http-test-client-2",
                "fiscal_year": "2026",
            },
            headers=auth_header,
        )
        assert r.status_code == 422
