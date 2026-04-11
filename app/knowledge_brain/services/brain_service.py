"""
╔════════════════════════════════════════════════════════════════╗
║  Apex Knowledge Brain — Reasoning & Retrieval Service          ║
║  محرك الاستدلال والاسترجاع                                    ║
║                                                                ║
║  يربط المعرفة بالمحرك المالي وطبقة AI                         ║
║  يسترجع القواعد والمراجع المناسبة حسب السياق                  ║
╚════════════════════════════════════════════════════════════════╝
"""

from typing import List, Dict, Optional
from app.knowledge_brain.rulebooks.tax_rulebook import TAX_RULES
from app.knowledge_brain.rulebooks.accounting_rulebook import ACCOUNTING_RULES
from app.knowledge_brain.rulebooks.governance_rulebook import GOVERNANCE_RULES
from app.knowledge_brain.rulebooks.compliance_rulebook import COMPLIANCE_RULES


class KnowledgeBrainService:
    """
    الخدمة الرئيسية للعقل المعرفي.
    تربط بين القواعد والمراجع والسياق لإنتاج:
    - تحذيرات امتثال
    - توصيات مدعومة بمرجع
    - سياق للـ AI Narrative
    """

    def __init__(self):
        self.all_rules = {
            **TAX_RULES,
            **ACCOUNTING_RULES,
            **GOVERNANCE_RULES,
            **COMPLIANCE_RULES,
        }

    def evaluate_analysis(self, analysis_result: dict) -> dict:
        """
        يقيّم نتائج التحليل المالي مقابل القواعد المعرفية.
        يُنتج: findings, compliance_notes, recommendations, citations

        يُستدعى بعد المحرك المالي وقبل AI Narrative.
        """
        findings = []
        compliance = []
        recommendations = []
        citations = []

        income = analysis_result.get("income_statement", {})
        balance = analysis_result.get("balance_sheet", {})
        ratios = analysis_result.get("ratios", {})
        meta = analysis_result.get("meta", {})
        confidence = analysis_result.get("confidence", {})
        tab_review = analysis_result.get("tab_review", {})
        industry = meta.get("industry", "general")
        inv_system = meta.get("inventory_system", "unknown")

        # ─── Apply all rules ───
        context = {
            "income": income,
            "balance": balance,
            "ratios": ratios,
            "meta": meta,
            "confidence": confidence,
            "tab_review": tab_review,
            "industry": industry,
            "inventory_system": inv_system,
        }

        for rule_id, rule in self.all_rules.items():
            try:
                result = rule["evaluate"](context)
                if result:
                    result["rule_id"] = rule_id
                    result["domain"] = rule.get("domain", "")
                    result["authority"] = rule.get("authority", "")
                    result["reference"] = rule.get("reference", "")
                    result["obligation"] = rule.get("obligation", "mandatory")

                    if result.get("type") == "finding":
                        findings.append(result)
                    elif result.get("type") == "compliance":
                        compliance.append(result)
                    elif result.get("type") == "recommendation":
                        recommendations.append(result)

                    if result.get("citation"):
                        citations.append(result["citation"])
            except Exception:
                pass  # Rule evaluation should never crash the pipeline

        return {
            "brain_findings": findings,
            "compliance_notes": compliance,
            "brain_recommendations": recommendations,
            "citations": citations,
            "rules_evaluated": len(self.all_rules),
            "rules_triggered": len(findings) + len(compliance) + len(recommendations),
        }

    def get_context_for_narrative(self, analysis_result: dict, brain_result: dict) -> str:
        """
        يبني سياق معرفي للـ AI Narrative.
        يضيف المراجع والقواعد ذات الصلة للـ prompt.
        """
        sections = []

        # Add compliance notes
        if brain_result.get("compliance_notes"):
            sections.append("=== ملاحظات الامتثال ===")
            for note in brain_result["compliance_notes"]:
                ref = f" ({note['reference']})" if note.get("reference") else ""
                sections.append(f"- [{note.get('authority', '')}]{ref}: {note.get('message', '')}")

        # Add findings
        if brain_result.get("brain_findings"):
            sections.append("\n=== نتائج الفحص المعرفي ===")
            for f in brain_result["brain_findings"]:
                sections.append(f"- [{f.get('severity', 'INFO')}] {f.get('message', '')}")

        # Add recommendations
        if brain_result.get("brain_recommendations"):
            sections.append("\n=== توصيات مبنية على الأنظمة ===")
            for r in brain_result["brain_recommendations"]:
                ref = f" (المرجع: {r['reference']})" if r.get("reference") else ""
                sections.append(f"- {r.get('message', '')}{ref}")

        return "\n".join(sections) if sections else ""

    def search(self, query: str, domain: str = None, sector: str = None) -> List[Dict]:
        """بحث بسيط في القواعد — سيُطوّر لاحقاً لـ semantic search"""
        results = []
        query_lower = query.lower()

        for rule_id, rule in self.all_rules.items():
            # Filter by domain
            if domain and rule.get("domain") != domain:
                continue

            # Simple keyword match
            searchable = f"{rule.get('title', '')} {rule.get('description', '')} {rule.get('reference', '')}".lower()
            if query_lower in searchable:
                results.append(
                    {
                        "rule_id": rule_id,
                        "domain": rule.get("domain"),
                        "title": rule.get("title", ""),
                        "reference": rule.get("reference", ""),
                        "authority": rule.get("authority", ""),
                        "obligation": rule.get("obligation", ""),
                    }
                )

        return results
