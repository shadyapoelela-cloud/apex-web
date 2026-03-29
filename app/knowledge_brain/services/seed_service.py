"""
Knowledge Brain Seed Service — تعبئة القاعدة بالبيانات الأولية
═══════════════════════════════════════════════════════════════

يأخذ البيانات من:
- authority_registry.py → authorities table
- saudi_knowledge_base.py → sources + entries tables
- rulebooks/*.py → rules table
- DOMAINS + SECTORS → domains + sectors tables
"""

from app.knowledge_brain.models.db_models import *
from app.knowledge_brain.data.authorities.authority_registry import AUTHORITIES, LEGAL_FORCE
from app.knowledge_brain.models.core_models import DOMAINS, SECTORS
from app.knowledge_brain.rulebooks.tax_rulebook import TAX_RULES
from app.knowledge_brain.rulebooks.accounting_rulebook import ACCOUNTING_RULES
from app.knowledge_brain.rulebooks.governance_rulebook import GOVERNANCE_RULES
from app.knowledge_brain.rulebooks.compliance_rulebook import COMPLIANCE_RULES


def seed_all(db):
    """Seed all tables with initial knowledge data."""
    stats = {"authorities": 0, "domains": 0, "sectors": 0, "sources": 0, "entries": 0, "rules": 0}

    # 1. Authorities
    for code, info in AUTHORITIES.items():
        if not db.query(Authority).filter_by(code=code).first():
            db.add(Authority(
                code=code,
                name_ar=info.get("name_ar", ""),
                name_en=info.get("name_en", ""),
                jurisdiction=info.get("jurisdiction", "sa"),
                domain_scope=info.get("domain_scope", []),
                official_urls=info.get("official_urls", []),
                source_priority=info.get("source_priority", 5),
                update_frequency=info.get("update_frequency"),
                notes=info.get("note"),
            ))
            stats["authorities"] += 1

    # 2. Domains
    for code, info in DOMAINS.items():
        if not db.query(Domain).filter_by(code=code).first():
            db.add(Domain(
                code=code,
                name_ar=info.get("ar", ""),
                name_en=code,
                priority=info.get("priority", 5),
            ))
            stats["domains"] += 1

    # 3. Sectors
    for code, info in SECTORS.items():
        if not db.query(Sector).filter_by(code=code).first():
            db.add(Sector(
                code=code,
                name_ar=info.get("ar", ""),
                name_en=code,
            ))
            stats["sectors"] += 1

    # 4. Sources (from knowledge base sections)
    SOURCES_SEED = [
        {"domain": "accounting", "title": "International Financial Reporting Standards (IFRS)", "authority_code": "SOCPA", "source_type": "standard", "legal_force": "professional_standard", "official_reference": "IFRS 1-16 + IAS 1-40", "status": "active"},
        {"domain": "tax", "subdomain": "zakat", "title": "Zakat Collection System", "authority_code": "ZATCA", "source_type": "law", "legal_force": "binding_law", "official_reference": "Royal Decree 17/2/28/8634", "status": "active"},
        {"domain": "tax", "subdomain": "vat", "title": "VAT Law and Implementing Regulation", "authority_code": "ZATCA", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "tax", "subdomain": "income_tax", "title": "Income Tax Law", "authority_code": "ZATCA", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "tax", "subdomain": "e_invoicing", "title": "E-Invoicing Regulation (FATOORAH)", "authority_code": "ZATCA", "source_type": "regulation", "legal_force": "implementing_regulation", "status": "active"},
        {"domain": "governance", "title": "Companies Law 2022", "authority_code": "MOC", "source_type": "law", "legal_force": "binding_law", "official_reference": "Royal Decree M/132", "status": "active"},
        {"domain": "governance", "title": "CMA Corporate Governance Regulations", "authority_code": "CMA", "source_type": "regulation", "legal_force": "implementing_regulation", "status": "active"},
        {"domain": "hr", "title": "Saudi Labor Law", "authority_code": "HRSD", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "hr", "title": "Social Insurance Law (GOSI)", "authority_code": "GOSI", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "finance", "title": "SAMA Banking Regulations", "authority_code": "SAMA", "source_type": "regulation", "legal_force": "regulatory_instruction", "status": "active"},
        {"domain": "investment", "title": "Investment Law and MISA Regulations", "authority_code": "MISA", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "governance", "title": "Bankruptcy Law 2018", "authority_code": "BANKRUPTCY_COMMITTEE", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "governance", "subdomain": "qawaem", "title": "Qawaem Financial Statements Filing Platform", "authority_code": "MOC", "source_type": "regulation", "legal_force": "implementing_regulation", "status": "active"},
        {"domain": "operations", "subdomain": "data_protection", "title": "Personal Data Protection Law (PDPL)", "authority_code": "SDAIA", "source_type": "law", "legal_force": "binding_law", "status": "active"},
        {"domain": "operations", "subdomain": "competition", "title": "Competition Law", "authority_code": "GAC", "source_type": "law", "legal_force": "binding_law", "status": "active"},
    ]

    for s in SOURCES_SEED:
        if not db.query(Source).filter_by(title=s["title"]).first():
            db.add(Source(**s))
            stats["sources"] += 1

    # 5. Rules (from existing rulebooks)
    all_rules = {**TAX_RULES, **ACCOUNTING_RULES, **GOVERNANCE_RULES, **COMPLIANCE_RULES}
    for rule_code, rule in all_rules.items():
        if not db.query(Rule).filter_by(rule_code=rule_code).first():
            db.add(Rule(
                rule_code=rule_code,
                domain=rule.get("domain", ""),
                rule_name_ar=rule.get("title", ""),
                rule_name_en=rule.get("title", ""),
                rule_type="compliance",
                authority_code=rule.get("authority", ""),
                reference=rule.get("reference", ""),
                obligation_level=rule.get("obligation", "mandatory"),
                active=True,
            ))
            stats["rules"] += 1

    db.commit()
    return stats
