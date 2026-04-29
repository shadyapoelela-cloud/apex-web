# APEX — الحالة المثالية (To-Be)

> مخطط APEX الكامل والمحسّن، مبني على **10 موجات بحث** عالمية على QuickBooks, Xero, Zoho Books, Wave, FreshBooks, NetSuite, Odoo, SAP, Stripe + معايير SaaS B2B 2026.

> **مبدأ التصميم**: في FinTech، الـ onboarding UX يبني الثقة بقدر ما يبني الاستخدام — كل خطوة لازم تطمئن المستخدم على بياناته (Wave 6).

---

## 1. النظرة الكلية المحسّنة

```mermaid
flowchart TD
    Start([🌐 Open APEX])

    subgraph EntryLayer["🚪 Entry Layer - Trust-First"]
        Start --> Lang{Language?}
        Lang --> Hero[Hero Page<br/>Trust signals + Social proof]
        Hero --> CTA{Action?}
    end

    subgraph AuthLayer["🔐 Authentication - Multi-method"]
        CTA -- Sign Up --> SignupHub[Signup Hub]
        CTA -- Sign In --> LoginHub[Login Hub]
        SignupHub --> Methods{Method?}
        Methods -- Email --> EmailReg[Email + Password<br/>+ Strength Meter]
        Methods -- Google --> GoogleVerified[✅ Real Token Validation]
        Methods -- Apple --> AppleVerified[✅ Real Token Validation]
        Methods -- SSO --> SSOFlow[SAML / OIDC<br/>JIT Provisioning]
        Methods -- Invite --> InviteFlow[Org Invite Link<br/>Auto-join Org]
    end

    subgraph OnboardingLayer["🚀 Smart Onboarding - AI Guided"]
        EmailReg --> AIGuide[AI Conversational Onboarding<br/>QuickBooks-style]
        GoogleVerified --> AIGuide
        AppleVerified --> AIGuide
        SSOFlow --> AIGuide
        InviteFlow --> RoleAssign[Auto-assigned Role]

        AIGuide --> Profile{Business Profile?}
        Profile -- New SME --> SMEFlow[SME Setup Wizard<br/>5-step + Progress Bar]
        Profile -- Accountant Firm --> FirmFlow[Multi-Client Hub<br/>FreshBooks-style]
        Profile -- Service Provider --> ProviderFlow[3-Mode Onboarding<br/>Stripe Connect-style]
    end

    subgraph CoreApp["💼 Core App - Adaptive Navigation"]
        SMEFlow --> AdaptiveNav[Role-Based Nav<br/>Multi-Role UX]
        FirmFlow --> AdaptiveNav
        ProviderFlow --> AdaptiveNav
        RoleAssign --> AdaptiveNav

        AdaptiveNav --> AppShell["/app Launchpad<br/>Personalized Today + Copilot"]
    end

    subgraph WorkflowLayer["⚙️ Workflow Layer"]
        AppShell --> Modules{Module?}
        Modules --> Finance[Finance Suite<br/>COA / TB / GL / JE]
        Modules --> Sales[Sales + AR<br/>Invoicing + Payments]
        Modules --> Purchase[Purchase + AP<br/>Bills + Approvals]
        Modules --> Operations[Operations<br/>Inventory + Assets + POS]
        Modules --> Compliance[Compliance Pack<br/>ZATCA + Zakat + VAT + IFRS]
        Modules --> Analytics[Analytics<br/>Forecast + Health Score]
        Modules --> HR[HR + Payroll]
        Modules --> Marketplace[Marketplace<br/>Services + Bids]
    end

    subgraph IntegrationLayer["🔌 Integration Layer"]
        Finance -.bank feeds.-> BankFeed[Bank Feeds<br/>Yodlee/Plaid]
        Sales -.OCR.-> Receipt[Receipt Capture<br/>Snap + Auto-fill]
        Purchase -.OCR.-> EmailInvoice[Email-to-Invoice<br/>Auto-extract]
        Compliance -.real-time.-> Zatca[ZATCA Live<br/>Production]
        AppShell -.AI.-> Copilot[Copilot AI<br/>Anthropic Claude]
    end

    subgraph GovernanceLayer["🛡️ Governance Layer"]
        AppShell -.events.-> Audit[Immutable Audit Chain]
        AppShell -.events.-> Notif[Multi-channel Notifications<br/>Email + SMS + WhatsApp + Push]
        AppShell -.events.-> Workflow[Workflow Automation<br/>Zoho-style Rules]
    end

    classDef trust fill:#10b981,stroke:#059669,color:#fff
    classDef ai fill:#fce7f3,stroke:#be185d,color:#000
    classDef adaptive fill:#dbeafe,stroke:#1e40af,color:#fff
    classDef integration fill:#fef3c7,stroke:#d97706,color:#000
    classDef governance fill:#ede9fe,stroke:#7c3aed,color:#000

    class Hero,EmailReg,GoogleVerified,AppleVerified,SSOFlow,InviteFlow trust
    class AIGuide,Copilot ai
    class AdaptiveNav,AppShell adaptive
    class BankFeed,Receipt,EmailInvoice,Zatca integration
    class Audit,Notif,Workflow governance
```

