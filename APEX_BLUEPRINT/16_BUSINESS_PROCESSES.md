# 16 — Business Processes / العمليات التجارية الكاملة

> Reference: continues from `15_DDD_BOUNDED_CONTEXTS.md`. Next: `17_STATE_MACHINES.md`.
> **Goal:** End-to-end business process diagrams for every major financial cycle, mapped to APEX implementation.

---

## Process Catalog / فهرس العمليات

| Code | Process EN | Process AR | APEX Module |
|------|-----------|-----------|-------------|
| **O2C** | Order-to-Cash | من الطلب إلى التحصيل | Sales + Pilot |
| **P2P** | Procure-to-Pay | من الشراء إلى الدفع | Purchase + Pilot |
| **R2R** | Record-to-Report | من التسجيل إلى التقرير | Accounting + Compliance |
| **H2R** | Hire-to-Retire | من التوظيف إلى التقاعد | HR + Payroll |
| **A2R** | Audit-to-Report | من المراجعة إلى التقرير | Audit |
| **P2P_M** | Plan-to-Produce (Manufacturing) | التخطيط للإنتاج | Operations + Inventory |
| **F2C** | Forecast-to-Cash | من التوقع إلى النقد | FP&A + Treasury |
| **I2I** | Invoice-to-Inquire (Tax) | الفاتورة الإلكترونية | ZATCA Compliance |
| **L2C** | Lead-to-Close (Sales CRM) | من العميل المحتمل للإغلاق | CRM (future) |
| **C2C** | Close-to-Compliance | من الإقفال إلى الامتثال | Period Close + Tax |

---

## 1. Order-to-Cash (O2C) / من الطلب إلى التحصيل

```mermaid
flowchart TB
    START([Customer expresses intent]) --> Q[1. Quote / عرض سعر<br/>/sales/quotes<br/>POST quote draft]
    Q -->|Approved by customer| SO[2. Sales Order / أمر البيع<br/>convert quote → SO]
    SO --> CRED{Credit check?}
    CRED -->|Pass| FUL[3. Fulfillment<br/>pick + pack + ship<br/>or service delivery]
    CRED -->|Fail| HOLD[Credit hold]
    HOLD -->|Approved| FUL

    FUL --> INV[4. Sales Invoice / فاتورة البيع<br/>POST /api/v1/pilot/sales-invoices]
    INV --> ZAT{ZATCA enabled?}
    ZAT -->|Yes| ZATCA[4a. ZATCA clearance<br/>POST /zatca/invoice/build<br/>PCSID sign + UBL XML + TLV QR]
    ZAT -->|No| SEND[Send PDF/email to customer]
    ZATCA --> SEND

    SEND --> AR[(AR Open<br/>tracked in /sales/aging)]
    AR --> REM{Overdue?}
    REM -->|Yes| REMINDER[5. Dunning / تذكيرات<br/>auto-email after 7/14/30 days]
    REM -->|No| WAIT
    WAIT --> PAY[6. Customer Payment<br/>POST /api/v1/pilot/customer-payments]
    REMINDER --> PAY

    PAY --> ALLOC[7. Allocate to invoice<br/>match payment ↔ invoice]
    ALLOC --> RECON[8. Bank Reconciliation<br/>/accounting/bank-rec-v2]
    RECON --> CLOSE[9. AR closed<br/>invoice status: paid]
    CLOSE --> GL[(GL: dr Cash<br/>cr AR)]
    GL --> MTRC[10. Update KPIs<br/>DSO, AR aging, top customers]

    classDef api fill:#fff3cd
    class INV,ZATCA,PAY,RECON api
    classDef state fill:#d1e7dd
    class AR,GL state
```

### Key APEX touchpoints
| Step | Screen | API |
|------|--------|-----|
| 1 | `/sales/quotes` | `POST /api/v1/pilot/quotes` |
| 4 | `/sales/invoices` | `POST /api/v1/pilot/sales-invoices` + `/issue` |
| 4a | (background) | `POST /zatca/invoice/build` |
| 6 | `/sales/payment/{invoiceId}` | `POST /api/v1/pilot/customer-payments` |
| 8 | `/accounting/bank-rec-v2` | `POST /bank-rec/compute` |

### Ratios computed
- DSO (Days Sales Outstanding) = AR ÷ daily revenue
- Cash conversion cycle
- AR turnover

---

## 2. Procure-to-Pay (P2P) / من الشراء إلى الدفع

