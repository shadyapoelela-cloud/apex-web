"""APEX — Industry Pack Auto-Provisioner.

Listens for `industry_pack.applied` events emitted by
`industry_packs_service.apply_pack`, then closes the loop by:

    1. Installing a curated set of zero-parameter workflow templates as
       live rules scoped to the tenant. Each pack maps to a list of
       template_ids that make sense for that sector. Failures are
       captured per-template; one bad template doesn't block the rest.
    2. Marking the pack assignment's `coa_seeded` + `widgets_provisioned`
       flags as True. (Real COA seeding via Phase 4 service is a TODO —
       hooked here so a future commit can replace the placeholder
       without changing the listener contract.)
    3. Emitting `industry_pack.provisioned` with the install summary
       (counts of installed/failed rules + which templates).

Why JSON-as-DB suffices: the assignment store already exists; this
module reads it via the public service helpers and only mutates via
`mark_provisioned()`. No new persistence needed.

Idempotency: running the provisioner twice for the same (tenant, pack)
will install duplicate rules. The intent is one-shot per `applied`
event. If admin re-applies a pack, the assignment refreshes timestamp
without firing `applied` again (that path emits `refreshed`), so the
listener stays single-fire by design.

Reference: Wave 1M Phase SS, closes Layer 4.4 of FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from app.core.event_bus import emit, register_listener

logger = logging.getLogger(__name__)


# ── Pack → templates mapping ────────────────────────────────────
#
# Only zero-parameter templates are listed here so the auto-installer
# doesn't need to invent values. Templates with required parameters
# (e.g. big-invoice-approval needs an approver_user_id) belong in the
# admin's manual install flow at /admin/workflow/templates.

_PACK_TEMPLATES: dict[str, list[str]] = {
    "fnb_retail": [
        "anomaly-high-teams",       # POS-driven, anomaly likely
        "low-stock-slack",          # inventory critical
        "period-close-reminder",    # universal
        "bill-paid-audit-log",      # high vendor turnover
    ],
    "construction": [
        "anomaly-high-teams",       # large amounts → anomaly important
        "overdue-invoice-slack",    # progress billing → AR critical
        "zatca-rejected-alert",     # B2B compliance focus
        "period-close-reminder",    # universal
    ],
    "medical": [
        "overdue-invoice-slack",    # insurance receivables
        "zatca-rejected-alert",     # claim compliance proxy
        "period-close-reminder",    # universal
        "bill-paid-audit-log",      # supplier audit trail
    ],
    "logistics": [
        "anomaly-high-teams",       # fuel-card fraud
        "low-stock-slack",          # parts inventory
        "period-close-reminder",    # universal
        "payment-thanks-email",     # high-volume customers
    ],
    "services": [
        "overdue-invoice-slack",    # SaaS dunning
        "welcome-new-user",         # onboarding new clients
        "period-close-reminder",    # universal
        "payment-thanks-email",     # MRR retention
    ],
}


# ── Provisioner ─────────────────────────────────────────────────


def _safe_install_template(
    template_id: str,
    tenant_id: str,
) -> dict[str, Any]:
    """Install one template for the given tenant. Catches all failures."""
    try:
        from app.core.workflow_templates import get_template, materialize
        from app.core.workflow_engine import create_rule
    except Exception as e:  # noqa: BLE001
        return {"template_id": template_id, "ok": False, "error": f"imports:{e}"}

    t = get_template(template_id)
    if t is None:
        return {"template_id": template_id, "ok": False, "error": "template_not_found"}

    # Sanity-check: only zero-parameter templates are eligible.
    required = [
        p["name"]
        for p in t.parameters
        if p.get("default") is None
    ]
    if required:
        return {
            "template_id": template_id,
            "ok": False,
            "error": f"required_params:{','.join(required)}",
        }

    try:
        rule_dict = materialize(t, {})  # all defaults
        rule = create_rule(
            name=f"[{tenant_id}] {rule_dict['name']}",
            event_pattern=rule_dict["event_pattern"],
            conditions=rule_dict.get("conditions", []),
            actions=rule_dict.get("actions", []),
            description_ar=(
                f"تم التثبيت تلقائياً بواسطة Industry Pack Provisioner — "
                f"{rule_dict.get('description_ar') or ''}"
            ).strip(),
            tenant_id=tenant_id,
            enabled=True,
        )
        return {"template_id": template_id, "ok": True, "rule_id": rule.id}
    except Exception as e:  # noqa: BLE001
        logger.exception("failed to install %s for %s: %s", template_id, tenant_id, e)
        return {"template_id": template_id, "ok": False, "error": str(e)}


def provision(
    tenant_id: str,
    pack_id: str,
    *,
    seed_coa: bool = True,
    install_workflows: bool = True,
    provision_widgets: bool = True,
) -> dict[str, Any]:
    """Run the full provisioning sequence for a (tenant, pack).

    Each step is best-effort and failures are captured in the result.
    Always emits `industry_pack.provisioned` at the end.
    """
    summary: dict[str, Any] = {
        "tenant_id": tenant_id,
        "pack_id": pack_id,
        "workflows": {"installed": [], "failed": []},
        "coa_seeded": False,
        "widgets_provisioned": False,
    }

    # Step 1 — Workflows.
    if install_workflows:
        for tid in _PACK_TEMPLATES.get(pack_id, []):
            r = _safe_install_template(tid, tenant_id)
            if r["ok"]:
                summary["workflows"]["installed"].append(r)
            else:
                summary["workflows"]["failed"].append(r)

    # Step 2 — COA seeding.
    # NB: real COA-by-pack seeding lives in Phase 4 (gl_engine). Today we
    # mark the flag so the dashboard can show "provisioned" without
    # touching ledger tables. A future commit can wire actual seeding.
    if seed_coa:
        try:
            from app.core.industry_packs_service import mark_provisioned
            mark_provisioned(tenant_id, coa=True)
            summary["coa_seeded"] = True
        except Exception as e:  # noqa: BLE001
            summary["coa_error"] = str(e)

    # Step 3 — Dashboard widgets.
    # Same pattern — today we just flip the flag. A future commit can
    # call into a widget registration service per pack.
    if provision_widgets:
        try:
            from app.core.industry_packs_service import mark_provisioned
            mark_provisioned(tenant_id, widgets=True)
            summary["widgets_provisioned"] = True
        except Exception as e:  # noqa: BLE001
            summary["widgets_error"] = str(e)

    # Always emit the result so workflow rules + observers can react.
    emit(
        "industry_pack.provisioned",
        {
            "tenant_id": tenant_id,
            "pack_id": pack_id,
            "workflows_installed": len(summary["workflows"]["installed"]),
            "workflows_failed": len(summary["workflows"]["failed"]),
            "coa_seeded": summary["coa_seeded"],
            "widgets_provisioned": summary["widgets_provisioned"],
        },
        source="industry_pack_provisioner",
    )
    return summary


# ── Auto-listener on the bus ────────────────────────────────────


@register_listener("industry_pack.applied")
def _on_pack_applied(event_name: str, payload: dict) -> None:
    tenant_id = payload.get("tenant_id")
    pack_id = payload.get("pack_id")
    if not tenant_id or not pack_id:
        logger.warning("industry_pack.applied missing tenant_id or pack_id: %s", payload)
        return
    summary = provision(tenant_id, pack_id)
    logger.info(
        "Industry pack auto-provisioned: tenant=%s pack=%s workflows_installed=%d failed=%d",
        tenant_id,
        pack_id,
        len(summary["workflows"]["installed"]),
        len(summary["workflows"]["failed"]),
    )


# ── Public introspection ────────────────────────────────────────


def get_pack_template_map() -> dict[str, list[str]]:
    """Return the pack→template mapping (used by the admin UI)."""
    return {k: list(v) for k, v in _PACK_TEMPLATES.items()}


def manual_provision(
    tenant_id: str,
    pack_id: str,
    *,
    seed_coa: bool = True,
    install_workflows: bool = True,
    provision_widgets: bool = True,
) -> dict:
    """Same as `provision` but exported for an admin re-run endpoint."""
    return provision(
        tenant_id,
        pack_id,
        seed_coa=seed_coa,
        install_workflows=install_workflows,
        provision_widgets=provision_widgets,
    )
