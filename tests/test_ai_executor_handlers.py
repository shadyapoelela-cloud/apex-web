"""APEX Platform -- app/ai/approval_executor.py handler-level tests.

Coverage target: cover the 3 `_execute_*` handlers (lines 88-162,
165-251, 254-278) that G-T1.7a deliberately left for G-T1.7a.1.

Existing tests (G-T1.7a) cover:
  * `execute_suggestion` orchestration (not-found, wrong-state, unknown-handler)
  * `execute_all_approved` queue drain + limit + partial-failure accounting

This module exercises the HANDLERS themselves:

  * `_execute_create_invoice`: subtotal validation, ZATCA build success,
    ValueError on bad input, generic exception, signing-cert configured
    vs not, retry-queue enqueue.
  * `_execute_send_reminder`: missing inputs, WhatsApp channel happy
    path + failure fallback, notification dispatch happy + failure,
    tone variants (gentle/firm/final_notice/unknown).
  * `_execute_ap_approval`: bridge ok=True, bridge ok=False, bridge raises.

Mock strategy:
  * Seed `AiSuggestion` rows directly via `SessionLocal()` (G-T1.7a pattern).
  * `sys.modules` stubs for `app.integrations.zatca.signer`,
    `app.integrations.zatca.retry_queue`, `app.integrations.whatsapp.client`,
    `app.core.notifications_bridge`, `app.features.ap_agent.suggestion_bridge`.
"""

from __future__ import annotations

import sys
import types
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest


# ══════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════


