"""
APEX — ZATCA queue background worker (Wave 9).

Closes Wave 5: until now the retry queue only drained when someone
hit the dry-run endpoint. This module runs the real worker — an
asyncio task that wakes every N seconds, calls
zatca_retry_queue.process_due(), and goes back to sleep.

Design:
- Opt-in via ZATCA_WORKER_ENABLED=true. In production this will be
  flipped on behind a feature flag after the real Fatoora HTTP client
  is integrated. Dev/test default is OFF so importing this module
  never starts a loop accidentally.
- The submit_fn is injected by app/main.py at startup so the worker
  stays decoupled from any HTTP client (same invariant as Wave 5 —
  the queue module itself does no I/O).
- Graceful shutdown: the lifespan context cancels the task on app
  shutdown, and the loop catches CancelledError cleanly so no row
  gets left in a half-processed state.
- A default "noop" submit_fn is provided for tests + local dev so the
  worker can exercise the loop mechanics without talking to ZATCA.

Lifecycle (called from app/main.py:lifespan):
    worker = ZatcaQueueWorker()
    await worker.start()
    yield
    await worker.stop()
"""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Any, Awaitable, Callable, Dict, Optional

from app.core.zatca_retry_queue import SubmissionResult, process_due

logger = logging.getLogger(__name__)


def _is_enabled() -> bool:
    """Default: disabled. Opt-in explicitly so nothing runs in test/dev
    unless the operator flips the flag."""
    return os.environ.get("ZATCA_WORKER_ENABLED", "").lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _default_interval_seconds() -> int:
    try:
        return max(10, int(os.environ.get("ZATCA_WORKER_INTERVAL_SECONDS", "60")))
    except ValueError:
        return 60


def _default_batch_limit() -> int:
    try:
        return max(1, min(500, int(os.environ.get("ZATCA_WORKER_BATCH_LIMIT", "50"))))
    except ValueError:
        return 50


# Submit-function contract mirrors zatca_retry_queue.process_due: it
# receives one queued-row dict and returns a SubmissionResult telling
# the queue whether to mark the row cleared or reschedule.
SubmitFn = Callable[[Dict[str, Any]], SubmissionResult]


def default_noop_submit(_row: Dict[str, Any]) -> SubmissionResult:
    """Drop-in submit_fn that always records a failure without hitting
    the network. Used in tests and before the real HTTP client is
    plugged in — lets us exercise the loop + backoff ladder safely."""
    return SubmissionResult(
        ok=False,
        error_code="NOOP",
        error_message="No ZATCA HTTP client wired yet — worker in no-op mode.",
    )


class ZatcaQueueWorker:
    """Long-running asyncio task that drains the ZATCA retry queue."""

    def __init__(
        self,
        *,
        interval_seconds: Optional[int] = None,
        batch_limit: Optional[int] = None,
        submit_fn: Optional[SubmitFn] = None,
        enabled: Optional[bool] = None,
    ) -> None:
        self._interval = interval_seconds or _default_interval_seconds()
        self._limit = batch_limit or _default_batch_limit()
        self._submit_fn: SubmitFn = submit_fn or default_noop_submit
        self._enabled = enabled if enabled is not None else _is_enabled()

        self._task: Optional[asyncio.Task[None]] = None
        self._stopped = asyncio.Event()
        # Public counters the admin UI can poll if we later expose them.
        self.iterations = 0
        self.last_summary: Dict[str, int] = {}
        self.last_error: Optional[str] = None

    @property
    def running(self) -> bool:
        return self._task is not None and not self._task.done()

    async def start(self) -> None:
        """Schedule the loop. No-op when disabled or already running."""
        if not self._enabled:
            logger.info("ZATCA worker: disabled (ZATCA_WORKER_ENABLED not set).")
            return
        if self.running:
            return
        self._stopped.clear()
        self._task = asyncio.create_task(self._run(), name="zatca-queue-worker")
        logger.info(
            "ZATCA worker: started (interval=%ss, batch_limit=%s).",
            self._interval,
            self._limit,
        )

    async def stop(self) -> None:
        """Cancel the loop and wait for it to wind down."""
        if self._task is None:
            return
        self._stopped.set()
        self._task.cancel()
        try:
            await self._task
        except (asyncio.CancelledError, Exception):
            pass
        self._task = None
        logger.info("ZATCA worker: stopped.")

    async def run_once(self) -> Dict[str, int]:
        """Execute a single drain pass — useful for tests and for the
        admin "process now" button that skips the interval wait."""
        summary = await asyncio.to_thread(
            process_due,
            self._submit_fn,
            limit=self._limit,
        )
        self.iterations += 1
        self.last_summary = summary
        return summary

    async def _run(self) -> None:
        while not self._stopped.is_set():
            try:
                await self.run_once()
            except asyncio.CancelledError:
                raise
            except Exception as e:
                logger.exception("ZATCA worker: iteration failed")
                self.last_error = str(e)[:2000]
            # Sleep in small steps so cancellation is responsive.
            try:
                await asyncio.wait_for(self._stopped.wait(), timeout=self._interval)
            except asyncio.TimeoutError:
                continue


# Module-level default instance used by app/main.py lifespan. Tests
# should instantiate ZatcaQueueWorker() directly with their own injected
# submit_fn instead of reaching for this singleton.
_default_worker: Optional[ZatcaQueueWorker] = None


def get_default_worker() -> ZatcaQueueWorker:
    global _default_worker
    if _default_worker is None:
        _default_worker = ZatcaQueueWorker()
    return _default_worker
