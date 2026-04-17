"""UAE FTA (Federal Tax Authority) integration.

Includes:
  • trn_validator.py     — Validate 15-digit Tax Registration Numbers.
  • corporate_tax.py     — Compute 9% Corporate Tax with AED 375K exemption,
                            Small Business Relief, and Qualifying Free Zone
                            Income rules.
  • vat_return.py        — Generate VAT 201 return in FTA format.
  • peppol_invoice.py    — (scaffold) Peppol BIS 3.0 compliant XML.
"""

from app.integrations.uae_fta.corporate_tax import (  # noqa: F401
    CorporateTaxInput,
    CorporateTaxResult,
    calculate_corporate_tax,
)
from app.integrations.uae_fta.trn_validator import (  # noqa: F401
    normalize_trn,
    validate_trn,
)

__all__ = [
    "CorporateTaxInput",
    "CorporateTaxResult",
    "calculate_corporate_tax",
    "normalize_trn",
    "validate_trn",
]
