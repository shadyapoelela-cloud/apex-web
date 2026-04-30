# 01 — Architecture Overview / نظرة عامة على البنية المعمارية

> Reference: Continues from `00_MASTER_INDEX.md`. Next: `02_USER_JOURNEYS_FLOWCHART.md`.

---

## 1. High-Level System Architecture / البنية على المستوى العالي

```mermaid
graph TB
    subgraph "Browser / المتصفح"
        FE[Flutter Web App<br/>Riverpod + GoRouter<br/>Arabic RTL Primary]
    end

    subgraph "CDN / الشبكة"
        GH[GitHub Pages<br/>Frontend Static]
    end

    subgraph "API Layer / طبقة API"
        FA[FastAPI Backend<br/>11 Phases + 6 Sprints<br/>213 Endpoints]
        MW[Middleware<br/>CORS · TenantContext · ErrorHandler · RateLimit]
    end

    subgraph "Auth Layer"
        JWT[JWT HS256<br/>Access 60min · Refresh 30d]
        RBAC[RBAC<br/>5 Roles × 5 Plans]
    end

    subgraph "Data Layer / طبقة البيانات"
        PG[(PostgreSQL<br/>Production)]
        SQ[(SQLite<br/>Dev/Test)]
        KB[(Knowledge Brain<br/>Separate DB)]
    end

    subgraph "External Services / الخدمات الخارجية"
        AN[Anthropic Claude<br/>Copilot · KB · Insights]
        ST[Stripe<br/>Payments · Subscriptions]
        SG[SendGrid / SMTP<br/>Email]
        TW[Twilio / Unifonic<br/>SMS]
        S3[AWS S3<br/>File Storage]
        ZA[ZATCA<br/>e-Invoicing Saudi]
    end

    FE -->|HTTPS + Bearer JWT| FA
    GH -.->|Serves| FE
    FA --> MW
    MW --> JWT
    JWT --> RBAC
    FA --> PG
    FA --> SQ
    FA --> KB
    FA --> AN
    FA --> ST
    FA --> SG
    FA --> TW
    FA --> S3
    FA --> ZA

    classDef external fill:#fff3cd,stroke:#856404
    class AN,ST,SG,TW,S3,ZA external
    classDef frontend fill:#cfe2ff,stroke:#084298
    class FE,GH frontend
    classDef backend fill:#d1e7dd,stroke:#0f5132
    class FA,MW,JWT,RBAC backend
    classDef data fill:#f8d7da,stroke:#842029
    class PG,SQ,KB data
```

---

## 2. Backend Layered Architecture / البنية الخلفية الطبقية