```mermaid
flowchart TB
    START([Need identified]) --> PR[1. Purchase Requisition / طلب شراء<br/>/operations/purchase-cycle]
    PR -->|Manager approval| RFQ[2. RFQ / طلب عرض أسعار<br/>send to 3+ vendors]
    RFQ --> COMP[3. Compare bids<br/>price/quality/lead-time]
    COMP --> PO[4. Purchase Order / أمر شراء<br/>POST /api/v1/pilot/purchase-orders]
    PO --> APP{Approval?}
    APP -->|Manager| APP2{Director if >50K?}
    APP -->|≤5K| AUTO[Auto-approved]
    APP2 -->|Yes| BOARD{CFO if >500K?}
    APP2 -->|No| ISS[Issue PO to vendor]
    BOARD -->|Yes| CEO[CEO/Board approval]
    BOARD -->|No| ISS
    AUTO --> ISS
    CEO --> ISS

    ISS --> RECV[5. Goods Receipt / استلام البضاعة<br/>POST /api/v1/pilot/goods-receipts]
    RECV --> INSP[6. Inspection<br/>quality check]
    INSP -->|Accepted| GRNI[(GRNI Accrual<br/>dr Inventory<br/>cr GRNI)]
    INSP -->|Rejected| RTV[Return to vendor]

    GRNI --> BILL[7. Vendor Bill / فاتورة المورد<br/>POST /api/v1/pilot/purchase-invoices]
    BILL --> MATCH[8. 3-Way Match<br/>PO ↔ Receipt ↔ Bill]
    MATCH -->|Match| POST[9. Post bill<br/>POST /...purchase-invoices/{id}/post]
    MATCH -->|Mismatch| EXC[Exception queue]
    EXC -->|Resolved| POST

    POST --> AP[(AP Open<br/>tracked in /purchase/aging)]
    AP --> SCHED[10. Payment scheduling<br/>by due date + early discount]
    SCHED --> PAY[11. Vendor Payment<br/>POST /api/v1/pilot/vendor-payments<br/>via SAMA / wire / check]
    PAY --> RECON[12. Bank reconciliation]
    RECON --> CLOSE[13. AP closed<br/>bill status: paid]
    CLOSE --> GL[(GL: dr AP<br/>cr Cash)]

    classDef api fill:#fff3cd
    class PO,RECV,BILL,POST,PAY api
```

### 3-Way Match Algorithm
```
For each Bill line:
  Find matching PO line by item + price + qty
  Find matching Receipt by PO line
  Tolerance:
    Price variance ≤ 2% OR ≤ 100 SAR
    Qty variance: 0 (exact)
  If all match → auto-post
  Else → exception queue
```

---

## 3. Record-to-Report (R2R) / من التسجيل إلى التقرير

```mermaid
flowchart TB
    DAILY[Daily transactions<br/>via O2C / P2P / Payroll<br/>auto-generate JEs]
    DAILY --> GL[(General Ledger<br/>app/pilot/journal_entries)]

    MID[Mid-month] --> BANKREC[1. Bank Reconciliation<br/>weekly cadence]
    BANKREC --> GL

    MEND[Month-end / إقفال الشهر] --> ACCRUAL[2. Accruals<br/>unbilled revenue<br/>unbilled expenses<br/>GRNI]
    ACCRUAL --> DEP[3. Depreciation<br/>POST /depreciation/compute<br/>auto-post JE per asset class]
    DEP --> AMORT[4. Amortization<br/>prepaid expenses<br/>intangibles<br/>POST /amortization/compute]
    AMORT --> FX[5. FX Revaluation<br/>foreign currency balances<br/>spot rate from API]
    FX --> ALLOC[6. Allocations<br/>shared services<br/>cost center distribution]
    ALLOC --> ELIM[7. Inter-company elim<br/>multi-entity only]
    ELIM --> ADJ[8. Manual adjustments<br/>by accountant]

    ADJ --> TB[9. Trial Balance<br/>GET /api/v1/pilot/entities/{id}/trial-balance]
    TB --> CHECK{TB balanced?<br/>Σ debit = Σ credit}
    CHECK -->|No| ADJ
    CHECK -->|Yes| FS[10. Financial Statements]

    FS --> IS[Income Statement<br/>/compliance/financial-statements]
    FS --> BS[Balance Sheet]
    FS --> CF[Cash Flow Statement]
    FS --> EQ[Equity Changes]
    FS --> NOTES[Notes & disclosures]

    IS --> RATIO[11. Ratios<br/>POST /ratios/compute]
    BS --> RATIO
    CF --> RATIO

    RATIO --> VAR[12. Variance Analysis<br/>actual vs budget vs PY]
    VAR --> EXEC[13. Executive Dashboard<br/>/compliance/executive]
    EXEC --> SIGN[14. Sign-off]
    SIGN --> LOCK[15. Lock period<br/>POST /period-close/lock]
    LOCK --> ARCH[(Archived for 10 years<br/>SOCPA requirement)]

    classDef state fill:#d1e7dd
    class GL,TB,FS,ARCH state
    classDef compute fill:#fff3cd
    class DEP,AMORT,FX,RATIO compute
```

