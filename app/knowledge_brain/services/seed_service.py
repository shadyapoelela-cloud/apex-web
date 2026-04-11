"""
Knowledge Brain Seed Service v2 — تعبئة شاملة لكل المعرفة
"""

from app.knowledge_brain.models.db_models import (
    Source,
    Entry,
    Rule,
    Authority,
    Domain,
    Sector,
)
from app.knowledge_brain.data.authorities.authority_registry import AUTHORITIES
from app.knowledge_brain.models.core_models import DOMAINS, SECTORS
from app.knowledge_brain.rulebooks.tax_rulebook import TAX_RULES
from app.knowledge_brain.rulebooks.accounting_rulebook import ACCOUNTING_RULES
from app.knowledge_brain.rulebooks.governance_rulebook import GOVERNANCE_RULES
from app.knowledge_brain.rulebooks.compliance_rulebook import COMPLIANCE_RULES
from app.core.saudi_knowledge_base import (
    IFRS,
    ZATCA,
    COMPANIES,
    LABOR,
    GOSI,
    BANKING,
    CAPITAL_MARKET,
    INVESTMENT,
    SECTORS as KB_SECTORS,
    QAWAEM,
    BANKRUPTCY,
    VISION_2030,
    HR_MANAGEMENT,
    OPERATIONS,
    MARKETING_SALES,
    ACCOUNTING_MGMT,
)


def _safe(obj):
    if isinstance(obj, dict):
        return {k: _safe(v) for k, v in obj.items() if not callable(v)}
    if isinstance(obj, list):
        return [_safe(i) for i in obj if not callable(i)]
    if isinstance(obj, (str, int, float, bool, type(None))):
        return obj
    return str(obj)


def _summ(obj, n=8):
    if isinstance(obj, str):
        return obj
    if not isinstance(obj, dict):
        return str(obj)[:300]
    parts = []
    for k, v in list(obj.items())[:n]:
        if isinstance(v, str):
            parts.append(f"{k}: {v}")
        elif isinstance(v, (int, float)):
            parts.append(f"{k}: {v}")
        elif isinstance(v, dict):
            sub = ", ".join(f"{sk}: {sv}" for sk, sv in list(v.items())[:3] if isinstance(sv, (str, int, float)))
            if sub:
                parts.append(f"{k}: {sub}")
        elif isinstance(v, list) and v and isinstance(v[0], str):
            parts.append(f"{k}: {', '.join(v[:4])}")
    return "\n".join(parts)


def _add_entries(db, data_dict, domain, subdomain_prefix, src_filter, stats, obligation="mandatory", conf=0.95):
    src = db.query(Source).filter(Source.title.contains(src_filter)).first() if src_filter else None
    sid = src.id if src else None
    for key, val in data_dict.items():
        code = f"{subdomain_prefix}_{key.upper()}"
        if not db.query(Entry).filter_by(entry_code=code).first():
            db.add(
                Entry(
                    entry_code=code,
                    source_id=sid,
                    domain=domain,
                    subdomain=key,
                    title=f"{subdomain_prefix} — {key}",
                    summary=_summ(val) if isinstance(val, dict) else str(val)[:500],
                    structured_json=_safe(val),
                    confidence_level=conf,
                    obligation_level=obligation,
                    status="approved",
                )
            )
            stats["entries"] += 1