```mermaid
graph TB
    subgraph "Entry / الدخول"
        MAIN[app/main.py<br/>FastAPI App + Lifespan]
    end

    subgraph "Middleware Pipeline"
        M1[CORS Middleware]
        M2[TenantContextMiddleware<br/>Extracts tenant_id]
        M3[ErrorHandler]
        M4[RequestLogger]
        M5[RateLimit]
    end

    subgraph "Routers — Phases / المراحل"
        P1[Phase 1<br/>Auth · Users · Plans · Legal]
        P2[Phase 2<br/>Clients · COA · Audit Cases]
        P3[Phase 3<br/>Knowledge Feedback]
        P4[Phase 4<br/>Service Provider Verification]
        P5[Phase 5<br/>Marketplace · Compliance]
        P6[Phase 6<br/>Admin Dashboard]
        P7[Phase 7<br/>Tasks · Provider Compliance]
        P8[Phase 8<br/>Subscription Entitlements]
        P9[Phase 9<br/>Account Center]
        P10[Phase 10<br/>Notifications V2]
        P11[Phase 11<br/>Legal Acceptance]
    end

    subgraph "Routers — Sprints"
        S1[Sprint 1<br/>COA Upload Integration]
        S2[Sprint 2<br/>COA Classification + Mapping]
        S3[Sprint 3<br/>COA Quality + Rule Engine]
        S4[Sprint 4<br/>Concept Graph + Rules]
        S4TB[Sprint 4 TB<br/>Trial Balance Binding]
        S5[Sprint 5<br/>Financial Analysis]
        S6[Sprint 6<br/>Reference Registry]
    end

    subgraph "Service Layer / طبقة الخدمات"
        AUTH_SVC[AuthService<br/>JWT · password · TOTP]
        COA_SVC[CoaService<br/>Parse · Classify · Approve]
        TB_SVC[TbBindingService]
        ANALYSIS_SVC[AnalysisService]
        COPILOT_SVC[CopilotService<br/>Anthropic wrapper]
        ZATCA_SVC[ZatcaService<br/>UBL · TLV · CSID]
        NOTIF_SVC[NotificationService<br/>WS · Email · SMS]
        AUDIT_SVC[AuditLogService]
    end

    subgraph "Data Access / الوصول للبيانات"
        ORM[SQLAlchemy 2.0 ORM]
        REPO[Repository Pattern<br/>per phase]
        MIG[Alembic Migrations<br/>configured but unused]
    end

    MAIN --> M1 --> M2 --> M3 --> M4 --> M5
    M5 --> P1 & P2 & P3 & P4 & P5 & P6 & P7 & P8 & P9 & P10 & P11
    M5 --> S1 & S2 & S3 & S4 & S4TB & S5 & S6
    P1 --> AUTH_SVC
    P2 --> COA_SVC
    S4TB --> TB_SVC
    S5 --> ANALYSIS_SVC
    P10 --> NOTIF_SVC
    AUTH_SVC --> ORM
    COA_SVC --> ORM
    ORM --> REPO
```

**Key conventions / القواعد الأساسية:**
- Each phase router is conditionally loaded in `app/main.py` via `try/except` flags (`HAS_P1`, `HAS_P2`, … `HAS_P11`).
- All phase models live in `app/phaseN/models/`.
- All phase routes live in `app/phaseN/routes/`.
- Services live in `app/phaseN/services/` and import models from same phase.
- `app/core/auth_utils.py` is the **single source of truth** for `JWT_SECRET`.

---

## 3. Frontend Layered Architecture / البنية الأمامية الطبقية

```mermaid
graph TB
    subgraph "Entry / الدخول"
        ENTRY[main.dart<br/>App + ProviderScope + MaterialApp.router]
    end

    subgraph "Routing"
        ROUTER[lib/core/router.dart<br/>858 lines · 70+ GoRoutes]
        V4[lib/core/v4/<br/>V4 group routes]
        V5[lib/core/v5/<br/>V5 dynamic /app/:service/:main/:chip]
    end

    subgraph "State / الحالة"
        SESSION[S Singleton<br/>core/session.dart<br/>token · uid · plan · entity]
        THEME[AC Singleton<br/>core/theme.dart<br/>12 themes]
        RP[Riverpod Providers<br/>auth · settings · clients · plans · notifications]
    end

    subgraph "API / الواجهة"
        API[ApiService<br/>api_service.dart · 1000+ LOC<br/>150+ methods]
        CFG[api_config.dart<br/>Base URL]
        RETRY[api_retry.dart<br/>Exponential backoff]
    end

    subgraph "Screens / الشاشات"
        AUTH[auth/<br/>Login · Register · ForgotPw]
        HOME[home/<br/>Launchpad · ServiceHub]
        SVC[Service screens<br/>sales · purchase · accounting<br/>compliance · audit · analytics<br/>hr · operations · workflow]
        ADM[admin/<br/>Reviewer · Audit · AI Console]
        ACC[account/<br/>Profile · Sessions · MFA]
    end

    subgraph "Shared UI"
        WIDGETS[widgets/<br/>HybridSidebar · BottomNav<br/>Cards · Tables · Forms]
        ASK[apex_ask_panel.dart<br/>Copilot Chat]
        TICKER[apex_news_ticker.dart]
    end

    ENTRY --> ROUTER
    ROUTER --> V4 & V5
    ROUTER -.uses.-> SESSION
    SESSION -.persisted to.-> LS[(localStorage)]
    THEME -.applied via.-> ENTRY
    V5 -->|builds screen for| SVC
    V4 -->|legacy shell| SVC
    SVC --> API
    API --> CFG & RETRY
    SVC -.imports.-> WIDGETS
    SVC -.uses.-> ASK
    SVC -.reads.-> RP
    RP --> API
```

