"""
APEX Platform — Analysis Service
═══════════════════════════════════════════════════════════════
Connects existing financial engine to Phase 2 DB models.
Stores results + generates Result Explanations (! icon).
Per execution document section 6.
"""

from typing import Optional
from app.phase1.models.platform_models import (
    AuditEvent,
    Notification,
    SessionLocal,
    gen_uuid,
    utcnow,
)
from app.phase2.models.phase2_models import (
    COAUpload,
    COAAccount,
    AnalysisResult,
    ResultExplanation,
    ResultWarning,
    UploadStatus,
    AnalysisStatus,
    ExplanationSeverity,
)


class AnalysisService:
    """Wraps the existing orchestrator and stores results in DB."""

    def store_upload(
        self,
        client_id: str,
        user_id: str,
        filename: str,
        file_size: int,
        industry: str,
        closing_inventory: Optional[float],
    ) -> str:
        """Record upload in DB, return upload_id."""
        db = SessionLocal()
        try:
            upload = COAUpload(
                id=gen_uuid(),
                client_id=client_id,
                uploaded_by=user_id,
                filename=filename,
                file_size_bytes=file_size,
                status=UploadStatus.pending.value,
                industry=industry,
                closing_inventory=closing_inventory,
            )
            db.add(upload)
            db.commit()
            return upload.id
        finally:
            db.close()

    def store_analysis_result(self, upload_id: str, client_id: str, user_id: str, engine_result: dict) -> str:
        """Store complete analysis result from orchestrator into DB."""
        db = SessionLocal()
        try:
            # Update upload status
            upload = db.query(COAUpload).filter(COAUpload.id == upload_id).first()
            if upload:
                meta = engine_result.get("meta", {})
                upload.status = UploadStatus.completed.value
                upload.total_accounts = meta.get("total_accounts")
                upload.file_format = meta.get("file_format")
                cls_data = engine_result.get("classification", {}).get("summary", {})
                upload.mapped_accounts = cls_data.get("mapped_accounts")
                upload.unmapped_accounts = cls_data.get("unmapped_accounts_count")
                upload.classification_confidence = engine_result.get("confidence", {}).get("overall")
                tr = engine_result.get("tab_review", {})
                upload.tab_consistency_score = tr.get("consistency_score")
                upload.tab_mismatches = tr.get("mismatches_count")

            # Create analysis result
            inc = engine_result.get("income_statement", {})
            bs = engine_result.get("balance_sheet", {})
            conf = engine_result.get("confidence", {})
            vs = engine_result.get("validation_summary", {})
            kb = engine_result.get("knowledge_brain", {})
            narr = engine_result.get("narrative", {})

            result = AnalysisResult(
                id=gen_uuid(),
                upload_id=upload_id,
                client_id=client_id,
                analyzed_by=user_id,
                status=AnalysisStatus.completed.value,
                overall_confidence=conf.get("overall"),
                confidence_label=conf.get("label"),
                revenue=inc.get("revenue"),
                net_revenue=inc.get("net_revenue"),
                cogs=inc.get("cogs"),
                cogs_method=inc.get("cogs_method"),
                gross_profit=inc.get("gross_profit"),
                operating_profit=inc.get("operating_profit"),
                net_profit=inc.get("net_profit"),
                total_assets=bs.get("total_assets"),
                total_liabilities=bs.get("total_liabilities"),
                total_equity=bs.get("equity", {}).get("total") if isinstance(bs.get("equity"), dict) else None,
                is_balanced=bs.get("is_balanced"),
                balance_diff=bs.get("balance_check"),
                ratios=engine_result.get("ratios"),
                errors_count=vs.get("errors", 0),
                warnings_count=vs.get("warnings", 0),
                can_approve=vs.get("can_approve"),
                brain_rules_evaluated=kb.get("rules_evaluated"),
                brain_rules_triggered=kb.get("rules_triggered"),
                brain_findings=kb.get("brain_findings"),
                has_narrative=bool(narr),
                narrative_platform=narr.get("platform"),
                executive_summary=narr.get("executive_summary"),
                strengths=narr.get("strengths"),
                weaknesses=narr.get("weaknesses"),
                risks=narr.get("risks"),
                recommendations=narr.get("recommendations"),
                management_letter=narr.get("management_letter"),
                full_result_json=engine_result,
            )
            db.add(result)

            # Generate explanations for key metrics (! icon)
            self._generate_explanations(db, result.id, engine_result)

            # Store warnings
            for v in engine_result.get("validations", []):
                db.add(
                    ResultWarning(
                        id=gen_uuid(),
                        result_id=result.id,
                        code=v.get("code", "UNKNOWN"),
                        severity=v.get("severity", "info").lower(),
                        message_ar=v.get("message", ""),
                    )
                )

            # Audit + Notification
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="analysis_completed",
                    resource_type="analysis_result",
                    resource_id=result.id,
                )
            )
            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=user_id,
                    title_ar="اكتمل التحليل المالي",
                    title_en="Financial analysis completed",
                    category="general",
                    source_type="analysis_completed",
                    source_id=result.id,
                )
            )

            db.commit()
            return result.id

        except Exception as e:
            db.rollback()
            raise e
        finally:
            db.close()

    def _generate_explanations(self, db, result_id: str, engine_result: dict):
        """Generate ! icon explanations for each major metric."""
        inc = engine_result.get("income_statement", {})
        bs = engine_result.get("balance_sheet", {})
        li = engine_result.get("line_items", {}).get("income_statement", {})
        ratios = engine_result.get("ratios", {})

        explanations = [
            {
                "key": "net_revenue",
                "label_ar": "صافي الإيرادات",
                "label_en": "Net Revenue",
                "value": inc.get("net_revenue"),
                "explanation_ar": f"صافي الإيرادات = إجمالي المبيعات ({self._fmt(inc.get('revenue'))}) - المردودات والمسموحات ({self._fmt(inc.get('sales_returns'))}) - الخصومات ({self._fmt(inc.get('sales_discounts'))})",
                "source_accounts": self._get_accounts(li, ["revenue", "service_revenue", "sales_returns"]),
                "severity": "info",
            },
            {
                "key": "cogs",
                "label_ar": "تكلفة البضاعة المباعة",
                "label_en": "Cost of Goods Sold",
                "value": inc.get("cogs"),
                "explanation_ar": self._explain_cogs(inc),
                "source_accounts": self._get_accounts(li, ["cogs", "purchases", "purchases_returns"]),
                "severity": "warning" if inc.get("cogs_method") == "none" else "info",
                "warnings": (
                    [{"code": "NO_COGS", "message": "لم يتم حساب تكلفة المبيعات"}]
                    if inc.get("cogs_method") == "none"
                    else None
                ),
            },
            {
                "key": "gross_profit",
                "label_ar": "مجمل الربح",
                "label_en": "Gross Profit",
                "value": inc.get("gross_profit"),
                "explanation_ar": f"مجمل الربح = صافي الإيرادات ({self._fmt(inc.get('net_revenue'))}) - تكلفة المبيعات ({self._fmt(inc.get('cogs'))})",
                "severity": "info",
            },
            {
                "key": "net_profit",
                "label_ar": "صافي الربح",
                "label_en": "Net Profit",
                "value": inc.get("net_profit"),
                "explanation_ar": f"صافي الربح بعد خصم المصروفات التشغيلية وتكاليف التمويل والزكاة/الضريبة",
                "severity": "success" if (inc.get("net_profit") or 0) > 0 else "warning",
            },
            {
                "key": "total_assets",
                "label_ar": "إجمالي الأصول",
                "label_en": "Total Assets",
                "value": bs.get("total_assets"),
                "explanation_ar": f"إجمالي الأصول = أصول متداولة ({self._fmt(bs.get('current_assets', {}).get('total') if isinstance(bs.get('current_assets'), dict) else bs.get('current_assets'))}) + أصول غير متداولة ({self._fmt(bs.get('non_current_assets', {}).get('total') if isinstance(bs.get('non_current_assets'), dict) else bs.get('non_current_assets'))})",
                "severity": "info",
            },
            {
                "key": "balance_check",
                "label_ar": "فحص توازن الميزانية",
                "label_en": "Balance Sheet Check",
                "value": bs.get("balance_check"),
                "explanation_ar": f"الأصول ({self._fmt(bs.get('total_assets'))}) {'=' if bs.get('is_balanced') else '≠'} الالتزامات + حقوق الملكية ({self._fmt(bs.get('total_liabilities_and_equity'))}). الفرق: {self._fmt(bs.get('balance_check'))}",
                "severity": "success" if bs.get("is_balanced") else "error",
                "warnings": (
                    [{"code": "UNBALANCED", "message": "الميزانية غير متوازنة"}] if not bs.get("is_balanced") else None
                ),
            },
        ]

        # Add ratio explanations
        prof = ratios.get("profitability", {}) if isinstance(ratios, dict) else {}
        if prof:
            explanations.append(
                {
                    "key": "gross_margin",
                    "label_ar": "هامش الربح المجمل",
                    "label_en": "Gross Margin",
                    "value": prof.get("gross_margin"),
                    "explanation_ar": f"هامش الربح المجمل = مجمل الربح ÷ صافي الإيرادات × 100",
                    "severity": "info",
                }
            )

        liq = ratios.get("liquidity", {}) if isinstance(ratios, dict) else {}
        if liq:
            cr = liq.get("current_ratio")
            explanations.append(
                {
                    "key": "current_ratio",
                    "label_ar": "نسبة التداول",
                    "label_en": "Current Ratio",
                    "value": cr,
                    "explanation_ar": f"نسبة التداول = الأصول المتداولة ÷ الالتزامات المتداولة. {'جيدة' if cr and cr >= 1.5 else 'ضعيفة — أقل من 1.5' if cr else 'غير محسوبة'}",
                    "severity": "success" if cr and cr >= 1.5 else "warning" if cr else "info",
                }
            )

        for exp in explanations:
            db.add(
                ResultExplanation(
                    id=gen_uuid(),
                    result_id=result_id,
                    metric_key=exp["key"],
                    metric_label_ar=exp["label_ar"],
                    metric_label_en=exp.get("label_en", ""),
                    metric_value=exp.get("value"),
                    metric_formatted=self._fmt(exp.get("value")),
                    explanation_ar=exp["explanation_ar"],
                    source_accounts=exp.get("source_accounts"),
                    source_rows_count=len(exp.get("source_accounts", []) or []),
                    confidence=engine_result.get("confidence", {}).get("overall"),
                    severity=exp.get("severity", "info"),
                    warnings=exp.get("warnings"),
                )
            )

    def get_result_details(self, result_id: str) -> dict:
        """Get result + all explanations (for ! icon panel)."""
        db = SessionLocal()
        try:
            result = db.query(AnalysisResult).filter(AnalysisResult.id == result_id).first()
            if not result:
                return {"success": False, "error": "النتيجة غير موجودة"}

            explanations = (
                db.query(ResultExplanation)
                .filter(ResultExplanation.result_id == result_id)
                .order_by(ResultExplanation.metric_key)
                .all()
            )

            warnings = db.query(ResultWarning).filter(ResultWarning.result_id == result_id).all()

            return {
                "success": True,
                "result_id": result.id,
                "confidence": result.overall_confidence,
                "confidence_label": result.confidence_label,
                "explanations": [
                    {
                        "metric_key": e.metric_key,
                        "metric_label_ar": e.metric_label_ar,
                        "metric_label_en": e.metric_label_en,
                        "value": e.metric_value,
                        "formatted": e.metric_formatted,
                        "explanation_ar": e.explanation_ar,
                        "source_accounts": e.source_accounts,
                        "source_rows_count": e.source_rows_count,
                        "applied_rules": e.applied_rules,
                        "confidence": e.confidence,
                        "severity": e.severity,
                        "warnings": e.warnings,
                        "feedback_count": e.feedback_count,
                    }
                    for e in explanations
                ],
                "warnings": [
                    {
                        "code": w.code,
                        "severity": w.severity,
                        "message_ar": w.message_ar,
                    }
                    for w in warnings
                ],
            }
        finally:
            db.close()

    def list_results(self, client_id: str) -> list:
        """List all analysis results for a client."""
        db = SessionLocal()
        try:
            results = (
                db.query(AnalysisResult)
                .filter(AnalysisResult.client_id == client_id)
                .order_by(AnalysisResult.created_at.desc())
                .all()
            )
            return [
                {
                    "id": r.id,
                    "upload_id": r.upload_id,
                    "status": r.status,
                    "confidence": r.overall_confidence,
                    "confidence_label": r.confidence_label,
                    "net_revenue": r.net_revenue,
                    "net_profit": r.net_profit,
                    "is_balanced": r.is_balanced,
                    "errors": r.errors_count,
                    "warnings": r.warnings_count,
                    "has_narrative": r.has_narrative,
                    "created_at": r.created_at.isoformat(),
                }
                for r in results
            ]
        finally:
            db.close()

    # ─── Helpers ─────────────────────────────────────────────

    @staticmethod
    def _fmt(value) -> str:
        if value is None:
            return "—"
        if isinstance(value, float):
            if abs(value) >= 1_000_000:
                return f"{value/1_000_000:,.2f}M"
            elif abs(value) >= 1_000:
                return f"{value/1_000:,.1f}K"
            return f"{value:,.2f}"
        return str(value)

    @staticmethod
    def _explain_cogs(inc: dict) -> str:
        method = inc.get("cogs_method", "none")
        if method == "periodic_user_input":
            return (
                f"تكلفة المبيعات (جرد دوري) = مخزون أول المدة ({AnalysisService._fmt(inc.get('opening_inventory'))}) "
                f"+ صافي المشتريات ({AnalysisService._fmt(inc.get('purchases'))}) "
                f"- مردودات المشتريات ({AnalysisService._fmt(inc.get('purchases_returns'))}) "
                f"- مخزون آخر المدة ({AnalysisService._fmt(inc.get('closing_inventory'))})"
            )
        elif method == "direct":
            return "تكلفة المبيعات محسوبة مباشرة من حسابات تكلفة البضاعة المباعة"
        return "لم يتم حساب تكلفة المبيعات — قد يكون نظام الجرد دوري ولم يتم إدخال مخزون آخر المدة"

    @staticmethod
    def _get_accounts(line_items: dict, keys: list) -> list:
        accounts = []
        for k in keys:
            item = line_items.get(k, {})
            if isinstance(item, dict):
                for a in item.get("accounts", []):
                    accounts.append({"name": a.get("name", ""), "balance": a.get("balance", 0)})
        return accounts[:20]  # Cap at 20
