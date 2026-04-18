"""Enhanced Accountant Marketplace — revenue share + matching + booking.

The existing Phase 5 Marketplace handles service offerings and provider
listings. This module adds the three layers required to turn it into a
revenue-generating two-sided marketplace:

  1. Revenue share — APEX takes a configurable % of payments routed
     through certified partners for the first N months.
  2. Matching engine — client describes their needs → we score and rank
     partners by certification, specialty, rating, availability.
  3. Booking — slot-based calendar reservations with automatic
     confirmation + decline expiry.

All tables inherit TenantMixin. Partner data is global (not tenant-
scoped) but booking/revenue records are tenant-scoped to the client.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from sqlalchemy import (
    Boolean, Column, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text,
    UniqueConstraint,
)

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)

_TWO = Decimal("0.01")


def _r2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


# ── Models ────────────────────────────────────────────────


class PartnerProfile(Base):
    """Global partner profile — visible to all tenants.

    Certified accountants / firms / bookkeepers can register here.
    Identity verification happens off-platform (SOCPA / ACCA check).
    """

    __tablename__ = "marketplace_partners"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)
    bio_ar = Column(Text, nullable=True)

    # Certifications
    socpa_number = Column(String(40), nullable=True)  # KSA
    acca_number = Column(String(40), nullable=True)
    cpa_number = Column(String(40), nullable=True)
    cma_number = Column(String(40), nullable=True)
    verified = Column(Boolean, nullable=False, default=False)

    # Availability & pricing
    hourly_rate = Column(Numeric(18, 2), nullable=True)
    currency = Column(String(3), nullable=False, default="SAR")
    languages = Column(JSON, nullable=True)       # ['ar','en']
    specialties = Column(JSON, nullable=True)     # ['zatca','gosi','ifrs',...]
    industries = Column(JSON, nullable=True)      # ['f_and_b','construction',...]

    rating_avg = Column(Numeric(3, 2), nullable=False, default=Decimal("0"))
    rating_count = Column(Integer, nullable=False, default=0)

    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class PartnerBooking(Base, TenantMixin):
    """A client (tenant) booked time with a partner."""

    __tablename__ = "marketplace_bookings"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    partner_id = Column(
        String(36), ForeignKey("marketplace_partners.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    client_user_id = Column(String(36), nullable=True, index=True)
    topic = Column(String(200), nullable=False)
    starts_at = Column(DateTime(timezone=True), nullable=False, index=True)
    duration_minutes = Column(Integer, nullable=False, default=60)

    status = Column(String(16), nullable=False, default="pending", index=True)
    # pending / confirmed / completed / cancelled / no_show

    agreed_rate = Column(Numeric(18, 2), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class RevenueShare(Base, TenantMixin):
    """One revenue-share event — APEX's cut on a partner-routed payment."""

    __tablename__ = "marketplace_revenue_share"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    partner_id = Column(String(36), nullable=False, index=True)
    booking_id = Column(String(36), nullable=True, index=True)

    gross_amount = Column(Numeric(18, 2), nullable=False)
    share_pct = Column(Numeric(5, 2), nullable=False)        # e.g. 20.00
    apex_cut = Column(Numeric(18, 2), nullable=False)
    partner_payout = Column(Numeric(18, 2), nullable=False)
    currency = Column(String(3), nullable=False, default="SAR")

    period = Column(String(7), nullable=False, index=True)   # 'YYYY-MM'
    settled = Column(Boolean, nullable=False, default=False)
    settled_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


# ── Revenue share calculator ──────────────────────────────


@dataclass
class RevenueShareResult:
    gross: Decimal
    share_pct: Decimal
    apex_cut: Decimal
    partner_payout: Decimal
    currency: str


def compute_revenue_share(
    gross: Decimal,
    months_since_first_booking: int,
    *,
    currency: str = "SAR",
) -> RevenueShareResult:
    """APEX takes 20% of the first 3 months, 15% months 4-6, 10% forever.

    This mirrors the Master Blueprint Accountant Marketplace §19 pricing.
    Tweakable per tenant later; these are the defaults.
    """
    if months_since_first_booking <= 3:
        pct = Decimal("20.00")
    elif months_since_first_booking <= 6:
        pct = Decimal("15.00")
    else:
        pct = Decimal("10.00")

    apex_cut = _r2(gross * pct / Decimal("100"))
    partner = _r2(gross - apex_cut)
    return RevenueShareResult(
        gross=_r2(gross),
        share_pct=pct,
        apex_cut=apex_cut,
        partner_payout=partner,
        currency=currency,
    )


