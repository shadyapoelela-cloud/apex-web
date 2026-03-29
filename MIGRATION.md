# دليل الانتقال من APEX v1 إلى v2
# Migration Guide: APEX v1 → v2

## الفرق الجوهري

| البند | v1 (القديم) | v2 (الجديد) |
|-------|------------|------------|
| هيكل الكود | ملف واحد 2,222 سطر | 8 ملفات منفصلة (2,600 سطر) |
| التصنيف | tab ثابت hardcoded | 5 مستويات + confidence |
| قائمة الدخل | دالة واحدة 100 سطر | builder مستقل + line items |
| الميزانية | مدمجة مع الدخل | builder مستقل + balance check |
| التدفقات النقدية | غير موجودة | builder كامل (indirect) |
| النسب | 11 نسبة | 25+ نسبة + benchmarks |
| التحقق | لا يوجد | 10+ فحص (ERROR/WARNING/INFO) |
| الثقة | رقم ثابت 90% | confidence حقيقي (mapping+validation+completeness) |
| AI يغيّر الأرقام | نعم (خوارزمية 60/40) | لا — ممنوع |
| حسابات غير مصنفة | تختفي | unmapped_accounts واضحة |

## خطوات النشر على Render

### الطريقة 1: استبدال الـ repo بالكامل

```bash
# على جهازك
cd C:\apex_app\apex-api

# احتفظ بنسخة من القديم
git checkout -b v1-backup
git push origin v1-backup

# ارجع للـ main
git checkout master

# احذف الملفات القديمة (api.py, apex_analyzer.py, financial_reports.py)
# ثم انسخ ملفات v2 الجديدة

# هيكل الملفات الجديد:
# apex-api/
#   app/
#     __init__.py
#     main.py                    ← FastAPI entry point
#     core/
#       __init__.py
#       constants.py             ← 80+ accounting taxonomy
#     services/
#       __init__.py
#       orchestrator.py          ← main pipeline
#       ingestion/
#         __init__.py
#         trial_balance_reader.py
#       classification/
#         __init__.py
#         account_classifier.py
#       financial/
#         __init__.py
#         income_statement_builder.py
#         balance_sheet_builder.py
#         cashflow_builder.py
#         ratio_engine.py
#         readiness_engine.py
#         validation_engine.py
#   requirements.txt
#   Procfile
#   templates/                   ← Excel templates (already uploaded)
#   apex_finance/               ← Flutter (keep as is)

# Render Settings:
#   Build Command: pip install -r requirements.txt
#   Start Command: uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

### الطريقة 2: تشغيل v2 بالتوازي (أفضل)

1. أنشئ service جديد على Render باسم `apex-api-v2`
2. اربطه بنفس الـ repo بس branch مختلف
3. اختبر v2 مع Flutter
4. لما يشتغل بشكل كامل، غيّر Flutter لـ URL الجديد

## API Endpoints الجديدة

### POST /analyze (بديل /unit1/analyze/multistage)
```json
// Request: upload Excel file + industry query param
// Response:
{
  "success": true,
  "meta": { "company_name", "period", "total_accounts", "industry" },
  "confidence": { "overall": 0.88, "mapping": 0.97, "validation": 0.85, "completeness": 0.80 },
  "income_statement": { ... },
  "balance_sheet": { ... },
  "cash_flow": { ... },
  "ratios": { "profitability": {}, "liquidity": {}, "leverage": {}, "efficiency": {} },
  "benchmark_comparison": { ... },
  "readiness": { "score": 82, "label": "Good with Conditions", "breakdown": {} },
  "validations": [ { "code", "severity", "message" } ],
  "classification": { "summary": {}, "unmapped_accounts": [] }
}
```

### POST /classify (بديل /unit1/evaluate-tabs)
```json
// Response:
{
  "success": true,
  "classification_summary": { "mapped": 40, "unmapped": 0, "confidence": 0.97 },
  "classified_accounts": [ { "name", "normalized_class", "confidence", "source" } ]
}
```

## ربط Flutter بـ v2

### الـ URL
```dart
// القديم:
final uri = Uri.parse('https://apex-api-ootk.onrender.com/unit1/analyze/multistage');

// الجديد:
final uri = Uri.parse('https://apex-api-v2.onrender.com/analyze?industry=retail');
```

### قراءة النتائج
```dart
// القديم:
final income = result['final_result']['financial_data']['income_statement'];

// الجديد:
final income = result['income_statement'];
final balance = result['balance_sheet'];
final ratios = result['ratios'];
final confidence = result['confidence'];
final validations = result['validations'];
```