**Key conventions:**
- `lib/main.dart` is monolithic (3500 lines) — **DO NOT add new classes there**. New screens → `lib/screens/{service}/`.
- All API calls go through `ApiService`.
- All theming via `AC.*` (no hardcoded colors).
- All session reads via `S.*` (no direct `localStorage` reads).
- Arabic strings hardcoded; future migration to ARB l10n is in `09_GAPS_AND_REWORK_PLAN.md`.

---

## 4. Authentication & Authorization Flow / التحقق والتصريح

```mermaid
sequenceDiagram
    participant U as User<br/>المستخدم
    participant FE as Flutter Web
    participant API as FastAPI
    participant SVC as AuthService
    participant DB as Database
    participant JWT as JWT Encoder

    U->>FE: Enter credentials
    FE->>API: POST /auth/login
    API->>SVC: authenticate(email, pwd)
    SVC->>DB: SELECT user WHERE email
    DB-->>SVC: user record
    SVC->>SVC: bcrypt.verify(pwd, hash)
    SVC->>JWT: encode(uid, roles, plan)
    JWT-->>SVC: access_token (60m)<br/>refresh_token (30d)
    SVC-->>API: {access, refresh, user}
    API-->>FE: 200 + tokens
    FE->>FE: S.token = access<br/>localStorage.set(apex_token)
    FE-->>U: Redirect to /app

    Note over U,DB: Subsequent request

    U->>FE: Click protected screen
    FE->>API: GET /clients<br/>Authorization: Bearer {access}
    API->>SVC: get_current_user(token)
    SVC->>JWT: decode(token)
    JWT-->>SVC: payload {uid, roles, plan}
    SVC->>DB: SELECT user (verify still active)
    DB-->>SVC: user
    SVC-->>API: User object
    API->>API: route handler runs<br/>checks role/plan if needed
    API-->>FE: 200 + data
```

**Permission enforcement layers:**
1. **JWT decode** — token signature must match `JWT_SECRET`
2. **`get_current_user` dependency** — extracts user from header or `apex_token` cookie
3. **Manual role check** — `if "client_admin" not in current_user.roles: raise 403`
4. **Admin secret** — admin endpoints require `X-Admin-Secret` header (`ADMIN_SECRET` env)
5. **Tenant isolation** — `TenantContextMiddleware` injects `tenant_id`; queries filter by it
6. **Plan entitlement** — `entitlements/me` returns feature limits; UI gates accordingly

Full matrix in `06_PERMISSIONS_AND_PLANS_MATRIX.md`.

---

## 5. Multi-Tenancy Model / نموذج تعدد المستأجرين

```mermaid
graph TB
    U[User / مستخدم] -->|owns| T1[Tenant A<br/>Accounting Firm]
    U -->|member of| T2[Tenant B<br/>Other Firm]
    T1 --> E1[Entity 1<br/>Client Co. X]
    T1 --> E2[Entity 2<br/>Client Co. Y]
    T2 --> E3[Entity 3<br/>Self-employed]
    E1 --> COA1[COA · TB · JE · Reports]
    E2 --> COA2[COA · TB · JE · Reports]
    E3 --> COA3[COA · TB · JE · Reports]

    classDef user fill:#cfe2ff
    class U user
    classDef tenant fill:#d1e7dd
    class T1,T2 tenant
    classDef entity fill:#fff3cd
    class E1,E2,E3 entity
```

