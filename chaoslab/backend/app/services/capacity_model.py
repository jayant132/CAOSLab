"""
Deterministic, formula-based capacity/load model.

This is deliberately NOT random and NOT an LLM guess: given a service's
role, its declared resource limits (or role-based defaults), a target
concurrent-user count, and an optional failure scenario, it computes
utilization/latency/error-rate numbers using explicit queueing-theory-style
heuristics. The LLM agents reason ON TOP of these numbers (diagnosis,
narrative, remediation) — they never invent the numbers themselves.
"""
import math
from typing import Dict, List, Tuple

from app.models.schemas import ArchitectureGraph, ComponentMetric, FailureScenarioType, ServiceNode

# Baseline per-instance capacity assumptions by role, when a service doesn't
# declare explicit cpu/memory limits in its compose file. Units: concurrent
# requests a single instance can comfortably serve before saturating.
_ROLE_BASELINE_CAPACITY = {
    "api": 500,
    "gateway": 2000,
    "cache": 5000,
    "queue": 3000,
    "database": 300,
    "search": 400,
    "unknown": 500,
}

# Rough fraction of total concurrent users that actually hit a given role
# per unit time, since not every request touches every tier equally.
_ROLE_TRAFFIC_FANOUT = {
    "api": 1.0,
    "gateway": 1.0,
    "cache": 0.7,
    "queue": 0.3,
    "database": 0.55,
    "search": 0.15,
    "unknown": 0.5,
}

_BASE_LATENCY_MS = {
    "api": 60,
    "gateway": 15,
    "cache": 3,
    "queue": 20,
    "database": 40,
    "search": 50,
    "unknown": 60,
}

_FAILURE_MULTIPLIERS: Dict[FailureScenarioType, Dict[str, float]] = {
    FailureScenarioType.none: {},
    FailureScenarioType.database_latency_spike: {"database": 4.0},
    FailureScenarioType.cache_outage: {"cache": 0.0, "database": 1.8, "api": 1.3},
    FailureScenarioType.dependency_timeout: {"api": 2.2},
    FailureScenarioType.traffic_surge: {},  # handled via target_users multiplier upstream
    FailureScenarioType.instance_loss: {"api": 1.6, "gateway": 1.6},
}


def _effective_capacity(service: ServiceNode) -> int:
    baseline = _ROLE_BASELINE_CAPACITY.get(service.inferred_role, _ROLE_BASELINE_CAPACITY["unknown"])
    if service.cpu_limit:
        # Scale baseline roughly linearly with declared CPU allocation
        # relative to an assumed 1-vCPU reference instance.
        baseline = int(baseline * max(service.cpu_limit, 0.25))
    return baseline


def _utilization_curve(load: float, capacity: float) -> float:
    """
    Utilization saturates smoothly toward 100% rather than exceeding it
    linearly forever, matching real system behaviour under overload.
    """
    if capacity <= 0:
        return 100.0
    ratio = load / capacity
    utilization = 100.0 * (1 - math.exp(-ratio))
    # Allow slight over-100 visual signal for severe overload, capped at 140.
    if ratio > 1:
        utilization = min(140.0, 100.0 + (ratio - 1) * 40.0)
    return round(utilization, 1)


def _latency_under_load(base_latency_ms: float, ratio: float) -> float:
    """Latency grows steeply (M/M/1-style) as utilization approaches 100%."""
    ratio = min(ratio, 0.995)
    factor = 1 / max(1e-6, (1 - ratio))
    return round(base_latency_ms * min(factor, 60), 1)


def _error_rate(ratio: float) -> float:
    if ratio <= 0.85:
        return round(max(0.0, (ratio - 0.5)) * 0.4, 2)
    overflow = ratio - 0.85
    return round(min(45.0, overflow * 120), 2)


_HEALTHY_TARGET_RATIO = 0.65  # ratio we size "recommended instances" to land on


def run_capacity_simulation(
    architecture: ArchitectureGraph,
    target_users: int,
    failure_scenario: FailureScenarioType,
) -> List[ComponentMetric]:
    """
    Computes each service's utilization/latency/error/risk against the
    CURRENTLY PROVISIONED fleet (service.replicas), not an idealized
    auto-scaled one. This is the whole point of the simulator: a service
    with too few replicas for the target load should show up as visibly
    overloaded, and different services should land at genuinely different
    risk levels depending on their own capacity, fanout, and replica count.

    `instances_required` is reported separately as the RECOMMENDED fleet
    size to bring this service back to a healthy ~65% utilization target —
    it does not feed back into the utilization math itself.
    """
    multipliers = _FAILURE_MULTIPLIERS.get(failure_scenario, {})
    metrics: List[ComponentMetric] = []

    for service in architecture.services:
        role = service.inferred_role
        fanout = _ROLE_TRAFFIC_FANOUT.get(role, _ROLE_TRAFFIC_FANOUT["unknown"])
        load = target_users * fanout

        capacity_per_instance = _effective_capacity(service)
        multiplier = multipliers.get(role, 1.0)

        if multiplier == 0.0:
            # Total outage of this component (e.g. cache_outage on 'cache').
            recommended = max(1, math.ceil(load / max(capacity_per_instance, 1) / _HEALTHY_TARGET_RATIO))
            metrics.append(
                ComponentMetric(
                    service_name=service.name,
                    role=role,
                    cpu_utilization_pct=0.0,
                    memory_utilization_pct=0.0,
                    p95_latency_ms=0.0,
                    error_rate_pct=100.0,
                    instances_required=recommended,
                    risk_score_pct=100.0,
                )
            )
            continue

        # Failure multipliers degrade a *single instance's* effective
        # capacity (e.g. a slow database serves fewer requests per second).
        effective_capacity_per_instance = capacity_per_instance / multiplier if multiplier else capacity_per_instance

        currently_provisioned_capacity = effective_capacity_per_instance * max(service.replicas, 1)
        ratio = load / max(currently_provisioned_capacity, 1e-6)

        cpu_util = _utilization_curve(load, currently_provisioned_capacity)
        mem_util = round(min(140.0, cpu_util * 0.85), 1)
        base_latency = _BASE_LATENCY_MS.get(role, 60) * multiplier
        latency = _latency_under_load(base_latency, ratio)
        error_pct = _error_rate(ratio)

        risk_score = round(min(100.0, (cpu_util * 0.5) + (error_pct * 1.2) + (min(ratio, 5.0) * 20)), 1)
        risk_score = max(0.0, min(100.0, risk_score))

        recommended_instances = max(
            1, math.ceil(load / max(effective_capacity_per_instance, 1) / _HEALTHY_TARGET_RATIO)
        )

        metrics.append(
            ComponentMetric(
                service_name=service.name,
                role=role,
                cpu_utilization_pct=cpu_util,
                memory_utilization_pct=mem_util,
                p95_latency_ms=latency,
                error_rate_pct=error_pct,
                instances_required=recommended_instances,
                risk_score_pct=risk_score,
            )
        )

    return metrics


def rank_bottlenecks(metrics: List[ComponentMetric]) -> List[Tuple[str, float]]:
    ranked = sorted(metrics, key=lambda m: m.risk_score_pct, reverse=True)
    return [(m.service_name, m.risk_score_pct) for m in ranked]
