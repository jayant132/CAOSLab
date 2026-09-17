"""
Fallback architecture inference for repositories that have no
docker-compose file — which is the common case (frontend apps, single
services deployed via a PaaS, monorepos without compose, etc.).

The previous fallback always returned the same hardcoded 3-tier guess
(api / cache / database) regardless of what the repository actually
contained. This module replaces that with a heuristic scan of real,
observable repo signals — manifest files present in the tree, and
dependency names inside them — so the fallback reflects the repo it was
run against instead of a fixed template.

This still produces an ArchitectureGraph with `used_fallback=True`: it is
an inference from static signals, not a verified runtime topology, and the
UI must keep presenting it as editable/unconfirmed rather than ground
truth. No component is ever invented that isn't backed by a concrete
signal (a manifest file found, or a dependency name matched).
"""
import json
import re
from typing import Dict, List, Optional

from app.models.schemas import ArchitectureGraph, ServiceNode

# path -> (ecosystem label, role this file's presence implies for the app itself)
_MANIFEST_FILES: Dict[str, str] = {
    "package.json": "node",
    "requirements.txt": "python",
    "pyproject.toml": "python",
    "Pipfile": "python",
    "go.mod": "go",
    "Gemfile": "ruby",
    "pom.xml": "java",
    "build.gradle": "java",
    "build.gradle.kts": "java",
    "composer.json": "php",
    "Cargo.toml": "rust",
    "manage.py": "python-django",
}

# dependency/keyword -> inferred infra role, checked against manifest text.
_DEPENDENCY_ROLE_HINTS: Dict[str, List[str]] = {
    "database": [
        "pg", "psycopg2", "psycopg", "postgres", "mysql", "mysqlclient", "mysql2",
        "sqlalchemy", "prisma", "mongoose", "pymongo", "mongodb", "sequelize",
        "django.db", "typeorm", "knex", "sqlite3", "asyncpg",
    ],
    "cache": ["redis", "ioredis", "memcached", "node-cache", "django-redis"],
    "queue": ["celery", "bullmq", "kafka-python", "kafkajs", "pika", "amqplib", "sidekiq", "bee-queue"],
    "search": ["elasticsearch", "opensearch", "algoliasearch", "meilisearch"],
}

# frontend-framework signals — if these dominate and no backend signal is
# found, the app itself is best described as a "gateway"-served static/SSR
# frontend rather than an API service.
_FRONTEND_ONLY_HINTS = ["next", "react-scripts", "vite", "nuxt", "@angular/core", "svelte"]


def _scan_manifest_text(text: str) -> List[str]:
    lowered = text.lower()
    found: List[str] = []
    for role, keywords in _DEPENDENCY_ROLE_HINTS.items():
        if any(re.search(rf"[\"'/]{re.escape(kw)}[\"'@/ ]", lowered) or kw in lowered for kw in keywords):
            found.append(role)
    return found


def infer_app_role(manifest_texts: Dict[str, str]) -> str:
    """Decides whether the repo's own primary service looks like an API/
    backend, or a frontend served behind a gateway, based on manifest
    contents actually read from the repo."""
    combined = " ".join(manifest_texts.values()).lower()
    has_frontend_signal = any(hint in combined for hint in _FRONTEND_ONLY_HINTS)
    has_backend_signal = any(
        term in combined for term in ["express", "fastapi", "flask", "django", "spring", "gin", "actix", "nestjs"]
    )
    if has_frontend_signal and not has_backend_signal:
        return "gateway"
    return "api"


async def infer_fallback_architecture(
    github,  # GitHubService — typed loosely to avoid a circular import
    owner: str,
    name: str,
    branch: str,
    repo_full_name: str,
    tree: List[dict],
) -> ArchitectureGraph:
    """
    Builds a best-effort ArchitectureGraph from real signals in the repo
    tree, used when no docker-compose file is present.
    """
    tree_paths = {item["path"] for item in tree if item.get("type") == "blob"}

    present_manifests = [p for p in _MANIFEST_FILES if p in tree_paths]
    has_dockerfile = any(p.lower() == "dockerfile" or p.lower().endswith("/dockerfile") for p in tree_paths)

    manifest_texts: Dict[str, str] = {}
    for manifest in present_manifests:
        content = await github.try_get_file_content(owner, name, manifest, branch)
        if content:
            manifest_texts[manifest] = content

    detected_roles: set = set()
    for text in manifest_texts.values():
        detected_roles.update(_scan_manifest_text(text))

    app_role = infer_app_role(manifest_texts)
    ecosystems = sorted({_MANIFEST_FILES[m] for m in present_manifests})

    services: List[ServiceNode] = [
        ServiceNode(
            name=name.lower().replace(" ", "-") or "app",
            inferred_role=app_role,
            depends_on=[],
            replicas=2 if app_role == "api" else 1,
        )
    ]
    edges: List[List[str]] = []

    role_labels = {"database": "database", "cache": "cache", "queue": "queue", "search": "search"}
    for role_key in ("database", "cache", "queue", "search"):
        if role_key in detected_roles:
            services.append(ServiceNode(name=role_labels[role_key], inferred_role=role_key, replicas=1))
            edges.append([services[0].name, role_labels[role_key]])

    signal_bits = []
    if present_manifests:
        signal_bits.append(f"manifest file(s) {', '.join(present_manifests)}")
    if has_dockerfile:
        signal_bits.append("a Dockerfile")
    if detected_roles:
        signal_bits.append(f"dependency signals for {', '.join(sorted(detected_roles))}")

    if signal_bits:
        reason = (
            "No docker-compose file found. Architecture inferred from " + "; ".join(signal_bits) +
            f" (ecosystem: {', '.join(ecosystems) if ecosystems else 'unknown'}). "
            "This is a heuristic reconstruction, not a verified topology — review and edit before simulating."
        )
    else:
        reason = (
            "No docker-compose file and no recognized manifest files found in the repository tree. "
            "Falling back to a single generic service node — edit the architecture before simulating."
        )

    return ArchitectureGraph(
        repo_full_name=repo_full_name,
        default_branch=branch,
        services=services,
        edges=edges,
        compose_file_path=None,
        used_fallback=True,
        fallback_reason=reason,
    )
