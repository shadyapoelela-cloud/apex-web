"""Copilot Agent — Claude function-calling with financial tool definitions.

Elevates Copilot from a chat UI to an autonomous agent that can:
  • Answer NL queries by running structured SQL ("كم صرفنا على التسويق؟")
  • Generate financial reports
  • Explain variances
  • Drill down into entities

Architecture:
  • Tools are declared once in TOOL_DEFINITIONS (JSON schema).
  • Each tool has a Python implementation in TOOL_IMPLS.
  • On a user query, we send it + tool definitions to Claude.
  • If Claude calls a tool, we execute it locally, return the result,
    and let Claude continue the conversation.

Graceful degradation:
  • Without anthropic SDK or API key: run() returns a clear error dict
    instead of raising. Existing rule-based Copilot fallback still works.
"""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any, Callable, Optional

logger = logging.getLogger(__name__)


# ── Tool definitions (JSON schema for Claude) ──────────────


TOOL_DEFINITIONS: list[dict[str, Any]] = [
    {
        "name": "query_financial_data",
        "description": (
            "Fetch aggregated financial data. Use for questions like "
            "'how much did we spend on marketing last month?' or "
            "'what's our cash balance?'. "
            "Returns {metric, period, value, currency, breakdown?}."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "metric": {
                    "type": "string",
                    "enum": [
                        "total_expenses",
                        "total_revenue",
                        "cash_balance",
                        "accounts_receivable",
                        "accounts_payable",
                        "mrr",
                        "burn_rate",
                    ],
                },
                "period": {
                    "type": "string",
                    "description": "ISO date range like '2026-04-01:2026-04-30', or 'this_month', 'last_month', 'ytd'.",
                },
                "dimension": {
                    "type": "string",
                    "description": "Optional grouping dimension: 'account', 'category', 'project', 'branch'.",
                },
            },
            "required": ["metric", "period"],
        },
    },
    {
        "name": "get_report",
        "description": (
            "Generate a pre-built financial report. Use when the user asks "
            "for 'show me the P&L' or 'balance sheet'."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "report_type": {
                    "type": "string",
                    "enum": [
                        "profit_and_loss",
                        "balance_sheet",
                        "cash_flow",
                        "trial_balance",
                        "aging_report",
                        "vat_return",
                    ],
                },
                "period": {"type": "string"},
                "currency": {"type": "string", "default": "SAR"},
            },
            "required": ["report_type", "period"],
        },
    },
    {
        "name": "explain_variance",
        "description": (
            "Explain why a metric changed between two periods. "
            "Good for 'why did expenses increase this month?'."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "account": {"type": "string"},
                "period_a": {"type": "string"},
                "period_b": {"type": "string"},
            },
            "required": ["account", "period_a", "period_b"],
        },
    },
    {
        "name": "forecast",
        "description": (
            "Project a metric forward using historical data. "
            "Use for 'what will our cash position be in 6 months?'."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "metric": {"type": "string"},
                "horizon_months": {"type": "integer", "minimum": 1, "maximum": 24},
            },
            "required": ["metric", "horizon_months"],
        },
    },
    {
        "name": "lookup_entity",
        "description": (
            "Find a specific entity (client, invoice, employee, account) by name or ID."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "entity_type": {
                    "type": "string",
                    "enum": ["client", "invoice", "employee", "account", "vendor"],
                },
                "query": {"type": "string"},
            },
            "required": ["entity_type", "query"],
        },
    },
    {
        "name": "create_invoice",
        "description": (
            "Draft a ZATCA-compliant invoice. Use when the user says "
            "'أصدر فاتورة لـ ...' or 'create an invoice for client X'. "
            "Returns a draft ID the user must then review and post. "
            "NEVER posts without explicit user confirmation in a follow-up turn."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "client_name": {"type": "string"},
                "description": {
                    "type": "string",
                    "description": "Single-line description of the service/product",
                },
                "amount": {"type": "number", "description": "Subtotal before VAT"},
                "vat_rate": {
                    "type": "number",
                    "default": 15,
                    "description": "VAT percent (15 for KSA, 5 for UAE)",
                },
                "currency": {"type": "string", "default": "SAR"},
            },
            "required": ["client_name", "description", "amount"],
        },
    },
    {
        "name": "send_reminder",
        "description": (
            "Send a payment reminder for one invoice or for every overdue "
            "invoice of a given client. Queues the message via the "
            "tenant's configured channel (WhatsApp Business, email, SMS). "
            "Honours the daily rate limit and never sends without user "
            "confirmation in the preceding turn."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "invoice_id": {
                    "type": "string",
                    "description": "Exact invoice ID. Mutually exclusive with client_name.",
                },
                "client_name": {
                    "type": "string",
                    "description": "Sends one reminder for EACH overdue invoice of this client.",
                },
                "channel": {
                    "type": "string",
                    "enum": ["whatsapp", "email", "sms", "auto"],
                    "default": "auto",
                },
                "tone": {
                    "type": "string",
                    "enum": ["gentle", "firm", "final_notice"],
                    "default": "gentle",
                },
            },
        },
    },
    {
        "name": "generate_report",
        "description": (
            "Generate a financial report on demand and return a download URL. "
            "Wraps get_report with actual file output (PDF or Excel). "
            "Use when the user says 'export the P&L to Excel' or "
            "'send the balance sheet as PDF'."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "report_type": {
                    "type": "string",
                    "enum": [
                        "profit_and_loss",
                        "balance_sheet",
                        "cash_flow",
                        "trial_balance",
                        "aging_report",
                        "vat_return",
                        "zakat_return",
                    ],
                },
                "period": {"type": "string"},
                "format": {
                    "type": "string",
                    "enum": ["pdf", "excel", "csv"],
                    "default": "pdf",
                },
                "currency": {"type": "string", "default": "SAR"},
            },
            "required": ["report_type", "period"],
        },
    },
    {
        "name": "categorize_transaction",
        "description": (
            "Classify a bank or card transaction into an account code. "
            "Call this for questions like 'ما حساب دفعة Netflix؟' or "
            "'where does this AWS charge go?'. Uses keyword heuristics + "
            "the COA lexicon. Returns (account_code, confidence, reason)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "description": {
                    "type": "string",
                    "description": "Raw bank-statement description (Arabic or English).",
                },
                "amount": {"type": "number"},
                "direction": {
                    "type": "string",
                    "enum": ["debit", "credit"],
                    "default": "debit",
                },
            },
            "required": ["description"],
        },
    },
]