---

## 2. تدفق الـ Onboarding المحسّن (AI Guided + Trust-First)

> **مرجع البحث**: QuickBooks 2026 (AI conversational + Intuit Expert) + Stripe Connect (3 modes) + SaaS 2026 (gamification + JIT provisioning)

```mermaid
flowchart TD
    Start([User Signs Up]) --> WelcomeAI[AI Welcome<br/>أهلاً! خليني أساعدك تبدأ]

    WelcomeAI --> Discover[AI Asks 3 Questions:<br/>1- نوع نشاطك؟<br/>2- حجم الفريق؟<br/>3- اللي محتاجه أول؟]

    Discover --> Personalize[Personalize Setup Path]

    Personalize --> Path{Path?}

    Path -- SME New --> SMEPath[SME 5-Step Wizard]
    Path -- Existing Books --> ImportPath[Import from QB/Xero/Zoho]
    Path -- Accountant --> FirmPath[Firm Multi-Client Hub]

    subgraph SME5Step["📋 SME 5-Step Wizard"]
        S1[Step 1: Business Info<br/>Name + Tax ID + Country]
        S2[Step 2: COA Choice<br/>Template / Upload / Build]
        S3[Step 3: Bank Connect<br/>Yodlee/Plaid live]
        S4[Step 4: Team Invite<br/>Optional]
        S5[Step 5: First Transaction<br/>Quick Win!]
        S1 --> S2 --> S3 --> S4 --> S5
    end

    SMEPath --> SME5Step

    subgraph ImportFlow["⤵️ Migration Flow"]
        I1[Connect Source] --> I2[Map Accounts]
        I2 --> I3[Validate Balances]
        I3 --> I4[Confirm Import]
    end

    ImportPath --> ImportFlow

    subgraph FirmHub["🏢 Accountant Firm Hub"]
        F1[Firm Profile] --> F2[Add Clients]
        F2 --> F3[SSO to Client Books<br/>FreshBooks Hub style]
        F3 --> F4[Bulk Period Close]
    end

    FirmPath --> FirmHub

    SME5Step --> ProgressBar[Progress: 100%<br/>🎉 Gamified Reward]
    ImportFlow --> ProgressBar
    FirmHub --> ProgressBar

    ProgressBar --> Aha[Aha Moment<br/>First report generated!]
    Aha --> ExpertOffer{Need Expert Help?}
    ExpertOffer -- Yes --> BookExpert[Book Live Expert<br/>15-min free consult<br/>QuickBooks-style]
    ExpertOffer -- No --> Dashboard

    BookExpert --> Dashboard([🎯 Personalized Dashboard])

    classDef ai fill:#fce7f3,stroke:#be185d,color:#000
    classDef step fill:#dbeafe,stroke:#1e40af,color:#000
    classDef reward fill:#d1fae5,stroke:#059669,color:#000

    class WelcomeAI,Discover,Personalize,BookExpert ai
    class S1,S2,S3,S4,S5,I1,I2,I3,I4,F1,F2,F3,F4 step
    class ProgressBar,Aha,Dashboard reward
```

