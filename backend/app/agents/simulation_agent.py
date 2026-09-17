"""
Simulation Agent: the deterministic core of the pipeline.

Consolidates what used to be three separate nodes (traffic_agent,
capacity_agent, failure_agent) into a single step, because all three do the
same kind of work — running the formula-based capacity_model — with no LLM
reasoning involved. Splitting them into three "agents" was adding pipeline
hops without adding pipeline intelligence.

This node still does the same three things internally, in the same order,
so the math and the report fields are unchanged:
  1. Build a synthetic traffic/journey profile for the target user count.
  2. Run the deterministic capacity model at steady state (the "baseline").
  3. Re-run it with the selected failure scenario applied (the "stressed"
     run), which is what actually feeds the investigator downstream.
"""
from app.agents.state import SimulationState
from app.models.schemas import AgentName, AgentStepEvent, AgentStepStatus, FailureScenarioType
from app.services.capacity_model import run_capacity_simulation

# Simple, transparent journey mix — % of concurrent users in each phase.
# Descriptive context for the report only; the load math itself lives in
# services/capacity_model.py and stays fully deterministic.
_DEFAULT_JOURNEY_MIX = {
    "browsing": 0.45,
    "authenticated_actions": 0.30,
    "checkout_or_write_path": 0.15,
    "idle_polling": 0.10,
}

_SCENARIO_LABELS = {
    FailureScenarioType.none: "Steady-state simulation — no failure injected",
    FailureScenarioType.database_latency_spike: "Database latency spike (+300%) injected",
    FailureScenarioType.cache_outage: "Cache layer total outage injected",
    FailureScenarioType.dependency_timeout: "Upstream dependency timeout injected on API tier",
    FailureScenarioType.traffic_surge: "Sudden traffic surge injected",
    FailureScenarioType.instance_loss: "Loss of running API/gateway instances injected",
}


async def simulation_agent_node(state: SimulationState) -> dict:
    architecture = state["architecture"]
    target_users = state["target_users"]
    scenario = state["failure_scenario"]

    # 1. Traffic profile
    journey_counts = {
        phase: round(target_users * share) for phase, share in _DEFAULT_JOURNEY_MIX.items()
    }

    # 2. Baseline (no failure) — establishes the healthy reference point.
    baseline_metrics = run_capacity_simulation(architecture, target_users, FailureScenarioType.none)
    total_instances = sum(m.instances_required for m in baseline_metrics)

    # 3. Stressed run — the failure scenario applied on top of load.
    effective_users = target_users
    if scenario == FailureScenarioType.traffic_surge:
        effective_users = int(target_users * 3)
    stressed_metrics = run_capacity_simulation(architecture, effective_users, scenario)

    detail = (
        f"Modeled {target_users:,} concurrent users across {len(journey_counts)} journey "
        f"phases. Healthy baseline requires {total_instances} instance(s) across "
        f"{len(baseline_metrics)} service(s). {_SCENARIO_LABELS.get(scenario, str(scenario))} "
        f"at an effective load of {effective_users:,} users."
    )

    step = AgentStepEvent(
        agent=AgentName.simulation_agent,
        status=AgentStepStatus.complete,
        headline=f"Capacity + failure simulation complete for {target_users:,} users",
        detail=detail,
        sequence=2,
    )
    return {
        "traffic_profile": {"target_users": target_users, "journey_mix": journey_counts},
        "baseline_component_metrics": baseline_metrics,
        "component_metrics": stressed_metrics,
        "steps": state.get("steps", []) + [step],
    }
