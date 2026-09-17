"""
Reads a public GitHub repository's file tree and fetches candidate
docker-compose files. No OAuth — public repos only, by design (see
project scope notes in README).
"""
import base64
import re
from dataclasses import dataclass
from typing import List, Optional

import httpx

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)

COMPOSE_FILENAMES = [
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "compose.yaml",
    "docker-compose.prod.yml",
    "docker-compose.dev.yml",
]

_REPO_URL_PATTERN = re.compile(
    r"github\.com[/:]([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$"
)


class GitHubServiceError(Exception):
    pass


@dataclass
class ParsedRepoUrl:
    owner: str
    name: str


def parse_repo_url(repo_url: str) -> ParsedRepoUrl:
    match = _REPO_URL_PATTERN.search(repo_url.strip())
    if not match:
        raise GitHubServiceError(
            "Could not parse a GitHub owner/repo from that URL. "
            "Expected something like https://github.com/owner/repo"
        )
    return ParsedRepoUrl(owner=match.group(1), name=match.group(2))


class GitHubService:
    def __init__(self) -> None:
        settings = get_settings()
        self._base = settings.github_api_base
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if settings.github_token:
            headers["Authorization"] = f"Bearer {settings.github_token}"
        self._client = httpx.AsyncClient(base_url=self._base, headers=headers, timeout=15.0)

    async def close(self) -> None:
        await self._client.aclose()

    async def get_repo_metadata(self, owner: str, name: str) -> dict:
        resp = await self._client.get(f"/repos/{owner}/{name}")
        if resp.status_code == 404:
            raise GitHubServiceError(f"Repository '{owner}/{name}' not found or is private.")
        if resp.status_code == 403:
            raise GitHubServiceError(
                "GitHub API rate limit hit. Set GITHUB_TOKEN in .env to raise the limit to 5000/hr."
            )
        resp.raise_for_status()
        return resp.json()

    async def get_languages(self, owner: str, name: str) -> dict:
        resp = await self._client.get(f"/repos/{owner}/{name}/languages")
        if resp.status_code != 200:
            return {}
        return resp.json()

    async def get_repo_tree(self, owner: str, name: str, branch: str) -> List[dict]:
        resp = await self._client.get(f"/repos/{owner}/{name}/git/trees/{branch}", params={"recursive": "1"})
        resp.raise_for_status()
        data = resp.json()
        return data.get("tree", [])

    async def find_compose_path(self, owner: str, name: str, branch: str) -> Optional[str]:
        tree = await self.get_repo_tree(owner, name, branch)
        candidates = [
            item["path"]
            for item in tree
            if item.get("type") == "blob"
            and item["path"].rsplit("/", 1)[-1] in COMPOSE_FILENAMES
        ]
        if not candidates:
            return None
        # Prefer the shallowest match (repo root over a nested example folder).
        candidates.sort(key=lambda p: p.count("/"))
        return candidates[0]

    async def get_file_content(self, owner: str, name: str, path: str, branch: str) -> str:
        resp = await self._client.get(
            f"/repos/{owner}/{name}/contents/{path}", params={"ref": branch}
        )
        resp.raise_for_status()
        payload = resp.json()
        if payload.get("encoding") != "base64":
            raise GitHubServiceError(f"Unexpected encoding for {path}")
        return base64.b64decode(payload["content"]).decode("utf-8", errors="replace")

    async def try_get_file_content(self, owner: str, name: str, path: str, branch: str) -> Optional[str]:
        """Best-effort file read used for probing manifest files during
        fallback architecture inference — a missing file is expected and
        not an error, so this returns None instead of raising."""
        try:
            resp = await self._client.get(
                f"/repos/{owner}/{name}/contents/{path}", params={"ref": branch}
            )
            if resp.status_code != 200:
                return None
            payload = resp.json()
            if payload.get("encoding") != "base64":
                return None
            return base64.b64decode(payload["content"]).decode("utf-8", errors="replace")
        except Exception:  # noqa: BLE001 — probing is best-effort by design
            return None
