"""APEX Platform — Financial Ratios tests."""

from decimal import Decimal

from app.core.ratios_service import (
    RatiosInput,
    compute_ratios,
    result_to_dict,
)


class TestLiquidity:
    def test_current_ratio_healthy(self):
        r = compute_ratios(RatiosInput(
            current_assets=Decimal("300000"),
            current_liabilities=Decimal("150000"),
        ))
        cur = next(x for x in r.ratios if x.code == "current_ratio")
        assert cur.value == Decimal("2.0000")
        assert cur.health == "healthy"

    def test_current_ratio_risk(self):
        r = compute_ratios(RatiosInput(
            current_assets=Decimal("80000"),
            current_liabilities=Decimal("150000"),
        ))
        cur = next(x for x in r.ratios if x.code == "current_ratio")
        assert cur.health == "risk"

    def test_quick_ratio_excludes_inventory(self):
        r = compute_ratios(RatiosInput(
            current_assets=Decimal("300000"),
            inventory=Decimal("100000"),
            current_liabilities=Decimal("150000"),
        ))
        q = next(x for x in r.ratios if x.code == "quick_ratio")
        # (300k - 100k) / 150k = 1.333
        assert q.value == Decimal("1.3333")

    def test_cash_ratio(self):
        r = compute_ratios(RatiosInput(
            cash_and_equivalents=Decimal("100000"),
            current_liabilities=Decimal("150000"),
        ))
        c = next(x for x in r.ratios if x.code == "cash_ratio")
        assert c.value == Decimal("0.6667")
        assert c.health == "healthy"


class TestSolvency:
    def test_debt_to_equity_healthy(self):
        r = compute_ratios(RatiosInput(
            total_liabilities=Decimal("300000"),
            total_equity=Decimal("500000"),
        ))
        de = next(x for x in r.ratios if x.code == "debt_to_equity")
        assert de.value == Decimal("0.6000")
        assert de.health == "healthy"

    def test_debt_ratio(self):
        r = compute_ratios(RatiosInput(
            total_liabilities=Decimal("400000"),
            total_assets=Decimal("1000000"),
        ))
        d = next(x for x in r.ratios if x.code == "debt_ratio")
        assert d.value == Decimal("0.4000")
        assert d.health == "healthy"

    def test_interest_coverage(self):
        r = compute_ratios(RatiosInput(
            operating_income=Decimal("300000"),
            interest_expense=Decimal("50000"),
        ))
        ic = next(x for x in r.ratios if x.code == "interest_coverage")
        assert ic.value == Decimal("6.0000")
        assert ic.health == "healthy"


class TestProfitability:
    def test_gross_margin(self):
        r = compute_ratios(RatiosInput(
            gross_profit=Decimal("400000"),
            revenue=Decimal("1000000"),
        ))
        g = next(x for x in r.ratios if x.code == "gross_margin")
        assert g.value == Decimal("40.00")   # 40%
        assert g.health == "healthy"

    def test_net_margin(self):
        r = compute_ratios(RatiosInput(
            net_income=Decimal("120000"),
            revenue=Decimal("1000000"),
        ))
        n = next(x for x in r.ratios if x.code == "net_margin")
        assert n.value == Decimal("12.00")
        assert n.health == "healthy"

    def test_roe(self):
        r = compute_ratios(RatiosInput(
            net_income=Decimal("150000"),
            total_equity=Decimal("750000"),
        ))
        roe = next(x for x in r.ratios if x.code == "roe")
        assert roe.value == Decimal("20.00")
        assert roe.health == "healthy"

    def test_roa(self):
        r = compute_ratios(RatiosInput(
            net_income=Decimal("80000"),
            total_assets=Decimal("1000000"),
        ))
        roa = next(x for x in r.ratios if x.code == "roa")
        assert roa.value == Decimal("8.00")
        assert roa.health == "healthy"