**Scoping rules:**
- `S.tenantId` and `S.entityId` set after onboarding
- Every Pilot ERP endpoint scoped by `entity_id` path param
- `TenantContextMiddleware` rejects cross-tenant access
- A user can be in multiple tenants with different roles per tenant (`UserRole` table)

---

## 6. Data Flow: COA → TB → Financial Statements
## تدفق البيانات: دليل الحسابات ← ميزان المراجعة ← القوائم المالية

```mermaid
flowchart LR
    UPLOAD[1. Upload COA<br/>Excel/CSV] --> PARSE[2. Parse<br/>column mapping]
    PARSE --> CLASSIFY[3. AI Classify<br/>Anthropic Claude]
    CLASSIFY --> ASSESS[4. Quality Assess<br/>Rule Engine]
    ASSESS --> APPROVE[5. Approve<br/>Bulk or per-account]
    APPROVE --> COASTATE[(COA<br/>state: approved)]
    COASTATE --> TBUPLOAD[6. Upload TB]
    TBUPLOAD --> TBBIND[7. Bind TB to COA<br/>auto-match]
    TBBIND --> TBAPPROVE[8. Approve Binding]
    TBAPPROVE --> TBSTATE[(Bound TB)]
    TBSTATE --> JE[9. JE Entries<br/>auto-balanced]
    TBSTATE --> ANALYSIS[10. Run Analysis<br/>Sprint 5]
    JE --> POSTING[(Posted Ledger)]
    POSTING --> FS_GEN[11. Generate FS<br/>P&L · BS · CF]
    ANALYSIS --> FS_GEN
    FS_GEN --> ZATCA_OUT[12. ZATCA Invoice]
    FS_GEN --> AUDIT_PKG[13. Audit Package<br/>Workpapers]
    FS_GEN --> EXEC_DASH[14. Executive Dashboard]
```

**Endpoint chain (full):**
```
POST /coa/uploads                           → CoaUpload row
POST /coa/uploads/{id}/parse                → CoaAccount rows
POST /coa/classify/{id}                     → Anthropic enrichment
POST /coa/uploads/{id}/assess               → quality score
POST /coa/bulk-approve/{id}                 → state=approved
POST /tb/uploads                            → TbUpload row
POST /tb/uploads/{tb_id}/bind               → bind to COA
POST /tb/uploads/{tb_id}/approve-binding    → bound state
POST /je/build                              → balanced JE
POST /analysis/full                         → FullAnalysis row
GET  /api/v1/pilot/entities/{id}/income-statement
GET  /api/v1/pilot/entities/{id}/balance-sheet
GET  /api/v1/pilot/entities/{id}/cash-flow
POST /zatca/invoice/build                   → UBL XML + TLV QR
```

---

## 7. AI Integration Topology / طوبولوجيا تكامل الذكاء الاصطناعي

```mermaid
graph LR
    subgraph "Frontend Triggers"
        ASK[Copilot Panel<br/>apex_ask_panel.dart]
        CLASSIFY_BTN[Classify COA Button]
        ANALYZE_BTN[Analyze TB Button]
        AI_AUDIT[AI Audit Workflow]
    end

    subgraph "Backend Services"
        COPILOT_SVC[CopilotService<br/>chat · sessions · intent]
        COA_AI[CoaClassificationService<br/>account name → category]
        BENFORD[BenfordService]
        ANOMALY[AnomalyDetectionService]
        WORKPAPER_AI[Audit Workpaper<br/>Generator]
    end

    subgraph "Anthropic Claude API"
        CLAUDE[claude-sonnet-4-6<br/>Tool use · System prompts]
    end

    subgraph "Knowledge Brain"
        KB_DB[(Concept Graph<br/>Rules<br/>Domain knowledge)]
    end

    subgraph "Fallback"
        FALLBACK[Hardcoded Templates<br/>activated when ANTHROPIC_API_KEY missing]
    end

    ASK --> COPILOT_SVC
    CLASSIFY_BTN --> COA_AI
    ANALYZE_BTN --> BENFORD & ANOMALY
    AI_AUDIT --> WORKPAPER_AI

    COPILOT_SVC -->|via Knowledge Brain context| KB_DB
    COPILOT_SVC --> CLAUDE
    COA_AI --> CLAUDE
    WORKPAPER_AI --> CLAUDE

    CLAUDE -.timeout/missing key.-> FALLBACK
    COPILOT_SVC -.fallback.-> FALLBACK
```

