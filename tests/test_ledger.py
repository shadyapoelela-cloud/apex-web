"""Journal Entry Builder + FX tests."""

from decimal import Decimal

import pytest

from app.core.journal_entry_service import (
    JELineInput, JournalEntryInput, build_journal_entry,
    list_templates, get_template,
)
from app.core.fx_service import (
    FxConvertInput, FxBatchInput, FxBatchItem, FxRevalInput,
    convert_fx, convert_fx_batch, revalue_fx,
)


class TestJournalEntry:
    def test_balanced_cash_sale(self):
        r = build_journal_entry(JournalEntryInput(
            client_id="test-c1", fiscal_year="2026", date="2026-04-15",
            memo="Test sale",
            lines=[
                JELineInput("1100", "Cash", debit=Decimal("1150")),
                JELineInput("4000", "Sales", credit=Decimal("1000")),
                JELineInput("2300", "VAT Output", credit=Decimal("150")),
            ],
            commit=True,
        ))
        assert r.is_balanced is True
        assert r.total_debits == Decimal("1150.00")
        assert r.total_credits == Decimal("1150.00")
        assert r.entry_number is not None
        assert r.sequence >= 1
        assert r.committed is True

    def test_unbalanced_rejected(self):
        with pytest.raises(ValueError, match="not balanced"):
            build_journal_entry(JournalEntryInput(
                client_id="test-c1", fiscal_year="2026", date="2026-04-15",
                lines=[
                    JELineInput("1100", "Cash", debit=Decimal("100")),
                    JELineInput("4000", "Sales", credit=Decimal("90")),  # off
                ],
            ))

    def test_line_with_both_sides_rejected(self):
        with pytest.raises(ValueError, match="both debit and credit"):
            build_journal_entry(JournalEntryInput(
                client_id="c", fiscal_year="2026", date="2026-04-15",
                lines=[
                    JELineInput("1100", "X", debit=Decimal("10"), credit=Decimal("10")),
                    JELineInput("4000", "Y", credit=Decimal("10")),
                ],
            ))

    def test_single_line_rejected(self):
        with pytest.raises(ValueError, match="at least 2 lines"):
            build_journal_entry(JournalEntryInput(
                client_id="c", fiscal_year="2026", date="2026-04-15",
                lines=[JELineInput("1100", "X", debit=Decimal("100"))],
            ))

    def test_empty_line_rejected(self):
        with pytest.raises(ValueError, match="must have either"):
            build_journal_entry(JournalEntryInput(
                client_id="c", fiscal_year="2026", date="2026-04-15",
                lines=[
                    JELineInput("1100", "X"),   # both zero
                    JELineInput("4000", "Y", credit=Decimal("10")),
                ],
            ))

    def test_preview_mode_does_not_reserve_number(self):
        r = build_journal_entry(JournalEntryInput(
            client_id="test-c-preview", fiscal_year="2026", date="2026-04-15",
            commit=False,
            lines=[
                JELineInput("1100", "Cash", debit=Decimal("100")),
                JELineInput("4000", "Sales", credit=Decimal("100")),
            ],
        ))
        assert r.committed is False
        assert r.entry_number is None
        assert r.sequence is None
        assert r.is_balanced is True

    def test_sequential_numbers(self):
        # Two committed entries must get sequential numbers
        a = build_journal_entry(JournalEntryInput(
            client_id="test-seq-client", fiscal_year="2099", date="2099-01-01",
            lines=[
                JELineInput("1", "A", debit=Decimal("1")),
                JELineInput("2", "B", credit=Decimal("1")),
            ],
        ))
        b = build_journal_entry(JournalEntryInput(
            client_id="test-seq-client", fiscal_year="2099", date="2099-01-02",
            lines=[
                JELineInput("1", "A", debit=Decimal("1")),
                JELineInput("2", "B", credit=Decimal("1")),
            ],
        ))
        assert b.sequence == a.sequence + 1

    def test_templates_listed(self):
        tmpls = list_templates()
        assert len(tmpls) >= 5
        codes = {t["code"] for t in tmpls}
        assert "cash_sale" in codes
        assert "payroll" in codes
        assert "depreciation" in codes

    def test_template_by_code(self):
        t = get_template("cash_sale")
        assert t is not None
        assert t["name_ar"] == "مبيعات نقدية"
        assert len(t["lines"]) == 3

    def test_template_unknown_returns_none(self):
        assert get_template("nonsense_template") is None


class TestFxConvert:
    def test_same_currency_noop(self):
        r = convert_fx(FxConvertInput(
            amount=Decimal("100"),
            from_currency="SAR", to_currency="SAR",
        ))
        assert r.amount_to == Decimal("100.00")
        assert r.rate_applied == Decimal("1.000000")

    def test_direct_rate(self):
        # 100 USD × 3.75 = 375 SAR
        r = convert_fx(FxConvertInput(
            amount=Decimal("100"),
            from_currency="USD", to_currency="SAR",
            direct_rate=Decimal("3.75"),
        ))
        assert r.amount_to == Decimal("375.00")
        assert r.via_base is False

    def test_cross_rate_via_base(self):
        # 100 USD → EUR using defaults: USD rate 3.75, EUR 4.05
        # Cross rate = 3.75 / 4.05 = 0.9259
        # 100 × 0.9259 = 92.59
        r = convert_fx(FxConvertInput(
            amount=Decimal("100"),
            from_currency="USD", to_currency="EUR",
        ))
        assert Decimal("92") < r.amount_to < Decimal("93")
        assert r.via_base is True

    def test_negative_amount_rejected(self):
        with pytest.raises(ValueError):
            convert_fx(FxConvertInput(
                amount=Decimal("-100"), from_currency="USD", to_currency="SAR",
            ))

    def test_unknown_currency_rejected(self):
        with pytest.raises(ValueError, match="No rate"):
            convert_fx(FxConvertInput(
                amount=Decimal("100"),
                from_currency="ZZZ", to_currency="SAR",
            ))


