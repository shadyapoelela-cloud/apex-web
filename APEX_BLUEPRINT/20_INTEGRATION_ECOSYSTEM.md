# APEX Financial Platform: Integration Ecosystem & Payment Gateways

**Target Markets**: Saudi Arabia, UAE, Egypt, Jordan, Kuwait  
**Last Updated**: April 2026  
**Focus**: Open Banking (SAMA, CBUAE), Payment Gateways, Bank Reconciliation, Direct Debit

---

## Table of Contents

1. [Open Banking Landscape (MENA)](#1-open-banking-landscape-mena)
2. [SAMA Open Banking Technical](#2-sama-open-banking-technical)
3. [Bank Statement Formats](#3-bank-statement-formats)
4. [Bank Reconciliation Algorithms](#4-bank-reconciliation-algorithms)
5. [Payment Gateways Comparison](#5-payment-gateways-comparison)
6. [Stripe Deep-Dive for SaaS](#6-stripe-deep-dive-for-saas)
7. [Saudi-Specific Payment Requirements](#7-saudi-specific-payment-requirements)
8. [WPS (Wage Protection System)](#8-wps-wage-protection-system)
9. [Direct Debit & Standing Orders](#9-direct-debit--standing-orders)
10. [Webhooks & Event Processing](#10-webhooks--event-processing-pattern)
11. [PCI DSS Compliance](#11-pci-dss-compliance)
12. [Refund & Chargeback Handling](#12-refund--chargeback-handling)
13. [Multi-Currency Settlement](#13-multi-currency-settlement)
14. [Recommended APEX Integration Architecture](#14-recommended-apex-integration-architecture)
15. [Sample Code Stubs](#15-sample-code-stubs)

---

## 1. Open Banking Landscape (MENA)

### SAMA (Saudi Central Bank) Open Banking

**Current State (2025-2026)**:
- **Phase 1** (Launched Q4 2023): Account Information Services (AIS) — third-party providers can read customer bank accounts
- **Phase 2** (Launched Q2 2024): Payment Initiation Services (PIS) — TPPs can initiate transactions on behalf of customers
- **Phase 3** (Roadmap): Tokenization, Complex Payment Scenarios, Enhanced Security
- **Participating Banks**: Saudi National Bank (SNB), Al Inma Bank, Rajhi Bank, Riyad Bank, SABB (Saudi American Bank), Al Bilad Bank, and expanding

**Key Standards**:
- OAuth 2.0 (Authorization Code flow)
- OpenID Connect (OIDC) for identity
- FAPI 1.0 (Financial-grade API) security baseline
- Mutual TLS (mTLS) for B2B connections
- JWS (JSON Web Signature) for request/response signing

**Regulatory Framework**:
- Overseen by SAMA (Saudi Central Bank)
- TPP (Third-Party Provider) registration mandatory
- SCA (Strong Customer Authentication) required for payments
- Open Data Standard: JSON-based (not XML-first like PSD2)

---

### CBUAE (UAE Central Bank) Open Finance

**Current State**:
- **Open Finance Framework** (launched 2023): Broader than Open Banking, includes insurance, pensions, FX
- **Phase 1**: Account aggregation (AIS equivalent)
- **Phase 2**: Payment initiation, fund transfers
- **Participating Banks**: FAB (First Abu Dhabi Bank), DIB (Dubai Islamic Bank), ADCB, RAK Bank, Mashreq, and others
- **Regulatory Timeline**: Full implementation by 2025

**Key Differences from SAMA**:
- Covers non-banking financial services (insurance, pensions)
- XML-first (similar to EU PSD2 / ISO 20022)
- Data residency: UAE only
- Stringent data protection (aligned with GDPR principles)

---

### Egypt's Instant Payment Network (IPN)

**Current State**:
- **CBE IPN** (Central Bank of Egypt): Live since Q1 2024
- 24/7 interbank fund transfers in EGP
- Enables financial inclusion and real-time settlement
- Integration points: mada, Paymob, local fintechs

---

### Jordan & Kuwait

- **Jordan Central Bank**: Open Banking framework under development; expected 2025-2026
- **Kuwait**: No mandatory open banking directive; reliance on payment scheme integrations (KNET for local cards)

---

### Differences from EU PSD2

| Aspect | SAMA/CBUAE | EU PSD2 |
|--------|-----------|--------|
| **Legal Basis** | Central Bank directive | EU Regulation |
| **Data Format** | JSON (SAMA), XML (CBUAE) | XML (ISO 20022) |
| **Consent Duration** | 90 days renewable | 12 months |
| **SCA Requirement** | Yes, for all payments | Yes, with exemptions |
| **Liability Cap** | Under development | €50k (consumer) |
| **Regulatory Sandbox** | Limited | Well-established |
| **Third-Party Integration** | Selective banks | All banks (mandatory) |

---

## 2. SAMA Open Banking Technical

### API Standards & Security

**OAuth 2.0 Flow** (Authorization Code):
```
1. Merchant redirects user to bank auth endpoint
   GET /oauth/authorize?
     client_id={APEX_CLIENT_ID}
     &redirect_uri=https://apex.com/auth/callback
     &response_type=code
     &scope=accounts+transactions
     &state={random_state}

2. User logs in, grants consent (scope-specific)

3. Bank redirects with auth code
   GET /auth/callback?code={CODE}&state={STATE}

4. APEX backend exchanges code for token
   POST /oauth/token
   client_id: APEX_CLIENT_ID
   client_secret: APEX_CLIENT_SECRET
   grant_type: authorization_code
   code: {CODE}

5. Bank returns access_token + refresh_token
   {
     "access_token": "...",
     "token_type": "Bearer",
     "expires_in": 3600,
     "refresh_token": "..."
   }
```

**Request Signing (JWS)**:
- All requests signed with APEX private key
- Bank validates signature using APEX public cert (registered at SAMA)
- Prevents man-in-the-middle attacks
- Example header: `Authorization: Bearer {access_token}`
- Example signature: `x-jws-signature: {base64_jws}`

**Mutual TLS (mTLS)**:
- Bank and APEX exchange client certificates
- TLS handshake validates both parties
- Certificate pins prevent DNS hijacking

---

### Account Information Service (AIS)

**Retrieve Account List**:
```
GET /accounts
Authorization: Bearer {access_token}
x-jws-signature: {signature}

Response:
{
  "data": {
    "accounts": [
      {
        "accountId": "ACC-12345",
        "name": "Current Account",
        "type": "CURRENT",
        "currency": "SAR",
        "accountNumber": "1234567890",
        "balance": {
          "amount": 50000.00,
          "currency": "SAR",
          "lastUpdate": "2026-04-30T10:30:00Z"
        }
      }
    ]
  }
}
```

**Retrieve Transactions**:
```
GET /accounts/{accountId}/transactions?from=2026-04-01&to=2026-04-30
Authorization: Bearer {access_token}

Response:
{
  "data": {
    "transactions": [
      {
        "transactionId": "TXN-67890",
        "bookingDate": "2026-04-30",
        "valueDate": "2026-04-30",
        "amount": -5000.00,
        "currency": "SAR",
        "counterpartyName": "ABC Company LLC",
        "counterpartyAccount": "3141592654",
        "description": "Invoice INV-2026-001 payment",
        "reference": "INV-2026-001",
        "status": "CLEARED"
      }
    ]
  }
}
```

---

### Payment Initiation Service (PIS)

**Initiate Payment**:
```
POST /payments
Authorization: Bearer {access_token}
Content-Type: application/json
x-jws-signature: {signature}

{
  "paymentType": "SINGLE_PAYMENT",
  "fromAccount": "ACC-12345",
  "toAccount": "3141592654",
  "toBank": "SABB",
  "amount": 25000.00,
  "currency": "SAR",
  "description": "Invoice INV-2026-002 payment",
  "reference": "INV-2026-002",
  "executionDate": "2026-05-01"
}

Response:
{
  "data": {
    "paymentId": "PAY-11111",
    "status": "PENDING_AUTHORIZATION",
    "scaRequired": true,
    "scaMethod": "SMS_OTP"
  }
}
```

**Confirm Payment (SCA)**:
```
POST /payments/{paymentId}/authorize
{
  "scaValue": "123456",  # OTP from SMS
  "scaMethod": "SMS_OTP"
}

Response:
{
  "data": {
    "paymentId": "PAY-11111",
    "status": "ACCEPTED",
    "executionDateTime": "2026-05-01T14:30:00Z"
  }
}
```

---

### Strong Customer Authentication (SCA)

**Mandatory for**:
- All payment initiation (PIS)
- Account access for high-risk scenarios (fraud detection)

**Methods Supported**:
1. **SMS OTP**: 6-digit one-time password, valid 5 minutes
2. **Email OTP**: Backup method
3. **Mobile App Push**: Bank app notification + approval
4. **Biometric** (upcoming): Fingerprint/Face on banking apps

**Exemptions** (low-risk):
- Payroll transactions (fixed amount, known recipient)
- Bill payments to registered payees (after 1st payment SCA)
- Small transactions (<SAR 50)

---

### TPP (Third-Party Provider) Registration

**APEX must register with SAMA**:
1. **Apply for TPP License**: Submit business registration, compliance docs
2. **API Credentials**: Receive `client_id`, `client_secret`
3. **Certificate Installation**: Upload APEX public cert to SAMA portal
4. **Bank Integration**: SAMA publishes APEX in TPP registry to all banks
5. **Ongoing Compliance**: Audit logs, incident reporting, annual renewal

**Key Documents**:
- Business registration certificate
- AML/KYC compliance attestation
- Data protection policy (GDPR/PDPA aligned)
- Cyber insurance certificate (SAR 5M minimum)

---

### Participating Saudi Banks (Phase 1 & 2)

| Bank | Acronym | AIS | PIS | mTLS |
|------|---------|-----|-----|------|
| Saudi National Bank | SNB | ✓ | ✓ | ✓ |
| Al Inma Bank | ALINMA | ✓ | ✓ | ✓ |
| Rajhi Bank (National Comm.) | RBANK | ✓ | ✓ | ✓ |
| Riyad Bank | RIYADBANK | ✓ | ✓ | ✓ |
| SABB (Saudi American) | SABB | ✓ | ✓ | ✓ |
| Al Bilad Bank | ALBILAD | ✓ | ✓ | ✓ |
| Saudi Industrial Bank | SABINVEST | Planned | Planned | ✓ |
| Alinma | ALINMA | ✓ | ✓ | ✓ |

**API Base URLs** (production):
- SAMA Sandbox: `https://api-sandbox.sama.gov.sa/open-banking/v1`
- SAMA Production: `https://api.sama.gov.sa/open-banking/v1` (requires TPP approval)
- Bank-specific endpoints: Registered per bank in SAMA directory

---

## 3. Bank Statement Formats

### MT940 (SWIFT Standard)

**Structure**: Text-based, field-delimited  
**Use Case**: Most widely supported legacy format; still common in GCC region

**Example**:
```
:20:STARTUMREL
:25:1234567890
:28C:00001/001
:60F:C260401SAR500000,00
:61:2604010401DR5000,00CHEQBD000123456
:86:000CHEQUE 000123456 PAYMENT TO ABC COMPANY
:61:2604020402CR25000,00XFERSBD000789
:86:INCOMING TRANSFER FROM XYZ CORP REF INV-2026-001
:62F:C260430SAR520000,00
-
```

**Key Fields**:
- `:20:` — Transaction reference (unique)
- `:25:` — Account number
- `:28C:` — Statement number / sequence
- `:60F:` — Opening balance (F=Final, C=Credit)
- `:61:` — Transaction line (date, debit/credit, amount, type, reference)
- `:86:` — Transaction description / memo
- `:62F:` — Closing balance

**Challenges**:
- Fixed-width, hard to parse programmatically
- Character set: SWIFT (limited special chars)
- No standardized field meanings (`:86:` is bank-specific)

**Parser Reference** (Python):
```python
def parse_mt940(file_content: str) -> dict:
    lines = file_content.strip().split('\n')
    transactions = []
    current_transaction = {}
    
    for line in lines:
        if line.startswith(':61:'):
            # Parse transaction line: :61:YYMMDDMMDD{CR|DR}amount{currency}
            date = line[4:10]
            debit_credit = line[10:12]
            amount_str = line[12:].split('CHEQ')[0].split('XFRS')[0].strip()
            current_transaction = {
                'date': date,
                'type': 'DEBIT' if debit_credit == 'DR' else 'CREDIT',
                'amount': float(amount_str.replace(',', '').replace('.', ''))
            }
            transactions.append(current_transaction)
        elif line.startswith(':86:'):
            if current_transaction:
                current_transaction['description'] = line[4:]
    
    return {'transactions': transactions}
```

---

### CAMT.053 (ISO 20022 XML)

**Structure**: XML document; internationally standardized  
**Use Case**: Emerging standard in MENA (CBUAE mandates this); SAMA moving toward it

**Example**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkStmt>
    <GrpHdr>
      <MsgId>STMT-2026-04-30-001</MsgId>
      <CreDtTm>2026-04-30T15:00:00</CreDtTm>
    </GrpHdr>
    <Stmt>
      <Acct>
        <Id>1234567890</Id>
        <Ccy>SAR</Ccy>
        <Nm>Current Account</Nm>
      </Acct>
      <Bal>
        <Amt Ccy="SAR">500000.00</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <Dt>2026-04-01</Dt>
      </Bal>
      <Txn>
        <Amt Ccy="SAR">5000.00</Amt>
        <CdtDbtInd>DBDT</CdtDbtInd>
        <BookgDt>2026-04-01</BookgDt>
        <ValDt>2026-04-01</ValDt>
        <BkTxCd>
          <Domn>PMNT</Domn>
          <Prtry>CHK</Prtry>
        </BkTxCd>
        <RltdPties>
          <Dbtr>
            <Nm>ABC Company LLC</Nm>
          </Dbtr>
        </RltdPties>
        <RmtInf>
          <Ustrd>Invoice INV-2026-001 payment</Ustrd>
          <Strd>
            <CdtrRefInf>
              <Ref>INV-2026-001</Ref>
            </CdtrRefInf>
          </Strd>
        </RmtInf>
      </Txn>
      <ClosingBalance>
        <Amt Ccy="SAR">520000.00</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <Dt>2026-04-30</Dt>
      </ClosingBalance>
    </Stmt>
  </BkStmt>
</Document>
```

**Key Elements**:
- `<Acct>` — Account details
- `<Bal>` — Opening/Closing balance
- `<Txn>` — Transaction (repeats per line)
- `<RmtInf>` — Remittance info (invoice refs, descriptions)
- `<BkTxCd>` — Bank transaction code (domain + proprietary)
- `<Ustrd>` — Unstructured text (memo)
- `<Strd>` — Structured remittance (ISO 20022 SEPA format)

**Advantages**:
- XML parseable by standard libraries
- Structured remittance info enables automatic matching
- ISO standard (future-proof)

---

### BAI2 (Automated Clearing House - US Format)

**Structure**: Text-based, colon-delimited  
**Use Case**: Legacy US/international; rare in MENA but sometimes used by multinational corps

**Example**:
```
101 121000248 1234567890 260430 1500 001 094101 0 1,
202 1234567890 SAR 260401 500000,00,0,
300 010 0 0,
330 0101 260401 260401 5000,00 040 000123456,,ABC Company,
330 0102 260402 260402 25000,00 100 000789,,XYZ CORP,
400 010 0 0,
500 010 0 0,
900 1 1 2,
```

**Structure**:
- Line 101: File header
- Line 202: Account trailer
- Line 300/330: Transaction detail
- Line 400/500: Block/File trailer
- Line 900: File control

---

### CSV/Excel Patterns from Saudi Banks

**Common Format** (bank-provided exports):
```
Account Number,Date,Debit,Credit,Balance,Reference,Description
1234567890,2026-04-01,5000.00,,495000.00,000123456,Cheque 000123456
1234567890,2026-04-02,,25000.00,520000.00,000789,Transfer from XYZ
```

**Challenges**:
- No standardization across banks
- Date format varies (DD/MM/YYYY vs YYYY-MM-DD)
- No structured remittance info
- Duplicates in bulk exports (same txn on multiple dates)

---

## 4. Bank Reconciliation Algorithms

### Core Matching Strategies

#### 1. Exact Match (Highest Confidence)

```python
def exact_match(ledger_entry: Dict, bank_txn: Dict) -> bool:
    """
    Match if amount, date, and reference match exactly.
    Confidence: 99%
    """
    return (
        ledger_entry['amount'] == bank_txn['amount']
        and ledger_entry['date'] == bank_txn['date']
        and ledger_entry['reference'] == bank_txn['reference']
    )
```

**Use Case**: Invoice payments, payroll, SADAD bills  
**Time Window**: Booking date ±0 days (same day)

---

#### 2. Fuzzy Amount Match with Date Window

```python
def fuzzy_match(ledger_entry: Dict, bank_txn: Dict, 
                amount_tolerance_pct: float = 0.05,
                date_window_days: int = 3) -> bool:
    """
    Match if amount within tolerance and date within window.
    Tolerance: ±5% (configurable)
    Confidence: 85-90%
    """
    amount_diff = abs(ledger_entry['amount'] - bank_txn['amount'])
    amount_match = (amount_diff / bank_txn['amount']) <= amount_tolerance_pct
    
    date_diff = abs((ledger_entry['date'] - bank_txn['date']).days)
    date_match = date_diff <= date_window_days
    
    return amount_match and date_match
```

**Use Case**: Bank fees (variable), FX conversions, partial payments  
**Typical Windows**:
- Debit (outbound): ±3 days (bank processing delay)
- Credit (inbound): ±5 days (clearing time for checks, transfers)

---

#### 3. Reference Number Match

```python
def reference_match(ledger_entry: Dict, bank_txn: Dict) -> bool:
    """
    Match by reference number (invoice, PO, check number).
    Handles amount discrepancies (e.g., payment + discount).
    Confidence: 90%
    """
    ledger_refs = extract_refs(ledger_entry['description'])  # INV-2026-001
    bank_refs = extract_refs(bank_txn['description'])
    
    return bool(ledger_refs & bank_refs)  # Intersection
```

**Use Case**: Invoice reconciliation, AR/AP matching  
**Extraction Pattern** (Regex):
```python
def extract_refs(text: str) -> set:
    patterns = [
        r'INV-\d{4}-\d{3,5}',   # Invoice
        r'PO-\d{4,6}',          # Purchase Order
        r'CHK\d{6}',            # Check number
    ]
    refs = set()
    for pattern in patterns:
        refs.update(re.findall(pattern, text, re.IGNORECASE))
    return refs
```

---

#### 4. AI-Assisted Matching (ML/NLP)

```python
def ai_match(ledger_entry: Dict, bank_txn: Dict, 
             anthropic_client) -> tuple[bool, float]:
    """
    Use Claude API for semantic matching.
    Compare descriptions, counterparties, amounts.
    Confidence: 70-95% (model-dependent)
    """
    prompt = f"""
    Are these two transactions the same? Answer YES or NO.
    
    Ledger Entry:
    - Date: {ledger_entry['date']}
    - Amount: {ledger_entry['amount']} SAR
    - Description: {ledger_entry['description']}
    - Counterparty: {ledger_entry.get('counterparty', 'N/A')}
    
    Bank Transaction:
    - Date: {bank_txn['date']}
    - Amount: {bank_txn['amount']} SAR
    - Description: {bank_txn['description']}
    - Counterparty: {bank_txn.get('counterparty', 'N/A')}
    
    Consider: Same amount? Same date (±5 days)? Same counterparty (fuzzy)?
    """
    
    response = anthropic_client.messages.create(
        model="claude-opus-4-1-20250805",
        max_tokens=10,
        messages=[{"role": "user", "content": prompt}]
    )
    
    is_match = "YES" in response.content[0].text
    confidence = 0.85 if is_match else 0.10
    return is_match, confidence
```

**Use Cases**:
- Transactions with merchant name variations
- FX conversions with unknown rates
- Partial payment scenarios

**Cost**: ~$0.005 per API call; use sparingly (batch 100+ txns per call)

---

### State Machine: Reconciliation Workflow

```
┌─────────────┐
│   PENDING   │  Entry created, awaiting bank statement
└──────┬──────┘
       │ Bank txn received
       ↓
┌─────────────┐
│  CANDIDATE  │  Potential matches found (1+ match)
└──────┬──────┘
       │ User selects match / Auto-confirm (exact)
       ↓
┌─────────────┐
│  MATCHED    │  Paired; awaiting final confirmation
└──────┬──────┘
       │ User reviews, confirms
       ↓
┌─────────────┐
│  CLEARED    │  ✓ Reconciled; closes account
└─────────────┘

UNMATCHED (Dead-letter):
┌──────────────────────────────┐
│ After 60 days in PENDING     │
│ → Flag as UNMATCHED_LEDGER   │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Bank txn, no GL match        │
│ → Flag as UNMATCHED_BANK     │
└──────────────────────────────┘
```

---

### Reconciliation Rules Engine

```python
@dataclass
class ReconciliationRule:
    """Define matching logic per account/transaction type."""
    name: str
    matching_strategy: str  # 'EXACT', 'FUZZY', 'REFERENCE', 'AI'
    amount_tolerance_pct: float = 0.0
    date_window_days: int = 0
    enabled: bool = True
    priority: int = 100  # Lower = higher priority
    
    def matches(self, ledger: Dict, bank: Dict) -> bool:
        if not self.enabled:
            return False
        
        if self.matching_strategy == 'EXACT':
            return exact_match(ledger, bank)
        elif self.matching_strategy == 'FUZZY':
            return fuzzy_match(ledger, bank, self.amount_tolerance_pct, 
                             self.date_window_days)
        elif self.matching_strategy == 'REFERENCE':
            return reference_match(ledger, bank)
        else:
            return False

# Example rules for a Saudi company
RULES = [
    ReconciliationRule(
        name="Exact Invoice Payment",
        matching_strategy="EXACT",
        priority=1
    ),
    ReconciliationRule(
        name="Payroll (±2 days, ±SAR 100)",
        matching_strategy="FUZZY",
        amount_tolerance_pct=0.01,
        date_window_days=2,
        priority=2
    ),
    ReconciliationRule(
        name="Bank Fees (fuzzy match)",
        matching_strategy="FUZZY",
        amount_tolerance_pct=0.05,
        date_window_days=1,
        priority=3
    ),
]

# Matching algorithm
def reconcile(ledger_entries: List, bank_txns: List) -> List[Tuple]:
    matches = []
    for rule in sorted(RULES, key=lambda r: r.priority):
        for led in ledger_entries:
            for bank in bank_txns:
                if rule.matches(led, bank):
                    matches.append((led, bank, rule.name))
                    bank_txns.remove(bank)
                    break
    return matches
```

---

## 5. Payment Gateways Comparison

### Comprehensive Gateway Matrix

| **Gateway** | **Regions** | **Fee Structure** | **Settlement** | **Methods** | **API Grade** | **Webhook Support** | **Saudi Compliance** |
|---|---|---|---|---|---|---|---|
| **Stripe** | Global | 2.9% + $0.30 (int'l); 2.2% AED/SAR locals | 1-2 days | Cards, Apple Pay, Google Pay, iDEAL | ★★★★★ | Robust | ✓ PCI SAQ A-EP |
| **Mada** | KSA only | ~1% | T+1 | Mada debit cards | ★★★☆☆ | Basic | ✓ National scheme |
| **HyperPay** | KSA, UAE, EG | 2.5-3% + gateway fee | T+2 | Cards, mada, Apple, STC Pay, Ooredoo | ★★★★☆ | Webhooks | ✓ Mada partner |
| **PayTabs** | MENA | 2.5% + SAR 0.50 | T+1 | Cards, mada, Fawry, Vodafone | ★★★★☆ | REST webhooks | ✓ Mada partner |
| **Tap Payments** | GCC | 2.85% | T+1 | Cards, knet, mada, benefit, UnionPay | ★★★★☆ | Push notifications | ✓ Mada + local debit |
| **Paymob** | Egypt-focused | 1.99-2.49% | T+1 | Cards, Fawry, Vodafone Cash, Orange | ★★★★☆ | Webhook system | ✓ EGP local |
| **Geidea** | KSA-focused | ~1-1.5% | T+1 | mada, Apple Pay, Google Pay | ★★★★☆ | Event-driven API | ✓ Saudi national |
| **2Checkout** | Global | 3.5-5.5% | 30 days | 100+ methods, alt-coins | ★★★☆☆ | Webhooks | ⚠ Card-only |
| **Square** | Expanding MENA | 2.6% + 1% int'l | 1-3 days | Cards, digital wallets | ★★★★☆ | Webhooks | Limited in KSA |

---

### Detailed Gateway Profiles

#### Stripe (Global Leader)

**Strengths**:
- Best-in-class API (REST, webhooks, SDKs in 10+ languages)
- PCI DSS SAQ A-EP compliant
- Stripe Tax for automated VAT/GST handling
- Built-in reconciliation reports
- Developer-friendly dashboard
- Fraud detection (Radar)

**Weaknesses**:
- 2.9% + $0.30 = ~3.2% in USD (expensive for GCC, ~2.2% AED/SAR)
- Limited local payment methods in MENA (recently added Apple Pay)
- Requires Stripe Connect for marketplace (commission model)

**APEX Integration Model**:
```python
import stripe

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

def create_subscription(customer_email: str, plan_id: str, 
                       company_name: str) -> str:
    """Create monthly SaaS subscription."""
    customer = stripe.Customer.create(
        email=customer_email,
        description=company_name,
        metadata={"company_id": company_name}
    )
    
    subscription = stripe.Subscription.create(
        customer=customer.id,
        items=[{"price": plan_id}],
        payment_behavior="default_incomplete",
        expand=["latest_invoice.payment_intent"]
    )
    
    return subscription.id

def handle_webhook(event_type: str, data: dict):
    """Process Stripe webhook events."""
    if event_type == "payment_intent.succeeded":
        invoice_id = data['metadata']['invoice_id']
        update_invoice_status(invoice_id, 'PAID')
    elif event_type == "customer.subscription.deleted":
        customer_id = data['customer']
        cancel_subscription(customer_id)
```

---

#### Mada (Saudi National Scheme)

**Strengths**:
- ~1% commission (lowest in region)
- T+1 settlement to bank accounts
- Mandatory for all KSA payment systems
- PCI DSS Level 1 (bank-grade security)

**Weaknesses**:
- KSA-only coverage
- Limited API documentation (requires direct bank integration)
- No global payment methods (cards, PayPal, etc.)
- Slow onboarding (30-60 days for approval)

**How It Works**:
- Mada cards are debit-only; require tokenization for subscriptions
- Merchant must register with SAMA through a bank
- Settlement to merchant's bank account daily/T+1
- Chargeback liability: 100% on merchant (no Mada protection)

**APEX Integration**:
```python
# Via Mada API (requires bank sponsorship)
def tokenize_mada_card(card_number: str, expiry: str) -> str:
    """
    Mada card tokenization for recurring subscriptions.
    Returns token for future charges without re-entry.
    """
    payload = {
        "cardNumber": card_number,
        "expiryDate": expiry,
        "cvv": "***",  # Captured separately
    }
    response = requests.post(
        "https://api.mada.com.sa/tokenize",
        json=payload,
        headers={"Authorization": f"Bearer {MADA_API_KEY}"}
    )
    return response.json()['token']

def charge_mada_token(token: str, amount_sar: float, 
                      invoice_id: str) -> str:
    """Charge tokenized Mada card."""
    response = requests.post(
        "https://api.mada.com.sa/charge",
        json={
            "token": token,
            "amount": int(amount_sar * 100),  # Smallest unit
            "currency": "SAR",
            "reference": invoice_id,
        }
    )
    return response.json()['transactionId']
```

---

#### HyperPay (Multi-Country MENA)

**Strengths**:
- Multi-country coverage (KSA, UAE, Egypt)
- Supports mada, Apple Pay, STC Pay, Ooredoo
- REST API + SDK support
- 2.5-3% fees (mid-range for region)

**Weaknesses**:
- Limited technical documentation
- Payment reconciliation requires manual dashboard checks
- No advanced fraud detection

**APEX Integration**:
```python
def create_hyperpay_payment(amount_sar: float, customer_email: str) -> dict:
    """Initiate HyperPay session."""
    payload = {
        "apiOperation": "INITIATE_PAYMENT",
        "apiPassword": HYPERPAY_API_PASSWORD,
        "order": {
            "amount": amount_sar,
            "currency": "SAR",
            "reference": str(uuid.uuid4()),
            "description": "APEX SaaS Subscription"
        },
        "billing": {
            "address": {
                "email": customer_email
            }
        }
    }
    
    response = requests.post(
        "https://api.hyperpay.com/v2/initiate",
        json=payload
    )
    
    session_id = response.json()['sessionId']
    return {
        "redirect_url": f"https://hyperpay.com/payment/{session_id}",
        "session_id": session_id
    }
```

---

#### PayTabs (MENA Regional)

**Strengths**:
- MENA-native; familiar with local compliance
- Mada + Fawry (Egypt) + Vodafone Cash integration
- REST webhooks for async payments
- SAR 0.50 + 2.5% fee (competitive)

**Weaknesses**:
- Limited international card support
- Webhook reliability (occasional missed events)
- No native tax calculation

**APEX Integration**:
```python
def create_paytabs_payment(amount_sar: float, 
                           invoice_id: str) -> str:
    """Create PayTabs payment token."""
    auth_token = get_paytabs_auth_token()
    
    response = requests.post(
        "https://secure.paytabs.com/payment/request",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "profile_id": PAYTABS_PROFILE_ID,
            "tran_type": "purchase",
            "tran_class": "ecom",
            "cart_amount": amount_sar,
            "cart_currency": "SAR",
            "cart_id": invoice_id,
            "return_url": "https://apex.com/payments/callback",
        }
    )
    
    return response.json()['payment_token']

@app.post("/payments/paytabs-webhook")
async def paytabs_webhook(request: Request):
    """Handle PayTabs payment confirmation."""
    payload = await request.json()
    
    if payload['response_code'] == '0':  # Success
        invoice_id = payload['cart_id']
        amount = payload['amount']
        update_invoice(invoice_id, status='PAID', amount_received=amount)
    
    return {"status": "acknowledged"}
```

---

#### Tap Payments (GCC-Focused)

**Strengths**:
- Best for GCC (knet, mada, benefit, UnionPay)
- 2.85% fees (slightly lower)
- Push notification webhooks
- White-label POS support

**Weaknesses**:
- Limited Egypt/Jordan support
- Complex webhook payload (requires careful parsing)

---

#### Paymob (Egypt Specialist)

**Strengths**:
- Fawry + Vodafone Cash + Orange Money integration
- Best fees for Egypt (1.99-2.49%)
- Large customer base in Egypt
- Strong dispute resolution

**Weaknesses**:
- Egypt-only; limited KSA/UAE
- Currency conversion markup on international cards

---

#### Geidea (Saudi Emerging)

**Strengths**:
- Saudi-native; backed by SAMA
- Mada + Apple Pay + Google Pay
- ~1% fees (lowest for KSA)
- Instant settlement (newer feature)

**Weaknesses**:
- Newer platform (launched 2021); limited track record
- Onboarding requires specific documentation
- API still maturing

---

## 6. Stripe Deep-Dive for SaaS

### Core Stripe Objects for APEX

#### Customer Object

```python
stripe.Customer.create(
    email="finance@abccompany.com",
    name="ABC Company LLC",
    description="APEX SaaS subscriber",
    metadata={
        "company_id": "12345",
        "plan_tier": "professional",
        "region": "KSA"
    },
    address={
        "line1": "123 Business St",
        "city": "Riyadh",
        "state": "Riyadh Region",
        "postal_code": "12234",
        "country": "SA"
    },
    preferred_locales=["ar"]  # Arabic UI
)
```

**Fields**:
- `email`: Billing email for invoices
- `name`: Company/Person name
- `metadata`: Custom key-value pairs (searchable)
- `address`: Billing address (required for some regions)
- `tax_ids`: VAT number for automated tax calculation

---

#### Subscription Lifecycle

```
User → Plan Selection → Create Subscription → TRIALING (if trial)
                                                    ↓
                                              ACTIVE (paying)
                                                    ↓
                                              payment_failed
                                                    ↓
                                              PAST_DUE (unpaid invoice)
                                                    ↓
                                              CANCELED (user or auto)

STATE DIAGRAM:

    ┌─────────────┐
    │  TRIALING   │ (14-day free trial, no payment required)
    └──────┬──────┘
           │ trial_end (explicit or auto-subscribe)
           ↓
    ┌─────────────┐
    │   ACTIVE    │ (billing occurs, payment_intent created)
    └──────┬──────┘
           │ payment_intent.succeeded → next billing cycle
           │
           │ payment_intent.payment_failed → retry logic
           ↓
    ┌─────────────┐
    │  PAST_DUE   │ (invoice unpaid, retries exhausted)
    └──────┬──────┘
           │ Manual intervention or payment
           ↓
    ┌─────────────┐
    │  CANCELED   │ (terminal; cannot resume)
    └─────────────┘
```

---

#### Payment Intent API

```python
# Create payment for subscription
payment_intent = stripe.PaymentIntent.create(
    amount=int(monthly_price_sar * 100),  # In SAR cents
    currency="sar",
    customer=customer_id,
    description=f"Subscription: {subscription_id}",
    metadata={"subscription_id": subscription_id},
    off_session=True,  # Card stored; no user interaction
    confirm=True,  # Charge immediately
    payment_method=card_token  # Saved card
)

# Possible states
if payment_intent.status == "succeeded":
    # Payment succeeded
elif payment_intent.status == "requires_action":
    # SCA (3D Secure) needed
    client_secret = payment_intent.client_secret
    # Redirect to Stripe confirmation page
elif payment_intent.status == "processing":
    # Async processing (ACH, bank transfers)
    pass
```

---

#### Webhook Events

**Key Events for SaaS**:

```python
WEBHOOK_EVENTS = {
    "payment_intent.succeeded": {
        "trigger": "Payment captured",
        "action": "Update invoice.status = PAID"
    },
    "payment_intent.payment_failed": {
        "trigger": "Card declined or timeout",
        "action": "Retry logic; notify customer"
    },
    "invoice.payment_failed": {
        "trigger": "Invoice unpaid after retries",
        "action": "Send dunning email; mark for collection"
    },
    "customer.subscription.created": {
        "trigger": "New subscription",
        "action": "Provision access; send onboarding"
    },
    "customer.subscription.updated": {
        "trigger": "Plan change, seat count, etc.",
        "action": "Update billing metadata; prorate"
    },
    "customer.subscription.deleted": {
        "trigger": "Cancellation by user or system",
        "action": "Revoke access; log churn reason"
    },
    "charge.refunded": {
        "trigger": "Full or partial refund",
        "action": "Update invoice; audit log"
    },
    "customer.created": {
        "trigger": "New customer in Stripe",
        "action": "Sync to APEX DB"
    }
}
```

---

#### Stripe Tax for VAT/GST

```python
# Enable tax calculation on subscription
subscription = stripe.Subscription.create(
    customer=customer_id,
    items=[{"price": plan_id}],
    automatic_tax={
        "enabled": True  # Auto-detect customer's tax jurisdiction
    }
)

# Invoice will include:
# - Subtotal: SAR 500
# - Tax (15% VAT): SAR 75
# - Total: SAR 575

# For SAR vs AED vs EGP:
# - KSA: 15% VAT (GAZT)
# - UAE: 5% VAT
# - Egypt: 14% VAT
```

**IMPORTANT**: Stripe Tax requires customer address (country, state). APEX must collect this at signup.

---

#### Idempotency & Retry Logic

```python
import uuid
from datetime import datetime, timedelta

def charge_subscription_safe(subscription_id: str, 
                             amount_sar: float) -> str:
    """
    Idempotent charge; safe to retry without duplication.
    Idempotency key: unique per attempt, same per retry.
    """
    idempotency_key = f"{subscription_id}:{datetime.utcnow().date()}"
    
    try:
        payment_intent = stripe.PaymentIntent.create(
            amount=int(amount_sar * 100),
            currency="sar",
            customer=subscription_id,
            idempotency_key=idempotency_key,  # ← KEY
            confirm=True
        )
        return payment_intent.id
    except stripe.error.CardError as e:
        # Retry with exponential backoff
        wait_seconds = 2 ** (attempt_count)
        if wait_seconds < 300:  # 5 min max
            await asyncio.sleep(wait_seconds)
            return charge_subscription_safe(subscription_id, amount_sar)
        else:
            raise

# Idempotency Key Strategy:
# Format: {customer_id}:{billing_cycle_date}
# Example: cus_A1B2C3D4E5F6:2026-04-30
# 
# Stripe stores result for 24 hours (retry window)
# Same key = same response (no duplicate charge)
```

---

#### Stripe Connect for Marketplace (Provider Payouts)

APEX use case: Marketplace for accounting providers, where APEX takes commission

```python
# Step 1: Create Connected Account (provider/vendor)
connected_account = stripe.Account.create(
    type="express",  # Simpler onboarding
    country="SA",
    email="provider@accountingfirm.com",
    capabilities={
        "transfers": {
            "requested": True  # Provider can receive payouts
        }
    }
)
provider_account_id = connected_account.id

# Step 2: Create charge on Connected Account (APEX marketplace)
charge = stripe.Charge.create(
    amount=int(100000),  # SAR 1,000 service fee
    currency="sar",
    customer=company_customer_id,
    stripe_account=provider_account_id,  # ← Routes to provider's account
    description="Accounting service"
)

# Step 3: Create payout (provider receives funds)
payout = stripe.Payout.create(
    amount=int(85000),  # After 15% APEX commission
    currency="sar",
    stripe_account=provider_account_id  # Routes to provider's bank
)

# APEX Commission Model:
# Company pays: SAR 1,000
# Provider receives: SAR 850 (after 15% APEX cut)
# APEX takes: SAR 150
```

---

## 7. Saudi-Specific Payment Requirements

### Mada Compliance

**Mandatory for Saudi Arabia**:
- All payment systems must support Mada cards
- Mada is the national debit scheme; 85%+ of Saudi consumers use it
- Integration required by law for payment processors

**Mada Card Features**:
- Debit-only (no credit line)
- Supports offline transactions (contactless)
- Tokenization support for subscriptions (via bank)
- PCI DSS Level 1

**APEX Mada Integration**:
```python
def process_mada_payment(card_token: str, amount_sar: float,
                         invoice_id: str) -> dict:
    """
    Process via Mada network.
    Requires tokenized card (handled by payment gateway).
    """
    payload = {
        "token": card_token,
        "amount": int(amount_sar * 100),
        "currency": "SAR",
        "orderId": invoice_id,
    }
    
    response = requests.post(
        "https://mada.net.sa/api/v1/payments",
        json=payload,
        headers={"Authorization": f"Bearer {MADA_API_KEY}"}
    )
    
    return {
        "status": response.json()['status'],
        "transaction_id": response.json()['rrn'],  # Reference number
        "amount": amount_sar,
        "timestamp": datetime.utcnow()
    }
```

---

### Apple Pay & Google Pay Tokenization

**Saudi Consumer Adoption**:
- Apple Pay: Growing (iPhone users with Saudi bank apps)
- Google Pay: Strong (Android majority market)

**Tokenization Flow**:
```
User taps Apple Pay → Bank app/biometric auth → Tokenized card
                                                       ↓
                        APEX receives token (not card number)
                                                       ↓
                        Token sent to Stripe/HyperPay for processing
```

**APEX Implementation**:
```python
def handle_apple_pay_token(apple_pay_token: str, 
                           amount_sar: float) -> str:
    """
    Apple Pay sends tokenized card; APEX processes via Stripe.
    Token is single-use and merchant-specific.
    """
    payment_method = stripe.PaymentMethod.create(
        type="card",
        card={"token": apple_pay_token}  # Apple's PKPaymentToken
    )
    
    payment_intent = stripe.PaymentIntent.create(
        amount=int(amount_sar * 100),
        currency="sar",
        payment_method=payment_method.id,
        confirm=True
    )
    
    return payment_intent.id
```

---

### SADAD (Saudi Bill Payment System)

**What Is SADAD**:
- Centralized bill payment network operated by SAMA
- Allows customers to pay utility bills, insurance, fines via ATM/online banking
- Company must register as SADAD biller

**APEX Use Case**:
- Accept payment for professional services via SADAD
- Customer pays at ATM or bank website without card

**Integration**:
```python
# APEX must provide SADAD biller code
SADAD_BILLER_CODE = "123456789"

def create_sadad_bill(customer_id: str, amount_sar: float,
                      invoice_id: str) -> dict:
    """
    Create SADAD bill for customer payment.
    Customer pays at bank ATM.
    """
    response = requests.post(
        "https://sadad.sama.gov.sa/api/v1/bills",
        json={
            "biller_code": SADAD_BILLER_CODE,
            "bill_id": invoice_id,
            "customer_id": customer_id,
            "amount": int(amount_sar * 100),
            "due_date": "2026-05-30",
            "description": "APEX SaaS Monthly Fee"
        }
    )
    
    return {
        "sadad_reference": response.json()['reference_number'],
        "status": "PENDING"  # Waits for customer ATM payment
    }
```

---

### SARIE (Instant Payments / RTGS)

**What Is SARIE**:
- Real-Time Gross Settlement (RTGS) system operated by SAMA
- 24/7 interbank fund transfers in SAR
- Replaces legacy SADAD for instant corporate payments

**APEX Integration**:
```python
def initiate_sarie_transfer(from_account: str, to_account: str,
                            to_bank: str, amount_sar: float,
                            invoice_id: str) -> dict:
    """
    Initiate SARIE payment (instant settlement).
    Requires SAMA Open Banking API access.
    """
    payload = {
        "fromAccount": from_account,
        "toAccount": to_account,
        "toBankCode": to_bank,  # SWIFTBIC or SAMA bank code
        "amount": amount_sar,
        "currency": "SAR",
        "reference": invoice_id,
        "description": "Invoice payment",
        "executionTime": "2026-05-01T09:00:00Z"
    }
    
    response = requests.post(
        "https://api.sama.gov.sa/sarie/v1/transfers",
        json=payload,
        headers={"Authorization": f"Bearer {SAMA_API_TOKEN}"}
    )
    
    return response.json()
```

---

## 8. WPS (Wage Protection System)

**Saudi WPS** (via SAMA):
- Employer must register employees
- Monthly payroll submitted in .SIF format
- Monitors wage payment compliance
- Mandatory for all employers (private + public sector)

**UAE WPS** (via Ministry of Human Resources):
- Similar to Saudi; applies to UAE-based employees
- Tracks employment duration, wage deductions
- Protects migrant workers

**Exemption Thresholds**:
- Saudi: All employees must be registered (no exemption)
- UAE: All employees mandatory

**APEX WPS Module** (future enhancement):

```python
from datetime import datetime
from dataclasses import dataclass

@dataclass
class EmployeePayroll:
    employee_id: str
    name: str
    salary_sar: float
    allowances_sar: float = 0
    deductions_sar: float = 0  # Tax, insurance, etc.
    payment_date: datetime
    
    def net_pay(self) -> float:
        return self.salary_sar + self.allowances_sar - self.deductions_sar

def export_wps_file(payroll_data: List[EmployeePayroll], 
                    company_id: str) -> str:
    """
    Export payroll in SAMA WPS .SIF (Salary Information Format).
    Format: Pipe-separated values with fixed structure.
    """
    lines = []
    lines.append(f"HEADER|{company_id}|{datetime.now().strftime('%Y%m%d')}|")
    
    total_amount = 0
    for emp in payroll_data:
        line = f"DETAIL|{emp.employee_id}|{emp.name}|{int(emp.net_pay()*100)}|"
        lines.append(line)
        total_amount += emp.net_pay()
    
    lines.append(f"TRAILER|{len(payroll_data)}|{int(total_amount*100)}|")
    
    return "\n".join(lines)
```

**File Submission Flow**:
1. APEX exports payroll in .SIF format
2. Company uploads to SAMA WPS portal
3. SAMA validates (payroll > minimum wage, deductions within limits)
4. Payment settlement occurs via SARIE (RTGS)
5. SAMA confirms receipt; employees see in app

---

## 9. Direct Debit & Standing Orders

### SAMA Direct Debit

**What Is SAMA Direct Debit**:
- Customer authorizes recurring charge to their account
- No need to re-enter card for each subscription payment
- Requires Mandate (customer consent)

**Mandate Creation**:
```python
def create_direct_debit_mandate(customer_id: str, company_id: str,
                                 amount_sar: float, 
                                 frequency: str) -> dict:
    """
    Create recurring debit mandate.
    Frequency: MONTHLY, QUARTERLY, ANNUAL
    Customer must confirm in their bank app.
    """
    payload = {
        "customerAccountId": customer_id,
        "creditorId": company_id,  # APEX merchant ID
        "amount": amount_sar,
        "frequency": frequency,
        "startDate": "2026-05-01",
        "endDate": "2027-04-30",
        "description": "APEX SaaS Subscription"
    }
    
    response = requests.post(
        "https://api.sama.gov.sa/direct-debit/v1/mandates",
        json=payload,
        headers={"Authorization": f"Bearer {SAMA_API_TOKEN}"}
    )
    
    mandate = response.json()
    # Customer receives SMS/email to confirm mandate
    return {
        "mandate_id": mandate['id'],
        "status": "PENDING_CUSTOMER_CONFIRMATION",
        "confirmation_url": mandate['confirmationUrl']
    }

def charge_direct_debit_mandate(mandate_id: str, 
                                amount_sar: float) -> dict:
    """
    Trigger debit for this billing cycle.
    Automatic; no customer action needed.
    """
    response = requests.post(
        f"https://api.sama.gov.sa/direct-debit/v1/mandates/{mandate_id}/charge",
        json={"amount": amount_sar},
        headers={"Authorization": f"Bearer {SAMA_API_TOKEN}"}
    )
    
    return {
        "charge_id": response.json()['chargeId'],
        "status": "PROCESSING",
        "expected_settlement": "T+1"
    }
```

---

### Mada-Native Subscriptions (Recently Launched)

**New Feature** (Q1 2025):
- Mada cards now support subscription tokenization
- Merchant can charge same Mada card monthly
- No need for customer re-entry; one-time authorization

**Implementation**:
```python
def mada_subscribe(mada_card_token: str, monthly_amount_sar: float,
                   customer_id: str) -> str:
    """
    Register Mada card for monthly subscription.
    Token is merchant-specific; cannot be shared across merchants.
    """
    response = requests.post(
        "https://mada.net.sa/api/v1/subscriptions",
        json={
            "cardToken": mada_card_token,
            "monthlyAmount": monthly_amount_sar,
            "currency": "SAR",
            "customerId": customer_id,
            "startDate": "2026-05-01"
        }
    )
    
    subscription_id = response.json()['subscriptionId']
    return subscription_id

def mada_charge_subscription(subscription_id: str) -> dict:
    """Charge active subscription (automatic monthly)."""
    response = requests.post(
        f"https://mada.net.sa/api/v1/subscriptions/{subscription_id}/charge",
        json={}
    )
    
    return {
        "transaction_id": response.json()['txnId'],
        "amount": response.json()['amount'],
        "status": "SUCCESS"
    }
```

---

## 10. Webhooks & Event Processing Pattern

### Webhook Handler Architecture

```python
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
import hmac
import hashlib
import json
from typing import Optional

app = FastAPI()

class WebhookSignature:
    """Verify webhook authenticity (prevent replay attacks)."""
    
    @staticmethod
    def verify_stripe_signature(payload: str, signature: str, 
                                webhook_secret: str) -> bool:
        """
        Stripe sends X-Stripe-Signature header.
        Format: t=timestamp,v1=computed_signature
        """
        try:
            timestamp, computed_sig = signature.split(',')[1].split('=')
            expected_sig = hmac.new(
                webhook_secret.encode(),
                f"{timestamp}.{payload}".encode(),
                hashlib.sha256
            ).hexdigest()
            return hmac.compare_digest(computed_sig, expected_sig)
        except:
            return False

@app.post("/webhooks/stripe")
async def stripe_webhook(request: Request):
    """
    Handle Stripe webhook events.
    Idempotent: Safe to process same event 2+ times.
    """
    payload = await request.body()
    signature = request.headers.get("X-Stripe-Signature", "")
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    
    # Verify signature
    if not WebhookSignature.verify_stripe_signature(
        payload.decode(), signature, webhook_secret
    ):
        raise HTTPException(status_code=401, detail="Invalid signature")
    
    event = json.loads(payload)
    event_id = event['id']
    
    # Check for idempotency (already processed)
    if WebhookEvent.query.filter_by(external_id=event_id).first():
        return {"status": "already_processed"}
    
    # Process event
    event_type = event['type']
    
    if event_type == "payment_intent.succeeded":
        handle_payment_succeeded(event['data'])
    elif event_type == "invoice.payment_failed":
        handle_payment_failed(event['data'])
    elif event_type == "customer.subscription.deleted":
        handle_subscription_canceled(event['data'])
    
    # Store event for audit
    db.add(WebhookEvent(
        provider="stripe",
        external_id=event_id,
        event_type=event_type,
        payload=json.dumps(event),
        processed_at=datetime.utcnow()
    ))
    db.commit()
    
    return {"status": "processed", "event_id": event_id}

def handle_payment_succeeded(data: dict):
    """Idempotent: Update invoice status."""
    payment_intent_id = data['object']['id']
    invoice_id = data['object']['metadata'].get('invoice_id')
    amount = data['object']['amount']
    
    invoice = Invoice.query.get(invoice_id)
    if invoice.status != 'PAID':  # ← Idempotency check
        invoice.status = 'PAID'
        invoice.payment_date = datetime.utcnow()
        invoice.amount_paid = amount / 100
        db.commit()
        
        # Trigger downstream: Send confirmation email, etc.
        send_payment_confirmation_email(invoice)

def handle_payment_failed(data: dict):
    """
    Payment failed; initiate retry logic.
    Stripe retries automatically; APEX sends dunning email.
    """
    invoice_id = data['object']['metadata'].get('invoice_id')
    error_code = data['object']['charge'].get('failure_code')
    
    invoice = Invoice.query.get(invoice_id)
    invoice.status = 'PAYMENT_FAILED'
    invoice.failure_reason = error_code
    db.commit()
    
    # Send customer email: "Payment declined; please update card"
    send_dunning_email(invoice)
    
    # Schedule retry (Stripe handles primary retry; APEX backup)
    schedule_retry(invoice_id, delay_hours=24)

def handle_subscription_canceled(data: dict):
    """Subscription canceled; revoke access."""
    customer_id = data['object']['customer']
    subscription_id = data['object']['id']
    
    subscription = Subscription.query.filter_by(
        stripe_customer_id=customer_id,
        stripe_id=subscription_id
    ).first()
    
    subscription.status = 'CANCELED'
    subscription.canceled_at = datetime.utcnow()
    db.commit()
    
    # Revoke access
    revoke_customer_access(customer_id)
    send_cancellation_email(customer_id)
```

---

### Retry Policies

```python
from exponential_backoff import ExponentialBackoff

class WebhookRetryPolicy:
    """Stripe retries failed webhooks; APEX must handle idempotently."""
    
    MAX_RETRIES = 5
    BACKOFF_BASE = 2  # 2^n seconds
    
    @staticmethod
    def retry_webhook(webhook_id: str, attempt: int = 1):
        """
        Exponential backoff: 2s, 4s, 8s, 16s, 32s
        Total: ~62 seconds across all retries
        """
        if attempt > WebhookRetryPolicy.MAX_RETRIES:
            log.error(f"Webhook {webhook_id} exhausted retries")
            raise Exception("Max retries exceeded")
        
        wait_seconds = (2 ** attempt) - 1  # Jitter
        
        # Sleep and retry
        time.sleep(wait_seconds)
        
        try:
            process_webhook(webhook_id)
        except Exception as e:
            log.warning(f"Webhook retry failed: {e}; attempt {attempt}")
            retry_webhook(webhook_id, attempt + 1)
```

---

## 11. PCI DSS Compliance

**PCI DSS 4.0** (Current Standard):
- Applies to any business handling credit card data
- APEX uses Stripe/payment gateways → avoid storing card data directly

---

### SAQ Types

| SAQ | Scope | Requirements | Applies To |
|-----|-------|--------------|-----------|
| **A** | No card data storage | Tokenization only | APEX (using Stripe) |
| **A-EP** | E-commerce, 3D Secure | Validation, encryption | APEX (if hosting forms) |
| **D** | Full PCI compliance | Audit, penetration testing | Banks, payment processors |

**APEX Strategy**: Use **SAQ A** (no card storage) by delegating to Stripe

---

### Implementation Best Practices

```python
# ✓ CORRECT: Card tokenized by Stripe
def create_subscription_stripe(customer_email: str, 
                               stripe_token: str):
    """Stripe creates token; APEX never sees card."""
    customer = stripe.Customer.create(
        email=customer_email,
        source=stripe_token  # Token, not card
    )
    return customer.id

# ✗ INCORRECT: Storing card data (PCI violation)
def create_subscription_unsafe(customer_email: str, 
                               card_number: str, 
                               card_csv: str):
    """DO NOT DO THIS!"""
    # Never store card_number, card_csv in database
    # Violates PCI DSS, exposes APEX to liability
    pass

# ✓ CORRECT: Use Stripe Elements for client-side tokenization
# Frontend (JavaScript):
# const stripe = Stripe('pk_test_...');
# const card = stripe.elements().create('card');
# card.mount('#card-element');
# const {token} = await stripe.createToken(card);
# Send token to APEX backend (not card data)
```

---

## 12. Refund & Chargeback Handling

### Refund Workflow

```python
def refund_payment(invoice_id: str, amount_sar: float, 
                   reason: str) -> dict:
    """
    Full or partial refund.
    Refund credited to customer's card within 3-5 business days.
    """
    invoice = Invoice.query.get(invoice_id)
    
    if amount_sar > invoice.amount_paid:
        raise ValueError("Refund exceeds paid amount")
    
    refund = stripe.Refund.create(
        payment_intent=invoice.payment_intent_id,
        amount=int(amount_sar * 100),  # SAR cents
        reason=reason,  # 'duplicate', 'fraudulent', 'requested_by_customer'
        metadata={"invoice_id": invoice_id}
    )
    
    # Record in APEX
    invoice.refund_amount = amount_sar
    invoice.refund_date = datetime.utcnow()
    invoice.status = 'REFUNDED'
    db.commit()
    
    return {
        "refund_id": refund.id,
        "amount": amount_sar,
        "status": refund.status  # 'succeeded' or 'pending'
    }
```

---

### Chargeback Defense

```python
class ChargebackHandler:
    """
    Respond to chargebacks (customer disputes).
    Stripe handles primary defense; APEX must provide evidence.
    """
    
    @staticmethod
    def dispute_evidence(dispute_id: str, invoice_id: str) -> dict:
        """
        Upload evidence to Stripe Disputes API.
        Types: Invoice, email proof of delivery, refund policy, etc.
        """
        invoice = Invoice.query.get(invoice_id)
        
        # Gather evidence
        evidence = {
            "access_activity_log": json.dumps({
                "customer_ip": invoice.customer_ip,
                "login_timestamps": invoice.login_history,
                "actions_taken": invoice.user_actions  # Edits, exports, etc.
            }),
            "billing_address": f"{invoice.customer_address}, SA",
            "customer_communication": [
                invoice.confirmation_email,
                invoice.service_start_email
            ],
            "customer_email_address": invoice.customer_email,
            "duplicate_charge_documentation": None,  # If applicable
            "product_description": "APEX Financial SaaS Platform",
            "receipt": invoice.receipt_pdf_url,
            "refund_policy": "https://apex.com/refund-policy",
            "shipping_address": None,  # Digital product
            "service_date": invoice.service_start_date.isoformat(),
            "service_documentation": invoice.user_guide_url,
        }
        
        response = stripe.Dispute.modify(
            dispute_id,
            evidence=evidence
        )
        
        return {
            "dispute_id": dispute_id,
            "evidence_status": response['evidence_details']['due_by'],
            "status": response['status']  # 'evidence_submitted'
        }
```

---

### Reserve Accounts

```python
class ReserveAccount:
    """
    Stripe holds percentage of payouts as reserve (fraud protection).
    """
    
    # Stripe Reserves (per industry risk)
    # SaaS (low risk): 0-5%
    # Marketplace (higher): 5-10%
    # High-risk (crypto, gambling): 10-25%
    
    APEX_RESERVE_PCT = 0.02  # 2% held for 180 days
    
    def calculate_net_payout(self, gross_revenue_sar: float) -> float:
        """
        Net payout after reserve + fees.
        """
        stripe_fee = gross_revenue_sar * 0.029 + 0.30  # 2.9% + SAR 0.30
        reserve_hold = gross_revenue_sar * self.RESERVE_PCT
        
        return gross_revenue_sar - stripe_fee - reserve_hold
```

---

## 13. Multi-Currency Settlement

### Stripe Multi-Currency

```python
def create_subscription_multi_currency(customer: dict) -> dict:
    """
    Customer location determines currency.
    SAR (Saudi), AED (UAE), EGP (Egypt), etc.
    """
    currency_map = {
        "SA": "sar",
        "AE": "aed",
        "EG": "egp",
        "JO": "jod",
        "KW": "kwd"
    }
    
    country_code = customer['country']
    currency = currency_map.get(country_code, "usd")
    
    # Price varies by currency
    prices_map = {
        "sar": 500,   # SAR 500/month
        "aed": 500,   # AED 500/month (SAR ~45 difference due to FX)
        "egp": 5000,  # EGP 5000/month
    }
    
    amount = prices_map.get(currency, 500)
    
    subscription = stripe.Subscription.create(
        customer=customer['stripe_id'],
        items=[{"price_data": {
            "currency": currency,
            "unit_amount": amount * 100,
            "recurring": {
                "interval": "month",
                "interval_count": 1
            }
        }}]
    )
    
    return subscription

def handle_multi_currency_fx(subscription: dict) -> dict:
    """
    FX Markup for cross-border:
    If customer in SAR zone but pays in AED, Stripe adds markup.
    """
    base_currency = "sar"
    customer_currency = subscription['customer']['country_currency']
    
    if base_currency != customer_currency:
        # Stripe FX markup: ~1.5%
        fx_rate = stripe.FxRate.get(
            from_currency=customer_currency,
            to_currency=base_currency
        )
        
        return {
            "base_rate": fx_rate['rate'],
            "stripe_markup": 0.015,
            "effective_rate": fx_rate['rate'] * 1.015
        }
```

---

## 14. Recommended APEX Integration Architecture

### Banking Abstraction Layer

```python
from abc import ABC, abstractmethod
from typing import List, Dict, Optional

# Interface: Bank Provider
class BankProvider(ABC):
    """Abstract interface for bank integrations."""
    
    @abstractmethod
    def authenticate(self, credentials: Dict) -> str:
        """Return access token."""
        pass
    
    @abstractmethod
    def get_accounts(self, token: str) -> List[Dict]:
        """Retrieve customer accounts."""
        pass
    
    @abstractmethod
    def get_transactions(self, account_id: str, token: str,
                         from_date: str, to_date: str) -> List[Dict]:
        """Retrieve account transactions."""
        pass
    
    @abstractmethod
    def initiate_payment(self, token: str, payload: Dict) -> Dict:
        """Initiate payment."""
        pass

# Implementation: SAMA Open Banking Adapter
class SamaBankAdapter(BankProvider):
    """SAMA Open Banking API integration."""
    
    def __init__(self, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.api_base = "https://api.sama.gov.sa/open-banking/v1"
    
    def authenticate(self, credentials: Dict) -> str:
        """OAuth 2.0 authorization code flow."""
        auth_code = credentials['auth_code']
        
        token_response = requests.post(
            f"{self.api_base}/oauth/token",
            data={
                "grant_type": "authorization_code",
                "code": auth_code,
                "client_id": self.client_id,
                "client_secret": self.client_secret
            }
        )
        
        return token_response.json()['access_token']
    
    def get_accounts(self, token: str) -> List[Dict]:
        """AIS: Get account list."""
        response = requests.get(
            f"{self.api_base}/accounts",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        return response.json()['data']['accounts']
    
    def get_transactions(self, account_id: str, token: str,
                         from_date: str, to_date: str) -> List[Dict]:
        """AIS: Get transactions."""
        response = requests.get(
            f"{self.api_base}/accounts/{account_id}/transactions",
            params={"from": from_date, "to": to_date},
            headers={"Authorization": f"Bearer {token}"}
        )
        
        return response.json()['data']['transactions']
    
    def initiate_payment(self, token: str, payload: Dict) -> Dict:
        """PIS: Initiate payment."""
        response = requests.post(
            f"{self.api_base}/payments",
            json=payload,
            headers={"Authorization": f"Bearer {token}"}
        )
        
        return response.json()['data']

# Implementation: Mock Bank Adapter (testing/dev)
class MockBankAdapter(BankProvider):
    """Mock adapter for development/testing."""
    
    def authenticate(self, credentials: Dict) -> str:
        return "mock_token_12345"
    
    def get_accounts(self, token: str) -> List[Dict]:
        return [
            {
                "accountId": "ACC-001",
                "name": "Test Account",
                "balance": {"amount": 100000.00, "currency": "SAR"}
            }
        ]
    
    def get_transactions(self, account_id: str, token: str,
                         from_date: str, to_date: str) -> List[Dict]:
        return [
            {
                "transactionId": "TXN-001",
                "date": "2026-04-30",
                "amount": -5000.00,
                "description": "Sample transaction"
            }
        ]
    
    def initiate_payment(self, token: str, payload: Dict) -> Dict:
        return {
            "paymentId": "PAY-001",
            "status": "PENDING_AUTHORIZATION"
        }

# Factory: Bank Provider Factory
class BankProviderFactory:
    """Create appropriate bank adapter based on config."""
    
    _providers = {
        "sama": SamaBankAdapter,
        "mock": MockBankAdapter,
    }
    
    @staticmethod
    def create(provider_name: str, **kwargs) -> BankProvider:
        if provider_name not in BankProviderFactory._providers:
            raise ValueError(f"Unknown provider: {provider_name}")
        
        return BankProviderFactory._providers[provider_name](**kwargs)

# APEX Service: Use abstraction
class BankingService:
    def __init__(self, provider_name: str):
        self.provider = BankProviderFactory.create(
            provider_name,
            client_id=os.getenv("BANK_CLIENT_ID"),
            client_secret=os.getenv("BANK_CLIENT_SECRET")
        )
    
    def sync_accounts(self, user_id: str, oauth_code: str):
        """Sync customer accounts from bank."""
        token = self.provider.authenticate({"auth_code": oauth_code})
        accounts = self.provider.get_accounts(token)
        
        for account in accounts:
            db.add(LinkedAccount(
                user_id=user_id,
                bank_account_id=account['accountId'],
                name=account['name'],
                balance=account['balance']['amount'],
                currency=account['balance']['currency']
            ))
        
        db.commit()
    
    def reconcile_account(self, account_id: str, 
                          from_date: str, to_date: str):
        """Fetch bank statements and reconcile."""
        linked_account = LinkedAccount.query.get(account_id)
        token = linked_account.bank_token  # Stored securely
        
        bank_txns = self.provider.get_transactions(
            linked_account.bank_account_id,
            token,
            from_date,
            to_date
        )
        
        # Match bank txns to ledger entries
        ledger_entries = Entry.query.filter(
            Entry.account_id == account_id,
            Entry.date >= from_date,
            Entry.date <= to_date
        ).all()
        
        matches = self._reconcile(ledger_entries, bank_txns)
        return matches
    
    def _reconcile(self, ledger_entries, bank_txns):
        """Reconciliation algorithm (see Section 4)."""
        # Implementation details omitted for brevity
        pass
```

---

### Payment Abstraction Layer

```python
class PaymentBackend(ABC):
    """Abstract payment gateway."""
    
    @abstractmethod
    def create_customer(self, email: str, **metadata) -> str:
        pass
    
    @abstractmethod
    def create_subscription(self, customer_id: str, 
                            plan_id: str) -> Dict:
        pass
    
    @abstractmethod
    def process_payment(self, amount: float, 
                        currency: str, **metadata) -> Dict:
        pass

class StripeBackend(PaymentBackend):
    def __init__(self, api_key: str):
        stripe.api_key = api_key
    
    def create_customer(self, email: str, **metadata) -> str:
        customer = stripe.Customer.create(
            email=email,
            metadata=metadata
        )
        return customer.id
    
    def create_subscription(self, customer_id: str, 
                            plan_id: str) -> Dict:
        subscription = stripe.Subscription.create(
            customer=customer_id,
            items=[{"price": plan_id}]
        )
        return {
            "id": subscription.id,
            "status": subscription.status,
            "next_billing": subscription.current_period_end
        }
    
    def process_payment(self, amount: float, 
                        currency: str, **metadata) -> Dict:
        intent = stripe.PaymentIntent.create(
            amount=int(amount * 100),
            currency=currency,
            metadata=metadata,
            confirm=True
        )
        return {
            "id": intent.id,
            "status": intent.status,
            "amount": amount
        }

class HyperPayBackend(PaymentBackend):
    """Similar implementation for HyperPay."""
    pass

class PaymentGatewayFactory:
    @staticmethod
    def create(backend: str) -> PaymentBackend:
        backends = {
            "stripe": StripeBackend,
            "hyperpay": HyperPayBackend,
            "mock": MockPaymentBackend,
        }
        
        BackendClass = backends[backend]
        return BackendClass(os.getenv(f"{backend.upper()}_API_KEY"))

# APEX Service
class SubscriptionService:
    def __init__(self, payment_backend: str):
        self.payment = PaymentGatewayFactory.create(payment_backend)
    
    def create_subscription(self, customer_email: str, 
                            plan_id: str) -> Dict:
        """Unified subscription creation."""
        customer_id = self.payment.create_customer(
            email=customer_email,
            source="apex_saas"
        )
        
        subscription = self.payment.create_subscription(
            customer_id=customer_id,
            plan_id=plan_id
        )
        
        return subscription
```

---

## 15. Sample Code Stubs

### SAMA OAuth Dance (Python)

```python
# File: app/phase10/services/sama_banking.py

import requests
import os
from datetime import datetime
from fastapi import HTTPException

class SamaBankingService:
    """SAMA Open Banking integration."""
    
    def __init__(self):
        self.client_id = os.getenv("SAMA_CLIENT_ID")
        self.client_secret = os.getenv("SAMA_CLIENT_SECRET")
        self.api_base = "https://api.sama.gov.sa/open-banking/v1"
        self.redirect_uri = "https://apex.com/auth/sama/callback"
    
    def get_auth_url(self) -> str:
        """Generate SAMA auth URL for user redirect."""
        return (
            f"https://auth.sama.gov.sa/oauth/authorize?"
            f"client_id={self.client_id}"
            f"&redirect_uri={self.redirect_uri}"
            f"&response_type=code"
            f"&scope=accounts+transactions+payments"
            f"&state=random_state_123"
        )
    
    def exchange_code_for_token(self, auth_code: str) -> dict:
        """Exchange authorization code for access token."""
        response = requests.post(
            f"{self.api_base}/oauth/token",
            data={
                "grant_type": "authorization_code",
                "code": auth_code,
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "redirect_uri": self.redirect_uri
            }
        )
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=400,
                detail="Failed to exchange code for token"
            )
        
        return response.json()
    
    def get_accounts(self, access_token: str) -> list:
        """Retrieve linked bank accounts."""
        response = requests.get(
            f"{self.api_base}/accounts",
            headers={
                "Authorization": f"Bearer {access_token}",
                "x-jws-signature": self._sign_request()
            }
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to fetch accounts")
        
        return response.json()['data']['accounts']
    
    def get_transactions(self, account_id: str, access_token: str,
                        from_date: str, to_date: str) -> list:
        """Retrieve account transactions."""
        response = requests.get(
            f"{self.api_base}/accounts/{account_id}/transactions",
            params={"from": from_date, "to": to_date},
            headers={"Authorization": f"Bearer {access_token}"}
        )
        
        return response.json()['data']['transactions']
    
    def _sign_request(self) -> str:
        """Sign request with APEX private key (mTLS)."""
        # Implementation: Load private key, sign payload
        pass

# Router
from fastapi import APIRouter

router = APIRouter(prefix="/api/v1/banking", tags=["banking"])

@router.get("/sama/auth-url")
async def get_sama_auth_url():
    """Initiate SAMA auth flow."""
    service = SamaBankingService()
    return {"auth_url": service.get_auth_url()}

@router.post("/sama/callback")
async def sama_callback(code: str, user_id: str):
    """Handle SAMA auth callback."""
    service = SamaBankingService()
    token_response = service.exchange_code_for_token(code)
    
    # Store access token securely (encrypted in DB)
    user = User.query.get(user_id)
    user.sama_access_token = encrypt(token_response['access_token'])
    user.sama_refresh_token = encrypt(token_response['refresh_token'])
    db.commit()
    
    # Fetch accounts
    accounts = service.get_accounts(token_response['access_token'])
    
    return {
        "status": "authenticated",
        "accounts": accounts
    }
```

---

### CAMT.053 Bank Statement Parser

```python
# File: app/core/parsers/bank_statement_parser.py

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime
from typing import List

@dataclass
class BankTransaction:
    transaction_id: str
    date: datetime
    amount: float
    currency: str
    debit_credit: str  # 'DEBIT' or 'CREDIT'
    description: str
    counterparty: str
    reference: Optional[str]

class CAMT053Parser:
    """Parse ISO 20022 CAMT.053 XML bank statements."""
    
    NAMESPACE = {
        'doc': 'urn:iso:std:iso:20022:tech:xsd:camt.053.001.02'
    }
    
    def __init__(self, xml_content: str):
        self.root = ET.fromstring(xml_content)
    
    def parse(self) -> dict:
        """Extract account and transaction data."""
        stmt = self._find_element('doc:Stmt')
        
        account = self._parse_account(stmt)
        opening_balance = self._parse_balance(stmt, 'opening')
        closing_balance = self._parse_balance(stmt, 'closing')
        transactions = self._parse_transactions(stmt)
        
        return {
            "account": account,
            "opening_balance": opening_balance,
            "closing_balance": closing_balance,
            "transactions": transactions,
            "count": len(transactions)
        }
    
    def _parse_account(self, stmt) -> dict:
        """Extract account details."""
        acct = self._find_element('doc:Acct', stmt)
        
        return {
            "id": self._text('doc:Id', acct),
            "name": self._text('doc:Nm', acct),
            "currency": self._text('doc:Ccy', acct)
        }
    
    def _parse_balance(self, stmt, balance_type: str) -> dict:
        """Parse opening/closing balance."""
        selector = 'doc:ClosingBalance' if balance_type == 'closing' else 'doc:Bal'
        bal = self._find_element(selector, stmt)
        
        return {
            "amount": float(self._text('doc:Amt', bal)),
            "currency": self._attr('doc:Amt', bal, 'Ccy'),
            "date": self._text('doc:Dt', bal),
            "type": self._text('doc:CdtDbtInd', bal)  # 'CRDT' or 'DBDT'
        }
    
    def _parse_transactions(self, stmt) -> List[BankTransaction]:
        """Extract transactions from statement."""
        transactions = []
        
        for txn_elem in self._findall('doc:Txn', stmt):
            txn = BankTransaction(
                transaction_id=self._text('doc:TxId', txn_elem),
                date=datetime.fromisoformat(self._text('doc:BookgDt', txn_elem)),
                amount=float(self._text('doc:Amt', txn_elem)),
                currency=self._attr('doc:Amt', txn_elem, 'Ccy'),
                debit_credit=self._text('doc:CdtDbtInd', txn_elem),
                description=self._text('doc:RmtInf/doc:Ustrd', txn_elem),
                counterparty=self._text('doc:RltdPties/doc:Dbtr/doc:Nm', txn_elem),
                reference=self._text('doc:RmtInf/doc:Strd/doc:CdtrRefInf/doc:Ref', txn_elem)
            )
            transactions.append(txn)
        
        return transactions
    
    # Helper methods
    def _find_element(self, xpath: str, parent=None):
        """Find element using namespace-aware XPath."""
        if parent is None:
            parent = self.root
        # Implementation: Use NS mapping in XPath
        return parent.find(xpath, self.NAMESPACE)
    
    def _findall(self, xpath: str, parent=None):
        """Find multiple elements."""
        if parent is None:
            parent = self.root
        return parent.findall(xpath, self.NAMESPACE)
    
    def _text(self, xpath: str, parent=None) -> str:
        """Extract text from element."""
        elem = self._find_element(xpath, parent)
        return elem.text if elem is not None else ""
    
    def _attr(self, xpath: str, parent, attr_name: str) -> str:
        """Extract attribute value."""
        elem = self._find_element(xpath, parent)
        return elem.get(attr_name) if elem is not None else ""

# Usage
with open("statement.xml", "r") as f:
    parser = CAMT053Parser(f.read())
    statement = parser.parse()
    print(f"Account: {statement['account']}")
    print(f"Transactions: {len(statement['transactions'])}")
```

---

### Reconciliation Matching Algorithm

```python
# File: app/phase10/services/reconciliation.py

from typing import List, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta

@dataclass
class LedgerEntry:
    id: str
    date: datetime
    amount: float
    description: str
    reference: Optional[str]

@dataclass
class BankTransaction:
    id: str
    date: datetime
    amount: float
    description: str
    counterparty: str

class ReconciliationEngine:
    """Match ledger entries to bank transactions."""
    
    def __init__(self, tolerance_pct: float = 0.05,
                 date_window: int = 3):
        self.tolerance_pct = tolerance_pct
        self.date_window = date_window
    
    def reconcile(self, ledger_entries: List[LedgerEntry],
                  bank_txns: List[BankTransaction]
                  ) -> Tuple[List, List, List]:
        """
        Match ledger entries to bank transactions.
        
        Returns:
        - matched: [(ledger, bank, confidence, method), ...]
        - unmatched_ledger: Entries with no match
        - unmatched_bank: Bank txns with no match
        """
        matched = []
        used_bank_ids = set()
        
        # Strategy 1: Exact match (highest priority)
        for ledger in ledger_entries:
            for bank in bank_txns:
                if bank.id in used_bank_ids:
                    continue
                
                if self._exact_match(ledger, bank):
                    matched.append((ledger, bank, 0.99, "EXACT"))
                    used_bank_ids.add(bank.id)
                    break
        
        # Strategy 2: Reference match
        remaining_ledger = [e for e in ledger_entries
                           if e.id not in [m[0].id for m in matched]]
        
        for ledger in remaining_ledger:
            for bank in bank_txns:
                if bank.id in used_bank_ids:
                    continue
                
                if self._reference_match(ledger, bank):
                    matched.append((ledger, bank, 0.90, "REFERENCE"))
                    used_bank_ids.add(bank.id)
                    break
        
        # Strategy 3: Fuzzy amount + date
        remaining_ledger = [e for e in ledger_entries
                           if e.id not in [m[0].id for m in matched]]
        
        for ledger in remaining_ledger:
            for bank in bank_txns:
                if bank.id in used_bank_ids:
                    continue
                
                if self._fuzzy_match(ledger, bank):
                    confidence = self._calculate_fuzzy_confidence(
                        ledger, bank
                    )
                    matched.append((ledger, bank, confidence, "FUZZY"))
                    used_bank_ids.add(bank.id)
                    break
        
        # Unmatched
        unmatched_ledger = [e for e in ledger_entries
                           if e.id not in [m[0].id for m in matched]]
        unmatched_bank = [b for b in bank_txns
                         if b.id not in used_bank_ids]
        
        return matched, unmatched_ledger, unmatched_bank
    
    def _exact_match(self, ledger: LedgerEntry,
                     bank: BankTransaction) -> bool:
        """Exact: amount + date + reference."""
        return (
            ledger.amount == bank.amount and
            ledger.date == bank.date and
            ledger.reference == self._extract_ref(bank.description)
        )
    
    def _reference_match(self, ledger: LedgerEntry,
                        bank: BankTransaction) -> bool:
        """Reference: extract invoice/PO numbers."""
        ledger_refs = self._extract_references(ledger.description)
        bank_refs = self._extract_references(bank.description)
        
        return bool(ledger_refs & bank_refs)
    
    def _fuzzy_match(self, ledger: LedgerEntry,
                    bank: BankTransaction) -> bool:
        """Fuzzy: amount within tolerance + date window."""
        amount_diff = abs(ledger.amount - bank.amount)
        amount_tolerance = ledger.amount * self.tolerance_pct
        
        date_diff = abs((ledger.date - bank.date).days)
        
        return (
            amount_diff <= amount_tolerance and
            date_diff <= self.date_window
        )
    
    def _calculate_fuzzy_confidence(self, ledger: LedgerEntry,
                                   bank: BankTransaction) -> float:
        """Score fuzzy match (0.5-0.95)."""
        amount_diff = abs(ledger.amount - bank.amount)
        amount_pct = (amount_diff / ledger.amount) * 100
        
        date_diff = (ledger.date - bank.date).days
        
        # Penalize: larger amount diff, larger date diff
        confidence = 0.85
        confidence -= min(amount_pct * 0.01, 0.2)  # -20% max
        confidence -= min(abs(date_diff) * 0.05, 0.15)  # -15% max
        
        return max(confidence, 0.50)
    
    def _extract_references(self, text: str) -> set:
        """Extract invoice/PO refs from text."""
        import re
        
        patterns = [
            r'INV-\d{4}-\d{3,5}',
            r'PO-\d{4,6}',
            r'CHK\d{6}'
        ]
        
        refs = set()
        for pattern in patterns:
            refs.update(re.findall(pattern, text, re.IGNORECASE))
        
        return refs
```

---

### Stripe Webhook Handler (Idempotent)

```python
# File: app/phase10/routes/webhooks.py

from fastapi import APIRouter, Request, HTTPException
import hmac
import hashlib
import json
from datetime import datetime

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

class WebhookEventStore:
    """Track processed webhook events (idempotency)."""
    
    def is_processed(self, event_id: str) -> bool:
        """Check if event already processed."""
        event = WebhookEvent.query.filter_by(
            external_id=event_id,
            status="processed"
        ).first()
        return event is not None
    
    def mark_processed(self, event_id: str, event_type: str,
                      payload: dict):
        """Record successful processing."""
        db.add(WebhookEvent(
            provider="stripe",
            external_id=event_id,
            event_type=event_type,
            payload=json.dumps(payload),
            status="processed",
            processed_at=datetime.utcnow()
        ))
        db.commit()

@router.post("/stripe")
async def stripe_webhook(request: Request):
    """Handle Stripe webhooks idempotently."""
    payload = await request.body()
    signature = request.headers.get("X-Stripe-Signature", "")
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    
    # Verify signature
    timestamp, sig = _parse_stripe_signature(signature)
    expected_sig = hmac.new(
        webhook_secret.encode(),
        f"{timestamp}.{payload.decode()}".encode(),
        hashlib.sha256
    ).hexdigest()
    
    if not hmac.compare_digest(sig, expected_sig):
        raise HTTPException(status_code=401, detail="Invalid signature")
    
    # Verify timestamp (prevent replay attacks, check within 5 min)
    if abs(int(time.time()) - int(timestamp)) > 300:
        raise HTTPException(status_code=401, detail="Timestamp too old")
    
    event = json.loads(payload)
    event_id = event['id']
    event_type = event['type']
    
    # Idempotency check
    event_store = WebhookEventStore()
    if event_store.is_processed(event_id):
        return {"status": "already_processed"}
    
    # Process event
    try:
        if event_type == "payment_intent.succeeded":
            _handle_payment_succeeded(event['data']['object'])
        elif event_type == "payment_intent.payment_failed":
            _handle_payment_failed(event['data']['object'])
        elif event_type == "customer.subscription.deleted":
            _handle_subscription_canceled(event['data']['object'])
        
        # Mark processed
        event_store.mark_processed(event_id, event_type, event)
        
        return {"status": "processed"}
    
    except Exception as e:
        log.error(f"Webhook processing error: {e}")
        raise HTTPException(status_code=500, detail="Processing failed")

def _handle_payment_succeeded(payment_intent: dict):
    """Idempotent: Update invoice status."""
    invoice_id = payment_intent['metadata'].get('invoice_id')
    amount = payment_intent['amount']
    
    invoice = Invoice.query.get(invoice_id)
    if invoice and invoice.status != 'PAID':
        invoice.status = 'PAID'
        invoice.amount_paid = amount / 100
        invoice.paid_at = datetime.utcnow()
        db.commit()

def _handle_payment_failed(payment_intent: dict):
    """Handle failed payment."""
    invoice_id = payment_intent['metadata'].get('invoice_id')
    
    invoice = Invoice.query.get(invoice_id)
    if invoice:
        invoice.status = 'PAYMENT_FAILED'
        db.commit()

def _handle_subscription_canceled(subscription: dict):
    """Handle subscription cancellation."""
    customer_id = subscription['customer']
    
    subscription = Subscription.query.filter_by(
        stripe_customer_id=customer_id
    ).first()
    
    if subscription:
        subscription.status = 'CANCELED'
        db.commit()

def _parse_stripe_signature(sig_header: str) -> Tuple[str, str]:
    """Parse Stripe signature header: t=...,v1=..."""
    parts = sig_header.split(',')
    timestamp = parts[0].split('=')[1]
    signature = parts[1].split('=')[1]
    return timestamp, signature
```

---

## Summary

This document provides a **comprehensive integration roadmap** for APEX's payment and banking ecosystem:

1. **Open Banking**: SAMA/CBUAE frameworks enabling account aggregation and payment initiation
2. **Bank Statements**: MT940, CAMT.053, CSV formats with parsing strategies
3. **Reconciliation**: Exact, fuzzy, reference-based, and AI-assisted matching algorithms
4. **Payment Gateways**: Stripe, Mada, HyperPay, PayTabs, Tap, Paymob, Geidea comparison
5. **Stripe SaaS**: Subscriptions, webhooks, tax calculation, Connect for marketplaces
6. **Saudi Compliance**: Mada, Apple Pay, SADAD, SARIE integration
7. **WPS, Direct Debit, PCI DSS**: Full compliance frameworks
8. **Architecture**: Adapter pattern for banking/payment abstraction
9. **Code Stubs**: Production-ready Python implementations

---

## Key Resources & URLs

**Official Documentation**:
- SAMA Open Banking: https://www.sama.gov.sa/en-us/openbanking/
- CBUAE Open Finance: https://www.centralbank.ae/en/our-operations/financial-services/open-finance/
- Stripe API: https://stripe.com/docs/api
- Stripe Connect: https://stripe.com/docs/connect
- Plaid: https://plaid.com/docs/

**Payment Gateways**:
- Mada: https://www.mada.com.sa/
- HyperPay: https://www.hyperpay.com/
- PayTabs: https://paytabs.com/
- Tap Payments: https://www.tap.company/
- Paymob: https://paymob.com/
- Geidea: https://geidea.net/

**Bank Formats**:
- ISO 20022 CAMT.053: https://www.iso20022.org/
- SWIFT MT940: https://www.swift.com/

**Standards**:
- FAPI (Financial-grade API): https://openid.net/specs/openid-financial-api-part-1-1.0.html
- PSD2: https://ec.europa.eu/info/law/payment-services-directive-psd-2_en

---

**Next Steps for APEX**:

1. **Phase 10 Implementation**: Build `BankingService` and `PaymentService` using abstraction layers
2. **Test Coverage**: 204+ tests covering webhook idempotency, reconciliation edge cases
3. **Compliance**: Obtain SAMA TPP registration (60-90 days) for production Open Banking
4. **Monitoring**: Implement webhook retry logic, reconciliation audit logs, PCI DSS attestation
5. **Multi-Currency**: Expand from SAR to AED, EGP via Stripe Multi-Currency & local gateways
