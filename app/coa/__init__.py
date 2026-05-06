"""Canonical Chart of Accounts module (CoA-1, Sprint 17).

Cross-tenant CRUD surface for hierarchical charts of accounts. See
`app/coa/README.md` for the architecture overview, and
`app/coa/GAP_ANALYSIS.md` for why this lives separately from
`app/coa_engine/` (upload-and-classify) and `app/pilot/models/gl.py`
(pilot ERP runtime table).

Public surface:
    from app.coa.models import ChartOfAccount, AccountTemplate, AccountChangeLog
    from app.coa.router import router
"""

from __future__ import annotations
