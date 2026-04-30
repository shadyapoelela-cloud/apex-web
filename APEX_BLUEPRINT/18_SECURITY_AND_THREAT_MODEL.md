# 18. SECURITY & THREAT MODEL — APEX Financial SaaS

**Status:** Reference Architecture (6500+ words)  
**Last Updated:** 2026-04-30  
**Scope:** Multi-tenant fintech SaaS (FastAPI + Flutter Web), MENA region (Saudi Arabia, UAE, Egypt)

---

## Table of Contents

1. [Threat Landscape for Fintech SaaS in MENA](#1-threat-landscape-for-fintech-saas-in-mena)
2. [OWASP Top 10 Mapped to APEX](#2-owasp-top-10-mapped-to-apex)
3. [OWASP API Security Top 10 Mapped](#3-owasp-api-security-top-10-mapped)
4. [STRIDE Threat Model for APEX](#4-stride-threat-model-for-apex)
5. [Data Classification & Handling](#5-data-classification--handling)
6. [Encryption Strategy](#6-encryption-strategy)
7. [Authentication & Session Management](#7-authentication--session-management)
8. [Authorization & RBAC](#8-authorization--rbac)
9. [Input Validation & Output Encoding](#9-input-validation--output-encoding)
10. [Saudi PDPL Deep-Dive](#10-saudi-pdpl-deep-dive)
11. [GDPR Compliance (EU Users)](#11-gdpr-compliance-eu-users)
12. [ISO 27001 Controls Mapping](#12-iso-27001-controls-mapping)
13. [SOC 2 Type II Readiness](#13-soc-2-type-ii-readiness)
14. [Logging & Monitoring](#14-logging--monitoring)
15. [Incident Response Plan](#15-incident-response-plan)
16. [Vulnerability Management](#16-vulnerability-management)
17. [Secure SDLC](#17-secure-sdlc)
18. [Disaster Recovery & Business Continuity](#18-disaster-recovery--business-continuity)
19. [MENA-Specific Regulatory Requirements](#19-mena-specific-regulatory-requirements)
20. [Threat Model Diagrams (ASCII)](#20-threat-model-diagrams-ascii)

---

## 1. Threat Landscape for Fintech SaaS in MENA

### Common Attack Vectors Against Accounting Platforms

**API Vulnerabilities** (~54% of breaches)
- Unauthenticated endpoints leaking financial data
- Missing or weak authorization on API endpoints
- Excessive data exposure (endpoints return more fields than needed)
- Mass assignment attacks (updating restricted fields via API)
- Broken pagination allowing data enumeration
- Reference: [OWASP API Security Top 10](https://owasp.org/API-Security/)

**Social Engineering & Phishing** (~73% of incidents)
- Voice phishing (vishing) targeting finance teams using AI voice synthesis
- Credential theft via malicious email links
- Pretexting with fake invoices or tax authority communications
- Business email compromise (BEC) targeting accountants and finance managers
- Reference: [Sprocket Security - Social Engineering](https://www.sprocketsecurity.com/blog/what-the-latest-social-engineering-attacks-in-financial-services-look-like)

**Third-Party & Supply Chain Risk** (~41.8% of breaches)
- Payment gateway integrations with weak security
- Accounting software integrations (QuickBooks, NetSuite connectors)
- Bank API integrations transmitting credentials unsafely
- Tax authority APIs (ZATCA, GAZT) integration points
- Reference: [SecurityScorecard - Third-Party Vendor Breaches](https://securityscorecard.com/company/press/securityscorecard-report-links-41-8-of-breaches-impacting-leading-fintech-companies-to-third-party-vendors/)

**Insider Threats**
- Privileged users extracting financial data or audit workpapers
- Fraudulent journal entry creation
- Invoice manipulation or duplicate invoice schemes
- Account reconciliation tampering
- Detection lag: ~50 days longer than external attacks

**Ransomware & Ransomware-as-a-Service (RaaS)**
- 40% via exploited unpatched vulnerabilities
- Targeting backup systems and disaster recovery infrastructure
- Encryption of audit logs and financial records
- Targeting multi-tenant systems to maximize ransom leverage

**Account Takeover (ATO)**
- Credential stuffing from leaked password databases
- Session hijacking via network sniffing (HTTP fallback)
- Weak 2FA or no 2FA enforcement for admins
- Token theft from localStorage (XSS vulnerabilities)

### Industry Incidents (Anonymized Patterns)

- **Pattern A:** Mid-market accounting SaaS exposed unencrypted invoices via broken object-level authorization; attackers accessed competitors' financial data
- **Pattern B:** Fintech platform suffered ransomware when admin account was compromised via phishing; no audit log backups
- **Pattern C:** Cloud accounting platform leaked API keys in frontend JavaScript; third parties scraped customer lists and financial summaries
- **Pattern D:** Tax software company's ZATCA integration leaked private keys when developers committed them to git history

---

## 2. OWASP Top 10 Mapped to APEX

Reference: [OWASP Top 10:2021](https://owasp.org/Top10/2021/)

### A01:2021 – Broken Access Control

**Description:**  
Access control enforces policy such that users cannot act outside intended permissions. Failures lead to unauthorized information disclosure, modification, or destruction of all data or performing business functions outside user limits.

**APEX Exposure:**
- Phase 1-7 route handlers lack field-level authorization checks
- Multi-tenant isolation relies solely on user.organization_id query filter (can be bypassed if filter removed)
- Admin endpoints only check `ADMIN_SECRET` header; no role-based admin access
- Invoice, COA, trial balance endpoints do not verify user.organization_id
- Public API endpoints may leak partner/provider data

**Mitigation in APEX:**
```python
# app/core/auth_utils.py - Add mandatory tenant isolation
from fastapi import HTTPException, status

def verify_org_access(user_id: int, org_id: int, db: Session) -> bool:
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.organization_id != org_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Org access denied")
    return True

# In route handlers:
@router.get("/invoices/{invoice_id}")
async def get_invoice(invoice_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404)
    verify_org_access(current_user.id, invoice.organization_id, db)  # Mandatory check
    return invoice
```

**Test Approach:**
- Attempt to read invoices from different organization by manipulating org_id
- Try to access admin endpoints without ADMIN_SECRET
- Attempt to modify invoice using PATCH with elevated role claims in JWT

---

### A02:2021 – Cryptographic Failures

**Description:**  
Shifted from "Sensitive Data Exposure"; now focuses on failures in cryptography. Often leads to data exposure or system compromise.

**APEX Exposure:**
- Database passwords stored in `DATABASE_URL` env var (plaintext in logs if not careful)
- ZATCA private keys stored as plaintext in database or filesystem
- JWT_SECRET hardcoded in dev, may leak in git history
- Backups may be unencrypted when stored on filesystem
- TLS 1.3 not enforced; older protocols accepted

**Mitigation in APEX:**
```python
# app/core/config.py
import os
from cryptography.fernet import Fernet

class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL")  # Must be overridden in prod
    JWT_SECRET: str = os.getenv("JWT_SECRET")  # Must use strong entropy
    ZATCA_PRIVATE_KEY_ENCRYPTED: str = os.getenv("ZATCA_PRIVATE_KEY_ENCRYPTED")
    
    # Use environment variables for all secrets
    # In production: use HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault

# Encrypt sensitive data at rest
def encrypt_zatca_key(private_key: str, kms_key: str) -> str:
    cipher = Fernet(kms_key)
    return cipher.encrypt(private_key.encode()).decode()

def decrypt_zatca_key(encrypted_key: str, kms_key: str) -> str:
    cipher = Fernet(kms_key)
    return cipher.decrypt(encrypted_key.encode()).decode()
```

**Test Approach:**
- Verify TLS 1.3 is enforced in production (no TLS 1.2 downgrade)
- Attempt to extract plaintext secrets from logs/error messages
- Verify database backups are encrypted (AES-256)

---

### A03:2021 – Injection

**Description:**  
SQL, NoSQL, OS, and LDAP injection occur when untrusted user input is sent to an interpreter as part of a command.

**APEX Exposure:**
- `app/phase3/services/coa_service.py` may concatenate user input in SQL queries
- CSV upload parsing may not validate format; XPath/XQuery injection in XML parsing
- File upload endpoints could execute code if stored in web-accessible directory

**Mitigation in APEX:**
```python
# CORRECT: SQLAlchemy ORM (parameterized by default)
from sqlalchemy import text

# app/phase3/services/coa_service.py
def search_coa(organization_id: int, code: str, db: Session):
    # Correct approach
    results = db.query(COA).filter(
        COA.organization_id == organization_id,
        COA.code.like(f"%{code}%")  # SQLAlchemy handles parameterization
    ).all()
    return results

# WRONG: Never do this
def search_coa_bad(organization_id: int, code: str, db: Session):
    query = f"SELECT * FROM coa WHERE organization_id = {organization_id} AND code LIKE '%{code}%'"
    # This is vulnerable to SQL injection!
    results = db.execute(query).fetchall()
    return results

# If raw SQL is required, use text() with bound parameters:
from sqlalchemy import text

def search_coa_raw(organization_id: int, code: str, db: Session):
    query = text("SELECT * FROM coa WHERE organization_id = :org_id AND code LIKE :code")
    results = db.execute(query, {"org_id": organization_id, "code": f"%{code}%"}).fetchall()
    return results
```

Reference: [SQLAlchemy SQL Injection Prevention](https://towardsdatascience.com/understand-sql-injection-and-learn-to-avoid-it-in-python-with-sqlalchemy-2c0ba57733b2)

**Test Approach:**
- Attempt classic SQL injection payloads ('; DROP TABLE invoices; --)
- Test CSV upload with malicious formulas (=cmd|'/c calc')
- Try XML entity expansion (XXE) in COA import

---

### A04:2021 – Insecure Design

**Description:**  
Missing security controls, insufficient threat modeling, missing design security features.

**APEX Exposure:**
- No rate limiting on login endpoint (brute force vulnerability)
- No CAPTCHA on registration or password reset
- No 2FA mandatory for admin/accountant roles
- No anomaly detection for unusual login patterns
- Invoice approval workflow lacks segregation of duties (same user can create and approve)

**Mitigation:**
```python
# app/core/security.py - Add rate limiting
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

# In app/main.py
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# In auth routes
@router.post("/login")
@limiter.limit("5/minute")  # 5 attempts per minute per IP
async def login(request: Request, credentials: LoginSchema, db: Session = Depends(get_db)):
    # Implement logic
    pass

# Add 2FA for admins
@router.post("/login/2fa")
async def verify_2fa(user_id: int, totp_code: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user.totp_secret:
        raise HTTPException(status_code=400, detail="2FA not enabled")
    # Verify TOTP using pyotp library
    import pyotp
    totp = pyotp.TOTP(user.totp_secret)
    if not totp.verify(totp_code):
        raise HTTPException(status_code=401, detail="Invalid 2FA code")
    return {"access_token": create_access_token(user_id)}
```

---

### A05:2021 – Broken Authentication

**Description:**  
Authentication mechanisms implemented incorrectly; allows attackers to compromise tokens or assume identities.

**APEX Exposure:**
- JWT access tokens valid for 24 hours (should be 15-60 minutes)
- No refresh token rotation
- Session fixation possible if token generation not randomized
- Social auth (Google, Apple) stubs do not validate ID tokens
- Password reset tokens have no expiry

**Mitigation:**
```python
# app/core/auth_utils.py - Implement secure JWT with short expiry
from datetime import datetime, timedelta
import jwt

def create_access_token(user_id: int, expires_in: timedelta = timedelta(minutes=15)):
    payload = {
        "sub": str(user_id),
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + expires_in
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token

def create_refresh_token(user_id: int, expires_in: timedelta = timedelta(days=7)):
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + expires_in
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token

# Implement refresh token rotation
@router.post("/auth/refresh")
async def refresh_access_token(refresh_token: str, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(refresh_token, JWT_SECRET, algorithms=["HS256"])
        user_id = int(payload["sub"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Refresh token expired")
    
    # Mark old token as revoked in Redis/DB
    revoke_token(refresh_token)
    
    # Issue new access token and new refresh token
    new_access_token = create_access_token(user_id)
    new_refresh_token = create_refresh_token(user_id)
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }
```

Reference: [Auth0 - Refresh Token Best Practices](https://auth0.com/blog/refresh-tokens-what-are-they-and-when-to-use-them/)

---

### A06:2021 – Vulnerable & Outdated Components

**Description:**  
Using libraries, frameworks, or components with known vulnerabilities.

**APEX Exposure:**
- Dependencies not pinned in `requirements.txt`; could pull vulnerable versions
- No regular dependency scanning (pip-audit, Dependabot)
- Docker base images may have unpatched OS vulnerabilities
- Flutter Web dependencies (Dart packages) not scanned

**Mitigation:**
```bash
# In CI/CD pipeline (.github/workflows/ci.yml)
- name: Scan Python dependencies
  run: |
    pip install pip-audit
    pip-audit --fix  # Auto-fix if possible
    pip-audit         # Report unpatched vulnerabilities

- name: SAST scan with Bandit
  run: |
    pip install bandit
    bandit -r app/ -f json -o bandit-report.json

- name: Lint with Ruff (includes security rules)
  run: |
    pip install ruff
    ruff check app/

# Use pinned dependency versions
# requirements.txt
flask==2.3.2
sqlalchemy==2.0.19
```

Reference: [Dependency Scanning](https://docs.github.com/en/code-security/dependabot)

---

### A07:2021 – Identification & Authentication Failures

**Description:**  
Formerly Broken Authentication; now includes broader identity/auth failures.

**APEX Exposure:** (See A05 above)

---

### A08:2021 – Software & Data Integrity Failures

**Description:**  
Lack of verification that software updates, CI/CD pipelines, or data updates are genuine.

**APEX Exposure:**
- GitHub Actions CI/CD not signed; could be poisoned
- Docker images pulled from registries without signature verification
- Dependencies fetched over HTTP (should use HTTPS only)
- No code review requirement for merges to main branch

**Mitigation:**
```yaml
# .github/workflows/ci.yml - Enforce code review
name: CI/CD

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      
      - name: Verify commit signature
        run: |
          git verify-commit HEAD || exit 1
      
      - name: Run tests & lint
        run: |
          pytest tests/ -v --cov=app
          black --check app/
          ruff check app/
          bandit -r app/
```

---

### A09:2021 – Logging & Monitoring Failures

**Description:**  
Insufficient logging and monitoring; lack of audit trails and alerting.

**APEX Exposure:**
- No centralized logging (logs scattered across container filesystems)
- Audit logs may be deleted by attackers with high privileges
- No alerting on suspicious activities (bulk downloads, failed logins)
- Password resets not logged

**Mitigation:** (See Section 14: Logging & Monitoring)

---

### A10:2021 – Server-Side Request Forgery (SSRF)

**Description:**  
Server makes requests to unintended locations (internal services, cloud metadata).

**APEX Exposure:**
- ZATCA submission may SSRF if URL is user-controllable
- Bank API integration endpoints may SSRF to internal services
- Image upload could fetch from attacker-controlled URL (image processing)

**Mitigation:**
```python
# app/phase7/services/zatca_service.py - Prevent SSRF
import httpx
from urllib.parse import urlparse

ALLOWED_HOSTS = ["api.zatca.gov.sa", "api-sandbox.zatca.gov.sa"]

def submit_to_zatca(invoice_xml: str, api_url: str):
    # Validate URL
    parsed = urlparse(api_url)
    if parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError("Invalid ZATCA API URL")
    
    # Never allow user input directly as URL
    api_url = "https://api.zatca.gov.sa/v2/invoices"  # Hardcoded
    
    async with httpx.AsyncClient() as client:
        response = await client.post(api_url, content=invoice_xml)
        return response
```

---

## 3. OWASP API Security Top 10 Mapped

Reference: [OWASP API Security Top 10 – 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)

### API1:2023 – Broken Object Level Authorization (BOLA)

**Description:**  
Endpoints expose resources by identifier (e.g., `/invoices/123`) without verifying the requester owns that resource.

**APEX Exposure:**
- `GET /invoices/{invoice_id}` – no org_id check
- `GET /users/{user_id}/profile` – returns full profile if authenticated
- `DELETE /coa/{coa_id}` – no org ownership verification

**Mitigation:**
```python
# app/phase3/routes/invoices.py
@router.get("/invoices/{invoice_id}")
async def get_invoice(
    invoice_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    
    # Mandatory ownership check
    if invoice.organization_id != current_user.organization_id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    return invoice
```

---

### API2:2023 – Broken Authentication

**Description:** (See OWASP Top 10 A05)

**APEX Exposure:**
- No token refresh endpoint
- Social auth tokens not validated

---

### API3:2023 – Broken Object Property Level Authorization (BOPLA)

**Description:**  
Formerly "Excessive Data Exposure"; APIs return more fields than needed or allow modifying restricted fields (mass assignment).

**APEX Exposure:**
```python
# VULNERABLE: Returns all user fields including password_hash
@router.get("/users/{user_id}")
async def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).all()  # Returns User with all fields
    return user  # password_hash, internal_notes exposed!

# VULNERABLE: Allows mass assignment
@router.put("/users/{user_id}")
async def update_user(user_id: int, data: dict, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    for key, value in data.items():
        setattr(user, key, value)  # Attacker sets role=admin
    db.commit()
    return user
```

**Mitigation:**
```python
# Use Pydantic schemas to whitelist fields
from pydantic import BaseModel

class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    organization_id: int
    # Exclude: password_hash, internal_notes
    
    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    full_name: str
    email: str
    # Exclude: role, is_admin, organization_id (non-updatable)

@router.put("/users/{user_id}")
async def update_user(
    user_id: int,
    data: UserUpdate,  # Only allows full_name, email
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.id == user_id).first()
    if user.organization_id != current_user.organization_id:
        raise HTTPException(status_code=403)
    
    user.full_name = data.full_name
    user.email = data.email
    db.commit()
    
    return UserResponse.from_orm(user)
```

---

### API4:2023 – Unrestricted Resource Consumption

**Description:**  
No rate limiting, pagination, or request size limits; leads to DoS.

**APEX Exposure:**
- `/invoices?page=1&limit=100000` – can fetch all invoices in one request
- No rate limiting on reports generation (CPU-intensive)
- File upload size unlimited

**Mitigation:**
```python
# app/phase3/routes/invoices.py
from slowapi import Limiter

limiter = Limiter(key_func=lambda: "global")

@router.get("/invoices")
@limiter.limit("30/minute")  # 30 requests per minute
async def list_invoices(
    current_user: User = Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),  # Max 100
    db: Session = Depends(get_db)
):
    invoices = db.query(Invoice).filter(
        Invoice.organization_id == current_user.organization_id
    ).offset(skip).limit(limit).all()
    return invoices
```

---

### API5:2023 – Broken Function Level Authorization

**Description:**  
Admin/privileged functions are accessible to regular users.

**APEX Exposure:**
- `/admin/users` endpoint only checks `ADMIN_SECRET` header (no role verification)
- Accountant role can access `/audit/logs` (should be restricted to audit role)

**Mitigation:**
```python
# app/core/auth_utils.py - Add role-based checks
from enum import Enum

class UserRole(str, Enum):
    ADMIN = "admin"
    ACCOUNTANT = "accountant"
    AUDITOR = "auditor"
    USER = "user"

def get_admin_user(current_user: User = Depends(get_current_user)):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user

# In routes
@router.get("/admin/users")
async def list_all_users(
    admin_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db)
):
    users = db.query(User).all()
    return users
```

---

### API6:2023 – Unrestricted Access to Sensitive Business Flows

**Description:**  
Sensitive operations (invoice approval, payment) lack proper authorization or can be bypassed.

**APEX Exposure:**
- Invoice approval can be triggered by non-approvers
- Payment initiation not logged or audited

**Mitigation:**
- Implement segregation of duties (creator ≠ approver)
- Audit every sensitive operation

---

### API7:2023 – Server-Side Request Forgery (SSRF)

**Description:** (See OWASP Top 10 A10)

---

### API8:2023 – Security Misconfiguration

**Description:**  
Insecure defaults, debug endpoints left enabled, missing security headers.

**APEX Exposure:**
- `debug=True` in production
- CORS allows `*` (all origins)
- No security headers (CSP, X-Frame-Options, etc.)
- Swagger/OpenAPI docs exposed publicly (reveals all endpoints)

**Mitigation:**
```python
# app/main.py
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware import Middleware

ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

if ENVIRONMENT == "production":
    CORS_ORIGINS = os.getenv("CORS_ORIGINS", "").split(",")
    DEBUG = False
else:
    CORS_ORIGINS = ["*"]
    DEBUG = True

app = FastAPI(debug=DEBUG, docs_url=None if ENVIRONMENT == "production" else "/docs")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"]
)

# Add security headers
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response
```

---

### API9:2023 – Improper Inventory Management

**Description:**  
No documentation of API versions, endpoints, deprecation; stale endpoints remain accessible.

**APEX Exposure:**
- Old `/api/v1/invoices` endpoint still works (may lack security fixes)
- No versioning strategy

**Mitigation:**
- Maintain API version registry
- Deprecate old versions with 12-month notice
- Force client updates

---

### API10:2023 – Unsafe Consumption of APIs

**Description:**  
Calling third-party APIs (banks, tax authorities) without verifying SSL certificates, validating responses, or handling errors securely.

**APEX Exposure:**
- ZATCA API calls may not validate TLS certificates
- Bank API responses not validated before storing

**Mitigation:**
```python
import httpx
import ssl

# Create custom SSL context (no self-signed certs in production)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = True
ssl_context.verify_mode = ssl.CERT_REQUIRED

async def submit_to_zatca(invoice_xml: str):
    async with httpx.AsyncClient(verify=ssl_context) as client:
        response = await client.post(
            "https://api.zatca.gov.sa/v2/invoices",
            content=invoice_xml,
            timeout=30
        )
        response.raise_for_status()
        return response.json()
```

---

## 4. STRIDE Threat Model for APEX

Reference: [Microsoft Threat Modeling](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)

### Spoofing Identity

**Threats:**
- Attacker impersonates a legitimate user via stolen JWT
- Social auth token forged (Google/Apple tokens not validated)
- Admin token generated without proper verification
- ZATCA certificate stolen and used by attacker

**APEX-Specific Mitigations:**
- Enforce 2FA for admins and accountants
- Validate ID tokens from social auth providers
- Store JWT secrets in HSM (Hardware Security Module) or KMS
- Implement short-lived access tokens (15 min) with refresh token rotation
- Certificate pinning for ZATCA API communication

---

### Tampering with Data

**Threats:**
- Attacker modifies invoice data in database (change amount, payee)
- API request modified in transit (missing TLS)
- Audit log entries deleted or modified
- ZATCA submission tampered with before transmission

**APEX-Specific Mitigations:**
- Enforce TLS 1.3 for all API communication
- Implement immutable audit logs with hash-chain (each log entry includes hash of previous)
- Sign invoice data before submission to ZATCA
- Use database triggers to prevent direct modification of financial records
- Row-level versioning for invoices (audit trail of changes)

```python
# app/core/audit_log.py - Immutable audit logging with hash chain
import hashlib
from datetime import datetime

class AuditLog(Base):
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True)
    organization_id = Column(Integer, nullable=False)
    action = Column(String, nullable=False)  # create_invoice, approve_invoice, etc.
    resource_type = Column(String)  # Invoice, COA, etc.
    resource_id = Column(Integer)
    user_id = Column(Integer)
    changes = Column(JSON)  # {before: {...}, after: {...}}
    timestamp = Column(DateTime, default=datetime.utcnow)
    previous_hash = Column(String)  # SHA-256 of previous log entry
    entry_hash = Column(String)  # SHA-256 of this entry
    
    def compute_hash(self):
        data = f"{self.organization_id}{self.action}{self.resource_type}{self.resource_id}{self.user_id}{self.timestamp}{self.previous_hash}"
        return hashlib.sha256(data.encode()).hexdigest()

# When creating a new audit log entry:
def log_action(organization_id, action, resource_type, resource_id, user_id, changes, db):
    previous_entry = db.query(AuditLog).filter(
        AuditLog.organization_id == organization_id
    ).order_by(AuditLog.id.desc()).first()
    
    new_entry = AuditLog(
        organization_id=organization_id,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        user_id=user_id,
        changes=changes,
        previous_hash=previous_entry.entry_hash if previous_entry else None
    )
    new_entry.entry_hash = new_entry.compute_hash()
    db.add(new_entry)
    db.commit()
```

---

### Repudiation

**Threats:**
- User denies creating an invoice or approval
- Admin denies granting access to sensitive data
- ZATCA submission denied (invoice marked as non-compliant)

**APEX-Specific Mitigations:**
- Mandatory audit logging on all actions
- Digital signatures on critical documents (invoice approval by accountant)
- Immutable audit trail with timestamps
- Email notifications for sensitive actions (approval, deletion)

---

### Information Disclosure

**Threats:**
- Attacker reads invoices from different organization (BOLA)
- API leaks sensitive fields (password hash, internal notes)
- Backups stored unencrypted in cloud
- Logs contain sensitive data (credit card numbers, tax IDs)

**APEX-Specific Mitigations:**
- Mandatory multi-tenant isolation at database level (organization_id on all queries)
- Response schemas that exclude sensitive fields
- Field-level encryption for PII (tax IDs, bank accounts)
- Encrypt backups with AES-256
- Log sanitization (mask PII before logging)
- Rate limit on bulk data export endpoints

```python
# app/core/encryption.py - Field-level encryption
from cryptography.fernet import Fernet

class EncryptedField:
    def __init__(self, encryption_key: str):
        self.cipher = Fernet(encryption_key.encode())
    
    def encrypt(self, value: str) -> str:
        return self.cipher.encrypt(value.encode()).decode()
    
    def decrypt(self, encrypted_value: str) -> str:
        return self.cipher.decrypt(encrypted_value.encode()).decode()

# In models:
class Vendor(Base):
    __tablename__ = "vendors"
    id = Column(Integer, primary_key=True)
    organization_id = Column(Integer, nullable=False)
    name = Column(String)
    tax_id_encrypted = Column(String)  # Encrypted
    bank_account_encrypted = Column(String)  # Encrypted
```

---

### Denial of Service (DoS)

**Threats:**
- Attacker floods login endpoint (brute force)
- Large file upload exhausts disk space
- Report generation consumes all CPU
- Database queries with N+1 problem or full table scans
- Pagination parameter set to fetch 1M records

**APEX-Specific Mitigations:**
- Rate limiting on all endpoints (5 login attempts/min per IP)
- File upload size limits (10MB max)
- Query timeouts (30 sec max per API request)
- Pagination limits (max 100 records per request)
- Monitor CPU/memory on report generation
- Implement circuit breaker for external APIs (ZATCA, banks)

```python
# app/main.py - Global rate limiting and timeouts
from slowapi.errors import RateLimitExceeded
from starlette.requests import Request
from starlette.responses import PlainTextResponse

limiter = Limiter(key_func=get_remote_address)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return PlainTextResponse("Too many requests", status_code=429)

@app.middleware("http")
async def timeout_middleware(request: Request, call_next):
    try:
        response = await asyncio.wait_for(call_next(request), timeout=30)
        return response
    except asyncio.TimeoutError:
        return JSONResponse(
            status_code=504,
            content={"detail": "Request timeout"}
        )
```

---

### Elevation of Privilege

**Threats:**
- Regular user becomes admin via JWT manipulation
- Accountant modifies their own role in database
- Auditor deletes audit logs
- Service account credentials leaked; attacker gains full system access

**APEX-Specific Mitigations:**
- JWT tokens signed with strong secret; never allow unsigned tokens
- Role changes logged and audited
- Audit logs stored separately with restricted access
- Service account credentials rotated every 90 days
- Implement role-based access control (RBAC) at database layer
- Disable password reset for admin accounts (use 2FA + recovery codes)

---

## 5. Data Classification & Handling

### Classification Levels

| Level | Examples | Encryption | Access | Retention |
|-------|----------|-----------|--------|-----------|
| **Public** | Marketing pages, pricing, public documentation | None | Public | Indefinite |
| **Internal** | System logs, operational metrics, internal processes | None (integrity-protected) | Employees only | 1 year |
| **Confidential** | User names, emails, audit trails, journal entries | AES-256 at rest, TLS in transit | Authorized users | 7 years (per local law) |
| **Restricted** | Invoice data, financial summaries, bank accounts, tax IDs, ZATCA private keys | AES-256 at rest + field-level encryption, TLS 1.3 in transit | Role-specific (accountant, auditor, admin) | Per regulation (PDPL: 3 years) |

### APEX Data Examples

- **Public:** Pricing page HTML, feature descriptions
- **Internal:** API request/response latency logs, server uptime metrics
- **Confidential:** User email addresses, organization names, invoice summaries
- **Restricted:** Complete invoice details (line items, amounts), tax ID, ZATCA credentials, bank account numbers, trial balance details, COA changes

---

## 6. Encryption Strategy

### Data in Transit

- **Protocol:** TLS 1.3 minimum (RFC 8446)
- **Ciphers:** AEAD suites only (ChaCha20-Poly1305, AES-GCM)
- **Certificate:** Wildcard or SANs for all domains
- **HSTS:** `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- **Implementation:** Nginx/Cloudflare reverse proxy enforces TLS before FastAPI

```nginx
# nginx.conf
server {
    listen 443 ssl http2;
    ssl_protocols TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_certificate /etc/letsencrypt/live/apex.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/apex.example.com/privkey.pem;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

### Data at Rest

- **Database:** PostgreSQL with encrypted storage
  - **Method:** Transparent Data Encryption (TDE) via dm-crypt (Linux) or EFS (AWS)
  - **Algorithm:** AES-256
  - **Key Management:** HSM-backed keys (AWS CloudHSM, Azure Key Vault)

- **Application-Level:** Fernet (AES-128 with HMAC) for highly sensitive fields

```python
from cryptography.fernet import Fernet

class SensitiveFieldEncryption:
    def __init__(self, master_key: str):
        # Master key from AWS Secrets Manager or HashiCorp Vault
        self.cipher = Fernet(master_key.encode())
    
    def encrypt(self, plaintext: str) -> str:
        return self.cipher.encrypt(plaintext.encode()).decode()
    
    def decrypt(self, ciphertext: str) -> str:
        return self.cipher.decrypt(ciphertext.encode()).decode()

# In SQLAlchemy model
class Vendor(Base):
    __tablename__ = "vendors"
    tax_id_encrypted = Column(String)  # Field-level encryption
    
    @property
    def tax_id(self):
        encryption = SensitiveFieldEncryption(os.getenv("FIELD_ENCRYPTION_KEY"))
        return encryption.decrypt(self.tax_id_encrypted)
    
    @tax_id.setter
    def tax_id(self, value: str):
        encryption = SensitiveFieldEncryption(os.getenv("FIELD_ENCRYPTION_KEY"))
        self.tax_id_encrypted = encryption.encrypt(value)
```

- **Backups:** Encrypted with AES-256; stored in geographically dispersed regions
  - **Tool:** `pg_dump` piped to GPG or AWS S3 with server-side encryption

```bash
# Backup script
pg_dump $DATABASE_URL | \
  gpg --symmetric --cipher-algo AES256 --batch --passphrase-file /secrets/backup_key > /backups/apex_$(date +%Y%m%d).sql.gpg

aws s3 cp /backups/apex_$(date +%Y%m%d).sql.gpg s3://apex-backups/encrypted/ --sse AES256
```

### ZATCA Private Keys

- **Storage:** AWS Secrets Manager (automatic rotation every 90 days)
- **Encryption:** KMS master key
- **Access:** Only service account with audit logging
- **Usage:** Never stored in plaintext on filesystem or database

```python
import boto3

class ZATCAKeyManager:
    def __init__(self):
        self.secrets_client = boto3.client('secretsmanager')
    
    def get_private_key(self, organization_id: int) -> str:
        secret_name = f"zatca-key-org-{organization_id}"
        response = self.secrets_client.get_secret_value(SecretId=secret_name)
        return response['SecretString']
    
    def rotate_key(self, organization_id: int):
        # Triggered by AWS event; old key archived, new key generated
        # Log rotation in audit trail
        pass
```

### Recommended Libraries

- **Python:** `cryptography` (Fernet, AES), `pycryptodome` (RSA for signing)
- **Flutter:** `pointycastle` (encryption), `crypton` (JWT)
- **Database:** PostgreSQL pgcrypto extension

---

## 7. Authentication & Session Management

### Password Policy

- **Minimum Length:** 14 characters
- **Complexity:** Uppercase, lowercase, digit, special character
- **Breach Check:** Validate against [HaveIBeenPwned API](https://haveibeenpwned.com/API/v3) before accepting
- **Expiry:** 90 days (password reset required)
- **History:** Cannot reuse last 5 passwords

```python
# app/core/password_policy.py
import requests
import hashlib
from pydantic import validator

class PasswordValidator:
    @staticmethod
    def validate_complexity(password: str):
        if len(password) < 14:
            raise ValueError("Password must be at least 14 characters")
        if not any(c.isupper() for c in password):
            raise ValueError("Password must contain uppercase letter")
        if not any(c.islower() for c in password):
            raise ValueError("Password must contain lowercase letter")
        if not any(c.isdigit() for c in password):
            raise ValueError("Password must contain digit")
        if not any(c in "!@#$%^&*" for c in password):
            raise ValueError("Password must contain special character")
    
    @staticmethod
    def check_breached(password: str):
        # Check against HaveIBeenPwned API
        sha1_hash = hashlib.sha1(password.encode()).hexdigest().upper()
        prefix = sha1_hash[:5]
        suffix = sha1_hash[5:]
        
        response = requests.get(f"https://api.pwnedpasswords.com/range/{prefix}")
        if suffix in response.text:
            raise ValueError("Password has been breached; choose another")
```

### bcrypt Configuration

- **Rounds:** 12 (≈ 500ms hashing time on modern hardware)
- **Algorithm:** `bcrypt` with salt; PBKDF2 or Argon2id for new systems

```python
# app/core/auth_utils.py
import bcrypt

def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode(), salt).decode()

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())

# Argon2id (recommended for new deployments)
from argon2 import PasswordHasher

hasher = PasswordHasher(
    time_cost=2,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16
)

def hash_password_argon2(password: str) -> str:
    return hasher.hash(password)

def verify_password_argon2(password: str, hashed: str) -> bool:
    try:
        hasher.verify(hashed, password)
        return True
    except:
        return False
```

### JWT Best Practices

- **Access Token Lifespan:** 15 minutes
- **Refresh Token Lifespan:** 7 days
- **Algorithm:** HS256 (HMAC-SHA256) with 256-bit secret
- **Claims:** `sub` (user_id), `iat` (issued at), `exp` (expiry), `org_id` (organization)
- **Signature Verification:** Mandatory on every request
- **No Sensitive Data:** Never include password, API keys, or PII in JWT payload

```python
# app/core/auth_utils.py
from datetime import datetime, timedelta, timezone
import jwt

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = "HS256"

def create_access_token(user_id: int, org_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "org_id": org_id,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=15),
        "type": "access"
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def create_refresh_token(user_id: int, org_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "org_id": org_id,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
        "type": "refresh"
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidSignatureError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

### Refresh Token Rotation

- Every refresh triggers new access + new refresh token
- Old refresh token immediately revoked
- Store hash of refresh token in Redis (TTL = 7 days)

```python
import redis

redis_client = redis.Redis(host='localhost', port=6379, db=0)

def revoke_refresh_token(token: str):
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    redis_client.setex(f"revoked_token:{token_hash}", 604800, 1)  # 7 days

def is_token_revoked(token: str) -> bool:
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    return redis_client.exists(f"revoked_token:{token_hash}") > 0

@router.post("/auth/refresh")
async def refresh_access_token(refresh_token: str, db: Session = Depends(get_db)):
    if is_token_revoked(refresh_token):
        raise HTTPException(status_code=401, detail="Token revoked")
    
    payload = verify_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")
    
    user_id = int(payload["sub"])
    org_id = payload["org_id"]
    
    # Revoke old token
    revoke_refresh_token(refresh_token)
    
    # Issue new tokens
    new_access_token = create_access_token(user_id, org_id)
    new_refresh_token = create_refresh_token(user_id, org_id)
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }
```

### 2FA Mandatory for Admins

- **TOTP (Time-based One-Time Password):** Primary method
- **Backup Codes:** 10 single-use codes for account recovery
- **SMS 2FA:** Fallback (less secure; not recommended)

```python
import pyotp
import qrcode
from io import BytesIO
import base64

class TwoFAManager:
    @staticmethod
    def generate_totp_secret() -> str:
        return pyotp.random_base32()
    
    @staticmethod
    def get_qr_code(user_email: str, secret: str) -> str:
        totp = pyotp.TOTP(secret)
        uri = totp.provisioning_uri(user_email, issuer_name="APEX")
        
        qr = qrcode.QRCode()
        qr.add_data(uri)
        qr.make()
        
        img = qr.make_image()
        buffer = BytesIO()
        img.save(buffer, format="PNG")
        return base64.b64encode(buffer.getvalue()).decode()
    
    @staticmethod
    def verify_totp(secret: str, code: str) -> bool:
        totp = pyotp.TOTP(secret)
        return totp.verify(code)

# Endpoint to enable 2FA
@router.post("/users/me/2fa/enable")
async def enable_2fa(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role not in [UserRole.ADMIN, UserRole.ACCOUNTANT]:
        raise HTTPException(status_code=403)
    
    secret = TwoFAManager.generate_totp_secret()
    qr_code = TwoFAManager.get_qr_code(current_user.email, secret)
    
    # Generate backup codes
    backup_codes = [secrets.token_hex(4) for _ in range(10)]
    
    # Store temporarily (user must verify within 5 minutes)
    cache.set(f"2fa_setup:{current_user.id}", {
        "secret": secret,
        "backup_codes": backup_codes
    }, ex=300)
    
    return {
        "qr_code": qr_code,
        "backup_codes": backup_codes,
        "message": "Scan QR code with authenticator app and verify code to complete setup"
    }

# Endpoint to verify 2FA setup
@router.post("/users/me/2fa/verify")
async def verify_2fa_setup(
    code: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    setup_data = cache.get(f"2fa_setup:{current_user.id}")
    if not setup_data:
        raise HTTPException(status_code=400, detail="2FA setup expired")
    
    if not TwoFAManager.verify_totp(setup_data["secret"], code):
        raise HTTPException(status_code=400, detail="Invalid code")
    
    current_user.totp_secret = setup_data["secret"]
    current_user.backup_codes = setup_data["backup_codes"]
    db.commit()
    
    cache.delete(f"2fa_setup:{current_user.id}")
    
    return {"message": "2FA enabled successfully"}

# During login, require 2FA
@router.post("/auth/login")
async def login(credentials: LoginSchema, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    if user.role in [UserRole.ADMIN] and user.totp_secret:
        # Require 2FA
        session_token = secrets.token_urlsafe(32)
        cache.set(f"pre_2fa_session:{session_token}", user.id, ex=300)
        return {
            "requires_2fa": True,
            "session_token": session_token
        }
    
    return {"access_token": create_access_token(user.id, user.organization_id)}

@router.post("/auth/login/2fa")
async def verify_login_2fa(session_token: str, code: str, db: Session = Depends(get_db)):
    user_id = cache.get(f"pre_2fa_session:{session_token}")
    if not user_id:
        raise HTTPException(status_code=400, detail="2FA session expired")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not TwoFAManager.verify_totp(user.totp_secret, code):
        raise HTTPException(status_code=401, detail="Invalid 2FA code")
    
    cache.delete(f"pre_2fa_session:{session_token}")
    return {"access_token": create_access_token(user.id, user.organization_id)}
```

---

## 8. Authorization & RBAC

### Role-Based Access Control (RBAC)

| Role | Permissions |
|------|-------------|
| **Admin** | All operations, user management, system settings, 2FA required |
| **Accountant** | Create/edit/approve invoices, COA, trial balance, 2FA required |
| **Auditor** | Read-only access to invoices, audit logs, COA, trial balance |
| **User** | View own invoices, basic reporting |

### Field-Level Masking

Sensitive fields masked based on role:

```python
# app/core/authorization.py
class FieldAccessControl:
    FIELD_ACCESS = {
        "bank_account": ["admin", "accountant"],
        "tax_id": ["admin", "accountant"],
        "profit_margin": ["admin"],
        "employee_count": ["admin"],
        "audit_notes": ["auditor", "admin"]
    }
    
    @staticmethod
    def apply_field_masking(data: dict, user_role: str) -> dict:
        for field, allowed_roles in FieldAccessControl.FIELD_ACCESS.items():
            if field in data and user_role not in allowed_roles:
                data[field] = "***MASKED***"
        return data

# In response schema
class InvoiceResponse(BaseModel):
    id: int
    amount: float
    vendor_name: str
    tax_id: str = "***MASKED***"  # Default masked
    bank_account: str = "***MASKED***"
    
    @classmethod
    def from_orm_with_role(cls, obj, user_role: str):
        data = obj.__dict__.copy()
        return cls(**FieldAccessControl.apply_field_masking(data, user_role))
```

### Tenant Isolation at Database Layer

```python
# SQLAlchemy event listeners to enforce organization_id filtering
from sqlalchemy import event
from sqlalchemy.orm import Session

def enforce_org_isolation(mapper, class_, target):
    # Only allow operations on current user's organization
    if hasattr(target, 'organization_id'):
        # Verify during INSERT/UPDATE
        pass

event.listen(Invoice, 'before_insert', enforce_org_isolation)
event.listen(Invoice, 'before_update', enforce_org_isolation)
```

Or use Row-Level Security (RLS) in PostgreSQL:

```sql
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY org_isolation_invoice ON invoices
USING (organization_id = (SELECT organization_id FROM users WHERE id = current_user_id));

CREATE POLICY org_isolation_invoice_insert ON invoices
WITH CHECK (organization_id = (SELECT organization_id FROM users WHERE id = current_user_id));
```

### Audit on Authorization Decisions

```python
def log_authorization_decision(user_id: int, resource: str, resource_id: int, allowed: bool, db: Session):
    log_entry = AuthorizationLog(
        user_id=user_id,
        resource=resource,
        resource_id=resource_id,
        allowed=allowed,
        timestamp=datetime.utcnow()
    )
    db.add(log_entry)
    db.commit()

@router.get("/invoices/{invoice_id}")
async def get_invoice(invoice_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    allowed = invoice and invoice.organization_id == current_user.organization_id
    log_authorization_decision(current_user.id, "invoice", invoice_id, allowed, db)
    
    if not allowed:
        raise HTTPException(status_code=403)
    
    return invoice
```

---

## 9. Input Validation & Output Encoding

### Input Validation with Pydantic

```python
from pydantic import BaseModel, Field, validator, EmailStr
from typing import Optional

class InvoiceCreateSchema(BaseModel):
    vendor_id: int = Field(..., gt=0)
    invoice_number: str = Field(..., min_length=1, max_length=50)
    invoice_date: str = Field(..., regex=r"^\d{4}-\d{2}-\d{2}$")
    due_date: str = Field(..., regex=r"^\d{4}-\d{2}-\d{2}$")
    amount: float = Field(..., gt=0, le=999999999.99)
    description: Optional[str] = Field(None, max_length=500)
    
    @validator('invoice_number')
    def validate_invoice_number(cls, v):
        # Only allow alphanumeric, dash, underscore
        import re
        if not re.match(r'^[A-Za-z0-9_-]+$', v):
            raise ValueError('Invalid invoice number format')
        return v
    
    @validator('amount')
    def validate_amount(cls, v):
        if v <= 0 or v > 999999999.99:
            raise ValueError('Amount out of range')
        return v

# FastAPI automatically validates on request
@router.post("/invoices")
async def create_invoice(payload: InvoiceCreateSchema, current_user: User = Depends(get_current_user)):
    # payload is validated
    pass
```

### Output Encoding (XSS Prevention)

```python
from html import escape

class InvoiceResponse(BaseModel):
    id: int
    invoice_number: str
    description: Optional[str] = None
    
    @validator('description', pre=False)
    def sanitize_description(cls, v):
        if v:
            return escape(v)  # Convert <script> to &lt;script&gt;
        return v
```

Or use Flask-Talisman for CSP headers:

```python
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.csp import CSPMiddleware

app.add_middleware(CSPMiddleware, header="Content-Security-Policy", value="default-src 'self'; script-src 'self'")
```

### File Upload Validation

```python
from fastapi import UploadFile, File
import mimetypes
import magic

ALLOWED_MIME_TYPES = ["application/pdf", "text/csv", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

@router.post("/invoices/upload")
async def upload_invoice(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    # Check file size
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File too large")
    
    # Check MIME type (both extension and magic bytes)
    mime_type = magic.from_buffer(contents, mime=True)
    if mime_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=400, detail="File type not allowed")
    
    # Scan for virus (optional: ClamAV)
    # av_scan(contents)
    
    # Store in safe location
    filename = secure_filename(file.filename)
    storage_path = f"/storage/{current_user.organization_id}/{uuid4()}_{filename}"
    with open(storage_path, 'wb') as f:
        f.write(contents)
    
    return {"filename": filename, "size": len(contents)}
```

---

## 10. Saudi PDPL Deep-Dive

Reference: [Saudi PDPL Guide - SDAIA](https://dgp.sdaia.gov.sa/)

### Five Core Principles

1. **Lawfulness, Fairness & Transparency**
   - Data processing must have legal basis (user consent, contractual necessity, legal obligation, vital interests, public task, legitimate interests)
   - Clear privacy notices before collection
   - Users informed of data processing purposes

2. **Purpose Limitation**
   - Data collected for specific purpose only
   - Cannot repurpose without user consent or legal basis
   - APEX: Invoices collected for accounting; cannot use for marketing

3. **Data Minimization**
   - Only collect data necessary for stated purpose
   - APEX: Collect invoice amounts, not employee salaries
   - Regular deletion of unnecessary data

4. **Accuracy**
   - Keep data current and accurate
   - Remove incorrect data promptly
   - Users have right to correct their data

5. **Storage Limitation**
   - Keep data only as long as necessary
   - APEX: Invoices retained per Saudi tax law (3-5 years), then anonymized or deleted

### Data Subject Rights

**Access Right**
- User can request copy of their personal data
- Response time: 10 business days
- Free for first request per year; subsequent requests may charge fee

```python
@router.post("/users/me/data-export")
async def export_personal_data(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Collect all personal data associated with user
    user_data = {
        "profile": get_user_profile(current_user.id, db),
        "invoices": get_user_invoices(current_user.id, db),
        "audit_logs": get_audit_logs_for_user(current_user.id, db)
    }
    
    # Export as PDF or JSON
    export_file = generate_data_export(user_data)
    
    # Log export request
    log_action(current_user.id, "data_export_requested", db)
    
    return StreamingResponse(export_file, filename=f"data_export_{current_user.id}.json")
```

**Rectification Right**
- Correct inaccurate personal data
- APEX: User can update email, address, name

**Erasure Right (Right to be Forgotten)**
- Request deletion of personal data
- Limited by legal obligations (must keep for tax purposes)

```python
@router.post("/users/me/delete")
async def request_account_deletion(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Check if user has outstanding obligations (unpaid invoices, audit in progress)
    if has_outstanding_obligations(current_user.id, db):
        raise HTTPException(status_code=403, detail="Cannot delete account with outstanding obligations")
    
    # Anonymize rather than delete
    user = db.query(User).filter(User.id == current_user.id).first()
    user.email = f"deleted_{uuid4()}@anonymous.local"
    user.first_name = "DELETED"
    user.last_name = "DELETED"
    user.is_active = False
    
    # Retain invoice data for 3 years per Saudi tax law
    db.commit()
    
    log_action(current_user.id, "account_deletion_requested", db)
    return {"message": "Account deletion requested; will be processed within 10 business days"}
```

**Data Portability**
- Export data in machine-readable format (JSON, CSV)
- Transfer to another service provider

**Objection Right**
- Opt-out of non-essential processing

### Cross-Border Transfers

**Restrictions:**
- Personal data cannot be transferred outside Saudi Arabia without explicit conditions
- Must obtain SDAIA approval (National Register of Data Controllers)
- Only if destination country has adequate protections

**APEX Implementation:**
- All data stored in Saudi Arabia (RDS in Riyadh region)
- No data transfer to international cloud providers without agreement
- If using international CDN, anonymize data

### Breach Notification

**Timeline:** 72 hours to notify SDAIA; 72 hours to notify affected data subjects  
**Notification Content:**
- Nature of breach
- Data types affected
- Mitigation measures taken
- Contact point for inquiries

```python
# app/core/breach_notification.py
from datetime import datetime, timedelta

class BreachNotificationManager:
    @staticmethod
    def notify_breach(breach_type: str, affected_users: list, db: Session):
        # Log breach
        breach = DataBreach(
            breach_type=breach_type,
            affected_user_count=len(affected_users),
            detected_at=datetime.utcnow(),
            notification_deadline=datetime.utcnow() + timedelta(hours=72)
        )
        db.add(breach)
        db.commit()
        
        # Send notification to SDAIA
        send_to_sdaia(breach)
        
        # Send notification to affected users
        for user_id in affected_users:
            send_breach_notification_email(user_id)
```

### Data Protection Officer (DPO)

- Appointment mandatory for organizations processing large-scale personal data or sensitive data
- Responsible for PDPL compliance
- Point of contact for SDAIA

```python
# In organization profile
class Organization(Base):
    __tablename__ = "organizations"
    dpo_email: str  # Data Protection Officer email
    dpo_phone: str
```

### APEX Implementation Checklist

- [ ] Privacy policy drafted per PDPL Article 5
- [ ] User consent mechanism for data collection
- [ ] Data retention policy (max 3 years for financial data)
- [ ] Breach notification process (72-hour requirement)
- [ ] DPO designated and contact info available
- [ ] Data export endpoint implemented
- [ ] Data deletion workflow (anonymization for tax records)
- [ ] Cross-border transfer restrictions (data localization)
- [ ] Regular privacy impact assessments
- [ ] Staff training on PDPL
- [ ] Registry of data processing activities maintained

---

## 11. GDPR Compliance (EU Users)

Reference: [GDPR Article 5](https://gdpr-info.eu/art-5-gdpr/)

**If APEX has EU users, six GDPR principles apply:**

### Article 5 Principles

1. **Lawfulness, Fairness & Transparency**
   - Legal basis required: consent, contract, legal obligation, vital interests, public task, legitimate interests
   - Privacy notice in plain language before data collection

2. **Purpose Limitation**
   - Only use data for stated purposes
   - Incompatible use requires new legal basis

3. **Data Minimization**
   - Only collect necessary data

4. **Accuracy**
   - Keep data current; allow rectification

5. **Storage Limitation**
   - Delete when no longer needed (different from Saudi 3-year requirement)

6. **Integrity and Confidentiality**
   - Security controls per Article 32 (encryption, access control, staff training)

### Key Obligations

**Lawful Basis** (Article 6):
- **Consent:** Explicit opt-in (pre-ticked boxes invalid)
- **Contract:** Data necessary to provide service
- **Legal Obligation:** Required by law (tax, audit)
- **Vital Interests:** Life or death
- **Public Task:** Government function
- **Legitimate Interests:** Balancing test (not marketing)

**Rights** (Chapter III):
- Right of access (Article 15)
- Right to rectification (Article 16)
- Right to erasure (Article 17) — "right to be forgotten"
- Right to restrict processing (Article 18)
- Right to data portability (Article 20)
- Right to object (Article 21)

**Records of Processing Activities** (RoPA, Article 5(2)):
- Document all processing activities
- Maintain for audit

**Data Protection Impact Assessment** (DPIA, Article 35):
- Required for:
  - Large-scale processing of sensitive data
  - Automated decision-making
  - Systematic monitoring
  - Facial recognition
  - Profiling with legal effect

**Processor Agreement** (Article 28):
- If using sub-processors (cloud, analytics), sign DPA
- AWS, Google, Microsoft provide standard DPAs

### APEX GDPR Compliance

- [ ] Privacy policy per Article 13/14
- [ ] Lawful basis documented for each processing
- [ ] Consent mechanism if relying on Article 7
- [ ] Data export (Article 20) — `/users/me/data-export` endpoint
- [ ] Erasure workflow (Article 17) — with legal basis exceptions
- [ ] Processor agreements with cloud vendors
- [ ] DPIA for high-risk processing
- [ ] Breach notification (Article 33/34) within 72 hours
- [ ] DPO designation (if high-volume processing)
- [ ] Staff training on GDPR

---

## 12. ISO 27001 Controls Mapping

Reference: [ISO 27001:2022 Annex A](https://www.isms.online/iso-27001/annex-a-2022/)

**ISO 27001:2022 restructured from 114 controls (2013) to 93 controls (2022) in 4 categories:**

### Organizational Controls (37)

- A.5.1 Policies for information security
- A.5.2 Information security roles and responsibilities
- A.5.3 Segregation of duties
- A.5.4 Management responsibilities
- A.5.5 Contact with authorities and special interest groups
- A.5.6 Project management
- A.5.7 Threat and vulnerability management
- A.5.8 Compliance
- A.5.9 Asset management
- A.5.10 Access management
- A.5.11 Cryptography
- A.5.12 Physical and environmental security
- A.5.13 Operations
- A.5.14 Communications
- A.5.15 System acquisition, development and maintenance
- A.5.16 Supplier relationships
- A.5.17 Information security incident management
- A.5.18 Business continuity management
- A.5.19 Compliance with legal and regulatory requirements

### People Controls (34)

- A.6.1 Screening
- A.6.2 Terms and conditions of employment
- A.6.3 Information security awareness, education and training
- A.6.4 Disciplinary process
- A.6.5 Responsibilities after employment termination
- A.6.6 Confidentiality or non-disclosure agreements
- A.6.7 Remote working
- A.6.8 Information security event reporting

### Physical Controls (14)

- A.7.1 Physical security perimeters
- A.7.2 Physical entry
- A.7.3 Securing assets
- A.7.4 Physical and environmental conditions
- A.7.5 Working in secure areas
- A.7.6 Delivery and loading areas

### Technology Controls (8 + detailed sub-controls)

- A.8.1 User endpoint devices
- A.8.2 Privileged access rights
- A.8.3 Information access restriction
- A.8.4 Access to cryptographic keys
- A.8.5 Cryptography
- A.8.6 Technical vulnerability management
- A.8.7 Configuration management
- A.8.8 Information deletion
- A.8.9 Data masking
- A.8.10 Data leakage prevention
- A.8.11 Monitoring
- A.8.12 Logging
- A.8.13 Monitoring system use and applications
- A.8.14 Software and information installed
- A.8.15 Restricting software installation
- A.8.16 Management of technically vulnerable systems
- A.8.17 Automated information system monitoring tools
- A.8.18 Installation of software on behalf of users
- A.8.19 Events and logs
- A.8.20 User identification and authentication
- A.8.21 User access provisioning
- A.8.22 Management of secret authentication information of users
- A.8.23 Management of information system security
- A.8.24 Use of privileged utility programs
- A.8.25 Recording user activities
- A.8.26 Removal or adjustment of access rights
- A.8.27 Information security for user processes outside of information systems
- A.8.28 Secure authentication
- A.8.29 Network security
- A.8.30 Network segregation
- A.8.31 Segregation of information networks
- A.8.32 Boundary protection
- A.8.33 Filtering
- A.8.34 Use of cryptography
- A.8.35 Cryptographic controls
- A.8.36 Key management
- A.8.37 Availability and resilience

### APEX Top 30 Relevant Controls

| Control | APEX Implementation Status | Target |
|---------|---------------------------|--------|
| A.5.1 Policies | Policy document drafted | Current |
| A.5.3 Segregation of Duties | Invoice approve ≠ create | Planned Q3 2026 |
| A.5.7 Threat & Vulnerability Management | Quarterly pen tests | Planned Q2 2026 |
| A.5.8 Compliance | PDPL/GDPR monitoring | Current |
| A.5.9 Asset Management | Device inventory maintained | Current |
| A.5.11 Cryptography | TLS 1.3, AES-256 | Current |
| A.6.3 Security Awareness Training | Annual staff training | Planned Q1 2026 |
| A.7.1 Physical Security Perimeters | Data center locked, access logged | Current (via Render) |
| A.8.2 Privileged Access | Service account rotation 90d | Planned Q2 2026 |
| A.8.3 Information Access Restriction | RBAC implemented | Current |
| A.8.5 Cryptography | AES-256, TLS 1.3 | Current |
| A.8.12 Logging | Centralized logs via CloudWatch | Planned Q2 2026 |
| A.8.20 User Authentication | JWT + 2FA for admins | Current |
| A.8.25 Recording User Activities | Audit logs with hash-chain | Planned Q3 2026 |
| A.8.28 Secure Authentication | Password policy, bcrypt 12 | Current |
| A.8.29 Network Security | VPC, security groups | Planned Q2 2026 |
| A.8.34 Cryptography | All APIs TLS 1.3 | Current |
| A.8.36 Key Management | AWS Secrets Manager | Planned Q2 2026 |
| A.5.17 Incident Management | Incident response plan | Planned Q1 2026 |
| A.5.18 Business Continuity | DR plan, RTO 4h, RPO 1h | Planned Q2 2026 |

---

## 13. SOC 2 Type II Readiness

Reference: [SOC 2 Type II](https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2)

### Five Trust Services Criteria

**1. Security**
- Access controls (authentication, authorization)
- Data protection (encryption, backups)
- Monitoring and logging
- Incident response

**2. Availability**
- System uptime (SLA: 99.9%)
- Disaster recovery (RTO 4 hours, RPO 1 hour)
- Monitoring and alerting

**3. Processing Integrity**
- Input validation
- Completeness and accuracy of data processing
- Error handling
- Audit trails

**4. Confidentiality**
- Encryption of sensitive data
- Access restrictions
- Monitoring for unauthorized access

**5. Privacy**
- Compliance with privacy laws (PDPL, GDPR)
- Consent management
- Data subject rights (access, deletion, portability)

### Evidence Collection

**Audit Period:** 6-12 months of continuous operation  
**Audit Window:** Typically 6 months minimum

**Required Documentation:**
- Access control policies and procedures
- User access logs (monthly review evidence)
- Change management logs (all changes tracked)
- Incident response plan and drills (quarterly)
- Backup and recovery test logs (quarterly)
- Security training records (annual)
- Encryption key management procedures
- Vendor management (SLAs, audits)
- Business continuity plan and drills (annual)

### APEX SOC 2 Readiness Checklist

- [ ] **Security**
  - [ ] Authentication policy (password, 2FA)
  - [ ] Authorization matrix (RBAC)
  - [ ] Quarterly access review process
  - [ ] Encryption implementation (TLS 1.3, AES-256)
  - [ ] Incident response plan and quarterly drills
  - [ ] Monthly log review and monitoring

- [ ] **Availability**
  - [ ] SLA commitment (99.9% uptime)
  - [ ] Uptime monitoring (Pingdom, CloudWatch)
  - [ ] Monthly uptime reports
  - [ ] DR plan with 4-hour RTO, 1-hour RPO
  - [ ] Quarterly DR drills with documentation

- [ ] **Processing Integrity**
  - [ ] Input validation per Pydantic schemas
  - [ ] Data processing audit logs
  - [ ] Error handling and logging
  - [ ] Regular reconciliations (manual/automated)

- [ ] **Confidentiality**
  - [ ] Encryption of data at rest and in transit
  - [ ] Access logs reviewed monthly
  - [ ] Classification of data levels
  - [ ] Data masking in non-production environments

- [ ] **Privacy**
  - [ ] Privacy policy (PDPL, GDPR compliant)
  - [ ] Consent tracking and audit
  - [ ] Data subject rights fulfillment (3-month SLA)
  - [ ] Breach notification procedures (72-hour target)

### Timeline for SOC 2 Readiness

- **Q2 2026:** Complete evidence collection setup (logging, monitoring, audit trails)
- **Q3 2026:** Document policies and procedures
- **Q4 2026:** Conduct internal audit to identify gaps
- **Q1 2027:** Implement remediation
- **Q2 2027:** Begin 6-month evidence collection for audit
- **Q4 2027:** SOC 2 Type II audit (2-3 week engagement)

---

## 14. Logging & Monitoring

### Centralized Log Aggregation

**Stack:** FastAPI app logs → AWS CloudWatch (Render-compatible) or ELK Stack

```python
# app/core/logging_config.py
import logging
import logging.handlers
import json
from datetime import datetime

# CloudWatch
import boto3
from watchtower import CloudWatchLogHandler

logger = logging.getLogger(__name__)

# Console handler
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)

# CloudWatch handler
cloudwatch_handler = CloudWatchLogHandler(
    log_group="/apex/fastapi",
    stream_name="production",
    use_queues=True
)
cloudwatch_handler.setLevel(logging.INFO)

# JSON formatter for structured logging
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.name,
            "function": record.funcName,
            "line": record.lineno
        }
        return json.dumps(log_data)

formatter = JSONFormatter()
cloudwatch_handler.setFormatter(formatter)

logger.addHandler(console_handler)
logger.addHandler(cloudwatch_handler)
logger.setLevel(logging.DEBUG)
```

### Security Events vs. Operational Events

**Security Events (Audit):**
- Login attempts (success/failure)
- Permission changes (role grants, revokes)
- Data access (invoice read, export)
- Sensitive modifications (invoice amount change)
- Administrative actions (user creation, deletion)
- Authentication failures (invalid token, MFA failure)

**Operational Events (Metrics):**
- API latency, response times
- Database query execution time
- Server resource utilization
- Scheduled job completion

```python
# app/core/audit_logging.py
from enum import Enum
from datetime import datetime

class AuditEventType(str, Enum):
    LOGIN_SUCCESS = "login_success"
    LOGIN_FAILURE = "login_failure"
    ROLE_CHANGED = "role_changed"
    INVOICE_CREATED = "invoice_created"
    INVOICE_APPROVED = "invoice_approved"
    INVOICE_DELETED = "invoice_deleted"
    DATA_EXPORTED = "data_exported"
    ADMIN_ACTION = "admin_action"
    BACKUP_COMPLETED = "backup_completed"
    MFA_ENABLED = "2fa_enabled"

def audit_log(event_type: AuditEventType, user_id: int, resource_type: str, resource_id: int, changes: dict, db: Session):
    log_entry = AuditLog(
        event_type=event_type.value,
        user_id=user_id,
        resource_type=resource_type,
        resource_id=resource_id,
        changes=changes,
        timestamp=datetime.utcnow(),
        organization_id=get_user_org(user_id, db)
    )
    db.add(log_entry)
    db.commit()
    
    # Also send to security monitoring/SIEM
    send_to_siem(log_entry)

# Usage
@router.post("/invoices")
async def create_invoice(payload: InvoiceCreateSchema, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invoice = Invoice(**payload.dict())
    db.add(invoice)
    db.commit()
    
    audit_log(
        AuditEventType.INVOICE_CREATED,
        current_user.id,
        "invoice",
        invoice.id,
        {"amount": invoice.amount, "vendor_id": invoice.vendor_id},
        db
    )
    
    return invoice
```

### SIEM Integration

**Tools:** Wazuh, Sumo Logic, Splunk

```python
# Send audit events to SIEM
import requests

def send_to_siem(log_entry: AuditLog):
    payload = {
        "event_type": log_entry.event_type,
        "timestamp": log_entry.timestamp.isoformat(),
        "user_id": log_entry.user_id,
        "resource_id": log_entry.resource_id,
        "changes": log_entry.changes
    }
    
    try:
        requests.post(
            "https://siem.example.com/api/events",
            json=payload,
            headers={"Authorization": f"Bearer {SIEM_API_KEY}"},
            timeout=5
        )
    except Exception as e:
        logger.error(f"Failed to send to SIEM: {e}")
```

### Anomaly Detection

**Rules to implement:**
- 5 failed login attempts in 5 minutes → block account, alert security team
- Bulk data export (>1000 records) → require approval, log
- Privilege escalation (user role changed) → alert
- Access from unusual IP/geography → flag
- Unusual API endpoint access pattern (many 404s) → possible reconnaissance

```python
# app/core/anomaly_detection.py
import redis
from datetime import datetime, timedelta

redis_client = redis.Redis(host='localhost', port=6379, db=1)

def detect_brute_force(user_id: int) -> bool:
    key = f"login_failures:{user_id}"
    failures = redis_client.incr(key)
    redis_client.expire(key, 300)  # 5 minutes
    
    if failures >= 5:
        logger.warning(f"Brute force detected for user {user_id}")
        send_alert(f"Brute force attack detected for user {user_id}")
        # Lock account
        redis_client.setex(f"account_locked:{user_id}", 3600, 1)
        return True
    
    return False

def detect_bulk_export(user_id: int, record_count: int) -> bool:
    if record_count > 1000:
        log_event(f"Bulk export detected: {record_count} records by user {user_id}")
        send_alert(f"Large data export: {record_count} records")
        return True
    return False

def detect_privilege_escalation(user_id: int, old_role: str, new_role: str):
    if old_role != new_role:
        log_event(f"Role change: {old_role} → {new_role} for user {user_id}")
        if new_role in ["admin", "auditor"]:
            send_alert(f"Privilege escalation: {old_role} → {new_role}")
```

---

## 15. Incident Response Plan

### Severity Matrix

| Level | Examples | Response Time | Escalation |
|-------|----------|---|---|
| **Critical** | Data breach, ransomware, system down >1h | 15 min | CEO, CTO, Legal |
| **High** | Failed logins, unauthorized access attempt, compliance violation | 1 hour | CTO, Security Lead |
| **Medium** | Suspicious activity, security misconfiguration | 4 hours | Security Lead, DevOps |
| **Low** | Failed 2FA attempts, unusual but non-critical activity | Next business day | Security Team |

### Incident Response Workflow

```
Detection → Triage → Contain → Eradicate → Recover → Lessons Learned
```

**1. Detection (0-15 min)**
- Automated alerts from SIEM
- User reports
- Security monitoring tools

**2. Triage (0-30 min)**
- Assess severity
- Identify affected systems/data
- Page on-call security engineer

**3. Containment (0-1 hour)**
- Isolate affected systems
- Preserve evidence (don't delete logs)
- Revoke compromised credentials
- Block attacker IP

```python
# app/core/incident_response.py
from enum import Enum

class IncidentSeverity(str, Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

def handle_data_breach(affected_users: list, data_type: str, db: Session):
    # Create incident record
    incident = SecurityIncident(
        severity=IncidentSeverity.CRITICAL,
        title=f"Data breach - {data_type}",
        description="...",
        affected_users=len(affected_users),
        detected_at=datetime.utcnow(),
        status="open"
    )
    db.add(incident)
    db.commit()
    
    # Send alerts
    send_alert_to_team(incident)
    send_alert_to_ceo(incident)
    
    # Revoke suspect tokens
    for user_id in affected_users:
        revoke_all_tokens(user_id)
    
    # Preserve evidence
    backup_logs()
    
    # Notify legal/compliance
    notify_compliance_team(incident)
    
    # Prepare breach notification (72-hour requirement)
    prepare_breach_notification(affected_users, data_type, db)
```

**4. Eradication (1-12 hours)**
- Remove malware/attacker access
- Patch vulnerabilities
- Reset compromised credentials

**5. Recovery (4-24 hours)**
- Restore systems from clean backups
- Verify systems operational
- Monitor for re-compromise

**6. Lessons Learned (1-2 weeks)**
- Post-mortem meeting
- Root cause analysis
- Implement preventive controls
- Update incident response plan

### Communication Plan

**Internal:**
- Slack #security-incidents channel
- Email to CISO, CTO, CEO (for critical)
- Daily standup during incident

**External (for data breaches):**
- Affected users (within 72 hours per PDPL)
- SDAIA (within 72 hours per PDPL)
- Insurers (within 5 days per insurance policy)
- Media (if >500 users affected, within 7 days)

**Template:**
```
Subject: [SECURITY INCIDENT] Data Breach Notification

Dear [User],

On [DATE], we detected a security incident affecting your personal data.

Affected Data: [Tax ID, Bank Account, etc.]

Incident Type: [SQL Injection, Ransomware, etc.]

Actions Taken:
- System patched and monitored
- Your account secured
- Password reset recommended

What You Should Do:
- Change your password
- Enable 2FA
- Monitor bank account for unauthorized transactions
- Contact us if you notice suspicious activity

Contact: security@apex.example.com
Case ID: [INCIDENT_ID]
```

### Forensics Readiness

- **Log Retention:** 7 years for financial systems (per PDPL)
- **Hash Chain:** Immutable audit logs with SHA-256 hash-chain
- **Evidence Preservation:** Do not delete logs during investigation
- **Chain of Custody:** Document who accessed logs and when

---

## 16. Vulnerability Management

### Dependency Scanning

**Tools & Frequency:**

```bash
# Python dependencies (weekly)
pip-audit
safety check

# Dart/Flutter dependencies (weekly)
pub pub audit --fatal-exit-code=1

# Docker images (on build)
docker scan [image]
trivy image [image]

# Container registry (continuous)
# AWS ECR image scanning on push
```

**In CI/CD:**

```yaml
# .github/workflows/security.yml
name: Security Checks

on: [push, pull_request]

jobs:
  dependency-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Scan Python dependencies
        run: |
          pip install pip-audit
          pip-audit --fix || exit 1
      
      - name: Scan Dart dependencies
        run: |
          dart pub get
          dart pub audit
  
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: SAST with Bandit
        run: |
          pip install bandit
          bandit -r app/ -f json -o bandit-report.json
      
      - name: SAST with Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: p/owasp-top-ten
```

### Static Application Security Testing (SAST)

**Tools:**
- **Bandit** (Python): Detects hardcoded credentials, weak cryptography
- **Ruff** (Python): With security rules (S101-S610)
- **Semgrep** (Multi-language): Pattern-based vulnerability detection
- **Dart Analyzer** (Dart): Built-in security checks

### Dynamic Application Security Testing (DAST)

**Tools:**
- **OWASP ZAP** (free): Web app scanning
- **Burp Suite Community/Pro** (commercial): Advanced scanning
- **Nuclei** (free, template-based)

### Penetration Testing

- **Frequency:** Annually
- **Scope:** Full application, APIs, infrastructure
- **Types:**
  - White-box (with access to source code)
  - Black-box (without access)
  - Grey-box (partial access)

### Vulnerability Disclosure / Bug Bounty

**Platforms:**
- HackerOne, Bugcrowd (managed)
- Self-hosted via responsible disclosure policy

**APEX Disclosure Policy:**
```
# Security Policy

If you discover a vulnerability in APEX:

1. Do not disclose publicly until patch is released
2. Email security@apex.example.com with:
   - Description
   - Proof of concept
   - Impact assessment
3. Response time:
   - Acknowledgment: 24 hours
   - Status update: 1 week
   - Patch release: 30 days (critical), 90 days (non-critical)

We offer bug bounties:
- Critical: $5,000
- High: $2,000
- Medium: $500
- Low: $100
```

---

## 17. Secure SDLC

### Security Design Review

**Before development of any feature:**
- Threat model (STRIDE)
- Data flow diagram
- Trust boundaries identified
- Security requirements documented

**Example: Invoice Approval Feature**
- **Threat:** Invoice creator approves own invoice (fraud)
- **Mitigation:** Different users must create and approve
- **Implementation:** Add `required_approver_id` to Invoice model; validation in approval endpoint

### Code Review Checklist

```markdown
# Security Code Review Checklist

- [ ] Input validation: All user inputs validated via Pydantic
- [ ] Output encoding: Sensitive data masked, HTML escaped
- [ ] Authentication: 2FA enforced for sensitive operations
- [ ] Authorization: org_id checked on all queries
- [ ] Encryption: Sensitive fields encrypted at application level
- [ ] SQL injection: No string concatenation; parameterized queries only
- [ ] Session management: JWT tokens with short expiry, refresh rotation
- [ ] CSRF protection: POST endpoints protected
- [ ] Rate limiting: Login, export endpoints rate-limited
- [ ] Logging: Sensitive operations logged to audit trail
- [ ] Error handling: No stack traces leaked to clients
- [ ] Dependencies: No deprecated/vulnerable packages
```

### Pre-Commit Hooks

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run Bandit
bandit -r app/ --skip B101,B601 || exit 1

# Run Ruff
ruff check app/ || exit 1

# Run Black
black --check app/ || exit 1

# Check for secrets
detect-secrets scan --baseline .secrets.baseline || exit 1

echo "Security checks passed"
```

### Pre-Deploy Security Gates

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: SAST scan
        run: bandit -r app/
      
      - name: Dependency audit
        run: pip-audit
      
      - name: Container scan
        run: trivy image apex:latest
  
  deploy:
    needs: security
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: |
          # Only proceed if security job passed
          curl -X POST https://api.render.com/deploy
```

### Security Training

- **Quarterly:** OWASP Top 10 review
- **Annual:** SDLC security update
- **New hire:** Security onboarding (2 hours)
- **Topics:** Password management, phishing, incident reporting, secure coding

---

## 18. Disaster Recovery & Business Continuity

### RTO & RPO

- **RTO (Recovery Time Objective):** 4 hours
  - Maximum acceptable downtime before data loss
  - Supports SLA of 99.9% uptime

- **RPO (Recovery Point Objective):** 1 hour
  - Maximum acceptable data loss
  - Database backups hourly, incremental

### Backup Strategy

**Frequency & Retention:**
- Full backup: Daily (midnight UTC)
- Incremental backup: Hourly
- Retention: 30 days (production), 7 days (non-production)

**Storage:**
- Primary: AWS S3 (us-east-1)
- Secondary: S3 (eu-west-1) — geo-redundant
- Encryption: AES-256 server-side

```python
# app/core/backup.py
import subprocess
import boto3
from datetime import datetime

s3_client = boto3.client('s3')

def backup_database(database_url: str):
    # Full backup
    timestamp = datetime.utcnow().isoformat()
    filename = f"apex_full_{timestamp}.sql.gz"
    
    # pg_dump + gzip
    cmd = f"pg_dump {database_url} | gzip > /tmp/{filename}"
    subprocess.run(cmd, shell=True)
    
    # Upload to S3
    s3_client.upload_file(
        f"/tmp/{filename}",
        'apex-backups',
        f"full/{filename}",
        ExtraArgs={'ServerSideEncryption': 'AES256'}
    )
    
    # Verify backup
    response = s3_client.head_object(Bucket='apex-backups', Key=f"full/{filename}")
    assert response['ContentLength'] > 1000000, "Backup file too small"
    
    log_action(f"Backup completed: {filename}", db)

def restore_database(backup_filename: str):
    # Download from S3
    s3_client.download_file(
        'apex-backups',
        f"full/{backup_filename}",
        f"/tmp/{backup_filename}"
    )
    
    # Restore
    cmd = f"gunzip -c /tmp/{backup_filename} | psql {DATABASE_URL}"
    subprocess.run(cmd, shell=True)
    
    log_action(f"Database restored from {backup_filename}", db)
```

### DR Drills

- **Frequency:** Quarterly
- **Procedure:**
  1. Restore backup to staging environment
  2. Verify data integrity (row counts, checksums)
  3. Run test suite against restored DB
  4. Document time to restore
  5. Document any issues

**Runbook:**

```markdown
# Disaster Recovery Runbook

## Critical System Down (Database)

1. **Declare Incident (5 min)**
   - Page on-call DBA
   - Assess severity (critical)
   - Post to #security-incidents

2. **Assess Damage (10 min)**
   - Check database connectivity
   - Review error logs
   - Determine if restore needed

3. **Restore from Backup (30 min)**
   ```bash
   # List available backups
   aws s3 ls s3://apex-backups/full/
   
   # Restore from most recent
   aws s3 cp s3://apex-backups/full/apex_full_2026-04-30T00:00:00.sql.gz /tmp/
   gunzip /tmp/apex_full_2026-04-30T00:00:00.sql.gz
   psql production_db < /tmp/apex_full_2026-04-30T00:00:00.sql
   ```

4. **Verify Integrity (15 min)**
   ```bash
   # Check row counts
   SELECT COUNT(*) FROM invoices;
   SELECT COUNT(*) FROM users;
   
   # Verify indexes
   REINDEX DATABASE production_db;
   ```

5. **Resume Service (10 min)**
   - Restart application
   - Monitor error rates
   - Verify API endpoints responding

6. **Post-Incident (next day)**
   - Root cause analysis
   - Preventive controls
   - Update runbook
```

---

## 19. MENA-Specific Regulatory Requirements

### Saudi Arabia

**Data Localization:**
- Personal data must be stored in Saudi Arabia (RDS in ap-southeast-1a — Riyadh region)
- No transfers outside KSA without SDAIA approval
- Government contractors must use government-certified data centers

**ZATCA Compliance:**
- E-invoicing mandatory (Phase 2: Jan 2023)
- Private keys stored securely (HSM or KMS)
- ZATCA API calls authenticated with certificates
- Invoice compliance reports submitted monthly

**Implementation:**
```python
# app/phase7/services/zatca_service.py
import boto3

secrets_client = boto3.client('secretsmanager', region_name='ap-southeast-1')

def get_zatca_certificate():
    # Retrieve from AWS Secrets Manager (KSA region)
    response = secrets_client.get_secret_value(SecretId='zatca-certificate')
    return response['SecretString']

def submit_invoice_to_zatca(organization_id: int, invoice: Invoice, db: Session):
    # Verify organization has ZATCA setup
    zatca_config = db.query(ZATCAConfig).filter(
        ZATCAConfig.organization_id == organization_id
    ).first()
    
    if not zatca_config:
        raise HTTPException(status_code=400, detail="ZATCA not configured")
    
    # Generate e-invoice (XML)
    invoice_xml = generate_zatca_xml(invoice)
    
    # Sign with ZATCA private key
    certificate = get_zatca_certificate()
    signed_invoice = sign_xml(invoice_xml, certificate)
    
    # Submit to ZATCA API
    response = submit_to_zatca_api(signed_invoice)
    
    # Store compliance status
    invoice.zatca_status = response['status']
    invoice.zatca_uuid = response['uuid']
    db.commit()
    
    return response
```

### UAE

**Data Residency:**
- Personal data may be stored outside UAE if destination has adequate protection
- Healthcare data must remain in UAE
- Financial data recommended to be in UAE

**PDPL Compliance:**
- No processing without consent (except legal/contractual obligations)
- Data subject rights: access, rectification, erasure (with exceptions)
- DPO required for high-volume processing
- Breach notification: 3 days to individuals, 2 weeks to authority

**Implementation:**
```python
# app/core/uae_compliance.py

# Consent management for UAE users
class UEAEConsentTracking(Base):
    __tablename__ = "uae_consent"
    user_id = Column(Integer, ForeignKey("users.id"))
    consent_type = Column(String)  # "marketing", "analytics", "financial_processing"
    granted_at = Column(DateTime)
    revoked_at = Column(DateTime, nullable=True)
```

### Egypt

**Data Protection Law 151/2020:**
- Explicit consent required for any data processing
- Processing license may be required for certain activities
- DPO mandatory if processing large-scale personal data
- Breach notification: 10 business days to authority
- Administrative fines up to EGP 5 million

**Implementation:**
```python
# app/core/egypt_compliance.py

# Explicit consent before processing
class EgyptConsentForm(Base):
    __tablename__ = "egypt_consent"
    user_id = Column(Integer, ForeignKey("users.id"))
    purpose = Column(String)  # "invoice_processing", "tax_reporting"
    consent_text = Column(String)
    agreed_at = Column(DateTime)
    ip_address = Column(String)  # Evidence of consent
    consent_version = Column(Integer)  # Track policy changes
```

---

## 20. Threat Model Diagrams (ASCII)

### Login Flow

```
┌─────────────────────────────────────────────────────────┐
│                     USER                                 │
│              (Browser / Flutter)                         │
└────────────────┬──────────────────────────────────────────┘
                 │
                 │ HTTPS POST /auth/login
                 │ {email, password}
                 ▼
┌─────────────────────────────────────────────────────────┐
│            FASTAPI BACKEND (TLS 1.3)                    │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 1. Validate email/password                       │  │
│  │    - Check HIBP for breached password            │  │
│  │    - Verify bcrypt hash (12 rounds)              │  │
│  │ 2. Check 2FA requirement (admins)                │  │
│  │    - Generate TOTP challenge                      │  │
│  │ 3. Create JWT tokens                             │  │
│  │    - Access token (15 min expiry)                │  │
│  │    - Refresh token (7 day, stored as hash)       │  │
│  │ 4. Log authentication event                      │  │
│  │    - Audit trail with organization_id            │  │
│  └──────────────────────────────────────────────────┘  │
│                      │                                  │
│                      ▼                                  │
│            ┌──────────────────────┐                    │
│            │  PostgreSQL Database │                    │
│            │  (AES-256 at rest)   │                    │
│            │  - User credentials  │                    │
│            │  - Audit logs        │                    │
│            │  - Token blacklist   │                    │
│            └──────────────────────┘                    │
└────────────┬──────────────────────────────────────────┘
             │
             │ HTTPS Response
             │ {access_token, refresh_token}
             ▼
┌─────────────────────────────────────────────────────────┐
│                     USER                                 │
│         (Token stored securely)                         │
│         - httpOnly cookie (ideal)                       │
│         - Encrypted localStorage (Flutter)              │
└─────────────────────────────────────────────────────────┘

Trust Boundaries:
  - TLS 1.3 boundary between client and server
  - Database encryption boundary
  - Token validation on every API request
```

### Invoice Creation & Approval Flow

```
┌──────────────────────────────────────┐
│    ACCOUNTANT (Creator)              │
│  POST /invoices                      │
│  {vendor_id, amount, due_date, ...} │
└────────────────┬─────────────────────┘
                 │ JWT + Organization ID
                 │ HTTPS POST
                 ▼
         ┌──────────────────────────┐
         │  INPUT VALIDATION        │
         │  - Pydantic schemas      │
         │  - Amount limits         │
         │  - Vendor ownership      │
         │  - Org isolation         │
         └────────┬─────────────────┘
                  │
                  ▼
         ┌──────────────────────────┐
         │  DATABASE INSERT         │
         │  - Set creator_id        │
         │  - Set invoice status    │
         │  - Generate UUID         │
         │  - Store encrypted       │
         └────────┬─────────────────┘
                  │
                  ▼
         ┌──────────────────────────┐
         │  AUDIT LOG               │
         │  - invoice_created event │
         │  - Hash chain update     │
         │  - Timestamp             │
         └────────┬─────────────────┘
                  │
         ┌────────┴─────────────────┐
         │                          │
         ▼                          ▼
    ┌─────────────────┐       ┌──────────────────┐
    │ NOTIFICATION    │       │ APPROVAL QUEUE   │
    │ Send to         │       │ Mark as pending  │
    │ Approver        │       │ approval         │
    └─────────────────┘       └──────────────────┘
                                     │
                                     │
         ┌───────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│    ACCOUNTANT (Approver)             │
│  POST /invoices/{id}/approve         │
│  - Verify amount                     │
│  - Check vendor details              │
│  - Add approval notes                │
└────────────────┬─────────────────────┘
                 │
         ┌───────┴──────────────────────────┐
         │                                  │
    Allowed (different user)     Blocked (same user)
         │                                  │
         ▼                                  ▼
    ┌──────────────┐             ┌─────────────────┐
    │ Update       │             │ Return 403      │
    │ status to    │             │ "Segregation    │
    │ "approved"   │             │ of duties       │
    │              │             │ required"       │
    └──────┬───────┘             └─────────────────┘
           │
           ▼
    ┌──────────────┐
    │ AUDIT LOG    │
    │ - Approver   │
    │ - Date/Time  │
    │ - Changes    │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Ready for    │
    │ ZATCA        │
    │ submission   │
    └──────────────┘
```

### ZATCA E-Invoice Submission Flow

```
┌────────────────────────────────┐
│  Invoice Status: "approved"    │
│  Ready for ZATCA submission    │
└────────────┬───────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│  GENERATE ZATCA XML                │
│  - Invoice structure per spec      │
│  - Line items detail               │
│  - Tax calculations                │
│  - Totals and amounts              │
└────────────┬───────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│  SIGN WITH ZATCA KEY               │
│  - Retrieve from AWS Secrets Mgr   │
│  - KMS-encrypted in transit        │
│  - Digital signature (RSA-256)     │
└────────────┬───────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│  VALIDATE XML SCHEMA               │
│  - Check structure                 │
│  - Verify all required fields      │
│  - Calculate compliance hash       │
└────────────┬───────────────────────┘
             │
             │ TLS 1.3 + Certificate Pinning
             │ HTTPS POST
             ▼
┌──────────────────────────────────────────────────┐
│  ZATCA API (api.zatca.gov.sa)                   │
│  - Validate invoice                             │
│  - Check compliance                             │
│  - Return UUID & compliance status              │
└────────────┬───────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│  STORE ZATCA RESPONSE              │
│  - UUID in database (encrypted)    │
│  - Compliance status               │
│  - Response timestamp              │
└────────────┬───────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│  UPDATE INVOICE STATUS             │
│  - "submitted_to_zatca"            │
│  - Archive on ZATCA platform       │
└────────────┬───────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│  AUDIT LOG                         │
│  - zatca_submission event          │
│  - UUID, status, timestamp         │
│  - Hash chain update               │
└────────────────────────────────────┘
```

---

## References & Sources

- [OWASP Top 10:2021](https://owasp.org/Top10/2021/)
- [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [Microsoft Threat Modeling Tool](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [ISO 27001:2022 Annex A](https://www.isms.online/iso-27001/annex-a-2022/)
- [Saudi PDPL Guide](https://dgp.sdaia.gov.sa/)
- [UAE Federal Decree-Law No. 45 of 2021](https://uaelegislation.gov.ae/en/legislations/1972/download)
- [Egypt Law 151 of 2020](https://www.acc.com/sites/default/files/program-materials/upload/Data%20Protection%20Law%20-%20Egypt%20-%20EN%20-%20MBH.PDF)
- [GDPR Article 5](https://gdpr-info.eu/art-5-gdpr/)
- [PCI DSS v4.0](https://blog.pcisecuritystandards.org/pci-dss-v4-0-resource-hub)
- [NIST Cybersecurity Framework 2.0](https://nvlpubs.nist.gov/nistpubs/CSWP/NIST.CSWP.29.pdf)
- [SOC 2 Type II](https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2)
- [SQLAlchemy SQL Injection Prevention](https://towardsdatascience.com/understand-sql-injection-and-learn-to-avoid-it-in-python-with-sqlalchemy-2c0ba57733b2)
- [Auth0 - Refresh Token Best Practices](https://auth0.com/blog/refresh-tokens-what-are-they-and-when-to-use-them/)
- [Fintech Attack Vectors](https://www.sprocketsecurity.com/blog/what-the-latest-social-engineering-attacks-in-financial-services-look-like)
- [Fintech Third-Party Risks](https://securityscorecard.com/company/press/securityscorecard-report-links-41-8-of-breaches-impacting-leading-fintech-companies-to-third-party-vendors/)
- [FastAPI Rate Limiting](https://dev.to/adiletakmatov/fastapi-security-100-lvl-production-grade-ddos-protection-162k)
- [Immutable Audit Logging](https://www.hubifi.com/blog/immutable-audit-log-guide)

---

**End of Document**

This comprehensive security & threat model document provides APEX with actionable guidance for:
- Securing multi-tenant financial data (MENA-compliant)
- Implementing OWASP Top 10 / API Security controls
- Meeting Saudi PDPL, UAE PDPL, Egypt Law 151, GDPR, ISO 27001, SOC 2 Type II
- Incident response, disaster recovery, and vulnerability management
- Architectural threat modeling with ASCII diagrams