class TestEfficiency:
    def test_asset_turnover(self):
        r = compute_ratios(RatiosInput(
            revenue=Decimal("1500000"),
            total_assets=Decimal("1000000"),
        ))
        at = next(x for x in r.ratios if x.code == "asset_turnover")
        assert at.value == Decimal("1.5000")
        assert at.health == "healthy"

    def test_inventory_turnover(self):
        r = compute_ratios(RatiosInput(
            cogs=Decimal("600000"),
            inventory=Decimal("100000"),
        ))
        it = next(x for x in r.ratios if x.code == "inventory_turnover")
        assert it.value == Decimal("6.0000")
        assert it.health == "watch"   # between 4 and 8

    def test_dso(self):
        r = compute_ratios(RatiosInput(
            receivables=Decimal("100000"),
            revenue=Decimal("1000000"),
        ))
        dso = next(x for x in r.ratios if x.code == "dso")
        # 0.1 * 365 = 36.5 days → watch
        assert dso.value == Decimal("36.50")
        assert dso.health == "watch"


class TestValuation:
    def test_eps_and_pe(self):
        r = compute_ratios(RatiosInput(
            net_income=Decimal("1000000"),
            shares_outstanding=Decimal("100000"),
            share_price=Decimal("150"),
        ))
        eps = next(x for x in r.ratios if x.code == "eps")
        pe = next(x for x in r.ratios if x.code == "pe_ratio")
        assert eps.value == Decimal("10.0000")
        assert pe.value == Decimal("15.00")

    def test_dividend_yield(self):
        r = compute_ratios(RatiosInput(
            share_price=Decimal("100"),
            dividends_per_share=Decimal("4"),
        ))
        dy = next(x for x in r.ratios if x.code == "dividend_yield")
        assert dy.value == Decimal("4.00")
        assert dy.health == "healthy"


class TestGracefulDegradation:
    def test_empty_input_no_ratios(self):
        r = compute_ratios(RatiosInput())
        assert len(r.ratios) == 0

    def test_partial_input_partial_ratios(self):
        # Only balance sheet — no profitability / efficiency
        r = compute_ratios(RatiosInput(
            current_assets=Decimal("100"),
            current_liabilities=Decimal("50"),
        ))
        codes = {x.code for x in r.ratios}
        assert "current_ratio" in codes
        assert "roe" not in codes
        assert "gross_margin" not in codes

    def test_divide_by_zero_skipped(self):
        r = compute_ratios(RatiosInput(
            net_income=Decimal("100"),
            total_equity=Decimal("0"),   # division by zero
        ))
        # ROE should NOT appear
        codes = {x.code for x in r.ratios}
        assert "roe" not in codes

    def test_negative_equity_warning(self):
        r = compute_ratios(RatiosInput(
            total_equity=Decimal("-100000"),
        ))
        assert any("عجز" in w for w in r.warnings)


class TestRoutes:
    def test_compute_requires_auth(self, client):
        r = client.post("/ratios/compute", json={})
        assert r.status_code == 401

    def test_full_compute_http(self, client, auth_header):
        r = client.post(
            "/ratios/compute",
            json={
                "period_label": "2026-Q1",
                "current_assets": "300000",
                "current_liabilities": "150000",
                "inventory": "50000",
                "total_assets": "1000000",
                "total_liabilities": "400000",
                "total_equity": "600000",
                "revenue": "1000000",
                "cogs": "600000",
                "gross_profit": "400000",
                "operating_income": "200000",
                "net_income": "120000",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_ratios"] > 0
        assert "categories" in d
        assert "liquidity" in d["categories"]
        assert "profitability" in d["categories"]
        # Verify the net_margin is present with correct value
        prof = d["categories"]["profitability"]
        nm = next((x for x in prof if x["code"] == "net_margin"), None)
        assert nm is not None
        assert nm["value"] == "12.00"
        assert nm["health"] == "healthy"

    def test_partial_input_http(self, client, auth_header):
        r = client.post(
            "/ratios/compute",
            json={"current_assets": "100", "current_liabilities": "50"},
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_ratios"] == 1  # current_ratio only