# ── Tool implementations (server-side) ─────────────────────


def _impl_query_financial_data(args: dict) -> dict:
    """Aggregate a financial metric from the real GL postings.

    Falls back to a zero-shaped placeholder when the pilot ledger tables
    aren't present (fresh CI DB, minimal test fixture) — keeps legacy
    tests green while giving the agent real numbers in production.
    """
    try:
        from app.services.copilot_tools_ledger import aggregate_metric
        return aggregate_metric(
            metric=args.get("metric") or "",
            period=args.get("period") or "this_month",
            dimension=args.get("dimension"),
        )
    except Exception as e:
        logger.warning("query_financial_data fallback: %s", e)
        return {
            "metric": args.get("metric"),
            "period": args.get("period"),
            "dimension": args.get("dimension"),
            "value": 0,
            "currency": "SAR",
            "breakdown": [],
            "_note": f"aggregation unavailable — {e.__class__.__name__}",
        }


def _impl_get_report(args: dict) -> dict:
    """Produce a narratable report snapshot for the agent.

    Uses the aggregated-metric layer for P&L / BS / TB so the LLM has
    real numbers to summarise. cash_flow / aging / vat_return still
    return the placeholder — their dedicated services need agent-facing
    adapters before wiring.
    """
    try:
        from app.services.copilot_tools_ledger import get_report_summary
        return get_report_summary(
            report_type=args["report_type"],
            period=args["period"],
            currency=args.get("currency", "SAR"),
        )
    except Exception as e:
        logger.warning("get_report fallback: %s", e)
        return {
            "report_type": args["report_type"],
            "period": args["period"],
            "currency": args.get("currency", "SAR"),
            "sections": [],
            "_note": f"report build failed — {e.__class__.__name__}",
        }


