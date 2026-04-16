"""
APEX Platform — Zakat + VAT calculator tests.
"""

from decimal import Decimal

import pytest

from app.core.zakat_service import ZakatInput, compute_zakat
from app.core.vat_service import (
    VatPurchases,
    VatReturnInput,
    VatSales,
    compute_vat_return,
    standard_rate_for,
)


# ══════════════════════════════════════════════════════════════
# Zakat
# ══════════════════════════════════════════════════════════════


class TestZakat:
    def test_simple_profitable_entity(self):
        # Entity with 1M capital, 200K retained, no deductions, 150K profit
        r = compute_zakat(ZakatInput(
            capital=Decimal("1000000"),
            retained_earnings=Decimal("200000"),
            adjusted_net_profit=Decimal("150000"),
        ))
        # Formula B: 1,000,000 + 200,000 - 0 = 1,200,000
        # Formula A: 150,000
        # Base = max(A, B) = 1,200,000
        # Due = 1,200,000 * 0.025 = 30,000
        assert r.zakat_base == Decimal("1200000.00")
        assert r.zakat_due == Decimal("30000.00")
        assert r.used_floor is False

    def test_formula_a_floor_triggered(self):
        # Lots of fixed assets wipe out Formula B; profit wins
        r = compute_zakat(ZakatInput(
            capital=Decimal("500000"),
            retained_earnings=Decimal("50000"),
            net_fixed_assets=Decimal("600000"),   # exceeds additions
            adjusted_net_profit=Decimal("80000"),
        ))
        # B = 550,000 - 600,000 = negative → 0
        # A = 80,000 → wins
        assert r.used_floor is True
        assert r.zakat_base == Decimal("80000.00")
        assert r.zakat_due == Decimal("2000.00")  # 80,000 * 2.5%

    def test_accumulated_losses_deduct(self):
        r = compute_zakat(ZakatInput(
            capital=Decimal("1000000"),
            accumulated_losses=Decimal("400000"),
            adjusted_net_profit=Decimal("0"),
        ))
        assert r.zakat_base == Decimal("600000.00")
        assert r.zakat_due == Decimal("15000.00")

    def test_hijri_strict_rate(self):
        # Some schools use 2.577% for Gregorian filings
        r = compute_zakat(ZakatInput(
            capital=Decimal("1000000"),
            adjusted_net_profit=Decimal("0"),
            rate=Decimal("0.02577"),
        ))
        # 1,000,000 * 0.02577 = 25,770.00
        assert r.zakat_due == Decimal("25770.00")
        assert r.rate_pct == Decimal("2.58")

    def test_zero_base_zero_due(self):
        r = compute_zakat(ZakatInput())
        assert r.zakat_base == Decimal("0.00")
        assert r.zakat_due == Decimal("0.00")

    def test_negative_base_floored(self):
        r = compute_zakat(ZakatInput(
            capital=Decimal("100000"),
            net_fixed_assets=Decimal("500000"),
        ))
        assert r.zakat_base == Decimal("0.00")
        assert r.zakat_due == Decimal("0.00")
        assert any("سالب" in w for w in r.warnings)

    def test_invalid_rate_rejected(self):
        with pytest.raises(ValueError):
            compute_zakat(ZakatInput(rate=Decimal("0")))
        with pytest.raises(ValueError):
            compute_zakat(ZakatInput(rate=Decimal("1")))

    def test_audit_trail_lines(self):
        r = compute_zakat(ZakatInput(
            capital=Decimal("100000"),
            retained_earnings=Decimal("50000"),
            net_fixed_assets=Decimal("20000"),
        ))
        adds = [l for l in r.lines if l.kind == "add"]
        deds = [l for l in r.lines if l.kind == "deduct"]
        assert len(adds) == 2
        assert len(deds) == 1
        assert deds[0].amount == Decimal("20000.00")

    def test_decimal_exact_math(self):
        # Regression for the Float → Numeric migration
        r = compute_zakat(ZakatInput(
            capital=Decimal("100.10"),
            retained_earnings=Decimal("200.20"),
            adjusted_net_profit=Decimal("0"),
        ))
        assert r.zakat_base == Decimal("300.30")  # not 300.30000000000001
        # 300.30 * 0.025 = 7.5075 → rounds to 7.51
        assert r.zakat_due == Decimal("7.51")


# ══════════════════════════════════════════════════════════════
# VAT
# ══════════════════════════════════════════════════════════════


