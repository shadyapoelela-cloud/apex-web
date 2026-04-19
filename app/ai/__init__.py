"""AI subpackage — proactive scanners + agent utilities.

The reactive Claude Copilot lives in app/services/copilot_agent.py.
This package owns the *proactive* half: background scanners that run
on a schedule, surface anomalies, and push ActivityLog events +
WebSocket notifications without a user prompt.
"""
