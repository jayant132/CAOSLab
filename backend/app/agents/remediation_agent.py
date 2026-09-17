"""
Remediation Agent: the last stop. Turns the approved bottleneck findings
into concrete, actionable engineering recommendations, and writes the
narrative summary that anchors the final report / LinkedIn-demo screen.
"""
from app.agents.llm_client import get_llm_client
from app.agents.state import SimulationState
from app.models.schemas import AgentName, AgentStepEvent, AgentStepStatus, RemediationStep

SYSTEM_PROMPT = (
    "You are the Remediation Agent in a distributed-systems reliability simulator. "
    "Given the confirmed bottleneck findings, propose 2-4 concrete engineering "
    "remediation steps (e.g. add read replicas, introduce caching, add backpressure). "
    "For each, state expected impact using cautious, evidence-based language "
    "('estimated', 'likely') — never claim certainty about the future. "
    "Also write a 2-3 sentence narrative_summary of the whole simulation suitable "
    "for a report headline. Return JSON: "
    "{\"remediation_plan\": [{\"title\": str, \"description\": str, \"expected_impact\": str}], "
    "\"narrative_summary\": str}"
)


async def remediation_agent_node(state: SimulationState) -> dict:
    bottlenecks = state.get("bottlenecks", [])
    target_users = state["target_users"]
    scenario = state["failure_scenario"]

    findings_text = "\n".join(
        f"- {b.service_name}: risk={b.risk_score_pct}%, reasoning={b.reasoning}" for b in bottlenecks
    )

    llm = get_llm_client()
    result = await llm.complete_json(
        SYSTEM_PROMPT,
        f"Target users: {target_users:,}\nFailure scenario: {scenario.value}\n"
        f"Confirmed bottleneck findings:\n{findings_text or 'None — system healthy.'}",
    )

    plan = []
    raw_plan = result.get("remediation_plan") if isinstance(result, dict) else None
    if isinstance(raw_plan, list):
        for item in raw_plan[:4]:
            if isinstance(item, dict) and item.get("title"):
                plan.append(
                    RemediationStep(
                        title=item.get("title", ""),
                        description=item.get("description", ""),
                        expected_impact=item.get("expected_impact", ""),
                    )
                )

    if not plan and bottlenecks:
        top = bottlenecks[0]
        plan.append(
            RemediationStep(
                title=f"Scale or optimize '{top.service_name}'",
                description=(
                    f"'{top.service_name}' showed the highest measured risk ({top.risk_score_pct}%). "
                    "Consider horizontal scaling, caching hot reads, or adding backpressure."
                ),
                expected_impact="Estimated risk reduction, pending re-simulation to confirm.",
            )
        )

    narrative = result.get("narrative_summary") if isinstance(result, dict) else None
    if not narrative:
        if bottlenecks:
            narrative = (
                f"At {target_users:,} concurrent users under '{scenario.value}', "
                f"'{bottlenecks[0].service_name}' is the most likely breaking point "
                f"({bottlenecks[0].risk_score_pct}% risk)."
            )
        else:
            narrative = f"System remained within healthy operating range at {target_users:,} users."

    step = AgentStepEvent(
        agent=AgentName.remediation_agent,
        status=AgentStepStatus.complete,
        headline=f"Generated {len(plan)} remediation step(s)",
        detail=narrative,
        sequence=4,
    )
    return {
        "remediation_plan": plan,
        "narrative_summary": narrative,
        "steps": state.get("steps", []) + [step],
    }
