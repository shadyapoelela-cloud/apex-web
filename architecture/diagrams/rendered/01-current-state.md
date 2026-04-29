# APEX — الواقع الحالي (As-Is)

> مخطط شامل لكل ما هو منفّذ فعلياً في الكود اليوم. مبني على استكشاف عميق لـ 11 Phase + 6 Sprint + 37 راوت أساسي في GoRouter.

---

## 1. النظرة العامة — كل الأدوار والرحلات الأساسية

![diagram](./01-current-state-1.png)

---

## 2. تدفق المصادقة (Authentication)

![diagram](./01-current-state-2.png)

**نقاط مهمة في الواقع الحالي:**
- ✅ JWT HS256 شغّال + bcrypt للباسورد
- ✅ 2FA TOTP منفّذ
- ✅ Forgot password كامل
- ⚠️ Google/Apple sign-in **stub** (التوكن مش متحقق منه — راجع `app/core/social_auth_verify.py`)
- ⚠️ SMS verification **stub** (دايماً يرجع success)

---

## 3. تدفق الـ Onboarding للعميل (SME)

![diagram](./01-current-state-3.png)

---

## 4. تدفق الـ Marketplace (Provider + Client)

![diagram](./01-current-state-4.png)

> **ملاحظة:** AML check حالياً integration stub — لازم تربط بمزوّد فعلي للإنتاج.

---

## 5. تدفق Knowledge Brain + Copilot (AI)

![diagram](./01-current-state-5.png)

---

## 6. تدفق الإدارة (Platform Admin)

![diagram](./01-current-state-6.png)

---

## 7. هيكل الـ Backend (Phases + Sprints)

![diagram](./01-current-state-7.png)

---

## 8. خريطة الراوتس (Frontend - 37 رئيسي)

![diagram](./01-current-state-8.png)

---

## 9. الفجوات والـ Stubs الحالية

![diagram](./01-current-state-9.png)

**التفاصيل في** [`04-gap-analysis.md`](04-gap-analysis.md).

---

## مرجع سريع — الأدوار العشرة

| # | Role Code | المسؤوليات الأساسية |
|---|-----------|---------------------|
| 1 | `guest` | غير مسجّل — صفحات عامة، تسجيل، دخول |
| 2 | `registered_user` | حساب مجاني، Dashboard، Profile |
| 3 | `client_user` | عضو فريق العميل — COA, Reports, TB |
| 4 | `client_admin` | إدارة المؤسسة — فريق + اشتراكات + فواتير |
| 5 | `provider_user` | مزوّد خدمة/معرفة — Marketplace + KB |
| 6 | `provider_admin` | قيادة المزوّد — فريق + KYC/AML + Audit |
| 7 | `reviewer` | مراجع محتوى — يعتمد COA classifications |
| 8 | `knowledge_reviewer` | مراجع MoBرفة — يعتمد KB articles |
| 9 | `platform_admin` | موظف APEX — Admin Console |
| 10 | `super_admin` | مالك النظام — DB migrations, emergency actions |
