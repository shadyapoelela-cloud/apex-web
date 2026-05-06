"""invoicing_credit_notes_recurring_attachments

INV-1, Sprint 18 — adds 4 tables for the invoicing orchestration layer:

    credit_notes                   — credit / debit notes (ZATCA-aware)
    credit_note_lines              — line items
    recurring_invoice_templates    — periodic invoice schedules
    invoice_attachments            — file attachments for any invoice type

Hand-written, idempotent — same pattern as `h2c5e8f1a4b7` (DASH-1
hotfix) and `i3d9f6c2e8a5` (CoA-1). Every `op.create_table` is gated
on `inspect().has_table(...)` so the migration survives the
`create_all() → alembic-stamp` transition.

Revision ID: j7e2c8d4f9b1
Revises: i3d9f6c2e8a5
Create Date: 2026-05-06
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect


revision: str = "j7e2c8d4f9b1"
down_revision: Union[str, None] = "i3d9f6c2e8a5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(name: str) -> bool:
    return inspect(op.get_bind()).has_table(name)


def _index_exists(table: str, name: str) -> bool:
    try:
        existing = {ix["name"] for ix in inspect(op.get_bind()).get_indexes(table)}
    except Exception:  # noqa: BLE001
        return False
    return name in existing


# ── Upgrade ──────────────────────────────────────────────


def upgrade() -> None:
    # ── credit_notes ────────────────────────────────────
    if not _table_exists("credit_notes"):
        op.create_table(
            "credit_notes",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("tenant_id", sa.String(length=36), nullable=True),
            sa.Column("entity_id", sa.String(length=36), nullable=False),
            sa.Column("cn_type", sa.String(length=20), nullable=False),
            sa.Column("cn_number", sa.String(length=40), nullable=False),
            sa.Column("issue_date", sa.Date(), nullable=False),
            sa.Column("original_invoice_id", sa.String(length=36), nullable=True),
            sa.Column("original_invoice_type", sa.String(length=20), nullable=True),
            sa.Column("original_invoice_number", sa.String(length=50), nullable=True),
            sa.Column("customer_id", sa.String(length=36), nullable=True),
            sa.Column("vendor_id", sa.String(length=36), nullable=True),
            sa.Column("subtotal", sa.Numeric(20, 2), nullable=False),
            sa.Column("tax_total", sa.Numeric(20, 2), nullable=False),
            sa.Column("grand_total", sa.Numeric(20, 2), nullable=False),
            sa.Column("currency_code", sa.String(length=3), nullable=False),
            sa.Column("reason_code", sa.String(length=40), nullable=False),
            sa.Column("reason_text", sa.String(length=400), nullable=True),
            sa.Column("status", sa.String(length=20), nullable=False),
            sa.Column("applied_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("applied_amount", sa.Numeric(20, 2), nullable=False),
            sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("journal_entry_id", sa.String(length=36), nullable=True),
            sa.Column("zatca_uuid", sa.String(length=36), nullable=True),
            sa.Column("zatca_qr", sa.Text(), nullable=True),
            sa.Column("zatca_status", sa.String(length=20), nullable=True),
            sa.Column("notes", sa.String(length=800), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_by", sa.String(length=36), nullable=True),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint(
                "tenant_id", "entity_id", "cn_number", name="uq_cn_number"
            ),
        )
    for ix_name, cols in (
        ("ix_cn_original", ["original_invoice_id"]),
        ("ix_cn_status", ["status"]),
        ("ix_cn_customer", ["customer_id"]),
        ("ix_cn_vendor", ["vendor_id"]),
        ("ix_cn_issue_date", ["issue_date"]),
    ):
        if not _index_exists("credit_notes", ix_name):
            op.create_index(ix_name, "credit_notes", cols, unique=False)
    if not _index_exists("credit_notes", "ix_credit_notes_tenant_id"):
        op.create_index(
            op.f("ix_credit_notes_tenant_id"),
            "credit_notes",
            ["tenant_id"],
            unique=False,
        )
    if not _index_exists("credit_notes", "ix_credit_notes_entity_id"):
        op.create_index(
            op.f("ix_credit_notes_entity_id"),
            "credit_notes",
            ["entity_id"],
            unique=False,
        )

    # ── credit_note_lines ───────────────────────────────
    if not _table_exists("credit_note_lines"):
        op.create_table(
            "credit_note_lines",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("cn_id", sa.String(length=36), nullable=False),
            sa.Column("line_no", sa.Integer(), nullable=False),
            sa.Column("description", sa.String(length=400), nullable=False),
            sa.Column("quantity", sa.Numeric(14, 4), nullable=False),
            sa.Column("unit_price", sa.Numeric(18, 4), nullable=False),
            sa.Column("line_total", sa.Numeric(18, 2), nullable=False),
            sa.Column("tax_rate", sa.String(length=20), nullable=True),
            sa.Column("tax_amount", sa.Numeric(18, 2), nullable=False),
            sa.Column("account_id", sa.String(length=36), nullable=True),
            sa.ForeignKeyConstraint(
                ["cn_id"], ["credit_notes.id"], ondelete="CASCADE"
            ),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("cn_id", "line_no", name="uq_cn_line_no"),
        )
    if not _index_exists("credit_note_lines", "ix_cn_line_cn"):
        op.create_index(
            "ix_cn_line_cn", "credit_note_lines", ["cn_id"], unique=False
        )

    # ── recurring_invoice_templates ─────────────────────
    if not _table_exists("recurring_invoice_templates"):
        op.create_table(
            "recurring_invoice_templates",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("tenant_id", sa.String(length=36), nullable=True),
            sa.Column("entity_id", sa.String(length=36), nullable=False),
            sa.Column("template_name", sa.String(length=160), nullable=False),
            sa.Column("invoice_type", sa.String(length=20), nullable=False),
            sa.Column("customer_id", sa.String(length=36), nullable=True),
            sa.Column("vendor_id", sa.String(length=36), nullable=True),
            sa.Column("frequency", sa.String(length=20), nullable=False),
            sa.Column("interval_n", sa.Integer(), nullable=False),
            sa.Column("start_date", sa.Date(), nullable=False),
            sa.Column("end_date", sa.Date(), nullable=True),
            sa.Column("next_run_date", sa.Date(), nullable=False),
            sa.Column("runs_count", sa.Integer(), nullable=False),
            sa.Column("max_runs", sa.Integer(), nullable=True),
            sa.Column("lines_json", sa.JSON(), nullable=False),
            sa.Column("notes", sa.String(length=800), nullable=True),
            sa.Column("currency_code", sa.String(length=3), nullable=False),
            sa.Column("auto_issue", sa.Boolean(), nullable=False),
            sa.Column("auto_send_email", sa.Boolean(), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.Column("last_run_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("last_invoice_id", sa.String(length=36), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_by", sa.String(length=36), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
    for ix_name, cols in (
        ("ix_recurring_next_run", ["next_run_date", "is_active"]),
        ("ix_recurring_entity", ["entity_id"]),
    ):
        if not _index_exists("recurring_invoice_templates", ix_name):
            op.create_index(
                ix_name, "recurring_invoice_templates", cols, unique=False
            )
    if not _index_exists(
        "recurring_invoice_templates", "ix_recurring_invoice_templates_tenant_id"
    ):
        op.create_index(
            op.f("ix_recurring_invoice_templates_tenant_id"),
            "recurring_invoice_templates",
            ["tenant_id"],
            unique=False,
        )

    # ── invoice_attachments ─────────────────────────────
    if not _table_exists("invoice_attachments"):
        op.create_table(
            "invoice_attachments",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("tenant_id", sa.String(length=36), nullable=True),
            sa.Column("invoice_id", sa.String(length=36), nullable=False),
            sa.Column("invoice_type", sa.String(length=20), nullable=False),
            sa.Column("filename", sa.String(length=200), nullable=False),
            sa.Column("file_size", sa.Integer(), nullable=False),
            sa.Column("mime_type", sa.String(length=80), nullable=False),
            sa.Column("storage_key", sa.String(length=400), nullable=False),
            sa.Column("uploaded_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("uploaded_by", sa.String(length=36), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
    for ix_name, cols in (
        ("ix_attachment_invoice", ["invoice_id", "invoice_type"]),
        ("ix_attachment_uploaded_at", ["uploaded_at"]),
    ):
        if not _index_exists("invoice_attachments", ix_name):
            op.create_index(
                ix_name, "invoice_attachments", cols, unique=False
            )
    if not _index_exists("invoice_attachments", "ix_invoice_attachments_tenant_id"):
        op.create_index(
            op.f("ix_invoice_attachments_tenant_id"),
            "invoice_attachments",
            ["tenant_id"],
            unique=False,
        )


# ── Downgrade ────────────────────────────────────────────


def downgrade() -> None:
    if _table_exists("invoice_attachments"):
        for ix in (
            "ix_invoice_attachments_tenant_id",
            "ix_attachment_uploaded_at",
            "ix_attachment_invoice",
        ):
            if _index_exists("invoice_attachments", ix):
                op.drop_index(ix, table_name="invoice_attachments")
        op.drop_table("invoice_attachments")

    if _table_exists("recurring_invoice_templates"):
        for ix in (
            "ix_recurring_invoice_templates_tenant_id",
            "ix_recurring_entity",
            "ix_recurring_next_run",
        ):
            if _index_exists("recurring_invoice_templates", ix):
                op.drop_index(ix, table_name="recurring_invoice_templates")
        op.drop_table("recurring_invoice_templates")

    if _table_exists("credit_note_lines"):
        if _index_exists("credit_note_lines", "ix_cn_line_cn"):
            op.drop_index("ix_cn_line_cn", table_name="credit_note_lines")
        op.drop_table("credit_note_lines")

    if _table_exists("credit_notes"):
        for ix in (
            "ix_credit_notes_entity_id",
            "ix_credit_notes_tenant_id",
            "ix_cn_issue_date",
            "ix_cn_vendor",
            "ix_cn_customer",
            "ix_cn_status",
            "ix_cn_original",
        ):
            if _index_exists("credit_notes", ix):
                op.drop_index(ix, table_name="credit_notes")
        op.drop_table("credit_notes")