### Period Close Calendar Template (5-day close)

| Day | Activity | Owner |
|-----|----------|-------|
| -3 | Cutoff communication | Controller |
| -1 | Last day for invoices | All |
| 0 | Period ends | — |
| +1 | Bank rec, AR/AP confirms, accruals draft | Staff |
| +2 | Depreciation, amortization, FX reval | Staff |
| +3 | TB review, intercompany match, adjustments | Senior |
| +4 | FS draft, variance analysis, KAM identified | Manager |
| +5 | Partner review, sign-off, period lock | Partner |

---

## 4. Hire-to-Retire (H2R) / من التوظيف إلى التقاعد

```mermaid
flowchart TB
    REQ[1. Hiring Requisition] --> POST[2. Job posting<br/>internal + external boards]
    POST --> APP[3. Applicants apply]
    APP --> SCREEN[4. Screening + interviews]
    SCREEN --> OFFER[5. Offer letter]
    OFFER -->|Accepted| ONBOARD[6. Onboarding / إدخال موظف<br/>/hr/employees<br/>POST /api/v1/employees]

    ONBOARD --> CONTRACT[7. Contract + Saudization<br/>Nitaqat tracking]
    CONTRACT --> GOSI[8. GOSI registration<br/>Saudi: GOSI portal<br/>UAE: MOHRE]
    GOSI --> PAYROLL_SETUP[9. Payroll setup<br/>bank account + WPS file]

    PAYROLL_SETUP --> CYCLE[10. Monthly payroll cycle / الرواتب الشهرية]

    subgraph "Monthly Payroll"
        CYCLE --> TS[10a. Timesheet<br/>/hr/timesheet<br/>collect hours]
        TS --> EXP[10b. Expense reports<br/>/hr/expense-reports<br/>collect + approve]
        EXP --> COMP[10c. Compute / حساب<br/>POST /payroll/compute<br/>basic + housing + transport - GOSI - tax]
        COMP --> REV[10d. Review by HR Manager]
        REV --> APP_PAY[10e. Approve payment]
        APP_PAY --> WPS[10f. Generate WPS file<br/>SIF format]
        WPS --> BANK[10g. Submit to bank]
        BANK --> JE[10h. Auto-post JE<br/>dr Wages Expense<br/>cr Cash<br/>cr GOSI Payable]
    end

    JE --> END_MONTH[Continue cycle...]

    CYCLE --> BENEFIT[11. Benefits admin<br/>medical, ticket, schooling]
    CYCLE --> LEAVE[12. Leave management]
    CYCLE --> PERF[13. Performance review<br/>annual]

    PERF --> RAISE[Salary review]
    PERF --> PROMO[Promotion]
    PERF --> DEV[Development plan]

    DEV --> END{Termination event?}
    END -->|Resign| EOSB[14a. EOSB calculation<br/>/eosb-demo<br/>Saudi formula]
    END -->|Termination| EOSB
    END -->|Retirement| RETIRE[14b. Retirement formalities]

    EOSB --> CLEAR[15. Clearance + final settlement]
    CLEAR --> ARCH[(Employee archive)]
    RETIRE --> ARCH
```

### EOSB Formula (Saudi Labor Law)
```
First 5 years: 0.5 month salary per year
After 5 years: 1 full month per year
If resignation: 
  < 2 years → 0
  2-5 years → 1/3 of EOSB
  5-10 years → 2/3 of EOSB
  > 10 years → full EOSB
```

---

## 5. Audit-to-Report (A2R) / من المراجعة إلى التقرير