**التحسينات الرئيسية:**
- 🤖 **AI conversational onboarding** بدل النموذج المعقد (QuickBooks 2026)
- 📊 **Progress Bar + Gamification** (SaaS 2026 standard)
- 🏦 **Bank Auto-Connect** عبر Yodlee/Plaid (Wave/Xero pattern)
- ⤵️ **Migration from competitors** — استورد من QuickBooks/Xero/Zoho بضغطة
- 👨‍💼 **Live Expert booking** — 15 دقيقة مجاناً (QuickBooks Intuit Expert)
- 🏢 **Accountant Firm Hub** مع SSO بين العملاء (FreshBooks Accountant Hub)

---

## 3. تدفق الـ COA + TB المحسّن (Workflow Engine)

> **مرجع البحث**: Zoho Books (Workflow Rules + Approvals) + Odoo (Period Close) + SOCPA/IFRS standards

```mermaid
flowchart TD
    Start([Upload COA])

    Start --> Source{Source?}
    Source -- Excel/CSV --> Parser1[Standard Parser]
    Source -- JSON/API --> Parser2[API Sync]
    Source -- Existing Software --> Migrate[Migration Tool<br/>QB/Xero/Zoho]
    Source -- Template --> Template[Industry Templates<br/>Saudi/UAE/Kuwait/Egypt]

    Parser1 --> AIClassify[🤖 AI Auto-Classify<br/>+ Anomaly Detection]
    Parser2 --> AIClassify
    Migrate --> AIClassify
    Template --> AIClassify

    AIClassify --> Confidence{Confidence ≥ 95%?}
    Confidence -- Yes --> AutoApprove[Auto-Approve High Confidence]
    Confidence -- No --> ReviewQueue[Review Queue<br/>+ Reasoning]

    ReviewQueue --> RuleCheck{Workflow Rules Match?}
    RuleCheck -- Yes --> AutoRoute[Auto-Route to Reviewer<br/>Zoho-style]
    RuleCheck -- No --> ManualReview[Manual Review]

    AutoRoute --> Approve[Approve / Reject]
    ManualReview --> Approve
    AutoApprove --> COAFinal

    Approve --> COAFinal[(COA Locked + Versioned)]

    COAFinal --> TBLoop[TB Binding Loop]

    subgraph TBProcess["🔄 TB Reconciliation"]
        TB1[Auto-Match Accounts] --> TB2{Variance?}
        TB2 -- Within Tolerance --> TB3[Auto-Reconcile]
        TB2 -- Material --> TB4[Flag for Review]
        TB4 --> TB5[Reviewer Investigates]
        TB5 --> TB6[Mark Explained / Adjust]
        TB6 --> TB3
        TB3 --> TB7[All Reconciled]
    end

    TBLoop --> TBProcess

    TB7 --> ClosingEntries[🔒 Closing Entries<br/>Odoo-style auto-generate]
    ClosingEntries --> LockPeriod[Lock Period<br/>Audit Trail Frozen]

    LockPeriod --> Outputs[(Generate)]
    Outputs --> PnL[P&L Statement]
    Outputs --> BS[Balance Sheet]
    Outputs --> CF[Cash Flow]
    Outputs --> Compliance[Compliance Reports<br/>ZATCA / Zakat / VAT]

    classDef ai fill:#fce7f3,stroke:#be185d,color:#000
    classDef workflow fill:#fef3c7,stroke:#d97706,color:#000
    classDef lock fill:#fee2e2,stroke:#dc2626,color:#000

    class AIClassify,Confidence,AutoRoute ai
    class RuleCheck,TBProcess,TB1,TB2,TB3,TB4,TB5,TB6 workflow
    class ClosingEntries,LockPeriod lock
```