**Key files:**
- `app/copilot/services/copilot_service.py` — chat orchestration
- `app/sprint4/services/concept_graph_service.py` — KB context retrieval
- `app/phase2/services/coa_classification_service.py` — AI classification
- `app/sprint5_analysis/services/benford_service.py` — anomaly detection

---

## 8. ZATCA Integration Pipeline / خط أنابيب تكامل ZATCA

```mermaid
sequenceDiagram
    participant FE as Flutter UI
    participant API as FastAPI
    participant ZS as ZatcaService
    participant CSID as CSID Manager
    participant SIGN as Cryptographic Stamp
    participant FATOORA as ZATCA Fatoora API

    Note over FE,FATOORA: Initial Onboarding (per device)

    FE->>API: POST /zatca/csid/request<br/>otp from Fatoora portal
    API->>ZS: registerDevice(otp)
    ZS->>FATOORA: compliance CSID request
    FATOORA-->>ZS: CCSID (sandbox)
    ZS->>FATOORA: send sample invoices
    FATOORA-->>ZS: validation result
    ZS->>FATOORA: production CSID request
    FATOORA-->>ZS: PCSID (live)
    ZS->>API: store PCSID
    API-->>FE: device registered ✓

    Note over FE,FATOORA: Per-Invoice Flow (Phase 2)

    FE->>API: POST /zatca/invoice/build<br/>{seller, buyer, lines, vat}
    API->>ZS: buildUbl(invoice_data)
    ZS->>ZS: generate UBL 2.1 XML
    ZS->>ZS: compute SHA256 hash
    ZS->>SIGN: ECDSA sign hash
    SIGN-->>ZS: cryptographic stamp
    ZS->>ZS: build TLV QR code (9 fields)
    ZS->>FATOORA: clear/report invoice
    FATOORA-->>ZS: cleared XML + UUID
    ZS-->>API: {xml, qr, uuid, status}
    API-->>FE: invoice ready
```

**Files:**
- `app/zatca/services/zatca_service.py`
- `app/zatca/services/csid_manager.py`
- `app/zatca/services/ubl_builder.py`
- `app/zatca/services/qr_tlv.py`

---

## 9. Notifications & Audit Log Topology

```mermaid
graph LR
    subgraph "Sources"
        SRC1[Login event]
        SRC2[Approval action]
        SRC3[Subscription change]
        SRC4[ZATCA result]
        SRC5[Period close task]
    end

    subgraph "Audit Log"
        LOG[AuditEvent table<br/>append-only<br/>hash-chained]
    end

    subgraph "Notification Engine"
        NS[NotificationService]
        PREF[User Preferences<br/>per type: in-app · email · sms]
    end

    subgraph "Channels"
        WS[WebSocket<br/>in-app real-time]
        EM[Email<br/>SendGrid/SMTP]
        SM[SMS<br/>Twilio/Unifonic]
    end

    SRC1 --> LOG
    SRC2 --> LOG
    SRC3 --> LOG
    SRC4 --> LOG
    SRC5 --> LOG

    LOG --> NS
    NS --> PREF
    PREF -->|in-app| WS
    PREF -->|email| EM
    PREF -->|sms| SM
```

**Files:**
- `app/phase10/services/notification_service.py`
- `app/core/audit_log.py`

---

## 10. Deployment Topology / طوبولوجيا النشر