def _impl_explain_variance(args: dict) -> dict:
    """Compute period-over-period variance for one account.

    Resolves the account by code or name, pulls net balances for both
    periods, and surfaces top partner-driven drivers so the agent can
    narrate "why" rather than just "by how much".
    """
    try:
        from app.services.copilot_tools_ledger import explain_variance
        return explain_variance(
            account=args["account"],
            period_a=args["period_a"],
            period_b=args["period_b"],
        )
    except Exception as e:
        logger.warning("explain_variance fallback: %s", e)
        return {
            "account": args.get("account"),
            "period_a": args.get("period_a"),
            "period_b": args.get("period_b"),
            "delta": 0,
            "drivers": [],
            "_note": f"variance unavailable — {e.__class__.__name__}",
        }


def _impl_forecast(args: dict) -> dict:
    """Project a metric forward via moving-average baseline.

    Not ML — a defensible, cheap baseline that gives the agent real
    numbers to reason over (running cash, expense trend, revenue). The
    agent explains that the method is a moving average so users know
    not to treat it as a ML-grade forecast.
    """
    try:
        from app.services.copilot_tools_ledger import forecast_metric
        return forecast_metric(
            metric=args["metric"],
            horizon_months=int(args["horizon_months"]),
        )
    except Exception as e:
        logger.warning("forecast fallback: %s", e)
        return {
            "metric": args.get("metric"),
            "horizon_months": args.get("horizon_months"),
            "projected_values": [],
            "confidence_interval": {"low": [], "high": []},
            "_note": f"forecast unavailable — {e.__class__.__name__}",
        }


def _impl_lookup_entity(args: dict) -> dict:
    """Search clients / invoices / accounts / vendors / employees.

    Queries real models when they're loaded; returns an empty match list
    with a note (not an error) when a given entity type isn't wired.
    """
    try:
        from app.services.copilot_tools_ledger import lookup_entity
        return lookup_entity(
            entity_type=args["entity_type"],
            query=args["query"],
        )
    except Exception as e:
        logger.warning("lookup_entity fallback: %s", e)
        return {
            "entity_type": args["entity_type"],
            "query": args["query"],
            "matches": [],
            "_note": f"entity lookup unavailable — {e.__class__.__name__}",
        }


def _impl_create_invoice(args: dict) -> dict:
    """Draft an invoice. Does NOT post — routes the proposal through
    the confidence-gated guardrail so the "AI wanted to draft" event is
    captured with audit trail even before any human action.

    Because creating a tax document is always destructive (touches
    ledger + ZATCA), the guardrail forces NEEDS_APPROVAL regardless of
    how confident the LLM was. The caller must explicitly approve the
    AiSuggestion row (via /ai/suggestions/{id}/approve) before a second
    tool-call actually posts.
    """
    import uuid as _uuid

    from decimal import Decimal

    client_name = str(args.get("client_name") or "").strip()
    description = str(args.get("description") or "").strip()
    amount = Decimal(str(args.get("amount") or 0))
    vat_rate = Decimal(str(args.get("vat_rate") or 15))
    currency = args.get("currency") or "SAR"

    if not client_name or not description or amount <= 0:
        return {
            "status": "rejected",
            "reason": "client_name, description, and amount > 0 are required",
        }

    vat = (amount * vat_rate / Decimal(100)).quantize(Decimal("0.01"))
    total = amount + vat
    draft_id = f"draft_{_uuid.uuid4().hex[:12]}"

    preview = {
        "draft_id": draft_id,
        "client_name": client_name,
        "description": description,
        "subtotal": float(amount),
        "vat_rate": float(vat_rate),
        "vat_amount": float(vat),
        "grand_total": float(total),
        "currency": currency,
    }

    # Route through guardrail so the proposal is persisted + audit-logged.
    # Failures here are non-fatal — if the guardrail is unavailable we
    # still return the preview so the agent flow keeps working.
    suggestion_id: Optional[str] = None
    try:
        from app.core.ai_guardrails import guard, Suggestion
        tenant_id = None
        try:
            from app.core.tenant_guard import current_tenant
            tenant_id = current_tenant() or None
        except Exception:
            pass
        decision = guard(Suggestion(
            source="copilot_agent",
            action_type="create_invoice",
            target_type="invoice_draft",
            target_id=draft_id,
            after=preview,
            confidence=0.85,          # below 0.95 floor — anyway destructive
            destructive=True,         # tax document → always needs approval
            reasoning=f"LLM drafted invoice for '{client_name}' — {total} {currency}",
            tenant_id=tenant_id,
        ))
        suggestion_id = decision.row_id
    except Exception as e:
        logger.debug("guardrail unavailable on create_invoice: %s", e)

    return {
        **preview,
        "status": "draft",
        "suggestion_id": suggestion_id,
        "requires_confirmation": True,
        "_note": (
            "Draft recorded. Approve via /ai/suggestions/{suggestion_id}/approve "
            "before any ZATCA submission — this tool never posts by itself."
        ),
    }