**التحسينات الرئيسية:**
- 🤖 **AI confidence threshold** — auto-approve عند ≥95% (يقلل الجهد اليدوي)
- 📋 **Workflow Rules Engine** بـ Zoho Books style (شروط + إجراءات + مسارات اعتماد)
- 🔄 **Auto-reconciliation tolerance** — variance صغير يتسوى تلقائياً
- 🔒 **Period close lock** كامل (Odoo pattern) — مايقدرش حد يعدّل في فترة مقفلة
- 📊 **Industry templates** عربية (Saudi/UAE/Kuwait/Egypt) — out of the box
- ⤵️ **Migration tools** — استيراد جاهز من QuickBooks/Xero/Zoho

---

## 4. الـ Marketplace المحسّن (Stripe Connect Style)

> **مرجع البحث**: Stripe Connect 3-mode onboarding + multi-org access (FreshBooks)

```mermaid
flowchart TD
    Start([Provider Joins])

    Start --> Mode{Onboarding Mode?}

    subgraph Hosted["🟢 Hosted - Default"]
        H1[APEX-hosted form<br/>Brand + Logo]
        H2[Auto-detect requirements]
        H3[Step-by-step KYC]
        H1 --> H2 --> H3
    end

    subgraph Embedded["🔵 Embedded - Whitelabel"]
        E1[Embed component<br/>in Provider's Site]
        E2[Themable UI]
        E3[Provider stays on their domain]
        E1 --> E2 --> E3
    end

    subgraph API["🟣 API - Custom"]
        A1[Provider builds own UI]
        A2[Uses APEX REST]
        A3[Full control]
        A1 --> A2 --> A3
    end

    Mode -- Default --> Hosted
    Mode -- Whitelabel --> Embedded
    Mode -- Custom UI --> API

    H3 --> KYCSubmit
    E3 --> KYCSubmit
    A3 --> KYCSubmit

    KYCSubmit[KYC Submission] --> KYCAuto{Auto-verifiable?}
    KYCAuto -- Yes Sumsub/Onfido --> AutoVerify[✅ Auto-Verify<br/>Real provider integration]
    KYCAuto -- No --> ManualReview[Manual Admin Review]

    AutoVerify --> AML[Real AML Check<br/>ComplyAdvantage / WorldCheck]
    ManualReview --> AML

    AML --> AmlResult{Pass?}
    AmlResult -- No --> Suspend[Provider Suspended<br/>+ Reason]
    AmlResult -- Yes --> Compliance[Compliance Checklist]

    Compliance --> Verified[✅ Provider Verified]

    Verified --> Active[Active in Marketplace]

    Active --> ServiceMgmt[Service Catalog Mgmt]
    ServiceMgmt --> Bidding[Live Bidding]
    Bidding --> Awarded{Bid Awarded?}
    Awarded -- Yes --> Escrow[💰 Escrow Payment<br/>Stripe Connect]
    Awarded -- No --> Bidding

    Escrow --> Deliver[Deliverables Tracked]
    Deliver --> Approval{Client Approves?}
    Approval -- Yes --> Release[Release Payment to Provider]
    Approval -- No --> Dispute[Dispute Resolution]
    Dispute --> Mediator[APEX Mediator]
    Mediator --> Release
    Mediator --> RefundClient[Refund Client]

    classDef stripeStyle fill:#635bff,stroke:#4f46e5,color:#fff
    classDef verify fill:#10b981,stroke:#059669,color:#fff
    classDef risk fill:#fee2e2,stroke:#dc2626,color:#000

    class Hosted,Embedded,API stripeStyle
    class AutoVerify,Verified,Release verify
    class Suspend,Dispute,RefundClient risk
```

**التحسينات الرئيسية:**
- 🚪 **3 onboarding modes** (Hosted / Embedded / API) — Stripe Connect pattern
- 🤖 **Real KYC automation** عبر Sumsub أو Onfido (مش stub)
- 🛡️ **Real AML** عبر ComplyAdvantage أو WorldCheck (مش stub)
- 💰 **Escrow Payment** — الفلوس محتجزة لحد التسليم (يحمي الطرفين)
- ⚖️ **Dispute Resolution** — وسيط من APEX

---

## 5. Adaptive Navigation - حسب الدور

> **مرجع البحث**: Multi-Role UX (Wave 10) — "Permissions defined by task, not feature"

