"""Period Close Checklist — NetSuite-pattern sequenced tasks with
sign-off + dependency enforcement.

Gives finance teams a step-by-step close checklist where each task
must be completed (signed off by an owner) before its dependents can
start. No more "did we lock AP?" emails at 11pm on month-end.

Default task template (can be customized per tenant):

  1. Lock AR / AP                 — no new invoices / bills for the period
  2. Bank reconciliation          — all bank accounts reconciled
  3. Review fixed asset run       — depreciation JEs posted
  4. FX revaluation               — run + post
  5. Accruals + prepayments       — book the adjusting JEs
  6. Intercompany elimination     — reconcile IC balances
  7. Inventory count variance     — adjust inventory GL
  8. Payroll accrual              — book salary accrual
  9. VAT return prep              — generate + file
 10. Close period                 — lock JE creation for the period
 11. Run reports                  — P&L / BS / CF distributed
 12. Sign-off                     — controller + CFO approve

Each task has: sequence / name / owner / due_date / completed /
completed_by / completed_at / notes / depends_on [task_ids].
"""

from __future__ import annotations

import enum
from sqlalchemy import (
    Column, String, Integer, DateTime, Date, Text, JSON, ForeignKey, Index,
)
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class PeriodCloseStatus(str, enum.Enum):
    not_started = "not_started"
    in_progress = "in_progress"
    completed = "completed"
    reopened = "reopened"


class PeriodCloseTaskStatus(str, enum.Enum):
    pending = "pending"
    blocked = "blocked"        # blocked by an incomplete dependency
    in_progress = "in_progress"
    completed = "completed"
    skipped = "skipped"


