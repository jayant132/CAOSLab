# ChaosLab — Backend

FastAPI + LangGraph multi-agent pipeline that estimates where a system
architecture would break under a given load and failure scenario, and
proposes what to change.

## Quick start

```bash
cd backend
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Edit .env: paste a free Groq key from https://console.groq.com/keys
# The app runs without one too — see "Stub mode" below.

uvicorn app.main:app --reload --port 8000
```

Interactive API docs: http://127.0.0.1:8000/docs

## Stub mode (no API key required)

Every agent node checks for `GROQ_API_KEY` at call time. If it's missing,
each agent falls back to a deterministic, rule-based version of its own
reasoning step instead of calling an LLM — the full 4-agent pipeline still
runs end to end, still produces a real report, and the UI behaves
identically. This means you (or a recruiter) can clone this repo and run
the whole thing immediately with zero setup cost, and only need a Groq key
once you want the agents actually reasoning in natural language instead of
following fixed rules. `GET /api/v1/system/pulse` reports whether a key is
currently configured (`groq_configured`).

Groq's free tier is generous and fast (Llama 3.3 70B at very low latency),
which is why it's the default here instead of a paid provider.

## Endpoints

Deliberately namespaced and specifically named — no generic `/health` or
`/run` anywhere in the API surface.

| Method | Path | Purpose |
|---|---|---|
| `GET`  | `/api/v1/system/pulse` | Liveness + whether Groq is configured |
| `POST` | `/api/v1/repository/inspect` | Public GitHub URL → parsed `ArchitectureGraph` |
| `POST` | `/api/v1/simulation/execute` | Launch the agent pipeline, returns a `simulation_id` immediately |
| `GET`  | `/api/v1/simulation/stream/{simulation_id}` | Server-Sent Events: live agent activity feed, ends with a `final_report` event |
| `GET`  | `/api/v1/simulation/report/{simulation_id}` | One-shot poll for the current/final report (fallback if SSE drops) |

## Architecture

```
app/
  main.py                  FastAPI app, CORS, router wiring
  core/
    config.py               env-driven settings (Groq key/model, GitHub token, CORS)
    logging.py
  models/
    schemas.py               single source of truth for the API contract
                              (Flutter's Dart models mirror this file field-for-field)
  services/
    github_service.py        GitHub REST API client (repo metadata, tree search, file fetch)
    compose_parser.py        docker-compose.yml -> ArchitectureGraph, + static safety-net fallback
    repo_inference.py        evidence-based fallback: infers architecture from manifest files
                              (package.json, requirements.txt, go.mod, ...) and their
                              dependencies when no docker-compose file exists
    capacity_model.py        deterministic queueing/capacity math (see note below)
    simulation_service.py    runs the LangGraph pipeline, writes progress to the store
  agents/
    graph.py                 the LangGraph StateGraph wiring (4 nodes, linear)
    state.py                 shared pipeline state (TypedDict)
    llm_client.py            thin Groq wrapper with stub-mode fallback
    architecture_agent.py     summarizes the parsed topology
    simulation_agent.py      deterministic: synthetic workload, baseline capacity run,
                              and the failure-scenario run — consolidates what used to
                              be three separate nodes (traffic/capacity/failure), since
                              none of them involve LLM reasoning
    investigator_agent.py    ranks components by risk, explains the top finding, and
                              self-verifies that finding against the raw evidence with
                              one bounded revision pass — this absorbs the former
                              critic_agent, which was a deterministic check, not a
                              second LLM opinion, so it didn't need its own pipeline hop
    remediation_agent.py     turns the confirmed finding into concrete next steps
  store/
    simulation_store.py       in-memory job store (swap for Redis/Postgres if this
                              ever needs to survive a restart or run multi-process)
  routers/
    system_router.py, repository_router.py, simulation_router.py
```

## An important scoping note (say this out loud in interviews)

This project does **not** spin up real infrastructure, run actual k6/Locust
load tests, or inject real faults with Chaos Mesh/Toxiproxy — none of that
is meaningful without a real deployed target, and building one just to
demo a portfolio project would be its own multi-month effort disconnected
from the actual point of this project (agent orchestration + capacity
reasoning).

Instead, `capacity_model.py` is a **deterministic queueing-theory-style
model**: each service has a role-based per-instance capacity, traffic
fans out to services by role, and utilization/latency/error-rate are
computed from load ÷ currently-provisioned capacity. Failure scenarios
degrade a service's effective per-instance capacity via a multiplier. This
is genuinely how capacity planning back-of-envelope math works — it's just
explicitly a **model**, not a live measurement, which is exactly why every
report is worded as "estimated risk" rather than a certainty. Swapping this
module for a real load-test harness against a real staging environment is
the natural "v2" if this ever became more than a portfolio piece, and the
rest of the architecture (agents consuming `ComponentMetric` objects) does
not need to change to support that.

## Fallback architecture inference

Most real-world repos don't ship a `docker-compose.yml` at the root — a
frontend app, a single service deployed via a PaaS, a monorepo with compose
buried somewhere non-standard. `repo_inference.py` handles that case by
reading real signals out of the repository instead of guessing: which
manifest files exist (`package.json`, `requirements.txt`, `go.mod`, `Gemfile`,
`pom.xml`, ...), whether a `Dockerfile` is present, and which dependency
names appear inside those manifests (`pg`, `redis`, `celery`, `mongoose`,
...). A database/cache/queue/search node is only added to the inferred
graph if a concrete dependency signal was found for it — nothing is
invented to fill out a template. The response is still flagged
`used_fallback: true` with a `fallback_reason` explaining exactly which
signals were used, and the Flutter client always surfaces that as an
editable, unconfirmed architecture rather than presenting it as ground
truth. `compose_parser.build_fallback_graph()` remains as a last-resort
static safety net for the rarer case where a compose file exists but fails
to parse or declares zero services.

## Testing without a GitHub rate limit

Unauthenticated GitHub API calls are capped at 60/hour. Set `GITHUB_TOKEN`
in `.env` (no scopes needed, just a plain token) to raise that to 5000/hour
— generate one at https://github.com/settings/tokens.
