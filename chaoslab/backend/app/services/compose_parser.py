"""
Parses a docker-compose.yml into ServiceNode/ArchitectureGraph objects.

This intentionally stays mechanical (structured YAML -> structured objects).
Role inference (api / database / cache / queue / gateway) uses simple,
transparent heuristics on image names — no LLM call needed for this step,
which keeps it fast and deterministic.
"""
from typing import Any, Dict, List, Optional

import yaml

from app.core.logging import get_logger
from app.models.schemas import ArchitectureGraph, ServiceNode

logger = get_logger(__name__)

_ROLE_HINTS = {
    "database": ["postgres", "mysql", "mariadb", "mongo", "cassandra", "cockroach"],
    "cache": ["redis", "memcached", "keydb"],
    "queue": ["rabbitmq", "kafka", "activemq", "nats", "sqs", "celery"],
    "gateway": ["nginx", "traefik", "envoy", "kong", "haproxy"],
    "search": ["elasticsearch", "opensearch", "solr", "meilisearch"],
}


def _infer_role(service_name: str, image: Optional[str]) -> str:
    haystack = f"{service_name} {image or ''}".lower()
    for role, hints in _ROLE_HINTS.items():
        if any(hint in haystack for hint in hints):
            return role
    # Anything with a build context and no known infra image is treated as
    # application code the team owns (an "api" node in the graph).
    return "api"


def _parse_memory_limit(value: Any) -> Optional[int]:
    """Parses compose-style memory strings ('512m', '1g') into MB."""
    if value is None:
        return None
    text = str(value).strip().lower()
    try:
        if text.endswith("g"):
            return int(float(text[:-1]) * 1024)
        if text.endswith("m"):
            return int(float(text[:-1]))
        if text.endswith("k"):
            return max(1, int(float(text[:-1]) / 1024))
        return int(float(text))
    except ValueError:
        return None


def parse_compose_yaml(raw_yaml: str, compose_path: str, repo_full_name: str, branch: str) -> ArchitectureGraph:
    try:
        document: Dict[str, Any] = yaml.safe_load(raw_yaml) or {}
    except yaml.YAMLError as exc:
        raise ValueError(f"Invalid YAML in {compose_path}: {exc}") from exc

    raw_services: Dict[str, Any] = document.get("services", {}) or {}
    services: List[ServiceNode] = []
    edges: List[List[str]] = []

    for service_name, spec in raw_services.items():
        spec = spec or {}
        image = spec.get("image")
        build = spec.get("build")
        build_context = None
        if isinstance(build, str):
            build_context = build
        elif isinstance(build, dict):
            build_context = build.get("context")

        ports_raw = spec.get("ports", []) or []
        ports = [str(p) for p in ports_raw]

        depends_on_raw = spec.get("depends_on", []) or []
        if isinstance(depends_on_raw, dict):
            depends_on = list(depends_on_raw.keys())
        else:
            depends_on = list(depends_on_raw)

        env = spec.get("environment", []) or []
        if isinstance(env, dict):
            env_keys = list(env.keys())
        else:
            env_keys = [str(e).split("=")[0] for e in env]

        deploy = spec.get("deploy", {}) or {}
        resources = deploy.get("resources", {}) or {}
        limits = resources.get("limits", {}) or {}
        cpu_limit = None
        if "cpus" in limits:
            try:
                cpu_limit = float(limits["cpus"])
            except (TypeError, ValueError):
                cpu_limit = None
        memory_limit_mb = _parse_memory_limit(limits.get("memory"))

        try:
            replicas = max(1, int(deploy.get("replicas", 1)))
        except (TypeError, ValueError):
            replicas = 1

        node = ServiceNode(
            name=service_name,
            image=image,
            build_context=build_context,
            ports=ports,
            depends_on=depends_on,
            environment_keys=env_keys,
            inferred_role=_infer_role(service_name, image),
            cpu_limit=cpu_limit,
            memory_limit_mb=memory_limit_mb,
            replicas=replicas,
        )
        services.append(node)

        for dependency in depends_on:
            edges.append([service_name, dependency])

    return ArchitectureGraph(
        repo_full_name=repo_full_name,
        default_branch=branch,
        services=services,
        edges=edges,
        compose_file_path=compose_path,
        used_fallback=False,
    )


def build_fallback_graph(repo_full_name: str, branch: str, reason: str) -> ArchitectureGraph:
    """
    Used when no compose file is found or parsing fails. Gives a sane,
    generic 3-tier default (api -> cache -> database) so the pipeline can
    still run, clearly flagged as a fallback so the UI can prompt the user
    to confirm/edit rather than presenting it as ground truth.
    """
    services = [
        ServiceNode(name="api", inferred_role="api", depends_on=["cache", "database"], replicas=2),
        ServiceNode(name="cache", inferred_role="cache", replicas=1),
        ServiceNode(name="database", inferred_role="database", replicas=1),
    ]
    edges = [["api", "cache"], ["api", "database"]]
    return ArchitectureGraph(
        repo_full_name=repo_full_name,
        default_branch=branch,
        services=services,
        edges=edges,
        compose_file_path=None,
        used_fallback=True,
        fallback_reason=reason,
    )