```mermaid
graph TB
    DEV[Developer Push] -->|main branch| GH[GitHub]
    GH -->|Actions: lint+test| CI[CI Pipeline<br/>Black · Ruff · Bandit · pytest]
    CI -->|pass| DEPLOY[Deploy Stage]

    DEPLOY --> R[Render.com<br/>Backend · Free tier · Cold-start]
    DEPLOY --> P[GitHub Pages<br/>Frontend · Static hosting]

    R --> RDB[(Render PostgreSQL<br/>or external Neon)]
    R --> RANTHROPIC[Anthropic API]
    R --> RZATCA[ZATCA API]
    R --> RSTRIPE[Stripe API]

    P --> CDN[Public CDN<br/>github.io domain]
    CDN -.calls.-> R

    classDef dev fill:#cfe2ff
    class DEV,GH,CI dev
    classDef prod fill:#d1e7dd
    class R,P,CDN prod
    classDef ext fill:#fff3cd
    class RANTHROPIC,RZATCA,RSTRIPE ext
```

**Cold-start mitigation (Render free tier):**
- Frontend has retry logic in `lib/core/api_retry.dart`
- First request after 15-min idle takes ~30s
- Health check `/health` runs every 5min via cron-job.org (config in `render.yaml`)

---

## 11. Environment Variables Reference

| Variable | Layer | Purpose | Production Required? |
|----------|-------|---------|----------------------|
| `JWT_SECRET` | Backend | JWT signing | **YES** (32+ chars) |
| `ADMIN_SECRET` | Backend | Admin endpoint auth | **YES** |
| `CORS_ORIGINS` | Backend | Allowed origins | **YES** (no `*`) |
| `DATABASE_URL` | Backend | Postgres connection | **YES** |
| `KB_DATABASE_URL` | Backend | Knowledge Brain DB | Optional |
| `ANTHROPIC_API_KEY` | Backend | Claude API | Required for AI |
| `EMAIL_BACKEND` | Backend | `console`/`smtp`/`sendgrid` | YES |
| `SMTP_*` or `SENDGRID_API_KEY` | Backend | Email creds | YES if email |
| `PAYMENT_BACKEND` | Backend | `mock`/`stripe` | YES |
| `STRIPE_SECRET_KEY` | Backend | Stripe API | YES if stripe |
| `STORAGE_BACKEND` | Backend | `local`/`s3` | YES |
| `S3_BUCKET`, `AWS_*` | Backend | S3 creds | YES if s3 |
| `ZATCA_BASE_URL` | Backend | Fatoora endpoint | YES if Phase 2 |
| `ZATCA_CSID_*` | Backend | Per-device CSID | YES if Phase 2 |
| `ENVIRONMENT` | Backend | `development`/`production` | YES |
| `API_BASE` | Frontend | Backend URL | YES (build-time `--dart-define`) |

Full list in `.env.example`.

---

## 12. Architecture Decisions / قرارات معمارية

### Why Phase-based instead of feature-modules?
**EN:** APEX evolved iteratively; each phase added a vertical slice (auth → clients → COA → providers → marketplace, etc.). Phases are conditionally loadable, allowing partial deployments.

**Trade-off:** Some functional overlap (e.g., `/compliance/journal-entries` and `/accounting/je-list` historically existed in two phases — now deduplicated via redirects in Phase 26).

**Future direction:** Continue phase pattern but enforce ownership:
- Each phase owns its DB tables (no cross-phase FK chains except to `User`)
- Each phase has its own router prefix where possible
- Cross-cutting concerns (auth, audit, notifications) live in `app/core/`

### Why monolithic main.dart?
**EN:** Initial speed; classes added inline. **THIS IS A KNOWN GAP** — see `09_GAPS_AND_REWORK_PLAN.md` for splitting plan.

**Rule going forward:** new screens → `lib/screens/{service}/{screen_name}_screen.dart`.

### Why two router systems (V4, V5)?
**EN:** V5 (current) is dynamic service-based. V4 is older group-based. Both coexist for backward compatibility. Long-term: deprecate V4 once all routes proven via V5.

---

**Continue → `02_USER_JOURNEYS_FLOWCHART.md`**
