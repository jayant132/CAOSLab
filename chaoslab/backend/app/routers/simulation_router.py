"""
Simulation lifecycle endpoints:
  POST /api/v1/simulation/execute        -> kicks off the agent pipeline, returns an id
  GET  /api/v1/simulation/stream/{id}    -> Server-Sent Events, live agent activity feed
  GET  /api/v1/simulation/report/{id}    -> poll for the current/final report (non-streaming)
"""
import asyncio
import json
import uuid

from fastapi import APIRouter, HTTPException
from sse_starlette.sse import EventSourceResponse

from app.core.logging import get_logger
from app.models.schemas import SimulationExecuteRequest, SimulationExecuteResponse, SimulationReport
from app.services.simulation_service import execute_simulation
from app.store.simulation_store import get_report

logger = get_logger(__name__)
router = APIRouter(prefix="/api/v1/simulation", tags=["simulation"])

_POLL_INTERVAL_SECONDS = 0.5


@router.post("/execute", response_model=SimulationExecuteResponse)
async def execute_simulation_endpoint(payload: SimulationExecuteRequest) -> SimulationExecuteResponse:
    simulation_id = str(uuid.uuid4())

    # Fire-and-forget: the SSE / polling endpoints pick up progress from the store.
    asyncio.create_task(
        execute_simulation(
            simulation_id=simulation_id,
            architecture=payload.architecture,
            target_users=payload.target_users,
            failure_scenario=payload.failure_scenario,
            notes=payload.notes,
        )
    )

    return SimulationExecuteResponse(simulation_id=simulation_id, status="queued")


@router.get("/stream/{simulation_id}")
async def stream_simulation_progress(simulation_id: str):
    async def event_generator():
        seen_step_count = 0
        while True:
            report = await get_report(simulation_id)
            if report is None:
                yield {"event": "error", "data": json.dumps({"detail": "simulation_id not found"})}
                return

            new_steps = report.steps[seen_step_count:]
            for step in new_steps:
                yield {"event": "agent_step", "data": step.model_dump_json()}
            seen_step_count = len(report.steps)

            if report.status in ("complete", "failed"):
                yield {"event": "final_report", "data": report.model_dump_json()}
                return

            await asyncio.sleep(_POLL_INTERVAL_SECONDS)

    return EventSourceResponse(event_generator())


@router.get("/report/{simulation_id}", response_model=SimulationReport)
async def get_simulation_report(simulation_id: str) -> SimulationReport:
    report = await get_report(simulation_id)
    if report is None:
        raise HTTPException(status_code=404, detail="simulation_id not found")
    return report
