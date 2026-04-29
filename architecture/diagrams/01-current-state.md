# APEX — الواقع الحالي (As-Is)

> مخطط شامل لكل ما هو منفّذ فعلياً في الكود اليوم. مبني على استكشاف عميق لـ 11 Phase + 6 Sprint + 37 راوت أساسي في GoRouter.

---

## 1. النظرة العامة — كل الأدوار والرحلات الأساسية

```mermaid
flowchart TD
    Start([🌐 Open APEX])
    Start --> LoggedIn{Logged In?}

    LoggedIn -- No --> AuthHub[/login or /register/]
    LoggedIn -- Yes --> RoleCheck{User Role?}

    AuthHub --> RegFlow[Register Flow]
    AuthHub --> LoginFlow[Login Flow]
    AuthHub --> ForgotFlow[Forgot Password]

    RegFlow --> EmailVerify[Email Verification]
    EmailVerify --> RoleCheck
    LoginFlow --> RoleCheck
    ForgotFlow --> LoginFlow

    RoleCheck -- registered_user --> UserHome["/app Launchpad"]
    RoleCheck -- client_user / client_admin --> ClientHub[Finance Hub]
    RoleCheck -- provider_user / provider_admin --> ProviderHub[Marketplace + KB]
    RoleCheck -- reviewer / knowledge_reviewer --> ReviewerHub["/admin/reviewer"]
    RoleCheck -- platform_admin / super_admin --> AdminHub["/admin/dashboard"]

    UserHome --> Onboard[SME Onboarding]
    Onboard --> ClientHub

    ClientHub --> CoaFlow[COA Upload + Classify + TB]
    ClientHub --> Compliance[ZATCA / Zakat / VAT]
    ClientHub --> Marketplace[Browse & Request Services]
    ClientHub --> Reports[Reports & Analytics]

    ProviderHub --> KycFlow[KYC + AML Verification]
    KycFlow --> ProviderActive[Active Provider]
    ProviderActive --> SubmitKB[Submit KB Articles]
    ProviderActive --> BidServices[Bid on Service Requests]

    ReviewerHub --> ReviewCOA[Review COA Classifications]
    ReviewerHub --> ReviewKB[Review KB Submissions]

    AdminHub --> UserMgmt[User & Provider Management]
    AdminHub --> AuditLog[Audit Logs]
    AdminHub --> AiConsole["/admin/ai-console"]
    AdminHub --> Policies[Policy Management]

    classDef start fill:#10b981,stroke:#059669,color:#fff
    classDef decision fill:#f59e0b,stroke:#d97706,color:#000
    classDef process fill:#8b5cf6,stroke:#6d28d9,color:#fff
    classDef hub fill:#3b82f6,stroke:#1d4ed8,color:#fff

    class Start start
    class LoggedIn,RoleCheck decision
    class UserHome,ClientHub,ProviderHub,ReviewerHub,AdminHub hub
    class RegFlow,LoginFlow,ForgotFlow,EmailVerify,Onboard,CoaFlow,Compliance,Marketplace,Reports,KycFlow,ProviderActive,SubmitKB,BidServices,ReviewCOA,ReviewKB,UserMgmt,AuditLog,AiConsole,Policies process
```

---

## 2. تدفق المصادقة (Authentication)

