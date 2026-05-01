"""APEX Platform -- app/core/anomaly_live.py unit tests.

Coverage target: ≥90% of 85 statements (G-T1.7b.2, Sprint 10).

anomaly_live.py is a pure-Python live anomaly bridge: tenant-scoped
in-memory ring buffer + scan-API. We exercise:

  * `_txn_from_payload` — happy path + drop branches (no id, no amount).
  * `_bus_listener` — event filter + buffer append.
  * `buffer_size`, `get_buffer`, `clear_buffer` (with/without tenant_id).
  * `scan_tenant` — full scan with mocked `scan_all` + emit capture.
  * `scan_tenant` — empty buffer / unavailable detector / scan raising.
  * Severity threshold gate (`_MIN_EMIT_SEVERITY`).
  * `scan_all_tenants` — multi-tenant aggregation.

Mocks: `scan_all` is monkeypatched to return a list of `SimpleNamespace`
findings (no `app.core.anomaly_detector` dep). `emit` is monkeypatched
to capture invocations without dispatching real listeners.
"""

from __future__ import annotations

import types

import pytest

from app.core import anomaly_live as al


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture(autouse=True)
def _clear_buffers():
    """Each test starts with empty per-tenant buffers."""
    al.clear_buffer()
    yield
    al.clear_buffer()


@pytest.fixture
def fake_finding():
    """Factory for a SimpleNamespace mimicking AnomalyFinding."""
    def _make(*, type_="duplicate", severity="medium", message_ar="مشبوه",
              transaction_ids=None, metadata=None):
        return types.SimpleNamespace(
            type=type_,
            severity=severity,
            message_ar=message_ar,
            transaction_ids=transaction_ids or [],
            metadata=metadata or {},
        )
    return _make


@pytest.fixture
def emit_capture(monkeypatch):
    """Capture every `emit()` call inside anomaly_live for verification."""
    calls = []

    def fake_emit(event_name, payload, *, source=None):
        calls.append({"event": event_name, "payload": payload, "source": source})

    monkeypatch.setattr(al, "emit", fake_emit)
    return calls


# ══════════════════════════════════════════════════════════════
# _txn_from_payload — payload → txn-shape mapper
# ══════════════════════════════════════════════════════════════


class TestTxnFromPayload:
    def test_je_posted_minimal_payload(self):
        txn = al._txn_from_payload(
            "je.posted",
            {"je_id": "JE-1", "amount": 100, "vendor_name": "Acme"},
        )
        assert txn is not None
        assert txn["id"] == "JE-1"
        assert txn["vendor"] == "Acme"
        assert txn["amount"] == 100
        assert txn["_event"] == "je.posted"

    def test_payment_received_uses_payment_id(self):
        txn = al._txn_from_payload("payment.received", {
            "payment_id": "PAY-1",
            "total_amount": 50.0,
            "payee": "Bob",
        })
        assert txn["id"] == "PAY-1"
        assert txn["vendor"] == "Bob"
        assert txn["amount"] == 50.0

    def test_invoice_posted_uses_invoice_id_and_customer_name(self):
        txn = al._txn_from_payload("invoice.posted", {
            "invoice_id": "INV-7",
            "total": 200.0,
            "customer_name": "Customer Co",
            "customer_id": "C-1",
        })
        assert txn["id"] == "INV-7"
        assert txn["vendor"] == "Customer Co"
        assert txn["vendor_id"] == "C-1"
        assert txn["amount"] == 200.0

    def test_drops_when_no_id(self):
        assert al._txn_from_payload("je.posted", {"amount": 100}) is None

    def test_drops_when_no_amount(self):
        assert al._txn_from_payload("je.posted", {"je_id": "X"}) is None


# ══════════════════════════════════════════════════════════════
# _bus_listener — event filter + buffer append
# ══════════════════════════════════════════════════════════════


class TestBusListener:
    def test_appends_monitored_event_to_tenant_buffer(self):
        al._bus_listener("je.posted", {
            "tenant_id": "t1",
            "je_id": "JE-1",
            "amount": 100,
        })
        assert al.buffer_size("t1") == 1
        assert al.get_buffer("t1")[0]["id"] == "JE-1"

    def test_unmonitored_event_is_ignored(self):
        al._bus_listener("user.login", {
            "tenant_id": "t1",
            "je_id": "JE-1",
            "amount": 100,
        })
        assert al.buffer_size("t1") == 0

    def test_payload_without_id_or_amount_is_dropped(self):
        al._bus_listener("je.posted", {"tenant_id": "t1"})
        assert al.buffer_size("t1") == 0

    def test_falls_back_to_unknown_tenant(self):
        al._bus_listener("je.posted", {"je_id": "JE-1", "amount": 100})
        # No tenant_id → bucketed under "_unknown"
        assert al.buffer_size("_unknown") == 1


# ══════════════════════════════════════════════════════════════
# buffer_size / get_buffer / clear_buffer
# ══════════════════════════════════════════════════════════════


