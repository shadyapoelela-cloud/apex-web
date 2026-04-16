"""Working Capital + Health Score tests."""

from decimal import Decimal

from app.core.working_capital_service import WorkingCapitalInput, compute_working_capital
from app.core.health_score_service import HealthScoreInput, compute_health_score


class TestWorkingCapital:
    def test_simple_ccc(self):
        # AR 100k on rev 1M → DSO ≈ 36.5
        # Inv 200k on COGS 600k → DIO ≈ 121.67
        # AP 120k on COGS 600k → DPO ≈ 73.0
        # CCC ≈ 36.5 + 121.67 − 73.0 = 85.17
        r = compute_working_capital(WorkingCapitalInput(
            revenue=Decimal("1000000"),
            cogs=Decimal("600000"),
            accounts_receivable=Decimal("100000"),
            inventory=Decimal("200000"),
            accounts_payable=Decimal("120000"),
            current_assets=Decimal("400000"),
            current_liabilities=Decimal("200000"),
        ))
        assert r.dso is not None
        assert Decimal("35") < r.dso < Decimal("38")
        assert r.ccc is not None
        assert Decimal("82") < r.ccc < Decimal("88")

    def test_healthy_ccc_short(self):
        r = compute_working_capital(WorkingCapitalInput(
            revenue=Decimal("1000000"),
            cogs=Decimal("800000"),
            accounts_receivable=Decimal("50000"),
            inventory=Decimal("30000"),
            accounts_payable=Decimal("80000"),
            current_assets=Decimal("200000"),
            current_liabilities=Decimal("100000"),
        ))
        # CCC = ~18 + ~14 − ~36 = −4 (very healthy)
        assert r.health == "healthy"

    def test_risk_ccc_long(self):
        r = compute_working_capital(WorkingCapitalInput(
            revenue=Decimal("1000000"),
            cogs=Decimal("500000"),
            accounts_receivable=Decimal("300000"),
            inventory=Decimal("400000"),
            accounts_payable=Decimal("50000"),
            current_assets=Decimal("700000"),
            current_liabilities=Decimal("100000"),
        ))
        # CCC large → risk
        assert r.health in ("watch", "risk")

    def test_negative_wc_downgrades_health(self):
        r = compute_working_capital(WorkingCapitalInput(
            revenue=Decimal("100000"),
            cogs=Decimal("60000"),
            accounts_receivable=Decimal("10000"),
            inventory=Decimal("5000"),
            accounts_payable=Decimal("5000"),
            current_assets=Decimal("50000"),
            current_liabilities=Decimal("100000"),   # CL > CA
        ))
        assert r.current_ratio is not None
        assert r.current_ratio < Decimal("1.0")
        assert r.health == "risk"

    def test_recommendations_generated(self):
        r = compute_working_capital(WorkingCapitalInput(
            revenue=Decimal("1000000"),
            cogs=Decimal("500000"),
            accounts_receivable=Decimal("250000"),   # high DSO ≈ 91
            inventory=Decimal("150000"),
            accounts_payable=Decimal("30000"),       # low DPO ≈ 22
            current_assets=Decimal("500000"),
            current_liabilities=Decimal("200000"),
        ))
        assert len(r.recommendations) > 0
        # Should mention DSO or DPO
        text = " ".join(r.recommendations)
        assert "DSO" in text or "DPO" in text

    def test_zero_revenue_no_dso(self):
        r = compute_working_capital(WorkingCapitalInput(
            revenue=Decimal("0"),
            accounts_receivable=Decimal("10000"),
        ))
        assert r.dso is None

    def test_working_capital_components(self):
        r = compute_working_capital(WorkingCapitalInput(
            current_assets=Decimal("500000"),
            current_liabilities=Decimal("200000"),
            cash=Decimal("100000"),
        ))
        assert r.working_capital == Decimal("300000.00")     # CA − CL
        assert r.net_working_capital == Decimal("200000.00")  # CA − Cash − CL