```mermaid
flowchart LR
    Open([Open Site]) --> AuthCheck{Has Session?}
    AuthCheck -- Yes --> Dashboard["/app Launchpad"]
    AuthCheck -- No --> AuthScreen["/login - SlideAuthScreen"]

    AuthScreen --> Choice{Action?}
    Choice -- Sign In --> EnterCreds[Email + Password]
    Choice -- Sign Up --> RegisterScreen["/register"]
    Choice -- Forgot --> ForgotScreen["/forgot-password"]
    Choice -- Google --> GoogleStub[POST /auth/social/google]
    Choice -- Apple --> AppleStub[POST /auth/social/apple]

    EnterCreds --> LoginAPI[POST /auth/login]
    LoginAPI --> ValidPwd{bcrypt valid?}
    ValidPwd -- No --> AuthScreen
    ValidPwd -- Yes --> Has2FA{2FA enabled?}

    Has2FA -- Yes --> TotpScreen["/account/mfa - Enter TOTP"]
    TotpScreen --> TotpAPI[POST /auth/totp/verify]
    TotpAPI --> Issue[Issue JWT HS256]
    Has2FA -- No --> Issue

    Issue --> StoreLocal[Store in localStorage]
    StoreLocal --> Dashboard

    RegisterScreen --> RegAPI[POST /auth/register]
    RegAPI --> CreateUser[(Create User<br/>status=pending_verification)]
    CreateUser --> SendEmail[/Send Verification Email/]
    SendEmail --> WaitClick[Wait for user click]
    WaitClick --> VerifyAPI[POST /auth/email/verify]
    VerifyAPI --> Active[(status=active)]
    Active --> AuthScreen

    ForgotScreen --> ForgotAPI[POST /auth/forgot-password]
    ForgotAPI --> EmailLink[/Email Reset Link/]
    EmailLink --> ResetScreen[Reset Password]
    ResetScreen --> ResetAPI[POST /auth/reset-password]
    ResetAPI --> AuthScreen

    GoogleStub -.STUB: token NOT verified.-> Issue
    AppleStub -.STUB: token NOT verified.-> Issue

    classDef stub fill:#fee2e2,stroke:#dc2626,color:#000
    classDef api fill:#dbeafe,stroke:#1e40af,color:#000
    classDef screen fill:#e9d5ff,stroke:#7c3aed,color:#000
    classDef db fill:#fef3c7,stroke:#d97706,color:#000

    class GoogleStub,AppleStub stub
    class LoginAPI,RegAPI,VerifyAPI,ForgotAPI,ResetAPI,TotpAPI api
    class AuthScreen,RegisterScreen,ForgotScreen,TotpScreen,ResetScreen,Dashboard screen
    class CreateUser,Active db
```

**نقاط مهمة في الواقع الحالي:**
- ✅ JWT HS256 شغّال + bcrypt للباسورد
- ✅ 2FA TOTP منفّذ
- ✅ Forgot password كامل
- ⚠️ Google/Apple sign-in **stub** (التوكن مش متحقق منه — راجع `app/core/social_auth_verify.py`)
- ⚠️ SMS verification **stub** (دايماً يرجع success)

---

## 3. تدفق الـ Onboarding للعميل (SME)

