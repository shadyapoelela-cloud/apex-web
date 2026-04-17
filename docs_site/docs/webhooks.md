---
id: webhooks
title: Webhooks
sidebar_position: 5
---

# Webhooks

تُبلِّغك APEX بالأحداث (فاتورة أُنشئت، دفعة استُلمت، ...) لحظة حدوثها
عبر Webhooks — HTTP POST إلى رابطك مع HMAC signature للتحقق من المصدر.

## 1. الاشتراك

```python
sub = apex.webhooks.subscribe(
    url="https://yourapp.com/hooks/apex",
    events=["invoice.created", "invoice.paid", "payment.received"],
    name="production bridge",
)
print("Secret (احفظه — لن يظهر مرة أخرى):", sub["secret"])
```

الاستجابة تحتوي `secret` بصيغة `whsec_...`. **احفظه** — ستحتاجه للتحقق
من كل request وارد. لن يُعرض مرة أخرى عبر الـ API.

## 2. شكل الـ payload

كل event:

```json
{
  "id": "evt_8f2e9a...",
  "type": "invoice.paid",
  "tenant_id": "t_123",
  "created_at": "2026-04-17T10:30:00Z",
  "data": {
    "invoice_id": "inv_001",
    "amount": 1500.00,
    "currency": "SAR"
  }
}
```

## 3. التحقق من التوقيع (إلزامي)

كل request يحمل `X-Apex-Signature: sha256=<hex>`. تأكّد قبل معالجته:

### Python

```python
import hmac
import hashlib

def verify(secret: str, body: bytes, signature: str) -> bool:
    if not signature.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(
        secret.encode(), body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)
```

### Node.js

```javascript
import crypto from "node:crypto";

function verify(secret, body, signature) {
  if (!signature.startsWith("sha256=")) return false;
  const expected = "sha256=" + crypto
    .createHmac("sha256", secret)
    .update(body)
    .digest("hex");
  return crypto.timingSafeEqual(
    Buffer.from(expected), Buffer.from(signature),
  );
}
```

### PHP

```php
use Apex\Sdk\Namespaces\Webhooks;

if (! Webhooks::verifySignature($secret, $rawBody, $signatureHeader)) {
    http_response_code(401);
    exit;
}
```

## 4. الأحداث المتاحة

| الحدث | متى يُطلَق |
|--------|------------|
| `invoice.created` | فاتورة جديدة مُصدَرة |
| `invoice.sent` | أُرسلت الفاتورة (بريد / WhatsApp) |
| `invoice.paid` | اكتمل الدفع |
| `invoice.overdue` | تجاوز تاريخ الاستحقاق |
| `payment.received` | دفعة تمت |
| `payment.failed` | فشل الدفع |
| `employee.created` | موظف جديد |
| `employee.terminated` | إنهاء خدمة |
| `payroll.approved` | تم اعتماد رواتب شهر |
| `payroll.paid` | صرف الرواتب |
| `leave.approved` | إجازة معتمدة |
| `reconciliation.completed` | انتهت مطابقة بنكية |

## 5. سياسة إعادة المحاولة

- عند استجابة ≥ 400 أو timeout: نعيد بتأخير تصاعدي
  `30s → 2m → 10m → 1h → 6h` (5 محاولات).
- بعد 5 فشلات متتالية: حالة الـ delivery تصبح `dead` وتظهر في الـ dashboard
  للمراجعة.
- يدوياً: `apex.webhooks.retry_delivery(delivery_id)` يُعيد المحاولة فوراً.

## 6. الأمان

- استخدم HTTPS فقط — لن نُرسل إلى HTTP.
- تأكّد من التوقيع في كل request — بدون ذلك، أي متسلل يعرف رابطك يستطيع محاكاتنا.
- رد `200-299` لتأكيد الاستلام. رد `4xx` يعتبر رفضاً ولا يُعيد المحاولة.
- المحتوى حتى 1MB؛ للـ payloads الكبيرة نرسل `entity_id` فقط واطلب التفاصيل عبر API.
- الـ `secret` قابل للتدوير (rotate) — اتصل بالدعم لعملية rotation بدون downtime.
