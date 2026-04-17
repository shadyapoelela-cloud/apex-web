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
]


# ── Tool implementations (server-side) ─────────────────────


def _impl_query_financial_data(args: dict) -> dict:
    """Scaffold — real impl runs a SQL query against the ledger.

    For now returns a deterministic placeholder so the agent flow can be
    tested end-to-end without a loaded dataset.
    """
    metric = args.get("metric")
    period = args.get("period")
    dimension = args.get("dimension")
    # A real implementation would:
    #   • parse 'period' → (start, end)
    #   • run SELECT SUM(amount) FROM journal_entries WHERE ...
    #   • apply tenant_guard.current_tenant() automatically
    return {
        "metric": metric,
        "period": period,
        "dimension": dimension,
        "value": 0,
        "currency": "SAR",
        "breakdown": [],
        "_note": "placeholder — wire to journal_entries aggregation when ready",
    }


def _impl_get_report(args: dict) -> dict:
    return {
        "report_type": args["report_type"],
        "period": args["period"],
        "currency": args.get("currency", "SAR"),
        "sections": [],
        "_note": "placeholder — wire to app.core.fin_statements_service",
    }


def _impl_explain_variance(args: dict) -> dict:
    return {
        "account": args["account"],
        "period_a": args["period_a"],
        "period_b": args["period_b"],
        "delta": 0,
        "drivers": [],
        "_note": "placeholder — wire to variance engine",
    }


def _impl_forecast(args: dict) -> dict:
    return {
        "metric": args["metric"],
        "horizon_months": args["horizon_months"],
        "projected_values": [],
        "confidence_interval": {"low": [], "high": []},
        "_note": "placeholder — wire to cashflow forecasting",
    }


def _impl_lookup_entity(args: dict) -> dict:
    return {
        "entity_type": args["entity_type"],
        "query": args["query"],
        "matches": [],
        "_note": "placeholder — wire to entity index",
    }


TOOL_IMPLS: dict[str, Callable[[dict], dict]] = {
    "query_financial_data": _impl_query_financial_data,
    "get_report": _impl_get_report,
    "explain_variance": _impl_explain_variance,
    "forecast": _impl_forecast,
    "lookup_entity": _impl_lookup_entity,
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

    for turn in range(max_turns):
        try:
            resp = client.messages.create(
                model=model,
                max_tokens=2048,
                system=system_prompt,
                tools=TOOL_DEFINITIONS,
                messages=messages,
            )
        except Exception as e:
            return AgentResult(
                success=False,
                answer="",
                error=f"Claude API call failed: {e}",
                tool_calls=tool_calls_log,
                model=model,
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
