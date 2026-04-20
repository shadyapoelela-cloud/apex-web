"""Currency + FX Rate models.

A tenant's base currency is set in CompanySettings.base_currency.
Each Entity operates in its own functional_currency (usually the local currency
of its country). FX rates translate between currencies for consolidation.

FX rate source can be:
  - SAMA (Saudi Central Bank) — preferred for SAR pairs
  - CBUAE (UAE Central Bank) — for AED pairs
  - Manual entry (for monthly closing rates)
  - API (Open Exchange Rates / Fixer / ECB)
"""

from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Numeric, UniqueConstraint, Index, Date
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class Currency(Base):
    """ISO-4217 currencies enabled per tenant."""
    __tablename__ = "pilot_currencies"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(3), nullable=False)  # SAR, AED, QAR, KWD, BHD, EGP, USD, EUR, ...
    name_ar = Column(String(100), nullable=False)  # ريال سعودي
    name_en = Column(String(100), nullable=False)  # Saudi Riyal
    symbol = Column(String(10), nullable=True)     # ر.س ، د.إ ، د.ك
    decimal_places = Column(Integer, nullable=False, default=2)  # 2 for most, 3 for KWD/BHD
    is_active = Column(Boolean, nullable=False, default=True)
    is_base_currency = Column(Boolean, nullable=False, default=False)  # per-tenant

    # Display
    sort_order = Column(Integer, nullable=False, default=0)
    emoji_flag = Column(String(10), nullable=True)  # 🇸🇦 🇦🇪 🇶🇦 ...

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_currency_tenant_code"),
        Index("ix_pilot_currencies_tenant_active", "tenant_id", "is_active"),
    )


class FxRate(Base):
    """Historical FX rates between two currencies for a tenant.

    Rate represents: 1 unit of `from_currency` = `rate` units of `to_currency`.
    Example: from=SAR, to=USD, rate=0.267 means 1 SAR = 0.267 USD.

    For accounting, we need daily rates for transactions and
    monthly averages / closing rates for financial statements.
    """
    __tablename__ = "pilot_fx_rates"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    from_currency = Column(String(3), nullable=False)
    to_currency = Column(String(3), nullable=False)
    rate = Column(Numeric(18, 8), nullable=False)  # 8 decimal places for precision

    # Rate type — different rates used for different purposes
    # spot  — daily transactional rate
    # avg_month — monthly average (for P&L items)
    # closing — end-of-period (for balance sheet)
    # historical — transaction date rate (for historical P&L)
    rate_type = Column(String(20), nullable=False, default="spot")

    effective_date = Column(Date, nullable=False, index=True)

    # Source provenance
    source = Column(String(50), nullable=False, default="manual")  # manual | sama | cbuae | oxr | fixer
    source_reference = Column(String(255), nullable=True)  # API response ID or doc number

    # Who set it (for audit)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)

    __table_args__ = (
        UniqueConstraint("tenant_id", "from_currency", "to_currency", "rate_type", "effective_date",
                         name="uq_pilot_fx_rate_unique"),
        Index("ix_pilot_fx_rates_tenant_date", "tenant_id", "effective_date"),
        Index("ix_pilot_fx_rates_pair_date", "from_currency", "to_currency", "effective_date"),
    )
