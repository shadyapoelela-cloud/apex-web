"""
APEX Analysis Orchestrator v2 — المنسّق الرئيسي
═══════════════════════════════════════════════════

Pipeline: Read → Classify → IS → BS → CF → Ratios → Readiness → Validate
"""

import os
import tempfile
from app.services.ingestion.trial_balance_reader import TrialBalanceReader
from app.services.classification.account_classifier import AccountClassifier
from app.services.financial.income_statement_builder import IncomeStatementBuilder
from app.services.financial.balance_sheet_builder import BalanceSheetBuilder
from app.services.financial.cashflow_builder import CashFlowBuilder
from app.services.financial.ratio_engine import RatioEngine
from app.services.financial.readiness_engine import ReadinessEngine
from app.services.financial.validation_engine import ValidationEngine


class AnalysisOrchestrator:

    def __init__(self):
        self.reader = TrialBalanceReader()
        self.classifier = AccountClassifier()
        self.is_builder = IncomeStatementBuilder()
        self.bs_builder = BalanceSheetBuilder()
        self.cf_builder = CashFlowBuilder()
        self.ratio_engine = RatioEngine()
        self.readiness_engine = ReadinessEngine()
        self.validator = ValidationEngine()

    def analyze_bytes(self, file_bytes: bytes, filename: str, industry: str = "general") -> dict:
        suffix = os.path.splitext(filename)[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(file_bytes)
            tmp_path = tmp.name
        try:
            result = self.analyze(filepath=tmp_path, industry=industry)
            result["meta"]["filename"] = filename
            return result
        finally:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

    def analyze(self, filepath: str, industry: str = "general") -> dict:
        all_warnings = []

        # Step 1: Read
        read_result = self.reader.read(filepath)
        raw_rows = read_result["rows"]
        meta = read_result["meta"]
        all_warnings.extend(read_result.get("warnings", []))

        if not raw_rows:
            return {"success": False, "error": "لم يتم العثور على بيانات في الملف", "warnings": all_warnings}

        # Step 2: Classify
        classified_rows = self.classifier.classify_rows(raw_rows)
        cls_summary = self.classifier.get_summary(classified_rows)

        # Step 3: Opening inventory
        opening_inventory = self._get_opening_inventory(raw_rows, classified_rows)

        # Step 4: Income Statement
        is_result = self.is_builder.build(classified_rows, opening_inventory=opening_inventory)
        income = is_result["income_statement"]
        all_warnings.extend(is_result.get("warnings", []))

        # Step 5: Balance Sheet
        bs_result = self.bs_builder.build(classified_rows, net_profit=income.get("net_profit", 0))
        balance = bs_result["balance_sheet"]
        all_warnings.extend(bs_result.get("warnings", []))

        # Step 6: Cash Flow
        cf_result = self.cf_builder.build(income=income, balance_current=balance, classified_rows=classified_rows)
        cash_flow = cf_result["cash_flow"]
        all_warnings.extend(cf_result.get("warnings", []))

        # Step 7: Ratios
        ratio_result = self.ratio_engine.calculate(income, balance, industry=industry)
        ratios = ratio_result.get("ratios", {})
        all_warnings.extend(ratio_result.get("warnings", []))

        # Step 8: Validate
        validations = self.validator.validate(classified_rows=classified_rows, income=income, balance=balance, classification_summary=cls_summary)
        severity_counts = self.validator.get_severity_counts(validations)

        # Step 9: Confidence
        confidence = self._calc_confidence(cls_summary, validations, income, balance)

        # Step 10: Readiness
        readiness_result = self.readiness_engine.calculate(income=income, balance=balance, ratios=ratios, validations=validations, confidence=confidence, industry=industry)

        return {
            "success": True,
            "meta": {"company_name": meta.get("company_name", ""), "period": meta.get("period", ""), "currency": "SAR", "file_format": read_result.get("format", "unknown"), "total_accounts": len(raw_rows), "industry": industry},
            "confidence": confidence,
            "classification": {"summary": cls_summary, "unmapped_accounts": cls_summary.get("unmapped_accounts", [])},
            "income_statement": income,
            "balance_sheet": balance,
            "cash_flow": cash_flow,
            "ratios": ratios,
            "benchmark_comparison": ratio_result.get("benchmark_comparison", {}),
            "readiness": readiness_result.get("readiness", {}),
            "validations": validations,
            "validation_summary": {"errors": severity_counts.get("ERROR", 0), "warnings": severity_counts.get("WARNING", 0), "info": severity_counts.get("INFO", 0), "can_approve": self.validator.can_approve(validations)},
            "line_items": {"income_statement": is_result.get("line_items", {}), "balance_sheet": bs_result.get("line_items", {})},
        }

    def _get_opening_inventory(self, raw_rows, classified_rows):
        total = 0.0
        for i, row in enumerate(classified_rows):
            if row.get("normalized_class") and "inventory" in row["normalized_class"]:
                if i < len(raw_rows):
                    total += raw_rows[i].get("open_debit", 0)
        return total

    def _calc_confidence(self, cls_summary, validations, income, balance):
        mapping = cls_summary.get("average_confidence", 0)
        errs = sum(1 for v in validations if v.get("severity") == "ERROR")
        warns = sum(1 for v in validations if v.get("severity") == "WARNING")
        val_conf = max(0, 1.0 - errs * 0.15 - warns * 0.03)
        comp = 1.0
        if income.get("net_revenue", 0) == 0: comp -= 0.3
        if balance.get("total_assets", 0) == 0: comp -= 0.3
        if not balance.get("is_balanced", False): comp -= 0.2
        unmapped_pct = cls_summary.get("unmapped_accounts_count", 0) / max(cls_summary.get("total_accounts", 1), 1)
        comp = max(0, comp - unmapped_pct * 0.5)
        overall = mapping * 0.4 + val_conf * 0.3 + comp * 0.3
        return {"overall": round(overall, 3), "mapping": round(mapping, 3), "validation": round(val_conf, 3), "completeness": round(comp, 3),
                "label": "ممتاز" if overall >= 0.90 else "جيد" if overall >= 0.75 else "مقبول" if overall >= 0.60 else "يحتاج مراجعة"}
