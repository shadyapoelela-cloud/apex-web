"""WHT (Saudi Withholding Tax) tests."""

from decimal import Decimal

import pytest

from app.core.wht_service import (
    WHTInput, WHTBatchInput, WHTBatchItem,
    compute_wht, compute_wht_batch,
    default_rates, PAYMENT_CATEGORIES,
)


class TestBasics:
    def test_default_rates_cover_all_categories(self):
        rates = default_rates()
        for cat in PAYMENT_CATEGORIES:
            assert cat in rates
        # Key sanity checks
        assert rates["royalties"] == Decimal("15")
        assert rates["dividends"] == Decimal("5")
        assert rates["management_fees"] == Decimal("20")

    def test_unknown_category_rejected(self):
        with pytest.raises(ValueError, match="Unknown payment_category"):
            compute_wht(WHTInput(
                payment_category="nonsense",
                amount=Decimal("1000"),
            ))

    def test_negative_amount_rejected(self):
        with pytest.raises(ValueError, match="cannot be negative"):
            compute_wht(WHTInput(
                payment_category="royalties",
                amount=Decimal("-100"),
            ))


class TestGrossFlow:
    def test_royalties_15pct(self):
        # 10000 × 15% = 1500 tax, net = 8500
        r = compute_wht(WHTInput(
            payment_category="royalties",
            amount=Decimal("10000"),
            is_gross=True,
        ))
        assert r.rate_applied_pct == Decimal("15.0000")
        assert r.base_gross == Decimal("10000.00")
        assert r.tax_withheld == Decimal("1500.00")
        assert r.net_to_pay == Decimal("8500.00")
        assert r.rate_source == "default"

    def test_management_fees_20pct(self):
        r = compute_wht(WHTInput(
            payment_category="management_fees",
            amount=Decimal("50000"),
        ))
        assert r.tax_withheld == Decimal("10000.00")
        assert r.net_to_pay == Decimal("40000.00")

    def test_dividends_5pct(self):
        r = compute_wht(WHTInput(
            payment_category="dividends",
            amount=Decimal("100000"),
        ))
        assert r.tax_withheld == Decimal("5000.00")
        assert r.net_to_pay == Decimal("95000.00")


class TestGrossUp:
    def test_net_to_gross_royalties(self):
        # net = 8500, rate 15%
        # base = 8500 / (1 - 0.15) = 8500 / 0.85 = 10000
        # tax = 1500
        r = compute_wht(WHTInput(
            payment_category="royalties",
            amount=Decimal("8500"),
            is_gross=False,
        ))
        assert r.base_gross == Decimal("10000.00")
        assert r.tax_withheld == Decimal("1500.00")
        assert r.net_to_pay == Decimal("8500.00")

    def test_net_to_gross_dividends(self):
        # net = 950, rate 5%
        # base = 950 / 0.95 = 1000
        r = compute_wht(WHTInput(
            payment_category="dividends",
            amount=Decimal("950"),
            is_gross=False,
        ))
        assert r.base_gross == Decimal("1000.00")
        assert r.tax_withheld == Decimal("50.00")


class TestOverrides:
    def test_treaty_rate_applied(self):
        # royalties default 15% but UAE-KSA DTT may apply 10%
        r = compute_wht(WHTInput(
            payment_category="royalties",
            amount=Decimal("10000"),
            treaty_rate_pct=Decimal("10"),
        ))
        assert r.rate_applied_pct == Decimal("10.0000")
        assert r.tax_withheld == Decimal("1000.00")
        assert r.rate_source == "treaty"

    def test_explicit_override_wins(self):
        r = compute_wht(WHTInput(
            payment_category="royalties",
            amount=Decimal("10000"),
            treaty_rate_pct=Decimal("10"),
            rate_override_pct=Decimal("7"),
        ))
        assert r.rate_applied_pct == Decimal("7.0000")
        assert r.rate_source == "override"

    def test_rate_bounds_enforced(self):
        with pytest.raises(ValueError, match="between 0 and 100"):
            compute_wht(WHTInput(
                payment_category="royalties",
                amount=Decimal("100"),
                rate_override_pct=Decimal("150"),
            ))


class TestCompliance:
    def test_1m_warning(self):
        r = compute_wht(WHTInput(
            payment_category="royalties",
            amount=Decimal("1500000"),
        ))
        assert any("1,000,000" in w for w in r.warnings)

    def test_zero_rate_warning(self):
        r = compute_wht(WHTInput(
            payment_category="royalties",
            amount=Decimal("1000"),
            treaty_rate_pct=Decimal("0"),
        ))
        assert any("صفر" in w for w in r.warnings)


class TestBatch:
    def test_batch_tallies(self):
        r = compute_wht_batch(WHTBatchInput(
            period_label="Q1 2026",
            items=[
                WHTBatchItem("royalties", Decimal("10000"), vendor_name="A"),
                WHTBatchItem("dividends", Decimal("20000"), vendor_name="B"),
                WHTBatchItem("technical_services", Decimal("5000"), vendor_name="C"),
            ],
        ))
        # Tax: 1500 + 1000 + 250 = 2750
        assert r.total_tax == Decimal("2750.00")
        assert r.total_base == Decimal("35000.00")
        assert len(r.items) == 3
        assert r.by_category["royalties"] == Decimal("1500.00")

    def test_empty_batch_rejected(self):
        with pytest.raises(ValueError):
            compute_wht_batch(WHTBatchInput(items=[]))

    def test_custom_rates_apply(self):
        r = compute_wht_batch(WHTBatchInput(
            custom_rates={"royalties": Decimal("10")},  # override default 15%
            items=[WHTBatchItem("royalties", Decimal("10000"))],
        ))
        # 10000 × 10% = 1000
        assert r.items[0].tax_withheld == Decimal("1000.00")
        assert r.items[0].rate_source == "custom"


class TestRoutes:
    def test_compute_requires_auth(self, client):
        r = client.post("/wht/compute", json={})
        assert r.status_code == 401

    def test_compute_http(self, client, auth_header):
        r = client.post("/wht/compute", json={
            "payment_category": "royalties",
            "amount": "10000",
            "is_gross": True,
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["tax_withheld"] == "1500.00"
        assert d["net_to_pay"] == "8500.00"

    def test_compute_gross_up_http(self, client, auth_header):
        r = client.post("/wht/compute", json={
            "payment_category": "dividends",
            "amount": "950",
            "is_gross": False,
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["base_gross"] == "1000.00"

    def test_batch_http(self, client, auth_header):
        r = client.post("/wht/batch", json={
            "currency": "SAR",
            "items": [
                {"payment_category": "royalties", "amount": "10000"},
                {"payment_category": "dividends", "amount": "20000"},
            ],
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["total_tax"] == "2500.00"

    def test_categories(self, client, auth_header):
        r = client.get("/wht/categories", headers=auth_header)
        assert r.status_code == 200
        lst = r.json()["data"]
        assert "royalties" in lst
        assert "dividends" in lst

    def test_rates(self, client, auth_header):
        r = client.get("/wht/rates", headers=auth_header)
        assert r.status_code == 200
        rates = r.json()["data"]
        assert rates["royalties"] == "15"

    def test_bad_category_http(self, client, auth_header):
        r = client.post("/wht/compute", json={
            "payment_category": "junk",
            "amount": "1000",
        }, headers=auth_header)
        assert r.status_code == 422
