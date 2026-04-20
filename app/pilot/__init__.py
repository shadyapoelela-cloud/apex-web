"""APEX Pilot Module — Multi-tenant retail ERP production runtime.

This module is the production backend for real customers.
Everything here assumes multi-tenancy: every row has tenant_id.

Structure:
  models/    — SQLAlchemy ORM models (Tenant, Entity, Product, ...)
  routes/    — FastAPI endpoints
  services/  — Business logic (not in routes)
  schemas/   — Pydantic request/response schemas
"""
