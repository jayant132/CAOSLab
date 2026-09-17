"""
Pydantic schemas shared across routers, services, and agents.
These are the single source of truth for the API contract — the Flutter
client's Dart models mirror these field-for-field.
"""
from __future__ import annotations

from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Repository intake
# ---------------------------------------------------------------------------

class ServiceNode(BaseModel):
    """A single service parsed out of docker-compose.yml."""
    name: str
    image: Optional[str] = None
    build_context: Optional[str] = None
    ports: List[str] = Field(default_factory=list)
    depends_on: List[str] = Field(default_factory=list)
    environment_keys: List[str] = Field(default_factory=list)
    inferred_role: str = "unknown"  # api | database | cache | queue | gateway | worker | unknown
    cpu_limit: Optional[float] = None
    memory_limit_mb: Optional[int] = None
    replicas: int = 1  # currently provisioned instance count (deploy.replicas, default 1)


class ArchitectureGraph(BaseModel):
    """The reconstructed system topology, ready to feed the agent pipeline."""
    repo_full_name: str
    default_branch: str
    services: List[ServiceNode]
    edges: List[List[str]] = Field(default_factory=list)  # [from, to] dependency pairs
    compose_file_path: Optional[str] = None
    used_fallback: bool = False
    fallback_reason: Optional[str] = None


class RepositoryInspectRequest(BaseModel):
    repo_url: str = Field(..., description="Public GitHub repo URL, e.g. https://github.com/owner/name")


class RepositoryInspectResponse(BaseModel):
    architecture: ArchitectureGraph
    warnings: List[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

class FailureScenarioType(str, Enum):
    none = "none"
    database_latency_spike = "database_latency_spike"
    cache_outage = "cache_outage"
    dependency_timeout = "dependency_timeout"
    traffic_surge = "traffic_surge"
    instance_loss = "instance_loss"


class SimulationExecuteRequest(BaseModel):
    architecture: ArchitectureGraph
    target_users: int = Field(..., gt=0, le=50_000_000)
    failure_scenario: FailureScenarioType = FailureScenarioType.none
    notes: Optional[str] = Field(
        default=None, description="Optional free-text context the user wants agents to consider."
    )


class SimulationExecuteResponse(BaseModel):
    simulation_id: str
    status: str = "queued"


class AgentName(str, Enum):
    """
    Four-stage pipeline. Reduced from an earlier 7-node graph: traffic/
    capacity/failure were three deterministic-only nodes doing what is now
    a single `simulation_agent` pass, and the former `critic_agent` (a
    deterministic evidence check, not an LLM call) now runs inline inside
    `investigator_agent` as a bounded self-verification step. See
    agents/graph.py for the full rationale.
    """
    architecture_agent = "architecture_agent"
    simulation_agent = "simulation_agent"
    investigator_agent = "investigator_agent"
    remediation_agent = "remediation_agent"


class AgentStepStatus(str, Enum):
    pending = "pending"
    running = "running"
    complete = "complete"
    failed = "failed"


class AgentStepEvent(BaseModel):
    """One line item in the live agent-activity feed the Flutter app streams."""
    agent: AgentName
    status: AgentStepStatus
    headline: str
    detail: Optional[str] = None
    sequence: int


class ComponentMetric(BaseModel):
    service_name: str
    role: str
    cpu_utilization_pct: float
    memory_utilization_pct: float
    p95_latency_ms: float
    error_rate_pct: float
    instances_required: int
    risk_score_pct: float  # 0-100, likelihood this component is the breaking point


class BottleneckFinding(BaseModel):
    service_name: str
    risk_score_pct: float
    reasoning: str


class RemediationStep(BaseModel):
    title: str
    description: str
    expected_impact: str


class SimulationReport(BaseModel):
    simulation_id: str
    status: AgentStepStatus
    target_users: int
    failure_scenario: FailureScenarioType
    baseline_component_metrics: List[ComponentMetric] = Field(default_factory=list)
    component_metrics: List[ComponentMetric] = Field(default_factory=list)
    bottlenecks: List[BottleneckFinding] = Field(default_factory=list)
    critic_verdict: Optional[str] = None
    critic_approved: Optional[bool] = None
    remediation_plan: List[RemediationStep] = Field(default_factory=list)
    narrative_summary: Optional[str] = None
    steps: List[AgentStepEvent] = Field(default_factory=list)
    error: Optional[str] = None


class HealthPayload(BaseModel):
    """Deliberately not called /health — see routers/system_router.py."""
    service: str
    version: str
    groq_configured: bool