```mermaid
flowchart LR
    Login([Login]) --> RoleDetect{Role?}

    RoleDetect -- registered_user --> NavFree[Basic Nav:<br/>- /app<br/>- /profile<br/>- /upgrade]

    RoleDetect -- client_user --> NavClient[Client Nav:<br/>- Finance<br/>- Sales/Purchase<br/>- Reports<br/>- Notifications]

    RoleDetect -- client_admin --> NavClientAdmin[+ Team Mgmt<br/>+ Billing<br/>+ Audit Trail<br/>+ Multi-entity]

    RoleDetect -- accountant_firm --> NavFirm[Firm Hub:<br/>- All Clients Grid<br/>- Bulk Operations<br/>- Period Close All<br/>- Firm Reports]

    RoleDetect -- provider --> NavProvider[Provider Nav:<br/>- Marketplace<br/>- My Services<br/>- Bids<br/>- Earnings<br/>- KB Contributions]

    RoleDetect -- reviewer --> NavReviewer[Reviewer Nav:<br/>- Review Queue<br/>- Approval History<br/>- KB Moderation]

    RoleDetect -- platform_admin --> NavAdmin[Admin Nav:<br/>- Dashboard<br/>- Users / Providers<br/>- Audit / Policy<br/>- AI Console<br/>- Reports]

    RoleDetect -- super_admin --> NavSuper[+ DB Migrations<br/>+ Feature Flags<br/>+ Emergency Tools<br/>+ Tenant Mgmt]

    classDef role fill:#dbeafe,stroke:#1e40af,color:#000
    class NavFree,NavClient,NavClientAdmin,NavFirm,NavProvider,NavReviewer,NavAdmin,NavSuper role
```

**القاعدة الذهبية**: لا تُظهر زر لمستخدم لا يقدر يستخدمه. شريط التنقل يتغيّر بناءً على:
- الدور (Role)
- الخطة (Plan / Entitlements)
- الـ Onboarding state (هل أنهى الإعداد؟)
- الفترة المحاسبية (هل مفتوحة أم مقفلة؟)

---

## 6. Workflow Automation Engine (Zoho Books Pattern)

```mermaid
flowchart TD
    Trigger([Event Trigger])

    Trigger --> EventType{Event?}

    EventType -- Invoice Created --> Inv[Invoice Workflow]
    EventType -- Payment Received --> Pay[Payment Workflow]
    EventType -- COA Updated --> Coa[COA Workflow]
    EventType -- TB Closed --> TB[Period Close Workflow]
    EventType -- Anomaly Detected --> Anom[Anomaly Workflow]

    Inv --> Rule1{Match Rules?}
    Pay --> Rule2{Match Rules?}
    Coa --> Rule3{Match Rules?}
    TB --> Rule4{Match Rules?}
    Anom --> Rule5{Match Rules?}

    Rule1 -- Yes --> Action1[Action: Notify CFO if amount > 100K]
    Rule2 -- Yes --> Action2[Action: Auto-reconcile + thank you email]
    Rule3 -- Yes --> Action3[Action: Re-classify + notify reviewer]
    Rule4 -- Yes --> Action4[Action: Generate reports + email summary]
    Rule5 -- Yes --> Action5[Action: Pause + escalate to admin]

    Action1 --> Audit[(Log to Audit Chain)]
    Action2 --> Audit
    Action3 --> Audit
    Action4 --> Audit
    Action5 --> Audit

    Audit --> Notify[Multi-channel Notification<br/>Email + SMS + WhatsApp + In-app + Push]

    classDef trigger fill:#fef3c7,stroke:#d97706,color:#000
    classDef rule fill:#dbeafe,stroke:#1e40af,color:#000
    classDef action fill:#d1fae5,stroke:#059669,color:#000

    class Trigger trigger
    class Rule1,Rule2,Rule3,Rule4,Rule5 rule
    class Action1,Action2,Action3,Action4,Action5 action
```

