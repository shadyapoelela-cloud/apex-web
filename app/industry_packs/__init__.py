"""Industry Packs — pre-configured COA + workflows + reports per sector.

Each pack is a self-contained bundle loaded on tenant onboarding. The pack
provides:
  • Chart of Accounts template (industry-specific accounts)
  • Dashboard widget presets
  • Sample data (for 'Try with demo' onboarding button)
  • Industry-specific workflows (e.g., F&B tip-pooling, Construction WIP)

Packs available:
  • fnb_retail       — Restaurants, cafés, retail shops
  • construction     — Contracting, project accounting, retention
  • medical          — Clinics, patient billing, insurance claims
  • logistics        — Fleet, driver settlements, fuel cards
  • services         — Consulting, freelance, agencies (default for SaaS)
"""

from app.industry_packs.registry import (  # noqa: F401
    IndustryPack,
    get_pack,
    list_packs,
)

__all__ = ["IndustryPack", "get_pack", "list_packs"]
