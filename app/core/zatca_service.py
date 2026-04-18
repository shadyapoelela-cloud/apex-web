"""
APEX Platform — ZATCA Phase 2 (Fatoora) E-Invoice Service
═══════════════════════════════════════════════════════════════

Implements the SUBSET of ZATCA Phase 2 required to produce a
compliant simplified e-invoice payload with:

  1. UBL 2.1 XML skeleton   (the canonical invoice document)
  2. TLV Base64 QR payload  (the 5-field tag-length-value structure
                             for simplified invoices — seller name,
                             VAT number, timestamp, total with VAT,
                             VAT amount)
  3. Invoice hash           (SHA-256 of the canonical XML, base64)
  4. Previous-invoice-hash  (chained PIH for ICV continuity)
  5. ICV counter            (Invoice Counter Value, monotonically
                             increasing per seller; reuses
                             JournalEntrySequence for atomicity)

Out of scope here (requires the ZATCA onboarding CSID + production
CSID + XMLDSig over the full UBL):
  • Cryptographic signature using the onboarded certificate
  • Clearance + reporting API calls to ZATCA Fatoora
  • B2B (standard) invoice flow — this module focuses on B2C simplified.

When the user has an onboarded certificate, set ZATCA_CERT_PEM and
ZATCA_PRIVATE_KEY_PEM env vars; the production signer in zatca_signer.py
(separate task) will consume them.

References:
  • ZATCA e-invoicing Phase 2 specifications v5
  • UBL 2.1 invoice schema
  • TLV QR spec: https://zatca.gov.sa/en/E-Invoicing/Introduction/Guidelines
"""

from __future__ import annotations

import base64
import hashlib
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
from xml.sax.saxutils import escape as xml_escape

from app.core.compliance_service import next_journal_entry_number

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════
# Data classes
# ═══════════════════════════════════════════════════════════════


@dataclass
class ZatcaLineItem:
    """One line on the invoice."""
    name: str
    quantity: Decimal
    unit_price: Decimal              # excluding VAT
    vat_rate: Decimal = Decimal("15.00")   # KSA standard rate
    discount: Decimal = Decimal("0")       # absolute amount

    @property
    def line_net(self) -> Decimal:
        return _round2((self.quantity * self.unit_price) - self.discount)

    @property
    def line_vat(self) -> Decimal:
        return _round2(self.line_net * self.vat_rate / Decimal(100))

    @property
    def line_total(self) -> Decimal:
        return _round2(self.line_net + self.line_vat)


@dataclass
class ZatcaSeller:
    """Seller identity — required by ZATCA."""
    name: str                        # legal name (Arabic preferred)
    vat_number: str                  # 15-digit VAT registration
    cr_number: Optional[str] = None  # commercial registration
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    address_postal: Optional[str] = None
    country_code: str = "SA"


@dataclass
class ZatcaBuyer:
    """Buyer — optional for simplified B2C; required for standard B2B."""
    name: Optional[str] = None
    vat_number: Optional[str] = None
    address_street: Optional[str] = None
    address_city: Optional[str] = None
    country_code: str = "SA"


@dataclass
class ZatcaInvoice:
    """Full invoice context. All money is Decimal to avoid Float drift."""
    seller: ZatcaSeller
    buyer: Optional[ZatcaBuyer]
    issue_datetime: datetime
    invoice_number: str               # free-form human id, e.g. INV-2026-00001
    icv: int                          # Invoice Counter Value (monotonic)
    previous_invoice_hash: Optional[str]  # base64 of prev invoice hash
    lines: list[ZatcaLineItem]
    currency: str = "SAR"
    invoice_type: str = "SIMPLIFIED"  # SIMPLIFIED (B2C) or STANDARD (B2B)
    uuid: Optional[str] = None        # filled by service if omitted

    @property
    def subtotal(self) -> Decimal:
        return _round2(sum((l.line_net for l in self.lines), Decimal("0")))

    @property
    def total_vat(self) -> Decimal:
        return _round2(sum((l.line_vat for l in self.lines), Decimal("0")))

    @property
    def total(self) -> Decimal:
        return _round2(self.subtotal + self.total_vat)


@dataclass
class ZatcaResult:
    """Output package produced by build_simplified_invoice()."""
    uuid: str
    invoice_number: str
    icv: int
    xml: str                          # canonical UBL 2.1 XML
    invoice_hash_b64: str             # base64(sha256(xml))
    qr_b64: str                       # base64 of TLV payload
    totals: dict = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════


_TWO = Decimal("0.01")


def _round2(value: Decimal | int | float) -> Decimal:
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


