"""
APEX Platform - Core Tests
Tests for critical paths: models, services, APIs
"""

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_imports():
    print("Test 1: Imports...")
    from app.phase1.models.platform_models import User, Base, engine, SessionLocal
    from app.phase2.models.phase2_models import Client, ClientTypeRef
    from app.phase2.models.onboarding_models import LegalEntityType, SectorMain, SectorSub, StageNote
    from app.phase2.models.archive_models import ArchiveItem, ArchivePolicy
    from app.phase2.models.service_catalog_models import ServiceCatalog, AuditWorkpaper
    print("  PASS: All models import successfully")

def test_seed_data():
    print("Test 2: Seed data...")
    from app.phase2.services.seed_onboarding import get_legal_entity_types, get_sector_main, get_sector_sub, get_stage_notes
    assert len(get_legal_entity_types()) == 13, "Expected 13 entity types"
    assert len(get_sector_main()) == 14, "Expected 14 main sectors"
    assert len(get_sector_sub()) >= 18, "Expected 18+ sub sectors"
    assert len(get_stage_notes()) >= 9, "Expected 9+ stage notes"
    print("  PASS: Seed data counts correct")

def test_enums():
    print("Test 3: Enums...")
    from app.phase2.models.phase2_models import ClientType, KNOWLEDGE_MODE_ELIGIBLE_TYPES
    assert "accounting_firm" in KNOWLEDGE_MODE_ELIGIBLE_TYPES
    assert "audit_firm" in KNOWLEDGE_MODE_ELIGIBLE_TYPES
    assert "standard_business" not in KNOWLEDGE_MODE_ELIGIBLE_TYPES
    print("  PASS: Knowledge mode eligibility correct")

def test_user_fields():
    print("Test 4: User model fields...")
    from app.phase1.models.platform_models import User
    cols = [c.name for c in User.__table__.columns]
    assert "auth_provider" in cols, "Missing auth_provider"
    assert "mobile_country_code" in cols, "Missing mobile_country_code"
    assert "mobile_number" in cols, "Missing mobile_number"
    print("  PASS: User has social auth + mobile fields")

def test_client_fields():
    print("Test 5: Client model fields...")
    from app.phase2.models.phase2_models import Client
    cols = [c.name for c in Client.__table__.columns]
    assert "legal_entity_type" in cols, "Missing legal_entity_type"
    assert "sector_main_code" in cols, "Missing sector_main_code"
    assert "sector_sub_code" in cols, "Missing sector_sub_code"
    assert "registration_status" in cols, "Missing registration_status"
    assert "onboarding_step" in cols, "Missing onboarding_step"
    print("  PASS: Client has onboarding fields")

def test_table_names():
    print("Test 6: New tables exist in metadata...")
    from app.phase1.models.platform_models import Base
    # Import all models to register them
    from app.phase2.models.onboarding_models import LegalEntityType, SectorMain, SectorSub
    from app.phase2.models.archive_models import ArchiveItem
    from app.phase2.models.service_catalog_models import ServiceCatalog, AuditWorkpaper
    tables = Base.metadata.tables.keys()
    required = ["legal_entity_types", "sector_main", "sector_sub", "stage_notes",
                "client_required_documents", "client_onboarding_drafts",
                "archive_items", "archive_links", "archive_policies",
                "service_catalog", "service_workflow_stages", "service_cases",
                "audit_program_templates", "audit_samples", "audit_workpapers", "audit_findings"]
    missing = [t for t in required if t not in tables]
    assert not missing, f"Missing tables: {missing}"
    print(f"  PASS: All 17 new tables registered ({len(required)} checked)")

def test_routes_exist():
    print("Test 7: Route files exist...")
    routes = [
        "app/phase1/routes/social_auth_routes.py",
        "app/phase2/routes/onboarding_routes.py",
        "app/phase2/routes/archive_routes.py",
        "app/phase2/routes/service_catalog_routes.py",
    ]
    for r in routes:
        assert os.path.exists(r), f"Missing: {r}"
    print("  PASS: All new route files exist")

def test_flutter_files():
    print("Test 8: Flutter files exist...")
    files = [
        "apex_finance/lib/main.dart",
        "apex_finance/lib/core/router.dart",
        "apex_finance/lib/core/theme.dart",
        "apex_finance/lib/widgets/auth_widgets.dart",
        "apex_finance/lib/screens/clients/client_onboarding_wizard.dart",
        "apex_finance/lib/screens/marketplace/service_catalog_screen.dart",
        "apex_finance/lib/screens/account/archive_screen.dart",
        "apex_finance/lib/screens/tasks/audit_service_screen.dart",
    ]
    for f in files:
        assert os.path.exists(f), f"Missing: {f}"
    print("  PASS: All critical Flutter files exist")


if __name__ == "__main__":
    print("=" * 50)
    print("APEX PLATFORM - CORE TESTS")
    print("=" * 50)
    tests = [test_imports, test_seed_data, test_enums, test_user_fields,
             test_client_fields, test_table_names, test_routes_exist, test_flutter_files]
    passed = 0
    failed = 0
    for t in tests:
        try:
            t()
            passed += 1
        except Exception as e:
            print(f"  FAIL: {e}")
            failed += 1
    print("=" * 50)
    print(f"Results: {passed} passed, {failed} failed, {len(tests)} total")
    print("=" * 50)