**خصائص المحرّك المحسّن:**
- 📋 **Custom Rules Builder** — UI no-code (Zoho-style)
- 🔁 **Approval Chains** — multi-level approvals
- 📜 **Scripting Hook** — لمن يحتاج logic معقّد (Deluge-like)
- 🎯 **Trigger Library** — 50+ event triggers جاهزة
- 📊 **Workflow Analytics** — كم مرة شغّلت rule X، نتائجها

---

## 7. Multi-Channel Notifications المحسّن

```mermaid
flowchart LR
    Event[System Event] --> Engine[Notification Engine]

    Engine --> Prefs[Read User Preferences]
    Prefs --> Channels{Selected Channels?}

    Channels --> InApp[In-App<br/>WebSocket Real-time]
    Channels --> Email[Email<br/>SendGrid Production]
    Channels --> SMS[SMS<br/>Twilio Real]
    Channels --> WA[WhatsApp<br/>Business API Real]
    Channels --> Push[Push<br/>FCM/APNs]
    Channels --> Slack[Slack<br/>Webhook]
    Channels --> Teams[Teams<br/>Webhook]

    InApp --> Center["/notifications<br/>Notification Center"]
    Email --> Track[Open / Click Tracking]
    SMS --> Track
    WA --> Track
    Push --> Track
    Slack --> Track
    Teams --> Track

    Track --> Analytics[(Analytics:<br/>delivered, opened, clicked)]

    classDef channel fill:#dbeafe,stroke:#1e40af,color:#000
    classDef new fill:#d1fae5,stroke:#059669,color:#000

    class InApp,Email,SMS,Push channel
    class WA,Slack,Teams new
```

**مكتمل في النموذج المثالي:**
- ✅ SMS عبر **Twilio** فعلي (مش stub)
- ✅ WhatsApp عبر **WhatsApp Business API** فعلي
- ✅ Push عبر **FCM/APNs**
- ✅ Slack + Teams webhooks (ميزة جديدة)
- ✅ Open/Click tracking + Analytics

---

## 8. الـ Modules الجديدة (Odoo-Style App Marketplace)

> Odoo عنده 80+ app — APEX يقدر يفعّل modules حسب الخطة

```mermaid
graph TB
    subgraph Core["✅ Core - Always On"]
        CoreFin[Finance / GL / COA]
        CoreSales[Sales + AR]
        CoreBuy[Purchase + AP]
        CoreUsers[Users + Auth]
    end

    subgraph Pro["💎 Pro - Subscription"]
        ProInv[Inventory + Stock]
        ProAssets[Fixed Assets + Depreciation]
        ProPOS[POS + Multi-location]
        ProMulti[Multi-currency + FX]
        ProConsol[Consolidation - Multi-entity]
    end

    subgraph Compliance["📋 Compliance Pack"]
        ZATCA[ZATCA Saudi]
        ZAKAT[Zakat]
        VAT[VAT + GCC]
        IFRS[IFRS Tools]
        SOCPA[SOCPA]
        TaxCal[Tax Calendar]
        Islamic[Islamic Finance]
    end

    subgraph Industry["🏭 Industry Packs"]
        Pharm[Pharmacy + Drug Inventory]
        Construction[Construction + WIP]
        Healthcare[Healthcare + Insurance Claims]
        Education[Education + Tuition]
        Retail[Retail + Multi-store]
        Manufacturing[Manufacturing + BOM]
        Restaurant[Restaurant + Recipes]
    end

    subgraph AI["🤖 AI Modules"]
        Copilot[Copilot AI]
        OCR[OCR + Receipt Capture]
        EmailAI[Email-to-Invoice]
        Anomaly[Anomaly Detection]
        Forecast[Cash Flow Forecast AI]
        Audit[AI Audit Workflow]
    end

    subgraph Future["🚀 Roadmap"]
        Banking[Embedded Banking]
        Lending[Working Capital Loans]
        Cards[Corporate Cards]
        Invest[Investment Mgmt]
        Crypto[Crypto Accounting]
        DAO[DAO Treasury]
    end

    classDef core fill:#10b981,stroke:#059669,color:#fff
    classDef pro fill:#3b82f6,stroke:#1d4ed8,color:#fff
    classDef compliance fill:#f59e0b,stroke:#d97706,color:#000
    classDef industry fill:#8b5cf6,stroke:#6d28d9,color:#fff
    classDef ai fill:#ec4899,stroke:#be185d,color:#fff
    classDef future fill:#64748b,stroke:#334155,color:#fff

    class Core core
    class Pro pro
    class Compliance compliance
    class Industry industry
    class AI ai
    class Future future
```