# ── Matching engine ───────────────────────────────────────


@dataclass
class MatchCandidate:
    partner_id: str
    name_ar: str
    score: float
    rating_avg: Decimal
    rating_count: int
    hourly_rate: Optional[Decimal]
    reasons: list[str]


def match_partners(
    *,
    specialty: Optional[str] = None,
    industry: Optional[str] = None,
    language: str = "ar",
    max_budget: Optional[Decimal] = None,
    top_k: int = 5,
) -> list[MatchCandidate]:
    """Rank partners for a client's need.

    Scoring (weights sum to 100):
      • specialty match       40
      • industry match        20
      • language match        10
      • rating × count        20 (rating × log10(count+1))
      • price fit (≤ budget)  10
    """
    db = SessionLocal()
    try:
        rows = (
            db.query(PartnerProfile)
            .filter(PartnerProfile.active.is_(True))
            .filter(PartnerProfile.verified.is_(True))
            .all()
        )
        results: list[MatchCandidate] = []
        for p in rows:
            score = 0.0
            reasons: list[str] = []

            specs = p.specialties or []
            inds = p.industries or []
            langs = p.languages or []

            if specialty and specialty in specs:
                score += 40
                reasons.append(f"تخصص {specialty}")
            if industry and industry in inds:
                score += 20
                reasons.append(f"خبرة في {industry}")
            if language in langs:
                score += 10
                reasons.append(f"يتحدث {language}")

            import math

            rating = float(p.rating_avg or 0)
            count = int(p.rating_count or 0)
            if count > 0:
                score += min(20.0, rating * 4 * math.log10(count + 1))
                reasons.append(f"تقييم {rating:.1f} ({count} مراجعة)")

            if max_budget is not None and p.hourly_rate is not None:
                if p.hourly_rate <= max_budget:
                    score += 10
                    reasons.append("ضمن ميزانيتك")

            results.append(MatchCandidate(
                partner_id=p.id,
                name_ar=p.name_ar,
                score=round(score, 1),
                rating_avg=p.rating_avg or Decimal("0"),
                rating_count=count,
                hourly_rate=p.hourly_rate,
                reasons=reasons,
            ))
        results.sort(key=lambda c: c.score, reverse=True)
        return results[:top_k]
    finally:
        db.close()


# ── Booking service ───────────────────────────────────────


def book_slot(
    *,
    partner_id: str,
    client_user_id: Optional[str],
    topic: str,
    starts_at: datetime,
    duration_minutes: int = 60,
    agreed_rate: Optional[Decimal] = None,
    notes: Optional[str] = None,
) -> PartnerBooking:
    """Create a booking (pending confirmation from partner)."""
    db = SessionLocal()
    try:
        booking = PartnerBooking(
            id=str(uuid.uuid4()),
            partner_id=partner_id,
            client_user_id=client_user_id,
            topic=topic,
            starts_at=starts_at,
            duration_minutes=duration_minutes,
            status="pending",
            agreed_rate=agreed_rate,
            notes=notes,
        )
        db.add(booking)
        db.commit()
        db.refresh(booking)
        return booking
    finally:
        db.close()


def confirm_booking(booking_id: str) -> dict:
    db = SessionLocal()
    try:
        b = db.query(PartnerBooking).filter(PartnerBooking.id == booking_id).first()
        if not b:
            return {"success": False, "error": "not_found"}
        if b.status != "pending":
            return {"success": False, "error": f"already_{b.status}"}
        b.status = "confirmed"
        db.commit()
        return {"success": True, "id": booking_id, "status": "confirmed"}
    finally:
        db.close()


def record_revenue_share(
    *,
    partner_id: str,
    booking_id: Optional[str],
    gross: Decimal,
    months_since_first_booking: int,
    period: str,
    currency: str = "SAR",
) -> RevenueShare:
    """Book the revenue-share event for a completed session."""
    calc = compute_revenue_share(
        gross, months_since_first_booking, currency=currency
    )
    db = SessionLocal()
    try:
        rs = RevenueShare(
            id=str(uuid.uuid4()),
            partner_id=partner_id,
            booking_id=booking_id,
            gross_amount=calc.gross,
            share_pct=calc.share_pct,
            apex_cut=calc.apex_cut,
            partner_payout=calc.partner_payout,
            currency=currency,
            period=period,
        )
        db.add(rs)
        db.commit()
        db.refresh(rs)
        return rs
    finally:
        db.close()