class TestFxBatch:
    def test_batch_convert_to_sar(self):
        r = convert_fx_batch(FxBatchInput(
            target_currency="SAR",
            items=[
                FxBatchItem("USD invoice", Decimal("100"), "USD"),
                FxBatchItem("EUR invoice", Decimal("50"), "EUR"),
                FxBatchItem("SAR invoice", Decimal("200"), "SAR"),
            ],
        ))
        # 100 × 3.75 = 375
        # 50 × 4.05 = 202.50
        # 200 × 1 = 200
        # Total: 777.50
        assert r.total_converted == Decimal("777.50")
        assert len(r.items) == 3

    def test_empty_batch_rejected(self):
        with pytest.raises(ValueError):
            convert_fx_batch(FxBatchInput(items=[]))


class TestFxRevalue:
    def test_gain(self):
        r = revalue_fx(FxRevalInput(
            amount_foreign=Decimal("1000"),
            foreign_currency="USD",
            historical_rate=Decimal("3.70"),
            current_rate=Decimal("3.80"),
        ))
        # 1000 × (3.80 − 3.70) = 100 gain
        assert r.unrealised_gain_loss == Decimal("100.00")
        assert r.gain_or_loss == "gain"

    def test_loss(self):
        r = revalue_fx(FxRevalInput(
            amount_foreign=Decimal("1000"),
            foreign_currency="USD",
            historical_rate=Decimal("3.80"),
            current_rate=Decimal("3.70"),
        ))
        assert r.unrealised_gain_loss == Decimal("-100.00")
        assert r.gain_or_loss == "loss"
        assert any("IAS 21" in w for w in r.warnings)

    def test_no_change(self):
        r = revalue_fx(FxRevalInput(
            amount_foreign=Decimal("1000"), foreign_currency="USD",
            historical_rate=Decimal("3.75"), current_rate=Decimal("3.75"),
        ))
        assert r.gain_or_loss == "none"
        assert r.unrealised_gain_loss == Decimal("0.00")

    def test_bad_rate_rejected(self):
        with pytest.raises(ValueError):
            revalue_fx(FxRevalInput(
                amount_foreign=Decimal("100"), foreign_currency="USD",
                historical_rate=Decimal("0"), current_rate=Decimal("3.75"),
            ))


class TestRoutes:
    def test_je_build_requires_auth(self, client):
        r = client.post("/je/build", json={})
        assert r.status_code == 401

    def test_je_build_http(self, client, auth_header):
        r = client.post("/je/build", json={
            "client_id": "http-je-test",
            "fiscal_year": "2026",
            "date": "2026-04-15",
            "memo": "HTTP test",
            "commit": False,   # preview
            "lines": [
                {"account_code": "1100", "account_name": "Cash", "debit": "100"},
                {"account_code": "4000", "account_name": "Sales", "credit": "100"},
            ],
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["is_balanced"] is True
        assert d["committed"] is False

    def test_je_unbalanced_http(self, client, auth_header):
        r = client.post("/je/build", json={
            "client_id": "c", "fiscal_year": "2026", "date": "2026-04-15",
            "lines": [
                {"account_code": "1100", "account_name": "Cash", "debit": "100"},
                {"account_code": "4000", "account_name": "Sales", "credit": "90"},
            ],
        }, headers=auth_header)
        assert r.status_code == 422

    def test_je_templates_list(self, client, auth_header):
        r = client.get("/je/templates", headers=auth_header)
        assert r.status_code == 200
        assert len(r.json()["data"]) > 0

    def test_fx_convert_http(self, client, auth_header):
        r = client.post("/fx/convert", json={
            "amount": "100",
            "from_currency": "USD", "to_currency": "SAR",
            "direct_rate": "3.75",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["amount_to"] == "375.00"

    def test_fx_batch_http(self, client, auth_header):
        r = client.post("/fx/batch", json={
            "target_currency": "SAR",
            "items": [{"label": "X", "amount": "100", "from_currency": "USD"}],
        }, headers=auth_header)
        assert r.status_code == 200
        assert float(r.json()["data"]["total_converted"]) > 0

    def test_fx_revalue_http(self, client, auth_header):
        r = client.post("/fx/revalue", json={
            "amount_foreign": "1000",
            "foreign_currency": "USD",
            "historical_rate": "3.70",
            "current_rate": "3.80",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["gain_or_loss"] == "gain"

    def test_fx_currencies(self, client, auth_header):
        r = client.get("/fx/currencies", headers=auth_header)
        assert r.status_code == 200
        assert "SAR" in r.json()["data"]

    def test_endpoints_require_auth(self, client):
        assert client.post("/fx/convert", json={}).status_code == 401
        assert client.get("/fx/currencies").status_code == 401