```mermaid
flowchart TD
    Login([User Logs In]) --> Launchpad["/app - Launchpad"]
    Launchpad --> ClickFinance[Click Finance Hub]
    ClickFinance --> EntitySetup["/settings/entities"]

    EntitySetup --> EntityForm[Enter: name, industry,<br/>country, tax ID]
    EntityForm --> CreateEntity[POST /clients]
    CreateEntity --> CoaWizard["/app/erp/finance/onboarding<br/>PilotOnboardingWizard"]

    CoaWizard --> Step1[Step 1: Upload COA File<br/>Excel / JSON]
    Step1 --> UploadAPI[POST /clients/-id-/coa/upload]
    UploadAPI --> StoreFile[(Store in S3/Local<br/>storage_backend)]
    StoreFile --> ParseJob[Parse Job Sprint 1]

    ParseJob --> Poll{Status?}
    Poll -- pending --> Wait[Frontend Polls]
    Wait --> Poll
    Poll -- error --> ErrorScreen[Show Parse Errors]
    ErrorScreen --> Step1
    Poll -- completed --> AccountsList[GET /coa/uploads/-id-/accounts]

    AccountsList --> Step2[Step 2: Auto-Classify<br/>Sprint 2]
    Step2 --> ClassifyAPI[POST /coa/uploads/-id-/classify]
    ClassifyAPI --> MLJob[ML classification<br/>SOCPA/IFRS]
    MLJob --> ReviewClass[User reviews<br/>confidence scores]

    ReviewClass --> NeedsOverride{Manual override?}
    NeedsOverride -- Yes --> OverrideAPI[PUT /coa/uploads/-id-/<br/>classifications/-account-]
    OverrideAPI --> ReviewClass
    NeedsOverride -- No --> Step3

    Step3[Step 3: Quality Check<br/>Sprint 3] --> QualityAPI[POST /coa/uploads/-id-/<br/>quality-check]
    QualityAPI --> Issues{Issues found?}
    Issues -- Yes --> AutoFix{Auto-fixable?}
    AutoFix -- Yes --> FixAPI[POST /coa/uploads/-id-/<br/>quality-fix]
    AutoFix -- No --> ManualFix[User fixes manually]
    FixAPI --> Step3
    ManualFix --> Step3
    Issues -- No --> Approval

    Approval[Reviewer Approval<br/>required] --> ApproveAPI[POST /coa/uploads/-id-/approve]
    ApproveAPI --> ApprovedFlag[(coa_approved_at = now)]

    ApprovedFlag --> Step4[Step 4: TB Binding<br/>Sprint 4 TB]
    Step4 --> UploadTB[Upload Trial Balance]
    UploadTB --> CreateTB[POST /tb/create]
    CreateTB --> BindAPI[POST /tb/-id-/bind-coa]
    BindAPI --> VarianceAPI[GET /tb/-id-/variance]
    VarianceAPI --> HasVariance{Variance found?}
    HasVariance -- Yes --> Reconcile[POST /tb/-id-/reconcile/-account-]
    Reconcile --> VarianceAPI
    HasVariance -- No --> ClosePeriod[POST /tb/-id-/close-period]

    ClosePeriod --> Step5[Step 5: Analysis Trigger<br/>Sprint 5]
    Step5 --> TriggerAnalysis[POST /analysis/trigger]
    TriggerAnalysis --> Done([Onboarding Complete])
    Done --> Reports[Reports + Statements ready]

    classDef stage fill:#dbeafe,stroke:#1e40af,color:#000
    classDef decision fill:#fef3c7,stroke:#d97706,color:#000
    classDef api fill:#e9d5ff,stroke:#7c3aed,color:#000
    classDef done fill:#d1fae5,stroke:#059669,color:#000

    class Step1,Step2,Step3,Step4,Step5 stage
    class Poll,NeedsOverride,Issues,AutoFix,HasVariance decision
    class UploadAPI,ClassifyAPI,QualityAPI,FixAPI,ApproveAPI,CreateTB,BindAPI,VarianceAPI,Reconcile,ClosePeriod,TriggerAnalysis api
    class Done,Reports done
```

---

## 4. تدفق الـ Marketplace (Provider + Client)

