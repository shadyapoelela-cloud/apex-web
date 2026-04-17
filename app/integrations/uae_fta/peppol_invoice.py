"""UAE FTA Peppol BIS Billing 3.0 e-invoice XML generator.

The UAE FTA mandated Peppol BIS 3.0 for B2B + B2G e-invoicing (phased
rollout from 2026 onward). This module produces the UBL 2.1 XML that
conforms to the BIS Billing 3.0 specification, with UAE-specific
customizations:
  • CustomizationID = urn:cen.eu:en16931:2017
                     #compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0
  • ProfileID = urn:fdc:peppol.eu:2017:poacc:billing:01:1.0
  • Document currency = AED by default.
  • TRN field is encoded as PartyTaxScheme > CompanyID with
    schemeID="0235" (UAE TRN scheme per Peppol EAS).

This is the generator side only — submission to the FTA Peppol Access
Point (e.g., Comarch, Pagero, Peppolnet) is done by a separate client
once an AP contract is signed.

Out of scope (production):
  • XAdES signature
  • Schematron validation
  • Credit note / debit note variants (easy extension)

References:
  - OpenPeppol BIS Billing 3.0 spec
  - UAE FTA e-invoicing guide v1.0 (2025)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
from xml.sax.saxutils import escape as xml_escape

_TWO = Decimal("0.01")


def _r2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class PeppolParty:
    """Seller or buyer party."""

    name: str
    trn: Optional[str] = None              # 15-digit TRN for UAE parties
    street: Optional[str] = None
    city: Optional[str] = None
    postal_code: Optional[str] = None
    country_code: str = "AE"


@dataclass
class PeppolLineItem:
    line_id: int                           # 1, 2, 3 ...
    description: str
    quantity: Decimal
    unit_price: Decimal                    # excluding VAT
    unit_code: str = "EA"                  # UBL code for "each"
    vat_rate: Decimal = Decimal("5.00")    # UAE standard VAT 5%
    vat_category: str = "S"                # S = Standard, Z = Zero, E = Exempt

    @property
    def line_net(self) -> Decimal:
        return _r2(self.quantity * self.unit_price)

    @property
    def line_vat(self) -> Decimal:
        return _r2(self.line_net * self.vat_rate / Decimal("100"))

    @property
    def line_total(self) -> Decimal:
        return _r2(self.line_net + self.line_vat)


@dataclass
class PeppolInvoice:
    invoice_number: str
    issue_date: date
    due_date: Optional[date]
    seller: PeppolParty
    buyer: PeppolParty
    lines: list[PeppolLineItem]
    currency: str = "AED"
    invoice_type_code: str = "380"         # 380 = Commercial invoice
    note: Optional[str] = None
    uuid: Optional[str] = None

    @property
    def subtotal(self) -> Decimal:
        return _r2(sum((l.line_net for l in self.lines), Decimal("0")))

    @property
    def vat_total(self) -> Decimal:
        return _r2(sum((l.line_vat for l in self.lines), Decimal("0")))

    @property
    def total(self) -> Decimal:
        return _r2(self.subtotal + self.vat_total)


# ── XML building blocks ────────────────────────────────────


def _party_xml(role: str, p: PeppolParty) -> str:
    """Render an AccountingSupplierParty / AccountingCustomerParty block."""
    street = xml_escape(p.street or "")
    city = xml_escape(p.city or "")
    postal = xml_escape(p.postal_code or "")
    country = xml_escape(p.country_code or "AE")
    name = xml_escape(p.name)
    trn_block = ""
    if p.trn:
        trn_block = f"""
      <cac:PartyTaxScheme>
        <cbc:CompanyID schemeID="0235">{xml_escape(p.trn)}</cbc:CompanyID>
        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
      </cac:PartyTaxScheme>"""
    return f"""
  <cac:Accounting{role}Party>
    <cac:Party>
      <cac:PartyName><cbc:Name>{name}</cbc:Name></cac:PartyName>
      <cac:PostalAddress>
        <cbc:StreetName>{street}</cbc:StreetName>
        <cbc:CityName>{city}</cbc:CityName>
        <cbc:PostalZone>{postal}</cbc:PostalZone>
        <cac:Country><cbc:IdentificationCode>{country}</cbc:IdentificationCode></cac:Country>
      </cac:PostalAddress>{trn_block}
      <cac:PartyLegalEntity><cbc:RegistrationName>{name}</cbc:RegistrationName></cac:PartyLegalEntity>
    </cac:Party>
  </cac:Accounting{role}Party>"""


def _lines_xml(lines: list[PeppolLineItem], currency: str) -> str:
    out: list[str] = []
    for line in lines:
        out.append(f"""
  <cac:InvoiceLine>
    <cbc:ID>{line.line_id}</cbc:ID>
    <cbc:InvoicedQuantity unitCode="{line.unit_code}">{line.quantity}</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount currencyID="{currency}">{line.line_net:.2f}</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Name>{xml_escape(line.description)}</cbc:Name>
      <cac:ClassifiedTaxCategory>
        <cbc:ID>{line.vat_category}</cbc:ID>
        <cbc:Percent>{line.vat_rate:.2f}</cbc:Percent>
        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
      </cac:ClassifiedTaxCategory>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount currencyID="{currency}">{line.unit_price:.2f}</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>""")
    return "".join(out)


def _tax_total_xml(invoice: PeppolInvoice) -> str:
    # Group lines by (rate, category) for TaxSubtotal entries.
    groups: dict[tuple[Decimal, str], tuple[Decimal, Decimal]] = {}
    for line in invoice.lines:
        key = (line.vat_rate, line.vat_category)
        net, vat = groups.get(key, (Decimal("0"), Decimal("0")))
        groups[key] = (net + line.line_net, vat + line.line_vat)

    subs = []
    for (rate, category), (net, vat) in sorted(groups.items()):
        subs.append(f"""
    <cac:TaxSubtotal>
      <cbc:TaxableAmount currencyID="{invoice.currency}">{_r2(net):.2f}</cbc:TaxableAmount>
      <cbc:TaxAmount currencyID="{invoice.currency}">{_r2(vat):.2f}</cbc:TaxAmount>
      <cac:TaxCategory>
        <cbc:ID>{category}</cbc:ID>
        <cbc:Percent>{rate:.2f}</cbc:Percent>
        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
      </cac:TaxCategory>
    </cac:TaxSubtotal>""")

    return f"""
  <cac:TaxTotal>
    <cbc:TaxAmount currencyID="{invoice.currency}">{invoice.vat_total:.2f}</cbc:TaxAmount>{''.join(subs)}
  </cac:TaxTotal>"""


def generate_peppol_xml(invoice: PeppolInvoice) -> str:
    """Produce the full BIS Billing 3.0 Invoice XML as a UTF-8 string."""
    due_line = (
        f"\n  <cbc:DueDate>{invoice.due_date.isoformat()}</cbc:DueDate>"
        if invoice.due_date
        else ""
    )
    note_line = (
        f"\n  <cbc:Note>{xml_escape(invoice.note)}</cbc:Note>"
        if invoice.note
        else ""
    )
    uuid_line = (
        f"\n  <cbc:UUID>{xml_escape(invoice.uuid)}</cbc:UUID>"
        if invoice.uuid
        else ""
    )

    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>
  <cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>
  <cbc:ID>{xml_escape(invoice.invoice_number)}</cbc:ID>{uuid_line}
  <cbc:IssueDate>{invoice.issue_date.isoformat()}</cbc:IssueDate>{due_line}
  <cbc:InvoiceTypeCode>{invoice.invoice_type_code}</cbc:InvoiceTypeCode>{note_line}
  <cbc:DocumentCurrencyCode>{invoice.currency}</cbc:DocumentCurrencyCode>
  <cbc:TaxCurrencyCode>{invoice.currency}</cbc:TaxCurrencyCode>
{_party_xml("Supplier", invoice.seller)}
{_party_xml("Customer", invoice.buyer)}
{_tax_total_xml(invoice)}
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="{invoice.currency}">{invoice.subtotal:.2f}</cbc:LineExtensionAmount>
    <cbc:TaxExclusiveAmount currencyID="{invoice.currency}">{invoice.subtotal:.2f}</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="{invoice.currency}">{invoice.total:.2f}</cbc:TaxInclusiveAmount>
    <cbc:PayableAmount currencyID="{invoice.currency}">{invoice.total:.2f}</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>{_lines_xml(invoice.lines, invoice.currency)}
</Invoice>
"""
    return xml
