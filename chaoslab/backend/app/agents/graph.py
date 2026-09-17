"""
Builds the LangGraph StateGraph that orchestrates the full agent pipeline:

    architecture_agent -> simulation_agent -> investigator_agent -> remediation_agent -> END

Four nodes, each with a single clear responsibility:
  1. architecture_agent  — LLM reads the parsed topology and summarizes it.
  2. simulation_agent     — deterministic capacity model: traffic profile,
                             healthy baseline, and failure-scenario run.
  3. investigator_agent   — LLM ranks bottlenecks from the evidence, with a
                             bounded self-verification pass built in (see
                             investigator_agent.py docstring).
  4. remediation_agent    — LLM turns confirmed findings into concrete steps
                             and the report's narrative summary.

This replaces an earlier 7-node graph (traffic/capacity/failure were split
into three nodes doing purely deterministic work, and a separate critic node
did a check that's now inline in the investigator). Consolidating removes
pipeline hops that added latency and UI noise without adding reasoning —
the math, prompts, and report fields are otherwise unchanged.

The graph is compiled once and reused; callers stream state updates via
`.astream(...)` so each node's completion can be pushed to the client live.
"""
from langgraph.graph import END, StateGraph

from app.agents.architecture_agent import architecture_agent_node
from app.agents.investigator_agent import investigator_agent_node
from app.agents.remediation_agent import remediation_agent_node
from app.agents.simulation_agent import simulation_agent_node
from app.agents.state import SimulationState


def build_simulation_graph():
    graph = StateGraph(SimulationState)

    graph.add_node("architecture_agent", architecture_agent_node)
    graph.add_node("simulation_agent", simulation_agent_node)
    graph.add_node("investigator_agent", investigator_agent_node)
    graph.add_node("remediation_agent", remediation_agent_node)

    graph.set_entry_point("architecture_agent")
    graph.add_edge("architecture_agent", "simulation_agent")
    graph.add_edge("simulation_agent", "investigator_agent")
    graph.add_edge("investigator_agent", "remediation_agent")
    graph.add_edge("remediation_agent", END)

    return graph.compile()


_compiled_graph = None


def get_simulation_graph():
    global _compiled_graph
    if _compiled_graph is None:
        _compiled_graph = build_simulation_graph()
    return _compiled_graph