_VAT_RE = re.compile(r"^\d{15}$")


def validate_vat_number(vat: str) -> bool:
    """KSA VAT registration numbers are exactly 15 digits, starting with 3
    and ending with 3 (per ZATCA spec)."""
    return bool(_VAT_RE.match(vat or "")) and vat[0] == "3" and vat[-1] == "3"


def _zulu(dt: datetime) -> str:
    """ZATCA requires ISO 8601 with 'Z' suffix (UTC)."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


# ═══════════════════════════════════════════════════════════════
# TLV QR Code (5 fields for simplified B2C invoices)
# Tag assignments per ZATCA spec:
#   1: seller name        (string, UTF-8)
#   2: VAT registration   (string, 15 digits)
#   3: invoice timestamp  (string, ISO 8601 w/ Z)
#   4: invoice total      (string, 2dp, incl VAT)
#   5: VAT total          (string, 2dp)
# ═══════════════════════════════════════════════════════════════


def _tlv(tag: int, value: str) -> bytes:
    payload = value.encode("utf-8")
    if len(payload) > 255:
        raise ValueError(f"TLV value for tag {tag} exceeds 255 bytes")
    return bytes([tag, len(payload)]) + payload


def build_tlv_qr(
    seller_name: str,
    vat_number: str,
    issue_datetime: datetime,
    total_with_vat: Decimal,
    vat_total: Decimal,
) -> str:
    """Return the base64-encoded TLV QR payload (5-field)."""
    parts = (
        _tlv(1, seller_name),
        _tlv(2, vat_number),
        _tlv(3, _zulu(issue_datetime)),
        _tlv(4, f"{_round2(total_with_vat):.2f}"),
        _tlv(5, f"{_round2(vat_total):.2f}"),
    )
    return base64.b64encode(b"".join(parts)).decode("ascii")


# ═══════════════════════════════════════════════════════════════
# UBL 2.1 XML (simplified — the fields ZATCA actually validates)
# ═══════════════════════════════════════════════════════════════


def build_ubl_xml(inv: ZatcaInvoice, pih_b64: Optional[str]) -> str:
    """Emit a canonical UBL 2.1 invoice XML. Deterministic — same input
    always yields the same string (important for hash stability)."""
    ns_cbc = "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
    ns_cac = "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
    ns_inv = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"

    s = inv.seller
    b = inv.buyer

    # Type code: 388 standard / simplified (with subtype tag)
    # InvoiceTypeCode @name='0100000' indicates B2C simplified
    name_attr = "0100000" if inv.invoice_type == "SIMPLIFIED" else "0200000"

    def _e(v: Optional[str]) -> str:
        return xml_escape(v or "", {'"': "&quot;", "'": "&apos;"})

    lines_xml = []
    for i, line in enumerate(inv.lines, start=1):
        lines_xml.append(
            f'  <cac:InvoiceLine>\n'
            f'    <cbc:ID>{i}</cbc:ID>\n'
            f'    <cbc:InvoicedQuantity unitCode="PCE">{line.quantity}</cbc:InvoicedQuantity>\n'
            f'    <cbc:LineExtensionAmount currencyID="{inv.currency}">{line.line_net:.2f}</cbc:LineExtensionAmount>\n'
            f'    <cac:TaxTotal>\n'
            f'      <cbc:TaxAmount currencyID="{inv.currency}">{line.line_vat:.2f}</cbc:TaxAmount>\n'
            f'      <cbc:RoundingAmount currencyID="{inv.currency}">{line.line_total:.2f}</cbc:RoundingAmount>\n'
            f'    </cac:TaxTotal>\n'
            f'    <cac:Item>\n'
            f'      <cbc:Name>{_e(line.name)}</cbc:Name>\n'
            f'      <cac:ClassifiedTaxCategory>\n'
            f'        <cbc:ID>S</cbc:ID>\n'
            f'        <cbc:Percent>{line.vat_rate:.2f}</cbc:Percent>\n'
            f'        <cac:TaxScheme>\n'
            f'          <cbc:ID>VAT</cbc:ID>\n'
            f'        </cac:TaxScheme>\n'
            f'      </cac:ClassifiedTaxCategory>\n'
            f'    </cac:Item>\n'
            f'    <cac:Price>\n'
            f'      <cbc:PriceAmount currencyID="{inv.currency}">{line.unit_price:.2f}</cbc:PriceAmount>\n'
            f'    </cac:Price>\n'
            f'  </cac:InvoiceLine>'
        )
    lines_block = "\n".join(lines_xml)

    buyer_block = ""
    if b is not None:
        buyer_vat_line = (
            '<cac:PartyIdentification><cbc:ID schemeID="VAT">'
            f'{_e(b.vat_number)}'
            '</cbc:ID></cac:PartyIdentification>'
            if b.vat_number else ''
        )
        buyer_block = (
            '  <cac:AccountingCustomerParty>\n'
            '    <cac:Party>\n'
            f'      {buyer_vat_line}\n'
            '      <cac:PartyName>\n'
            f'        <cbc:Name>{_e(b.name)}</cbc:Name>\n'
            '      </cac:PartyName>\n'
            '      <cac:PostalAddress>\n'
            f'        <cbc:StreetName>{_e(b.address_street)}</cbc:StreetName>\n'
            f'        <cbc:CityName>{_e(b.address_city)}</cbc:CityName>\n'
            '        <cac:Country>\n'
            f'          <cbc:IdentificationCode>{_e(b.country_code)}</cbc:IdentificationCode>\n'
            '        </cac:Country>\n'
            '      </cac:PostalAddress>\n'
            '    </cac:Party>\n'
            '  </cac:AccountingCustomerParty>'
        )

    pih_block = ""
    if pih_b64:
        pih_block = (
            f'  <cac:AdditionalDocumentReference>\n'
            f'    <cbc:ID>PIH</cbc:ID>\n'
            f'    <cac:Attachment>\n'
            f'      <cbc:EmbeddedDocumentBinaryObject mimeCode="text/plain">{pih_b64}</cbc:EmbeddedDocumentBinaryObject>\n'
            f'    </cac:Attachment>\n'
            f'  </cac:AdditionalDocumentReference>'
        )

    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<Invoice xmlns="{ns_inv}" xmlns:cac="{ns_cac}" xmlns:cbc="{ns_cbc}">\n'
        f'  <cbc:ProfileID>reporting:1.0</cbc:ProfileID>\n'
        f'  <cbc:ID>{_e(inv.invoice_number)}</cbc:ID>\n'
        f'  <cbc:UUID>{_e(inv.uuid or "")}</cbc:UUID>\n'
        f'  <cbc:IssueDate>{inv.issue_datetime.strftime("%Y-%m-%d")}</cbc:IssueDate>\n'
        f'  <cbc:IssueTime>{inv.issue_datetime.strftime("%H:%M:%S")}</cbc:IssueTime>\n'
        f'  <cbc:InvoiceTypeCode name="{name_attr}">388</cbc:InvoiceTypeCode>\n'
        f'  <cbc:DocumentCurrencyCode>{inv.currency}</cbc:DocumentCurrencyCode>\n'
        f'  <cbc:TaxCurrencyCode>{inv.currency}</cbc:TaxCurrencyCode>\n'
        f'  <cac:AdditionalDocumentReference>\n'
        f'    <cbc:ID>ICV</cbc:ID>\n'
        f'    <cbc:UUID>{inv.icv}</cbc:UUID>\n'
        f'  </cac:AdditionalDocumentReference>\n'
        f'{pih_block}\n'
        f'  <cac:AccountingSupplierParty>\n'
        f'    <cac:Party>\n'
        f'      <cac:PartyIdentification><cbc:ID schemeID="CRN">{_e(s.cr_number or "")}</cbc:ID></cac:PartyIdentification>\n'
        f'      <cac:PartyName>\n'
        f'        <cbc:Name>{_e(s.name)}</cbc:Name>\n'
        f'      </cac:PartyName>\n'
        f'      <cac:PostalAddress>\n'
        f'        <cbc:StreetName>{_e(s.address_street)}</cbc:StreetName>\n'
        f'        <cbc:CityName>{_e(s.address_city)}</cbc:CityName>\n'
        f'        <cbc:PostalZone>{_e(s.address_postal)}</cbc:PostalZone>\n'
        f'        <cac:Country>\n'
        f'          <cbc:IdentificationCode>{_e(s.country_code)}</cbc:IdentificationCode>\n'
        f'        </cac:Country>\n'
        f'      </cac:PostalAddress>\n'
        f'      <cac:PartyTaxScheme>\n'
        f'        <cbc:CompanyID>{_e(s.vat_number)}</cbc:CompanyID>\n'
        f'        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>\n'
        f'      </cac:PartyTaxScheme>\n'
        f'    </cac:Party>\n'
        f'  </cac:AccountingSupplierParty>\n'
        f'{buyer_block}\n'
        f'  <cac:TaxTotal>\n'
        f'    <cbc:TaxAmount currencyID="{inv.currency}">{inv.total_vat:.2f}</cbc:TaxAmount>\n'
        f'  </cac:TaxTotal>\n'
        f'  <cac:LegalMonetaryTotal>\n'
        f'    <cbc:LineExtensionAmount currencyID="{inv.currency}">{inv.subtotal:.2f}</cbc:LineExtensionAmount>\n'
        f'    <cbc:TaxExclusiveAmount currencyID="{inv.currency}">{inv.subtotal:.2f}</cbc:TaxExclusiveAmount>\n'
        f'    <cbc:TaxInclusiveAmount currencyID="{inv.currency}">{inv.total:.2f}</cbc:TaxInclusiveAmount>\n'
        f'    <cbc:PayableAmount currencyID="{inv.currency}">{inv.total:.2f}</cbc:PayableAmount>\n'
        f'  </cac:LegalMonetaryTotal>\n'
        f'{lines_block}\n'
        '</Invoice>\n'
    )
    return xml


# ═══════════════════════════════════════════════════════════════
# Public build function
# ═══════════════════════════════════════════════════════════════


def build_simplified_invoice(
    seller: ZatcaSeller,
    lines: list[ZatcaLineItem],
    *,
    client_id: str,
    fiscal_year: str,
    buyer: Optional[ZatcaBuyer] = None,
    invoice_number: Optional[str] = None,
    previous_invoice_hash_b64: Optional[str] = None,
    currency: str = "SAR",
    issue_datetime: Optional[datetime] = None,
    uuid_override: Optional[str] = None,
) -> ZatcaResult:
    """
    Produce a ZATCA-compliant simplified (B2C) e-invoice package.

    Validates VAT number format, allocates a gap-free ICV (Invoice Counter
    Value) via JournalEntrySequence with prefix "ICV", builds the UBL
    XML, hashes it, and produces the TLV QR payload.

    Raises ValueError on validation failure.
    """
    from uuid import uuid4

    warnings: list[str] = []

    # Validation
    if not validate_vat_number(seller.vat_number):
        raise ValueError(
            f"Invalid KSA VAT number: {seller.vat_number!r}. Expected 15 digits "
            f"starting and ending with '3'."
        )
    if not lines:
        raise ValueError("At least one invoice line is required.")
    for i, ln in enumerate(lines, 1):
        if ln.quantity <= 0:
            raise ValueError(f"Line {i}: quantity must be positive, got {ln.quantity}")
        if ln.unit_price < 0:
            raise ValueError(f"Line {i}: unit_price must be non-negative")

    # Allocate ICV atomically (re-using JE sequence table, prefix 'ICV')
    icv_alloc = next_journal_entry_number(client_id, fiscal_year, prefix="ICV")
    icv = icv_alloc["sequence"]
    final_invoice_number = invoice_number or icv_alloc["number"]

    inv = ZatcaInvoice(
        seller=seller,
        buyer=buyer,
        issue_datetime=issue_datetime or datetime.now(timezone.utc),
        invoice_number=final_invoice_number,
        icv=icv,
        previous_invoice_hash=previous_invoice_hash_b64,
        lines=lines,
        currency=currency,
        invoice_type="SIMPLIFIED",
        uuid=uuid_override or str(uuid4()),
    )

    # Sanity warnings
    if icv == 1 and previous_invoice_hash_b64:
        warnings.append("ICV=1 should have no previous invoice hash; ignored.")
    if icv > 1 and not previous_invoice_hash_b64:
        warnings.append(
            "ICV>1 without previous invoice hash breaks the PIH chain — "
            "supply the prior invoice's hash_b64."
        )

    xml = build_ubl_xml(inv, previous_invoice_hash_b64 if icv > 1 else None)
    xml_hash = hashlib.sha256(xml.encode("utf-8")).digest()
    invoice_hash_b64 = base64.b64encode(xml_hash).decode("ascii")

    qr_b64 = build_tlv_qr(
        seller_name=seller.name,
        vat_number=seller.vat_number,
        issue_datetime=inv.issue_datetime,
        total_with_vat=inv.total,
        vat_total=inv.total_vat,
    )

    return ZatcaResult(
        uuid=inv.uuid or "",
        invoice_number=final_invoice_number,
        icv=icv,
        xml=xml,
        invoice_hash_b64=invoice_hash_b64,
        qr_b64=qr_b64,
        totals={
            "subtotal": f"{inv.subtotal:.2f}",
            "vat_total": f"{inv.total_vat:.2f}",
            "total": f"{inv.total:.2f}",
            "currency": currency,
        },
        warnings=warnings,
    )
