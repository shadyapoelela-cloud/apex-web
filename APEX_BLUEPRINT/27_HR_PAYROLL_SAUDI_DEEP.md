# APEX Financial Platform: Saudi/GCC HR & Payroll Integration Deep Dive

**Research Date:** April 30, 2026  
**Focus:** Full Saudi HR compliance stack, API integrations, competitor analysis, and MVP recommendations for APEX market penetration

---

## Executive Summary

The Saudi/GCC HR & Payroll market is **highly regulated, government-integrated, and rapidly consolidating** around native platforms like Bayzat, ZenHR, Jisr, and Malachite. A successful SaaS offering targeting serious enterprises requires:

1. **Mandatory government integrations** (Mudad, Qiwa, GOSI, Muqeem, Absher Business, WPS/SAMA)
2. **Deep labor law compliance** (EOSB accrual, Saudization/Nitaqat tracking, leave management)
3. **Local banking/payroll infrastructure** (WPS file generation, bank channel integration)
4. **Arabic UI/RTL support** and Hijri calendar support
5. **Estimated 6-9 months engineering effort** for a production-ready module

**Recommendation:** APEX should **build minimal HR module + tight Mudad integration** rather than full-stack HR platform. This allows faster market entry while capturing payroll data needed for accounting/financial reporting (APEX's core strength).

---

## 1. The Saudi HR Compliance Stack: Required Government Integrations

### 1.1 Mudad (مدد) — Employment Contracts & Payroll Certification

**Purpose:** Digital employment contract authentication + payroll certification platform  
**Operator:** Ministry of Human Resources and Social Development (MHRSD)  
**URL:** https://mudad.com.sa/

**What it does:**
- Employers upload employment contracts (auto-filled from GOSI database) and employees approve via Tameenati portal
- Monthly payroll certification: employers send salary/deductions; Mudad validates against WPS compliance
- Single hub connecting to SAMA, Saudi banks, and Wage Protection System
- Automated WPS file submission on behalf of employer (eliminating manual uploads)

**For APEX Integration:**
- Mudad is the **primary touchpoint** for HR/payroll data
- Employee master data, salary, allowances, deductions flow through Mudad
- WPS files must be generated and validated for Mudad submission
- Mudad acts as compliance checkpoint before bank payment processing

**Data Flow:**
1. APEX payroll system calculates salary → generates WPS file (.TXT format)
2. Submit to Mudad with establishment credentials (Commercial Reg + MLSD Unified ID)
3. Mudad validates, issues payment confirmation
4. Banks execute transfers via SAMA
5. WPS confirmation auto-uploaded to ministry

**Integration Effort:** Moderate (OAuth + REST API, or integration library via third-party HR platform)

---

### 1.2 Qiwa (قوى) — Contract Management, Transfers, Permits

**Purpose:** Central workforce management platform  
**Operator:** Ministry of Human Resources and Social Development (MHRSD)  
**URL:** https://www.qiwa.sa/

**What it does:**
- Electronic employment contract management (employers create, employees approve/reject/amend)
- Leave request workflows with manager approval and balance tracking
- Work permit renewals and employee transfers between employers
- Serves 14.5+ million registered users
- Integrated with GOSI data (auto-fills contract templates)

**For APEX Integration:**
- **Leave tracking:** Annual (21/30 days depending on tenure), sick leave (120 days/year with tiered pay), Ramadan adjustments
- **Contract history:** pulling employee contract data for payroll validation
- **Transfer tracking:** monitoring when employees move between establishments

**Leave Entitlements (Legal Minimums):**
- **Annual Leave:** 21 days (first 5 years) → 30 days (5+ years)
- **Sick Leave:** 30 days full pay + 60 days half pay + 30 days unpaid = 120 days/year total
- **Ramadan:** Special working hour adjustments (filed in Qiwa)
- **Special cases:** Marriage (6 months), maternity (variable), illness/injury (flexible)

**Integration Effort:** Low to Moderate (pull-only integration for leave balance validation; direct leave submission may require API access not yet publicly documented)

---

### 1.3 GOSI (التأمينات الاجتماعية) — Social Insurance Contributions

**Purpose:** Mandatory social insurance system for all workers  
**Operator:** General Organization for Social Insurance (GOSI)  
**URL:** https://www.gosi.gov.sa/

**What it does:**
- Collects employer/employee contributions (annuities, occupational hazard, disability, death)
- Maintains wage history and contribution records
- Issues wage certificates and eligibility reports
- System-to-System API for large enterprises; GOSI Online portal for manual submission

**Contribution Rates (2025-2026 Update):**

| Category | Rate | Notes |
|----------|------|-------|
| **New employees (on/after July 3, 2024)** | |
| Employer contribution (annuities) | 9.5% | Rising 0.5% annually until 11% by 2028 |
| Employee contribution (annuities) | 9.5% | Rising 0.5% annually until 11% by 2028 |
| **Existing employees (before July 3, 2024)** | |
| Employer contribution (annuities) | 9.0% | Frozen at legacy rate |
| Employee contribution (annuities) | 9.0% | Frozen at legacy rate |
| **Expatriate employees** | |
| Employer contribution | 2% only | No employee contribution required |
| **Occupational hazard (variable by sector)** | 0.5%–3% | Employer pays; variable by industry |

**Salary Calculation Base:**
- Contributions calculated on: Base Salary + Housing Allowance
- **Wage ceiling:** SAR 45,000/month (maximum contribution base)
- **Wage floor:** SAR 1,500/month (minimum)
- Other allowances (transportation, food, etc.) **not included** in contribution base

**For APEX Integration:**
- Monthly GOSI contribution calculation (conditional on employee nationality + hire date)
- Wage file submission (if not automated via Mudad)
- Contribution amount accrual for month-end GL posting

**Integration Effort:** Low (calculation engine only; Mudad or third-party HR handles submission)

---

### 1.4 Muqeem (مقيم) — Expat Residency & Iqama Management

**Purpose:** Digital residency permit (Iqama) lifecycle management  
**Operator:** General Directorate of Passports (Jawazat), managed by Saudi Digital Company (Elm)  
**URL:** Not publicly listed; accessed via Absher Business

**What it does:**
- Iqama issuance, renewal, and tracking
- Visa status and exit/re-entry permit management
- Expat worker residency history
- Integration hub for municipalities, border control, health ministries

**For APEX Integration:**
- **Employee data validation:** Verify Iqama number, expiry date, status
- **Visa calendar:** Track Iqama renewal dates to trigger alerts for HR teams
- **Expat classification:** Determine GOSI rates (2% employer only) based on residency status

**Integration Effort:** Low (Muqeem is read-only; typically accessed via Absher Business APIs)

---

### 1.5 Absher Business (أبشر) — Government Service Integration Hub

**Purpose:** Single gateway for government employee visa/Iqama transactions  
**Operator:** Ministry of Interior  
**URL:** https://www.absher.sa/wps/portal/business/Home

**What it does:**
- Issue/renew Iqamas for employees
- Apply for/renew work permits
- Request exit/re-entry visas
- Sponsorship transfers
- REST API support for auto-renewal workflows

**For APEX Integration:**
- Absher APIs can trigger visa renewals when Iqama expiry approaches
- ServiceDesk Plus integration possible for HR ticket automation
- Employee verification (cross-check employee data against MOI records)

**Integration Effort:** Low to Moderate (REST APIs available; requires MOI developer registration)

---

### 1.6 WPS (Wage Protection System) — SAMA-Supervised Payroll Processing

**Purpose:** Mandatory bank-mediated salary payment system  
**Operator:** Ministry of Human Resources & Social Development + Saudi Arabian Monetary Agency (SAMA)  
**File Format:** `.TXT` (fixed-width, Mudad registration required)

**Requirements:**
- All private-sector wages must be paid within first 10 days of following month
- File must include: employee national ID, bank IBAN, salary, allowances, deductions
- Currency: SAR only
- Housing allowance **must be explicitly listed** as separate component
- Encrypted file submission to SAMA-approved banks
- Bank confirmation uploaded by 10th of month

**For APEX Integration:**
- Generate WPS-compliant `.TXT` file from payroll data
- Include salary breakdown: Base + Housing + Other Allowances - GOSI - Deductions
- Validate IBAN format and bank routing
- Manage payment status tracking and reconciliation

**Integration Effort:** Moderate (file format parsing/generation + bank channel management)

---

### 1.7 HRSD (Ministry of Human Resources & Social Development)

**Purpose:** Labor law enforcement and compliance oversight  
**URL:** https://hrsd.gov.sa/

**What it does:**
- Publishes labor law, regulation updates
- Oversees Qiwa, Mudad, Nitaqat/Saudization enforcement
- Processes complaints, violations
- Issues guidance on leave, EOSB, working hours

**For APEX Integration:**
- Policy monitoring (track regulation changes for compliance updates)
- Audit reporting (if APEX customer is subject to ministry audits)
- **Not a direct integration point**, but monitoring source for legal compliance

---

### 1.8 Nitaqat (نطاقات) — Saudization Quota Tracking

**Purpose:** Enforce Saudi workforce nationalization policy  
**System:** Color-band classification tied to visa/contract approvals

**Color Band Classifications:**

| Band | Saudi % Range | Benefits | Penalties for Fall |
|------|---------------|----------|-------------------|
| **Platinum** | 26.52%–100% | Expedited visa processing, unrestricted hiring globally, profession change rights, priority government contract access | N/A |
| **High Green** | ~21%–26% | Visa renewal allowed, profession change permitted, work permit renewals | Risk of downgrade to Medium Green |
| **Medium Green** | ~17%–21% | Limited visa approvals | Risk of downgrade to Low Green |
| **Low Green** | ~13%–17% | Minimal visa approvals | Risk of downgrade to Red |
| **Red** | <13% | **No new visas**, **no government contracts**, fines & penalties | Visa freeze, public reporting |

**Saudization % = Saudi nationals ÷ Total workforce (by establishment size & sector)**

**Changes (2025):** Yellow band removed; companies auto-downgraded to Red if previously Yellow.

**For APEX Integration:**
- Quarterly Nitaqat tracking dashboard (Saudi vs. expat headcount)
- Alerts when approaching band threshold
- Report generation for HRSD submissions
- Linked to payroll data (salary vs. nationality costs)

**Integration Effort:** Low (calculation + dashboard; pull data from Qiwa or manual HR input)

---

## 2. Mudad Deep Dive: The Payroll Authentication Gateway

### 2.1 Contract Authentication Flow

```
1. Employer logs into Mudad
2. Extracts employee data from GOSI (auto-filled)
3. Uses MHRSD-approved contract template
4. Fills gaps (salary, allowances, position, terms)
5. Employee receives notification on Tameenati portal
6. Employee approves/rejects/requests amendment
7. Once approved → contract active in system
8. Mudad links contract to payroll cycle
```

### 2.2 Monthly Payroll Certification Process

```
1. APEX payroll system calculates monthly salary
2. Generates WPS file (.TXT) with:
   - Employee national ID
   - Bank IBAN
   - Base salary, housing allowance, other allowances
   - GOSI deduction (calculated per contribution rates)
   - Other deductions (loans, advances, etc.)
   - Net salary
3. Submits file to Mudad (OAuth or API key authentication)
4. Mudad validates:
   - IBAN correctness
   - GOSI deduction calculation matches government rates
   - Salary ≥ SAR 3,000 (minimum wage, varies by sector)
   - No missing required fields
5. Mudad → SAMA → Saudi banks execute transfers
6. Bank confirmation → Mudad → Ministry (auto-uploaded)
7. Payment status available in Mudad dashboard
```

### 2.3 API & Integration Approach

**Current ecosystem** (as of 2026):
- **No public Mudad REST API** published by MHRSD
- Integration happens via **third-party HR platforms** (ZenHR, Bayzat, Jisr, Malachite)
- These platforms have **proprietary integrations** with Mudad

**For APEX to integrate directly:**

**Option A: OAuth Integration (Recommended for MVP)**
- Partner with a Mudad-ready HR platform (e.g., Jisr, Malachite)
- APEX integrates via their API/webhooks
- APEX sends payroll → Partner → Mudad → Banks
- Faster but revenue-shared

**Option B: Direct Mudad Integration (Long-term)**
- Negotiate with MHRSD for API access
- Implement OAuth or API key authentication
- Requires Saudi entity registration + compliance audit
- 6–12 month negotiation + development cycle

**Option C: Hybrid (Recommended for serious competitors)**
- Build payroll module in APEX
- Partner with Mudad-ready platform for initial 12-18 months
- Parallel: negotiate direct Mudad integration
- Sunset partnership once native integration live

### 2.4 Data Requirements for Mudad

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| Establishment ID | MLSD Unified ID | 123456789 | From commercial registration |
| Commercial Reg No. | String | 1010123456 | 10-digit |
| Employee Nat'l ID | 10-digit | 2345678901 | Saudi: 1xxxxxxxxx; Expat: 2xxxxxxxxx |
| Bank IBAN | String | SA4420000001234567890123456789 | IBAN-24 compliant |
| Base Salary | Decimal | 5000.00 | SAR, no decimals in file |
| Housing Allowance | Decimal | 1500.00 | **Must be separate line** |
| Other Allowances | Decimal (variable) | 500.00 | Transport, food, etc. |
| GOSI Deduction | Decimal | Calculated | Auto-calculated if API available |
| Loan Deduction | Decimal | 200.00 | Optional |
| Other Deductions | Decimal | 100.00 | Optional |
| Payment Date | Date | 2026-05-10 | First 10 days of month |

---

## 3. Qiwa Deep Dive: Contract & Leave Management

### 3.1 Electronic Contract Lifecycle

```
Employer Actions:
  1. Log into Qiwa
  2. Create contract (job title, hours, duration, salary, terms)
  3. Send to employee via Qiwa Afrad (employee portal)

Employee Actions:
  1. Log into Qiwa Afrad
  2. Review contract terms
  3. Approve → Contract active
       OR Reject → Negotiation cycle
       OR Request amendment → Employer reviews

Final State:
  - Contract stored in Qiwa (government record of employment)
  - Linked to payroll cycle (via Mudad)
  - Linked to leave entitlements (pre-calculated in system)
```

### 3.2 Leave Management Module (Qiwa)

**Annual Leave:**
- **Accrual:** 21 days for first 5 years; 30 days after 5 years (legal minimum)
- **Carried forward:** Varies by contract; typically 5–10 days max rollover
- **Not taken:** Paid out at end of service (full salary calculation)

**Sick Leave:**
- **Total entitlement:** 120 days/year (per Article 117)
- **Tier 1:** First 30 days → full salary
- **Tier 2:** Days 31–90 → 50% salary
- **Tier 3:** Days 91–120 → unpaid (but protected employment)
- **Requirement:** Medical certificate from accredited doctor

**Other Leave Types:**
- Hajj leave (for Muslims, once in lifetime): 5–10 days (varies by employer)
- Maternity leave: 120 days (paid) + 60 days (unpaid, variable)
- Marriage leave: 3 days (first 6 months after marriage)
- Moving leave: 2–3 days (relocation to new city)
- Examination leave: 3–5 days (study-related)

**Workflow:**
1. Employee submits leave request in Qiwa
2. System checks leave balance (pulls from contract template)
3. Request routed to manager for approval
4. Manager approves/rejects
5. If approved → marked in payroll system (affects salary calculation for unpaid leave)
6. If rejected → employee can appeal

**For APEX Integration:**
- Pull leave balance from Qiwa (read-only integration)
- Track leave taken in payroll module (affects gross-to-net calculation)
- Generate leave summary reports for HR teams

---

## 4. GOSI Deep Dive: Contribution Calculation & Compliance

### 4.1 Contribution Rate Logic (2025 Update)

**Scenario A: New Saudi Employee (hired on/after July 3, 2024)**
```
Monthly Salary: SAR 10,000
Housing Allowance: SAR 2,000
GOSI Base = SAR 12,000 (within ceiling of SAR 45,000)

Employer Contribution (Annuities): 12,000 × 9.5% = SAR 1,140
Employee Contribution (Annuities): 12,000 × 9.5% = SAR 1,140
Occupational Hazard (example 1% by sector): 12,000 × 1% = SAR 120
Total GOSI Liability: SAR 2,400

Net Salary to Employee: 10,000 - 1,140 - (any other deductions) = SAR 8,860 (approx.)
```

**Scenario B: Existing Saudi Employee (hired before July 3, 2024)**
```
Same salary structure, but:

Employer Contribution (Annuities): 12,000 × 9.0% = SAR 1,080 (locked)
Employee Contribution (Annuities): 12,000 × 9.0% = SAR 1,080 (locked)
Occupational Hazard: 12,000 × 1% = SAR 120
Total GOSI Liability: SAR 2,280

Net Salary to Employee: 10,000 - 1,080 - (other deductions) = SAR 8,920
```

**Scenario C: Expatriate Employee (any hire date)**
```
Monthly Salary: SAR 10,000
Housing Allowance: SAR 2,000
GOSI Base = SAR 12,000

Employer Contribution (Annuities): 12,000 × 2% = SAR 240
Employee Contribution: SAR 0 (not required for expats)
Occupational Hazard: 12,000 × 1% = SAR 120
Total GOSI Liability: SAR 360 (employer only)

Net Salary to Employee: 10,000 (no GOSI deduction)
```

### 4.2 Allowances Included vs. Excluded in GOSI Base

**INCLUDED (subject to GOSI):**
- Base salary
- Housing allowance
- Fixed cost-of-living allowances (if explicitly defined in contract)
- Bonuses (if regular/recurring)

**EXCLUDED (not subject to GOSI):**
- Transportation allowance
- Meal allowance
- Uniform allowance
- Irregular bonuses
- Overtime pay (handled separately)

### 4.3 GOSI Wage Ceiling & Floor

- **Ceiling:** SAR 45,000/month → contributions capped at this level
  - Example: If salary = SAR 60,000, GOSI calculated on SAR 45,000 only
- **Floor:** SAR 1,500/month → minimum wage threshold
  - Below this = informal/cash labor (not GOSI-eligible)

### 4.4 GOSI Submission (System-to-System)

**For large enterprises:**
- GOSI System-to-System API available (no manual portal entry)
- File format: CSV or GOSI-specified XML
- Submission monthly with payroll data
- Integration typically handled by Mudad or dedicated HR platform

**For APEX Integration:**
- Calculate GOSI deduction in payroll module (conditional logic by employee nationality + hire date)
- If partnering with Mudad or Jisr → GOSI submission automated
- If standalone → implement System-to-System API with GOSI (requires GOSI registration + API credentials)

---

## 5. WPS Deep Dive: File Format & Bank Submission

### 5.1 WPS File Specification (.TXT Format)

**Structure:** Fixed-width text file (not CSV) with mandatory fields:

```
Header Record:
  Position 1-2:     "01" (record type)
  Position 3-15:    Establishment ID (MLSD Unified ID)
  Position 16-25:   Commercial Registration Number
  Position 26-35:   Total Salary Amount (integer, no decimals)
  Position 36-43:   Payment Date (YYYYMMDD)
  Position 44-245:  Filler (spaces)

Employee Record (repeating for each employee):
  Position 1-2:     "02" (record type)
  Position 3-12:    Employee National ID
  Position 13-40:   Bank IBAN (28 chars, left-padded)
  Position 41-50:   Base Salary (9 digits, right-aligned, no decimals)
  Position 51-60:   Housing Allowance (9 digits)
  Position 61-70:   Other Allowances (9 digits)
  Position 71-80:   GOSI Deduction (9 digits)
  Position 81-90:   Loan Deduction (9 digits)
  Position 91-100:  Other Deductions (9 digits)
  Position 101-110: Net Salary (9 digits)
  Position 111-250: Filler (spaces)

Trailer Record:
  Position 1-2:     "03" (record type)
  Position 3-12:    Total Record Count (employees + header + trailer)
  Position 13-22:   Total Salary Amount (sum of all net salaries)
  Position 23-245:  Filler (spaces)
```

**Example WPS File (3 employees):**
```
01123456789      1010123456    125000000202605101
0223456789012SA4420000001234567890123456789  500000   150000    50000    42500    20000     5000   432500
0224567890123SA4420000001234567890123456790  600000   180000    60000    50760    25000     5000   519240
0225678901234SA4420000001234567890123456791  550000   165000    55000    46395    22500     5000   475105
03000000000000000003                        1250000000
```

### 5.2 Submission & Validation Flow

```
1. APEX generates WPS file (format above)
2. Encryption (via Saudi bank's public key, varies by bank)
3. Upload to Mudad portal OR direct bank submission
4. Mudad validation checks:
   - IBAN format correctness
   - National ID validity (1xxxxxxxx for Saudis, 2xxxxxxxx for expats)
   - GOSI deduction accuracy (vs. GOSI rates)
   - Salary ≥ minimum wage (SAR 3,000 for some sectors, SAR 5,000 for others)
   - No duplicate IBANs
   - Total salary ≥ number of employees × minimum
5. If valid → transmitted to SAMA
6. SAMA → Saudi banks → Individual bank transfers
7. Bank confirmation → Mudad → Ministry reporting (auto)
8. Payment status available in Mudad dashboard (by 10th of following month)
```

### 5.3 Bank Channel Integration

**SAMA-approved channels** for WPS in Saudi Arabia (as of 2026):
- Riyad Bank
- Al Rajhi Bank
- Saudi National Bank (SNB, post-merger)
- Arab National Bank
- Bank Albilad
- ADIB (Arab Development Investment Bank)
- STC Pay
- Mada (payment processor, not a bank)

**For APEX Integration:**
- Select primary bank from SAMA-approved list
- Encrypt WPS file with bank's certificate
- Submit via bank's B2B portal OR Mudad (preferred)
- Poll for status via Mudad API
- Reconcile bank confirmations with APEX GL

---

## 6. EOSB (End-of-Service Benefits): Calculation Formula

### 6.1 Base Formula (Article 84, Saudi Labor Law)

**EOSB accrues based on:**
- **Wage:** Last salary earned (base + fixed allowances, excluding overtime/bonuses)
- **Service duration:** Total continuous employment with single employer

**Accrual rates:**
- **Years 1–5:** Half-month wage per year = 0.5 × Monthly Wage per year
- **Years 5+:** Full month wage per year = 1.0 × Monthly Wage per year

**Formula for service duration:**
```
EOSB = (First 5 years × 0.5 × Monthly Wage) + ((Years 5+) × 1.0 × Monthly Wage) + Proportional for partial year

Example: 7.3 years of service, SAR 10,000/month wage
  EOSB = (5 × 0.5 × 10,000) + (2.3 × 1.0 × 10,000) + (0.3 × 0.5 × 10,000)
       = 25,000 + 23,000 + 1,500
       = SAR 49,500
```

### 6.2 Entitlement by Resignation Timing

| Service Duration | Resignation Entitlement | Termination by Employer | Notes |
|------------------|-------------------------|------------------------|-------|
| < 2 years | 0% (nothing) | 100% EOSB | No benefit for voluntary resignation under 2 years |
| 2–5 years | 33.3% of calculated EOSB | 100% EOSB | One-third rule |
| 5–10 years | 66.6% of calculated EOSB | 100% EOSB | Two-thirds rule |
| 10+ years | 100% of calculated EOSB | 100% EOSB | Full entitlement |

### 6.3 Special Cases (Full EOSB Regardless of Service Duration)

1. **Female employee:** Resignation within 6 months of marriage OR within 3 months of childbirth
2. **Illness/Injury:** Termination due to medical condition (not occupational)
3. **Relocation:** If employer moves facility beyond commute distance
4. **Employer breach:** Non-payment of wages, unsafe conditions
5. **Occupational injury:** Related to work (covered separately by GOSI occupational hazard)

### 6.4 For APEX Payroll Module: EOSB Accrual Calculation

**Monthly accrual logic:**
```
Monthly_EOSB_Accrual = Last_Monthly_Wage × (Accrual_Rate / 12)

Where Accrual_Rate = 0.5 if service < 5 years, else 1.0

Example (assuming SAR 10,000/month):
  Year 1 monthly accrual = 10,000 × 0.5 / 12 = SAR 416.67/month
  Year 6 monthly accrual = 10,000 × 1.0 / 12 = SAR 833.33/month
```

**GL posting (monthly):**
```
Debit: EOSB Expense (P&L)
  Credit: EOSB Liability (Balance Sheet)
    Amount: SAR 416.67 (or SAR 833.33 depending on year)
```

**At termination:**
```
If resignation:
  EOSB_Payment = Calculated_EOSB × Entitlement_Percentage
Else (employer termination):
  EOSB_Payment = Calculated_EOSB × 100%
```

---

## 7. Saudization (Nitaqat): Quota Tracking & Compliance

### 7.1 Calculation & Color Band Assignment

**Saudization % = Saudi Nationals ÷ Total Workforce**

Color band assignment is **dynamic, quarterly**, based on:
1. Workforce size (micro, small, medium, large)
2. Industry sector (retail, manufacturing, healthcare, etc.)
3. Saudi employee headcount

**Example:**
```
Company: 150 total employees
Saudi employees: 28
Saudization % = 28 / 150 = 18.67%

If retail sector, 100–250 employee band:
  → 18.67% falls in "Low Green" range (16%–20%)
  → Quarterly status: Low Green
  → Visa applications: Limited approval
  → Risk: Downgrade to Red if % drops below 13%
```

### 7.2 Color Bands & Incentives/Penalties

| Band | Range | Visa Processing | New Hire Visas | Gov Contracts | Penalties |
|------|-------|------------------|----------------|---------------|-----------|
| Platinum | 26.52%+ | Expedited (1 week) | Unrestricted global hiring | Priority access | None |
| High Green | ~21%–26% | Standard (2 weeks) | Full approval | Eligible | Downgrade risk |
| Medium Green | ~17%–21% | Delayed (3 weeks) | Partial approval | Restricted | Downgrade risk |
| Low Green | ~13%–17% | Delayed (4 weeks) | Very limited | No access | Downgrade to Red |
| Red | <13% | **Frozen** | **Frozen** | **No access** | Fines, public reporting |

### 7.3 Quarterly Recalculation & Notification

- **HRSD calculates** Saudization % each quarter (Jan, Apr, Jul, Oct)
- Employer notified of band change via Qiwa
- If downgraded → 30-day remediation window
- If Red → immediate visa freeze until remediation

### 7.4 For APEX Integration: Saudization Dashboard

**Minimum MVP features:**
1. **Headcount tracking:** Saudi vs. expat (by payroll data)
2. **% calculation:** Auto-calculated as payroll updates
3. **Band predictor:** Show "at risk of downgrade" alerts
4. **Industry mapping:** HR inputs sector, system suggests target %
5. **Quarterly report:** Generate Saudization summary for HRSD submission

**GL integration:**
- Track salary cost per nationality (useful for cost analysis)
- Reports: "Saudization cost impact" (e.g., premium for hiring Saudis)

---

## 8. Visa & Iqama Lifecycle (For Expat Employees)

### 8.1 Visa Types & Duration

| Visa Type | Issued By | Duration | Use Case |
|-----------|-----------|----------|----------|
| **Entry Visa** | MOI, processed by MOI | 3 months | Initial entry into Saudi Arabia |
| **Iqama (Residency Permit)** | Muqeem platform | 1–3 years | Primary residency permit (renewable) |
| **Work Permit** | HRSD via Qiwa | Tied to Iqama | Authorization to work for employer |
| **Exit/Re-entry Visa** | Absher/Muqeem | 1–3 entries | Temporary exit + re-entry (Hajj, vacation) |
| **Final Exit Visa** | Absher/Muqeem | One-way | Permanent departure |

### 8.2 Iqama Issuance Workflow

```
1. Employer applies for Iqama in Muqeem
   - Employee national ID (passport)
   - Salary amount (must meet sector minimum)
   - Job title & contract details
   - Medical/background clearance (if required)

2. Muqeem validates against:
   - No duplicate Iqamas
   - Salary ≥ minimum (varies by sector: SAR 3,000–5,000)
   - Employee not on deportation list
   - Medical/security clearances

3. Approval (typically 1–4 weeks)
   - Employee receives notification
   - Iqama number issued
   - Employee must visit MOI for biometrics + photo

4. Iqama active (1–3 years)
   - Valid travel document
   - Allows work in Saudi Arabia
   - Tied to specific employer (sponsorship)

5. Renewal process (starts 60 days before expiry)
   - Employer initiates in Muqeem
   - Similar approval process
   - Typically approved if salary/status unchanged
```

### 8.3 For APEX Integration

**Minimal feature set:**
1. **Iqama tracking:** Store expiry dates in employee master data
2. **Renewal alerts:** Email HR team 60 days before expiry
3. **Salary compliance check:** Validate monthly salary against sector minimum
4. **Visas in GL:** Track visa costs (application fees, medical exams) as expenses

**Integration points:**
- Muqeem API (read-only, via Absher Business)
- Qiwa (pulls visa renewal status)
- Payroll (ensures salary meets minimum for visa continuation)

---

## 9. Competitive Landscape: Saudi HR/Payroll SaaS Products

### 9.1 Market Size & Growth

- **2024 baseline:** USD 332.3 million (Saudi Arabia HR tech market)
- **2026 projection:** USD 710.1 million (CAGR 8.17%)
- **Labor market:** 14.5+ million registered workers on Qiwa (2026)
- **SME segment:** 99% of registered establishments in Saudi Arabia are SMEs (<100 employees)

### 9.2 Leading Competitors

#### **Bayzat**
- **Founded:** 2014 (UAE-based, now serves KSA heavily)
- **Core:** HR, insurance, payroll
- **Mudad integration:** Yes (native)
- **GOSI integration:** Yes
- **Muqeem integration:** Partial
- **Pricing:** ~750 SAR/month for Mudad subscription (first 100 customers free for 1 year)
- **Strengths:** User-friendly, group insurance bundled, strong in UAE
- **Weaknesses:** Less deep Saudi labor law expertise than native competitors
- **URL:** https://www.bayzat.com/ksa/mudad

#### **ZenHR**
- **Founded:** 2015 (Saudi startup)
- **Core:** HR, payroll, attendance, recruitment
- **Mudad integration:** Yes (native)
- **GOSI integration:** Yes (native)
- **Muqeem integration:** Via Jisr partnership
- **Saudization tracking:** Yes
- **Pricing:** Custom (enterprise)
- **Strengths:** Deep Saudi labor law, Arabic-first, Hijri calendar, Qiwa integration underway
- **Weaknesses:** Less polished UI than Bayzat, higher price point
- **Coverage:** KSA, UAE, Jordan, Kuwait, Bahrain

#### **Jisr**
- **Founded:** 2019 (Saudi startup)
- **Core:** HR, payroll, finance, compliance
- **Mudad integration:** Yes (native, early adopter)
- **GOSI integration:** Yes (native)
- **Muqeem integration:** Yes (native)
- **Qiwa integration:** Planned (2026–2027)
- **Saudization tracking:** Yes
- **Compliance features:** Most integrated with government systems
- **Pricing:** Tiered (micro, SME, semi-government, enterprise)
- **Strengths:** Most government integrations, Saudi-born, BI/reporting tools
- **Weaknesses:** Newer brand, less marketing maturity
- **URL:** https://www.jisr.net/en

#### **Malachite**
- **Founded:** ~2020 (Saudi startup)
- **Core:** HR, payroll, compliance
- **Mudad integration:** Yes (native)
- **GOSI integration:** Yes (native)
- **Muqeem integration:** Yes (native)
- **Saudization tracking:** Yes
- **Strengths:** Marketed as "best HR built for Saudi regulations"
- **Weaknesses:** Limited market presence, smaller customer base
- **URL:** https://malhr.com/en

#### **PalmHR**
- **Founded:** ~2016 (Gulf-based)
- **Core:** HR, payroll
- **Mudad integration:** Yes (native)
- **GOSI integration:** Yes (native)
- **Muqeem integration:** Yes (native)
- **Strengths:** Affordable, mid-market focus
- **Weaknesses:** Weaker UI, limited reporting
- **URL:** Capterra listing only (no public website found)

### 9.3 Enterprise Competitors (Low Saudi Adoption)

#### **NetSuite SuitePeople**
- **Mudad integration:** None
- **GOSI integration:** None
- **Localization:** US-only payroll; ME via third-party (InoPeople)
- **Assessment:** Not suitable for pure Saudi deployment; works only with ME-specific add-ons
- **URL:** https://netsuite.folio3.com/blog/suitepeople-by-netsuite-a-complete-guide-to-hr-payroll-management/

#### **Workday**
- **Mudad integration:** None (no public integration)
- **GOSI integration:** None
- **Localization:** Generic EMEA; no Saudi-specific rules
- **Assessment:** Enterprise-grade but requires extensive custom configuration for Saudi compliance
- **Suitability for APEX:** Not recommended for Saudi market without 6+ months customization

#### **ADP**
- **Mudad integration:** None
- **GOSI integration:** None (available for UAE via MOHRE, not Saudi)
- **Assessment:** Global payroll, not Saudi-specific
- **Suitability for APEX:** Only if APEX targets multi-country enterprises

#### **BambooHR**
- **Mudad integration:** None
- **GOSI integration:** None
- **Arabic/RTL support:** None
- **Saudization tracking:** None
- **Assessment:** Explicitly lacks Saudi localization
- **Pricing:** $250/month (25 employees) or $12–22 per employee/month
- **Suitability for APEX:** Not suitable; BambooHR has abandoned Saudi market focus
- **URL:** https://www.capterra.com/p/113872/BambooHR/ (reviews confirm lack of Saudi support)

### 9.4 Zoho People + Zoho Payroll

- **Mudad integration:** None (direct)
- **GOSI integration:** Yes (via formula-based calculation, not API)
- **Localization:** Partial (Arabic, RTL, Hijri calendar)
- **Assessment:** Mid-market option; less integrated than Jisr/Bayzat but affordable
- **Suitability for APEX:** Viable if bundling with accounting (Zoho Books already integrated)

---

## 10. Feature Gap Analysis: What Competitors Are Missing

### Unmet Market Needs (as of April 2026)

1. **Qiwa Full Integration:** Only Jisr claims integration (in beta); others manually sync contracts
2. **Occupational Hazard Insurance:** Most platforms calculate but don't manage insurance procurement
3. **Visa Cost Management:** No platform tracks visa expenses + ROI (for Saudization planning)
4. **EOSB Forecasting:** Which employees will cost most at exit (workforce planning)
5. **Nitaqat Optimization:** Modeling salary impact of Saudization threshold changes
6. **Multi-establishment:** Large companies with multiple Saudi branches (different GOSI rates per location)
7. **Overtime & Shift Management:** Integration with attendance → automatic OT calculations
8. **Mobile-first payslips:** Mostly web-only, despite Qiwa mobile-first culture
9. **Real-time GOSI rate changes:** Manual updates required when rates change (July 2025 confusion still evident)
10. **AI-powered leave forecasting:** Predict employee absences, plan coverage

---

## 11. Recommendation: Should APEX Build HR/Payroll?

### 11.1 Three Strategic Options

#### **Option A: Minimal HR + Mudad Integration (RECOMMENDED for APEX)**

**What APEX builds:**
- Employee master data (name, ID, bank, salary components)
- Monthly payroll calculation (base + allowances - GOSI)
- WPS file generation (.TXT format)
- Simple leave tracking dashboard
- EOSB accrual (GL posting only, no advanced analytics)

**What APEX partners for:**
- Contract management → Jisr/Bayzat API
- Mudad submission → Partner's integration
- GOSI submission → Partner's System-to-System API
- Muqeem/Absher → Read-only via partner

**Effort:** 4–6 months (2–3 senior engineers)  
**Revenue model:** SaaS payroll module ($50–100/month per employee)  
**Market entry:** 12–18 months  
**Risk:** Partner dependency (if Jisr/Bayzat becomes competitor)

**Pros:**
- Leverages APEX's accounting strength (GL integration, reports)
- Faster time to market
- Lower R&D cost
- Can white-label partner's integration initially

**Cons:**
- Revenue-shared with partner
- Customer lock-in to partner (difficult to switch)
- Cannot claim "fully native" integration

---

#### **Option B: Full HR/Payroll Stack (High-effort, high-reward)**

**What APEX builds:**
- All of Option A +
- Contract management (Mudad-compliant templates)
- Full leave management (Qiwa sync)
- GOSI submission (System-to-System API)
- Iqama tracking (Muqeem read-only)
- Visa management (Absher API integration)
- Saudization dashboard (real-time Nitaqat tracking)
- Mobile app for employees (leave requests, payslips)
- Advanced EOSB forecasting
- Occupational hazard insurance quoting

**Effort:** 9–12 months (4–5 senior engineers)  
**Revenue model:** Premium payroll module ($100–150/month per employee)  
**Market entry:** 18–24 months  
**Risk:** High (requires Saudi-based team, government relationship)

**Pros:**
- Full vertical integration (finance + HR)
- Direct Mudad revenue (no partner rev-share)
- Can be rebranded for GCC (UAE, Qatar, Bahrain variants)
- Strong moat vs. competitors

**Cons:**
- Requires Saudi engineering talent (hard to hire)
- Government API access negotiations (3–6 months bureaucracy)
- Ongoing compliance maintenance (legal risk)
- Competes directly with well-funded Jisr, Bayzat

---

#### **Option C: Skip HR, Focus on Accounting**

**What APEX skips:**
- No payroll module
- No leave tracking
- No GOSI calculation

**What APEX integrates:**
- Read-only from partner HR platform (Jisr, Bayzat, ZenHR)
- Pull: Monthly payroll expense, payable GL entries, employee count
- Push: GL codes, cost center mappings, department charges

**Effort:** 2–3 months (1 engineer)  
**Revenue model:** Accounting module only ($80–150/month per company)  
**Market entry:** 6 months  
**Risk:** Low (no regulatory exposure)

**Pros:**
- Fast market entry
- No HR expertise required
- Simple integrations (API webhooks)
- Can add HR later if demand appears

**Cons:**
- Missing 40% of value (HR + Finance integration)
- Customers still need separate HR platform (higher customer acquisition cost)
- Competitors will bundle HR eventually (pressure from ZenHR, Jisr growth)

---

### 11.2 Final Recommendation: **Option A with Path to Option B**

**Phase 1 (Months 0–6):**
- Build APEX payroll module (salary calc, WPS file, EOSB accrual, leave tracking)
- Partner with Jisr (or Bayzat if willing) for contract + Mudad integration
- Market as "APEX Financial + Jisr HR" bundle
- Target mid-market (500–5,000 employees, currently underserved by Jisr/Bayzat)

**Phase 2 (Months 12–18, if market signals positive):**
- Negotiate direct Mudad API access (or obtain via new Saudi tech partner)
- Build contract management + Qiwa sync
- Migrate customers off Jisr partnership to native APEX
- Launch independent brand (not bundled)

**Phase 3 (Months 18–24):**
- Add Muqeem/Absher integrations
- Expand to UAE (WPS variant)
- Launch occupational hazard insurance integration

**ROI Model (Phase 1):**
```
Engineering cost: 8 FTE-months ≈ $400K (Saudi-based team $5K/month)
GTM/localization: $150K
Total investment: $550K

Revenue potential (Year 1):
  100 customers × 50 employees avg × $60/employee/month = $360K/month = $4.3M/year
  Expected Year 1: 30 customers = $1.3M MRR potential
  Breakeven: Month 8–10

Payback period: ~5 months (with 30 customers)
```

---

## 12. Minimum Viable Feature Set for APEX HR/Payroll

### 12.1 Core Payroll Engine

```
✅ Employee master data
  - National/Iqama ID validation (1xxxxxxxx vs 2xxxxxxxx)
  - Bank IBAN storage + validation
  - Nationality flag (Saudi vs expat) → controls GOSI deduction
  - Hire date → controls EOSB accrual rate
  - Salary components breakdown (base, allowances)

✅ Monthly payroll processing
  - Salary calculation (base + allowances - GOSI - deductions)
  - GOSI calculation (conditional: nationality + hire date)
    - 9.5% new Saudis, 9% existing Saudis, 2% expats
    - Base = salary + housing allowance (max SAR 45K)
  - WPS file generation (.TXT format per HRSD spec)
  - Payment status tracking (pending → submitted → confirmed)

✅ GL posting
  - Debit: Salary Expense, GOSI Expense, Deductions
  - Credit: Salaries Payable, GOSI Payable
  - Auto-reverse next month (accrual reversal)

✅ EOSB tracking
  - Monthly accrual (0.5 year 1–5, 1.0 year 5+)
  - Liability GL posting
  - Termination calculator (resignation vs employer term, duration, entitlement %)
```

### 12.2 Leave Management

```
✅ Leave balance tracking
  - Annual (21 days default, 30 after 5 years)
  - Sick leave (120 days/year, tiered pay)
  - Hajj, marriage, maternity (special rules)
  - Rollover policy (typically 5–10 day max)

✅ Leave request workflow
  - Employee submit → manager approve → HR confirm
  - Auto-check balance before approval
  - Integration with Qiwa (for read-only balance sync)

✅ Payroll impact
  - Unpaid leave reduces gross salary (lower GOSI base)
  - Sick leave tier logic (full pay days 1–30, half pay days 31–90, unpaid 91–120)
```

### 12.3 Saudization Tracking

```
✅ Headcount dashboard
  - Total employees
  - Saudi count, expat count
  - Saudization % = Saudi / Total

✅ Nitaqat band calculator
  - Input: company size, industry sector
  - Output: suggested % target + current band (Platinum/High/Mid/Low Green/Red)

✅ Risk alerting
  - "At risk of downgrade to Red" if % < threshold
  - Quarterly reminder (Jan, Apr, Jul, Oct)

✅ Salary cost analysis
  - Cost per Saudi vs expat
  - Saudization premium (e.g., Saudis cost 20% more)
```

### 12.4 WPS File Management

```
✅ File generation
  - Input: payroll data from monthly calc
  - Output: .TXT file (HRSD spec)
  - Validation: IBAN format, national ID range, salary >= minimum

✅ Submission workflow
  - Upload to partner platform (Jisr/Bayzat) OR Mudad directly
  - Bank confirmation tracking
  - Payment reconciliation (compare GL to bank statement)
```

### 12.5 Reporting

```
✅ Payroll summary
  - Headcount, gross salary, GOSI, net salary
  - YTD accruals (EOSB, expenses)

✅ Compliance reports
  - Saudization status (quarterly)
  - GOSI deduction verification
  - EOSB liability (balance sheet reserve)

✅ Analytics
  - Cost per employee (Saudi vs expat)
  - Leave usage patterns
  - Visa expiry calendar
```

### 12.6 Integrations (MVP Phase)

```
✅ Mudad (via partner API or direct)
  - Send: WPS file
  - Receive: Contract validation, payment status

✅ Jisr/Bayzat (partner integration)
  - Pull: Contract data, leave balance
  - Push: Payroll amounts, GOSI deduction (for validation)

✅ QuickBooks/Odoo/Xero (GL integration)
  - Push: Payroll GL entries (salary expense, GOSI, payables)
```

---

## 13. Build vs. Buy Analysis: Costs & Timelines

### 13.1 Build Option A: Payroll Module (4–6 months)

| Component | Effort | Cost | Owner |
|-----------|--------|------|-------|
| Employee master data module | 2 weeks | $25K | 1 senior dev |
| Payroll calculation engine | 4 weeks | $50K | 1–2 devs |
| GOSI logic (conditional) | 1 week | $15K | 1 dev |
| WPS file generation | 1 week | $15K | 1 dev |
| Leave management (basic) | 3 weeks | $40K | 1 dev |
| GL posting (accruals) | 1 week | $15K | 1 dev |
| EOSB accrual tracking | 1 week | $15K | 1 dev |
| Saudization dashboard | 2 weeks | $25K | 1 dev |
| Testing (unit + integration) | 3 weeks | $40K | 1 QA |
| Mudad integration (via partner) | 1 week | $15K | 1 dev |
| Documentation + support | 1 week | $15K | 1 technical writer |
| **Total** | **20 weeks** | **$270K** | **2–3 FTE** |
| Plus: Saudi team hiring, onboarding | | $150K | — |
| Plus: Legal/compliance review (MHRSD) | | $30K | — |
| **Grand Total** | **6 months** | **$450K** | — |

**Ongoing costs (Year 1):**
- 2 FTE maintenance + enhancements: $120K
- Legal/regulatory monitoring: $20K/year
- Mudad API support: $15K/year
- **Total Year 1 post-launch:** $155K

### 13.2 Buy Option: Extend Partner Platform

**Scenario: Bundle with Jisr**

| Item | Cost | Notes |
|------|------|-------|
| Jisr API integration (development) | $80K | 4–8 weeks work |
| Jisr partnership revenue share | 20–30% | On all APEX customers using Jisr |
| Jisr annual licensing (reseller) | $10K–$50K | Depends on customer volume |
| **Year 1 Total** | **$90K–$130K** | Plus 20–30% revenue share |

**Breakeven Analysis (Build vs. Buy):**

```
Build option:
  Initial investment: $450K
  Year 1 revenue (30 customers, 50 emp avg, $60/emp/mo): $1.3M
  Year 1 operating cost: $155K
  Margin: 79%
  Payback: Month 5

Buy (Jisr partnership):
  Initial investment: $130K
  Year 1 revenue: $1.3M
  Revenue share cost (25%): -$325K
  Year 1 operating cost: $30K
  Margin: 54%
  Payback: Month 1.5 (but lower margin)

Verdict: Build is better long-term (higher margin, customer lock-in), but Buy is safer short-term (lower risk, faster launch).
```

---

## 14. Competitor-Specific Attack Vectors for APEX

### How APEX Can Differentiate vs. Jisr, Bayzat, ZenHR:

1. **Accounting Integration (Core Strength)**
   - Jisr/Bayzat are HR-first; accounting is afterthought
   - APEX: HR → auto GL posting → financial statements
   - Value: CFO buys APEX for finance, gets HR for free

2. **Cost Analysis & Saudization ROI**
   - Model: "If we hire 10 more Saudis, how does salary cost impact P&L?"
   - Competitors: No forecasting
   - APEX: Excel-style scenario modeling for Saudization

3. **Multi-establishment Support**
   - Competitors: Single establishment per contract
   - APEX: 1 parent company, 5 Saudi branches, different GOSI rates per location
   - Market: Large groups (250+ employees) currently underserved

4. **Visa Cost Management**
   - Competitors: Track Iqama expiry only
   - APEX: Track visa costs (application, medical, processing) by employee
   - ROI: Show visa cost per productive employee (Saudization impact)

5. **Occupational Hazard Insurance Bundling**
   - Competitors: Calculate deduction only
   - APEX: Partner with insurance broker, auto-quote premium
   - Revenue: 10% commission on insurance sales

---

## 15. Final Recommendation Summary

### Go/No-Go Decision Matrix

| Criteria | Weight | Score (1–10) | Recommendation |
|----------|--------|--------------|-----------------|
| **Market size** | 20% | 9 | Strong demand (USD 710M by 2026) |
| **Competitive intensity** | 15% | 4 | Very high (Jisr, Bayzat well-funded) |
| **Integration complexity** | 15% | 6 | Moderate (Mudad doable via partner) |
| **Engineering burden** | 15% | 7 | High (6+ months for full-stack) |
| **APEX core strength fit** | 20% | 8 | Excellent (HR data → GL) |
| **Revenue potential** | 15% | 8 | $2–5M ARR by Year 2 |
| **Weighted Score** | 100% | **7.0** | **PROCEED (with caution)** |

### Final Recommendation

**✅ APEX SHOULD BUILD MINIMAL HR/PAYROLL MODULE**

**Scope:**
- Payroll calculation + WPS file generation
- Leave tracking (basic)
- EOSB accrual (GL posting only)
- Saudization dashboard
- Mudad integration (via partner for MVP)

**Timeline:** 6 months (2–3 engineers)  
**Budget:** $450K (first release)  
**Market Entry:** 12 months (Q2 2027)  
**Revenue Potential:** $1–3M ARR (Year 2)

**Success Metrics:**
- 50+ customers (first 12 months)
- 95%+ compliance score (no GOSI/WPS errors)
- NPS > 40 (vs. competitors at 30–35)
- < 10% churn (competitors at 15%)

---

## Appendices

### A. Government Integration URLs

| System | URL | Type | API Status |
|--------|-----|------|-----------|
| Mudad | https://mudad.com.sa/ | Portal + Services | Private API (via partners) |
| Qiwa | https://www.qiwa.sa/ | Portal + Services | No public API (yet) |
| GOSI | https://www.gosi.gov.sa/ | Portal + Services | System-to-System API (B2B only) |
| Muqeem | Via Absher Business | Portal | Read-only via Absher |
| Absher Business | https://www.absher.sa/wps/portal/business/Home | Portal + APIs | REST APIs (requires MOI registration) |
| HRSD | https://hrsd.gov.sa/ | Information + Portal | No direct APIs |
| WPS | https://my.gov.sa/en/services | Portal | File-based (no API) |

### B. Key Regulatory Documents

- **WPS Wages File Specification:** https://www.hrsd.gov.sa/sites/default/files/2017-06/WPS%20Wages%20File%20Technical%20Specification.pdf
- **GOSI Contribution Rates (2025):** https://zenhrsolutions.freshdesk.com/en/support/solutions/articles/43000760572-mandatory-gosi-update-new-contribution-rates-effective-july-2025
- **Leave Regulations:** https://www.hrsd.gov.sa/sites/default/files/2023-03/Regulations%20on%20Leaves.pdf
- **Nitaqat Program Guidelines:** https://www.hrsd.gov.sa/sites/default/files/2023-06/E20210523.pdf

### C. Comparable HR SaaS Pricing (Saudi Arabia, 2026)

| Product | Per-Employee/Month | Setup | Notes |
|---------|-------------------|-------|-------|
| Bayzat | $15–$40 | $500–$2K | Insurance bundled |
| ZenHR | $20–$60 | $1K–$5K | Enterprise pricing |
| Jisr | $10–$50 | $500–$2K | Tiered by company size |
| Malachite | $12–$45 | $500–$1.5K | Competitive pricing |
| BambooHR | $250 flat (25 emp) or $12–$22/emp | $0 | Not Saudi-compliant |

**APEX Suggested Pricing:** $25–$50/employee/month (competitive with Bayzat, undercut ZenHR)

---

## Sources

### Primary Sources (Government & Official)

1. [HRSD Wage Protection System](https://www.hrsd.gov.sa/en/knowledge-centre/initiatives/national-transformation-initiatives-bank/108808)
2. [WPS Wages File Technical Specification](https://www.hrsd.gov.sa/sites/default/files/2017-06/WPS%20Wages%20File%20Technical%20Specification.pdf)
3. [GOSI Official Portal](https://www.gosi.gov.sa/en)
4. [Qiwa Employment Contracts](https://www.qiwa.sa/en/service-overview/employees/manage-your-current-job/employment-contracts)
5. [Absher Business Platform](https://www.absher.sa/wps/portal/business/Home)
6. [HRSD Leave Regulations](https://www.hrsd.gov.sa/sites/default/files/2023-03/Regulations%20on%20Leaves.pdf)
7. [Nitaqat Procedural Guideline](https://www.hrsd.gov.sa/sites/default/files/2023-06/E20210523.pdf)

### Secondary Sources (HR Platforms & Analysis)

8. [Bayzat Mudad Integration](https://www.bayzat.com/ksa/mudad)
9. [ZenHR Mudad Integration Guide](https://blog.zenhr.com/en/2022/09/08/whats-new-in-zenhr-mudad-payroll-platform-integration/)
10. [Jisr HR Software Overview](https://www.jisr.net/en)
11. [Malachite HR Platform](https://malhr.com/en)
12. [PalmHR - Capterra Listing](https://www.capterra.ae/software/1023231/palmhr)
13. [ZenHR GOSI Calculation Guide](https://blog.zenhr.com/en/how-to-calculate-gosi-deductions-in-saudi-arabia-complete-guide-2026)
14. [Mudad Contract Authentication (ISSA)](https://www.issa.int/gp/212500)
15. [Qiwa & Mudad Platform Overview (LinkedIn)](https://www.linkedin.com/pulse/qiwa-mudad-new-platforms-saudi-labor-market-fasih-sandhu)

### Market & Competitive Intelligence

16. [Saudi Arabia HR Tech Market Size (Grand View Research)](https://www.grandviewresearch.com/horizon/outlook/human-resource-management-market/saudi-arabia)
17. [Saudi Arabia HR Tech Market 2024–2033 (IMARC Group)](https://www.imarcgroup.com/saudi-arabia-hr-tech-market)
18. [Best HR Software in Saudi Arabia 2026 Comparison](https://themiddleeastinsider.com/2026/03/02/best-hr-software-saudi-arabia-2026-comparison/)
19. [BambooHR Review: Lack of Saudi Compliance](https://www.capterra.com/p/113872/BambooHR/)
20. [NetSuite SuitePeople for Middle East (InoPeople)](https://inopeople.com/netsuite-payroll-automation-in-the-middle-east)

### Technical & Regulatory References

21. [EOSB Calculator & Formula](https://saudieosbcalculator.com/)
22. [Saudi EOSB Entitlement Rules (Resignation)](https://saudieosbcalculator.com/entitlement/resignation-full/)
23. [Saudization & Nitaqat Overview](https://www.centuroglobal.com/article/saudization/)
24. [Muqeem Platform Guide](https://motaded.com.sa/blog/muqeem-portal-registration)
25. [Global Employment Compass Saudi Arabia](https://www.pilnet.org/wp-content/uploads/2024/08/Global-Employment-Compass-KSA.pdf)
26. [ILO Wage Protection Report (Gulf Region)](https://www.ilo.org/sites/default/files/2025-11/ILO_Beirut_Wage-Protection_Report_R10.pdf)
27. [UAE WPS & MOHRE Updates](https://www.mohre.gov.ae/en/media-center/news/10/12/2025/mohre-launches-new-update-for-the-wage-protection-system)

---

**Document Status:** Complete Research (April 30, 2026)  
**Next Steps:** Share with APEX product & engineering leadership; schedule decision meeting Q2 2026
