"""Full Cash Flow Statement (IAS 7) tests."""

from decimal import Decimal

import pytest

from app.core.cashflow_statement_service import (
    CFSLine, CFSInput, build_cash_flow_statement,
)


def _sample() -> CFSInput:
    """
    NI = 1000
    Depreciation (accum) rose by 200 → add-back 200
    AR rose by 300 → WC consumes 300
    AP rose by 150 → WC generates 150
    PP&E gross rose by 500 → investing outflow 500
    LT Debt rose by 400 → financing inflow 400
    Dividends paid explicit_flow = -200 → financing outflow 200
    Cash: opening 100, closing 100 + (CFO + CFI + CFF)
      CFO = 1000 + 200 - 300 + 150 = 1050
      CFI = -500
      CFF = 400 - 200 = 200
      Net = 1050 - 500 + 200 = 750
      Closing cash = 100 + 750 = 850
    """
    return CFSInput(
        entity_name="شركة", period_label="FY2026",
        net_income=Decimal("1000"),
        lines=[
            CFSLine("1100", "النقد", "cash",
                opening_balance=Decimal("100"), closing_balance=Decimal("850")),
            CFSLine("1510", "مجمع الإهلاك", "op_addback",
                opening_balance=Decimal("1000"), closing_balance=Decimal("1200")),
            CFSLine("1200", "الذمم المدينة", "op_wc_asset",
                opening_balance=Decimal("400"), closing_balance=Decimal("700")),
            CFSLine("2100", "الذمم الدائنة", "op_wc_liability",
                opening_balance=Decimal("200"), closing_balance=Decimal("350")),
            CFSLine("1500", "الأصول الثابتة", "investing",
                opening_balance=Decimal("5000"), closing_balance=Decimal("5500")),
            CFSLine("2500", "القروض طويلة الأجل", "financing",
                opening_balance=Decimal("2000"), closing_balance=Decimal("2400")),
            CFSLine("3300", "توزيعات الأرباح", "financing",
                opening_balance=Decimal("0"), closing_balance=Decimal("0"),
                explicit_flow=Decimal("-200")),
        ],
    )


class TestCFS:
    def test_reconciles(self):
        r = build_cash_flow_statement(_sample())
        assert r.cash_from_operating == Decimal("1050.00")
        assert r.cash_from_investing == Decimal("-500.00")
        assert r.cash_from_financing == Decimal("200.00")
        assert r.net_change_in_cash == Decimal("750.00")
        assert r.opening_cash == Decimal("100.00")
        assert r.closing_cash == Decimal("850.00")
        assert r.reconciles is True
        assert r.cash_check == Decimal("0.00")

    def test_non_reconciling_flagged(self):
        inp = _sample()
        # Tamper with closing cash
        inp.lines[0] = CFSLine("1100", "النقد", "cash",
            opening_balance=Decimal("100"), closing_balance=Decimal("900"))
        r = build_cash_flow_statement(inp)
        assert r.reconciles is False
        assert r.cash_check == Decimal("50.00")
        assert any("لا يُطابق" in w for w in r.warnings)

    def test_empty_rejected(self):
        with pytest.raises(ValueError, match="lines is required"):
            build_cash_flow_statement(CFSInput(
                entity_name="x", period_label="p", lines=[]))

    def test_invalid_class_rejected(self):
        with pytest.raises(ValueError, match="cfs_class"):
            build_cash_flow_statement(CFSInput(
                entity_name="x", period_label="p",
                lines=[CFSLine("1", "a", "nonsense",
                    opening_balance=Decimal("0"), closing_balance=Decimal("0"))],
            ))

    def test_duplicate_code_rejected(self):
        with pytest.raises(ValueError, match="duplicate"):
            build_cash_flow_statement(CFSInput(
                entity_name="x", period_label="p",
                lines=[
                    CFSLine("1", "a", "cash",
                        opening_balance=Decimal("0"), closing_balance=Decimal("0")),
                    CFSLine("1", "b", "cash",
                        opening_balance=Decimal("0"), closing_balance=Decimal("0")),
                ],
            ))

    def test_zero_ni_still_reconciles(self):
        inp = CFSInput(
            entity_name="x", period_label="p",
            net_income=Decimal("0"),
            lines=[
                CFSLine("1100", "Cash", "cash",
                    opening_balance=Decimal("100"), closing_balance=Decimal("200")),
                CFSLine("2500", "Debt", "financing",
                    opening_balance=Decimal("0"), closing_balance=Decimal("100")),
            ],
        )
        r = build_cash_flow_statement(inp)
        assert r.cash_from_financing == Decimal("100.00")
        assert r.reconciles is True

    def test_depreciation_only(self):
        # NI = 0, depreciation 500, nothing else moves except cash
        inp = CFSInput(
            entity_name="x", period_label="p",
            net_income=Decimal("0"),
            lines=[
                CFSLine("1100", "Cash", "cash",
                    opening_balance=Decimal("0"), closing_balance=Decimal("500")),
                CFSLine("1510", "Accum Dep", "op_addback",
                    opening_balance=Decimal("0"), closing_balance=Decimal("500")),
            ],
        )
        r = build_cash_flow_statement(inp)
        assert r.cash_from_operating == Decimal("500.00")
        assert r.reconciles is True


class TestRoutes:
    def _payload(self) -> dict:
        return {
            "entity_name": "Co",
            "period_label": "FY 2026",
            "currency": "SAR",
            "net_income": "1000",
            "lines": [
                {"account_code": "1100", "account_name": "Cash",
                 "cfs_class": "cash", "opening_balance": "100",
                 "closing_balance": "1100"},
                {"account_code": "2500", "account_name": "Debt",
                 "cfs_class": "financing", "opening_balance": "0",
                 "closing_balance": "0"},
            ],
        }

    def test_requires_auth(self, client):
        r = client.post("/cfs/build", json={})
        assert r.status_code == 401

    def test_build_http(self, client, auth_header):
        r = client.post("/cfs/build", json=self._payload(), headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["reconciles"] is True
        assert d["cash_from_operating"] == "1000.00"

    def test_classifications(self, client, auth_header):
        r = client.get("/cfs/classifications", headers=auth_header)
        assert r.status_code == 200
        lst = r.json()["data"]
        assert "op_addback" in lst
        assert "investing" in lst
        assert "financing" in lst

    def test_bad_class_http(self, client, auth_header):
        payload = self._payload()
        payload["lines"][0]["cfs_class"] = "junk"
        r = client.post("/cfs/build", json=payload, headers=auth_header)
        assert r.status_code == 422
