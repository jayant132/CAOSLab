"""
ChaosLab backend entrypoint.

Run locally with:
    uvicorn app.main:app --reload --port 8000

Endpoints are deliberately namespaced under /api/v1/<domain>/<action> with
specific, unique action names (see routers/) rather than generic verbs like
"/health" or "/run" — this keeps the API self-documenting as the project
grows and avoids collisions if more domains are added later.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.routers import repository_router, simulation_router, system_router

configure_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    if not settings.groq_api_key:
        logger.warning(
            "GROQ_API_KEY is not set — agents will run in stub mode. "
            "Get a free key at https://console.groq.com/keys and put it in backend/.env"
        )
    else:
        logger.info("Groq configured with model=%s", settings.groq_model)
    yield
    logger.info("ChaosLab backend shutting down.")


def create_app() -> FastAPI:
    app = FastAPI(
        title="ChaosLab API",
        description=(
            "AI-powered scalability & resilience simulation platform. "
            "Multi-agent pipeline built with LangGraph, reasoning agents on Groq."
        ),
        version="1.0.0",
        lifespan=lifespan,
    )

    settings = get_settings()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(system_router.router)
    app.include_router(repository_router.router)
    app.include_router(simulation_router.router)

    return app


app = create_app()
