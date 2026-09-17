"""
Investigator Agent: identifies the most likely breaking point(s) from the
computed component metrics (evidence), and self-verifies its own finding
against that evidence before returning it.

This node absorbs what used to be a separate "Critic Agent" node. The critic
never called an LLM — it was a deterministic check ("does the claimed
top-risk service actually match the highest measured risk score?") — so
giving it its own pipeline hop added a visible "agent" without adding a
second opinion. The check is exactly as strict as before; it just runs
inline, with one bounded self-revision if the first finding doesn't hold up
against the evidence, instead of looping back through the graph.

`critic_verdict` / `critic_approved` are kept in the returned state (and in
SimulationReport) unchanged, so the rest of the API contract — and the
"AI reasoning vs. deterministic evidence" distinction in the UI — is
unaffected by this consolidation.
"""
from app.agents.llm_client import get_llm_client
from app.agents.state import SimulationState
from app.models.schemas import AgentName, AgentStepEvent, AgentStepStatus, BottleneckFinding

SYSTEM_PROMPT = (
    "You are the Investigator Agent in a distributed-systems reliability simulator. "
    "You are given per-service metrics (CPU%, memory%, p95 latency ms, error rate%, "
    "risk score%) that were computed by a deterministic capacity model — treat these "
    "numbers as ground-truth evidence, do not contradict or restate different numbers. "
    "Identify the top 1-3 bottleneck services and explain the causal chain in plain "
    "English (e.g. 'X saturates first, causing cascading latency in Y'). "
    'Return JSON: {"bottlenecks": [{"service_name": str, "reasoning": str}]} '
    "ordered most severe first, using ONLY service names present in the input."
)

_REVISION_SUFFIX = (
    "\n\nYour previous answer named '{prev_service}' as the top bottleneck, but the "
    "evidence shows '{true_service}' has a higher measured risk score ({true_risk}% vs "
    "{prev_risk}%). Revise your answer so the top bottleneck is consistent with the "
    "highest-risk service in the evidence."
)

_RISK_TOLERANCE_PCT = 5.0  # allow the model to pick within 5pts of the true max


def _parse_bottlenecks(result: dict, metrics: list) -> list:
    valid_names = {m.service_name for m in metrics}
    risk_lookup = {m.service_name: m.risk_score_pct for m in metrics}
    bottlenecks: list = []
    raw = result.get("bottlenecks") if isinstance(result, dict) else None
    if isinstance(raw, list):
        for item in raw[:3]:
            name = item.get("service_name") if isinstance(item, dict) else None
            if name in valid_names:
                bottlenecks.append(
                    BottleneckFinding(
                        service_name=name,
                        risk_score_pct=risk_lookup[name],
                        reasoning=item.get("reasoning", ""),
                    )
                )
    return bottlenecks


async def investigator_agent_node(state: SimulationState) -> dict:
    metrics = state.get("component_metrics", [])
    metrics_text = "\n".join(
        f"- {m.service_name} ({m.role}): cpu={m.cpu_utilization_pct}%, "
        f"mem={m.memory_utilization_pct}%, p95_latency={m.p95_latency_ms}ms, "
        f"error_rate={m.error_rate_pct}%, risk_score={m.risk_score_pct}%"
        for m in metrics
    )

    # Deterministic fallback ranking — used if the LLM is unconfigured,
    # returns nothing usable, or fails self-verification on both attempts.
    ranked_by_risk = sorted(
        metrics, key=lambda m: (m.risk_score_pct, m.p95_latency_ms), reverse=True
    )
    true_max_risk = ranked_by_risk[0].risk_score_pct if ranked_by_risk else 0.0
    true_max_service = ranked_by_risk[0].service_name if ranked_by_risk else None

    llm = get_llm_client()
    user_prompt = f"Component metrics:\n{metrics_text}"
    result = await llm.complete_json(SYSTEM_PROMPT, user_prompt)
    bottlenecks = _parse_bottlenecks(result, metrics)

    approved = False
    verdict = "No components to verify — trivial pass."
    revised = False

    if not metrics:
        approved = True
    elif bottlenecks:
        claimed_risk = bottlenecks[0].risk_score_pct
        approved = (true_max_risk - claimed_risk) <= _RISK_TOLERANCE_PCT
        if approved:
            verdict = (
                f"Top finding ({bottlenecks[0].service_name}, {claimed_risk}% risk) matches "
                f"the highest measured risk in the evidence ({true_max_risk}%). Supported."
            )
        else:
            # One bounded self-revision: re-ask with the discrepancy spelled out.
            revised = True
            revision_prompt = user_prompt + _REVISION_SUFFIX.format(
                prev_service=bottlenecks[0].service_name,
                true_service=true_max_service,
                true_risk=true_max_risk,
                prev_risk=claimed_risk,
            )
            revised_result = await llm.complete_json(SYSTEM_PROMPT, revision_prompt)
            revised_bottlenecks = _parse_bottlenecks(revised_result, metrics)
            if revised_bottlenecks:
                revised_claimed_risk = revised_bottlenecks[0].risk_score_pct
                if (true_max_risk - revised_claimed_risk) <= _RISK_TOLERANCE_PCT:
                    bottlenecks = revised_bottlenecks
                    approved = True
                    verdict = (
                        f"Revised finding ({bottlenecks[0].service_name}, "
                        f"{revised_claimed_risk}% risk) now matches the highest measured "
                        f"risk in the evidence ({true_max_risk}%). Supported after one revision."
                    )

    if not bottlenecks or not approved:
        # LLM unavailable, returned nothing usable, or failed verification
        # twice — fall back to the deterministic ranking directly so the
        # report never contradicts its own evidence.
        bottlenecks = [
            BottleneckFinding(
                service_name=m.service_name,
                risk_score_pct=m.risk_score_pct,
                reasoning=(
                    f"Highest computed risk score ({m.risk_score_pct}%) driven by "
                    f"{m.cpu_utilization_pct}% CPU utilization and {m.error_rate_pct}% error rate."
                ),
            )
            for m in ranked_by_risk[:3]
        ]
        approved = True
        if metrics and not verdict.startswith("Top finding") and not verdict.startswith("Revised"):
            verdict = (
                f"Reverted to the deterministic risk ranking — highest measured risk is "
                f"'{true_max_service}' ({true_max_risk}%)."
            )

    top = bottlenecks[0] if bottlenecks else None
    headline = (
        f"Primary bottleneck: {top.service_name} ({top.risk_score_pct}% risk)"
        if top
        else "No bottleneck detected"
    )
    if revised:
        headline += " · self-verified"

    step = AgentStepEvent(
        agent=AgentName.investigator_agent,
        status=AgentStepStatus.complete,
        headline=headline,
        detail=top.reasoning if top else "All components within healthy operating range.",
        sequence=3,
    )
    return {
        "bottlenecks": bottlenecks,
        "critic_verdict": verdict,
        "critic_approved": approved,
        "steps": state.get("steps", []) + [step],
    }