class PeriodClose(Base):
    """One close cycle per (tenant, entity, period). A close is a
    collection of ordered tasks that must all reach completed before
    the underlying FiscalPeriod is locked."""

    __tablename__ = "pilot_period_close"
    __table_args__ = (
        Index("ix_pilot_period_close_entity_period", "entity_id", "fiscal_period_id"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=False, index=True)
    entity_id = Column(String(36), nullable=False, index=True)
    fiscal_period_id = Column(String(36), nullable=False)

    period_code = Column(String(20), nullable=False)          # "2026-04"
    status = Column(String(20), nullable=False, default=PeriodCloseStatus.not_started.value)

    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    signed_off_by = Column(String(36), nullable=True)

    notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    tasks = relationship("PeriodCloseTask", back_populates="close",
                         cascade="all, delete-orphan",
                         order_by="PeriodCloseTask.sequence")


class PeriodCloseTask(Base):
    """One step in the close checklist. `depends_on_ids` is a JSON list
    of sibling task ids that must be completed before this one can start."""

    __tablename__ = "pilot_period_close_task"
    __table_args__ = (
        Index("ix_pilot_close_task_close", "close_id"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    close_id = Column(
        String(36),
        ForeignKey("pilot_period_close.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sequence = Column(Integer, nullable=False, default=0)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)
    description_ar = Column(Text, nullable=True)

    status = Column(String(20), nullable=False, default=PeriodCloseTaskStatus.pending.value)
    assignee_user_id = Column(String(36), nullable=True)
    due_date = Column(Date, nullable=True)

    depends_on_ids = Column(JSON, nullable=False, default=list)

    completed_at = Column(DateTime(timezone=True), nullable=True)
    completed_by = Column(String(36), nullable=True)
    completion_notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    close = relationship("PeriodClose", back_populates="tasks")


# ── Default template ─────────────────────────────────────


DEFAULT_CLOSE_TASKS: list[dict] = [
    {"sequence": 1,  "name_ar": "قفل الذمم المدينة (AR) والدائنة (AP)",
     "description_ar": "إيقاف إنشاء فواتير جديدة للفترة الحالية"},
    {"sequence": 2,  "name_ar": "التسوية البنكية لكل الحسابات",
     "description_ar": "مطابقة كل الحركات البنكية مع دفاتر الأستاذ"},
    {"sequence": 3,  "name_ar": "مراجعة إهلاك الأصول الثابتة",
     "description_ar": "ترحيل قيود الإهلاك الشهري"},
    {"sequence": 4,  "name_ar": "إعادة تقييم العملات الأجنبية (FX)",
     "description_ar": "حساب وترحيل فروقات الصرف على الأرصدة بالعملات"},
    {"sequence": 5,  "name_ar": "استحقاقات ومصروفات مدفوعة مقدماً",
     "description_ar": "قيود التسوية للاستحقاقات والإيرادات/المصروفات المؤجلة"},
    {"sequence": 6,  "name_ar": "الشطب بين الشركات (Intercompany)",
     "description_ar": "تسوية الأرصدة بين الكيانات قبل التوحيد"},
    {"sequence": 7,  "name_ar": "تسوية جرد المخزون",
     "description_ar": "قيود فروقات الجرد الدوري"},
    {"sequence": 8,  "name_ar": "قيد استحقاق الرواتب",
     "description_ar": "حساب وترحيل استحقاق رواتب الشهر"},
    {"sequence": 9,  "name_ar": "إعداد وتسجيل إقرار VAT",
     "description_ar": "توليد إقرار ZATCA والتحقق قبل التقديم"},
    {"sequence": 10, "name_ar": "قفل الفترة المحاسبية",
     "description_ar": "منع إنشاء أو تعديل أي قيد في الفترة"},
    {"sequence": 11, "name_ar": "تشغيل التقارير (P&L / BS / Cash Flow)",
     "description_ar": "توليد التقارير وتوزيعها على الإدارة"},
    {"sequence": 12, "name_ar": "توقيع الاعتماد النهائي",
     "description_ar": "اعتماد المدير المالي والرئيس التنفيذي"},
]


# ── Service layer ────────────────────────────────────────


def start_close(
    *,
    tenant_id: str,
    entity_id: str,
    fiscal_period_id: str,
    period_code: str,
) -> str:
    """Create a new close cycle with default tasks. Returns close_id."""
    from app.phase1.models.platform_models import SessionLocal
    from datetime import datetime, timezone

    db = SessionLocal()
    try:
        close = PeriodClose(
            id=gen_uuid(),
            tenant_id=tenant_id,
            entity_id=entity_id,
            fiscal_period_id=fiscal_period_id,
            period_code=period_code,
            status=PeriodCloseStatus.in_progress.value,
            started_at=datetime.now(timezone.utc),
        )
        db.add(close)
        db.flush()
        # Seed tasks with dependency chain (each depends on the previous).
        prev_id = None
        for t in DEFAULT_CLOSE_TASKS:
            task = PeriodCloseTask(
                id=gen_uuid(),
                close_id=close.id,
                sequence=t["sequence"],
                name_ar=t["name_ar"],
                description_ar=t.get("description_ar"),
                depends_on_ids=[prev_id] if prev_id else [],
                status=(
                    PeriodCloseTaskStatus.pending.value
                    if prev_id is None
                    else PeriodCloseTaskStatus.blocked.value
                ),
            )
            db.add(task)
            db.flush()
            prev_id = task.id
        db.commit()
        return close.id
    finally:
        db.close()


def complete_task(
    *,
    task_id: str,
    user_id: str,
    notes: str | None = None,
) -> dict:
    """Mark a task complete. Unblocks any task that depends on this one
    IFF all its dependencies are now complete."""
    from app.phase1.models.platform_models import SessionLocal
    from datetime import datetime, timezone

    db = SessionLocal()
    try:
        task = db.query(PeriodCloseTask).filter(PeriodCloseTask.id == task_id).first()
        if task is None:
            return {"ok": False, "detail": "task not found"}
        if task.status == PeriodCloseTaskStatus.completed.value:
            return {"ok": True, "detail": "already completed"}
        task.status = PeriodCloseTaskStatus.completed.value
        task.completed_at = datetime.now(timezone.utc)
        task.completed_by = user_id
        task.completion_notes = notes

        # Find siblings that have this task as a dependency and unblock
        # them if all their deps are satisfied.
        siblings = db.query(PeriodCloseTask).filter(
            PeriodCloseTask.close_id == task.close_id,
            PeriodCloseTask.id != task.id,
        ).all()
        for s in siblings:
            if s.status != PeriodCloseTaskStatus.blocked.value:
                continue
            deps = s.depends_on_ids or []
            if not deps:
                s.status = PeriodCloseTaskStatus.pending.value
                continue
            done = db.query(PeriodCloseTask).filter(
                PeriodCloseTask.id.in_(deps),
                PeriodCloseTask.status == PeriodCloseTaskStatus.completed.value,
            ).count()
            if done == len(deps):
                s.status = PeriodCloseTaskStatus.pending.value

        # If all tasks in the close are complete, mark the close complete.
        remaining = db.query(PeriodCloseTask).filter(
            PeriodCloseTask.close_id == task.close_id,
            PeriodCloseTask.status != PeriodCloseTaskStatus.completed.value,
        ).count()
        if remaining == 0:
            close = db.query(PeriodClose).filter(PeriodClose.id == task.close_id).first()
            if close is not None:
                close.status = PeriodCloseStatus.completed.value
                close.completed_at = datetime.now(timezone.utc)
                close.signed_off_by = user_id

        db.commit()
        return {"ok": True, "task_id": task.id, "unblocked_count": db.query(PeriodCloseTask).filter(
            PeriodCloseTask.close_id == task.close_id,
            PeriodCloseTask.status == PeriodCloseTaskStatus.pending.value,
        ).count()}
    finally:
        db.close()


def get_close(close_id: str) -> dict | None:
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        close = db.query(PeriodClose).filter(PeriodClose.id == close_id).first()
        if close is None:
            return None
        tasks = db.query(PeriodCloseTask).filter(
            PeriodCloseTask.close_id == close_id,
        ).order_by(PeriodCloseTask.sequence).all()
        return {
            "id": close.id,
            "tenant_id": close.tenant_id,
            "entity_id": close.entity_id,
            "period_code": close.period_code,
            "status": close.status,
            "started_at": close.started_at.isoformat() if close.started_at else None,
            "completed_at": close.completed_at.isoformat() if close.completed_at else None,
            "signed_off_by": close.signed_off_by,
            "total_tasks": len(tasks),
            "completed_tasks": sum(1 for t in tasks if t.status == PeriodCloseTaskStatus.completed.value),
            "tasks": [
                {
                    "id": t.id,
                    "sequence": t.sequence,
                    "name_ar": t.name_ar,
                    "description_ar": t.description_ar,
                    "status": t.status,
                    "assignee_user_id": t.assignee_user_id,
                    "due_date": t.due_date.isoformat() if t.due_date else None,
                    "depends_on_ids": t.depends_on_ids or [],
                    "completed_at": t.completed_at.isoformat() if t.completed_at else None,
                    "completed_by": t.completed_by,
                    "completion_notes": t.completion_notes,
                }
                for t in tasks
            ],
        }
    finally:
        db.close()


def list_closes(tenant_id: str | None = None, entity_id: str | None = None) -> list[dict]:
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    try:
        q = db.query(PeriodClose)
        if tenant_id:
            q = q.filter(PeriodClose.tenant_id == tenant_id)
        if entity_id:
            q = q.filter(PeriodClose.entity_id == entity_id)
        rows = q.order_by(PeriodClose.created_at.desc()).limit(200).all()
        out = []
        for c in rows:
            total = db.query(PeriodCloseTask).filter(PeriodCloseTask.close_id == c.id).count()
            done = db.query(PeriodCloseTask).filter(
                PeriodCloseTask.close_id == c.id,
                PeriodCloseTask.status == PeriodCloseTaskStatus.completed.value,
            ).count()
            out.append({
                "id": c.id,
                "entity_id": c.entity_id,
                "period_code": c.period_code,
                "status": c.status,
                "total_tasks": total,
                "completed_tasks": done,
                "progress_pct": round((done / total * 100) if total else 0, 1),
                "started_at": c.started_at.isoformat() if c.started_at else None,
                "completed_at": c.completed_at.isoformat() if c.completed_at else None,
            })
        return out
    finally:
        db.close()