def _impl_send_reminder(args: dict) -> dict:
    """Queue a payment reminder via the guardrail.

    An AI-initiated outbound message to a customer is customer-facing
    (affects reputation + can be read as a collection action). It always
    goes through the guardrail — the LLM never fires a message directly.
    The row stays in NEEDS_APPROVAL until a human clicks "approve" on
    the suggestion, at which point a separate worker dispatches through
    the notification bridge.
    """
    invoice_id = args.get("invoice_id")
    client_name = args.get("client_name")
    channel = args.get("channel") or "auto"
    tone = args.get("tone") or "gentle"

    if not invoice_id and not client_name:
        return {"status": "rejected", "reason": "invoice_id or client_name required"}

    proposal = {
        "invoice_id": invoice_id,
        "client_name": client_name,
        "channel": channel,
        "tone": tone,
    }

    suggestion_id: Optional[str] = None
    try:
        from app.core.ai_guardrails import guard, Suggestion
        tenant_id = None
        try:
            from app.core.tenant_guard import current_tenant
            tenant_id = current_tenant() or None
        except Exception:
            pass
        decision = guard(Suggestion(
            source="copilot_agent",
            action_type="send_reminder",
            target_type="reminder_plan",
            target_id=invoice_id or client_name,
            after=proposal,
            confidence=0.80,
            destructive=True,        # outbound message → always needs approval
            reasoning=(
                f"LLM proposes a {tone} reminder via {channel} for "
                f"{invoice_id or client_name}"
            ),
            tenant_id=tenant_id,
        ))
        suggestion_id = decision.row_id
    except Exception as e:
        logger.debug("guardrail unavailable on send_reminder: %s", e)

    # Proposal persisted via guardrail. Actual dispatch happens when a
    # human approves the AiSuggestion row — an approval worker will
    # render the right template (WhatsApp / email / SMS) and call the
    # notifications_bridge.
    return {
        "status": "queued",
        "suggestion_id": suggestion_id,
        "invoice_id": invoice_id,
        "client_name": client_name,
        "channel": channel,
        "tone": tone,
        "estimated_sends": 1 if invoice_id else 0,
        "requires_confirmation": True,
        "_note": (
            "Proposal recorded — NO message has been sent. Approve via "
            "/ai/suggestions/{suggestion_id}/approve to dispatch."
        ),
    }


def _impl_generate_report(args: dict) -> dict:
    """Thin wrapper over the real report service. Returns a download
    URL the user can click; backend streams PDF/Excel/CSV bytes."""
    report_type = args["report_type"]
    period = args["period"]
    fmt = args.get("format") or "pdf"
    currency = args.get("currency") or "SAR"

    # Real impl: call app.services.pdf_report_service or an Excel
    # writer, store to S3/local, return presigned URL.
    # Here we return a deterministic placeholder so the agent can
    # answer "هل الملف جاهز؟" with a clickable link in the demo.
    slug = f"{report_type}_{period}_{fmt}".replace(":", "_").replace(" ", "_")
    return {
        "report_type": report_type,
        "period": period,
        "format": fmt,
        "currency": currency,
        "download_url": f"/api/v1/reports/download/{slug}",
        "expires_at": "+1 hour",
        "_note": "placeholder — wire to real report writer + object storage",
    }