```mermaid
flowchart TD
    subgraph Provider["🟢 Provider"]
        P1[Provider Registers] --> P2["/admin/providers/documents"]
        P2 --> P3[Upload KYC Docs<br/>Phase 4]
        P3 --> P4[POST /providers/-id-/<br/>kyc/documents]
        P4 --> P5{Admin Reviews}
        P5 -- Reject --> P6[Resubmit]
        P5 -- Approve --> P7[POST /providers/-id-/<br/>aml/check]
        P7 --> P8{AML Pass?}
        P8 -- No --> P9[Provider Suspended]
        P8 -- Yes --> P10[Compliance Checklist]
        P10 --> P11[Status = verified]
        P11 --> P12[Can Bid + Submit KB]
    end

    subgraph Client["🔵 Client"]
        C1["/marketplace/catalog"] --> C2[Browse Services]
        C2 --> C3[Click Request Service]
        C3 --> C4[POST /services/request]
        C4 --> C5[ServiceRequest Created]
        C5 --> C6[Wait for Bids]
        C6 --> C7["/service-request-detail<br/>View Bids"]
        C7 --> C8[Compare + Select]
        C8 --> C9[POST /services/request/-id-/<br/>accept-bid]
    end

    subgraph BidLoop["💼 Bidding"]
        B1[Provider sees request] --> B2[POST /services/request/-id-/bid]
        B2 --> B3[(ServiceBid stored)]
    end

    subgraph Payment["💳 Payment"]
        Pay1[Stripe Checkout<br/>PAYMENT_BACKEND=stripe] --> Pay2{Paid?}
        Pay2 -- No --> Pay3[Cancel Order]
        Pay2 -- Yes --> Pay4[Order Active]
    end

    P12 --> B1
    C5 --> B1
    C9 --> Pay1
    Pay4 --> Deliver[Provider Delivers]
    Deliver --> Complete[Client Marks Complete]
    Complete --> Payout[Provider Paid<br/>net of commission]

    classDef stub fill:#fee2e2,stroke:#dc2626,color:#000
    classDef provider fill:#d1fae5,stroke:#059669,color:#000
    classDef client fill:#dbeafe,stroke:#1e40af,color:#000

    class P1,P2,P3,P4,P5,P6,P7,P8,P9,P10,P11,P12 provider
    class C1,C2,C3,C4,C5,C6,C7,C8,C9 client
    class P7 stub
```

> **ملاحظة:** AML check حالياً integration stub — لازم تربط بمزوّد فعلي للإنتاج.

---

## 5. تدفق Knowledge Brain + Copilot (AI)

```mermaid
flowchart LR
    User([User Asks Question]) --> ChatUI["/knowledge/brain<br/>or inline chat"]
    ChatUI --> AskAPI[GET /copilot/ask?q=...]

    AskAPI --> KeyCheck{ANTHROPIC_<br/>API_KEY set?}
    KeyCheck -- No --> Fallback[Hardcoded Fallback<br/>Response]
    Fallback --> Render

    KeyCheck -- Yes --> Embed[Anthropic Embeddings<br/>Semantic Search]
    Embed --> KbSearch[POST /kb/search]
    KbSearch --> Found{Match found?}

    Found -- Yes & high confidence --> Cite[Return KB Article<br/>+ Citations]
    Found -- Yes & low confidence --> Synth[Claude API Synthesis<br/>+ KB Context]
    Found -- No --> Synth
    Synth --> Cite

    Cite --> Render[Render Answer in UI]
    Render --> Rate{User Rates?}
    Rate -- 👍 --> SaveGood[POST /kb/rate helpful]
    Rate -- 👎 --> Feedback[POST /coa/<br/>knowledge-feedback]
    Feedback --> ReviewerQueue[Knowledge Reviewer Queue]
    ReviewerQueue --> AuthorRevise[KB Author Revises]

    SaveConv[POST /copilot/conversation] -.save history.-> SaveGood
    SaveConv -.-> Feedback

    classDef ai fill:#fce7f3,stroke:#be185d,color:#000
    classDef stub fill:#fee2e2,stroke:#dc2626,color:#000

    class Embed,Synth,KbSearch ai
    class Fallback stub
```

---

## 6. تدفق الإدارة (Platform Admin)

