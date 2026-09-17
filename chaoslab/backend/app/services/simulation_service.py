"""
Runs the compiled LangGraph pipeline for a simulation, persisting a
progressively-updated SimulationReport into the store after every node
completes. The SSE router polls the store to stream this progress live —
this keeps the streaming transport decoupled from LangGraph's execution
model, which is the simplest robust combination.
"""
from app.agents.graph import get_simulation_graph
from app.agents.state import SimulationState
from app.core.logging import get_logger
from app.models.schemas import (
    AgentStepStatus,
    ArchitectureGraph,
    FailureScenarioType,
    SimulationReport,
)
from app.store.simulation_store import save_report

logger = get_logger(__name__)


async def execute_simulation(
    simulation_id: str,
    architecture: ArchitectureGraph,
    target_users: int,
    failure_scenario: FailureScenarioType,
    notes: str | None,
) -> None:
    initial_state: SimulationState = {
        "simulation_id": simulation_id,
        "architecture": architecture,
        "target_users": target_users,
        "failure_scenario": failure_scenario,
        "notes": notes,
        "steps": [],
        "critic_revision_count": 0,
    }

    await save_report(
        SimulationReport(
            simulation_id=simulation_id,
            status=AgentStepStatus.running,
            target_users=target_users,
            failure_scenario=failure_scenario,
        )
    )

    graph = get_simulation_graph()
    latest_state: SimulationState = dict(initial_state)  # type: ignore[assignment]

    try:
        async for update in graph.astream(initial_state, stream_mode="updates"):
            for _node_name, patch in update.items():
                latest_state.update(patch)  # type: ignore[arg-type]

            await save_report(
                SimulationReport(
                    simulation_id=simulation_id,
                    status=AgentStepStatus.running,
                    target_users=target_users,
                    failure_scenario=failure_scenario,
                    component_metrics=latest_state.get("component_metrics", []),
                    bottlenecks=latest_state.get("bottlenecks", []),
                    critic_verdict=latest_state.get("critic_verdict"),
                    critic_approved=latest_state.get("critic_approved"),
                    remediation_plan=latest_state.get("remediation_plan", []),
                    narrative_summary=latest_state.get("narrative_summary"),
                    steps=latest_state.get("steps", []),
                )
            )

        await save_report(
            SimulationReport(
                simulation_id=simulation_id,
                status=AgentStepStatus.complete,
                target_users=target_users,
                failure_scenario=failure_scenario,
                baseline_component_metrics=latest_state.get("baseline_component_metrics", []),
                component_metrics=latest_state.get("component_metrics", []),
                bottlenecks=latest_state.get("bottlenecks", []),
                critic_verdict=latest_state.get("critic_verdict"),
                critic_approved=latest_state.get("critic_approved"),
                remediation_plan=latest_state.get("remediation_plan", []),
                narrative_summary=latest_state.get("narrative_summary"),
                steps=latest_state.get("steps", []),
            )
        )
    except Exception as exc:  # noqa: BLE001
        logger.exception("Simulation %s failed", simulation_id)
        await save_report(
            SimulationReport(
                simulation_id=simulation_id,
                status=AgentStepStatus.failed,
                target_users=target_users,
                failure_scenario=failure_scenario,
                steps=latest_state.get("steps", []),
                error=str(exc),
            )
        )