```mermaid
flowchart TB
    ENG[1. Engagement Letter / خطاب الارتباط<br/>/audit/engagements<br/>POST /audit/cases]
    ENG --> ACCEPT[2. Acceptance / قبول الارتباط<br/>independence check<br/>conflict check<br/>capacity check]
    ACCEPT --> TEAM[3. Team Assignment<br/>Partner · Manager · Senior · Staff · EQR]
    TEAM --> PLAN[4. Planning / التخطيط<br/>ISA 300]

    PLAN --> RA[5. Risk Assessment / تقييم المخاطر<br/>ISA 315<br/>/compliance/risk-register]
    RA --> MAT[6. Materiality / الأهمية النسبية<br/>ISA 320<br/>5% PBT or 1% revenue]
    MAT --> PROG[7. Audit Program<br/>procedures library 200+]

    PROG --> TB_IMP[8. Import client TB+GL<br/>POST /tb/uploads<br/>bind to CoA]
    TB_IMP --> ANALYTICS[9. Analytics / تحليلات<br/>Benford, outliers, duplicates<br/>POST /ai/benford/analyze]
    ANALYTICS --> SAMP[10. Sampling / العينات<br/>ISA 530<br/>MUS / stratified / random]

    SAMP --> WALK[11. Walkthroughs<br/>inquiry + observation +<br/>inspection + re-perform]
    WALK --> TOC[12. Tests of Controls / اختبار الضوابط<br/>design + operating effectiveness]
    TOC -->|Effective| SUBSTANTIVE_REDUCED[Substantive: reduced]
    TOC -->|Ineffective| SUBSTANTIVE_FULL[Substantive: full]

    SUBSTANTIVE_REDUCED --> TOD[13. Tests of Details<br/>per cycle + assertion]
    SUBSTANTIVE_FULL --> TOD

    TOD --> WP[14. Workpapers<br/>preparer + reviewer sign-off<br/>POST /audit/workpapers/{id}/review]
    WP --> FIND[15. Findings / الملاحظات<br/>MW / SD / MLI<br/>POST /audit/findings]

    FIND --> REVIEW[16. Review hierarchy / مراجعات]
    REVIEW --> MGRREV[Manager review]
    MGRREV --> PARTREV[Partner review]
    PARTREV --> EQR{EQR required?}
    EQR -->|Listed/PIE| EQRREV[EQR concurrence]
    EQR -->|Otherwise| OPINION
    EQRREV --> OPINION[17. Form Opinion / إبداء الرأي<br/>ISA 700<br/>Unmodified / Qualified / Adverse / Disclaimer]

    OPINION --> REP[18. Audit Report<br/>SOCPA template<br/>+ KAM + Other Info]
    REP --> ML[19. Management Letter / خطاب الإدارة<br/>findings + recommendations]
    ML --> ARCH[20. Archive 10 years<br/>SOCPA Article 16]

    classDef plan fill:#cfe2ff
    class PLAN,RA,MAT,PROG plan
    classDef field fill:#fff3cd
    class TB_IMP,ANALYTICS,SAMP,WALK,TOC,TOD,WP field
    classDef report fill:#d1e7dd
    class OPINION,REP,ML,ARCH report
```

---

## 6. Plan-to-Produce (P2P_M) / التخطيط للإنتاج

```mermaid
flowchart TB
    DEMAND[1. Demand Forecast<br/>sales projections]
    DEMAND --> MPS[2. Master Production Schedule]
    MPS --> MRP[3. Material Requirements Planning<br/>BOM explosion]
    MRP --> PR[4. Auto-generate PRs<br/>for materials]
    PR -->|loops back to P2P| END[Continue with P2P process]
    MRP --> WO[4b. Work Orders / أوامر التشغيل]
    WO --> PROD[5. Production / الإنتاج<br/>raw materials → WIP]
    PROD --> QC[6. Quality Control]
    QC -->|Pass| FG[(Finished Goods<br/>inventory)]
    QC -->|Fail| REWORK[Rework / scrap]
    FG --> SHIP[7. Ship / available for sale]
    SHIP -->|loops back to O2C| END
```

(For APEX: Manufacturing not in current scope but architecture should accommodate Phase 2 industries.)

---

## 7. Forecast-to-Cash (F2C) / من التوقع إلى النقد

```mermaid
flowchart LR
    FCST[1. 13-Week Cash Forecast<br/>/analytics/cash-flow-forecast] --> SCEN[2. Scenarios / السيناريوهات<br/>best · expected · worst]
    SCEN --> AR[3. AR Collections / تحصيلات]
    SCEN --> AP[4. AP Payments / مدفوعات]
    AR & AP --> NET[5. Net cash position]
    NET --> ALERT{Below threshold?}
    ALERT -->|Yes| LIQ[6. Liquidity actions:<br/>accelerate AR<br/>delay AP<br/>draw line of credit<br/>FX hedge]
    LIQ --> SOURCE[7. Funding source]
    SOURCE --> END
    ALERT -->|No| INVEST[6b. Excess cash invest]
    INVEST --> END[Update next forecast]
```

