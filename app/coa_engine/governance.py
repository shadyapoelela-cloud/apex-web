"""
APEX COA Engine v4.3 — Rule Governance System
================================================
Propose, approve, deprecate rules + governance stats.
"""
from __future__ import annotations

import uuid
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════
# Rule lifecycle: draft → active → deprecated
# ═══════════════════════════════════════════════════════════════

VALID_STATUSES = {"draft", "active", "deprecated"}
VALID_TRANSITIONS = {
    "draft": {"active", "deprecated"},
    "active": {"deprecated"},
    "deprecated": set(),
}


def propose_rule(
    rule_name: str,
    description_ar: str = "",
    rule_type: str = "error_check",
    condition: Optional[Dict] = None,
    action: Optional[Dict] = None,
    severity: str = "Medium",
    proposed_by: str = "system",
) -> Dict[str, Any]:
    """Create a new rule proposal in draft status."""
    rule_id = f"R-{uuid.uuid4().hex[:8].upper()}"
    return {
        "rule_id": rule_id,
        "rule_name": rule_name,
        "description_ar": description_ar,
        "rule_type": rule_type,
        "condition": condition or {},
        "action": action or {},
        "severity": severity,
        "status": "draft",
        "version": 1,
        "proposed_by": proposed_by,
        "proposed_at": datetime.now(timezone.utc).isoformat(),
    }


def approve_rule(rule: Dict, approved_by: str = "admin") -> Dict[str, Any]:
    """Transition a draft rule to active."""
    current = rule.get("status", "draft")
    if current != "draft":
        return {"success": False, "error": f"لا يمكن اعتماد قاعدة بحالة '{current}' — يجب أن تكون draft"}

    return {
        "success": True,
        "rule_id": rule["rule_id"],
        "new_status": "active",
        "approved_by": approved_by,
    }


def deprecate_rule(rule: Dict, deprecated_by: str = "admin", reason: str = "") -> Dict[str, Any]:
    """Transition a rule to deprecated."""
    current = rule.get("status", "draft")
    if current not in ("draft", "active"):
        return {"success": False, "error": f"القاعدة بحالة '{current}' لا يمكن إيقافها"}

    return {
        "success": True,
        "rule_id": rule["rule_id"],
        "new_status": "deprecated",
        "deprecated_by": deprecated_by,
        "reason": reason,
    }


def get_active_rules(rules: List[Dict]) -> List[Dict]:
    """Filter only active rules."""
    return [r for r in rules if r.get("status") == "active"]


def get_governance_stats(rules: List[Dict]) -> Dict[str, Any]:
    """Compute governance statistics across all rules."""
    total = len(rules)
    by_status = {}
    by_type = {}
    by_severity = {}
    total_executions = 0
    weighted_success = 0.0

    for r in rules:
        st = r.get("status", "unknown")
        by_status[st] = by_status.get(st, 0) + 1

        rt = r.get("rule_type", "unknown")
        by_type[rt] = by_type.get(rt, 0) + 1

        sv = r.get("severity", "unknown")
        by_severity[sv] = by_severity.get(sv, 0) + 1

        ec = r.get("execution_count", 0) or 0
        sr = r.get("success_rate", 0.0) or 0.0
        total_executions += ec
        weighted_success += sr * ec

    avg_success = round(weighted_success / total_executions, 4) if total_executions > 0 else 0.0

    return {
        "total_rules": total,
        "by_status": by_status,
        "by_type": by_type,
        "by_severity": by_severity,
        "total_executions": total_executions,
        "average_success_rate": avg_success,
    }


# ═══════════════════════════════════════════════════════════════
# A/B Testing Framework
# ═══════════════════════════════════════════════════════════════

