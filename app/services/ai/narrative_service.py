"""
APEX AI Narrative Service — طبقة الذكاء الاصطناعي
═══════════════════════════════════════════════════

القاعدة الذهبية: AI يشرح ويوصي — لا يغيّر أي رقم.

المدخلات: نتائج مالية مقفلة من المحرك المالي
المخرجات: ملخص تنفيذي + نقاط قوة + مخاطر + توصيات + أسئلة فحص
"""

import os
import json
from typing import Optional


class NarrativeService:
    """
    Generates AI narrative from locked financial results.
    Supports: OpenAI GPT-4, Google Gemini, Anthropic Claude.
    """

    def __init__(self):
        self.openai_key = os.environ.get("OPENAI_API_KEY", "")
        self.google_key = os.environ.get("GOOGLE_API_KEY", "")
        self.anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")

    async def generate(self, analysis_result: dict, language: str = "ar", brain_context: str = "") -> dict:
        """
        Generate narrative from locked analysis results.

        Args:
            analysis_result: Full result from AnalysisOrchestrator
            language: "ar" for Arabic, "en" for English
            brain_context: Knowledge Brain context with compliance notes and citations

        Returns:
            dict with narrative sections + platform used
        """
        if not analysis_result.get("success"):
            return {"error": "لا يمكن إنشاء تقرير لتحليل فاشل", "platform": "none"}

        # Build the prompt with locked data + brain context
        prompt = self._build_prompt(analysis_result, language, brain_context)

        # Try platforms in order: OpenAI → Gemini → Claude
        narrative = {}
        platform = "none"

        if self.openai_key:
            try:
                narrative = await self._call_openai(prompt)
                platform = "gpt4"
            except Exception as e:
                narrative = {"error": f"GPT-4: {str(e)}"}

        if not narrative.get("executive_summary") and self.google_key:
            try:
                narrative = await self._call_gemini(prompt)
                platform = "gemini"
            except Exception as e:
                narrative = {"error": f"Gemini: {str(e)}"}

        if not narrative.get("executive_summary") and self.anthropic_key:
            try:
                narrative = await self._call_claude(prompt)
                platform = "claude"
            except Exception as e:
                narrative = {"error": f"Claude: {str(e)}"}

        narrative["platform"] = platform
        narrative["language"] = language
        return narrative

    def _build_prompt(self, result: dict, language: str, brain_context: str = "") -> str:
        """Build the AI prompt with locked financial data + brain context."""
        income = result.get("income_statement", {})
        balance = result.get("balance_sheet", {})
        ratios = result.get("ratios", {})
        readiness = result.get("readiness", {})
        validations = result.get("validations", [])
        confidence = result.get("confidence", {})
        meta = result.get("meta", {})
        benchmark = result.get("benchmark_comparison", {})

        # Summarize validations
        errors = [v for v in validations if v.get("severity") == "ERROR"]
        warnings = [v for v in validations if v.get("severity") == "WARNING"]

        financial_summary = {
            "company": meta.get("company_name", "غير محدد"),
            "period": meta.get("period", "غير محدد"),
            "industry": meta.get("industry", "general"),
            "income_statement": {
                "net_revenue": income.get("net_revenue", 0),
                "gross_profit": income.get("gross_profit", 0),
                "gross_margin": ratios.get("profitability", {}).get("gross_margin_pct"),
                "operating_profit": income.get("operating_profit", 0),
                "ebitda": income.get("ebitda", 0),
                "net_profit": income.get("net_profit", 0),
                "net_margin": ratios.get("profitability", {}).get("net_margin_pct"),
            },
            "balance_sheet": {
                "total_assets": balance.get("total_assets", 0),
                "current_assets": balance.get("current_assets", {}).get("total", 0),
                "total_liabilities": balance.get("total_liabilities", 0),
                "total_equity": balance.get("equity", {}).get("total", 0),
                "is_balanced": balance.get("is_balanced", False),
            },
            "key_ratios": {
                "current_ratio": ratios.get("liquidity", {}).get("current_ratio"),
                "quick_ratio": ratios.get("liquidity", {}).get("quick_ratio"),
                "debt_to_equity": ratios.get("leverage", {}).get("debt_to_equity"),
                "roa": ratios.get("profitability", {}).get("roa_pct"),
                "roe": ratios.get("profitability", {}).get("roe_pct"),
                "dso": ratios.get("efficiency", {}).get("dso"),
                "inventory_days": ratios.get("efficiency", {}).get("days_in_inventory"),
                "asset_turnover": ratios.get("efficiency", {}).get("asset_turnover"),
            },
            "readiness": {
                "score": readiness.get("score", 0),
                "label": readiness.get("label", ""),
            },
            "confidence": confidence.get("overall", 0),
            "data_quality": {
                "errors": len(errors),
                "warnings": len(warnings),
                "error_details": [e.get("message", "") for e in errors],
                "warning_details": [w.get("message", "") for w in warnings],
            },
            "benchmark_highlights": {
                k: {"actual": v.get("actual"), "benchmark": v.get("benchmark"), "status": v.get("status")}
                for k, v in benchmark.items()
            },
        }

        if language == "ar":
            return self._arabic_prompt(financial_summary, brain_context)
        return self._english_prompt(financial_summary, brain_context)

    def _arabic_prompt(self, data: dict, brain_context: str = "") -> str:
        brain_section = ""
        if brain_context:
            brain_section = f"""

═══ نتائج العقل المعرفي (Knowledge Brain) ═══
{brain_context}
═══ انتهت نتائج العقل المعرفي ═══

استخدم هذه المعلومات من العقل المعرفي لتعزيز تحليلك — اذكر المراجع الرسمية عند الإشارة لها.
"""
        return f"""أنت محلل مالي تنفيذي خبير في السوق السعودي. استقبل نتائج مالية نهائية مقفلة.

⚠️ قواعد صارمة:
- لا تغيّر أي رقم مالي — الأرقام نهائية ومقفلة من المحرك المالي
- لا تختلق بيانات غير موجودة
- إذا كانت الثقة منخفضة أو فيه تحذيرات، اذكرها بوضوح
- إذا فيه أخطاء في البيانات، نبّه عليها
- استخدم المراجع الرسمية من العقل المعرفي عند الإشارة للأنظمة والمعايير
{brain_section}
البيانات المالية المقفلة:
{json.dumps(data, ensure_ascii=False, indent=2)}

اكتب تقريراً تحليلياً شاملاً بالعربية. أجب بـ JSON فقط بدون أي نص آخر أو markdown:
{{
  "executive_summary": "ملخص تنفيذي شامل من 4-6 جمل يغطي الأداء المالي والسيولة والربحية والمديونية",
  "strengths": ["نقطة قوة 1 مع أرقام", "نقطة قوة 2 مع أرقام", "نقطة قوة 3"],
  "weaknesses": ["نقطة ضعف 1 مع أرقام", "نقطة ضعف 2"],
  "risks": [
    {{"risk": "وصف الخطر", "severity": "عالي/متوسط/منخفض", "impact": "الأثر المحتمل"}},
    {{"risk": "خطر 2", "severity": "متوسط", "impact": "الأثر"}}
  ],
  "recommendations": [
    {{"priority": "عالية", "action": "الإجراء المقترح", "expected_impact": "الأثر المتوقع", "timeline": "المدة"}},
    {{"priority": "متوسطة", "action": "إجراء 2", "expected_impact": "الأثر", "timeline": "المدة"}}
  ],
  "due_diligence_questions": [
    "سؤال فحص نافي للجهالة 1",
    "سؤال 2",
    "سؤال 3"
  ],
  "sector_commentary": "تعليق على أداء الشركة مقارنة بالقطاع",
  "management_letter": "رسالة موجزة للإدارة تلخص الوضع المالي وأهم التوصيات"
}}"""

    def _english_prompt(self, data: dict, brain_context: str = "") -> str:
        brain_section = ""
        if brain_context:
            brain_section = f"\n=== Knowledge Brain Findings ===\n{brain_context}\n=== End Knowledge Brain ===\nUse these regulatory references to strengthen your analysis.\n"
        return f"""You are an expert financial analyst specializing in Saudi Arabian market. You received locked final financial results.

⚠️ Strict rules:
- Do NOT modify any financial number — numbers are final from the financial engine
- Do NOT fabricate missing data
- If confidence is low or there are warnings, mention them clearly
- Reference official regulations from the Knowledge Brain when applicable
{brain_section}
Locked Financial Data:
{json.dumps(data, ensure_ascii=False, indent=2)}

Write a comprehensive analytical report. Respond with JSON only, no markdown:
{{
  "executive_summary": "4-6 sentence executive summary covering financial performance, liquidity, profitability, and leverage",
  "strengths": ["strength 1 with numbers", "strength 2", "strength 3"],
  "weaknesses": ["weakness 1 with numbers", "weakness 2"],
  "risks": [
    {{"risk": "description", "severity": "high/medium/low", "impact": "potential impact"}},
    {{"risk": "risk 2", "severity": "medium", "impact": "impact"}}
  ],
  "recommendations": [
    {{"priority": "high", "action": "recommended action", "expected_impact": "expected impact", "timeline": "timeframe"}},
    {{"priority": "medium", "action": "action 2", "expected_impact": "impact", "timeline": "timeframe"}}
  ],
  "due_diligence_questions": ["question 1", "question 2", "question 3"],
  "sector_commentary": "commentary on company performance vs sector benchmarks",
  "management_letter": "brief letter to management summarizing financial position and key recommendations"
}}"""

    async def _call_openai(self, prompt: str) -> dict:
        from openai import OpenAI
        client = OpenAI(api_key=self.openai_key)
        response = client.chat.completions.create(
            model="gpt-4o",
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=3000,
        )
        raw = response.choices[0].message.content.strip()
        raw = raw.replace("```json", "").replace("```", "").strip()
        return json.loads(raw)

    async def _call_gemini(self, prompt: str) -> dict:
        import requests as req
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={self.google_key}"
        resp = req.post(url, json={
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.3},
        })
        rj = resp.json()
        if "candidates" in rj and len(rj["candidates"]) > 0:
            raw = rj["candidates"][0]["content"]["parts"][0]["text"].strip()
            raw = raw.replace("```json", "").replace("```", "").strip()
            return json.loads(raw)
        return {"error": rj.get("error", {}).get("message", str(rj))}

    async def _call_claude(self, prompt: str) -> dict:
        import anthropic
        client = anthropic.Anthropic(api_key=self.anthropic_key)
        message = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=3000,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = message.content[0].text.strip()
        raw = raw.replace("```json", "").replace("```", "").strip()
        return json.loads(raw)
