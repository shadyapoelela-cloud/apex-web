"""Autonomous AP (Accounts Payable) Agent — Q2 killer feature.

Pipeline for every inbound vendor invoice:
  1. Ingest   — receive via email (ap@client.apex.sa) or WhatsApp.
  2. OCR      — Claude Vision extracts vendor, amount, VAT, IBAN, due_date.
  3. Vendor match — fuzzy match against vendor master; auto-create if new.
  4. 3-way match — PO + Goods Receipt + Invoice (qty + price tolerance).
  5. GL code   — COA Engine v4.3 suggests account + category.
  6. Approval  — policy-based routing (under X: auto, X-Y: manager, >Y: CFO).
  7. Schedule  — payment date based on due_date + cash-flow forecast.
  8. Execute   — via bank API (Open Banking) or manual approval screen.

State machine::

    received -> ocr_done -> coded -> awaiting_approval -> approved -> scheduled -> paid
                                                      \\-> rejected (terminal)

This scaffold establishes the models + pipeline skeleton. The actual
pipeline steps are orchestrated by the state machine in `pipeline.py`
which dispatches to pluggable processors — each can be implemented
independently.
"""

from app.features.ap_agent.models import (  # noqa: F401
    APInvoice,
    APInvoiceStatus,
    APLineItem,
)
from app.features.ap_agent.pipeline import (  # noqa: F401
    APPipeline,
    APProcessorResult,
)

__all__ = [
    "APInvoice",
    "APInvoiceStatus",
    "APLineItem",
    "APPipeline",
    "APProcessorResult",
]