class TestVat:
    def test_ksa_15pct_simple(self):
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            period_label="2026-Q1",
            sales=VatSales(standard_rated_net=Decimal("1000000")),
            purchases=VatPurchases(standard_rated_net=Decimal("400000")),
        ))
        # Output: 1M * 15% = 150,000
        # Input: 400K * 15% = 60,000
        # Net: 150,000 - 60,000 = 90,000 payable
        assert r.output_vat_total == Decimal("150000.00")
        assert r.input_vat_reclaimable == Decimal("60000.00")
        assert r.net_vat_due == Decimal("90000.00")
        assert r.status == "payable"

    def test_uae_5pct(self):
        r = compute_vat_return(VatReturnInput(
            jurisdiction="AE",
            period_label="2026-01",
            sales=VatSales(standard_rated_net=Decimal("500000")),
            purchases=VatPurchases(standard_rated_net=Decimal("100000")),
        ))
        # 500K * 5% = 25,000 out; 100K * 5% = 5,000 in; net = 20,000
        assert r.standard_rate_pct == Decimal("5.00")
        assert r.net_vat_due == Decimal("20000.00")

    def test_refund_scenario(self):
        # More input than output → refund
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            sales=VatSales(standard_rated_net=Decimal("100000")),
            purchases=VatPurchases(standard_rated_net=Decimal("500000")),
        ))
        # Out: 15,000; In: 75,000 → net -60,000 (refund)
        assert r.net_vat_due == Decimal("-60000.00")
        assert r.status == "refund"

    def test_zero_rated_sales_no_vat(self):
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            sales=VatSales(zero_rated_net=Decimal("1000000")),
            purchases=VatPurchases(standard_rated_net=Decimal("100000")),
        ))
        # No output VAT, 15,000 input → net -15,000 refund
        assert r.output_vat_total == Decimal("0.00")
        assert r.input_vat_reclaimable == Decimal("15000.00")
        assert r.status == "refund"

    def test_prior_credit_reduces_payable(self):
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            sales=VatSales(standard_rated_net=Decimal("100000")),
            purchases=VatPurchases(standard_rated_net=Decimal("0")),
            prior_period_credit=Decimal("5000"),
        ))
        # Out 15,000 - in 0 - prior credit 5,000 = 10,000 payable
        assert r.net_vat_due == Decimal("10000.00")

    def test_nil_return(self):
        r = compute_vat_return(VatReturnInput(jurisdiction="SA"))
        assert r.net_vat_due == Decimal("0.00")
        assert r.status == "nil"

    def test_rate_override(self):
        # Emergency rate change scenario
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            standard_rate_override=Decimal("0.20"),   # hypothetical 20%
            sales=VatSales(standard_rated_net=Decimal("100000")),
        ))
        assert r.standard_rate_pct == Decimal("20.00")
        assert r.output_vat_total == Decimal("20000.00")

    def test_unknown_jurisdiction_rejected(self):
        with pytest.raises(ValueError):
            standard_rate_for("ZZ")
        with pytest.raises(ValueError):
            compute_vat_return(VatReturnInput(jurisdiction="ZZ"))

    def test_negative_prior_credit_floored(self):
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            sales=VatSales(standard_rated_net=Decimal("100000")),
            prior_period_credit=Decimal("-1000"),
        ))
        assert r.prior_period_credit == Decimal("0.00")
        assert any("سالب" in w for w in r.warnings)

    def test_sales_buckets_complete(self):
        r = compute_vat_return(VatReturnInput(
            jurisdiction="SA",
            sales=VatSales(
                standard_rated_net=Decimal("1000"),
                zero_rated_net=Decimal("500"),
                exempt_net=Decimal("300"),
                out_of_scope_net=Decimal("200"),
            ),
        ))
        assert len(r.sales_buckets) == 4
        assert r.sales_net_total == Decimal("2000.00")
        # Only standard bucket has VAT
        assert r.sales_buckets[0].vat == Decimal("150.00")
        for b in r.sales_buckets[1:]:
            assert b.vat == Decimal("0.00")


# ══════════════════════════════════════════════════════════════
# HTTP routes
# ══════════════════════════════════════════════════════════════


class TestTaxRoutes:
    def test_zakat_requires_auth(self, client):
        r = client.post("/tax/zakat/compute", json={})
        assert r.status_code == 401

    def test_zakat_simple(self, client, auth_header):
        r = client.post(
            "/tax/zakat/compute",
            json={"capital": "1000000", "adjusted_net_profit": "100000"},
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["zakat_base"] == "1000000.00"
        assert d["zakat_due"] == "25000.00"
        assert d["rate_pct"] == "2.50"

    def test_zakat_with_deductions(self, client, auth_header):
        r = client.post(
            "/tax/zakat/compute",
            json={
                "capital": "500000",
                "retained_earnings": "100000",
                "net_fixed_assets": "200000",
                "adjusted_net_profit": "50000",
                "rate": "0.025",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        # 500K + 100K - 200K = 400K base (wins over 50K profit)
        assert d["zakat_base"] == "400000.00"
        assert d["zakat_due"] == "10000.00"

    def test_zakat_bad_rate_rejected(self, client, auth_header):
        r = client.post(
            "/tax/zakat/compute",
            json={"capital": "100000", "rate": "2"},
            headers=auth_header,
        )
        assert r.status_code == 422

    def test_vat_return_payable(self, client, auth_header):
        r = client.post(
            "/tax/vat/return",
            json={
                "jurisdiction": "SA",
                "period_label": "2026-Q1",
                "sales": {"standard_rated_net": "1000000"},
                "purchases": {"standard_rated_net": "400000"},
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["status"] == "payable"
        assert d["net_vat_due"] == "90000.00"

    def test_vat_return_uae(self, client, auth_header):
        r = client.post(
            "/tax/vat/return",
            json={
                "jurisdiction": "AE",
                "sales": {"standard_rated_net": "200000"},
                "purchases": {"standard_rated_net": "100000"},
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["standard_rate_pct"] == "5.00"
        # (200K - 100K) * 5% = 5000
        assert d["net_vat_due"] == "5000.00"

    def test_vat_return_requires_auth(self, client):
        r = client.post("/tax/vat/return", json={})
        assert r.status_code == 401

    def test_vat_unknown_jurisdiction(self, client, auth_header):
        r = client.post(
            "/tax/vat/return",
            json={"jurisdiction": "ZZ"},
            headers=auth_header,
        )
        assert r.status_code == 422
