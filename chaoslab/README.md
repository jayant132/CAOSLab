# ChaosLab

**AI-powered scalability & resilience simulation platform.**

> Paste a GitHub repository and a target scenario — e.g. *"what happens if
> traffic goes from 100K to 10M users?"* — and ChaosLab reconstructs the
> system's architecture, runs a deterministic capacity simulation against
> it, and uses a multi-agent LangGraph pipeline to identify the most likely
> breaking point and what to do about it.

![status](https://img.shields.io/badge/status-active-3ECF8E)
![backend](https://img.shields.io/badge/backend-FastAPI%20%2B%20LangGraph-4FD1C5)
![frontend](https://img.shields.io/badge/frontend-Flutter%20(MVVM)-4FD1C5)
![license](https://img.shields.io/badge/license-MIT-8C9BB0)

---

## What it does

1. **You give it a public GitHub repo.** ChaosLab reads the repository tree
   and reconstructs a service topology — from `docker-compose.yml` when one
   exists, or from real repo signals (manifest files, dependencies, a
   `Dockerfile`) when it doesn't. See [Repository intake](#repository-intake--fallback-behavior).
2. **You configure a scenario.** Target concurrent-user count and an
   optional failure scenario (database latency spike, cache outage,
   dependency timeout, traffic surge, instance loss).
3. **A 4-stage agent pipeline runs, live.** Architecture interpretation →
   deterministic capacity/failure simulation → bottleneck investigation
   (with built-in self-verification against the evidence) → remediation.
   Every stage streams to the client over Server-Sent Events as it
   completes.
4. **You get a report**, not a guess: the primary bottleneck, the
   measured metrics that support it, the failure chain, and a concrete
   remediation plan — each framed as an *estimate* from a deterministic
   model, never as a certainty.

## Why the architecture is the way it is

This isn't a chat UI wrapped around one LLM call. It's a deliberate split
between two kinds of work, made visible in the product itself:

| | Handled by | Examples |
|---|---|---|
| **Reasoning** | LLM agents (LangGraph, Groq) | Interpreting the topology, ranking bottlenecks and explaining *why*, writing remediation steps |
| **Computation** | A deterministic capacity model | Utilization %, latency, error rate, risk score — plain queueing-theory-style math, no LLM involved |

The Investigator agent's claim about *why* a service is the bottleneck is
never taken on faith — it's checked against the same evidence the model
produced, with one bounded self-revision if the first answer doesn't hold
up. That check is what "estimated risk" actually means here, instead of
being a disclaimer bolted onto an LLM's opinion.

### The pipeline

```
Architecture Agent  →  Simulation Agent  →  Investigator Agent  →  Remediation Agent
 (LLM, reads the        (deterministic:         (LLM, ranks             (LLM, turns
  parsed topology)        traffic profile +       bottlenecks from        confirmed
                           baseline capacity +     evidence, self-         findings into
                           failure-scenario run)   verifies the top        concrete next
                                                    claim against the      steps + report
                                                    measured risk score)   narrative)
```

Four stages, each with one clear job. This was previously a 7-node graph;
three purely deterministic steps (traffic / capacity / failure) collapsed
into one `simulation_agent` pass, and a separate `critic_agent` — which was
already a deterministic evidence check, not a second LLM opinion — now runs
inline inside `investigator_agent` as a bounded self-verification step.
Same math, same guarantees, fewer redundant hops. Full rationale in
[`backend/app/agents/graph.py`](backend/app/agents/graph.py).

Every hand-off streams to the Flutter client over SSE
(`GET /api/v1/simulation/stream/{id}`) as it happens, so the live pipeline
view shows agents actually completing in sequence rather than one opaque
spinner.

## Repository intake & fallback behavior

Most real repositories don't ship a `docker-compose.yml`. ChaosLab handles
that without falling back to a fixed, made-up template:

- **Compose file found** → parsed directly into services, dependency
  edges, resource limits, and replica counts.
- **No compose file** → the repository tree is scanned for real signals:
  manifest files (`package.json`, `requirements.txt`, `go.mod`, `Gemfile`,
  `pom.xml`, ...), a `Dockerfile`, and dependency names inside those
  manifests (`pg`, `redis`, `celery`, `mongoose`, ...). A database, cache,
  queue, or search node is only added if a concrete dependency signal
  backs it — a frontend-only repo correctly infers a single gateway-served
  node instead of an invented backend.
- **Nothing recognizable found** → a single generic service node, clearly
  labeled as unconfirmed.

Every fallback architecture is returned with `used_fallback: true` and a
`fallback_reason` explaining exactly what was detected, and the UI always
presents it as editable, not as verified ground truth.

## Stack

| Layer | Choice | Why |
|---|---|---|
| Agent orchestration | LangGraph | Explicit, typed state graph — not just a linear prompt chain |
| LLM | Groq (Llama 3.3 70B) | Free tier, very low latency — a good fit for a pipeline making several calls per run |
| Backend | FastAPI | Async, SSE-friendly, Pydantic schemas double as the API contract |
| Frontend | Flutter (MVVM) | `provider` + plain `ChangeNotifier`, `dio` for HTTP, a hand-rolled SSE client |
| Repo intake | GitHub REST API + PyYAML | Parses `docker-compose.yml`; infers a fallback architecture from repo signals when none exists |

## Project layout

```
chaoslab/
  backend/             FastAPI + LangGraph — see backend/README.md
  frontend/
    chaoslab_flutter/  Flutter MVVM client — see frontend/chaoslab_flutter/README.md
```

## Running it end to end

```bash
# 1. Backend
cd backend
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env   # optionally add a free Groq key — runs fine without one, see below
uvicorn app.main:app --reload --port 8000

# 2. Frontend (separate terminal)
cd frontend/chaoslab_flutter
flutter create . --platforms=android,ios,web
flutter pub get
flutter run
```

The backend runs with zero API keys out of the box: every reasoning agent
has a deterministic stub fallback when `GROQ_API_KEY` isn't set, so the
full 4-agent pipeline and final report work immediately. Add a free key
from https://console.groq.com/keys when you want the agents reasoning in
natural language instead of following fixed rules.

> **A note on scope, worth reading before you judge the risk numbers:**
> ChaosLab does not spin up real infrastructure or run live load tests
> against a deployed target. `capacity_model.py` is a deterministic,
> queueing-theory-style model — real capacity-planning math, just not a
> live measurement — which is exactly why every number in the report is
> worded as *estimated*, never as a certainty. See
> [`backend/README.md`](backend/README.md#an-important-scoping-note-say-this-out-loud-in-interviews)
> for the full reasoning.

## API surface

Deliberately namespaced, no generic `/health` or `/run`:

| Method | Path | Purpose |
|---|---|---|
| `GET`  | `/api/v1/system/pulse` | Liveness + whether Groq is configured |
| `POST` | `/api/v1/repository/inspect` | Public GitHub URL → parsed `ArchitectureGraph` |
| `POST` | `/api/v1/simulation/execute` | Launch the agent pipeline, returns a `simulation_id` immediately |
| `GET`  | `/api/v1/simulation/stream/{simulation_id}` | Server-Sent Events: live agent activity, ends with a `final_report` event |
| `GET`  | `/api/v1/simulation/report/{simulation_id}` | One-shot poll for the current/final report (fallback if SSE drops) |

Full endpoint and module documentation: [`backend/README.md`](backend/README.md).
Frontend architecture and screen-by-screen notes: [`frontend/chaoslab_flutter/README.md`](frontend/chaoslab_flutter/README.md).

## Roadmap / known scope boundaries

- No auth on the API — this is a single-user portfolio/demo backend, not
  a multi-tenant service. Adding auth would touch `core/config.py` and the
  routers, not the agent pipeline.
- `store/simulation_store.py` is in-memory by design; swapping it for
  Redis/Postgres is a contained change if this ever needs to survive a
  restart or run multi-process.
- Public repos only — no OAuth flow for private repositories yet.

## License

MIT — see [LICENSE](LICENSE).
