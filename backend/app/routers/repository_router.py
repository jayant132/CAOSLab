"""
Repository intake endpoints: paste a public GitHub URL, get back a parsed
ArchitectureGraph ready to feed into /api/v1/simulation/execute.
"""
from fastapi import APIRouter, HTTPException

from app.core.logging import get_logger
from app.models.schemas import RepositoryInspectRequest, RepositoryInspectResponse
from app.services.compose_parser import build_fallback_graph, parse_compose_yaml
from app.services.github_service import GitHubService, GitHubServiceError, parse_repo_url
from app.services.repo_inference import infer_fallback_architecture

logger = get_logger(__name__)
router = APIRouter(prefix="/api/v1/repository", tags=["repository"])


@router.post("/inspect", response_model=RepositoryInspectResponse)
async def inspect_repository(payload: RepositoryInspectRequest) -> RepositoryInspectResponse:
    warnings = []
    try:
        parsed_url = parse_repo_url(payload.repo_url)
    except GitHubServiceError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    github = GitHubService()
    try:
        metadata = await github.get_repo_metadata(parsed_url.owner, parsed_url.name)
        branch = metadata.get("default_branch", "main")
        repo_full_name = metadata.get("full_name", f"{parsed_url.owner}/{parsed_url.name}")

        tree = await github.get_repo_tree(parsed_url.owner, parsed_url.name, branch)
        compose_path = None
        candidates = [
            item["path"]
            for item in tree
            if item.get("type") == "blob"
            and item["path"].rsplit("/", 1)[-1] in {
                "docker-compose.yml", "docker-compose.yaml", "compose.yml",
                "compose.yaml", "docker-compose.prod.yml", "docker-compose.dev.yml",
            }
        ]
        if candidates:
            candidates.sort(key=lambda p: p.count("/"))
            compose_path = candidates[0]

        if not compose_path:
            architecture = await infer_fallback_architecture(
                github, parsed_url.owner, parsed_url.name, branch, repo_full_name, tree
            )
            warnings.append(
                architecture.fallback_reason
                or "No docker-compose file found — using an inferred fallback architecture. "
                "Review and edit it before running the simulation."
            )
            return RepositoryInspectResponse(architecture=architecture, warnings=warnings)

        raw_yaml = await github.get_file_content(parsed_url.owner, parsed_url.name, compose_path, branch)

        try:
            architecture = parse_compose_yaml(raw_yaml, compose_path, repo_full_name, branch)
        except ValueError as exc:
            warnings.append(f"Failed to parse {compose_path}: {exc}. Using fallback architecture.")
            architecture = build_fallback_graph(repo_full_name, branch, reason=str(exc))
            return RepositoryInspectResponse(architecture=architecture, warnings=warnings)

        if not architecture.services:
            warnings.append(
                f"{compose_path} contained no services — using fallback architecture."
            )
            architecture = build_fallback_graph(
                repo_full_name, branch, reason="Compose file had an empty 'services' block."
            )

        return RepositoryInspectResponse(architecture=architecture, warnings=warnings)

    except GitHubServiceError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001 — surfaced to client as 502
        logger.exception("Unexpected error inspecting repository")
        raise HTTPException(status_code=502, detail=f"Unexpected error reading repository: {exc}") from exc
    finally:
        await github.close()