def run_ab_test(
    rule_a: Dict,
    rule_b: Dict,
    test_accounts: List[Dict],
    error_fn=None,
) -> Dict[str, Any]:
    """
    Compare two rules on the same test set.
    error_fn(accounts, rule) -> list of errors found.
    If error_fn is None, uses a dummy comparison.
    """
    results_a = []
    results_b = []

    if error_fn:
        results_a = error_fn(test_accounts, rule_a)
        results_b = error_fn(test_accounts, rule_b)
    else:
        # Dummy: compare rule severity as proxy
        severity_rank = {"Critical": 4, "High": 3, "Medium": 2, "Low": 1}
        results_a = [{"score": severity_rank.get(rule_a.get("severity", "Medium"), 2)}]
        results_b = [{"score": severity_rank.get(rule_b.get("severity", "Medium"), 2)}]

    errors_a = len(results_a)
    errors_b = len(results_b)

    winner = "A" if errors_a <= errors_b else "B"
    winning_rule = rule_a if winner == "A" else rule_b

    return {
        "rule_a": {"rule_id": rule_a.get("rule_id"), "errors_found": errors_a},
        "rule_b": {"rule_id": rule_b.get("rule_id"), "errors_found": errors_b},
        "winner": winner,
        "winning_rule_id": winning_rule.get("rule_id"),
        "recommendation": f"القاعدة {winner} أفضل — اكتشفت {'أقل' if winner == 'A' else 'أكثر'} أخطاء",
        "test_sample_size": len(test_accounts),
    }


def shadow_release(
    new_rule: Dict,
    baseline_rule: Dict,
    test_accounts: List[Dict],
    threshold: float = 0.9,
    error_fn=None,
) -> Dict[str, Any]:
    """
    Shadow-test a new rule against baseline.
    If new rule's error rate is within threshold of baseline, it's safe.
    """
    ab_result = run_ab_test(baseline_rule, new_rule, test_accounts, error_fn)

    baseline_errors = ab_result["rule_a"]["errors_found"]
    new_errors = ab_result["rule_b"]["errors_found"]

    if baseline_errors == 0:
        ratio = 1.0 if new_errors == 0 else 0.0
    else:
        ratio = round(1.0 - abs(new_errors - baseline_errors) / max(baseline_errors, 1), 4)

    safe = ratio >= threshold

    return {
        "baseline_rule_id": baseline_rule.get("rule_id"),
        "new_rule_id": new_rule.get("rule_id"),
        "baseline_errors": baseline_errors,
        "new_errors": new_errors,
        "similarity_ratio": ratio,
        "threshold": threshold,
        "safe_to_deploy": safe,
        "recommendation": "آمن للنشر" if safe else "يحتاج مراجعة — الانحراف عن الأساس كبير",
    }


# ═══════════════════════════════════════════════════════════════
# Auto-Rollback
# ═══════════════════════════════════════════════════════════════

def check_auto_rollback(
    rule: Dict,
    min_executions: int = 10,
    min_success_rate: float = 0.7,
) -> Dict[str, Any]:
    """
    Check if a rule should be auto-rolled-back based on its performance.
    """
    ec = rule.get("execution_count", 0) or 0
    sr = rule.get("success_rate", 0.0) or 0.0
    status = rule.get("status", "draft")

    if status != "active":
        return {
            "rule_id": rule.get("rule_id"),
            "should_rollback": False,
            "reason": "القاعدة ليست نشطة",
        }

    if ec < min_executions:
        return {
            "rule_id": rule.get("rule_id"),
            "should_rollback": False,
            "reason": f"عدد التنفيذات ({ec}) أقل من الحد الأدنى ({min_executions})",
        }

    should_rollback = sr < min_success_rate

    return {
        "rule_id": rule.get("rule_id"),
        "should_rollback": should_rollback,
        "execution_count": ec,
        "success_rate": sr,
        "min_success_rate": min_success_rate,
        "reason": f"نسبة النجاح ({sr:.1%}) أقل من الحد ({min_success_rate:.1%})" if should_rollback
                  else f"الأداء مقبول ({sr:.1%})",
    }


def notify_governance_alert(
    rule_id: str,
    alert_type: str,
    message: str,
    severity: str = "High",
    details: Optional[Dict] = None,
) -> Dict[str, Any]:
    """Create a governance alert object for persistence."""
    return {
        "alert_id": f"GA-{uuid.uuid4().hex[:8].upper()}",
        "rule_id": rule_id,
        "alert_type": alert_type,
        "message": message,
        "severity": severity,
        "details": details or {},
        "resolved": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
