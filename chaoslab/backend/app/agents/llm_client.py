"""
Thin wrapper around Groq's free-tier LLM API (OpenAI-compatible), shared by
every reasoning agent in the graph. Centralizing this makes it trivial to
swap models/providers later (the whole point of naming it llm_client, not
groq_client, in imports elsewhere).
"""
import json
from typing import Any, Dict, Optional

from groq import AsyncGroq

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)


class LLMClient:
    def __init__(self) -> None:
        settings = get_settings()
        self._model = settings.groq_model
        self._client: Optional[AsyncGroq] = (
            AsyncGroq(api_key=settings.groq_api_key) if settings.groq_api_key else None
        )

    @property
    def is_configured(self) -> bool:
        return self._client is not None

    async def complete(self, system_prompt: str, user_prompt: str, temperature: float = 0.3) -> str:
        """Returns raw text completion. Falls back to a deterministic stub
        if no API key is configured, so the pipeline stays demoable without
        secrets set up."""
        if not self._client:
            return (
                "[LLM not configured — set GROQ_API_KEY in backend/.env to enable live reasoning] "
                "Analysis unavailable in stub mode."
            )
        response = await self._client.chat.completions.create(
            model=self._model,
            temperature=temperature,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        )
        return response.choices[0].message.content or ""

    async def complete_json(self, system_prompt: str, user_prompt: str, temperature: float = 0.2) -> Dict[str, Any]:
        """Requests a strict-JSON completion and parses it, with a safe fallback."""
        if not self._client:
            return {"error": "llm_not_configured"}

        json_system = (
            system_prompt
            + "\n\nRespond with ONLY a single valid JSON object. No markdown fences, no preamble."
        )
        raw = await self.complete(json_system, user_prompt, temperature=temperature)
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.strip("`")
            if cleaned.lower().startswith("json"):
                cleaned = cleaned[4:]
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning("Failed to parse LLM JSON output, returning raw text wrapper.")
            return {"raw_text": raw}


_llm_singleton: Optional[LLMClient] = None


def get_llm_client() -> LLMClient:
    global _llm_singleton
    if _llm_singleton is None:
        _llm_singleton = LLMClient()
    return _llm_singleton
