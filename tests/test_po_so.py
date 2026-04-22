"""Tests for Purchase Orders & Sales Orders service."""

import pytest
from decimal import Decimal
from app.core.po_so_service import (
    OrderLine, OrderInput, process_order, to_dict, _q, KSA_VAT_RATE,
)


def _line(code="ITM01", desc="Item", qty=10, price=100, disc=0, vat=0.15, recv=None):
    return OrderLine(
        item_code=code, description=desc,
        quantity=Decimal(str(qty)), unit_price=Decimal(str(price)),
        discount_pct=Decimal(str(disc)), vat_rate=Decimal(str(vat)),
        received_qty=Decimal(str(recv)) if recv is not None else None,
    )


def _po(lines, party="مورد تجريبي", date="2026-04-17"):
    return OrderInput(order_type="purchase", counterparty=party,
                      order_date=date, lines=lines)


def _so(lines, party="عميل تجريبي", date="2026-04-17"):
    return OrderInput(order_type="sales", counterparty=party,
                      order_date=date, lines=lines)


class TestPurchaseOrder:
    def test_basic_po(self):
        r = process_order(_po([_line(qty=10, price=100)]))
        assert r.order_type == "purchase"
        assert r.subtotal == Decimal("1000.00")
        assert r.total_vat == Decimal("150.00")
        assert r.grand_total == Decimal("1150.00")

    def test_po_with_discount(self):
        r = process_order(_po([_line(qty=10, price=100, disc=10)]))
        assert r.subtotal == Decimal("900.00")
        assert r.total_discount == Decimal("100.00")
        assert r.total_vat == Decimal("135.00")
        assert r.grand_total == Decimal("1035.00")

    def test_po_multiple_lines(self):
        r = process_order(_po([
            _line("A", "Widget", qty=100, price=50),
            _line("B", "Gadget", qty=20, price=200),
        ]))
        assert r.subtotal == Decimal("9000.00")  # 5000 + 4000
        assert len(r.lines) == 2


class TestSalesOrder:
    def test_basic_so(self):
        r = process_order(_so([_line(qty=5, price=500)]))
        assert r.order_type == "sales"
        assert r.subtotal == Decimal("2500.00")
        assert r.total_vat == Decimal("375.00")
        assert r.grand_total == Decimal("2875.00")

    def test_so_zero_vat(self):
        r = process_order(_so([_line(qty=10, price=100, vat=0)]))
        assert r.total_vat == Decimal("0.00")
        assert r.grand_total == Decimal("1000.00")


class TestThreeWayMatch:
    def test_full_receipt(self):
        r = process_order(_po([_line(qty=10, price=100, recv=10)]))
        assert r.three_way_match is not None
        assert r.three_way_match.status == "matched"
        assert r.three_way_match.match_pct == Decimal("100.00")
        assert r.status == "received"

    def test_partial_receipt(self):
        r = process_order(_po([_line(qty=10, price=100, recv=6)]))
        assert r.three_way_match.status == "partial"
        assert r.three_way_match.match_pct == Decimal("60.00")
        assert r.status == "partially_received"

    def test_over_receipt(self):
        r = process_order(_po([_line(qty=10, price=100, recv=12)]))
        assert r.three_way_match.status == "over_receipt"

    def test_no_match_for_sales(self):
        r = process_order(_so([_line(qty=10, price=100, recv=10)]))
        assert r.three_way_match is None


class TestJournalSuggestion:
    def test_po_journal(self):
        r = process_order(_po([_line(qty=10, price=100)]))
        j = r.journal_suggestion
        assert "شراء" in j.description
        assert len(j.entries) == 3
        debits = sum(Decimal(e["debit"]) for e in j.entries)
        credits = sum(Decimal(e["credit"]) for e in j.entries)
        assert debits == credits  # balanced

    def test_so_journal(self):
        r = process_order(_so([_line(qty=10, price=100)]))
        j = r.journal_suggestion
        assert "بيع" in j.description
        debits = sum(Decimal(e["debit"]) for e in j.entries)
        credits = sum(Decimal(e["credit"]) for e in j.entries)
        assert debits == credits


class TestValidation:
    def test_empty_lines_raises(self):
        with pytest.raises(ValueError, match="lines"):
            process_order(OrderInput(order_type="purchase", counterparty="X",
                                     order_date="2026-01-01", lines=[]))

    def test_invalid_type_raises(self):
        with pytest.raises(ValueError, match="order_type"):
            process_order(OrderInput(order_type="rental", counterparty="X",
                                     order_date="2026-01-01",
                                     lines=[_line()]))

    def test_zero_qty_raises(self):
        with pytest.raises(ValueError, match="quantity"):
            process_order(_po([_line(qty=0)]))

    def test_high_discount_warning(self):
        r = process_order(_po([_line(qty=10, price=100, disc=40)]))
        assert len(r.warnings) >= 1


class TestToDict:
    def test_dict_keys(self):
        r = process_order(_po([_line(qty=10, price=100, recv=10)]))
        d = to_dict(r)
        assert "order_type" in d
        assert "subtotal" in d
        assert "grand_total" in d
        assert "lines" in d
        assert "journal_suggestion" in d
        assert "three_way_match" in d
        assert len(d["lines"]) == 1