```mermaid
flowchart TD
    AdminLogin([Platform Admin Login]) --> Dashboard["/admin/dashboard<br/>Phase 6"]

    Dashboard --> Tabs{Action?}

    Tabs --> Users[User Management]
    Users --> ListUsers[GET /admin/users]
    Users --> AssignRole[POST /admin/users/-id-/role-assign]
    Users --> Suspend[POST /users/-id-/suspend]

    Tabs --> Providers[Provider Management]
    Providers --> ProvList["/admin/providers/verify"]
    Providers --> ApproveKyc[Approve KYC]
    Providers --> SetStatus[PUT /admin/providers/-id-/status]

    Tabs --> Audit[Audit & Compliance]
    Audit --> AuditLog[GET /admin/audit-log<br/>Phase 7 audit_chain]
    Audit --> Suspicious[GET /admin/activities/suspicious]

    Tabs --> AI[AI Console]
    AI --> AiInbox["/admin/ai-suggestions"]
    AI --> AiQueue["/admin/ai-suggestions-v2"]
    AI --> AiConsole["/admin/ai-console"]

    Tabs --> Policies[Policy & Legal<br/>Phase 11]
    Policies --> PolicyMgmt["/admin/policies"]
    Policies --> CreatePolicy[POST /admin/policies/create]
    Policies --> Supersede[POST /legal/supersede]

    Tabs --> Knowledge[Knowledge Governance<br/>Phase 3]
    Knowledge --> Reviewer["/admin/reviewer"]
    Knowledge --> ReviewQueue[GET /kb/pending-review]
    Knowledge --> ApproveKb[POST /kb/review/-id-]

    classDef admin fill:#fce7f3,stroke:#be185d,color:#000
    class Dashboard,Users,Providers,Audit,AI,Policies,Knowledge admin
```

---

## 7. هيكل الـ Backend (Phases + Sprints)

```mermaid
graph TB
    subgraph Phase1["Phase 1: Identity & Auth"]
        P1A[User / Role / Plan Models]
        P1B["/auth/* + /users/me + /plans + /legal"]
    end

    subgraph Phase2["Phase 2: Clients & COA"]
        P2A[Client / Branch / Entity Models]
        P2B["/clients/* + /onboarding/* + /archive"]
    end

    subgraph Phase3["Phase 3: Knowledge Governance"]
        P3A[KbSubmission / ReviewQueue]
        P3B["/kb/submit + /kb/review"]
    end

    subgraph Phase4["Phase 4: Provider Verification"]
        P4A[Provider / KYC / AML Models]
        P4B["/providers/* + /kyc + /aml"]
    end

    subgraph Phase5["Phase 5: Marketplace"]
        P5A[Service / ServiceRequest / Bid]
        P5B["/marketplace + /services/request"]
    end

    subgraph Phase6["Phase 6: Admin Console"]
        P6A[Audit dashboards + reporting]
        P6B["/admin/* routes"]
    end

    subgraph Phase7["Phase 7: Tasks & Audit Chain"]
        P7A[Task / Document / AuditChain]
        P7B["/tasks + /audit/chain"]
    end

    subgraph Phase8["Phase 8: Entitlements"]
        P8A[Entitlement / PlanLimit / AddOn]
        P8B["/entitlements + /subscriptions"]
    end

    subgraph Phase9["Phase 9: Account Center"]
        P9A[Profile / Sessions / Preferences]
        P9B["/account/* unified settings"]
    end

    subgraph Phase10["Phase 10: Notifications"]
        P10A[Notification / Template / Delivery]
        P10B["/notifications + WebSocket hub"]
    end

    subgraph Phase11["Phase 11: Legal Acceptance"]
        P11A[Versioned Policy / Acceptance Log]
        P11B["/legal/* GDPR-ready"]
    end

    subgraph Sprints["Sprints 1-6: COA Pipeline"]
        S1[S1: Upload + Parse]
        S2[S2: Classify ML]
        S3[S3: Quality Check]
        S4[S4: Knowledge Brain + TB Binding]
        S5[S5: Analysis Trigger]
        S6[S6: Registry + Eligibility]
    end

    Phase1 -.auth gate.-> Phase2
    Phase1 -.auth gate.-> Phase4
    Phase2 --> Sprints
    Phase4 --> Phase5
    Phase8 -.feature gate.-> Phase2
    Phase8 -.feature gate.-> Phase5
    Phase11 -.policy gate.-> Phase1
    Phase10 -.events.-> Phase2
    Phase10 -.events.-> Phase5
    Phase7 -.audit log.-> Phase2
    Phase7 -.audit log.-> Phase4

    classDef p1 fill:#fef3c7,stroke:#d97706
    classDef p2 fill:#dbeafe,stroke:#1e40af
    classDef p3 fill:#e9d5ff,stroke:#7c3aed
    classDef sprint fill:#d1fae5,stroke:#059669
    class Phase1 p1
    class Phase2,Phase8,Phase9 p2
    class Phase3,Phase11 p3
    class Sprints sprint
```