class TestHealthScore:
    def test_excellent_company(self):
        r = compute_health_score(HealthScoreInput(
            current_ratio=Decimal("2.5"),
            quick_ratio=Decimal("1.8"),
            debt_to_equity=Decimal("0.3"),
            interest_coverage=Decimal("12"),
            net_margin_pct=Decimal("18"),
            roe_pct=Decimal("22"),
            asset_turnover=Decimal("1.2"),
            ccc_days=Decimal("15"),
            ocf_to_ni_ratio=Decimal("1.3"),
            ocf_ratio=Decimal("1.2"),
        ))
        assert r.composite_score >= 85
        assert r.grade == "A"

    def test_struggling_company(self):
        r = compute_health_score(HealthScoreInput(
            current_ratio=Decimal("0.7"),
            quick_ratio=Decimal("0.4"),
            debt_to_equity=Decimal("3.5"),
            interest_coverage=Decimal("0.8"),
            net_margin_pct=Decimal("-5"),
            roe_pct=Decimal("-10"),
            asset_turnover=Decimal("0.3"),
            ccc_days=Decimal("180"),
            ocf_to_ni_ratio=Decimal("0.1"),
            ocf_ratio=Decimal("0.05"),
        ))
        # Values should all score low
        assert r.composite_score < 40
        assert r.grade == "F"

    def test_partial_data_warning(self):
        r = compute_health_score(HealthScoreInput(
            current_ratio=Decimal("2.0"),
            # all others None
        ))
        # Should still compute with warnings
        assert r.composite_score >= 0
        assert len(r.warnings) > 0

    def test_red_flags_identified(self):
        r = compute_health_score(HealthScoreInput(
            current_ratio=Decimal("2.5"),     # good
            quick_ratio=Decimal("1.8"),        # good
            debt_to_equity=Decimal("4.0"),     # bad
            interest_coverage=Decimal("0.5"),  # bad
            net_margin_pct=Decimal("-3"),      # bad
        ))
        # 3 red flags should be the three worst
        codes = {m.name_en for m in r.red_flags}
        assert "Debt-to-Equity" in codes or "Interest coverage" in codes

    def test_strengths_identified(self):
        r = compute_health_score(HealthScoreInput(
            current_ratio=Decimal("3.0"),
            quick_ratio=Decimal("2.0"),
            net_margin_pct=Decimal("25"),
        ))
        # 3 strongest metrics should be high-scoring
        assert all(m.score >= 85 for m in r.strengths)

    def test_dimension_weights_sum_100(self):
        r = compute_health_score(HealthScoreInput(
            current_ratio=Decimal("1.5"),
        ))
        # Sum of dimension weights should be 100
        total = sum(d.weight_pct for d in r.dimensions)
        assert total == Decimal("100")


class TestRoutes:
    def test_wc_requires_auth(self, client):
        r = client.post("/working-capital/analyze", json={})
        assert r.status_code == 401

    def test_wc_http(self, client, auth_header):
        r = client.post(
            "/working-capital/analyze",
            json={
                "revenue": "1000000",
                "cogs": "600000",
                "accounts_receivable": "100000",
                "inventory": "150000",
                "accounts_payable": "80000",
                "current_assets": "300000",
                "current_liabilities": "200000",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["ccc"] is not None
        assert d["health"] in ("healthy", "watch", "risk")

    def test_health_requires_auth(self, client):
        r = client.post("/health-score/compute", json={})
        assert r.status_code == 401

    def test_health_http(self, client, auth_header):
        r = client.post(
            "/health-score/compute",
            json={
                "current_ratio": "1.5",
                "quick_ratio": "1.0",
                "debt_to_equity": "0.8",
                "interest_coverage": "5",
                "net_margin_pct": "10",
                "roe_pct": "15",
                "asset_turnover": "1.0",
                "ccc_days": "40",
                "ocf_to_ni_ratio": "1.1",
                "ocf_ratio": "0.8",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert 0 <= d["composite_score"] <= 100
        assert d["grade"] in ("A", "B", "C", "D", "F")
        assert len(d["dimensions"]) == 5
