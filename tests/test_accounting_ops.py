"""Bank Rec + Inventory + Aging tests."""

from decimal import Decimal

import pytest

from app.core.bank_rec_service import BankRecInput, RecItem, compute_bank_rec
from app.core.inventory_service import InventoryInput, InventoryTxn, compute_inventory
from app.core.aging_service import AgingInput, AgingInvoice, compute_aging


# ══════════════════════════════════════════════════════════════
# Bank Reconciliation
# ══════════════════════════════════════════════════════════════


class TestBankRec:
    def test_already_reconciled(self):
        r = compute_bank_rec(BankRecInput(
            book_balance=Decimal("10000"),
            bank_balance=Decimal("10000"),
        ))
        assert r.reconciled is True
        assert r.difference == Decimal("0.00")

    def test_outstanding_check_reduces_bank(self):
        # Check written (book already −) but not yet cleared
        r = compute_bank_rec(BankRecInput(
            book_balance=Decimal("5000"),
            bank_balance=Decimal("7000"),
            items=[
                RecItem("Outstanding Check #123", Decimal("2000"), "bank", "subtract"),
            ],
        ))
        # book 5000, bank adjusted 5000 → reconciled
        assert r.adjusted_bank == Decimal("5000.00")
        assert r.reconciled is True

    def test_deposit_in_transit_increases_bank(self):
        r = compute_bank_rec(BankRecInput(
            book_balance=Decimal("10000"),
            bank_balance=Decimal("8000"),
            items=[
                RecItem("Deposit in transit", Decimal("2000"), "bank", "add"),
            ],
        ))
        assert r.adjusted_bank == Decimal("10000.00")
        assert r.reconciled is True

    def test_bank_charges_reduce_book(self):
        r = compute_bank_rec(BankRecInput(
            book_balance=Decimal("5100"),
            bank_balance=Decimal("5000"),
            items=[
                RecItem("Bank service charge", Decimal("100"), "book", "subtract"),
            ],
        ))
        assert r.adjusted_book == Decimal("5000.00")
        assert r.reconciled is True

    def test_unreconciled_has_difference(self):
        r = compute_bank_rec(BankRecInput(
            book_balance=Decimal("5000"),
            bank_balance=Decimal("4800"),
        ))
        assert r.reconciled is False
        assert r.difference == Decimal("200.00")
        assert any("فرق" in w for w in r.warnings)

    def test_negative_amount_rejected(self):
        with pytest.raises(ValueError):
            compute_bank_rec(BankRecInput(items=[
                RecItem("Bad", Decimal("-50"), "book", "add"),
            ]))

    def test_bad_side_rejected(self):
        with pytest.raises(ValueError):
            compute_bank_rec(BankRecInput(items=[
                RecItem("X", Decimal("10"), "asset", "add"),
            ]))


# ══════════════════════════════════════════════════════════════
# Inventory Valuation
# ══════════════════════════════════════════════════════════════