def seed_all(db):
    stats = {"authorities": 0, "domains": 0, "sectors": 0, "sources": 0, "entries": 0, "rules": 0}

    # 1. Authorities
    for code, info in AUTHORITIES.items():
        if not db.query(Authority).filter_by(code=code).first():
            db.add(
                Authority(
                    code=code,
                    name_ar=info.get("name_ar", ""),
                    name_en=info.get("name_en", ""),
                    jurisdiction=info.get("jurisdiction", "sa"),
                    domain_scope=info.get("domain_scope", []),
                    official_urls=info.get("official_urls", []),
                    source_priority=info.get("source_priority", 5),
                    update_frequency=info.get("update_frequency"),
                    notes=info.get("note"),
                )
            )
            stats["authorities"] += 1

    # 2. Domains
    for code, info in DOMAINS.items():
        if not db.query(Domain).filter_by(code=code).first():
            db.add(Domain(code=code, name_ar=info.get("ar", ""), name_en=code, priority=info.get("priority", 5)))
            stats["domains"] += 1

    # 3. Sectors
    for code, info in SECTORS.items():
        if not db.query(Sector).filter_by(code=code).first():
            db.add(Sector(code=code, name_ar=info.get("ar", ""), name_en=code))
            stats["sectors"] += 1

    # 4. Sources
    SOURCES = [
        {
            "domain": "accounting",
            "title": "المعايير الدولية IFRS",
            "authority_code": "SOCPA",
            "source_type": "standard",
            "legal_force": "professional_standard",
        },
        {
            "domain": "tax",
            "subdomain": "zakat",
            "title": "نظام جباية الزكاة",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "vat",
            "title": "نظام ضريبة القيمة المضافة",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "income_tax",
            "title": "نظام ضريبة الدخل",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "withholding",
            "title": "ضريبة الاستقطاع",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "e_invoicing",
            "title": "نظام الفوترة الإلكترونية",
            "authority_code": "ZATCA",
            "source_type": "regulation",
            "legal_force": "implementing_regulation",
        },
        {
            "domain": "tax",
            "subdomain": "excise",
            "title": "نظام الضريبة الانتقائية",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "rett",
            "title": "ضريبة التصرفات العقارية",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "customs",
            "title": "نظام الجمارك الموحد",
            "authority_code": "ZATCA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "tax",
            "subdomain": "transfer_pricing",
            "title": "لائحة التسعير التحويلي",
            "authority_code": "ZATCA",
            "source_type": "regulation",
            "legal_force": "implementing_regulation",
        },
        {
            "domain": "governance",
            "title": "نظام الشركات 2022",
            "authority_code": "MOC",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "governance",
            "title": "لائحة حوكمة الشركات",
            "authority_code": "CMA",
            "source_type": "regulation",
            "legal_force": "implementing_regulation",
        },
        {
            "domain": "governance",
            "subdomain": "qawaem",
            "title": "منصة قوائم",
            "authority_code": "MOC",
            "source_type": "regulation",
            "legal_force": "implementing_regulation",
        },
        {
            "domain": "hr",
            "title": "نظام العمل السعودي",
            "authority_code": "HRSD",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "hr",
            "subdomain": "gosi",
            "title": "نظام التأمينات الاجتماعية",
            "authority_code": "GOSI",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "finance",
            "title": "لوائح البنك المركزي SAMA",
            "authority_code": "SAMA",
            "source_type": "regulation",
            "legal_force": "regulatory_instruction",
        },
        {
            "domain": "finance",
            "subdomain": "capital_market",
            "title": "لوائح هيئة السوق المالية",
            "authority_code": "CMA",
            "source_type": "regulation",
            "legal_force": "implementing_regulation",
        },
        {
            "domain": "investment",
            "title": "نظام الاستثمار",
            "authority_code": "MISA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "governance",
            "subdomain": "bankruptcy",
            "title": "نظام الإفلاس 2018",
            "authority_code": "BANKRUPTCY_COMMITTEE",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "governance",
            "subdomain": "competition",
            "title": "نظام المنافسة",
            "authority_code": "GAC",
            "source_type": "law",
            "legal_force": "binding_law",
        },
        {
            "domain": "operations",
            "subdomain": "data_protection",
            "title": "نظام حماية البيانات PDPL",
            "authority_code": "SDAIA",
            "source_type": "law",
            "legal_force": "binding_law",
        },
    ]
    for s in SOURCES:
        if not db.query(Source).filter_by(title=s["title"]).first():
            db.add(Source(**s, status="active"))
            stats["sources"] += 1
    db.flush()

    # 5. IFRS Entries (28 standards)
    ifrs_src = db.query(Source).filter(Source.title.contains("IFRS")).first()
    for std_key, std in IFRS.items():
        code = f"IFRS_{std_key}"
        if not db.query(Entry).filter_by(entry_code=code).first():
            title_ar = std.get("title_ar", std.get("title", std_key))
            db.add(
                Entry(
                    entry_code=code,
                    source_id=ifrs_src.id if ifrs_src else None,
                    domain="accounting",
                    subdomain=std_key,
                    title=f"{std_key} — {title_ar}",
                    summary=_summ(std),
                    structured_json=_safe(std),
                    confidence_level=0.95,
                    obligation_level="mandatory",
                    status="approved",
                )
            )
            stats["entries"] += 1

    # 6-16. All other entries
    _add_entries(db, ZATCA, "tax", "ZATCA", "ضريبة القيمة", stats)
    _add_entries(db, COMPANIES, "governance", "COMPANIES", "الشركات", stats)
    _add_entries(db, LABOR, "hr", "LABOR", "العمل", stats)
    _add_entries(db, GOSI, "hr", "GOSI", "التأمينات", stats)
    _add_entries(db, BANKING, "finance", "BANKING", "SAMA", stats, conf=0.90)
    _add_entries(db, CAPITAL_MARKET, "finance", "CMA", "السوق المالية", stats, conf=0.90)
    _add_entries(db, INVESTMENT, "investment", "INVEST", "الاستثمار", stats, obligation="recommended", conf=0.90)
    _add_entries(db, KB_SECTORS, "operations", "SECTOR", None, stats, obligation="recommended", conf=0.85)
    _add_entries(db, HR_MANAGEMENT, "hr", "HR_MGMT", "العمل", stats, obligation="recommended", conf=0.85)
    _add_entries(db, OPERATIONS, "operations", "OPS", None, stats, obligation="recommended", conf=0.85)
    _add_entries(db, MARKETING_SALES, "sales", "MKTG", None, stats, obligation="recommended", conf=0.80)
    _add_entries(db, ACCOUNTING_MGMT, "accounting", "ACCT_MGMT", "IFRS", stats, obligation="recommended", conf=0.85)

    # Single entries
    for code, data, domain, sub, title in [
        ("BANKRUPTCY_LAW", BANKRUPTCY, "governance", "bankruptcy", "نظام الإفلاس"),
        ("QAWAEM_FILING", QAWAEM, "governance", "qawaem", "منصة قوائم"),
        ("VISION_2030", VISION_2030, "market", "vision", "رؤية 2030"),
    ]:
        if not db.query(Entry).filter_by(entry_code=code).first():
            db.add(
                Entry(
                    entry_code=code,
                    domain=domain,
                    subdomain=sub,
                    title=title,
                    summary=_summ(data),
                    structured_json=_safe(data),
                    confidence_level=0.85,
                    obligation_level="recommended",
                    status="approved",
                )
            )
            stats["entries"] += 1

    # 17. Rules
    all_rules = {**TAX_RULES, **ACCOUNTING_RULES, **GOVERNANCE_RULES, **COMPLIANCE_RULES}
    for rc, rule in all_rules.items():
        if not db.query(Rule).filter_by(rule_code=rc).first():
            db.add(
                Rule(
                    rule_code=rc,
                    domain=rule.get("domain", ""),
                    rule_name_ar=rule.get("title", ""),
                    rule_name_en=rule.get("title", ""),
                    rule_type="compliance",
                    authority_code=rule.get("authority", ""),
                    reference=rule.get("reference", ""),
                    obligation_level=rule.get("obligation", "mandatory"),
                    active=True,
                )
            )
            stats["rules"] += 1

    db.commit()
    return stats
