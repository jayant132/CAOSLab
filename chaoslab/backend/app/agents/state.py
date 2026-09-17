"""
Shared mutable state passed between every node in the LangGraph pipeline.
Using a TypedDict (LangGraph's preferred state shape) rather than a Pydantic
model keeps node functions simple: each node returns a partial dict patch
that LangGraph merges into the running state.
"""
from typing import Any, Dict, List, Optional, TypedDict

from app.models.schemas import (
    AgentStepEvent,
    ArchitectureGraph,
    BottleneckFinding,
    ComponentMetric,
    FailureScenarioType,
    RemediationStep,
)


class SimulationState(TypedDict, total=False):
    simulation_id: str
    architecture: ArchitectureGraph
    target_users: int
    failure_scenario: FailureScenarioType
    notes: Optional[str]

    traffic_profile: Dict[str, Any]
    baseline_component_metrics: List[ComponentMetric]
    component_metrics: List[ComponentMetric]
    bottlenecks: List[BottleneckFinding]
    critic_verdict: Optional[str]
    critic_approved: Optional[bool]
    remediation_plan: List[RemediationStep]
    narrative_summary: Optional[str]

    steps: List[AgentStepEvent]
    error: Optional[str]
