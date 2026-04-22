"""Tests for Inventory & Warehouse Management service."""

import pytest
from decimal import Decimal
from app.core.inventory_service import (
    Item, Warehouse, StockMovement, InventoryInput,
    process_inventory, to_dict, _q,
)


def _item(sku, name="Item", cat="general", rp=0, rq=0, nrv=None):
    return Item(sku=sku, name=name, category=cat,
                reorder_point=Decimal(str(rp)),
                reorder_qty=Decimal(str(rq)),
                nrv=Decimal(str(nrv)) if nrv is not None else None)


def _wh(code, name="Warehouse"):
    return Warehouse(code=code, name=name)


def _mv(sku, mtype, qty, cost, wh, to_wh=None, ref=""):
    return StockMovement(item_sku=sku, movement_type=mtype,
                         quantity=Decimal(str(qty)), unit_cost=Decimal(str(cost)),
                         warehouse_code=wh, to_warehouse_code=to_wh, reference=ref)


def _inp(items, warehouses, movements):
    return InventoryInput(items=items, warehouses=warehouses, movements=movements)


class TestBasicReceipts:
    def test_single_receipt(self):
        r = process_inventory(_inp(
            [_item("SKU1", "Widget")],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1")],
        ))
        assert len(r.balances) == 1
        assert r.balances[0].quantity == Decimal("100.00")
        assert r.balances[0].unit_cost == Decimal("10.00")
        assert r.total_stock_value == Decimal("1000.00")

    def test_multiple_receipts_avg_cost(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1"),
             _mv("SKU1", "receipt", 100, 12, "WH1")],
        ))
        assert r.balances[0].quantity == Decimal("200.00")
        assert r.balances[0].unit_cost == Decimal("11.00")  # weighted avg
        assert r.total_stock_value == Decimal("2200.00")

    def test_multi_warehouse(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1"), _wh("WH2")],
            [_mv("SKU1", "receipt", 50, 10, "WH1"),
             _mv("SKU1", "receipt", 30, 12, "WH2")],
        ))
        assert len(r.balances) == 2
        assert r.total_stock_value == Decimal("860.00")  # 500 + 360


class TestIssues:
    def test_simple_issue(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1"),
             _mv("SKU1", "issue", 30, 10, "WH1")],
        ))
        assert r.balances[0].quantity == Decimal("70.00")
        assert r.total_stock_value == Decimal("700.00")

    def test_over_issue_warning(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 10, 10, "WH1"),
             _mv("SKU1", "issue", 20, 10, "WH1")],
        ))
        assert len(r.warnings) >= 1
        assert r.balances == []  # qty went to 0


class TestTransfers:
    def test_warehouse_transfer(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1"), _wh("WH2")],
            [_mv("SKU1", "receipt", 100, 10, "WH1"),
             _mv("SKU1", "transfer", 40, 10, "WH1", "WH2")],
        ))
        assert len(r.balances) == 2
        bals = {b.warehouse_code: b for b in r.balances}
        assert bals["WH1"].quantity == Decimal("60.00")
        assert bals["WH2"].quantity == Decimal("40.00")


class TestAdjustments:
    def test_positive_adjustment(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1"),
             _mv("SKU1", "adjustment", 5, 10, "WH1")],
        ))
        assert r.balances[0].quantity == Decimal("105.00")

    def test_negative_adjustment(self):
        r = process_inventory(_inp(
            [_item("SKU1")],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1"),
             _mv("SKU1", "adjustment", -10, 10, "WH1")],
        ))
        assert r.balances[0].quantity == Decimal("90.00")


class TestNRV:
    def test_nrv_writedown(self):
        r = process_inventory(_inp(
            [_item("SKU1", nrv=8)],  # NRV=8, cost=10
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1")],
        ))
        assert r.balances[0].nrv_writedown == Decimal("200.00")  # (10-8)*100
        assert r.total_nrv_writedown == Decimal("200.00")
        assert r.total_stock_value == Decimal("800.00")  # at NRV
        assert len(r.warnings) >= 1

    def test_no_nrv_writedown_when_cost_below(self):
        r = process_inventory(_inp(
            [_item("SKU1", nrv=15)],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 100, 10, "WH1")],
        ))
        assert r.balances[0].nrv_writedown == Decimal("0.00")
        assert r.total_stock_value == Decimal("1000.00")


class TestReorderAlerts:
    def test_reorder_triggered(self):
        r = process_inventory(_inp(
            [_item("SKU1", rp=50, rq=100)],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 30, 10, "WH1")],
        ))
        assert len(r.reorder_alerts) == 1
        assert r.reorder_alerts[0]["sku"] == "SKU1"

    def test_no_reorder_when_sufficient(self):
        r = process_inventory(_inp(
            [_item("SKU1", rp=50, rq=100)],
            [_wh("WH1")],
            [_mv("SKU1", "receipt", 200, 10, "WH1")],
        ))
        assert len(r.reorder_alerts) == 0


class TestValidation:
    def test_unknown_sku_raises(self):
        with pytest.raises(ValueError, match="Unknown item SKU"):
            process_inventory(_inp(
                [_item("SKU1")],
                [_wh("WH1")],
                [_mv("BADSKU", "receipt", 10, 10, "WH1")],
            ))

    def test_unknown_warehouse_raises(self):
        with pytest.raises(ValueError, match="Unknown warehouse"):
            process_inventory(_inp(
                [_item("SKU1")],
                [_wh("WH1")],
                [_mv("SKU1", "receipt", 10, 10, "BADWH")],
            ))

    def test_empty_items_raises(self):
        with pytest.raises(ValueError, match="items"):
            process_inventory(InventoryInput(items=[], warehouses=[_wh("WH1")], movements=[]))


class TestToDict:
    def test_dict_structure(self):
        r = process_inventory(_inp(
            [_item("SKU1", "Widget", rp=50)],
            [_wh("WH1", "Main")],
            [_mv("SKU1", "receipt", 100, 10, "WH1"),
             _mv("SKU1", "issue", 20, 10, "WH1")],
        ))
        d = to_dict(r)
        assert "total_stock_value" in d
        assert len(d["balances"]) == 1
        assert d["balances"][0]["sku"] == "SKU1"
        assert d["movement_summary"]["receipts"] == 1
        assert d["movement_summary"]["issues"] == 1