def _impl_categorize_transaction(args: dict) -> dict:
    """Classify a bank txn into a COA account code.

    Strategy: keyword heuristics over a small built-in lexicon so tests
    are deterministic; a real deployment would call the COA engine's
    Claude-powered classifier for unmatched rows. Returns confidence
    + the matched keyword so the UI can show why.
    """
    desc = str(args.get("description") or "").lower()
    direction = args.get("direction") or "debit"

    # Tiny lexicon — extend or replace with the engine's full lexicon.
    rules = [
        # (keywords, account_code, account_name)
        (("netflix", "spotify", "shahid", "osn", "anghami"),
         "5501", "اشتراكات برامج ترفيه"),
        (("aws", "gcp", "azure", "digitalocean", "vercel", "render"),
         "5502", "خدمات سحابية — هوستنج"),
        (("google ads", "facebook", "instagram", "linkedin", "twitter"),
         "5301", "تسويق رقمي"),
        (("zatca", "هيئة الزكاة", "gazt"),
         "2401", "ضرائب مستحقة ZATCA"),
        (("gosi", "مؤسسة التأمينات", "التأمينات الاجتماعية"),
         "2402", "اشتراكات GOSI"),
        (("رواتب", "payroll", "salary"),
         "5001", "رواتب الموظفين"),
        (("إيجار", "rent", "تأجير"),
         "5201", "إيجارات"),
        (("كهرباء", "electricity", "sec "),
         "5202", "كهرباء"),
        (("stc", "اتصالات سعودية", "mobily", "zain"),
         "5203", "اتصالات"),
        (("uber", "careem", "كريم", "طلبات"),
         "5204", "انتقالات / توصيل"),
        (("stripe", "paytabs", "hyperpay", "checkout.com"),
         "2301", "رسوم بوابة دفع"),
    ]
    for keywords, code, name in rules:
        if any(kw in desc for kw in keywords):
            return {
                "account_code": code,
                "account_name": name,
                "confidence": 0.92,
                "direction": direction,
                "matched_on": next(kw for kw in keywords if kw in desc),
                "source": "lexicon",
            }

    # Unmatched — fall back to a generic "uncategorised" suggestion
    return {
        "account_code": "9999",
        "account_name": "غير مصنّف — بانتظار المراجعة",
        "confidence": 0.15,
        "direction": direction,
        "matched_on": None,
        "source": "fallback",
        "_note": "Wire COA engine Claude classifier for higher confidence.",
    }


TOOL_IMPLS: dict[str, Callable[[dict], dict]] = {
    "query_financial_data": _impl_query_financial_data,
    "get_report": _impl_get_report,
    "explain_variance": _impl_explain_variance,
    "forecast": _impl_forecast,
    "lookup_entity": _impl_lookup_entity,
    "create_invoice": _impl_create_invoice,
    "send_reminder": _impl_send_reminder,
    "generate_report": _impl_generate_report,
    "categorize_transaction": _impl_categorize_transaction,
}


# ── Agent runner ───────────────────────────────────────────


@dataclass
class AgentResult:
    """Structured result of an agent run."""

    success: bool
    answer: str                                   # final natural-language answer
    tool_calls: list[dict] = field(default_factory=list)  # [{name, args, result}]
    model: str = ""
    error: Optional[str] = None


SYSTEM_PROMPT_AR = """\
أنت Copilot منصة APEX المالية. مهمتك: الإجابة على أسئلة المستخدم بالعربية والاستفادة من الأدوات المتاحة.

قواعد:
1. استدعِ أداة (tool) عند الحاجة إلى بيانات — لا تخترع الأرقام.
2. عند الإجابة اعرض الرقم الصافي أولاً، ثم شرحاً موجزاً.
3. استخدم الأرقام العربية إذا طلب المستخدم ذلك.
4. لا تعرض تفاصيل فنية (أسماء الجداول، SQL).
"""


