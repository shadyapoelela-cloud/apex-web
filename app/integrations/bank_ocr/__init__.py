"""Arabic-aware bank statement OCR + auto-reconciliation.

Supported banks:
  KSA:  Al Rajhi, SNB (Saudi National Bank), Riyad, Albilad
  UAE:  Emirates NBD, FAB, ADCB, Mashreq

Supported file formats:
  PDF        → pdfplumber / Claude Vision (for scanned statements)
  Excel      → openpyxl
  MT940      → SWIFT message parser
  camt.053   → ISO 20022 XML parser

Output: normalized list of BankTransaction records suitable for the
4-layer matching engine in matcher.py.

This package is the engine — the UI (Flutter drag-drop reconciliation) and
the REST routes sit on top.
"""

from app.integrations.bank_ocr.matcher import (  # noqa: F401
    MatchCandidate,
    MatchEngine,
    MatchScore,
)
from app.integrations.bank_ocr.parsers import (  # noqa: F401
    BankTransaction,
    ParsedStatement,
    detect_format,
    parse_statement,
)

__all__ = [
    "BankTransaction",
    "ParsedStatement",
    "MatchCandidate",
    "MatchEngine",
    "MatchScore",
    "detect_format",
    "parse_statement",
]