---

## 9. AI-First Copilot (مكتمل)

```mermaid
flowchart TD
    User([User]) --> Inputs{Input Type?}

    Inputs -- Text Question --> Q[Text Query]
    Inputs -- Voice --> Voice[Voice → STT<br/>Whisper API]
    Inputs -- Screenshot --> Vision[Image → Vision<br/>Claude Vision]
    Inputs -- Document --> Doc[PDF/Excel → Parser]

    Q --> Intent[Intent Detection]
    Voice --> Intent
    Vision --> Intent
    Doc --> Intent

    Intent --> Type{Intent?}
    Type -- Question --> Search[KB Semantic Search]
    Type -- Action --> Plan[Plan Multi-step Action]
    Type -- Analysis --> Analyze[Run Financial Analysis]
    Type -- Forecast --> Forecast[Cash Flow Forecast]

    Search --> RAG[RAG: KB + User's Books]
    Plan --> Approve{User Approves?}
    Approve -- Yes --> Execute[Execute Tool Calls<br/>Create Invoice / Reconcile / etc]
    Approve -- No --> Cancel
    Execute --> Audit[(Log to Audit)]

    RAG --> Synth[Claude Synthesis]
    Analyze --> Synth
    Forecast --> Synth

    Synth --> Output[Structured Response]
    Output --> Display[UI: Cards + Charts + Citations]

    Display --> Followup{Follow-up?}
    Followup -- Yes --> Q
    Followup -- No --> End([End])

    classDef ai fill:#fce7f3,stroke:#be185d,color:#000
    classDef action fill:#d1fae5,stroke:#059669,color:#000

    class Voice,Vision,Intent,Search,Plan,Analyze,Forecast,RAG,Synth ai
    class Execute,Audit action
```

**ميزات Copilot المكتمل:**
- 🎤 **Voice-first** — اتكلم بالعربي والـ Copilot يفهم
- 👁️ **Vision** — صوّر إيصال أو جدول، يفهمه ويصنّفه
- 🔧 **Tool calling** — ينفّذ مهام (إنشاء فاتورة، تسوية بنكية) بعد موافقتك
- 📊 **RAG على دفاتر العميل** — مش بس KB، كمان بيانات حساباتك
- 🔮 **Forecasting AI** — توقّع التدفّق النقدي + سيناريوهات

---

## 10. الفجوات المُسدّة (مقارنة بالواقع الحالي)

```mermaid
graph LR
    subgraph Before["⚠️ الواقع الحالي"]
        B1[Social Auth STUB]
        B2[SMS STUB]
        B3[AML STUB]
        B4[WhatsApp Console]
        B5[Bank OCR L4 missing]
        B6[Email-to-Invoice missing]
        B7[Period Lock partial]
        B8[Real-time Collab limited]
    end

    subgraph After["✅ الحالة المثالية"]
        A1[Real Google/Apple verify]
        A2[Twilio SMS Production]
        A3[ComplyAdvantage AML]
        A4[WhatsApp Business API]
        A5[Yodlee/Plaid + ML matching]
        A6[Email parser + Auto-create]
        A7[Full lock with overrides]
        A8[Y.js / CRDT collab]
    end

    B1 --> A1
    B2 --> A2
    B3 --> A3
    B4 --> A4
    B5 --> A5
    B6 --> A6
    B7 --> A7
    B8 --> A8

    classDef before fill:#fee2e2,stroke:#dc2626,color:#000
    classDef after fill:#d1fae5,stroke:#059669,color:#000

    class B1,B2,B3,B4,B5,B6,B7,B8 before
    class A1,A2,A3,A4,A5,A6,A7,A8 after
```

التفاصيل والـ priorities في **[`04-gap-analysis.md`](04-gap-analysis.md)**.