def _make_suggestion(*, action_type, after_json=None, status="approved"):
    """Insert an AiSuggestion row + return it (detached for direct
    handler invocation)."""
    from app.core.compliance_models import AiSuggestion
    from app.phase1.models.platform_models import SessionLocal

    sid = uuid.uuid4().hex
    db = SessionLocal()
    try:
        row = AiSuggestion(
            id=sid,
            tenant_id="t-test-1",
            source="test",
            action_type=action_type,
            target_type="invoice",
            target_id=f"INV-{sid[:6]}",
            after_json=after_json or {},
            confidence=900,  # permille
            destructive=0,
            reasoning="test fixture",
            status=status,
            approved_by="user-1",
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        # Detach so the handler can read attributes after the session closes.
        db.expunge(row)
    finally:
        db.close()
    return row


# ══════════════════════════════════════════════════════════════
# Zone 2a: _execute_create_invoice
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def zatca_stubs(monkeypatch):
    """Stub ZATCA service + signer + retry_queue."""
    # The real module exists but its build call is what we want to control.
    import app.core.zatca_service as zs

    def fake_build(*, seller, lines, client_id, fiscal_year, currency):
        return SimpleNamespace(
            uuid=f"uuid-{uuid.uuid4().hex[:8]}",
            invoice_number=f"SI-{uuid.uuid4().hex[:6]}",
            invoice_hash_b64="hash-b64",
            icv=1,
            totals={"net": 100.0, "tax": 15.0, "gross": 115.0},
        )

    monkeypatch.setattr(zs, "build_simplified_invoice", fake_build)

    # Signer + retry_queue: install sys.modules stubs.
    signer = types.ModuleType("app.integrations.zatca.signer")
    signer.sign_invoice = lambda result, *, tenant_id: SimpleNamespace(
        signed_xml="<xml>signed</xml>"
    )
    monkeypatch.setitem(sys.modules, "app.integrations.zatca.signer", signer)

    rq = types.ModuleType("app.integrations.zatca.retry_queue")
    rq.enqueue_submission = lambda **kw: f"sub-{uuid.uuid4().hex[:6]}"
    monkeypatch.setitem(sys.modules, "app.integrations.zatca.retry_queue", rq)

    return SimpleNamespace(zs=zs, signer=signer, rq=rq)


class TestExecuteCreateInvoice:
    def test_subtotal_zero_or_negative_fails(self):
        from app.ai.approval_executor import _execute_create_invoice

        row = _make_suggestion(
            action_type="create_invoice",
            after_json={"client_name": "X", "subtotal": 0},
        )
        result = _execute_create_invoice(row)
        assert result.ok is False
        assert "subtotal" in result.detail

    def test_happy_path_with_signing_and_queue(self, zatca_stubs):
        from app.ai.approval_executor import _execute_create_invoice

        row = _make_suggestion(
            action_type="create_invoice",
            after_json={
                "client_name": "Acme Co",
                "description": "Service A",
                "subtotal": 200,
                "vat_rate": 15,
                "currency": "SAR",
            },
        )
        result = _execute_create_invoice(row)
        assert result.ok is True
        assert "built" in result.detail
        assert result.output["invoice_number"].startswith("SI-")
        assert result.output["submission_id"] is not None

    def test_zatca_value_error_is_caught(self, monkeypatch):
        """ZATCA build raising ValueError → friendly Arabic detail."""
        import app.core.zatca_service as zs

        def boom(**kw):
            raise ValueError("invalid VAT format")

        monkeypatch.setattr(zs, "build_simplified_invoice", boom)
        from app.ai.approval_executor import _execute_create_invoice

        row = _make_suggestion(
            action_type="create_invoice",
            after_json={"client_name": "X", "subtotal": 100},
        )
        result = _execute_create_invoice(row)
        assert result.ok is False
        assert "ZATCA build rejected" in result.detail

    def test_zatca_generic_exception_is_caught(self, monkeypatch):
        import app.core.zatca_service as zs

        def boom(**kw):
            raise RuntimeError("upstream broken")

        monkeypatch.setattr(zs, "build_simplified_invoice", boom)
        from app.ai.approval_executor import _execute_create_invoice

        row = _make_suggestion(
            action_type="create_invoice",
            after_json={"client_name": "X", "subtotal": 100},
        )
        result = _execute_create_invoice(row)
        assert result.ok is False
        assert "ZATCA build error" in result.detail

    def test_signing_cert_missing_still_succeeds(self, monkeypatch):
        """When signer/retry_queue raise (cert not configured in dev),
        the result still succeeds — invoice was built."""
        import app.core.zatca_service as zs

        def fake_build(**kw):
            return SimpleNamespace(
                uuid="uuid-1", invoice_number="SI-001",
                invoice_hash_b64="h", icv=1, totals={},
            )

        monkeypatch.setattr(zs, "build_simplified_invoice", fake_build)

        # signer raises ImportError-equivalent inside its module.
        signer = types.ModuleType("app.integrations.zatca.signer")

        def bad_sign(*a, **kw):
            raise RuntimeError("cert not configured")

        signer.sign_invoice = bad_sign
        monkeypatch.setitem(sys.modules, "app.integrations.zatca.signer", signer)

        from app.ai.approval_executor import _execute_create_invoice

        row = _make_suggestion(
            action_type="create_invoice",
            after_json={"client_name": "X", "subtotal": 100},
        )
        result = _execute_create_invoice(row)
        assert result.ok is True
        assert "queued skipped" in result.detail
        assert result.output["submission_id"] is None


# ══════════════════════════════════════════════════════════════
# Zone 2b: _execute_send_reminder
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def whatsapp_stub(monkeypatch):
    """Stub WhatsApp client."""
    stub = types.ModuleType("app.integrations.whatsapp.client")
    state = {"success": True, "backend": "stub", "message_id": "wa-msg-1"}

    def send(**kwargs):
        return SimpleNamespace(
            success=state["success"],
            backend=state["backend"],
            message_id=state["message_id"],
            error=state.get("error"),
        )

    stub.send_template_message = send
    stub._state = state
    monkeypatch.setitem(sys.modules, "app.integrations.whatsapp.client", stub)
    return stub


@pytest.fixture
def notify_stub(monkeypatch):
    """Stub notifications_bridge.notify (async) — capture invocations."""
    captured = {"calls": []}

    async def fake_notify(**kwargs):
        captured["calls"].append(kwargs)
        return {"persisted": True, "websocket_delivered": 1}

    stub = types.ModuleType("app.core.notifications_bridge")
    stub.notify = fake_notify
    monkeypatch.setitem(sys.modules, "app.core.notifications_bridge", stub)
    return captured


class TestExecuteSendReminder:
    def test_missing_invoice_id_and_client_name_fails(self, notify_stub):
        from app.ai.approval_executor import _execute_send_reminder

        row = _make_suggestion(
            action_type="send_reminder", after_json={},
        )
        result = _execute_send_reminder(row)
        assert result.ok is False
        assert "neither invoice_id nor client_name" in result.detail

    def test_default_channel_via_notification(self, notify_stub):
        """Channel defaults to 'auto' → uses notifications_bridge (no WhatsApp)."""
        from app.ai.approval_executor import _execute_send_reminder

        row = _make_suggestion(
            action_type="send_reminder",
            after_json={"invoice_id": "INV-1", "client_name": "Acme"},
        )
        result = _execute_send_reminder(row)
        assert result.ok is True
        assert "notification dispatched" in result.detail
        assert len(notify_stub["calls"]) == 1
        assert notify_stub["calls"][0]["kind"] == "ai_reminder"
        assert notify_stub["calls"][0]["entity_id"] == "INV-1"

    def test_whatsapp_channel_happy_path(self, whatsapp_stub, notify_stub):
        from app.ai.approval_executor import _execute_send_reminder

        row = _make_suggestion(
            action_type="send_reminder",
            after_json={
                "invoice_id": "INV-2", "client_name": "Bob",
                "channel": "whatsapp", "phone": "+966501234567",
            },
        )
        result = _execute_send_reminder(row)
        assert result.ok is True
        assert "WhatsApp" in result.detail
        # WhatsApp succeeded → notification NOT called as fallback.
        assert len(notify_stub["calls"]) == 0

    def test_whatsapp_failure_falls_back_to_notification(
        self, whatsapp_stub, notify_stub
    ):
        whatsapp_stub._state["success"] = False
        whatsapp_stub._state["error"] = "rate limited"
        from app.ai.approval_executor import _execute_send_reminder

        row = _make_suggestion(
            action_type="send_reminder",
            after_json={
                "invoice_id": "INV-3", "client_name": "C",
                "channel": "whatsapp", "phone": "+966500000000",
            },
        )
        result = _execute_send_reminder(row)
        # Fell through to notification path → result is the notification
        # dispatch outcome.
        assert result.ok is True
        assert len(notify_stub["calls"]) == 1

    def test_notification_dispatch_failure_marks_failed(self, monkeypatch):
        from app.ai.approval_executor import _execute_send_reminder

        async def boom(**kw):
            raise RuntimeError("hub offline")

        stub = types.ModuleType("app.core.notifications_bridge")
        stub.notify = boom
        monkeypatch.setitem(sys.modules, "app.core.notifications_bridge", stub)

        row = _make_suggestion(
            action_type="send_reminder",
            after_json={"invoice_id": "INV-4", "client_name": "X"},
        )
        result = _execute_send_reminder(row)
        assert result.ok is False
        assert "RuntimeError" in result.detail

    @pytest.mark.parametrize("tone,expected_substr", [
        ("gentle", "ودّي"),
        ("firm", "متأخرة"),
        ("final_notice", "نهائي"),
        ("unknown_tone", "ودّي"),  # falls back to gentle
    ])
    def test_tone_variants_render_correct_body(
        self, notify_stub, tone, expected_substr
    ):
        from app.ai.approval_executor import _execute_send_reminder

        row = _make_suggestion(
            action_type="send_reminder",
            after_json={
                "invoice_id": "INV-T", "client_name": "X", "tone": tone,
            },
        )
        result = _execute_send_reminder(row)
        assert result.ok is True
        assert expected_substr in notify_stub["calls"][-1]["body"]

    def test_whatsapp_exception_falls_back_to_notification(
        self, monkeypatch, notify_stub
    ):
        """WhatsApp client raising → caught + falls back to notify."""
        stub = types.ModuleType("app.integrations.whatsapp.client")

        def boom(**kw):
            raise RuntimeError("whatsapp api 500")

        stub.send_template_message = boom
        monkeypatch.setitem(
            sys.modules, "app.integrations.whatsapp.client", stub
        )

        from app.ai.approval_executor import _execute_send_reminder

        row = _make_suggestion(
            action_type="send_reminder",
            after_json={
                "invoice_id": "INV-5", "client_name": "Y",
                "channel": "whatsapp", "phone": "+966500000000",
            },
        )
        result = _execute_send_reminder(row)
        assert result.ok is True  # fallback succeeded
        assert len(notify_stub["calls"]) == 1


# ══════════════════════════════════════════════════════════════
# Zone 2c: _execute_ap_approval
# ══════════════════════════════════════════════════════════════


class TestExecuteApApproval:
    def test_bridge_returns_ok_true(self, monkeypatch):
        stub = types.ModuleType("app.features.ap_agent.suggestion_bridge")
        stub.on_suggestion_approved = lambda sid: {
            "ok": True, "ap_invoice_id": "AP-100",
        }
        monkeypatch.setitem(
            sys.modules, "app.features.ap_agent.suggestion_bridge", stub
        )

        from app.ai.approval_executor import _execute_ap_approval

        row = _make_suggestion(action_type="ap_invoice_approval")
        result = _execute_ap_approval(row)
        assert result.ok is True
        assert "AP-100" in result.detail
        assert result.output["ap_invoice_id"] == "AP-100"

    def test_bridge_returns_ok_false(self, monkeypatch):
        stub = types.ModuleType("app.features.ap_agent.suggestion_bridge")
        stub.on_suggestion_approved = lambda sid: {
            "ok": False, "detail": "missing AP row",
        }
        monkeypatch.setitem(
            sys.modules, "app.features.ap_agent.suggestion_bridge", stub
        )

        from app.ai.approval_executor import _execute_ap_approval

        row = _make_suggestion(action_type="ap_invoice_approval")
        result = _execute_ap_approval(row)
        assert result.ok is False
        assert "missing AP row" in result.detail

    def test_bridge_raises(self, monkeypatch):
        stub = types.ModuleType("app.features.ap_agent.suggestion_bridge")

        def boom(sid):
            raise RuntimeError("schema drift")

        stub.on_suggestion_approved = boom
        monkeypatch.setitem(
            sys.modules, "app.features.ap_agent.suggestion_bridge", stub
        )

        from app.ai.approval_executor import _execute_ap_approval

        row = _make_suggestion(action_type="ap_invoice_approval")
        result = _execute_ap_approval(row)
        assert result.ok is False
        assert "RuntimeError" in result.detail
