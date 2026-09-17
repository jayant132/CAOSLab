"""
Deliberately named 'system_router', with endpoint '/api/v1/system/pulse'
rather than the generic '/health', per project requirements.
"""
from fastapi import APIRouter

from app.core.config import get_settings
from app.models.schemas import HealthPayload

router = APIRouter(prefix="/api/v1/system", tags=["system"])


@router.get("/pulse", response_model=HealthPayload)
async def get_system_pulse() -> HealthPayload:
    settings = get_settings()
    return HealthPayload(
        service="chaoslab-backend",
        version="1.0.0",
        groq_configured=bool(settings.groq_api_key),
    )