class TestBufferAccessors:
    def test_buffer_size_per_tenant_and_global(self):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "1", "amount": 1})
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "2", "amount": 2})
        al._bus_listener("je.posted", {"tenant_id": "t2", "je_id": "3", "amount": 3})
        assert al.buffer_size("t1") == 2
        assert al.buffer_size("t2") == 1
        # No-arg → global sum across all tenants.
        assert al.buffer_size() == 3

    def test_get_buffer_returns_list_copy(self):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "1", "amount": 1})
        out = al.get_buffer("t1")
        assert isinstance(out, list)
        assert len(out) == 1
        # mutating the returned list must not affect internal state.
        out.clear()
        assert al.buffer_size("t1") == 1

    def test_get_buffer_unknown_tenant_returns_empty_list(self):
        assert al.get_buffer("missing") == []

    def test_clear_buffer_specific_tenant(self):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "1", "amount": 1})
        al._bus_listener("je.posted", {"tenant_id": "t2", "je_id": "2", "amount": 2})
        al.clear_buffer("t1")
        assert al.buffer_size("t1") == 0
        assert al.buffer_size("t2") == 1

    def test_clear_buffer_global(self):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "1", "amount": 1})
        al._bus_listener("je.posted", {"tenant_id": "t2", "je_id": "2", "amount": 2})
        al.clear_buffer()
        assert al.buffer_size() == 0


# ══════════════════════════════════════════════════════════════
# scan_tenant — orchestration
# ══════════════════════════════════════════════════════════════


class TestScanTenant:
    def test_returns_unavailable_when_detector_missing(self, monkeypatch):
        monkeypatch.setattr(al, "scan_all", None)
        out = al.scan_tenant("t1")
        assert out == {"ok": False, "error": "anomaly_detector_unavailable"}

    def test_empty_buffer_returns_zero_findings(self):
        out = al.scan_tenant("t1")
        assert out == {
            "ok": True,
            "tenant_id": "t1",
            "findings": [],
            "by_severity": {},
            "txn_count": 0,
        }

    def test_emits_high_severity_finding(self, monkeypatch, emit_capture, fake_finding):
        # Seed buffer.
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "JE-1", "amount": 100})

        finding = fake_finding(
            type_="duplicate",
            severity="high",
            message_ar="معاملة مكررة",
            transaction_ids=["JE-1"],
            metadata={"score": 0.92},
        )
        monkeypatch.setattr(al, "scan_all", lambda txns: [finding])

        out = al.scan_tenant("t1")
        assert out["ok"] is True
        assert out["txn_count"] == 1
        assert out["by_severity"] == {"high": 1}
        assert len(out["findings"]) == 1
        assert out["findings"][0]["type"] == "duplicate"

        # emit() called exactly once with the right shape.
        assert len(emit_capture) == 1
        e = emit_capture[0]
        assert e["event"] == "anomaly.detected"
        assert e["source"] == "anomaly_live"
        assert e["payload"]["tenant_id"] == "t1"
        assert e["payload"]["severity"] == "high"
        assert e["payload"]["transaction_ids"] == ["JE-1"]

    def test_low_severity_finding_below_threshold_not_emitted(
        self, monkeypatch, emit_capture, fake_finding
    ):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "JE-1", "amount": 100})
        # severity "low" is below _MIN_EMIT_SEVERITY="medium".
        monkeypatch.setattr(al, "scan_all", lambda txns: [fake_finding(severity="low")])

        out = al.scan_tenant("t1")
        assert out["ok"] is True
        assert out["by_severity"] == {"low": 1}
        # finding still serialized but NOT emitted.
        assert len(out["findings"]) == 1
        assert emit_capture == []

    def test_emit_events_false_suppresses_emit(self, monkeypatch, emit_capture, fake_finding):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "JE-1", "amount": 100})
        monkeypatch.setattr(al, "scan_all", lambda txns: [fake_finding(severity="critical")])
        out = al.scan_tenant("t1", emit_events=False)
        assert out["ok"] is True
        assert emit_capture == []  # emit never called

    def test_scan_all_raising_returns_error(self, monkeypatch):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "JE-1", "amount": 100})

        def boom(_txns):
            raise RuntimeError("detector exploded")

        monkeypatch.setattr(al, "scan_all", boom)
        out = al.scan_tenant("t1")
        assert out["ok"] is False
        assert "detector exploded" in out["error"]


# ══════════════════════════════════════════════════════════════
# scan_all_tenants — aggregation
# ══════════════════════════════════════════════════════════════


class TestScanAllTenants:
    def test_aggregates_across_tenants(self, monkeypatch, fake_finding, emit_capture):
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "1", "amount": 1})
        al._bus_listener("je.posted", {"tenant_id": "t1", "je_id": "2", "amount": 2})
        al._bus_listener("je.posted", {"tenant_id": "t2", "je_id": "3", "amount": 3})

        # Each scan_all call returns one finding per call.
        monkeypatch.setattr(
            al, "scan_all", lambda txns: [fake_finding(severity="medium")]
        )

        out = al.scan_all_tenants()
        assert out["ok"] is True
        assert out["tenants_scanned"] == 2
        assert out["total_txns"] == 3  # 2 + 1
        assert out["total_findings"] == 2  # 1 per tenant
        assert len(out["results"]) == 2

    def test_empty_state_returns_zero(self):
        out = al.scan_all_tenants()
        assert out["ok"] is True
        assert out["tenants_scanned"] == 0
        assert out["total_txns"] == 0
        assert out["total_findings"] == 0