---

## 8. Invoice-to-Inquire (ZATCA Phase 2) / دورة الفاتورة الإلكترونية

```mermaid
sequenceDiagram
    autonumber
    actor U as Accountant
    participant FE as Flutter
    participant API as APEX
    participant CSID as CSID Manager
    participant FATOORA as ZATCA Fatoora

    U->>FE: Issue invoice
    FE->>API: POST /api/v1/pilot/sales-invoices/{id}/issue
    API->>API: Generate UBL 2.1 XML
    API->>API: SHA-256 of XML
    API->>CSID: ECDSA sign
    CSID-->>API: Cryptographic stamp
    API->>API: Build TLV QR (9 fields)
    
    alt Standard B2B (≥1000 SAR)
        API->>FATOORA: POST /clearance
        FATOORA-->>API: 200 + UUID + cleared XML
        API->>API: Store cleared
        API->>FE: ✓ Cleared
    else Simplified B2C (<1000 SAR)
        API->>API: Mark issued (no real-time)
        API->>FE: ✓ Issued
        Note over API: Async report within 24h
        API->>FATOORA: POST /reporting (batch)
        FATOORA-->>API: Reported
    end

    FE->>U: Show invoice + QR
    U->>FE: Print PDF
    FE->>U: PDF with QR + UUID
```

---

## 9. Close-to-Compliance (C2C) / من الإقفال إلى الامتثال

```mermaid
flowchart TB
    PERIOD_LOCK[Period locked] --> VAT_PERIOD{End of VAT period?}
    VAT_PERIOD -->|Monthly >40M revenue| VAT[1. VAT Return<br/>/compliance/vat-return<br/>POST /tax/vat/return]
    VAT_PERIOD -->|Quarterly| VAT
    VAT --> ZATCA_FILE[2. File to ZATCA portal<br/>before 28th of next month]
    ZATCA_FILE --> PAY_VAT[3. Pay VAT due<br/>via SADAD]

    PERIOD_LOCK --> WHT_PERIOD{End of month?}
    WHT_PERIOD -->|Yes| WHT[4. WHT computation<br/>/compliance/wht-v2]
    WHT --> WHT_FILE[5. File WHT to ZATCA]

    PERIOD_LOCK --> YEAR_END{Fiscal year end?}
    YEAR_END -->|Yes| ZAKAT[6. Zakat declaration<br/>/compliance/zakat<br/>POST /tax/zakat/compute<br/>2.5% × adjusted base]
    ZAKAT --> ZAKAT_FILE[7. File within 4 months<br/>of FY-end]

    YEAR_END -->|Yes| AUDIT_PREP[8. Audit preparation<br/>archive support docs<br/>signed FS]
    AUDIT_PREP -->|loops to A2R| END

    YEAR_END -->|Yes| CORP_TAX{Foreign-owned?}
    CORP_TAX -->|Yes| TAX_RET[9. Corporate tax return<br/>20% on foreign share]
    CORP_TAX -->|No| ZAKAT

    classDef compliance fill:#fff3cd
    class VAT,WHT,ZAKAT,TAX_RET compliance
```

---

## 10. Cross-Process Touchpoints / نقاط الاتصال

```mermaid
graph LR
    O2C --> R2R
    P2P --> R2R
    H2R --> R2R
    R2R --> A2R
    O2C --> I2I
    R2R --> C2C
    F2C -.feeds.-> R2R
    A2R -.feedback.-> R2R
```

---

## Process Maturity Targets / أهداف نضج العمليات

| Process | Today (estimated) | 6mo target | 12mo target |
|---------|-------------------|------------|-------------|
| O2C | Manual + partial automation | Full O2C automation | Predictive AR |
| P2P | Manual | 3-way match | AP automation + AI |
| R2R | 10-day close | 5-day close | 3-day close |
| H2R | Basic payroll | Full HR | HR+performance+L&D |
| A2R | Skeleton | Full audit module | AI-assisted audit |
| C2C | ZATCA Phase 2 KSA | + UAE FTA + Egypt ETA | + multi-jurisdiction |

---

**Continue → `17_STATE_MACHINES.md`**