---

## 8. خريطة الراوتس (Frontend - 37 رئيسي)

```mermaid
mindmap
  root((APEX Routes))
    Auth_and_Account
      /login
      /register
      /forgot-password
      /profile/edit
      /password/change
      /account/close
      /account/sessions
      /account/mfa
    App_Shell
      /app launchpad
      /app/:service/apps
      /app/:service/:main/:chip
      /today
      /home
    Accounting
      /accounting/je-list
      /accounting/coa-v2
      /accounting/bank-rec-v2
      /accounting/period-close
      /app/erp/finance/je-builder
    Sales
      /sales/customers
      /sales/invoices
      /sales/payment
      /sales/aging
      /sales/recurring
      /sales/quotes
      /sales/memos
    Purchase
      /purchase/vendors
      /purchase/bills
      /purchase/aging
      /purchase/payment
    Operations
      /operations/inventory-v2
      /operations/fixed-assets-v2
      /operations/customer-360
      /operations/vendor-360
      /operations/pos-sessions
      /operations/consolidation-ui
      /operations/universal-journal
    Compliance_28_routes
      /compliance/zatca-invoice
      /compliance/zakat
      /compliance/vat-return
      /compliance/depreciation
      /compliance/payroll
      /compliance/ifrs-tools
      /compliance/islamic-finance
      and 21 more
    Analytics
      /analytics/budget-variance-v2
      /analytics/cash-flow-forecast
      /analytics/health-score-v2
      /analytics/multi-currency-v2
      /analytics/cost-variance-v2
      /analytics/project-profitability
    HR
      /hr/employees
      /hr/payroll-run
      /hr/expense-reports
      /hr/timesheet
    Admin
      /admin/dashboard
      /admin/reviewer
      /admin/providers/verify
      /admin/policies
      /admin/audit
      /admin/ai-console
    Knowledge
      /knowledge/brain
      /knowledge/feedback
      /knowledge/console
      /knowledge/search
    Onboarding
      /onboarding wizard
      /settings/entities
      /settings/unified
      /settings/bank-feeds
    Notifications_and_Legal
      /notifications/panel
      /notifications/prefs
      /legal documents
      /legal-acceptance
    Subscription
      /subscription
      /plans/compare
    Marketplace
      /marketplace/catalog
      /service-request-detail
      /provider/profile
```

---

## 9. الفجوات والـ Stubs الحالية

```mermaid
graph LR
    subgraph Stubs["⚠️ STUBS / TODOs"]
        S1[Social Auth<br/>Google/Apple<br/>token NOT verified]
        S2[SMS Verification<br/>always returns success]
        S3[Redis OTP Backend<br/>fallback to in-memory]
        S4[Bank OCR L4<br/>vendor matching]
        S5[AP Agent Processors<br/>logs only]
        S6[Invoice Creation AI<br/>ZATCA wiring WIP]
        S7[WhatsApp Notifications<br/>console only]
        S8[Multi-currency L4<br/>FX matching]
        S9[Period Close Lock<br/>partial enforcement]
        S10[Email-to-Invoice<br/>not implemented]
        S11[GraphQL API<br/>REST only]
        S12[Real-time Collab<br/>WebSocket limited]
    end

    classDef stub fill:#fee2e2,stroke:#dc2626,color:#000
    class S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12 stub
```

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