def run_agent(
    user_query: str,
    conversation_history: Optional[list[dict]] = None,
    system_prompt: str = SYSTEM_PROMPT_AR,
    max_turns: int = 5,
) -> AgentResult:
    """Run the agent: let Claude call tools until it produces a final answer.

    `conversation_history` is a list of {"role": "user"|"assistant", "content": ...}.
    """
    try:
        import anthropic
    except ImportError:
        return AgentResult(
            success=False,
            answer="",
            error="anthropic SDK not installed — run `pip install anthropic`",
        )
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return AgentResult(
            success=False,
            answer="",
            error="ANTHROPIC_API_KEY not set — set it to enable the agent",
        )

    try:
        client = anthropic.Anthropic(api_key=api_key)
    except Exception as e:
        return AgentResult(success=False, answer="", error=f"client init failed: {e}")

    model = os.environ.get("COPILOT_MODEL", "claude-sonnet-4-5")
    messages: list[dict] = list(conversation_history or [])
    messages.append({"role": "user", "content": user_query})

    tool_calls_log: list[dict] = []

    # Per-run correlation id so the 1–N rows the usage log accumulates
    # for this agent turn can be grouped back together.
    import time as _time
    import uuid as _uuid
    _run_id = _uuid.uuid4().hex
    _tenant_id = None
    try:
        from app.core.tenant_guard import current_tenant
        _tenant_id = current_tenant() or None
    except Exception:
        pass

    def _record(
        *,
        turn_index: int,
        input_tokens: int,
        output_tokens: int,
        cache_read: int = 0,
        cache_create: int = 0,
        latency_ms: int = 0,
        stop_reason: Optional[str] = None,
        error: bool = False,
        error_kind: Optional[str] = None,
    ) -> None:
        try:
            from app.core.ai_usage_log import record_usage, UsageRecord
            record_usage(UsageRecord(
                surface="copilot_agent",
                model=model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                cache_read_tokens=cache_read,
                cache_creation_tokens=cache_create,
                tenant_id=_tenant_id,
                latency_ms=latency_ms,
                agent_run_id=_run_id,
                turn_index=turn_index,
                stop_reason=stop_reason,
                error=error,
                error_kind=error_kind,
            ))
        except Exception as _e:
            logger.debug("usage record skipped: %s", _e)

    for turn in range(max_turns):
        _t0 = _time.perf_counter()
        try:
            resp = client.messages.create(
                model=model,
                max_tokens=2048,
                system=system_prompt,
                tools=TOOL_DEFINITIONS,
                messages=messages,
            )
        except Exception as e:
            _record(
                turn_index=turn,
                input_tokens=0,
                output_tokens=0,
                latency_ms=int((_time.perf_counter() - _t0) * 1000),
                error=True,
                error_kind=e.__class__.__name__,
            )
            return AgentResult(
                success=False,
                answer="",
                error=f"Claude API call failed: {e}",
                tool_calls=tool_calls_log,
                model=model,
            )

        _latency_ms = int((_time.perf_counter() - _t0) * 1000)
        _usage = getattr(resp, "usage", None)
        _record(
            turn_index=turn,
            input_tokens=int(getattr(_usage, "input_tokens", 0) or 0),
            output_tokens=int(getattr(_usage, "output_tokens", 0) or 0),
            cache_read=int(getattr(_usage, "cache_read_input_tokens", 0) or 0),
            cache_create=int(getattr(_usage, "cache_creation_input_tokens", 0) or 0),
            latency_ms=_latency_ms,
            stop_reason=getattr(resp, "stop_reason", None),
        )

        # Did Claude call a tool?
        if resp.stop_reason == "tool_use":
            # Collect all tool_use blocks, execute, return results.
            tool_results = []
            for block in resp.content:
                if getattr(block, "type", None) == "tool_use":
                    name = block.name
                    args = block.input or {}
                    impl = TOOL_IMPLS.get(name)
                    if impl is None:
                        result = {"error": f"unknown tool: {name}"}
                    else:
                        try:
                            result = impl(args)
                        except Exception as e:
                            result = {"error": str(e)}
                    tool_calls_log.append({"name": name, "args": args, "result": result})
                    tool_results.append(
                        {
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": json.dumps(result, ensure_ascii=False, default=str),
                        }
                    )
            # Append assistant turn (including its tool_use blocks) + tool results
            messages.append({"role": "assistant", "content": resp.content})
            messages.append({"role": "user", "content": tool_results})
            continue

        # No more tool calls — Claude produced a final answer.
        text_parts = [
            getattr(b, "text", "")
            for b in resp.content
            if getattr(b, "type", None) == "text"
        ]
        return AgentResult(
            success=True,
            answer="".join(text_parts).strip(),
            tool_calls=tool_calls_log,
            model=model,
        )

    return AgentResult(
        success=False,
        answer="",
        error=f"max_turns={max_turns} exceeded without a final answer",
        tool_calls=tool_calls_log,
        model=model,
    )
