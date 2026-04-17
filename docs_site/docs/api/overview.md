---
id: overview
title: نظرة عامة على الـ API
sidebar_position: 1
---

# APEX REST API

الـ API يتبع REST — JSON في الطلب والاستجابة، UTF-8 في كل مكان،
HTTP status codes معيارية.

## URL الأساسي

```
الإنتاج:   https://api.apex-app.com
التطوير:  https://sandbox.apex-app.com
```

## المصادقة

كل الـ endpoints تتطلب:

1. `Authorization: Bearer <api_key>` — مفتاح API.
2. `X-Tenant-Id: <tenant_id>` — معرّف الشركة (tenant) في حسابك.

مفاتيح الـ API منفصلة لكل بيئة (live / test) — لا تعيد استخدامها.

## شكل الاستجابة

كل استجابة ناجحة:

```json
{
  "success": true,
  "data": { ... }
}
```

استجابة فاشلة:

```json
{
  "success": false,
  "error": "الوصف العربي",
  "detail": "Technical detail for developers"
}
```

## الترقيم المتسلسل (Cursor Pagination)

القوائم الطويلة تُستخدم ترقيماً مبنياً على الـ cursor — أسرع من offset وأكثر
استقراراً مع التعديلات المتزامنة.

```bash
GET /hr/employees?limit=25
```

الاستجابة:

```json
{
  "success": true,
  "data": [ { "id": "..." }, ... ],
  "next_cursor": "eyJmIjoiY3JlYXRlZF9hdCI...",
  "has_more": true,
  "limit": 25
}
```

للصفحة التالية، أعِد الـ `next_cursor`:

```bash
GET /hr/employees?limit=25&cursor=eyJmIjoi...
```

الـ SDKs تتعامل مع التكرار تلقائياً عبر `paginate()`.

## الإصدار

الـ API الحالي `v1`. مسارات جديدة تبدأ بـ `/api/v1/`. كل استجابة تحمل
`X-API-Version: v1` — عند استخدام v2 مستقبلاً ستستمر v1 لمدة 6 أشهر.

## الحدود المعدلة (Rate Limits)

- إنشاء/تعديل: 120/دقيقة/IP.
- تسجيل دخول: 10/5 دقائق/IP.
- الافتراضي: 100/دقيقة/IP.

استجابة التجاوز: `429 Too Many Requests` مع `Retry-After` header.

## الأمان

- TLS 1.3 فقط في الإنتاج.
- كل الطلبات المتحوّلة للحالة (POST/PUT/PATCH/DELETE) تُسجَّل في audit log.
- الأسرار (passwords, tokens, IBAN, national_id) يتم redact قبل التسجيل.
- كل الـ tenants معزولة بـ Row-Level Security — طلبات tenant A لا ترى بيانات tenant B.

## موارد الـ API

| المورد | URL | الوصف |
|--------|-----|-------|
| **الموظفون (HR)** | `/hr/employees` | CRUD + ترقيم |
| **الإجازات** | `/hr/leave-requests` | إنشاء + اعتماد/رفض |
| **الرواتب** | `/hr/payroll/run` | تشغيل شهري + WPS download |
| **حاسبات HR** | `/hr/calc/gosi`, `/hr/calc/eosb` | GOSI + EOSB |
| **الأبعاد المحاسبية** | `/api/v1/dimensions` | branch/project/cost-center tagging |
| **Saved Views** | `/api/v1/saved-views` | حفظ فلاتر/أعمدة لكل مستخدم/شاشة |
| **Webhooks** | `/api/v1/webhooks/subscriptions` | اشتراك في الأحداث |
| **ZATCA** | `/zatca/*` | فوترة إلكترونية سعودية |
| **UAE FTA** | `/uae-fta/*` | ضريبة شركات + TRN + Peppol |

## خرائط الرموز الخاصة

- `Numeric(18,2)` لكل مبلغ مالي — لا تستخدم `float` في العميل.
- كل المبالغ بعملة الـ tenant افتراضياً (SAR للسعودية، AED للإمارات).
- التواريخ بصيغة ISO 8601 (`YYYY-MM-DD`).
- الأوقات بـ UTC (`YYYY-MM-DDTHH:MM:SSZ`).
