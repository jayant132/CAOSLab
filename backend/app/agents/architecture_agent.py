"""
Architecture Agent: validates/summarizes the reconstructed system graph
before any load is simulated against it. Pure bookkeeping + one LLM call
to produce a human-readable description of the topology for the report.
"""
from app.agents.llm_client import get_llm_client
from app.agents.state import SimulationState
from app.models.schemas import AgentName, AgentStepEvent, AgentStepStatus

SYSTEM_PROMPT = (
    "You are the Architecture Agent in a distributed-systems simulation platform. "
    "Given a parsed service topology, write a concise (2-3 sentence) plain-English "
    "description of the architecture a senior engineer would recognize immediately. "
    "Do not invent services that were not listed."
)


async def architecture_agent_node(state: SimulationState) -> dict:
    architecture = state["architecture"]
    service_summary = ", ".join(
        f"{s.name} ({s.inferred_role})" for s in architecture.services
    )

    llm = get_llm_client()
    description = await llm.complete(
        SYSTEM_PROMPT,
        f"Repo: {architecture.repo_full_name}\nServices: {service_summary}\n"
        f"Dependency edges: {architecture.edges}",
    )

    step = AgentStepEvent(
        agent=AgentName.architecture_agent,
        status=AgentStepStatus.complete,
        headline=f"Reconstructed topology: {len(architecture.services)} services",
        detail=description.strip(),
        sequence=1,  # 1 of 4: architecture -> simulation -> investigator -> remediation
    )
    return {"steps": state.get("steps", []) + [step]}
