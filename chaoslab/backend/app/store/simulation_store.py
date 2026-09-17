"""
In-memory store for running/completed simulations, keyed by simulation_id.

This is intentionally simple (a dict behind an asyncio.Lock) — it's a
portfolio/demo backend, not a production job queue. Swapping this for
Redis later would only touch this file.
"""
import asyncio
from typing import Dict, Optional

from app.models.schemas import SimulationReport

_lock = asyncio.Lock()
_reports: Dict[str, SimulationReport] = {}


async def save_report(report: SimulationReport) -> None:
    async with _lock:
        _reports[report.simulation_id] = report


async def get_report(simulation_id: str) -> Optional[SimulationReport]:
    async with _lock:
        return _reports.get(simulation_id)