class TestInventory:
    def test_fifo_simple(self):
        r = compute_inventory(InventoryInput(
            method="fifo",
            transactions=[
                InventoryTxn("purchase", Decimal("10"), Decimal("100")),   # 10 @ 100
                InventoryTxn("purchase", Decimal("10"), Decimal("120")),   # 10 @ 120
                InventoryTxn("sale", Decimal("12")),                        # sell 12
            ],
        ))
        # FIFO: first 10@100 + 2@120 = 1000 + 240 = 1240 COGS
        assert r.total_cogs == Decimal("1240.00")
        # Remaining: 8 @ 120 = 960
        assert r.ending_qty == Decimal("8.00")
        assert r.ending_value == Decimal("960.00")

    def test_lifo_simple(self):
        r = compute_inventory(InventoryInput(
            method="lifo",
            transactions=[
                InventoryTxn("purchase", Decimal("10"), Decimal("100")),
                InventoryTxn("purchase", Decimal("10"), Decimal("120")),
                InventoryTxn("sale", Decimal("12")),
            ],
        ))
        # LIFO: last 10@120 + 2@100 = 1200 + 200 = 1400
        assert r.total_cogs == Decimal("1400.00")
        assert r.ending_qty == Decimal("8.00")
        assert r.ending_value == Decimal("800.00")
        # IFRS warning
        assert any("IFRS" in w or "LIFO" in w for w in r.warnings)

    def test_wac_simple(self):
        r = compute_inventory(InventoryInput(
            method="wac",
            transactions=[
                InventoryTxn("purchase", Decimal("10"), Decimal("100")),
                InventoryTxn("purchase", Decimal("10"), Decimal("120")),
                InventoryTxn("sale", Decimal("12")),
            ],
        ))
        # WAC: avg = (1000 + 1200) / 20 = 110 → 12 * 110 = 1320 COGS
        assert r.total_cogs == Decimal("1320.00")
        assert r.ending_qty == Decimal("8.00")
        # 8 * 110 = 880
        assert r.ending_value == Decimal("880.00")

    def test_revenue_and_gross_profit(self):
        r = compute_inventory(InventoryInput(
            method="fifo",
            transactions=[
                InventoryTxn("purchase", Decimal("10"), Decimal("50")),
                InventoryTxn("sale", Decimal("10"), unit_price=Decimal("80")),
            ],
        ))
        assert r.total_revenue == Decimal("800.00")
        assert r.total_cogs == Decimal("500.00")
        assert r.gross_profit == Decimal("300.00")

    def test_sale_exceeds_inventory_rejected(self):
        with pytest.raises(ValueError, match="exceeds on-hand"):
            compute_inventory(InventoryInput(
                method="fifo",
                transactions=[
                    InventoryTxn("purchase", Decimal("5"), Decimal("100")),
                    InventoryTxn("sale", Decimal("10")),
                ],
            ))

    def test_empty_transactions_rejected(self):
        with pytest.raises(ValueError):
            compute_inventory(InventoryInput(method="fifo"))

    def test_unknown_method_rejected(self):
        with pytest.raises(ValueError):
            compute_inventory(InventoryInput(
                method="specific_id",
                transactions=[InventoryTxn("purchase", Decimal("1"), Decimal("1"))],
            ))


# ══════════════════════════════════════════════════════════════
# Aging
# ══════════════════════════════════════════════════════════════


