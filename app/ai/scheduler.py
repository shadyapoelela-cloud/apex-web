"""Proactive AI scheduler — runs `run_all_scans()` on a cadence.

The /api/v1/ai/scan endpoint is fine for admin-triggered invocation,
but V2 blueprint § 9.NEW.2 calls for the agent to be genuinely
proactive: surface anomalies without anyone having to click a button.

This module wires an asyncio task that loops every `AI_SCAN_INTERVAL`
seconds (default 6 hours) and invokes run_all_scans(). Each finding
hits activity_log → WebSocket push → NotificationBellLive — all the
plumbing we already built.

Design choices:
  • Pure asyncio task — no APScheduler / Celery dependency. Keeps
    Render free-tier happy and single-container.
  • Opt-in via env var: PROACTIVE_AI_ENABLED=true. Default off so CI,
    tests, and sandbox demos don't spam spurious findings.
  • First run happens AI_SCAN_WARMUP seconds after startup (default
    60s) so the app is fully booted before the first scan.
  • Jittered interval — each tick adds up to 60s of random noise to
    avoid thundering-herd across cluster replicas.

Install once at startup:
    from app.ai.scheduler import start_proactive_scheduler
    start_proactive_scheduler()
"""
from __future__ import annotations

import asyncio
import logging
import os
import random
from typing import Optional

logger = logging.getLogger(__name__)

# Environment knobs
_ENV_ENABLED = "PROACTIVE_AI_ENABLED"
_ENV_INTERVAL = "AI_SCAN_INTERVAL_SECONDS"
_ENV_WARMUP = "AI_SCAN_WARMUP_SECONDS"
_ENV_DRAIN_ENABLED = "AI_DRAIN_APPROVED_ENABLED"
_ENV_DRAIN_INTERVAL = "AI_DRAIN_APPROVED_INTERVAL_SECONDS"
_DEFAULT_INTERVAL = 6 * 60 * 60   # 6 hours
_DEFAULT_WARMUP = 60              # 1 minute
_DEFAULT_DRAIN_INTERVAL = 5 * 60  # 5 minutes

_task: Optional[asyncio.Task] = None
_drain_task: Optional[asyncio.Task] = None


def _enabled() -> bool:
    return os.environ.get(_ENV_ENABLED, "").lower() in ("true", "1", "yes")


def _interval_seconds() -> int:
    try:
        return max(60, int(os.environ.get(_ENV_INTERVAL, _DEFAULT_INTERVAL)))
    except ValueError:
        return _DEFAULT_INTERVAL


def _warmup_seconds() -> int:
    try:
        return max(0, int(os.environ.get(_ENV_WARMUP, _DEFAULT_WARMUP)))
    except ValueError:
        return _DEFAULT_WARMUP


async def _loop() -> None:
    """Main scheduler loop. Runs until cancelled."""
    # Lazy import — avoid circular deps at module load time.
    from app.ai.proactive import run_all_scans

    interval = _interval_seconds()
    logger.info(
        "Proactive AI scheduler armed — first scan in %ss, then every %ss",
        _warmup_seconds(), interval,
    )
    await asyncio.sleep(_warmup_seconds())

    while True:
        try:
            summary = run_all_scans(emit_activity=True)
            logger.info(
                "Proactive AI scan completed: %d findings across %d scans",
                summary.get("total_findings", 0),
                summary.get("scans_run", 0),
            )
        except asyncio.CancelledError:
            raise
        except Exception as e:
            logger.error("Proactive AI scan errored: %s", e, exc_info=True)

        # Jittered sleep — up to 60s of noise so replicas stagger.
        jitter = random.uniform(0, min(60, interval * 0.1))
        await asyncio.sleep(interval + jitter)


def start_proactive_scheduler() -> bool:
    """Register the loop as a background task on the current event loop.

    Returns True if scheduled, False if skipped (disabled by env or no
    running loop available). Safe to call multiple times — the second
    call no-ops if a task is already running.
    """
    global _task
    if not _enabled():
        logger.info("Proactive AI scheduler disabled — set %s=true to arm it",
                    _ENV_ENABLED)
        return False
    if _task is not None and not _task.done():
        logger.info("Proactive AI scheduler already running")
        return True
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        logger.info("No event loop — scheduler will be started by lifespan()")
        return False
    _task = loop.create_task(_loop(), name="apex-proactive-ai-scan")
    return True


async def stop_proactive_scheduler() -> None:
    """Cancel the scheduler task. Called from lifespan shutdown."""
    global _task
    if _task is None:
        return
    _task.cancel()
    try:
        await _task
    except (asyncio.CancelledError, Exception):  # noqa: BLE001
        pass
    _task = None


# ── Approved-suggestion drain ──────────────────────────────


def _drain_enabled() -> bool:
    return os.environ.get(_ENV_DRAIN_ENABLED, "").lower() in ("true", "1", "yes")


def _drain_interval_seconds() -> int:
    try:
        return max(30, int(os.environ.get(_ENV_DRAIN_INTERVAL, _DEFAULT_DRAIN_INTERVAL)))
    except ValueError:
        return _DEFAULT_DRAIN_INTERVAL


async def _drain_loop() -> None:
    """Drains the approved-but-not-executed AiSuggestion queue.

    Decouples human approval (cheap, idempotent) from domain execution
    (expensive, side-effectful). A fast cadence (5 min default) keeps
    the UX feeling "live" without pounding the DB.
    """
    from app.ai.approval_executor import execute_all_approved

    interval = _drain_interval_seconds()
    logger.info(
        "AI approval-drain scheduler armed — every %ss",
        interval,
    )
    # Smaller warmup so approved rows seeded at startup execute quickly.
    await asyncio.sleep(min(_warmup_seconds(), 30))

    while True:
        try:
            out = execute_all_approved(limit=50)
            if out.get("considered", 0) > 0:
                logger.info(
                    "AI approval-drain: considered=%d executed=%d failed=%d",
                    out.get("considered", 0),
                    out.get("executed", 0),
                    out.get("failed", 0),
                )
        except asyncio.CancelledError:
            raise
        except Exception as e:
            logger.error("AI approval-drain errored: %s", e, exc_info=True)
        jitter = random.uniform(0, min(30, interval * 0.1))
        await asyncio.sleep(interval + jitter)


def start_drain_scheduler() -> bool:
    """Arm the approved-suggestion drain task."""
    global _drain_task
    if not _drain_enabled():
        logger.info("AI approval-drain disabled — set %s=true to arm it",
                    _ENV_DRAIN_ENABLED)
        return False
    if _drain_task is not None and not _drain_task.done():
        logger.info("AI approval-drain already running")
        return True
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        logger.info("No event loop — drain scheduler will be started by lifespan()")
        return False
    _drain_task = loop.create_task(_drain_loop(), name="apex-ai-approval-drain")
    return True


async def stop_drain_scheduler() -> None:
    global _drain_task
    if _drain_task is None:
        return
    _drain_task.cancel()
    try:
        await _drain_task
    except (asyncio.CancelledError, Exception):  # noqa: BLE001
        pass
    _drain_task = None