class TestAging:
    def test_current_bucket(self):
        r = compute_aging(AgingInput(
            kind="ar",
            as_of_date="2026-01-01",
            invoices=[
                AgingInvoice("Customer A", "INV-1",
                    "2026-01-01", "2026-02-01", Decimal("1000")),
            ],
        ))
        assert r.total_outstanding == Decimal("1000.00")
        current_bucket = next(b for b in r.buckets if b.code == "current")
        assert current_bucket.total == Decimal("1000.00")

    def test_31_60_bucket(self):
        r = compute_aging(AgingInput(
            kind="ar",
            as_of_date="2026-03-01",
            invoices=[
                AgingInvoice("Customer B", "INV-2",
                    "2025-12-01", "2026-01-15", Decimal("500")),  # 45 days overdue
            ],
        ))
        b = next(b for b in r.buckets if b.code == "d31_60")
        assert b.total == Decimal("500.00")

    def test_90_plus_bucket(self):
        r = compute_aging(AgingInput(
            kind="ar",
            as_of_date="2026-06-01",
            invoices=[
                AgingInvoice("Customer C", "INV-3",
                    "2025-10-01", "2026-01-01", Decimal("2000")),  # 151 days
            ],
        ))
        b = next(b for b in r.buckets if b.code == "d90_plus")
        assert b.total == Decimal("2000.00")

    def test_ecl_for_ar(self):
        r = compute_aging(AgingInput(
            kind="ar",
            as_of_date="2026-06-01",
            invoices=[
                AgingInvoice("C1", "I-1", "2026-05-01", "2026-07-01", Decimal("10000")),  # current
                AgingInvoice("C2", "I-2", "2025-10-01", "2026-01-01", Decimal("5000")),   # 90+
            ],
        ))
        # Current: 10000 * 0.5% = 50; 90+: 5000 * 40% = 2000 → ECL 2050
        assert r.total_ecl == Decimal("2050.00")

    def test_ap_no_ecl(self):
        r = compute_aging(AgingInput(
            kind="ap",
            as_of_date="2026-01-01",
            invoices=[
                AgingInvoice("Supplier X", "B-1",
                    "2025-11-01", "2025-12-01", Decimal("3000")),
            ],
        ))
        # AP → no ECL
        assert r.total_ecl == Decimal("0.00")

    def test_by_counterparty_aggregation(self):
        r = compute_aging(AgingInput(
            kind="ar",
            as_of_date="2026-01-01",
            invoices=[
                AgingInvoice("A", "1", "2025-12-01", "2026-01-15", Decimal("1000")),
                AgingInvoice("A", "2", "2025-12-15", "2026-01-30", Decimal("500")),
                AgingInvoice("B", "3", "2025-11-01", "2025-12-15", Decimal("2000")),
            ],
        ))
        assert len(r.by_counterparty) == 2
        a = next(c for c in r.by_counterparty if c.counterparty == "A")
        b = next(c for c in r.by_counterparty if c.counterparty == "B")
        assert a.total == Decimal("1500.00")
        assert b.total == Decimal("2000.00")
        # Sorted by total desc — B first
        assert r.by_counterparty[0].counterparty == "B"

    def test_invalid_kind_rejected(self):
        with pytest.raises(ValueError):
            compute_aging(AgingInput(
                kind="xx",
                invoices=[AgingInvoice("A", "1", "2026-01-01", "2026-02-01", Decimal("100"))],
            ))

    def test_bad_date_rejected(self):
        with pytest.raises(ValueError):
            compute_aging(AgingInput(
                kind="ar",
                invoices=[AgingInvoice("A", "1", "2026-01-01", "not-a-date", Decimal("100"))],
            ))

    def test_high_overdue_warning(self):
        r = compute_aging(AgingInput(
            kind="ar",
            as_of_date="2026-06-01",
            invoices=[
                AgingInvoice("C1", "1", "2025-10-01", "2025-12-01", Decimal("10000")),  # 90+
                AgingInvoice("C2", "2", "2026-05-01", "2026-06-01", Decimal("5000")),   # current
            ],
        ))
        # 10k out of 15k = 66% in 90+ → warning
        assert any("90 يوم" in w for w in r.warnings)


# ══════════════════════════════════════════════════════════════
# HTTP
# ══════════════════════════════════════════════════════════════


class TestRoutes:
    def test_bank_rec_http(self, client, auth_header):
        r = client.post(
            "/bank-rec/compute",
            json={
                "book_balance": "10000",
                "bank_balance": "10000",
                "items": [],
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["reconciled"] is True

    def test_inventory_http(self, client, auth_header):
        r = client.post(
            "/inventory/valuate",
            json={
                "method": "fifo",
                "transactions": [
                    {"kind": "purchase", "quantity": "10", "unit_cost": "100"},
                    {"kind": "sale", "quantity": "5"},
                ],
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["ending_qty"] == "5.00"
        assert d["total_cogs"] == "500.00"

    def test_aging_http(self, client, auth_header):
        r = client.post(
            "/aging/report",
            json={
                "kind": "ar",
                "as_of_date": "2026-01-01",
                "invoices": [
                    {"counterparty": "C1", "invoice_number": "I-1",
                     "invoice_date": "2025-12-01", "due_date": "2026-01-15",
                     "balance": "1000"},
                ],
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_outstanding"] == "1000.00"

    def test_endpoints_require_auth(self, client):
        assert client.post("/bank-rec/compute", json={}).status_code == 401
        assert client.post("/inventory/valuate", json={}).status_code == 401
        assert client.post("/aging/report", json={}).status_code == 401
